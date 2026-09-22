// ChatRows.swift
// Reusable row views shared by CompanionChatView (sheet on compact) and
// CompanionSidebarView (left pane on regular-width layouts).

import SwiftUI

// MARK: - Event divider row

/// Centered, unobtrusive row used for system events like
/// "Task completed: Write report". Rendered inline in the chat transcript
/// but NOT sent to the LLM as part of the conversation context.
struct EventDividerRow: View {
    let text: String
    let timestamp: Date

    var body: some View {
        HStack(spacing: 8) {
            line
            VStack(spacing: 2) {
                Text(text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            line
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) at \(timestamp.formatted(date: .omitted, time: .shortened))")
    }

    private var line: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 1)
    }
}

// MARK: - Typing indicator

struct ChatTypingIndicatorRow: View {
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
