// CompanionSidebarView.swift
// Left-hand sidebar used on regular-width layouts (iPad, foldable Duo).
// Hosts the companion (face + chat), a "Today" summary, and quick habit logging.
import SwiftData
import SwiftUI

struct CompanionSidebarView: View {
    @Environment(\.modelContext) private var context
    @Environment(CompanionService.self) private var companion
    @FocusState private var inputFocused: Bool
    @State private var flashMessageID: PersistentIdentifier? = nil

    private var draftBinding: Binding<String> {
        Binding(
            get: { companion.chatDraft },
            set: { companion.chatDraft = $0 }
        )
    }

    // Live data for the Today summary + habit quick-log section.
    @Query(sort: \ToDoTask.completedAt, order: .reverse)
    private var allCompletedTasks: [ToDoTask]

    @Query(filter: #Predicate<Habit> { !$0.isArchived })
    private var activeHabits: [Habit]

    @State private var store: ClarityModelActor? = nil
    @State private var todayOccurrences: [UUID: HabitOccurrenceDTO] = [:]
    @State private var habitDTOs: [UUID: HabitDTO] = [:]

    private let bottomID = "sidebar-bottom"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        todaySummarySection
                        Divider().padding(.vertical, 4)
                        habitQuickLogSection

                        if !companion.chatHistory.isEmpty {
                            Divider().padding(.vertical, 4)
                            chatSection
                        }

                        Color.clear.frame(height: 1).id(bottomID)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: companion.chatHistory.count) { _, _ in
                    if let last = companion.chatHistory.last,
                       last.sender == .companion,
                       companion.isVisible {
                        let id = last.persistentModelID
                        flashMessageID = id
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.2))
                            if flashMessageID == id {
                                flashMessageID = nil
                            }
                        }
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            Divider()
            if companion.modelAvailability.isAvailable {
                inputBar
            }
        }
        .task {
            if store == nil {
                store = await ClarityModelActorFactory.makeBackground(container: context.container)
            }
            await refreshHabitOccurrences()
        }
        .onChange(of: activeHabits) { _, _ in
            Task { await refreshHabitOccurrences() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            CompanionFaceView(
                emotion: companion.currentMessage?.emotion ?? .idle,
                size: 40,
                assetPrefix: companion.personality.assetPrefix,
                fallbackEmoji: companion.personality.fallbackEmoji
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(companion.displayName)
                    .font(.headline)
                Text("Today at a glance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Today summary

    private var todayCompletedTaskCount: Int {
        let calendar = Calendar.current
        return allCompletedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }.count
    }

    private var todayCompletedHabitCount: Int {
        todayOccurrences.values.filter(\.completed).count
    }

    private var todaySummarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                summaryPill(
                    icon: "checkmark.circle.fill",
                    title: todayCompletedTaskCount == 1 ? "1 task" : "\(todayCompletedTaskCount) tasks",
                    tint: .accentColor
                )
                summaryPill(
                    icon: "flame.fill",
                    title: todayCompletedHabitCount == 1 ? "1 habit" : "\(todayCompletedHabitCount) habits",
                    tint: .orange
                )
            }
        }
    }

    private func summaryPill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }

    // MARK: - Habits quick log

    private var habitQuickLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Habits")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if activeHabits.isEmpty {
                Text("No active habits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activeHabits, id: \.persistentModelID) { habit in
                    let dto = habitDTOs[habit.uuid] ?? HabitDTO(from: habit)
                    let occurrence = todayOccurrences[habit.uuid]
                    SidebarHabitRow(
                        habit: dto,
                        occurrence: occurrence,
                        onIncrement: { logHabit(dto) }
                    )
                }
            }
        }
    }

    // MARK: - Chat transcript

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conversation")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(companion.chatHistory.enumerated()), id: \.offset) { _, message in
                chatRow(message)
            }

            if companion.isGenerating {
                ChatTypingIndicatorRow(
                    assetPrefix: companion.personality.assetPrefix,
                    fallbackEmoji: companion.personality.fallbackEmoji
                )
            }
        }
    }

    @ViewBuilder
    private func chatRow(_ message: ChatMessage) -> some View {
        if message.sender == .event {
            EventDividerRow(text: message.text, timestamp: message.timestamp)
        } else {
            let isFlashing = flashMessageID == message.persistentModelID
            HStack(alignment: .bottom, spacing: 6) {
                if message.sender == .companion {
                    CompanionFaceView(
                        emotion: message.emotion ?? .happy,
                        size: 24,
                        assetPrefix: companion.personality.assetPrefix,
                        fallbackEmoji: companion.personality.fallbackEmoji
                    )
                }
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        message.sender == .user
                            ? Color.accentColor
                            : (isFlashing
                                ? Color.accentColor.opacity(0.25)
                                : Color(uiColor: .secondarySystemBackground))
                    )
                    .foregroundStyle(message.sender == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(
                        maxWidth: .infinity,
                        alignment: message.sender == .user ? .trailing : .leading
                    )
                    .animation(.easeInOut(duration: 0.25), value: isFlashing)
                if message.sender == .user {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.sender == .user ? .trailing : .leading)
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Say something…", text: draftBinding, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .focused($inputFocused)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        companion.chatDraft.trimmingCharacters(in: .whitespaces).isEmpty || companion.isGenerating
                            ? Color.secondary
                            : Color.accentColor
                    )
            }
            .disabled(companion.chatDraft.trimmingCharacters(in: .whitespaces).isEmpty || companion.isGenerating)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }

    private func send() {
        let trimmed = companion.chatDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !companion.isGenerating else { return }
        companion.chatDraft = ""
        companion.chat(trimmed)
    }

    // MARK: - Habit actions

    private func logHabit(_ habit: HabitDTO) {
        guard let store else { return }
        Task {
            do {
                let dto: HabitOccurrenceDTO
                if habit.healthKitIdentifier != nil {
                    dto = try await store.logHabitProgressWithHealthKit(habit.uuid)
                } else {
                    dto = try await store.logHabitProgress(habit.uuid)
                }
                if dto.completed {
                    companion.recordEvent("Habit completed: \(habit.name)")
                    companion.triggerHabitCompleted(habit: habit, completedOccurrence: dto)
                }
                await refreshHabitOccurrences()
            } catch {
                LogManager.shared.log.error("Sidebar logHabit failed: \(error)")
            }
        }
    }

    private func refreshHabitOccurrences() async {
        guard let store else { return }
        do {
            let habits = try await store.fetchHabits()
            let calendar = HabitStreakCalculator.streakCalendar()
            let now = Date()
            let today = calendar.startOfDay(for: now)
            var newOccurrences: [UUID: HabitOccurrenceDTO] = [:]
            var newDTOs: [UUID: HabitDTO] = [:]
            for habit in habits where !habit.isArchived {
                let history = try await store.fetchHabitHistory(
                    habit.uuid,
                    from: today,
                    to: now
                )
                if let todayOccurrence = history.first(where: { calendar.isDate($0.periodStart, inSameDayAs: now) }) {
                    newOccurrences[habit.uuid] = todayOccurrence
                }
                newDTOs[habit.uuid] = habit
            }
            await MainActor.run {
                todayOccurrences = newOccurrences
                habitDTOs = newDTOs
            }
        } catch {
            LogManager.shared.log.error("Sidebar refreshHabitOccurrences failed: \(error)")
        }
    }
}

