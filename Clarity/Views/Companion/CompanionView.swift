// CompanionView.swift
// Floating otter companion overlay — appears across all tabs

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
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(true)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: companion.isVisible)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: companion.currentMessage?.emotion)
        .sheet(isPresented: $showingChat) {
            CompanionChatSheet(companion: companion)
        }
    }

    // MARK: - Idle bubble (small, draggable)

    @ViewBuilder
    private func idleBubble(geo: GeometryProxy) -> some View {
        let position = bubblePosition(in: geo)
        ZStack {
            CompanionSpriteView(emotion: .idle, size: bubbleSize)
            // Subtle "thinking" indicator when generating
            if companion.isGenerating {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )
                    }
                    Spacer()
                }
            }
        }
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .clipShape(Circle())
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
                CompanionSpriteView(emotion: message.emotion, size: expandedOtterSize)
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

// MARK: - Chat sheet

struct CompanionChatSheet: View {
    var companion: CompanionService

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Otter header
                VStack(spacing: 8) {
                    CompanionSpriteView(
                        emotion: companion.currentMessage?.emotion ?? .idle,
                        size: 80
                    )
                    if let message = companion.currentMessage {
                        Text(message.text)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 32)
                            .transition(.opacity)
                    } else {
                        Text("What's on your mind?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 20)
                .animation(.easeInOut(duration: 0.3), value: companion.currentMessage?.text)

                Divider()

                Spacer()

                if let task = companion.currentMessage?.suggestedTask {
                    Button {
                        companion.requestStartTask(task.uuid)
                    } label: {
                        Label("Start \"\(task.name)\"", systemImage: "timer")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                if companion.modelAvailability.isAvailable {
                    // Input bar
                    HStack(spacing: 10) {
                        TextField("Say something to \(UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? "Otto")…", text: $inputText, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .focused($inputFocused)
                            .onSubmit { sendMessage() }

                        Button(action: sendMessage) {
                            Group {
                                if companion.isGenerating {
                                    ProgressView()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
                                }
                            }
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || companion.isGenerating)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .padding(.top, 8)
                } else {
                    // Apple Intelligence unavailable notice
                    VStack(spacing: 6) {
                        Label("Apple Intelligence unavailable", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text(companion.modelAvailability.userFacingReason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? "Otto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if companion.modelAvailability.isAvailable {
                inputFocused = true
            }
            Task { await companion.refreshContext() }
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !companion.isGenerating else { return }
        inputText = ""
        companion.chat(trimmed)
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
    CompanionChatSheet(companion: CompanionService.shared)
}
