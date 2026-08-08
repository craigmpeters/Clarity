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
                ForEach(habits) { habit in
                    WatchHabitPage(habit: habit, occurrence: store.occurrence(for: habit.uuid)) {
                        store.logHabitProgress(habit)
                    }
                    .tag(habit.uuid as UUID?)
                }
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle(selectedHabit?.name ?? "Habits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: ContentView()) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
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
    let onIncrement: () -> Void

    var body: some View {
        ZStack {
            WatchHabitArtworkBackground(filename: habit.artworkFilename)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(habit.streakFreezes)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progressFraction)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.2), value: progressFraction)
                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.largeTitle.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(width: 100, height: 100)

                Text(HabitFormatter.progressDescription(amount: occurrence?.currentAmount ?? 0, target: habit.dailyTarget, unit: habit.unitLabel))
                    .font(.subheadline)

                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var progressFraction: Double {
        let current = occurrence?.currentAmount ?? habit.currentAmount
        return min(current / max(habit.dailyTarget, 1), 1.0)
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
                .overlay(.regularMaterial.opacity(0.7))
        }
    }

    private func loadCGImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
