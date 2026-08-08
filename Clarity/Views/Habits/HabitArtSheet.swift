//
//  HabitArtSheet.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import SwiftUI
#if os(iOS) && canImport(ImagePlayground)
import ImagePlayground
#endif

#if os(iOS) && canImport(ImagePlayground)
@available(iOS 26.0, *)
struct HabitArtSheet: UIViewControllerRepresentable {
    let habit: HabitDTO
    let onComplete: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> ImagePlaygroundViewController {
        let controller = ImagePlaygroundViewController()
        controller.allowedGenerationStyles = [.illustration, .sketch]
        controller.concepts = [
            .text("minimalist soft gradient illustration"),
            .text(habit.name),
            .text(habit.unitLabel ?? "habit")
        ]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ImagePlaygroundViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, ImagePlaygroundViewController.Delegate {
        let onComplete: (URL) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
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
}
#endif
