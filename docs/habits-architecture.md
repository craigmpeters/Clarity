# Architecture: Habits Feature for Clarity

**Status:** Approved design, implementation in progress — **current uncommitted build is broken (2 compile errors in `Shared/Utilities/HealthKitService.swift`; see §17)**  
**Scope:** iOS app, Widgets, App Intents (Siri/Shortcuts), Watch app  
**Out of scope:** Full HealthKit background-delivery auto-logging (model-ready, observer v2), negative habits, social streaks  
**Date:** 2026-08-08 (revised 2026-08-08 for HealthKit-write + locale-natural units + wizard Type-step list)  
**Replaces:** `docs/quantifiable-tasks-architecture.md` (uncommitted and superseded)  

---

## 1. Executive Summary

This document defines the **Habits** feature for Clarity. Habits are distinct from boolean Tasks: they accumulate progress toward a daily target, run on a weekly frequency, and support streaks with a manual "freeze" system.

Habits can optionally be **Health-linked**: a Health habit reads today's cumulative value from HealthKit as a floor, and manual logs write delta samples back to HealthKit so other apps see the progress. All user-facing quantities are rendered in **locale-natural units** (mL vs fl oz, km vs mi) derived from `Locale.current` via `Measurement`/`MeasurementFormatter`, never hardcoded per-region strings.

**Key constraint:** the existing quantifiable-tasks work was never deployed. We therefore revert it and build Habits as a self-contained model, without touching `ToDoTask` or its data pipeline.

---

## 2. Locked Design Decisions

| Decision | Choice |
| --- | --- |
| Separation | Dedicated `Habit` and `HabitOccurrence` models; `ToDoTask` untouched |
| Frequency | Unified engine — every Habit has a **daily target** and a **weeklyFrequency** (1–7) = "hit the daily target X days per week" |
| Streaks | Consecutive successful weeks; a week succeeds if completed/frozen days ≥ `weeklyFrequency` |
| Freeze | Auto-earn +1 per 7-day streak, cap 3, **manual spend**, grace = **end of next period** |
| HealthKit | `healthKitIdentifier` stored on the model; v1 = foreground sync (read floor) + **manual delta writes to HealthKit**; full background observer is v2. Clarity store remains canonical. Supported set is fixed at 4 types: `water`, `steps`, `workouts`, `mindful` |
| Units | **Locale-natural units via `Measurement`/`MeasurementFormatter`.** Canonical value stored in a fixed base unit per type; display unit derived from `Locale.current` (e.g. water → mL in UK, fl oz in US). No per-locale hardcoded unit strings |
| Image Playground | Gated by availability; no system picker sheet — background generation only |
| New-habit UX | Multi-step wizard for **create**. **Step 1 (Type) asks Health vs. General and shows the exhaustive, friendly-named list of supported Health types up front.** Existing `HabitFormView` remains for edit |
| Surfaces | Main app (new Habits tab + wizard + row), Siri/Shortcuts, interactive widgets, Watch app (one habit per page) |
| Migration | None; CloudKit schema evolution only |

---

## 3. Data Model

### 3.1 New file: `Shared/Models/Habit.swift`

```swift
@Model class Habit {
    var uuid: UUID
    var name: String
    var created: Date
    var unitLabel: String?          // display override only; when nil, a Health-linked habit renders in locale-natural units
    var dailyTarget: Double        // target per day, stored in the type's canonical base unit (see §12.7)
    var incrementStep: Double = 1.0
    var weeklyFrequency: Int = 7   // hit dailyTarget X days per week (7 = every day)
    var streakFreezes: Int = 0     // cap 3
    var freezesSpent: Int = 0      // running counter for deterministic reconcile
    var healthKitIdentifier: String?  // "water" | "steps" | "workouts" | "mindful" | nil (v1)
    var isArchived: Bool = false     // preserves history instead of deleting
    var artworkFilename: String?   // filename in App Group artwork directory
    @Relationship(deleteRule: .cascade) var occurrences: [HabitOccurrence]?
    @Relationship var categories: [Category]?
}

@Model class HabitOccurrence {
    var uuid: UUID
    @Relationship var habit: Habit?
    var periodStart: Date           // startOfDay this occurrence counts toward
    var currentAmount: Double = 0
    var completed: Bool = false
    var completedAt: Date?
    var freezeUsed: Bool = false
    var source: String?             // "manual" | "healthkit" | "watch" | "siri" | ...
}
```

