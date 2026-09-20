// CompanionView.swift
// Floating companion overlay — appears across all tabs

import SwiftUI

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
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
                        ))
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
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: companion.currentMessage?.emotion)
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
                    let newX = clamp(
                        offsetX + Double(value.translation.width),
                        min: Double(bubbleSize / 2),
                        max: Double(geo.size.width - bubbleSize / 2)
                    )
                    let newY = clamp(
                        offsetY + Double(value.translation.height),
                        min: Double(bubbleSize / 2),
                        max: Double(geo.size.height - bubbleSize / 2 - 80)
                    )
                    offsetX = newX
                    offsetY = newY
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            guard !isDragging else { return }
            showingChat = true
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

    @ViewBuilder
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
