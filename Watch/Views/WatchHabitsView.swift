//
//  WatchHabitsView.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
//

import SwiftUI
import ImageIO

struct WatchHabitsView: View {
    @State private var store = WatchSnapshotStore.shared
    @State private var selectedHabitUUID: UUID? = nil

    var habits: [HabitDTO] {
        store.snapshot.habits.filter { !$0.isArchived }
    }

    var selectedHabit: HabitDTO? {
        guard let selectedHabitUUID = selectedHabitUUID else { return habits.first }
        return habits.first { $0.uuid == selectedHabitUUID } ?? habits.first
    }

    var body: some View {
        NavigationStack {
            TabView(selection: selectedTabBinding) {
                ForEach(habits, id: \.uuid) { habit in
                    WatchHabitPage(
                        habit: habit,
                        occurrence: store.occurrence(for: habit.uuid),
                        isOptimisticallyIncremented: store.isHabitOptimisticallyIncremented(habit.uuid)
                    ) {
                        store.logHabitProgress(habit)
                    }
                    .tag(habit.uuid as UUID?)
                }
            }
            .tabViewStyle(.verticalPage)
//            .navigationTitle(selectedHabit?.name ?? "Habits")
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    NavigationLink(destination: ContentView()) {
//                        Image(systemName: "list.bullet")
//                    }
//                }
//            }
            .overlay {
                if habits.isEmpty {
                    ContentUnavailableView("No Habits", systemImage: "checklist", description: Text("Add habits on your iPhone"))
                }
            }
        }
    }

    private var selectedTabBinding: Binding<UUID?> {
        Binding(
            get: { selectedHabitUUID ?? habits.first?.uuid },
            set: { selectedHabitUUID = $0 }
        )
    }
}

struct WatchHabitPage: View {
    let habit: HabitDTO
    let occurrence: HabitOccurrenceDTO?
    let isOptimisticallyIncremented: Bool
    let onIncrement: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Text(habit.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .allowsTightening(true)

                Text(HabitFormatter.progressDescription(amount: effectiveAmount, target: habit.dailyTarget, unit: habit.unitLabel, healthKitIdentifier: habit.healthKitIdentifier))
                    .font(.subheadline)

                HStack(spacing: 4) {
                    ForEach(Array(habit.weekCompletionBitmap.enumerated()), id: \.offset) { index, completed in
                        Circle()
                            .fill(completed ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .accessibilityLabel(dotAccessibilityLabel(index: index, completed: completed))
                    }
                }
                .accessibilityLabel("Recent progress: \(habit.weekCompletionBitmap.filter(\.self).count) of last 7 days completed")
            }

            .padding(8)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    onIncrement()
                } label: {
                    Image(systemName: isOptimisticallyIncremented ? "checkmark" : "plus")
                }
                .controlSize(.extraLarge)
                .background(.blue, in: Capsule())
                .disabled(isOptimisticallyIncremented)
                .accessibilityLabel("Log progress for \(habit.name)")
                .accessibilityHint("Adds \(HabitFormatter.formatted(habit.incrementStep)) to today's amount")
            }
        }
    }

    private var effectiveAmount: Double {
        let base = occurrence?.currentAmount ?? habit.currentAmount
        if isOptimisticallyIncremented {
            return min(base + habit.incrementStep, habit.dailyTarget)
        }
        return base
    }

    private var progressFraction: Double {
        let current = effectiveAmount
        return min(current / max(habit.dailyTarget, 1), 1.0)
    }

    /// The bitmap is a rolling 7-day window: index 0 is 6 days ago, index 6 is today.
    private func dotAccessibilityLabel(index: Int, completed: Bool) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: index - 6, to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: day)
        return completed ? "\(dayName): completed" : "\(dayName): not completed"
    }
}

struct WatchHabitArtworkBackground: View {
    let filename: String?

    var body: some View {
        if let filename = filename,
           let url = WidgetFileCoordinator.shared.habitArtworkURL(filename: filename),
           let cgImage = loadCGImage(from: url) {
            Image(decorative: cgImage, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            Color.clear
        }
    }

    private func loadCGImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
