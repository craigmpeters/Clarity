//
//  SwipeActionsDemoView.swift
//  Clarity
//
//  Created by AI Assistant on 07/09/2025.
//

import SwiftUI

struct SwipeActionsDemoView: View {
    @State private var currentDemoIndex = 0
    @State private var showingInstructions = true
    
    private let swipeActions = [
        SwipeActionDemo(
            title: "Start Pomodoro Timer",
            subtitle: "Swipe right to begin focus session",
            direction: .right,
            color: .blue,
            icon: "timer",
            description: "Quick access to start your focused work session"
        ),
        SwipeActionDemo(
            title: "Mark Complete",
            subtitle: "Swipe right to finish task",
            direction: .right,
            color: .green,
            icon: "checkmark",
            description: "Mark tasks as done with a simple gesture"
        ),
        SwipeActionDemo(
            title: "Delete Task",
            subtitle: "Swipe left to remove",
            direction: .left,
            color: .red,
            icon: "trash",
            description: "Remove tasks you no longer need"
        )
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            // Instructions
            VStack(spacing: 8) {
                Text("Essential Gestures")
                    .font(.title2.bold())
                
                Text("Learn these powerful swipe actions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Demo area
            VStack(spacing: 24) {
                // Current action description
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: swipeActions[currentDemoIndex].icon)
                            .foregroundStyle(swipeActions[currentDemoIndex].color)
                            .font(.title2)
                        
                        Text(swipeActions[currentDemoIndex].title)
                            .font(.headline)
                    }
                    
                    Text(swipeActions[currentDemoIndex].description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Interactive demo task
                InteractiveTaskDemo(
                    action: swipeActions[currentDemoIndex],
                    onActionTriggered: nextDemo
                )
                
                // Progress indicators
                HStack(spacing: 8) {
                    ForEach(0..<swipeActions.count, id: \.self) { index in
                        Circle()
                            .fill(currentDemoIndex == index ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: currentDemoIndex)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            
            // Auto-advance hint
            Text("Try the gesture or wait to see the next one")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32)
        .onAppear {
            startAutoAdvance()
        }
    }
    
    private func nextDemo() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentDemoIndex = (currentDemoIndex + 1) % swipeActions.count
        }
        
        // Continue auto-advance after user interaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            startAutoAdvance()
        }
    }
    
    private func startAutoAdvance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            nextDemo()
        }
    }
}

struct SwipeActionDemo {
    let title: String
    let subtitle: String
    let direction: SwipeDirection
    let color: Color
    let icon: String
    let description: String
    
    enum SwipeDirection {
        case left, right
    }
}

struct InteractiveTaskDemo: View {
    let action: SwipeActionDemo
    let onActionTriggered: () -> Void
    let exampleTask = ToDoTask(
        name: "Sample Task",
        pomodoro: true,
        pomodoroTime: TimeInterval(10 * 60),
        repeating: true,
        recurrenceInterval: .daily,
        categories: [Category(name: "Work", color: .Blue, weeklyTarget: 8)].compactMap { $0 }
    )
    
    @State private var offset: CGFloat = 0
    @State private var hasTriggered = false
    @State private var showingHint = false
    
    var body: some View {
        ZStack {
            // Background actions
            HStack {
                if action.direction == .right {
                    // Show action on the left when swiping right
                    Rectangle()
                        .fill(action.color)
                        .overlay(
                            Image(systemName: action.icon)
                                .font(.title2)
                                .foregroundStyle(.white)
                        )
                    Spacer()
                } else {
                    // Show action on the right when swiping left
                    Spacer()
                    Rectangle()
                        .fill(action.color)
                        .overlay(
                            Image(systemName: action.icon)
                                .font(.title2)
                                .foregroundStyle(.white)
                        )
                }
            }
            
            // Task row
            // FIXME: Preview Tasks, Generic?
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text(exampleTask.due, format: .dateTime.day())
                                .font(.title3.weight(.bold))
                            Text(exampleTask.due, format: .dateTime.month(.abbreviated))
                                .font(.caption2.weight(.semibold))
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(dateAccentTextColor(exampleTask.due))
                        .frame(width: 56, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(dateAccentBackgroundColor(exampleTask.due))
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exampleTask.name ?? "")
                                .font(.headline)
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                if exampleTask.categories?.count ?? 0 >= 3 {
                                    ForEach(exampleTask.categories!) { category in
                                        ZStack {
                                            Circle()
                                                .fill(category.color?.SwiftUIColor ?? .gray)
                                                .frame(width: 25, height: 25)
                                            Text(String(category.name!.first!))
                                                .textCase(.uppercase)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.black)
                                                .blendMode(.colorBurn)
                                        }
                                        .clipShape(Circle())
                                    }
                                } else {
                                    ForEach(exampleTask.categories!) { category in
                                        Text(category.name!)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(category.color?.SwiftUIColor ?? .gray.opacity(0.2))
                                            )
                                            .foregroundStyle(category.color!.contrastingTextColor)
                                    }
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    //RecurrenceIndicatorBadge(task: task)
                                    //TimerIndicatorBadge(task: task)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                }

                // Animated swipe hint
                if showingHint {
                    HStack {
                        if action.direction == .right {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(action.color)
                            Text(action.subtitle)
                                .font(.caption2)
                                .foregroundStyle(action.color)
                            Spacer()
                        } else {
                            Spacer()
                            Text(action.subtitle)
                                .font(.caption2)
                                .foregroundStyle(action.color)
                            Image(systemName: "arrow.left")
                                .font(.caption)
                                .foregroundStyle(action.color)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: action.direction == .right ? .leading : .trailing)))
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        
                        // Constrain swipe direction and limit distance
                        if action.direction == .left && translation < 0 {
                            offset = max(translation, -100)
                        } else if action.direction == .right && translation > 0 {
                            offset = min(translation, 100)
                        }
                        
                        // Trigger action if swiped far enough
                        let threshold: CGFloat = 60
                        if !hasTriggered && abs(offset) > threshold {
                            hasTriggered = true
                            triggerAction()
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            offset = 0
                        }
                        hasTriggered = false
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            showSwipeHint()
        }
        .onChange(of: action.title) { _, _ in
            // Reset state when action changes
            offset = 0
            hasTriggered = false
            showingHint = false
            
            // Show hint for new action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSwipeHint()
            }
        }
    }
    
    private func showSwipeHint() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showingHint = true
        }
        
        // Auto-demonstrate after showing hint
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            demonstrateSwipe()
        }
        
        // Hide hint after demonstration
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingHint = false
            }
        }
    }
    
    private func demonstrateSwipe() {
        let targetOffset: CGFloat = action.direction == .left ? -70 : 70
        
        withAnimation(.easeInOut(duration: 1)) {
            offset = targetOffset
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                offset = 0
            }
        }
    }
    
    private func triggerAction() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Visual feedback
        withAnimation(.easeOut(duration: 0.2)) {
            offset = 0
        }
        
        // Notify parent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onActionTriggered()
        }
    }
}

#Preview {
    SwipeActionsDemoView()
        .padding()
}
