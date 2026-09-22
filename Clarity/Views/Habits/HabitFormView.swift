import SwiftUI
import SwiftData

struct HabitFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var store: ClarityModelActor? = nil
    @State private var state = HabitFormState()

    var habit: HabitDTO? = nil

    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var showError = false

    var body: some View {
        let isEditing = habit != nil
        NavigationStack {
            Form {
                if isEditing {
                    typeReadOnlySection
                } else {
                    typeSelectionSection
                }

                Section("Habit Name") {
                    TextField("e.g. Drink Water", text: $state.name)
                }

                Section("Unit") {
                    if state.habitType == .health {
                        if !state.availableUnits.isEmpty {
                            Picker("Unit", selection: $state.unitLabel) {
                                ForEach(state.availableUnits, id: \.self) { unit in
                                    Text(unit).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    } else {
                        TextField("e.g. glasses, pages, minutes", text: $state.unitLabel)
                    }
                }

                Section {
                    HStack {
                        Text("Increment size")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("Amount", value: $state.incrementStep, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        .onChange(of: state.incrementStep) { _, newValue in
                            let upper = min(HabitConfig.maxIncrementStep, HabitConfig.dailyTargetRange(for: state.healthKitIdentifier).upperBound)
                            state.incrementStep = max(min(newValue, upper), HabitConfig.incrementStepRange.lowerBound)
                            state.didEditIncrement = true
                        }
                        Text(state.displayUnit)
                            .foregroundColor(.secondary)
                    }

                HStack {
                    Text("Number of increments")
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            state.incrementCount = max(state.incrementCount - 1, 1)
                            state.didEditCount = true
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 24, height: 24)
                        }
                        .disabled(state.incrementCount <= 1)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Text("\(state.incrementCount)")
                            .monospacedDigit()
                            .frame(minWidth: 24)

                        Button {
                            state.incrementCount += 1
                            state.didEditCount = true
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                    HStack {
                        Text("Total daily target")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(state.formattedTotal)
                            .fontWeight(.semibold)
                    }
                } header: {
                    Text("Daily Amount")
                }

                Section("Days per Week") {
                    Stepper(value: $state.weeklyFrequency, in: 1...7) {
                        Text("^[\(state.weeklyFrequency) days](inflect: true)")
                    }
                }

                Section("Categories") {
                    CategorySelectionView(selectedCategories: $state.selectedCategories)
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
                        .disabled(!state.isValid || isSaving)
                }
            }
            .alert("Save Failed", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(saveError ?? "Unknown error")
            }
            .task {
                if store == nil {
                    store = await StoreRegistry.shared.store(for: modelContext.container)
                }
                if let habit = habit {
                    state.load(habit: habit)
                }
            }
        }
    }

    private func save() {
        guard let store = store else { return }
        isSaving = true
        let dto = state.makeDTO(existing: habit)
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

    private var typeReadOnlySection: some View {
        Section("Type") {
            HStack {
                Image(systemName: state.habitType.localizedIcon)
                    .foregroundColor(state.habitType == .health ? .red : .accentColor)
                    .frame(width: 24)
                Text(state.habitType.localizedTitle)
                    .font(.headline)
                Spacer()
            }

            if let option = state.selectedHealthKitTypeOption {
                HStack {
                    Image(systemName: option.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text(option.title)
                        .font(.headline)
                    Spacer()
                }
            }
        }
    }

    private var typeSelectionSection: some View {
        Section("Type") {
            Picker("Type", selection: $state.habitType) {
                ForEach(HabitFormState.HabitType.allCases) { option in
                    Label(option.localizedTitle, systemImage: option.localizedIcon).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: state.habitType) { _, newValue in
                if newValue == .nonHealth {
                    state.healthKitIdentifier = nil
                } else if state.healthKitIdentifier == nil {
                    state.healthKitIdentifier = state.healthKitOptions.first
                    state.applyHealthKitDefaultsIfNeeded()
                }
            }

            if state.habitType == .health {
                Picker("HealthKit Type", selection: $state.healthKitIdentifier) {
                    ForEach(state.healthKitTypeOptions) { option in
                        Label(option.title, systemImage: option.icon).tag(option.id as String?)
                    }
                }
                .onChange(of: state.healthKitIdentifier) { _, newValue in
                    HabitHealthKitSync.shared.requestAuthorizationIfNeeded(for: newValue)
                    state.applyHealthKitDefaultsIfNeeded()
                }
            }
        }
    }
}