### 3.2 New file: `Shared/Models/HabitDTO.swift`

Mirror `Habit` and `HabitOccurrence` as `Sendable`, `Hashable`, `Codable` structs with `decodeIfPresent` defaults for backward compatibility. `HabitDTO` stores the model metadata only; `HabitOccurrenceDTO` is the separate occurrence payload. The in-memory `HabitDTO.currentAmount`/`completed` helpers are **not** persisted to JSON.

```swift
struct HabitDTO: Sendable, Hashable, Codable {
    var id: PersistentIdentifier?
    var uuid: UUID
    var name: String
    var created: Date
    var unitLabel: String?
    var dailyTarget: Double
    var incrementStep: Double
    var weeklyFrequency: Int
    var streakFreezes: Int
    var freezesSpent: Int
    var healthKitIdentifier: String?
    var isArchived: Bool
    var artworkFilename: String?
    var categories: [CategoryDTO]

    var isTargetReached: Bool { currentAmount >= dailyTarget }
    var progressFraction: Double { min(currentAmount / max(dailyTarget, 1), 1.0) }
    var periodDescription: String { HabitFormatter.progressDescription(...) }

    // UI-only; not part of encoded payload
    var currentAmount: Double = 0
    var completed: Bool = false
    var completedAt: Date?
    var freezeUsed: Bool = false
    var source: String? = nil
    var periodStart: Date = Date()
}
```

```swift
struct HabitOccurrenceDTO: Sendable, Hashable, Codable {
    var id: PersistentIdentifier?
    var uuid: UUID
    var habitUUID: UUID
    var periodStart: Date
    var currentAmount: Double
    var completed: Bool
    var completedAt: Date?
    var freezeUsed: Bool
    var source: String?
}
```

### 3.3 Schema registration

Both models are registered in `ClarityModelActor.swift` (the `Containers` enum) for `liveApp()`, `liveExtension()`, and `inMemory()`. Because the app has not been deployed, CloudKit will create the new record types automatically without a migration plan.

### 3.4 Tasks remain untouched

`ToDoTask` keeps its existing shape, semantics, DTO, and widget pipeline. The quantifiable-tasks diff is reverted.

---

## 4. Repository / Actor Changes

### 4.1 Core methods in `Shared/Data/ClarityModelActor.swift`

```swift
func logHabitProgress(
    _ habitUUID: UUID,
    amount: Double? = nil,
    source: String = "manual"
) throws -> HabitOccurrenceDTO
```

1. Fetch `Habit` by `uuid` and guard it is not archived.
2. Fetch or create today's `HabitOccurrence` (periodStart = startOfDay today).
3. Add `amount ?? habit.incrementStep` to `currentAmount`.
4. If `currentAmount >= habit.dailyTarget`, set `completed = true` and `completedAt = Date.now`.
5. Set `occurrence.source = source`.
6. Call `reconcileFreezes(habit)`.
7. Run the post-mutation pipeline: save, write `habits.json`, write `tasks.json`, reload widgets, fire mutation hooks.

```swift
func setHabitProgress(
    _ habitUUID: UUID,
    date: Date,
    amount: Double
) throws -> HabitOccurrenceDTO
```

Sets an occurrence's `currentAmount` to an absolute value (clamped ≥ 0), re-evaluates completion, reconciles freezes, and runs the post-mutation pipeline. This is the undo/correct path.

```swift
func applyHealthKitProgress(
    _ habitUUID: UUID,
    value: Double
) throws -> HabitOccurrenceDTO
```

Used only for HealthKit-linked habits. Sets `currentAmount = max(currentAmount, value)`, never lowers. Marks `source = "healthkit"`, re-evaluates completion, reconciles freezes, and runs the pipeline. **No-op if the value is not higher than the current manual total.**

```swift
func spendFreeze(_ habitUUID: UUID) throws
```

1. Fetch habit; guard `streakFreezes > 0`.
2. Determine the most recently missed period via `HabitStreakCalculator`.
3. Guard the miss is within the **end of the next period** grace window.
4. Decrement `streakFreezes`, increment `freezesSpent`, create or mark the missed occurrence `freezeUsed = true` and `completed = true` with `currentAmount = dailyTarget`.
5. Run the post-mutation pipeline.

