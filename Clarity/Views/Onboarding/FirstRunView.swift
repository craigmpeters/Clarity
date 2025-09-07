//
//  FirstRunView.swift
//  Clarity
//
//  Created by AI Assistant on 07/09/2025.
//

import SwiftUI

struct FirstRunView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            title: "Welcome to Clarity",
            subtitle: "Your focused productivity companion",
            systemImage: "brain.head.profile",
            description: "Break down complex tasks, stay focused with Pomodoro timers, and track your progress with beautiful insights."
        ),
        OnboardingPage(
            title: "Swipe to Take Action",
            subtitle: "Powerful gestures at your fingertips",
            systemImage: "hand.tap",
            description: "Learn the essential swipe gestures that make managing your tasks lightning-fast."
        ),
        OnboardingPage(
            title: "Ready to Focus",
            subtitle: "Let's get started!",
            systemImage: "target",
            description: "Create your first task and begin your journey to better productivity."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 32) {
                        Spacer()
                        
                        // Icon
                        Image(systemName: page.systemImage)
                            .font(.system(size: 80, weight: .light))
                            .foregroundStyle(.blue.gradient)
                            .accessibilityLabel(page.title)
                        
                        VStack(spacing: 16) {
                            Text(page.title)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            
                            Text(page.subtitle)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text(page.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        // Special content for swipe demo page
                        if index == 1 {
                            SwipeActionsDemoView()
                                .padding(.top, 16)
                        }
                        
                        Spacer()
                    }
                    .tag(index)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(page.title). \(page.subtitle). \(page.description)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            // Bottom controls
            VStack(spacing: 24) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(currentPage + 1) of \(pages.count)")
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Go to previous page")
                    }
                    
                    Spacer()
                    
                    Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                        if currentPage == pages.count - 1 {
                            // Mark onboarding as complete and dismiss
                            UserDefaults.hasCompletedOnboarding = true
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint(currentPage == pages.count - 1 ? "Complete onboarding and start using the app" : "Go to next page")
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Announce the onboarding experience for VoiceOver users
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIAccessibility.post(notification: .announcement, argument: "Welcome to Clarity onboarding. Swipe left or right to navigate, or use the Next button.")
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let systemImage: String
    let description: String
}

#Preview {
    FirstRunView()
}
