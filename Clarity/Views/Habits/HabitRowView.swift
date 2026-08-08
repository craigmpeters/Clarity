import SwiftUI
import SwiftData

struct HabitRowView: View {
    let habit: HabitDTO
    let occurrence: HabitOccurrenceDTO?
    let weekOccurrences: [HabitOccurrenceDTO]
    let streak: HabitStreakResult
    let onIncrement: () -> Void
    let onLogAmount: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onCompleteAnyway: () -> Void
    let onUseFreeze: () -> Void
    let onGenerateArt: () -> Void

    var body: some View {
        ZStack {
            HabitArtworkBackground(filename: habit.artworkFilename)

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
                        WeeklyDotsView(habit: habit, weekOccurrences: weekOccurrences)
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
            .padding(.vertical, 8)
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
            Button(action: onGenerateArt) {
                Label("Generate Art", systemImage: "paintbrush")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var currentAmount: Double { occurrence?.currentAmount ?? 0 }
    private var progressFraction: Double { min(currentAmount / max(habit.dailyTarget, 1), 1.0) }
    private var periodDescription: String {
        HabitFormatter.progressDescription(amount: currentAmount, target: habit.dailyTarget, unit: habit.unitLabel)
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
                .overlay(.regularMaterial.opacity(0.7))
        }
    }
}

struct WeeklyDotsView: View {
    let habit: HabitDTO
    let weekOccurrences: [HabitOccurrenceDTO]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let day = dayForOffset(offset)
                let occurrence = weekOccurrences.first { Calendar.current.isDate($0.periodStart, inSameDayAs: day) }
                let isCompleted = occurrence?.completed ?? false
                let isFreeze = occurrence?.freezeUsed ?? false
                Circle()
                    .fill(isCompleted ? Color.accentColor : (isFreeze ? Color.orange : Color.secondary.opacity(0.2)))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
                    .accessibilityLabel(label(for: day, completed: isCompleted, freeze: isFreeze))
            }
        }
    }

    private func dayForOffset(_ offset: Int) -> Date {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return calendar.date(byAdding: .day, value: offset, to: weekStart) ?? Date()
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