```swift
func reconcileFreezes(_ habit: Habit)
```

Recomputes the full streak from `fetchHabitHistory` and sets `streakFreezes = max(0, min(freezesEarned, maxFreezes) - freezesSpent)`. Ensures the cap-3 is enforced and spent freezes are not re-credited.

```swift
func fetchHabits() throws -> [HabitDTO]
func fetchHabitsIncludingArchived() throws -> [HabitDTO]
func fetchHabitHistory(_ uuid: UUID, from: Date, to: Date) throws -> [HabitOccurrenceDTO]
```

### 4.2 In-flight deduplication

Add `private var inFlightHabitLogs: Set<UUID>` to the actor. Guard the start of `logHabitProgress`/`spendFreeze`/`setHabitProgress` so rapid widget taps and WatchConnectivity `transferUserInfo` redelivery cannot double-increment the same habit.

### 4.3 Existing Task methods

No changes to `completeTask`, `uncompleteTask`, `createNextOccurrence`, or any `ToDoTask` logic. The model schema is the only touch point in the actor file.

---

## 5. Streak Engine

### 5.1 New file: `Shared/Models/HabitStreakCalculator.swift`

Pure, `nonisolated` function over `[HabitOccurrenceDTO]`:

```swift
struct HabitStreakResult {
    let current: Int
    let longest: Int
    let freezesEarned: Int
    let atRisk: Bool
    let missedPeriod: Date?     // the period that can be frozen
}

static func streak(
    occurrences: [HabitOccurrenceDTO],
    frequency: Int,
    freezes: Int,
    referenceDate: Date = Date()
) -> HabitStreakResult
```

Algorithm:

1. Bucket occurrences by day, keeping the latest if duplicates exist.
2. A day counts if its occurrence is `completed` or `freezeUsed`.
3. A week succeeds if counted days ≥ `weeklyFrequency`.
4. Streak = consecutive successful weeks ending at the current week. An in-progress week **preserves** the existing streak until it actually fails.
5. `freezesEarned` = 1 per **7-day** streak (e.g. a 7-day streak = 1 freeze), capped at `HabitConfig.maxFreezes` in the model.
6. `atRisk` = last week failed, we are within the **end of the next period** grace window, and `freezes > 0`.
7. `missedPeriod` = the end-of-week date of the failed week that can be frozen.

### 5.2 Unit tests

`ClarityTests/HabitStreakCalculatorTests.swift` covers:
- Daily habit streaks (7/7)
- 3×/week habit streaks (3/7)
- Freeze usage preserving streaks
- Missed periods ending streaks after grace window
- Edge cases around week boundaries
- Freeze-earn cap at `maxFreezes`
- Grace window = end of next period

---

## 6. Connectivity & Snapshot Pipeline

### 6.1 Widget snapshot (App Group file)

`WidgetFileCoordinator` provides:

```swift
func writeHabits(_ habits: [HabitDTO]) throws -> [HabitDTO]
func readHabits() throws -> [HabitDTO]
```

These write to `ClarityHabits.json`, separate from `tasks.json`. `readHabits` is **throwing**, uses `NSFileCoordinator`, and never swallows decode errors as an empty list. `WatchSnapshotStore.requestInitialSnapshot` no longer writes a fallback-derived empty snapshot over a decode failure.

### 6.2 Watch snapshot

`Shared/Data/ConnectivityWireTypes.swift`:

```swift
struct Snapshot: Sendable {
    var revision: Int
    var tasks: [ToDoTaskDTO]
    var habits: [HabitDTO]                // decodeIfPresent default []
    var habitOccurrences: [UUID: HabitOccurrenceDTO]  // today's occurrence per habit
    var progress: WeeklyProgress
    var activePomodoro: PomodoroDTO?
}
```

Old watch snapshots without the `habits`/`habitOccurrences` keys decode successfully. Future revision: add `currentStreak` and a 7-day completion bitmap to `HabitDTO` (or to a small watch-specific habit projection) so the watch shows real streaks and weekly dots instead of the current `streakFreezes`-as-streak and hardcoded gray dots.

### 6.3 Watch commands

