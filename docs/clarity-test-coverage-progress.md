# Clarity Test-Coverage Progress Tracker

Plan: `/Users/craig/dev/Clarity/docs/clarity-test-coverage-plan.md`
Repo: `/Users/craig/dev/Clarity`
Started: 2026-08-09

## Wave 1 — Pure quick wins (COMPLETED)

All Wave 1 steps complete and passing. Full suite: **207 tests, 0 failures**.

| Step | File | Status | Notes |
|------|------|--------|-------|
| 1 | `StatisticsCalculatorTests.swift` | Completed | 26/26 passing; used `Calendar.current` for fixtures to match production code, disambiguated `Clarity.Category` from Objective-C `Category`. |
| 2 | `HabitConfigTests.swift` + `HabitErrorTests.swift` | Completed | 19/19 passing; pinned the global 10_000 cap on identifier-specific increment-step validation. |
| 3 | `PomodoroAlarmSoundTests.swift` | Completed | 11/11 passing. |
| 4 | `SwipeActionTests.swift`, `HeatmapSizeTests.swift`, `StatsTimeframeTests.swift` | Completed | 18/18 passing. |
| 5 | `HabitFormatterTests.swift` | Completed | 12/12 passing; water assertions are locale-shape tests. |
| 6 | `CategoryIconTests.swift` | Completed | 9/9 passing; pinned phone/bed order-dependence. |
| 7 | `HabitDTOTests.swift` + `HabitOccurrenceDTOTests.swift` | Completed | 12/12 passing. |
| 8 | `ToDoTaskDTOTests.swift` + `CategoryDTOTests.swift` + round-ups | Completed | 10/10 passing in `DTOCodableTests.swift`. |
| 9 | `TaskFilterTests.swift` | Completed | 13/13 passing. |
| 10 | `CompanionPersonalityTests.swift` | Completed | 12/12 passing. |
| 11 | `CompanionEnumTests.swift` | Completed | 9/9 passing. |
| 12 | `CompanionTaskContextTests.swift` | Completed | 11/11 passing. |
| 13 | `UserDefaultsExtensionsTests.swift` | Completed | 12/12 passing; marked `@Suite(.serialized)` to avoid shared UserDefaults interference. |
| 14 | `HabitStreakCalculatorGapTests.swift` | Completed | 10/10 passing; pinned at-risk boundary behavior and missedPeriod being the end of the failed week. |
| 15 | `ConnectivityWireTests.swift` | Completed | 10/10 passing; used fixed dates to avoid ISO8601 sub-second precision issues. |

## Wave 2 — Small refactors / in-memory SwiftData

| Step | File | Status | Notes |
|------|------|--------|-------|
| 16 | SwiftData host check + seam | Completed | `WidgetCoordination` protocol + `NoOpWidgetCoordinator` added; `ClarityModelActor.widgetCoordinator` static seam added; host-check passes. |
| 16 | `SwiftDataHostCheckTests.swift` | Completed | In-memory insert/fetch for Category and Habit passing. |
| 16 | `CompanionChatStoreTests.swift` | Completed | 9/9 passing; uses in-memory `ModelContainer`. |
| 16 | `HabitFormStateTests.swift` | Completed | 17/17 passing. |
| 16 | `ClarityModelActorHabitTests.swift` | Completed | 13/13 passing; pinned lowering amount via `logHabitProgress` does not un-complete. |
| 16 | `ClarityAppShellTests.swift` | Completed | 8/8 passing; added `Migration.reset` helper and `ClarityApp.currentBuild` extension to make shell helpers testable. |

## Wave 2 — Small refactors / in-memory SwiftData (COMPLETED)

| Step | File | Status | Notes |
|------|------|--------|-------|
| 16 | SwiftData host check + seam | Completed | `WidgetCoordination` protocol + `NoOpWidgetCoordinator` added; `ClarityModelActor.widgetCoordinator` static seam added; host-check passes. |
| 16 | `SwiftDataHostCheckTests.swift` | Completed | In-memory insert/fetch for Category and Habit passing. |
| 16 | `CompanionChatStoreTests.swift` | Completed | 9/9 passing; uses in-memory `ModelContainer`. |
| 16 | `HabitFormStateTests.swift` | Completed | 17/17 passing. |
| 16 | `ClarityModelActorHabitTests.swift` | Completed | 13/13 passing; pinned lowering amount via `logHabitProgress` does not un-complete. |
| 16 | `ClarityAppShellTests.swift` | Completed | 8/8 passing; added `Migration.reset` helper and `ClarityApp.currentBuild` extension to make shell helpers testable. |
| 17 | `TaskSplitParserTests.swift` | Completed | 8/8 passing; extracted `TaskSplitParser` from `TaskSplitterService.parseResponse`. |
| 17 | `HeatmapMathTests.swift` | Completed | 9/9 passing; extracted `HeatmapMath` with `latenessRatio`, `intervalDuration`, and `buildDays`. |
| 17 | `CompanionOutputMapperTests.swift` | Completed | 13/13 passing; extracted `CompanionOutputMapper` and `CompanionOutputValues` protocol. |
| 17 | `FocusFilterTests.swift` | Completed | 10/10 passing; extracted `FocusFilter` and `FocusFilterable` protocol. |
| 17 | `RecurrenceAndFilterMenuTests.swift` | Completed | 12/12 passing; extracted `RecurrenceDescription` and `CategoryFilter`. |

## Final verification

- [x] All new tests pass in `Clarity` scheme on iOS Simulator. **307 tests, 0 failures**.
- [x] No new warnings or errors.
- [ ] `swift-format` (if run on edits) left formatting consistent.
