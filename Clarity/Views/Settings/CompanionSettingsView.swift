// CompanionSettingsView.swift
// Settings for the otter companion

import SwiftUI

struct CompanionSettingsView: View {
    @State private var companionEnabled = UserDefaults.companionEnabled
    @State private var companionName = UserDefaults.companionName

    @State private var companion = CompanionService.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        CompanionFaceView(
                            emotion: companionEnabled ? .happy : .idle,
                            size: 100
                        )
                        Text(companionName.isEmpty ? "Otto" : companionName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

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
                        UserDefaults.companionName = companionName.isEmpty ? "Otto" : companionName
                        companion.clearHistory()
                    }
                }
            }

            if companionEnabled {
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
    }
}

#Preview {
    NavigationStack {
        CompanionSettingsView()
    }
}