```swift
enum WatchCommand: Sendable {
    case completeTask(UUID)
    case uncompleteTask(UUID)
    case startPomodoro(UUID)
    case stopPomodoro
    case requestSnapshot
    case sendLogs(Data)
    case logHabitProgress(UUID, amount: Double?)
}
```

`PhoneConnectivityCoordinator.handleCommand` routes `.logHabitProgress` to `store.logHabitProgress(...)`. If the command fails, the coordinator **must not broadcast a success-looking snapshot**. Add a negative-ack path (logged failure, optionally an error event to the watch).

### 6.4 Artwork transfer

Generated PNGs are stored in the App Group container (filename = `habitUUID.uuidString + ".png"`). Image data is too large for the `Snapshot`, so it is transferred via WatchConnectivity `transferFile` and cached on the watch side. The `Snapshot` carries only the `artworkFilename` reference.

---

## 7. App Intents

### 7.1 `Widgets/Intents/LogHabitProgressIntent.swift`

```swift
struct LogHabitProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Habit Progress"
    static let openAppWhenRun = false

    @Parameter(title: "Habit") var habit: HabitEntity
    @Parameter(title: "Amount") var amount: Double?

    func perform() async throws -> some IntentResult & ProvidesDialog { ... }
}
```

The actor returns the updated `HabitOccurrenceDTO`; the dialog is built from that result (no file round-trip). The unit is conditionally included and uses localizable `LocalizedStringResource` interpolation.

### 7.2 `Widgets/Entities/HabitEntity.swift`

Queryable App Entity. Filters out archived habits. `EntityStringQuery` is implemented so phrases like *"Log progress on Drink Water"* resolve against the name.

### 7.3 Task intents

`CompleteTaskIntent` remains unchanged.

---

## 8. Main App UI

### 8.1 `Clarity/Views/ContentView.swift`

Habits is the second tab (tag 1):

| Tag | Label | Icon | View |
| --- | --- | --- | --- |
| 0 | Tasks | `list.bullet` | `TaskIndexView` |
| 1 | Habits | `checklist.checked` | `HabitsIndexView` |
| 2 | Focus | `timer` | `PomodoroView` |
| 3 | Stats | `chart.bar` | `StatsView` |
| 4 | Settings | `gear` | `SettingsView` |

The `NavigationStack` is owned by `ContentView`; `HabitsIndexView` must **not** wrap itself in its own `NavigationStack`.

### 8.2 `Clarity/Views/Habits/HabitsIndexView.swift`

- `@Query` for `Habit` where `!isArchived` (used as a change trigger only; rendering uses actor-fetched DTOs for now, subject to the R1 refactor in the review report).
- Sections: **Streak at Risk** (habits with a miss in the grace window and available freezes); **Today** (all active habits).
- Toolbar: trailing `+` → `HabitWizardView` sheet; leading filter/category menu (v2 or implement now per review D9).
- Pull-to-refresh + `.task` load DTOs and occurrences.
- Confirmation dialog for Delete (already present).

### 8.3 `Clarity/Views/Habits/HabitRowView.swift`

- Large circular progress ring with a `+` button.
- Text: `currentAmount / dailyTarget unitLabel` via `HabitFormatter` (preserves decimals, trims trailing zeros).
- Streak flame badge: real `currentStreak` from `HabitStreakCalculator`.
- Weekly dot row: 7 circles filled for completed/frozen days this week; dots must have accessibility labels/shapes, not just color.
- Tap → "Log amount…" sheet.
- Context menu: Edit, Complete Anyway, **Generate Art** (only when `HabitArtService.isAvailable`), Archive, Delete (with confirmation).
- Background artwork via `HabitArtworkBackground`, dimmed/blurred with a scrim so the ring/text stay legible.

### 8.4 New `Clarity/Views/Habits/HabitWizardView.swift` (create only)

Step-by-step wizard for **new** habits:

