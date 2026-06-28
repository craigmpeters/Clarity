//
//  PremiumSettings.swift
//  Clarity
//
//  Created by Craig Peters on 04/05/2026.
//

import SwiftUI
import StoreKit

struct PremiumSettings: View {
    @Environment(Store.self) private var store: Store

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                    .padding(.bottom, 32)

                featuresSection
                    .padding(.horizontal)
                    .padding(.bottom, 32)

                disclaimerSection
                    .padding(.horizontal)
                    .padding(.bottom, 24)

                if store.hasBoughtPremium {
                    alreadyOwnedBadge
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                } else {
                    storeSection
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Clarity Premium")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Image("Appicon-Preview-Premium")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    .padding(.top, 48)

                Text("Clarity Premium")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("A little thank-you for those who want to show their support.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's included")
                .font(.title3.bold())
                .padding(.bottom, 4)

            FeatureRow(
                icon: "paintbrush.fill",
                color: .purple,
                title: "Exclusive App Icons",
                description: "Unlock a premium app icon to personalise your home screen."
            )

            FeatureRow(
                icon: "heart.fill",
                color: .pink,
                title: "Support Development",
                description: "Help keep Clarity independent and ad-free."
            )

            FeatureRow(
                icon: "sparkles",
                color: .orange,
                title: "More to Come",
                description: "Premium perks will grow over time as new ones are added."
            )
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Everything is free")
                    .font(.subheadline.bold())
                Text("All core functionality in Clarity — tasks, categories, Pomodoro, widgets, and everything else — is completely free. Premium is purely cosmetic and entirely optional.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Store

    private var storeSection: some View {
        StoreView(ids: ProductID.all) { _ in
            Image("Appicon-Preview-Premium")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .productViewStyle(.large)
        .storeButton(.hidden, for: .cancellation)
        .storeButton(.visible, for: .restorePurchases)
        .frame(minHeight: 200)
    }

    // MARK: - Already owned

    private var alreadyOwnedBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're a Premium supporter")
                    .font(.subheadline.bold())
                Text("Thank you for your support!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Supporting views

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .font(.callout.bold())
                .frame(width: 34, height: 34)
                .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PremiumSettings()
            .environment(Store())
    }
}
