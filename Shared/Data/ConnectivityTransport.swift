//
//  ConnectivityTransport.swift
//  Clarity
//
//  Swift 6 transport for watch ↔ iPhone connectivity.
//
//  NOTE: WCSession API methods are isolated to the main actor in current SDKs,
//  so the transport itself is @MainActor. JSON encode/decode and queue state still
//  live here; the only main-thread work is the WCSession calls.
//

import Foundation
import WatchConnectivity
import XCGLogger

#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - WCSession abstraction

@preconcurrency protocol WCSessionProtocol: AnyObject {
    var activationState: WCSessionActivationState { get }
    #if os(iOS)
    var isComplicationEnabled: Bool { get }
    #endif

    func activate()
    func updateApplicationContext(_ context: [String: Any]) throws
    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer
    #if os(iOS)
    func transferCurrentComplicationUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer
    #endif
    func sendMessageData(_ data: Data,
                         replyHandler: ((Data) -> Void)?,
                         errorHandler: ((Error) -> Void)?)
}

extension WCSession: WCSessionProtocol {}

// MARK: - Snapshot builder

protocol SnapshotBuilder: Sendable {
    func buildSnapshot() async -> Snapshot
}

// MARK: - Transport

@MainActor
final class ConnectivityTransport: NSObject {
    static let shared = ConnectivityTransport(session: WCSession.default)

    private let session: WCSessionProtocol
    private var outboundQueue: [Data] = []
    private var lastComplicationDigest: Data? = nil
    private var snapshotBuilder: SnapshotBuilder?
    private var inboundContinuation: AsyncStream<WireMessage>.Continuation?

    nonisolated let inbound: AsyncStream<WireMessage>

    private init(session: WCSessionProtocol) {
        self.session = session
        var cont: AsyncStream<WireMessage>.Continuation!
        self.inbound = AsyncStream { continuation in
            cont = continuation
        }
        super.init()
        self.inboundContinuation = cont
    }

    // MARK: Configuration

    func configure(snapshotBuilder: SnapshotBuilder) {
        self.snapshotBuilder = snapshotBuilder
    }

    nonisolated func start() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard WCSession.isSupported() else {
                LogManager.shared.log.debug("[ConnectivityTransport] WCSession not supported")
                return
            }
            (self.session as? WCSession)?.delegate = self
            self.session.activate()
            LogManager.shared.log.verbose("[ConnectivityTransport] WCSession activating")
        }
    }

    // MARK: Outbound API

    func send(_ command: WatchCommand) async throws {
        let msg = WireMessage.command(command)
        let data = try makeEncoder().encode(msg)
        enqueueReliable(data)
    }

    func send(_ event: PhoneEvent) async throws {
        let msg = WireMessage.event(event)
        let data = try makeEncoder().encode(msg)
        enqueueReliable(data)
    }

    func pushState(_ snapshot: Snapshot) async throws {
        let data = try makeEncoder().encode(WireMessage.snapshot(snapshot))
        try session.updateApplicationContext(["payload": data])
    }

    func pushComplicationIfNeeded(_ snapshot: Snapshot) async throws {
        let projection = ComplicationProjection(snapshot: snapshot)
        let digest = try complicationDigest(for: projection)
        guard digest != lastComplicationDigest else { return }
        lastComplicationDigest = digest
        let data = try makeEncoder().encode(WireMessage.complicationSnapshot(snapshot))
        #if os(iOS)
        if session.isComplicationEnabled {
            _ = session.transferCurrentComplicationUserInfo(["complication": data])
        } else {
            // Smart Stack fallback: still wake the watch, but via userInfo.
            _ = session.transferUserInfo(["complication": data])
        }
        #else
        _ = session.transferUserInfo(["complication": data])
        #endif
    }

    func fetchSnapshot() async throws -> Snapshot {
        let requestData = try makeEncoder().encode(WireMessage.command(.requestSnapshot))
        let reply: Data = try await withCheckedThrowingContinuation { cont in
            session.sendMessageData(requestData,
                replyHandler: { cont.resume(returning: $0) },
                errorHandler: { cont.resume(throwing: $0) })
        }
        let msg = try makeDecoder().decode(WireMessage.self, from: reply)
        guard case .snapshot(let snap) = msg else {
            throw NSError(domain: "ConnectivityTransport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected reply"])
        }
        return snap
    }

    // MARK: Private queueing

    private func enqueueReliable(_ data: Data) {
        outboundQueue.append(data)
        flushOutboundIfActivated()
    }

    private func flushOutboundIfActivated() {
        guard session.activationState == .activated, !outboundQueue.isEmpty else { return }
        let pending = outboundQueue
        outboundQueue.removeAll()
        for data in pending {
            _ = session.transferUserInfo(["payload": data])
        }
    }

    private func emit(_ message: WireMessage) {
        inboundContinuation?.yield(message)
    }

    // MARK: Coding utilities

    private func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private func makeDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    // MARK: Complication digest

    private func complicationDigest(for projection: ComplicationProjection) throws -> Data {
        let data = try makeEncoder().encode(projection)
        #if canImport(CryptoKit)
        return Data(SHA256.hash(data: data))
        #else
        return data
        #endif
    }
}

// MARK: - WCSessionDelegate

extension ConnectivityTransport: WCSessionDelegate {

    nonisolated func session(_ s: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        LogManager.shared.log.verbose("[ConnectivityTransport] activationDidCompleteWith state=\(state.rawValue), error=\(String(describing: error))")
        Task { @MainActor [weak self] in
            self?.flushOutboundIfActivated()
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ s: WCSession) {}

    nonisolated func sessionDidDeactivate(_ s: WCSession) {
        s.activate()
    }
#endif

    nonisolated func session(_ s: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["complication"] as? Data,
           let msg = try? decodeMessage(data) {
            Task { @MainActor [weak self] in self?.emit(msg) }
            return
        }
        guard let data = userInfo["payload"] as? Data,
              let msg = try? decodeMessage(data) else { return }
        Task { @MainActor [weak self] in self?.emit(msg) }
    }

    nonisolated func session(_ s: WCSession,
                             didReceiveApplicationContext ctx: [String: Any]) {
        guard let data = ctx["payload"] as? Data,
              let msg = try? decodeMessage(data) else { return }
        Task { @MainActor [weak self] in self?.emit(msg) }
    }

    nonisolated func session(_ s: WCSession,
                             didReceiveMessageData data: Data,
                             replyHandler: @escaping (Data) -> Void) {
        let boxed = SendableReplyHandler(replyHandler)
        guard let msg = try? decodeMessage(data) else {
            Task { @MainActor in boxed.reply(Data()) }
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { boxed.reply(Data()); return }
            if case .command(.requestSnapshot) = msg,
               let builder = self.snapshotBuilder {
                let snap = await builder.buildSnapshot()
                let replyMsg = WireMessage.snapshot(snap)
                if let replyData = try? self.makeEncoder().encode(replyMsg) {
                    boxed.reply(replyData)
                    return
                }
            }
            boxed.reply(Data())
        }
    }
}

// MARK: - Sendable reply handler box

/// WCSession reply handlers are Obj-C blocks, callable from any thread.
/// This is the only @unchecked Sendable in the module.
private nonisolated struct SendableReplyHandler: @unchecked Sendable {
    let handler: (Data) -> Void
    init(_ handler: @escaping (Data) -> Void) { self.handler = handler }
    func reply(_ data: Data) { handler(data) }
}

private nonisolated func decodeMessage(_ data: Data) throws -> WireMessage {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    return try dec.decode(WireMessage.self, from: data)
}
