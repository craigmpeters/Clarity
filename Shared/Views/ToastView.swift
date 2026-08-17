//
//  ToastView.swift
//  Clarity
//
//  Created by OpenCode on 02/08/2026.
//

import SwiftUI

/// A toast notification that appears briefly with an optional action button
struct ToastView: View {
  let message: String
  let actionLabel: String?
  let action: (() -> Void)?

  init(message: String, actionLabel: String? = nil, action: (() -> Void)? = nil) {
    self.message = message
    self.actionLabel = actionLabel
    self.action = action
  }

  var body: some View {
    HStack(spacing: 12) {
      Text(message)
        .font(.subheadline)
        .foregroundColor(.primary)

      if let actionLabel = actionLabel, let action = action {
        Spacer()
        Button(action: action) {
          Text(actionLabel)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.accentColor)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    .padding(.horizontal)
  }
}

/// View modifier for showing toast notifications
struct ToastModifier: ViewModifier {
  @Binding var isPresented: Bool
  let message: String
  let actionLabel: String?
  let action: (() -> Void)?
  let duration: TimeInterval

  @State private var dismissTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    ZStack(alignment: .bottom) {
      content

      if isPresented {
        ToastView(message: message, actionLabel: actionLabel, action: action)
          .padding(.bottom, 16)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .zIndex(1)
          .onAppear {
            scheduleDismissal()
          }
          .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
          }
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
  }

  private func scheduleDismissal() {
    dismissTask?.cancel()
    dismissTask = Task {
      try? await Task.sleep(for: .seconds(duration))
      await MainActor.run {
        withAnimation {
          isPresented = false
        }
      }
    }
  }
}

extension View {
  /// Shows a toast notification with an optional action button
  /// - Parameters:
  ///   - isPresented: Binding to control toast visibility
  ///   - message: The message to display
  ///   - actionLabel: Optional button label (e.g., "Undo")
  ///   - action: Optional action to perform when button is tapped
  ///   - duration: How long to show the toast (default: 5 seconds)
  func toast(
    isPresented: Binding<Bool>,
    message: String,
    actionLabel: String? = nil,
    action: (() -> Void)? = nil,
    duration: TimeInterval = 5
  ) -> some View {
    modifier(
      ToastModifier(
        isPresented: isPresented,
        message: message,
        actionLabel: actionLabel,
        action: action,
        duration: duration
      ))
  }
}

#if DEBUG
  #Preview("Toast without action") {
    VStack {
      Spacer()
    }
    .toast(
      isPresented: .constant(true),
      message: "Task completed"
    )
  }

  #Preview("Toast with Undo") {
    VStack {
      Spacer()
    }
    .toast(
      isPresented: .constant(true),
      message: "Task completed",
      actionLabel: "Undo"
    ) {
      print("Undo tapped")
    }
  }
#endif
