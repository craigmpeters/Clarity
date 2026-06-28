import ActivityKit
import HealthKit
import SwiftData
import SwiftUI

// MARK: - Mood option model

private struct MoodOption: Identifiable {
    let id = UUID()
    let label: HKStateOfMind.Label
    let emoji: String
    let title: String
    let valence: Double
}

private let moodOptions: [MoodOption] = [
    MoodOption(label: .excited,    emoji: "🤩", title: "Excited",    valence:  0.9),
    MoodOption(label: .happy,      emoji: "😄", title: "Happy",      valence:  0.7),
    MoodOption(label: .calm,       emoji: "😶", title: "Calm",       valence:  0.3),
    MoodOption(label: .stressed,   emoji: "😓", title: "Stressed",   valence: -0.4),
    MoodOption(label: .discouraged,emoji: "😞", title: "Discouraged",valence: -0.7),
]

// MARK: - Main view

struct PomodoroView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var service: PomodoroService
    @EnvironmentObject var appState: AppState
    @Environment(CompanionService.self) private var companion

    init(previewService: PomodoroService? = nil) {
        _service = StateObject(wrappedValue: previewService ?? .shared)
    }

    // Mood sheet state — set when a session finishes or when the user taps the row button
    @State private var pendingMoodSession: PomodoroService.CompletedSession? = nil
    @State private var showingMoodSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if service.isActive {
                        ActiveTimerCard(service: service)
                    } else {
                        IdleCard()
                    }

                    if !service.recentSessions.isEmpty {
                        RecentSessionsList(sessions: service.recentSessions) { session in
                            pendingMoodSession = session
                            showingMoodSheet = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingMoodSheet) {
            if let session = pendingMoodSession {
                MoodPickerSheet(session: session, onDismiss: {
                    pendingMoodSession = nil
                }, onMoodSaved: { valence, emoji in
                    service.markMoodLogged(for: session.id, emoji: emoji)
                    companion.trigger(.moodSelected(valence: valence, taskName: session.taskName))
                    if let taskUUID = session.taskUUID {
                        let store = ClarityModelActor(modelContainer: context.container)
                        Task {
                            try? await store.recordMood(valence: valence, taskUUID: taskUUID)
                        }
                    }
                })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { _ in
            // Surface the mood sheet for the most recently completed session
            if let latest = service.recentSessions.first {
                Task {
                    await companion.refreshContext()
                    companion.trigger(.pomodoroCompleted(taskName: latest.taskName))
                }
                pendingMoodSession = latest
                showingMoodSheet = true
            }
        }
    }
}

// MARK: - Active timer card

private struct ActiveTimerCard: View {
    @ObservedObject var service: PomodoroService

    var body: some View {
        VStack(spacing: 20) {
            Text(service.toDoTask?.name ?? "Pomodoro")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: service.progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: service.progress)

                Text(service.formattedTime)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
            }

            // Stop button
            Button {
                Task { await service.endPomodoro() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 18, weight: .medium))
                    Text("Stop Timer")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Idle card

private struct IdleCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No active session")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a Pomodoro from a task to begin focusing.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Recent sessions list

private struct RecentSessionsList: View {
    let sessions: [PomodoroService.CompletedSession]
    let onLogMood: (PomodoroService.CompletedSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    SessionRow(session: session, onLogMood: onLogMood)
                    if session.id != sessions.last?.id {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct SessionRow: View {
    let session: PomodoroService.CompletedSession
    let onLogMood: (PomodoroService.CompletedSession) -> Void

    private var duration: String {
        let secs = Int(session.endTime.timeIntervalSince(session.startTime))
        let m = secs / 60
        let s = secs % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.endTime, relativeTo: Date())
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(duration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let emoji = session.moodEmoji {
                Text(emoji)
                    .font(.system(size: 20))
                    .grayscale(1)
                    .opacity(0.5)
            } else {
                Button {
                    onLogMood(session)
                } label: {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Mood picker sheet

struct MoodPickerSheet: View {
    let session: PomodoroService.CompletedSession
    let onDismiss: () -> Void
    var onMoodSaved: ((Double, String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: MoodOption? = nil
    @State private var isSaving = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("How do you feel?")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You just finished \"\(session.taskName)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(moodOptions) { mood in
                        MoodButton(
                            mood: mood,
                            isSelected: selectedMood?.id == mood.id,
                            isSaving: isSaving
                        ) {
                            selectMood(mood)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button("Skip") {
                    onDismiss()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func selectMood(_ mood: MoodOption) {
        guard !isSaving else { return }
        selectedMood = mood
        if UserDefaults.healthKitEnabled {
            isSaving = true
            Task {
                await HealthKitService.shared.logStateOfMind(
                    label: mood.label,
                    valence: mood.valence,
                    date: session.endTime,
                    taskName: session.taskName
                )
                isSaving = false
                onMoodSaved?(mood.valence, mood.emoji)
                onDismiss()
                dismiss()
            }
        } else {
            onDismiss()
            dismiss()
        }
    }
}

private struct MoodButton: View {
    let mood: MoodOption
    let isSelected: Bool
    var isSaving: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Text(mood.emoji)
                        .font(.system(size: 32))
                        .opacity(isSelected && isSaving ? 0 : 1)
                    if isSelected && isSaving {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    }
                }
                Text(mood.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Idle") {
    PomodoroView()
        .modelContainer(PreviewData.shared.previewContainer)
        .environmentObject(AppState())
}

#Preview("Active Timer") {
    let service = PomodoroService.makePreview(
        taskName: "SwiftUI documentation reading",
        totalMinutes: 25,
        elapsedMinutes: 10
    )
    PomodoroView(previewService: service)
        .modelContainer(PreviewData.shared.previewContainer)
        .environmentObject(AppState())
}

#Preview("Mood Picker") {
    let session = PomodoroService.CompletedSession(
        id: UUID(),
        taskName: "SwiftUI documentation reading",
        taskUUID: nil,
        startTime: Date().addingTimeInterval(-25 * 60),
        endTime: Date()
    )
    MoodPickerSheet(session: session) {}
}
#endif
