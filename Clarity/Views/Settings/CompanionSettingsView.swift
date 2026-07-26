// CompanionSettingsView.swift
// Settings for the companion

import SwiftUI

struct CompanionSettingsView: View {
    @State private var companionEnabled = UserDefaults.companionEnabled
    @State private var companionName = UserDefaults.companionName
    @State private var showingStore = false

    @State private var companion = CompanionService.shared
    @Environment(Store.self) private var store

    private var freePersonalities: [any CompanionPersonality] {
        CompanionService.allPersonalities.filter { !$0.requiresPremium }
    }

    private var premiumPersonalities: [any CompanionPersonality] {
        CompanionService.allPersonalities.filter { $0.requiresPremium }
    }

    var body: some View {
        Form {
            // MARK: Header preview
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        CompanionFaceView(
                            emotion: companionEnabled ? .happy : .idle,
                            size: 100,
                            assetPrefix: companion.personality.assetPrefix,
                            fallbackEmoji: companion.personality.fallbackEmoji
                        )
                        Text(companion.displayName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            // MARK: Enable + rename
            Section("Companion") {
                Toggle(isOn: $companionEnabled) {
                    HStack {
                        Image(systemName: "otter")
                            .foregroundColor(.brown)
                        Text("Enable Companion")
                    }
                }
                .onChange(of: companionEnabled) { _, value in
                    UserDefaults.companionEnabled = value
                }

                if companionEnabled {
                    HStack {
                        Image(systemName: "character.cursor.ibeam")
                            .foregroundColor(.orange)
                        TextField("Companion Name", text: $companionName)
                            .autocorrectionDisabled()
                    }
                    .onChange(of: companionName) {
                        UserDefaults.companionName = companionName
                        companion.clearHistory()
                    }
                }
            }

            // MARK: Character picker
            if companionEnabled {
                Section("Character") {
                    ForEach(freePersonalities, id: \.id) { p in
                        personalityRow(p)
                            .onTapGesture { selectPersonality(p) }
                    }
                }

                if !premiumPersonalities.isEmpty {
                    Section(header: Text("Premium"), footer: Text("Requires Clarity Premium.")) {
                        ForEach(premiumPersonalities, id: \.id) { p in
                            personalityRow(p)
                                .onTapGesture {
                                    if store.hasBoughtPremium {
                                        selectPersonality(p)
                                    } else {
                                        showingStore = true
                                    }
                                }
                        }
                    }
                }

                // MARK: Apple Intelligence status
                Section("Apple Intelligence") {
                    if companion.modelAvailability.isAvailable {
                        Label("Apple Intelligence active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Apple Intelligence unavailable", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                            Text(companion.modelAvailability.userFacingReason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if companion.modelAvailability == .appleIntelligenceNotEnabled {
                                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("About") {
                    Text("Your companion uses Apple Intelligence (on-device) to offer personalised encouragement, habit suggestions, and emotional support based on your activity. All processing happens privately on your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        companion.clearHistory()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Conversation History")
                        }
                    }
                }
            }
        }
        .navigationTitle("Companion")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: companion.personality.id) { _, _ in
            // Sync name field when personality changes (selectPersonality resets it)
            companionName = UserDefaults.companionName
        }
        .sheet(isPresented: $showingStore) {
            NavigationStack {
                PremiumSettings()
                    .navigationTitle("Clarity Premium")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingStore = false }
                        }
                    }
            }
        }
    }

    // MARK: - Personality row

    @ViewBuilder
    private func personalityRow(_ p: any CompanionPersonality) -> some View {
        let isSelected = companion.personality.id == p.id
        let isLocked = p.requiresPremium && !store.hasBoughtPremium

        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                CompanionFaceView(emotion: .idle, size: 48, assetPrefix: p.assetPrefix, fallbackEmoji: p.fallbackEmoji)
                    .opacity(isLocked ? 0.5 : 1)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.secondary, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading) {
                Text(p.displayName)
                if isSelected {
                    Text("Selected").font(.caption).foregroundStyle(.secondary)
                } else if isLocked {
                    Text("Premium required").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark").foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Selection

    private func selectPersonality(_ p: any CompanionPersonality) {
        companion.selectPersonality(p)
        // companionName state is synced via .onChange(of: companion.personality.id)
    }
}

#Preview {
    NavigationStack {
        CompanionSettingsView()
    }
}
