// CompanionSpriteView.swift
// Displays the companion sprite for a given emotion.
//
// To add a real image, add a PNG to companion.xcassets using the name
// "\(assetPrefix)_\(emotion.rawValue)" (e.g. "otter_idle") and it will be
// picked up automatically. The image should be square and at least 256×256 px.

import SwiftUI

struct CompanionSpriteView: View {
    let emotion: CompanionEmotion
    let size: CGFloat
    var assetPrefix: String = "otter"
    var fallbackEmoji: String = "🦦"

    private var assetName: String {
        "\(assetPrefix)_\(emotion.rawValue)"
    }

    var body: some View {
        if let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Emoji placeholder — replaced automatically when asset is added
            ZStack {
                Circle()
                    .fill(Color.brown.opacity(0.15))
                Text(fallbackEmoji)
                    .font(.system(size: size * 0.6))
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Face (sprite + white circle + black border)

struct CompanionFaceView: View {
    let emotion: CompanionEmotion
    let size: CGFloat
    var assetPrefix: String = "otter"
    var fallbackEmoji: String = "🦦"

    var body: some View {
        CompanionSpriteView(emotion: emotion, size: size, assetPrefix: assetPrefix, fallbackEmoji: fallbackEmoji)
            .background(Circle().fill(.white))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black, lineWidth: 2))
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            CompanionFaceView(emotion: .idle, size: 80)
            CompanionFaceView(emotion: .thinking, size: 80)
            CompanionFaceView(emotion: .happy, size: 80)
        }
        HStack(spacing: 16) {
            CompanionFaceView(emotion: .encouraging, size: 80)
            CompanionFaceView(emotion: .loving, size: 80)
            CompanionFaceView(emotion: .caring, size: 80)
        }
        HStack(spacing: 16) {
            CompanionFaceView(emotion: .determined, size: 80)
        }
    }
    .padding()
}
