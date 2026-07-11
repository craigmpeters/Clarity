// CompanionSpriteView.swift
// Displays the otter companion for a given emotion.
//
// To replace the placeholder with a real image, add a PNG to companion.xcassets
// using the asset name for the emotion (see `assetName` below) and it will be
// picked up automatically. The image should be square and at least 256×256 px.

import SwiftUI

struct CompanionSpriteView: View {
    let emotion: CompanionEmotion
    let size: CGFloat

    // MARK: - Asset name per emotion
    // Add a matching image to companion.xcassets to replace the emoji placeholder.
    private var assetName: String {
        switch emotion {
        case .idle:        return "otter_idle"
        case .thinking:    return "otter_thinking"
        case .happy:       return "otter_happy"
        case .encouraging: return "otter_encouraging"
        case .loving:      return "otter_loving"
        case .caring:      return "otter_caring"
        case .determined:  return "otter_determined"
        }
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
                Text("🦦")
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

    var body: some View {
        CompanionSpriteView(emotion: emotion, size: size)
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
