//
//  HabitArtService.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
#if os(iOS) && canImport(ImagePlayground)
import ImagePlayground
#endif
import XCGLogger

#if os(iOS) && canImport(ImagePlayground)
@available(iOS 26.0, *)
@MainActor
final class HabitArtService {
    var isAvailable: Bool {
        ImagePlaygroundViewController.isAvailable
    }

    func concepts(for habit: HabitDTO) -> [ImagePlaygroundConcept] {
        [
            .text("minimalist soft gradient illustration"),
            .text(habit.name),
            .text(habit.unitLabel ?? "habit")
        ]
    }

    func prompt(for habit: HabitDTO) -> String {
        "minimalist soft gradient illustration of \(habit.name), calm and focused"
    }

    /// Generates a habit artwork on-device in the background using the ImagePlayground programmatic API.
    /// Returns a file URL to the generated PNG in a temporary directory. The caller is responsible for
    /// copying it to the App Group artwork directory via `WidgetFileCoordinator.copyArtwork`.
    func generate(for habit: HabitDTO) async throws -> URL {
        guard isAvailable else { throw HabitArtError.unavailable }

        let concepts = concepts(for: habit)
        let generator = try await ImageCreator()
        let iterator = generator.images(for: concepts, style: .illustration, limit: 1)

        for try await image in iterator {
            let cgImage = image.cgImage
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
                throw HabitArtError.saveFailed(underlying: NSError(domain: "HabitArtService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination"]))
            }
            CGImageDestinationAddImage(destination, cgImage, nil)
            if !CGImageDestinationFinalize(destination) {
                throw HabitArtError.saveFailed(underlying: NSError(domain: "HabitArtService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not finalize PNG"]))
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
            try data.write(to: url)
            return url
        }

        throw HabitArtError.saveFailed(underlying: NSError(domain: "HabitArtService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No image generated"]))
    }
}
#endif

enum HabitArtError: Error, Sendable {
    case unavailable
    case cancelled
    case missingHabit
    case saveFailed(underlying: Error)

    var localizedDescription: String {
        switch self {
        case .unavailable: return "Image Playground is not available on this device."
        case .cancelled: return "Image generation was cancelled."
        case .missingHabit: return "Habit not found."
        case .saveFailed(let error): return "Failed to save artwork: \(error.localizedDescription)"
        }
    }
}
