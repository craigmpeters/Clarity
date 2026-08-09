//
//  ChatMessage.swift
//  Clarity
//
//  Companion chat message model. Stored in an app-target-only SwiftData container.
//

import Foundation
import SwiftData

enum ChatSender: String, Codable, Sendable {
    case user
    case companion
}

@Model
final class ChatMessage {
    var timestamp: Date = Date()
    var senderRaw: String = ChatSender.companion.rawValue
    var text: String = ""
    var emotionRaw: String? = nil
    var suggestedTaskUUID: UUID? = nil
    var suggestedTaskName: String? = nil

    init(
        timestamp: Date = Date(),
        sender: ChatSender,
        text: String,
        emotion: String? = nil,
        suggestedTaskUUID: UUID? = nil,
        suggestedTaskName: String? = nil
    ) {
        self.timestamp = timestamp
        self.senderRaw = sender.rawValue
        self.text = text
        self.emotionRaw = emotion
        self.suggestedTaskUUID = suggestedTaskUUID
        self.suggestedTaskName = suggestedTaskName
    }
}

extension ChatMessage {
    var sender: ChatSender {
        ChatSender(rawValue: senderRaw) ?? .companion
    }

    var emotion: CompanionEmotion? {
        guard let emotionRaw else { return nil }
        return CompanionEmotion(rawValue: emotionRaw)
    }
}
