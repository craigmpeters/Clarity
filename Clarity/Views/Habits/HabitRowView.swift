import SwiftUI
import SwiftData

struct HabitRowView: View {
    let habit: HabitDTO
    let occurrence: HabitOccurrenceDTO?
    let recentOccurrences: [HabitOccurrenceDTO]
    let streak: HabitStreakResult
    let onIncrement: () -> Void
    let onLogAmount: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onCompleteAnyway: () -> Void
    let onUseFreeze: () -> Void
    let onGenerateArt: () -> Void
    var isGeneratingArt: Bool = false
    var isImagePlaygroundAvailable: Bool = false

    var body: some View {
        ZStack {
            HabitArtworkBackground(filename: habit.artworkFilename)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .font(.headline)
                        Text(periodDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(streak.current)")
                        .font(.subheadline.weight(.semibold))
                    if occurrence?.source == "healthkit" {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                            .accessibilityLabel("HealthKit linked")
                    }
                }
                }

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: progressFraction)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: progressFraction)
                        Button(action: onIncrement) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Log progress for \(habit.name)")
                        .accessibilityHint("Adds \(HabitFormatter.formatted(habit.incrementStep)) to today's amount")
                    }
                    .frame(width: 64, height: 64)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(periodDescription)

                    VStack(alignment: .leading, spacing: 6) {
                        WeeklyDotsView(habit: habit, recentOccurrences: recentOccurrences)
                        if streak.atRisk {
                            Button(action: onUseFreeze) {
                                Label("Use Freeze", systemImage: "snowflake")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        }
                    }

                    Spacer()
                }
            }
            .padding(12)
            .background(
                ZStack {
                    if habit.artworkFilename != nil {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial.opacity(0.6))
                    }
                }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { onLogAmount() }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(action: onCompleteAnyway) {
                Label("Complete Anyway", systemImage: "checkmark.circle")
            }
            if isImagePlaygroundAvailable {
                Button(action: onGenerateArt) {
                    Label(isGeneratingArt ? "Generating Art..." : "Generate Art", systemImage: "paintbrush")
                }
                .disabled(isGeneratingArt)
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var currentAmount: Double { occurrence?.currentAmount ?? 0 }
    private var progressFraction: Double { min(currentAmount / max(habit.dailyTarget, 1), 1.0) }
    private var periodDescription: String {
        HabitFormatter.progressDescription(
            amount: currentAmount,
            target: habit.dailyTarget,
            unit: habit.unitLabel,
            healthKitIdentifier: habit.healthKitIdentifier
        )
    }
}

struct HabitArtworkBackground: View {
    let filename: String?

    var body: some View {
        if let filename = filename,
           let url = WidgetFileCoordinator.shared.habitArtworkURL(filename: filename),
           let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            Color.clear
        }
    }
}

struct WeeklyDotsView: View {
    let habit: HabitDTO
    let recentOccurrences: [HabitOccurrenceDTO]

    /// Rolling 7-day window: oldest day first, today last.
    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: today)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let occurrence = recentOccurrences.first { Calendar.current.isDate($0.periodStart, inSameDayAs: day) }
                let isCompleted = occurrence?.completed ?? false
                let isFreeze = occurrence?.freezeUsed ?? false
                Circle()
                    .fill(isCompleted ? Color.accentColor : (isFreeze ? Color.orange : Color.clear))
                    .frame(width: 10, height: 10)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                    )
                    .overlay(
                        Circle()
                            .stroke(isCompleted || isFreeze ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .accessibilityLabel(label(for: day, completed: isCompleted, freeze: isFreeze))
            }
        }
    }

    private func label(for day: Date, completed: Bool, freeze: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: day)
        if completed {
            return "\(dayName): completed"
        } else if freeze {
            return "\(dayName): freeze used"
        } else {
            return "\(dayName): not completed"
        }
    }
}

#if DEBUG
#Preview {
    let habit = HabitDTO(
        name: "Morning Run",
        unitLabel: "km",
        dailyTarget: 5,
        incrementStep: 1,
        streakFreezes: 1
    )
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    let recentOccurrences: [HabitOccurrenceDTO] = (0..<7).compactMap { offset in
        guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
        switch offset {
        case 0, 1, 3, 4:
            return HabitOccurrenceDTO(
                habitUUID: habit.uuid,
                periodStart: day,
                currentAmount: 5,
                completed: true,
                completedAt: day
            )
        case 5:
            return HabitOccurrenceDTO(
                habitUUID: habit.uuid,
                periodStart: day,
                freezeUsed: true
            )
        default:
            return nil
        }
    }
    let todayOccurrence = HabitOccurrenceDTO(
        habitUUID: habit.uuid,
        periodStart: now,
        currentAmount: 2
    )
    let streak = HabitStreakResult(current: 6, longest: 14, freezesEarned: 1, atRisk: false, missedPeriod: nil)

    return HabitRowView(
        habit: habit,
        occurrence: todayOccurrence,
        recentOccurrences: recentOccurrences,
        streak: streak,
        onIncrement: {},
        onLogAmount: {},
        onEdit: {},
        onArchive: {},
        onDelete: {},
        onCompleteAnyway: {},
        onUseFreeze: {},
        onGenerateArt: {}
    )
}

#Preview("Streak at Risk") {
    let habit = HabitDTO(
        name: "Read 20 Pages",
        unitLabel: "pages",
        dailyTarget: 20,
        incrementStep: 5,
        weeklyFrequency: 5,
        streakFreezes: 1
    )
    let streak = HabitStreakResult(current: 12, longest: 12, freezesEarned: 1, atRisk: true, missedPeriod: Date())

    return HabitRowView(
        habit: habit,
        occurrence: nil,
        recentOccurrences: [],
        streak: streak,
        onIncrement: {},
        onLogAmount: {},
        onEdit: {},
        onArchive: {},
        onDelete: {},
        onCompleteAnyway: {},
        onUseFreeze: {},
        onGenerateArt: {}
    )
}
#endif