// MARK: - Sidebar habit row

private struct SidebarHabitRow: View {
    let habit: HabitDTO
    let occurrence: HabitOccurrenceDTO?
    let onIncrement: () -> Void

    private var currentAmount: Double { occurrence?.currentAmount ?? 0 }
    private var progress: Double { min(currentAmount / max(habit.dailyTarget, 1), 1.0) }
    private var isCompleted: Bool { occurrence?.completed ?? false }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onIncrement) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isCompleted ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Image(systemName: isCompleted ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isCompleted ? Color.green : Color.accentColor)
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log progress for \(habit.name)")

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.subheadline)
                    .strikethrough(isCompleted, color: .secondary)
                Text(
                    HabitFormatter.progressDescription(
                        amount: currentAmount,
                        target: habit.dailyTarget,
                        unit: habit.unitLabel,
                        healthKitIdentifier: habit.healthKitIdentifier
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onIncrement)
    }
}

#Preview {
    CompanionSidebarView()
        .modelContainer(PreviewData.shared.previewContainer)
        .environment(CompanionService.shared)
}

#Preview("Sidebar — Narrow + AX5") {
    CompanionSidebarView()
        .modelContainer(PreviewData.shared.previewContainer)
        .environment(CompanionService.shared)
        .frame(width: 300)
        .dynamicTypeSize(.accessibility5)
}

#Preview("Sidebar — Min Width") {
    CompanionSidebarView()
        .modelContainer(PreviewData.shared.previewContainer)
        .environment(CompanionService.shared)
        .frame(width: 300, height: 800)
}