1. **Type** — the entry point of the flow. Asks **"Is this a Health habit?"** and presents two choices: **Health** or **General** (non-health). Choosing **Health** immediately reveals the **exhaustive list of the Health types Clarity supports**, rendered as friendly, localized names with icons — not raw identifiers:
   - **Water** (`water`) — `drop.fill`
   - **Steps** (`steps`) — `figure.walk`
   - **Exercise Minutes** (`workouts`) — `flame.fill`
   - **Mindful Minutes** (`mindful`) — `brain.head.profile`

   The selected Health type is stored as `healthKitIdentifier`. **General** clears `healthKitIdentifier`. This list is the single source of truth for the supported set; it is fixed at these four for v1 (see §12.2). Picking a type here pre-selects it in Step 3 and triggers the HealthKit authorization request (§12.3).
2. **Name** — text field; debounced AI suggestion via `HabitSuggestionService`.
3. **Amount & Unit** — unit, daily target, increment step. For Health habits the HealthKit type is shown (pre-filled from Step 1) and the unit/increment are pre-filled from the type's **locale-natural unit** (§12.7); the AI suggestion is shown as a tappable chip, but all fields remain editable. For General habits this is a free-form unit label (e.g. "pages", "glasses").
4. **Schedule** — days per week (1–7), categories (`CategorySelectionView`). The HealthKit source picker is **not** repeated here; the type was chosen in Step 1.
5. **Finish** — summary + Save. The summary shows amounts formatted in the **locale-natural unit** (e.g. "250 ml" in the UK, "8.5 fl oz" in the US).

Validation: trim name/unit, clamp target/step to `HabitConfig` ranges, reject empty/whitespace name.

### 8.5 `Clarity/Views/Habits/HabitFormView.swift` (edit only)

The existing single-page form remains for editing. After the wizard is built, its mutable state and validation logic should be extracted to a shared `@Observable HabitFormState` so both paths behave identically and do not duplicate code.

### 8.6 Stats

`Clarity/Views/Stats/StatsView.swift` adds a new `HabitStreaksView` section showing per-habit current streak, longest streak, and freeze balance. Data comes from `HabitStreakCalculator` over the actor.

---

## 9. Widget UI

### 9.1 Existing widgets

No change to `DueWidget`, `CompletedWidget`, or `TaskHistoryWidget`. They continue to read `tasks.json`.

### 9.2 Habits file

Widgets that choose to can read `ClarityHabits.json` in a future phase. For v1, App Intents and Siri cover the quick-entry path outside the app.

---

## 10. Watch App UI

### 10.1 `Watch/Views/WatchHabitsView.swift`

- Vertical `TabView` so one Habit occupies the full screen.
- Large circular progress indicator in the center; **tap anywhere on the circle** to increment (not just the inner `+` button).
- Below the ring: "3/5 glasses" and weekly dots.
- Streak flame badge at the top showing the real `currentStreak`.
- Menu item / toolbar to return to the main Tasks list.

### 10.2 Watch action flow

1. User taps the ring on a habit page.
2. `WatchSnapshotStore.shared.logHabitProgress(habitUUID, amount: step)` **optimistically** updates the displayed habit and sends `WatchCommand.logHabitProgress` via `ConnectivityTransport`.
3. Phone handles the command in `PhoneConnectivityCoordinator`, runs `ClarityServices.store().logHabitProgress(...)`.
4. Phone's mutation hook triggers `broadcastSnapshot()`, which includes the `habits` array and `habitOccurrences`.
5. Watch receives the new snapshot and refreshes the display. If the phone command failed, the watch must receive a negative-ack or a snapshot that reverts the optimistic increment.

### 10.3 Optimistic updates

Mirror the existing `optimisticallyCompleted` mechanism for habits: add an `optimisticallyIncrementedHabits: Set<UUID>` (or similar) in `WatchSnapshotStore`, apply the local increment to the displayed occurrence, and clear on the next snapshot. Add a watch-side accessibility label for the ring and dots.

---

## 11. AI Artwork

### 11.1 Service

`Shared/Models/HabitArtService.swift` is the single owner of Image Playground generation.

```swift
@available(iOS 26.0, *)
final class HabitArtService: ObservableObject {
    var isAvailable: Bool { ImagePlaygroundViewController.isAvailable }

    func generate(for habit: HabitDTO) async throws -> URL
    func concepts(for habit: HabitDTO) -> [ImagePlaygroundConcept]
    func prompt(for habit: HabitDTO) -> String
}
```

`generate` uses the programmatic `ImageCreator` API to produce a PNG on-device without presenting a picker. If the programmatic API is unavailable or the signature differs, the implementation must be verified against the iOS 26 SDK before finalizing.

