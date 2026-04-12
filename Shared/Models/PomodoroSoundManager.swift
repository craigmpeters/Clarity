#if !os(watchOS)
import AudioToolbox
@preconcurrency import AVFoundation
import Combine
import Foundation

/// Manages custom Pomodoro alarm sounds: validation, conversion, storage, and preview.
@MainActor
final class PomodoroSoundManager: ObservableObject {
    static let shared = PomodoroSoundManager()

    private var audioPlayer: AVAudioPlayer?

    // Maximum allowed duration in seconds for a notification sound
    static let maxDurationSeconds: Double = 30

    // MARK: Library Sounds Directory

    /// Returns the app's `Library/Sounds` directory, creating it if necessary.
    func librarySoundsURL() -> URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let sounds = library.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: sounds.path) {
            try? FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        }
        return sounds
    }

    // MARK: Save Custom Sound

    enum SoundError: LocalizedError {
        case tooLong(Double)
        case conversionFailed(String)
        case unreadable

        var errorDescription: String? {
            switch self {
            case .tooLong(let seconds):
                return "The audio file is \(Int(seconds.rounded())) seconds long. Notification sounds must be 30 seconds or shorter."
            case .conversionFailed(let reason):
                return "Could not convert audio: \(reason)"
            case .unreadable:
                return "The audio file could not be read."
            }
        }
    }

    /// Validates, converts if needed, and saves a user-provided audio file to `Library/Sounds`.
    /// Returns the saved `.caf` filename on success.
    func saveCustomSound(from sourceURL: URL) async throws -> String {
        // Access the security-scoped resource
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        // 1. Check duration
        let asset = AVURLAsset(url: sourceURL)
        let duration: Double
        do {
            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)
        } catch {
            throw SoundError.unreadable
        }

        guard duration.isFinite && duration <= Self.maxDurationSeconds else {
            throw SoundError.tooLong(duration.isFinite ? duration : 31)
        }

        // 2. Determine destination filename (.m4a — supported by UNNotificationSound)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let safeName = baseName
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).inverted)
            .joined(separator: "_")
        let destFilename = "\(safeName.isEmpty ? "custom_sound" : safeName).m4a"
        let destURL = librarySoundsURL().appendingPathComponent(destFilename)

        // 3. Export to AAC .m4a using AVAssetExportSession.
        //    UNNotificationSound(named:) supports .m4a (AAC), .wav, .aiff, and .caf.
        //    Using .m4a avoids all manual PCM conversion and works with any input format.
        try? FileManager.default.removeItem(at: destURL)

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw SoundError.conversionFailed("Could not create export session")
        }

        do {
            try await exporter.export(to: destURL, as: .m4a)
        } catch {
            throw SoundError.conversionFailed(error.localizedDescription)
        }

        return destFilename
    }

    // MARK: Delete Custom Sound

    func deleteCustomSound(filename: String) {
        let url = librarySoundsURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Preview

    func previewSound(_ sound: PomodoroAlarmSound) {
        audioPlayer?.stop()
        audioPlayer = nil

        switch sound {
        case .default:
            // Play the system notification sound
            AudioServicesPlaySystemSound(1007)
        case .preset(let name):
            playBundledSound(named: "pomodoro_\(name)", withExtension: "caf")
        case .custom(let filename):
            let url = librarySoundsURL().appendingPathComponent(filename)
            playAudioFile(at: url)
        }
    }

    private func playBundledSound(named name: String, withExtension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        playAudioFile(at: url)
    }

    private func playAudioFile(at url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("PomodoroSoundManager: Failed to play sound: \(error.localizedDescription)")
        }
    }

    func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
#endif
