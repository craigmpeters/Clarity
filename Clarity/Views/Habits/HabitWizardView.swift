import SwiftUI
import SwiftData

struct HabitWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var store: ClarityModelActor? = nil
    @State private var state = HabitFormState()
    @State private var step: Step = .type
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var showError = false

    private enum Step: Int, CaseIterable {
        case type = 1
        case amount = 2
        case schedule = 3
        case finish = 4

        var title: String {
            switch self {
            case .type: return "Type"
            case .amount: return "Amount"
            case .schedule: return "Schedule"
            case .finish: return "Ready"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .type:
                    typeStep
                case .amount:
                    amountStep
                case .schedule:
                    scheduleStep
                case .finish:
                    finishStep
                }
            }
            .navigationTitle("New Habit — \(step.rawValue) / \(Step.allCases.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .finish {
                        Button("Save") { save() }
                            .disabled(!state.isValid || isSaving)
                            .accessibilityIdentifier("habit-wizard-save")
                    } else {
                        Button("Next") { advance() }
                            .accessibilityIdentifier("habit-wizard-next")
                    }
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
            }
        }
    }

    private var typeStep: some View {
        Group {
            Section("Is this a Health habit?") {
                ForEach(HabitFormState.HabitType.allCases) { option in
                    Button {
                        state.habitType = option
                        if option == .nonHealth {
                            state.healthKitIdentifier = nil
                        } else if state.healthKitIdentifier == nil {
                            state.healthKitIdentifier = state.healthKitOptions.first
                            state.applyHealthKitDefaultsIfNeeded()
                        }
                    } label: {
                        HStack {
                            Image(systemName: option.localizedIcon)
                                .foregroundColor(option == .health ? .red : .accentColor)
                                .frame(width: 24)
                            Text(option.localizedTitle)
                                .font(.headline)
                            Spacer()
                            if state.habitType == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .listRowBackground(state.habitType == option ? Color.accentColor.opacity(0.1) : Color.clear)
                }
            }
            .listRowSeparator(.hidden)

            if state.habitType == .health {
                Section("Supported Health types") {
                    ForEach(state.healthKitTypeOptions) { option in
                        Button {
                            state.healthKitIdentifier = option.id
                            HabitHealthKitSync.shared.requestAuthorizationIfNeeded(for: option.id)
                            state.applyHealthKitDefaultsIfNeeded()
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.headline)
                                    Text(option.id.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if state.healthKitIdentifier == option.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                        .listRowBackground(state.healthKitIdentifier == option.id ? Color.accentColor.opacity(0.1) : Color.clear)
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
    }

    private var amountStep: some View {
        Group {
            Section("Habit Name") {
                    TextField("e.g. Drink Water", text: $state.name)
                        .accessibilityIdentifier("habit-wizard-name")

            }

            Section("Unit") {
                if state.habitType == .health, let option = state.selectedHealthKitTypeOption {
                    HStack {
                        Image(systemName: option.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text(option.title)
                            .font(.headline)
                        Spacer()
                        Text(option.id.capitalized)
                            .foregroundColor(.secondary)
                    }

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
            } header: {
                Text("Daily Amount")
            }
        }
    }

    private var scheduleStep: some View {
        Group {
            Section("Days per Week") {
                Stepper(value: $state.weeklyFrequency, in: 1...7) {
                    Text("^[\(state.weeklyFrequency) days](inflect: true)")
                }
            }

            Section("Categories") {
                CategorySelectionView(selectedCategories: $state.selectedCategories)
            }
        }
    }

    private var finishStep: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Name")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(state.name)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Type")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(state.habitType.localizedTitle)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Daily target")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(state.formattedTotal)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Increment")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("+\(HabitFormatter.formatted(state.incrementStep)) \(state.displayUnit)")
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Days per week")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("^[\(state.weeklyFrequency) days](inflect: true)")
                        .fontWeight(.semibold)
                }
                if let option = state.selectedHealthKitTypeOption {
                    HStack {
                        Text("HealthKit")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(option.title)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func save() {
        guard let store = store else { return }
        isSaving = true
        let dto = state.makeDTO(existing: nil)
        Task {
            do {
                _ = try await store.addHabit(dto)
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
