import SwiftUI
import SwiftData

struct HabitsIndexView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @State private var habitDTOs: [HabitDTO] = []
    @State private var occurrences: [UUID: HabitOccurrenceDTO] = [:]
    @State private var weekOccurrences: [UUID: [HabitOccurrenceDTO]] = [:]
    @State private var streaks: [UUID: HabitStreakResult] = [:]
    @State private var showingForm = false
    @State private var editingHabit: HabitDTO? = nil
    @State private var loggingHabit: HabitDTO? = nil
    @State private var generatingArtHabitIDs: Set<UUID> = []
    @State private var isImagePlaygroundAvailable: Bool = false
    @State private var habitToDelete: HabitDTO? = nil
    @State private var store: ClarityModelActor? = nil
    @Environment(CompanionService.self) private var companion

    var body: some View {
        List {
            if !atRiskHabits.isEmpty {
                    Section("Streak at Risk") {
                        ForEach(atRiskHabits, id: \.uuid) { habit in
                            HabitRowView(
                                habit: habit,
                                occurrence: occurrences[habit.uuid],
                                weekOccurrences: weekOccurrences[habit.uuid] ?? [],
                                streak: streaks[habit.uuid] ?? HabitStreakResult(current: 0, longest: 0, freezesEarned: 0, atRisk: false, missedPeriod: nil),
                                onIncrement: { increment(habit) },
                                onLogAmount: { loggingHabit = habit },
                                onEdit: { editingHabit = habit },
                                onArchive: { archive(habit) },
                                onDelete: { habitToDelete = habit },
                                onCompleteAnyway: { completeAnyway(habit) },
                                onUseFreeze: { useFreeze(habit) },
                                onGenerateArt: { generateArt(habit) },
                                isGeneratingArt: generatingArtHabitIDs.contains(habit.uuid),
                                isImagePlaygroundAvailable: isImagePlaygroundAvailable
                            )
                        }
                    }
                }

                Section("Today") {
                    ForEach(todayHabits, id: \.uuid) { habit in
                        HabitRowView(
                            habit: habit,
                            occurrence: occurrences[habit.uuid],
                            weekOccurrences: weekOccurrences[habit.uuid] ?? [],
                            streak: streaks[habit.uuid] ?? HabitStreakResult(current: 0, longest: 0, freezesEarned: 0, atRisk: false, missedPeriod: nil),
                            onIncrement: { increment(habit) },
                            onLogAmount: { loggingHabit = habit },
                            onEdit: { editingHabit = habit },
                            onArchive: { archive(habit) },
                            onDelete: { habitToDelete = habit },
                                onCompleteAnyway: { completeAnyway(habit) },
                                onUseFreeze: { useFreeze(habit) },
                                onGenerateArt: { generateArt(habit) },
                                isGeneratingArt: generatingArtHabitIDs.contains(habit.uuid),
                                isImagePlaygroundAvailable: isImagePlaygroundAvailable
                            )

                    }
                }
            }
        .navigationTitle("Habits")
        .accessibilityIdentifier("habit-list")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("habit-add")
            }
        }

            .refreshable { await refresh() }
            .task {
                if store == nil {
                    store = await ClarityModelActorFactory.makeBackground(container: modelContext.container)
                }
                await refresh()
            }
            .sheet(isPresented: $showingForm) {
                HabitWizardView()
            }
            .sheet(item: $editingHabit) { habit in
                HabitFormView(habit: habit)
            }
            .sheet(item: $loggingHabit) { habit in
                LogHabitAmountSheet(habit: habit, initialAmount: occurrences[habit.uuid]?.currentAmount ?? 0) { amount in
                    setAmount(habit, amount: amount)
                }
            }
            .onChange(of: habits) { _, _ in
                Task { await refresh() }
            }
            .task {
                if store == nil {
                    store = await ClarityModelActorFactory.makeBackground(container: modelContext.container)
                }
                await refresh()
                checkImagePlaygroundAvailability()
                let synced = await HabitHealthKitSync.shared.syncAllHabits()
                for dto in synced where dto.completed {
                    if let habit = habitDTOs.first(where: { $0.uuid == dto.habitUUID }) {
                        companion.triggerHabitCompleted(habit: habit, completedOccurrence: dto)
                    }
                }
                await refresh()
            }
            .refreshable {
                await refresh()
                let synced = await HabitHealthKitSync.shared.syncAllHabits()
                for dto in synced where dto.completed {
                    if let habit = habitDTOs.first(where: { $0.uuid == dto.habitUUID }) {
                        companion.triggerHabitCompleted(habit: habit, completedOccurrence: dto)
                    }
                }
                await refresh()
            }
            .confirmationDialog(
                "Delete Habit?",
                isPresented: Binding(
                    get: { habitToDelete != nil },
                    set: { if !$0 { habitToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let habit = habitToDelete {
                        delete(habit)
                    }
                    habitToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    habitToDelete = nil
                }
            } message: {
                if let habit = habitToDelete {
                    Text("Are you sure you want to delete \"\(habit.name)\"? This cannot be undone.")
                }
            }
    }

    private var activeHabits: [HabitDTO] {
        habitDTOs.filter { !$0.isArchived }
    }

    private var atRiskHabits: [HabitDTO] {
        activeHabits.filter { streaks[$0.uuid]?.atRisk ?? false }
    }

    private var todayHabits: [HabitDTO] {
        activeHabits.filter { !(streaks[$0.uuid]?.atRisk ?? false) }
    }

    private func refresh() async {
        guard let store = store else { return }
        do {
            let fetched = try await store.fetchHabits()
            await MainActor.run {
                habitDTOs = fetched
            }
            try await withThrowingTaskGroup(of: (UUID, HabitOccurrenceDTO?, [HabitOccurrenceDTO], HabitStreakResult).self) { group in
                for habit in fetched {
                    group.addTask {
                        let calendar = HabitStreakCalculator.streakCalendar()
                        let now = Date()
                        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                        let history = try await store.fetchHabitHistory(habit.uuid, from: weekStart, to: now)
                        let today = history.first { calendar.isDate($0.periodStart, inSameDayAs: now) }
                        let allHistory = try await store.fetchHabitHistory(habit.uuid, from: Date.distantPast, to: now)
                        let streak = HabitStreakCalculator.streak(occurrences: allHistory, frequency: habit.weeklyFrequency, freezes: habit.streakFreezes)
                        return (habit.uuid, today, history, streak)
                    }
                }
                for try await (uuid, today, history, streak) in group {
                    await MainActor.run {
                        occurrences[uuid] = today
                        weekOccurrences[uuid] = history
                        streaks[uuid] = streak
                    }
                }
            }
        } catch {
            LogManager.shared.log.error("Failed to refresh habits: \(error)")
        }
    }

    private func increment(_ habit: HabitDTO) {
        guard let store = store else { return }
        Task {
            do {
                let dto: HabitOccurrenceDTO
                if habit.healthKitIdentifier != nil {
                    dto = try await store.logHabitProgressWithHealthKit(habit.uuid)
                } else {
                    dto = try await store.logHabitProgress(habit.uuid)
                }
                if dto.completed {
                    companion.triggerHabitCompleted(habit: habit, completedOccurrence: dto)
                }
                await refresh()
            } catch {
                LogManager.shared.log.error("Failed to increment habit: \(error)")
            }
        }
    }

    private func setAmount(_ habit: HabitDTO, amount: Double) {
        guard let store = store else { return }
        Task {
            do {
                let dto = try await store.setHabitProgress(habit.uuid, date: Date(), amount: amount)
                if dto.completed {
                    companion.triggerHabitCompleted(habit: habit, completedOccurrence: dto)
                }
                await refresh()
            } catch {
                LogManager.shared.log.error("Failed to set habit amount: \(error)")
            }
        }
    }

    private func completeAnyway(_ habit: HabitDTO) {
        setAmount(habit, amount: habit.dailyTarget)
    }

    private func useFreeze(_ habit: HabitDTO) {
        guard let store = store else { return }
        Task {
            do {
                try await store.spendFreeze(habit.uuid)
                await refresh()
            } catch {
                LogManager.shared.log.error("Failed to spend freeze: \(error)")
            }
        }
    }

    private func archive(_ habit: HabitDTO) {
        guard let store = store else { return }
        Task {
            do {
                try await store.archiveHabit(habit.uuid)
                await refresh()
            } catch {
                LogManager.shared.log.error("Failed to archive habit: \(error)")
            }
        }
    }

    private func delete(_ habit: HabitDTO) {
        guard let store = store else { return }
        Task {
            do {
                try await store.deleteHabit(habit.uuid)
                await refresh()
            } catch {
                LogManager.shared.log.error("Failed to delete habit: \(error)")
            }
        }
    }

    private func checkImagePlaygroundAvailability() {
        #if os(iOS) && canImport(ImagePlayground)
        if #available(iOS 26.0, *) {
            isImagePlaygroundAvailable = HabitArtService().isAvailable
        } else {
            isImagePlaygroundAvailable = false
        }
        #else
        isImagePlaygroundAvailable = false
        #endif
    }

    private func generateArt(_ habit: HabitDTO) {
        #if os(iOS) && canImport(ImagePlayground)
        guard #available(iOS 26.0, *) else { return }
        Task { @MainActor in
            generatingArtHabitIDs.insert(habit.uuid)
            defer { generatingArtHabitIDs.remove(habit.uuid) }
            do {
                let service = HabitArtService()
                let url = try await service.generate(for: habit)
                saveArtwork(url, for: habit)
            } catch {
                LogManager.shared.log.error("Failed to generate habit art: \(error)")
            }
        }
        #endif
    }

    private func saveArtwork(_ url: URL, for habit: HabitDTO) {
        guard let store = store else { return }
        Task { @MainActor in
            do {
                guard let filename = try WidgetFileCoordinator.shared.copyArtwork(from: url, for: habit.uuid) else {
                    LogManager.shared.log.error("Failed to copy artwork to app group")
                    return
                }
                _ = try await store.updateHabitArtwork(habit.uuid, filename: filename)
                #if os(iOS)
                PhoneConnectivityCoordinator.shared.transferHabitArtwork(filename: filename, for: habit.uuid)
                #endif
                await refresh()
            } catch {
                LogManager.shared.log.error("Failed to save artwork: \(error)")
            }
        }
    }
}

struct LogHabitAmountSheet: View {
    let habit: HabitDTO
    let initialAmount: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount for \(habit.name)") {
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Log Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(amount)
                        dismiss()
                    }
                }
            }
            .onAppear {
                amount = initialAmount
            }
        }
    }
}
