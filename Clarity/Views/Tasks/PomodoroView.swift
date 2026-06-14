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
    MoodOption(label: .proud,      emoji: "😤", title: "Proud",      valence:  0.8),
    MoodOption(label: .happy,      emoji: "😄", title: "Happy",      valence:  0.7),
    MoodOption(label: .satisfied,  emoji: "😌", title: "Satisfied",  valence:  0.5),
    MoodOption(label: .calm,       emoji: "😶", title: "Calm",       valence:  0.3),
    MoodOption(label: .relieved,   emoji: "😮‍💨", title: "Relieved",   valence:  0.4),
    MoodOption(label: .stressed,   emoji: "😓", title: "Stressed",   valence: -0.4),
    MoodOption(label: .anxious,    emoji: "😰", title: "Anxious",    valence: -0.5),
    MoodOption(label: .discouraged,emoji: "😞", title: "Discouraged",valence: -0.7),
]

// MARK: - Main view

struct PomodoroView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var service: PomodoroService = .shared
    @EnvironmentObject var appState: AppState

    // Mood sheet state — set when a session finishes
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
                        RecentSessionsList(sessions: service.recentSessions)
                    }
                }
                .padding()
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingMoodSheet) {
            if let session = pendingMoodSession {
                MoodPickerSheet(session: session) {
                    pendingMoodSession = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { _ in
            // Surface the mood sheet for the most recently completed session
            if let latest = service.recentSessions.first {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    SessionRow(session: session)
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
            Text(timeAgo)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Mood picker sheet

struct MoodPickerSheet: View {
    let session: PomodoroService.CompletedSession
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood: MoodOption? = nil
    @State private var isSaving = false

    private let columns = [
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
                            isSelected: selectedMood?.id == mood.id
                        ) {
                            selectedMood = mood
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    if UserDefaults.healthKitEnabled {
                        Button {
                            saveAndDismiss()
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "heart.fill")
                                    Text("Save to Health")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(selectedMood != nil ? Color.accentColor : Color.secondary.opacity(0.3))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        }
                        .disabled(selectedMood == nil || isSaving)
                    }

                    Button("Skip") {
                        onDismiss()
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
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

    private func saveAndDismiss() {
        guard let mood = selectedMood else { return }
        isSaving = true
        Task {
            await HealthKitService.shared.logStateOfMind(
                label: mood.label,
                valence: mood.valence,
                date: session.endTime
            )
            isSaving = false
            onDismiss()
            dismiss()
        }
    }
}

private struct MoodButton: View {
    let mood: MoodOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(mood.emoji)
                    .font(.system(size: 32))
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
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PomodoroView()
        .modelContainer(PreviewData.shared.previewContainer)
        .environmentObject(AppState())
}
#endif
