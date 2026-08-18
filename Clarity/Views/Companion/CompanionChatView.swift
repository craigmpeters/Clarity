// CompanionChatView.swift
// iMessage-style conversation view for the companion.

import SwiftUI

struct CompanionChatView: View {
    var companion: CompanionService

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let bottomID = "bottom"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                companionHeader
                    .padding(.top, 8)
                    .padding(.bottom, 4)
//                    .background(Color(uiColor: .systemBackground))

                ScrollViewReader { proxy in
                    ZStack(alignment: .top) {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(0..<companion.chatHistory.count, id: \.self) { index in
                                    let message = companion.chatHistory[index]
                                    messageRow(message, index: index)
                                        .id(index)
                                }

                                if companion.isGenerating {
                                    TypingIndicatorRow(
                                        assetPrefix: companion.personality.assetPrefix,
                                        fallbackEmoji: companion.personality.fallbackEmoji
                                    )
                                    .id("typing")
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id(bottomID)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .defaultScrollAnchor(.bottom)
                        .onChange(of: companion.chatHistory.count) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: companion.isGenerating) { _, _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onAppear {
                            scrollToBottom(proxy: proxy)
                        }

                        topBlendGradient
                    }
                }

                if companion.modelAvailability.isAvailable {
                    inputBar
                } else {
                    unavailableNotice
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            Task { await companion.refreshContext() }
        }
    }

    // MARK: - Header

    private var companionHeader: some View {
        VStack(spacing: 6) {
            CompanionFaceView(
                emotion: companion.currentMessage?.emotion ?? .idle,
                size: 56,
                assetPrefix: companion.personality.assetPrefix,
                fallbackEmoji: companion.personality.fallbackEmoji
            )
            Text(companion.displayName)
                .font(.headline)
        }
    }

    // MARK: - Top blend

    private var topBlendGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color(uiColor: .systemBackground).opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 24)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage, index: Int) -> some View {
        if let uuid = message.suggestedTaskUUID,
           let name = message.suggestedTaskName,
           message.persistentModelID == companion.mostRecentSuggestedTask?.persistentModelID {
            suggestionRow(uuid: uuid, name: name)
        }
        chatBubbleRow(message, index: index)
    }

    @ViewBuilder
    private func chatBubbleRow(_ message: ChatMessage, index: Int) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .companion {
                CompanionFaceView(
                    emotion: message.emotion ?? .happy,
                    size: 28,
                    assetPrefix: companion.personality.assetPrefix,
                    fallbackEmoji: companion.personality.fallbackEmoji
                )
            }

            Text(message.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.sender == .user
                        ? Color.accentColor
                        : Color(uiColor: .secondarySystemBackground)
                )
                .foregroundStyle(message.sender == .user ? .white : .primary)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: message.sender == .user ? .trailing : .leading
                )

            if message.sender == .user {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: message.sender == .user ? .trailing : .leading)

        if shouldShowSeparator(at: index) {
            Text(separatorText(at: index))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func suggestionRow(uuid: UUID, name: String) -> some View {
        HStack(spacing: 0) {
            Button {
                companion.requestStartTask(uuid)
                dismiss()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("Start task")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\"\(name)\"")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(.leading, 12)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Separators

    private func shouldShowSeparator(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let previous = companion.chatHistory[index - 1].timestamp
        let current = companion.chatHistory[index].timestamp
        return !Calendar.current.isDate(previous, inSameDayAs: current)
            || current.timeIntervalSince(previous) > 2 * 60 * 60
    }

    private func separatorText(at index: Int) -> String {
        let previous = companion.chatHistory[index - 1].timestamp
        let current = companion.chatHistory[index].timestamp
        if !Calendar.current.isDate(previous, inSameDayAs: current) {
            return RelativeDateTimeFormatter().localizedString(for: current, relativeTo: Date())
        }
        return DateFormatter.localizedString(from: current, dateStyle: .none, timeStyle: .short)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Say something to \(companion.displayName)…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($inputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty || companion.isGenerating ? Color.secondary : Color.accentColor)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || companion.isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }

    private var unavailableNotice: some View {
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
        .background(Color(uiColor: .systemBackground))
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !companion.isGenerating else { return }
        inputText = ""
        companion.chat(trimmed)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicatorRow: View {
    let assetPrefix: String
    let fallbackEmoji: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            CompanionFaceView(
                emotion: .thinking,
                size: 28,
                assetPrefix: assetPrefix,
                fallbackEmoji: fallbackEmoji
            )

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(.secondary)
                        .opacity(reduceMotion ? 1.0 : 0.4)
                        .scaleEffect(reduceMotion ? 1.0 : 0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview {
    let service = CompanionService.shared
    service.chatHistory = [
        ChatMessage(sender: .companion, text: "Ready to make today count?", emotion: "encouraging"),
        ChatMessage(sender: .user, text: "I have a lot to do today"),
        ChatMessage(sender: .companion, text: "One step at a time. You've got this!", emotion: "encouraging"),
        ChatMessage(
            sender: .companion,
            text: "Nice work! Want to keep going?",
            emotion: "happy",
            suggestedTaskUUID: UUID(),
            suggestedTaskName: "Review Q3 report"
        )
    ]
    return CompanionChatView(companion: service)
}
