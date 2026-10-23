// CompanionView.swift
// Floating companion overlay — appears across all tabs

import SwiftUI

// MARK: - Layout math (pure, testable)

/// Valid bounds for the bubble's center point within a given container size.
/// The overlay no longer ignores the safe area, so `containerSize` already excludes
/// unsafe regions (notch, home indicator, Duo hinge). We keep the historical
/// `tabBarAllowance` so the bubble rests above the tab bar rather than over it.
enum CompanionBubbleLayout {
    static let tabBarAllowance: Double = 80

    struct CenterRange: Equatable {
        var minX: Double
        var maxX: Double
        var minY: Double
        var maxY: Double

        func contains(_ point: CGPoint) -> Bool {
            point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
        }

        /// Clamp `value` into `[lower, upper]`. If the range is degenerate
        /// (lower > upper), returns the midpoint of the two bounds so the
        /// bubble stays deterministic rather than exploding.
        private static func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
            if lower > upper { return (lower + upper) / 2 }
            return Swift.min(Swift.max(value, lower), upper)
        }

        func clampedPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: CenterRange.clamped(point.x, minX, maxX),
                y: CenterRange.clamped(point.y, minY, maxY)
            )
        }

        func nearestCorner(to point: CGPoint) -> CGPoint {
            let corners: [CGPoint] = [
                CGPoint(x: minX, y: minY),
                CGPoint(x: maxX, y: minY),
                CGPoint(x: minX, y: maxY),
                CGPoint(x: maxX, y: maxY),
            ]
            var best = corners[0]
            var bestDist = Double.greatestFiniteMagnitude
            for c in corners {
                let dx = c.x - point.x
                let dy = c.y - point.y
                let d = dx * dx + dy * dy
                if d < bestDist {
                    bestDist = d
                    best = c
                }
            }
            return best
        }
    }

    static func centerRange(bubbleSize: Double, containerSize: CGSize) -> CenterRange {
        let r = bubbleSize / 2
        return CenterRange(
            minX: r,
            maxX: Double(containerSize.width) - r,
            minY: r,
            maxY: Double(containerSize.height) - r - tabBarAllowance
        )
    }

    /// Given a stored offset (which may be stale after a posture change),
    /// return the point it should be healed to. If the stored point is
    /// outside the valid range, snap to the *nearest* of the range's four
    /// corners — this keeps the bubble in the user's preferred screen
    /// quadrant across span/rotation transitions on Duo.
    static func healedOffset(
        stored: CGPoint,
        bubbleSize: Double,
        containerSize: CGSize
    ) -> CGPoint {
        // (0, 0) means "never moved" — preserve the default anchor.
        guard stored.x != 0 || stored.y != 0 else { return stored }
        let range = centerRange(bubbleSize: bubbleSize, containerSize: containerSize)
        guard !range.contains(stored) else { return stored }
        return range.nearestCorner(to: stored)
    }
}

// MARK: - Floating overlay

struct CompanionOverlayView: View {
    var companion: CompanionService

    // Persisted position (bottom-right by default)
    @AppStorage("companionOffsetX") private var offsetX: Double = 0
    @AppStorage("companionOffsetY") private var offsetY: Double = 0

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var autoDismissTask: Task<Void, Never>? = nil
    @State private var showingChat = false

    @State private var companionEnabled = UserDefaults.companionEnabled

