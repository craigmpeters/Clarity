# Clarity Test-Coverage Quick-Win Plan

Date: 2026-08-09
Status: Draft → ready for build execution
Scope: `ClarityTests` unit-test target for the iOS app (`Clarity.app`) which includes the `Shared/` and `Clarity/` modules.

## Context & ground rules

- **Test target:** `ClarityTests` is hosted in `Clarity.app` (`TEST_HOST` = `Clarity.app`). All tests use `@testable import Clarity` and can access any code compiled into the app target (i.e., `Shared/` and `Clarity/`). Widgets, Watch, and AppIntents are separate targets and are **not** importable from `ClarityTests`; test their logic only through the `Shared/` copies.
- **Framework & style:** Use **Swift Testing** (`import Testing`), not XCTest. Match the existing style in `ClarityTests/HabitStreakCalculatorTests.swift`:
  - `struct FooTests` (no classes).
  - `@Test func descriptiveCamelCaseName() async throws { ... }`.
  - `#expect(...)` for assertions.
  - Private fixture factories at the top of each test struct.
  - Pinned gregorian `Calendar` with `firstWeekday = 1` (Sunday).
  - Construct dates at **noon** to avoid DST/midnight edge cases.
  - Pass `referenceDate:` explicitly wherever the API supports it.
- **Tooling:** Build the `Clarity` scheme and run the targeted tests after each step; fix all errors and warnings before continuing. (`swift build`/`swift test` are not applicable here because this is an Xcode project.)
- **Behavioral pinning:** Several code paths look like latent bugs. For each, write a **characterization test** that pins the current behavior with a `// PINNED: possible bug — <note>` comment. Do not fix the production behavior in the same step unless explicitly requested. Known pins:
  - `CompletedTaskFilter.Month` matches **every** completed task.
  - `StatisticsCalculator.categoryData` overwrites the uncategorized count on the second pass.
  - `ToDoTask.recurrenceDescription` has no `weekdaySymbols` bounds guard (do not test an out-of-range day; it will crash).
  - `HabitStreakResult.longest` resets to `0` when the current streak breaks.
  - `ClarityApp.populateUUIDsIfNeeded` compares build numbers lexicographically.
- **Locale sensitivity:** `HabitFormatter` water-unit output depends on `Locale.current`. Assert membership in the valid set rather than hardcoding a single unit, or only test locale-independent branches.

## Business assumptions (correct if wrong)

