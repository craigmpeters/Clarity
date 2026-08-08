//
//  HabitArtService.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation
import SwiftUI
import Combine
#if os(iOS) && canImport(ImagePlayground)
import ImagePlayground
#endif
import XCGLogger

#if os(iOS) && canImport(ImagePlayground)
@available(iOS 26.0, *)
@MainActor
final class HabitArtService: ObservableObject {
    @Published var isPresenting = false

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

    func viewController(for habit: HabitDTO, onComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void) -> ImagePlaygroundViewController {
        let controller = ImagePlaygroundViewController()
        controller.allowedGenerationStyles = [.illustration, .sketch]
        controller.concepts = concepts(for: habit)
        controller.delegate = HabitArtDelegate(habit: habit, onComplete: onComplete, onCancel: onCancel)
        return controller
    }
}

@available(iOS 26.0, *)
private final class HabitArtDelegate: NSObject, ImagePlaygroundViewController.Delegate {
    let habit: HabitDTO
    let onComplete: (URL) -> Void
    let onCancel: () -> Void

    init(habit: HabitDTO, onComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.habit = habit
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    func imagePlaygroundViewController(_ controller: ImagePlaygroundViewController, didCreateImageAt url: URL) {
        onComplete(url)
    }

    func imagePlaygroundViewControllerDidCancel(_ controller: ImagePlaygroundViewController) {
        onCancel()
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