    private let bubbleSize: CGFloat = 72
    private let expandedOtterSize: CGFloat = 90

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                if companion.isVisible && companionEnabled, let message = companion.currentMessage {
                    expandedCard(message: message, geo: geo)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.6, anchor: .bottomTrailing).combined(
                                    with: .opacity
                                ),
                                removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(
                                    with: .opacity
                                )
                            )
                        )
                } else {
                    idleBubble(geo: geo)
                        .accessibilityIdentifier("companion-bubble")
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(true)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: companion.isVisible)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.75), value: companion.currentMessage?.emotion
        )
        .sheet(isPresented: $showingChat) {
            CompanionChatView()
        }
    }

    // MARK: - Idle bubble (small, draggable)

    @ViewBuilder
    private func idleBubble(geo: GeometryProxy) -> some View {
        let position = bubblePosition(in: geo)
        CompanionFaceView(
            emotion: companion.isGenerating ? .thinking : .idle,
            size: bubbleSize,
            assetPrefix: companion.personality.assetPrefix,
            fallbackEmoji: companion.personality.fallbackEmoji
        )
        .offset(dragOffset)
        .position(x: position.x, y: position.y)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    let range = CompanionBubbleLayout.centerRange(
                        bubbleSize: Double(bubbleSize),
                        containerSize: geo.size
                    )
                    let healed = range.clampedPoint(
                        CGPoint(
                            x: offsetX + Double(value.translation.width),
                            y: offsetY + Double(value.translation.height)
                        )
                    )
                    offsetX = Double(healed.x)
                    offsetY = Double(healed.y)
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            guard !isDragging else { return }
            showingChat = true
        }
        .onAppear { healPersistedOffset(in: geo.size) }
        .onChange(of: geo.size) { _, newSize in healPersistedOffset(in: newSize) }
    }

    /// After a posture change (e.g. Duo span ↔ single-screen, or rotation),
    /// a previously persisted offset may land in an unsafe/off-screen region.
    /// Snap it to the nearest valid corner so the bubble is never lost.
    private func healPersistedOffset(in containerSize: CGSize) {
        let healed = CompanionBubbleLayout.healedOffset(
            stored: CGPoint(x: offsetX, y: offsetY),
            bubbleSize: Double(bubbleSize),
            containerSize: containerSize
        )
        if healed.x != offsetX || healed.y != offsetY {
            offsetX = Double(healed.x)
            offsetY = Double(healed.y)
        }
    }

    // MARK: - Expanded card with speech bubble

    @ViewBuilder
    private func expandedCard(message: CompanionMessage, geo: GeometryProxy) -> some View {
        let position = bubblePosition(in: geo)
        let isRightSide = position.x > geo.size.width / 2

        VStack(alignment: isRightSide ? .trailing : .leading, spacing: 0) {
            speechBubble(text: message.text, isRightSide: isRightSide)
                .padding(.bottom, -6)

            HStack(spacing: 8) {
                if !isRightSide {
                    replyButton
                }
                CompanionFaceView(
                    emotion: message.emotion,
                    size: expandedOtterSize,
                    assetPrefix: companion.personality.assetPrefix,
                    fallbackEmoji: companion.personality.fallbackEmoji
                )
                .frame(width: expandedOtterSize, height: expandedOtterSize)
                if isRightSide {
                    replyButton
                }
            }
            .padding(isRightSide ? .trailing : .leading, 4)
        }
        .position(
            x: clamp(position.x, min: 160, max: Double(geo.size.width) - 160),
            y: clamp(position.y - 80, min: 160, max: Double(geo.size.height) - 160)
        )
        .onTapGesture {
            cancelAutoDismiss()
            companion.dismiss()
        }
        .onAppear { scheduleAutoDismiss() }
        .onDisappear { cancelAutoDismiss() }
    }

    private var replyButton: some View {
        Button {
            cancelAutoDismiss()
            companion.dismiss()
            // Small delay so dismiss animation completes before sheet opens
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                showingChat = true
            }
        } label: {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func speechBubble(text: String, isRightSide: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
            )
            .overlay(
                Triangle()
                    .fill(.regularMaterial)
                    .frame(width: 14, height: 10)
                    .frame(maxWidth: .infinity, alignment: isRightSide ? .trailing : .leading)
                    .padding(isRightSide ? .trailing : .leading, 20)
                    .offset(y: 5),
                alignment: .bottom
            )
    }

    // MARK: - Position helpers

    private func bubblePosition(in geo: GeometryProxy) -> CGPoint {
        let defaultX = geo.size.width - bubbleSize / 2 - 16
        let defaultY = geo.size.height - bubbleSize / 2 - 100
        let x = offsetX == 0 ? Double(defaultX) : offsetX
        let y = offsetY == 0 ? Double(defaultY) : offsetY
        return CGPoint(x: x, y: y)
    }

    private func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        Swift.min(Swift.max(value, minVal), maxVal)
    }

    // MARK: - Auto dismiss

    private func scheduleAutoDismiss() {
        cancelAutoDismiss()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            companion.dismiss()
        }
    }

    private func cancelAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
    }
}

// MARK: - Triangle shape for speech bubble tail

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        CompanionOverlayView(companion: CompanionService.shared)
    }
}

#Preview("Chat Sheet") {
    CompanionChatView()
        .environment(CompanionService.shared)
}
