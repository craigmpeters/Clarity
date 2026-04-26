import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct PomodoroSoundSettingsView: View {
    @StateObject private var soundManager = PomodoroSoundManager.shared
    @State private var selectedSoundID: String = UserDefaults.pomodoroAlarmSoundID
    @State private var showingFilePicker = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isImporting = false

    private var selectedSound: PomodoroAlarmSound {
        PomodoroAlarmSound.from(persistenceID: selectedSoundID)
    }

    private var customFilename: String? {
        if case .custom(let filename) = selectedSound { return filename }
        // Also check if there's any previously saved custom file that isn't selected
        return nil
    }

    // Find any saved custom sound in Library/Sounds
    private var savedCustomFilename: String? {
        let dir = PomodoroSoundManager.shared.librarySoundsURL()
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.first(where: { $0.hasSuffix(".m4a") || $0.hasSuffix(".caf") })
    }

    var body: some View {
        List {
            // MARK: Built-in Sounds
            Section {
                soundRow(.default)
                ForEach(PomodoroAlarmSound.allPresets, id: \.persistenceID) { sound in
                    soundRow(sound)
                }
            } header: {
                Text("Built-in Sounds")
            }

            // MARK: Custom Sound
            Section {
                if let filename = savedCustomFilename {
                    let customSound = PomodoroAlarmSound.custom(filename: filename)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(customSound.displayName)
                            Text("Custom")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedSoundID == customSound.persistenceID {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        select(customSound)
                    }

                    Button(role: .destructive) {
                        removeCustomSound(filename: filename)
                    } label: {
                        Label("Remove Custom Sound", systemImage: "trash")
                    }
                }

                Button {
                    showingFilePicker = true
                } label: {
                    Label(
                        savedCustomFilename == nil ? "Import Custom Sound" : "Replace Custom Sound",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .disabled(isImporting)
            } header: {
                Text("Custom Sound")
            } footer: {
                Text("Supported formats: MP3, AAC, WAV, AIFF, CAF. Maximum duration: 30 seconds. The file will be converted for use as a notification sound.")
            }
        }
        .navigationTitle("Pomodoro Sound")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.audio],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Failed", isPresented: $showingError) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Converting sound…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: Sound Row

    @ViewBuilder
    private func soundRow(_ sound: PomodoroAlarmSound) -> some View {
        HStack {
            Text(sound.displayName)
            Spacer()
            if selectedSoundID == sound.persistenceID {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            select(sound)
        }
    }

    // MARK: Actions

    private func select(_ sound: PomodoroAlarmSound) {
        selectedSoundID = sound.persistenceID
        UserDefaults.pomodoroAlarmSoundID = sound.persistenceID
        soundManager.previewSound(sound)
    }

    private func removeCustomSound(filename: String) {
        soundManager.deleteCustomSound(filename: filename)
        // If the deleted sound was selected, fall back to default
        if selectedSoundID == PomodoroAlarmSound.custom(filename: filename).persistenceID {
            select(.default)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            Task {
                do {
                    // Remove any existing custom sound first
                    if let existing = savedCustomFilename {
                        soundManager.deleteCustomSound(filename: existing)
                    }
                    let filename = try await soundManager.saveCustomSound(from: url)
                    await MainActor.run {
                        isImporting = false
                        let sound = PomodoroAlarmSound.custom(filename: filename)
                        select(sound)
                    }
                } catch {
                    await MainActor.run {
                        isImporting = false
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationStack {
        PomodoroSoundSettingsView()
    }
}