1. A habit week runs **Sunday → Saturday** (`firstWeekday = 1`), succeeds when completed or frozen days ≥ `weeklyFrequency`, freezes are earned at **+1 per 7-day streak capped at 3**, and the grace period is **7 days**.
2. `HabitStreakResult.longest` resetting to 0 on a break is intentional (it tracks the current streak's longest, not all-time).
3. `CompletedTaskFilter.Month` matching everything is a placeholder, not the intended rule.
4. Health-linked habit identifiers are exactly `water` / `steps` / `workouts` / `mindful` with canonical base units mL / count / minutes.

## Wave 1 — Pure quick wins (zero production changes)

Each step is a new file under `Clarity/ClarityTests/`, added to the `ClarityTests` target. They can be done in order and each is independently shippable.

### Step 1: `StatisticsCalculatorTests.swift`

Target: `Shared/Models/StatisticsCalculator.swift`.

Fixtures: `task(name:completedAt:pomodoro:pomodoroTime:categories:)`, pinned gregorian calendar, noon dates.

Test cases:
- `filter(_:for:referenceDate:)` for all 6 `StatsTimeframe` values.
  - Boundary `completedAt == start` is included.
  - `completedAt == nil` is excluded.
  - `.today` uses same-day matching only.
  - `.thisYear` uses the calendar year start.
- `overviewMetrics(from:referenceDate:)`
  - Empty input → all zeros.
  - `totalFocusTime` sums `pomodoroTime` only when `pomodoro == true`.
  - `averagePerDay` with single-day span uses divisor 1 (clamped), and multi-day span uses actual day span.
- `hourlyData(from:)`
  - Always returns 24 entries.
  - Counts bucketed by hour.
  - All-zero input produces intensities 0 (no division by zero).
  - Max bucket intensity is 1.0.
- `dailyData(from:)`
  - Buckets by startOfDay.
  - Pin the two "Uncategorized" paths (empty name vs. no categories) and the overwrite behavior.
  - Sorted descending by count.
  - `dateString` format matches "EEE, MMM d".
- `categoryData(from:categories:)`
  - Counts per category.
  - Missing color → `.Brown` sentinel.
  - Pin uncategorized double-pass overwrite.
  - Sorted descending by count.
- `streakData(from:referenceDate:)`
  - Current streak when today is completed vs. not completed (starts from yesterday).
  - Single completed day.
  - Gap breaks streak.
  - `calculateLongestStreak` ignores `diff == 0` and resets on `diff > 1`.
- `weeklyProgress(completedTasks:categories:globalTarget:referenceDate:)`
  - Monday-based week: assert behavior with reference date on Monday and on Sunday.
  - Per-category progress only when `weeklyTarget > 0`.
  - Sorted by category name.
  - Global target aggregation.

### Step 2: `HabitConfigTests.swift` + `HabitErrorTests.swift`

Target: `Shared/Models/HabitConfig.swift`.

Test cases:
- `dailyTargetRange(for:)`
  - `water` → `1...30000`.
  - `steps` → `1...200000`.
  - `workouts` / `mindful` → `1...1440`.
  - unknown / `nil` → `1...10000`.
- `validateTarget(_:healthKitIdentifier:)`
  - Exactly 1, exactly upper bound, 0, negative, NaN (pin: `ClosedRange.contains(NaN)` is false).
  - For each identifier and for `nil`.
- `validateIncrementStep(_:)` and `validateIncrementStep(_:healthKitIdentifier:)`
  - Lower bound 0.1, upper bounds, and step exceeding the range upper bound for a given identifier.
- `HabitError`
  - Equality includes `.persistenceFailed` comparing `localizedDescription`.
  - `errorDescription` is non-nil for every case.

### Step 3: `PomodoroAlarmSoundTests.swift`

Target: `Shared/Models/PomodoroAlarmSound.swift`.

Test cases:
- Round-trip `from(persistenceID: x.persistenceID) == x` for `.default`, `.preset(name:)`, `.custom(filename:)`.
- Unknown persistence ID → `.default`.
- Pin `"preset:"` (empty name) → `.preset(name: "")`.
- `displayName` capitalizes preset names, strips `.caf` suffix from custom filenames, and leaves non-`.caf` custom names unchanged.
- `allPresets` equals `[chime, bell, ding]`.

### Step 4: `SwipeActionTests.swift`, `HeatmapSizeTests.swift`, `StatsTimeframeTests.swift`

Exhaustive enum pins (regression guards):
- `SwipeAction`:
  - All `title` values non-empty.
  - Raw values match expected strings.
  - `role` is `.destructive` only for `.delete`.
  - Pin `systemImage` and `systemImageName` returning the same value.
- `HeatmapSize`:
  - Columns, rows, and boolean flags (`showMonthLabels`, `showLegend`, `isInteractive`) per preset.
- `StatsTimeframe`:
  - `shortDescription` for each case; the current-year case uses `Date().formatted(.dateTime.year())`, so assert shape rather than exact value.
  - `dateRange` shape assertions only (not injectable; avoid brittle exact date checks).

### Step 5: `HabitFormatterTests.swift`

Target: `Shared/Models/HabitFormatter.swift`.

Test cases:
- `formatted(_:)`: `1.0` → "1", `1.234` → "1.23", `0` → "0".
- `progressDescription(amount:target:unit:)`: returns `"X / Y unit"`.
- `progressDescription(amount:target:healthKitIdentifier:)`: pin that `unit != nil` takes precedence over `healthKitIdentifier`.
- `healthKitUnitString(for:)` for the four identifiers + default; for water, assert the output is in the locale-appropriate set (mL or fl oz) without hardcoding.
- `formattedHealthKitMeasurement(value:identifier:)`: steps → "N steps", workouts/mindful → "N min".

### Step 6: `CategoryIconTests.swift`

Target: `Shared/Views/CategoryIcon.swift`.

Test cases:
- `suggestedIconName(for:)` returns the expected symbol for known keywords.
- Matching is case-insensitive.
- Empty / unknown input returns `nil`.
- Pin order-dependence: e.g., `"phone"` matches the social entry before the digital-wellbeing entry. Document any unreachable entries discovered (e.g., if "make the bed" appears after "bed" it is dead).

### Step 7: `HabitDTOTests.swift` + `HabitOccurrenceDTOTests.swift`

Targets: `Shared/Models/HabitDTO.swift` and `HabitOccurrenceDTO.swift`.

Test cases:
- `HabitDTO.isTargetReached` boundaries (equal to target, below, above).
- `HabitDTO.progressFraction`:
  - Target 0 → clamped divisor (`max(target, 1)`).
  - Over-target → capped at 1.0.
  - Negative `currentAmount` **pin** (not floored at 0).
- Codable round-trip for both DTOs.
- Decode from JSON missing keys → verify every default (`dailyTarget ?? 1`, `weeklyFrequency ?? 7`, etc.).

### Step 8: `ToDoTaskDTOTests.swift` + `CategoryDTOTests.swift` + Codable round-ups

Targets: `Shared/Models/Todo.swift`, `Category.swift`, `Statistics.swift`, `Widgets.swift`, `PomodoroService.swift`.

Test cases:
- `ToDoTaskDTO` Codable round-trip + defaults for missing fields.
- `CategoryDTO` Codable round-trip + `weeklyTarget` defaults to 0.
- `CategoryDTO.decodeId(_:)` throws for garbage base64; `encodedId` can be exercised with a `PersistentIdentifier` from `Containers.inMemory()` (reused in Wave 2).
- `WeeklyProgress`, `WatchUserInfo`, `WatchWidgetData`, and `CompletedSession` round-trips.

### Step 9: `TaskFilterTests.swift`

Target: `Shared/Models/Todo.swift` (injectable `matches` extensions and `RecurrenceInterval`).

Test cases:
- `TaskFilter.matches(task:at:calendar:)` and `.matches(dto:at:calendar:)`:
  - `.overdue`: due < startOfDay(now); due exactly at startOfDay is **not** overdue.
  - `.today`: same-day match.
  - `.tomorrow`: next calendar day.
  - `.thisWeek`: due at week start included; just outside excluded.
- `RecurrenceInterval.nextDate(from:)`:
  - `daily` / `everyOtherDay` / `weekly` / `biweekly` / `monthly` arithmetic.
  - `.custom` and `.specific` return the input unchanged.
  - Pin month-end behavior for `monthly` on Jan 31.
- `CompletedTaskFilter.matches(_:calendar:now:)`:
  - `.Today` and `.PastWeek` (Monday-based week) boundaries.
  - **Pin `.Month` always returns true.**
- `TaskFilterOption.toTaskFilter()` mapping.

### Step 10: `CompanionPersonalityTests.swift`

Targets: `Clarity/Companions/Otto.swift`, `Goose.swift`.

Test cases (parameterize over `[any CompanionPersonality]` from `CompanionService.allPersonalities`):
- Structural invariants: unique `id`s, `supportedEmotions` non-empty, `fallbackEmoji` non-empty.
- `requiresPremium`: Otto `false`, Goose `true`.
- `prompt(for:)` for all 8 `CompanionTrigger` cases:
  - Associated-value interpolation present (e.g., `streakMilestone(days: 30)` contains "30").
  - `habitSuggestion` truncates `categories` to 3 (pass 5, expect the first 3).
  - Suffix matches `allowsTaskSuggestion` ("You may suggest…" vs. "Do not set suggestedTaskName.").
- `fallbackMessage(for:)` expected emotion per trigger (e.g., Otto `.taskUncompleted` → `.loving`, Goose → `.silly`).
- `errorFallback(overdueTask:)`:
  - With task: name interpolated and `suggestedTask` set.
  - Without task: generic text and no suggestion.
- `systemInstructions(name:contextBlock:)` contains both arguments.

### Step 11: `CompanionEnumTests.swift`

Target: `Clarity/Models/CompanionService.swift` (value types only).

Test cases:
- `CompanionTrigger.allowsTaskSuggestion` is true only for `.taskCompleted` and `.pomodoroCompleted` (table test all 8).
- `CompanionModelAvailability.isAvailable` and `userFacingReason` exhaustive; `.available` user-facing reason is `""`.
- `CompanionEmotion` raw-value round-trips.
- `ChatMessage.sender` and `.emotion`:
  - Valid raw → matching enum.
  - Invalid raw → `.companion` fallback for sender, `nil` for emotion.
  - `nil emotionRaw` → `nil`.

### Step 12: `CompanionTaskContextTests.swift`

Target: `CompanionTaskContext.instructionsBlock` in `Clarity/Models/CompanionService.swift`.

Test cases:
- Empty context → empty-state string.
- UPCOMING TASKS section contains task names (don't assert exact RelativeDateTimeFormatter output).
- Category list is present and formatted.
- RECENTLY COMPLETED section contains `String(format: "%.1f", mood)`.
- HABITS section:
  - `weeklyFrequency == 7` → "daily".
  - `weeklyFrequency != 7` → "N days/week".
  - `doneToday` true → "done today", false → "not done today".
- Mood-valence thresholds: `0.5` → "great", `0.0` → "okay", negative → "drained".
- "last done …, user felt …" suffix present when there is a last-completed task and absent otherwise.

### Step 13: `UserDefaultsExtensionsTests.swift`

Target: `Clarity/Extensions/UserDefaults+Extensions.swift`.

Notes:
- These extensions use `UserDefaults.standard`. Each test must clean up its keys (save/restore or `removeObject` at the end).

Test cases:
- Absent-key defaults for every property, especially:
  - `companionEnabled` → `true` (tri-state).
  - `pomodoroAlarmSoundID` → `"default"`.
  - `companionPersonalityID` → `"otto"`.
- Round-trip set/get for each property.
- `resetOnboardingState()` removes both onboarding keys and leaves others intact.

### Step 14: `HabitStreakCalculatorGapTests.swift`

Extend the existing `HabitStreakCalculatorTests.swift` or add a companion file.

Target: `Shared/Models/HabitStreakCalculator.swift`.

Test cases:
- Same-day duplicate occurrences: most recent wins.
- `frequency` clamping: `0` → `1`, `8` → `7`, negative → `1`.
- Empty occurrences → zeros.
- **Pin** `longest` resets to 0 after streak break.
- `atRisk` boundary exactly at `missedPeriod` (included) and exactly at `graceEnd` (included).
- `missedPeriod` value correctness.
- Mixed `habitUUID` occurrences: **pin** the calculator does not filter by habit (caller's responsibility).

### Step 15: `ConnectivityWireTests.swift`

Target: `Shared/Data/ConnectivityWireTypes.swift`.

Notes:
- Replicate the ISO8601 date strategy from `ConnectivityTransport` in private helpers `makeEncoder()` / `makeDecoder()` so dates round-trip exactly.

Test cases:
- `WatchCommand` (7 cases), `PhoneEvent`, and `WireMessage` round-trips.
- `Snapshot` custom Codable:
  - Dictionary ↔ array asymmetry round-trip.
  - Missing fields → defaults.
  - **Document** that duplicate `habitUUID` in payload crashes; do not test the crash.
- `ComplicationProjection.init(snapshot:)`:
  - Empty tasks → nils.
  - Incomplete-only tasks sorted by due, first picked.
  - Completed-only tasks → nil `nextTask`.
  - `isPomodoroActive` true when an active pomodoro is present.

## Wave 2 — Small refactors / in-memory SwiftData

### Step 16: Verify SwiftData test host behavior

Before writing tests that mutate `ClarityModelActor`:
1. Create a scratch test that instantiates `Containers.inMemory()` and `ClarityModelActor(modelContainer:)` and performs one harmless mutation (e.g., insert a `Category`).
2. Run it. If `WidgetFileCoordinator` file writes or `WidgetCenter.reloadAllTimelines()` throw or fail:
   - **Refactor:** introduce a `WidgetCoordination` protocol and a no-op test implementation; inject it into `ClarityModelActor` through its existing initializer path (or a new test-only initializer). Keep the production behavior unchanged.
3. If they do not throw, Wave 2 tests can proceed without a refactor.

Once the seam is verified/created, add:

#### `CompanionChatStoreTests.swift`

Target: `Clarity/Models/CompanionChatStore.swift`.

Use the existing `init(container:)` with `Containers.inMemory()`.

Test cases:
- `fetchRecent(limit:)` ascending order; `suffix(limit)` when limit < count, > count, and empty.
- `append(_:)` then `fetchRecent` round-trip.
- `deleteAll()` empties the store.
- `prune()`: message just inside 48h retained, just outside 48h deleted (build timestamps relative to now; no clock seam; allow ±1 minute tolerance).
- `enforceCap()`: exactly 100 messages → none removed; 101 messages → oldest removed.

#### `HabitFormStateTests.swift`

Target: `Clarity/Views/Habits/HabitFormState.swift`.

Test cases:
- `isValid`, `isTargetOutOfRange`, `isIncrementOutOfRange` per `HabitConfig` rules.
- `dailyTarget = step × count`.
- `load(habit:)` inverse math: `incrementCount = round(target / max(step, 1))` clamped ≥ 1.
- `applyHealthKitDefaultsIfNeeded()` per identifier: water → 250, steps → 500, workouts + mindful → 5, gated on `didEdit*` flags.
- `makeDTO(existing:)` clamping and the rule that health-linked habits nil the `unitLabel`.

#### `ClarityModelActorHabitTests.swift`

Target: `Shared/Data/ClarityModelActor.swift`.

Test cases:
- `logHabitProgress(_:amount:source:)`: threshold crossing sets `completed` and `completedAt`; **pin** that lowering an amount via `logHabitProgress` does **not** un-complete (contrast with `setHabitProgress`).
- `setHabitProgress(_:date:amount:)`: `max(amount, 0)` clamp; bidirectional completion (set below target → un-complete).
- `applyHealthKitProgress(_:value:)`: never decreases the current amount.
- `spendFreeze(_:)`: error paths `.noFreezesAvailable` and `.noFreezableMiss` (outside grace); happy path backfills an occurrence, sets `freezeUsed`/`completed`, and decrements counters.
- `reconcileFreezes(_:)`: arithmetic `max(min(streak.freezesEarned, maxFreezes) - freezesSpent, 0)`.
- `createNextOccurrence(_:)`: weekday mapping for `.specific` recurrence; characterize the app-weekday → Calendar-weekday normalization (`((appWeekday - 1) % 7 + 7) % 7 + 1` then +1 shift).
- Dedup winner ranking: if the comparator is extracted, test the (categories, count, earliest due, name, id) tie-breaker order.

#### `ClarityAppShellTests.swift`

Target: `Clarity/ClarityApp.swift` (non-UI migration helpers).

Test cases:
- `consumePendingStartTimerTaskId(appGroup:)` with an injected suite name:
  - valid UUID read-and-cleared,
  - missing → nil,
  - malformed → nil.
- `Migration.hasRun(forBuild:)` and `markRun(forBuild:)` per build.
- **Pin** `populateUUIDsIfNeeded(modelContext:minimumBuild:)` build-number comparison is lexicographic.

### Step 17: Extract-and-test small pure functions

For each, refactor the production code to expose a small, pure, internal helper or static function, then add tests. Keep diffs minimal.

1. `TaskSplitterService.parseResponse` in `Shared/Models/Intelligence.swift`:
   - Extract to an internal static function or a `TaskSplitParsing` enum.
   - Test malformed lines, missing `|`, non-numeric minutes like `"about 10"`, minutes clamped to 5...25, empty text → `[]`, unparseable non-empty text → single 15-minute fallback.
   - Mark tests with `@available(iOS 26, *)` if needed.

2. Heatmap math in `Shared/Views/Heatmap.swift`:
   - Extract `internal enum HeatmapMath` with `latenessRatio(for:completedAt:interval:)`, `intervalDuration(for:)`, and `buildDays(totalDays:tasks:referenceDate:)`.
   - Test early/nil completion → 0, late ratio capped at 1, interval-0 fallback, interval duration per recurrence, and day bucketing with injected `today`.

3. `CompanionService` output mapping in `Clarity/Models/CompanionService.swift`:
   - Extract `CompanionOutputMapper` (pure value type) covering `show(_:trigger:)` trimming, emotion fallback chain (`rawValue` → first supported emotion → `.happy`), and case-insensitive task-name matching gated on `trigger.allowsTaskSuggestion`.
   - Extract `isDuplicateCompanionMessage` logic: last message must be companion, never dedup when suggestion allowed, text equality.
   - Test `isModelCatalogError(_:)` with synthetic `NSError`s over domain/code matrix.

4. `ToDoTask.focusFilter(in:)` and `ToDoTaskDTO.focusFilter(in:)` in `Shared/Models/Todo.swift`:
   - Parameterize by passing settings data (or a `UserDefaults` instance) so the function is pure over the input.
   - Test show/hide × categories-empty matrix, uncategorized handling, and legacy `[String]` decode.

5. Recurrence badge in `Clarity/Views/Tasks/RecurrenceIndicatorBadge.swift` and `FilterMenuView.filteredCategories` in `Clarity/Views/Tasks/FilterMenuView.swift`:
   - Extract internal helpers and test the recurrence-description mapping and focus-filter set operations.

## Out of scope

Do not attempt unit tests for:
- `HealthKitService` / `HabitHealthKitSync` (hardware + HealthKit framework).
- `PomodoroSoundManager` (AVFoundation/filesystem).
- `PomodoroService` timer lifecycle, `ActivityKit`, `UNUserNotificationCenter` (integration territory).
- `ConnectivityTransport` / `PhoneConnectivityCoordinator` / `Store.handle(updatedTransaction:)` (WatchConnectivity/StoreKit; use StoreKitTest or UI tests instead).
- LLM live paths (`PomodoroSuggestionService`, `HabitSuggestionService`, `TaskSplitterService` async calls).
- `WidgetFileCoordinator` file I/O machinery (compression round-trips are acceptable if the app group works in the test host).
- `ToastView`, `CategoryLines`, `Logger`.
- `DataRepository` (unused singleton; recommend deleting it rather than testing).

## Execution order for the agent

1. Steps 1–15 in order. Each is self-contained and requires no production changes.
2. After each step, build and run the new tests; fix warnings/errors.
3. Step 16: run the host check, add the seam if needed, then add the SwiftData-backed suites.
4. Step 17: do the focused extractions one at a time, testing each immediately after.

## Estimated deliverables

- Wave 1: ~15 new test files, ~150+ tests, zero production changes.
- Wave 2: ~4 new test files + 5 small production extractions.
