import SwiftUI
import SwiftData

struct HabitFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var store: ClarityModelActor? = nil
    @StateObject private var suggestionService = HabitSuggestionService()

    var habit: HabitDTO? = nil

    @State private var name: String = ""
    @State private var unitLabel: String = ""
    @State private var dailyTarget: Double = 1
    @State private var incrementStep: Double = 1
    @State private var weeklyFrequency: Int = 7
    @State private var selectedCategories: [CategoryDTO] = []
    @State private var healthKitIdentifier: String? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var showError = false
    @State private var didEditUnit = false
    @State private var didEditTarget = false
    @State private var didEditIncrement = false
    @State private var suggestionTask: Task<Void, Never>? = nil

    private let healthKitOptions = ["None", "water", "steps", "workouts", "mindful"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Name") {
                    TextField("e.g. Drink Water", text: $name)
                        .onChange(of: name) { _, _ in
                            requestSuggestion()
                        }

                    if suggestionService.isProcessing {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Spacer()
                        }
                    } else if let suggestion = suggestionService.currentSuggestion {
                        Button {
                            applySuggestion(suggestion)
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text(suggestionChipText(for: suggestion))
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Unit") {
                    TextField("e.g. glasses, pages, minutes", text: $unitLabel)
                        .onChange(of: unitLabel) { _, _ in didEditUnit = true }
                }

                Section("Daily Target") {
                    HStack {
                        TextField("Target", value: $dailyTarget, format: .number)
                            .keyboardType(.decimalPad)
                            .onChange(of: dailyTarget) { _, newValue in
                                dailyTarget = clampedTarget(newValue)
                                didEditTarget = true
                            }
                        Stepper(value: $dailyTarget, in: HabitConfig.dailyTargetRange, step: 1) { EmptyView() }
                    }
                }

                Section("Increment Step") {
                    Stepper(value: $incrementStep, in: HabitConfig.incrementStepRange, step: 0.5) {
                        Text("\(incrementStep, specifier: "%.1f")")
                    }
                    .onChange(of: incrementStep) { _, _ in didEditIncrement = true }
                }

                Section("Days per Week") {
                    Stepper(value: $weeklyFrequency, in: 1...7) {
                        Text("\(weeklyFrequency) day\(weeklyFrequency == 1 ? "" : "s")")
                    }
                }

                Section("Categories") {
                    CategorySelectionView(selectedCategories: $selectedCategories)
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .alert("Save Failed", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(saveError ?? "Unknown error")
            }
            .task {
                if store == nil {
                    store = await ClarityModelActorFactory.makeBackground(container: modelContext.container)
                }
                if let habit = habit {
                    name = habit.name
                    unitLabel = habit.unitLabel ?? ""
                    dailyTarget = habit.dailyTarget
                    incrementStep = habit.incrementStep
                    weeklyFrequency = habit.weeklyFrequency
                    selectedCategories = habit.categories
                    healthKitIdentifier = habit.healthKitIdentifier
                    didEditUnit = true
                    didEditTarget = true
                    didEditIncrement = true
                }
            }
        }
    }

    private func suggestionChipText(for suggestion: HabitSuggestionService.Suggestion) -> String {
        let target = HabitFormatter.formatted(suggestion.dailyTarget)
        let step = HabitFormatter.formatted(suggestion.incrementStep)
        return "Suggested: \(target) \(suggestion.unitLabel), +\(step)"
    }

    private func applySuggestion(_ suggestion: HabitSuggestionService.Suggestion) {
        if !didEditUnit || unitLabel.isEmpty {
            unitLabel = suggestion.unitLabel
        }
        if !didEditTarget || dailyTarget == 1 {
            dailyTarget = suggestion.dailyTarget
        }
        if !didEditIncrement || incrementStep == 1 {
            incrementStep = suggestion.incrementStep
        }
        suggestionService.clear()
    }

    private func requestSuggestion() {
        suggestionTask?.cancel()
        let currentName = name
        guard habit == nil else { return }
        suggestionTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await suggestionService.suggest(for: currentName)
        }
    }

    private func clampedTarget(_ value: Double) -> Double {
        min(max(value, HabitConfig.dailyTargetRange.lowerBound), HabitConfig.dailyTargetRange.upperBound)
    }

    private func save() {
        guard let store = store else { return }
        isSaving = true
        suggestionTask?.cancel()
        let trimmedUnit = unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let dto = HabitDTO(
            id: habit?.id,
            uuid: habit?.uuid ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            unitLabel: trimmedUnit.isEmpty ? nil : trimmedUnit,
            dailyTarget: clampedTarget(dailyTarget),
            incrementStep: incrementStep,
            weeklyFrequency: weeklyFrequency,
            healthKitIdentifier: healthKitIdentifier,
            categories: selectedCategories
        )
        Task {
            do {
                if habit == nil {
                    _ = try await store.addHabit(dto)
                } else {
                    _ = try await store.updateHabit(dto)
                }
                await MainActor.run { dismiss() }
            } catch {
                LogManager.shared.log.error("Failed to save habit: \(error)")
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run {
                    saveError = message
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}