### 11.2 Storage & sync

- Save PNG to the App Group artwork directory with filename `habitUUID.uuidString.png`.
- Store only the filename on `Habit.artworkFilename`.
- Sync to the watch via `ConnectivityTransport.transferHabitArtwork`.
- UI renders the image behind the progress ring with a scrim; falls back to the default gray track when no art exists.

### 11.3 UI entry point

The "Generate Art" context-menu item is shown only when `isAvailable` is true. Tapping it starts a fire-and-forget `Task` that shows a transient in-progress state on the row and then routes the resulting URL through the existing `saveArtwork` pipeline.

---

## 12. HealthKit Integration

### 12.1 Scope (v1)

- Foreground sync when the Habits tab is refreshed; each sync applies today's value and **backfills any days missed since the last successful sync** (bounded to 30 days), so occurrences exist for days when the app was never opened.
- No background observer in v1 (v2 item).
- Clarity remains the canonical source of truth; HealthKit data is treated as a **read-only floor** for the day's amount.
- **Manual logging writes to HealthKit** so other apps can see Clarity's habit progress.

### 12.2 Identifier → HealthKit type mapping

| `healthKitIdentifier` | HK Type | Unit | Semantics |
|---|---|---|---|
| `water` | `HKQuantityType.dietaryWater` | mL / L | Cumulative daily intake |
| `steps` | `HKQuantityType.stepCount` | count | Cumulative daily steps |
| `workouts` | `HKQuantityType.appleExerciseTime` | minutes | Cumulative daily exercise minutes |
| `mindful` | `HKCategoryType.mindfulSession` | minutes | Cumulative daily mindful minutes |

The `workouts` identifier may be reinterpreted to workout session count if product preference changes; default to exercise time.

### 12.3 Authorization

Extend `HealthKitService.requestAuthorization` to include the mapped **read and write** types alongside the existing `stateOfMind` types. Request authorization when a habit is linked to a HealthKit identifier for the first time or when the identifier changes.

### 12.4 Sync rule

For each active habit with a `healthKitIdentifier`, sync walks each day from the last synced day (or habit creation, bounded to 30 days back) through today:

```
for day in lastSyncedDay...today {
    let hkValue = HealthKitService.cumulativeValue(for: identifier, on: day)
    let effective = max(manualOccurrence.currentAmount, hkValue ?? 0)
    actor.applyHealthKitProgress(habitUUID, value: effective, date: day)
}
```

- **Only raises** the occurrence amount; never lowers a manual log.
- Backfilled days are stamped `completedAt` at end of that day; today uses the current time.
- The last synced day is persisted per habit in UserDefaults (`habitHealthKitLastSyncDates`) and re-applied on the next sync, so data recorded later that same day is still picked up.
- Marks `source = "healthkit"`.
- Re-evaluates completion and reconciles freezes.

### 12.5 Write rule

When a user manually logs progress on a HealthKit-linked habit:

```
let delta = amount ?? habit.incrementStep
let unit = HealthKitService.unit(for: identifier)
let sample = HKQuantitySample(type: hkType, quantity: HKQuantity(unit: unit, doubleValue: delta), start: Date(), end: Date())
HealthKitService.save(sample)
```

- Writes the **delta** (increment) as a new sample, not the absolute total.
- Uses the habit's `incrementStep` as the default write amount.
- Only writes for `HKQuantityType` identifiers (`water`, `steps`, `workouts`). `mindful` is a category type and uses duration-based samples.
- Marks `source = "manual"` on the Clarity occurrence; HealthKit writes are a side-effect, not a source change.

### 12.6 UI

- The HealthKit picker in the wizard / edit form is functional and triggers an authorization request.
- When today's occurrence has `source == "healthkit"`, show a small HealthKit glyph in the row.
- When today's occurrence has `source == "manual"` on a HealthKit-linked habit, show a small "HK" badge to indicate the write went through.

---

## 13. Reverting the Superseded Quantifiable Work

Because the quantifiable-tasks changes were never committed, we restore the affected files to HEAD and delete the new file.

Files to restore:
- `Clarity.xcodeproj/project.pbxproj`
- `Clarity/Localizable.xcstrings`
- `Clarity/Views/Tasks/TaskFormView.swift`
- `Clarity/Views/Tasks/TaskIndexView.swift`
- `Clarity/Views/Tasks/TaskRowView.swift`
- `Shared/Data/ClarityModelActor.swift`
- `Shared/Models/Todo.swift`
- `Widgets/Entities/TaskDetailEntity.swift`
- `Widgets/Intents/CompleteTaskIntent.swift`
- `Widgets/Views/TaskRowInteractive.swift`
- `Widgets/Views/WidgetTaskRow.swift`

File to delete:
- `Widgets/Intents/IncrementTaskIntent.swift` (and remove from `project.pbxproj` if it survives the restore).

---

## 14. Implementation Order

1. **Streak semantics** — update `HabitStreakCalculator` and `spendFreeze` for "end of next period" grace and "per 7-day streak" earn rate; update tests.
2. **Review must-fixes** — D16 localization, D11 `HabitStreaksView`, D13 watch optimistic + negative-ack, P2 real watch streak/dots, P2 `readHabits` hardening, R6 in-flight dedup, R8 nested `NavigationStack`, R10/R11 cleanup.
3. **Image Playground** — gate entry, delete `HabitArtSheet`, implement background `ImageCreator` generation, wire to row context menu.
4. **Wizard** — create `HabitWizardView`; extract shared `HabitFormState` with `HabitFormView`; wire `+` button to wizard.
5. **HealthKit** — extend `HealthKitService` with read + write support, add `HabitHealthKitSync`, add `applyHealthKitProgress` actor method, wire foreground sync, picker, and manual-log write path.
6. **Doc update** — rewrite `docs/habits-architecture.md` to reflect final state (this document).
7. **Build & verify** — all five targets (Clarity iOS, Widgets, App Intents, ClarityWatch, ClarityWatchWidgets); on-device watch + Siri round-trip.

---

## 15. Acceptance Checklist

- [ ] `ToDoTask` behavior is byte-identical to HEAD (complete / uncomplete / recur / widget).
- [ ] Habits never appear in the Tasks tab; Tasks never appear in the Habits tab.
- [ ] `+` button logs `incrementStep` into today's `HabitOccurrence`.
- [ ] "Log amount…" sets the occurrence's `currentAmount` to an absolute value.
- [ ] `unitLabel` appears in rows, forms, dialogs, and Siri responses ("3 of 5 glasses").
- [ ] Daily target reached → occurrence marks `completed` and `completedAt`.
- [ ] Weekly goal = `weeklyFrequency` completed days; streak = consecutive successful weeks.
- [ ] Freeze auto-earned per 7-day streak, capped at 3; manual spend within grace saves streak.
- [ ] Siri/Shortcuts: "Log progress on Drink Water" works via `LogHabitProgressIntent`.
- [ ] Watch: one habit per page, tap-to-increment (whole ring), optimistic update, real streak/dots, snapshot round-trip with negative-ack on failure.
- [ ] Old task snapshots and watch snapshots still decode (`habits`/`habitOccurrences` absent → empty/default).
- [ ] CloudKit private database evolves to include `Habit` and `HabitOccurrence` record types without a custom migration.
- [ ] All new user-facing strings are localized for en, de, es, fr, and zh-Hans.
- [ ] Image Playground "Generate Art" is gated by availability and uses background generation (no sheet).
- [ ] New habits use a wizard; edit uses the existing form.
- [ ] HealthKit-linked habits sync today's cumulative value via `max(manual, healthkit)` in the foreground.
- [ ] Manual logs on HealthKit-linked habits write the delta to HealthKit as a new sample.
- [ ] Unit tests pass (`HabitStreakCalculatorTests`).

---

## 16. Future / v2 Items

- **HealthKit background observer:** `HKObserverQuery` with `enableBackgroundDelivery` and `UIBackgroundModes` so HK samples update the habit without foregrounding the app.
- **Negative habits:** e.g. "No sugar" — success defined by *not* logging, or by logging "slips" below a threshold.
- **Friend/social streaks:** compare streaks with contacts.
- **Habit-specific widgets:** a dedicated widget showing today's habit progress.
- **Habit calendar heatmap:** monthly view of completed/frozen/missed days.
- **Smart reminders:** per-habit notification cadence based on weekly frequency and current streak.
