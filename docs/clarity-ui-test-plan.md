# Clarity UI Test Plan

Date: 2026-08-13
Status: Ready for build execution
Scope: UI-testing target for the iOS app (`Clarity.app`) covering all 5 tabs plus onboarding.

---

## Context & ground rules

- **Test target:** `ClarityUITests` is a new XCUITest bundle hosted in `Clarity.app`. It tests the app through the UI only; it does not import app source directly.
- **Framework:** Use **XCTest** (not Swift Testing). Apple does not support XCUITest UI automation from Swift Testing yet.
- **Deterministic data:** UI tests launch the app with a special argument set that forces the app to use an **in-memory SwiftData container** pre-seeded with the same data as `PreviewData`. This keeps tests fast, isolated, and avoids polluting the real CloudKit store.
- **Onboarding & companion:** Tests also pass launch flags that skip the onboarding sheet and disable the floating companion overlay so they cannot intercept taps or block the UI.
- **Tooling:** After every change, build the `Clarity` scheme and run the UI tests in the simulator. Fix all errors and warnings before continuing.
- **Accessibility:** Add minimal `accessibilityIdentifier`s to test-critical elements rather than relying on brittle text queries.
- **Minimal diffs:** Keep production changes small and test-focused. Do not refactor unrelated code.
- **No secrets:** No API keys or hardcoded credentials are involved.

---

## Business assumptions (correct if wrong)

1. The app ships with 5 tabs: Tasks, Habits, Focus, Stats, Settings.
2. Onboarding is a 3-page, non-dismissable sheet shown until the user taps **Get Started**.
3. The companion overlay is enabled by default and floats over every tab.
4. The default task swipe actions are: leading = complete, trailing = delete + edit (or whatever the seeded `TaskSwipeAndTapOptions` defines).
5. HealthKit, ImagePlayground, Apple Intelligence, and StoreKit flows are unavailable in the simulator and are only tested for graceful degradation.
6. Deployment target is iOS 18.0 as configured in `project.pbxproj` (AGENTS.md says iOS 17; this discrepancy should be resolved separately).

---

## Phase 1 — App-side test hooks and testability

### 1.1 Launch-argument hook in `ClarityApp.swift`

- Add `ProcessInfo.processInfo.arguments.contains("--uitesting")` check.
- When present, replace `Containers.liveApp()` with an in-memory container seeded from `PreviewData` (or a shared seeding helper).
- Also support:
  - `--uitesting-skip-onboarding` → forces `UserDefaults.hasCompletedOnboarding = true`.
  - `--uitesting-disable-companion` → forces `UserDefaults.companionEnabled = false`.
- Replace the `try! Containers.liveApp()` force-try with a failable path that falls back to the in-memory container and logs an error (per AGENTS.md).

### 1.2 Minimal accessibility identifiers

Add the following identifiers to the app UI:

- Tab bar: `tab-tasks`, `tab-habits`, `tab-focus`, `tab-stats`, `tab-settings`
- `TaskIndexView`: `task-add`, `task-list`
- `TaskFormView`: `task-form-name`, `task-form-save`, `task-form-cancel`
- `HabitsIndexView`: `habit-add`, `habit-list`
- `HabitWizardView`: `habit-wizard-next`, `habit-wizard-save`, `habit-wizard-name`
- `SettingsView`: `settings-categories`, `settings-notifications`, `settings-swipe`, `settings-appicon`
- `CompanionOverlayView`: `companion-bubble`
- `FirstRunView`: `onboarding-next`, `onboarding-get-started`, `onboarding-back`

---

## Phase 2 — MVVM refactors (worst two before tests)

### 2.1 `TaskIndexView` → `TaskIndexViewModel`

- Extract an `@Observable` view model.
- Move into it: `store`, `selectedFilter`, `selectedCategory`, `filteredTasks` computation, `editTask`, `deleteTask`, `completeTask`, `startTimer`, `logDuplicateTasks`, `dumpTask`.
- View holds only `@Binding selectedTask`, sheet state, and rendering.
- Keep the `@Query` for tasks/categories on the view or pass the results into the model; whichever is cleaner after the first attempt.

### 2.2 `TaskRowView` side-effect fix

- The `currentTaskSwipeAndTapOptions` computed property (lines 24–34) inserts a default model and saves it on every view evaluation.
- Move default-options resolution into an explicit loader (`.task` or view model) or make the store responsible for materializing defaults.
- Pass the resolved `TaskSwipeAndTapOptions` into the view as a plain value.

### 2.3 MVVM findings document

Create `docs/mvvm-findings.md` listing remaining violations for later work:

- `HabitsIndexView`: owns store, HealthKit sync, and image-playground art generation.
- `ClarityApp`: migrations and container creation live in the App struct.
- `SettingsView.CategoryManagementView`: directly deletes categories from `modelContext`.
- `PomodoroView`: creates `ClarityModelActor` inside sheet callbacks.

---

## Phase 3 — `ClarityUITests` target

### 3.1 Create the target

- New target: **UI Testing Bundle**.
- Product name: `ClarityUITests`.
- Bundle identifier: `me.craigpeters.clarity.ClarityUITests`.
- Host application: `Clarity`.
- Language: Swift.
- Target iOS 18.0 (matches project).

The stale `ClarityUITests.xctest` references in `Clarity.xcscheme` will resolve once this target exists.

### 3.2 Test harness

File: `ClarityUITests/UITestCase.swift`

- Base `XCTestCase` subclass.
- `setUpWithError()`:
  - `continueAfterFailure = false`
  - `app = XCUIApplication()`
  - `app.launchArguments = ["--uitesting", "--uitesting-skip-onboarding", "--uitesting-disable-companion"]`
  - `app.launch()`
- Helpers:
  - `switchToTab(_ identifier: String)`
  - `waitForExistence(timeout: TimeInterval)`
  - `skipOnboarding()` for the one onboarding test that exercises the real flow

### 3.3 Test files

| File | Coverage |
|------|----------|
| `OnboardingUITests.swift` | 3-page onboarding flow; Next/Back navigation; page indicator; Get Started dismisses sheet and lands on Tasks tab. |
| `TaskListUITests.swift` | Seeded tasks render; filter menu (All/Overdue/Today/Tomorrow/This Week); category filter; add button opens task form. |
| `TaskFormUITests.swift` | Create task (name, quick date, repeat toggle, recurrence picker, category select, Save); Save disabled when name empty; Cancel; Edit existing task. |
| `TaskSwipeUITests.swift` | Swipe actions match default options; complete via swipe; delete via swipe → confirmation dialog → Delete/Cancel. |
| `HabitUITests.swift` | Habits list sections (Streak at Risk / Today); 4-step wizard (type → amount → schedule → finish → Save); increment button; log-amount sheet; delete confirmation. |
| `PomodoroUITests.swift` | Focus tab idle state; start timer from a task row; active timer card appears; stop timer; recent sessions list; mood sheet surfaces on completion. |
| `StatsUITests.swift` | Statistics renders: timeframe pills, overview cards, category chart, heatmap, streaks, habit streaks; export menu opens. |
| `SettingsUITests.swift` | Rows navigate (Categories, Notifications, App Icon, Swipe Options, Companion); category add/edit/delete flow; version row shows build info. |

### 3.4 Target test count estimate

~25–35 test methods across the 8 files.

---

## Phase 4 — Shared test plan

### 4.1 New file: `Clarity.xctestplan`

A single JSON test plan at the repo root covering both test bundles:

- Test targets:
  - `ClarityTests` (unit) — `parallelizable: true`
  - `ClarityUITests` (UI) — `parallelizable: false`
- Default configuration:
  - `testTimeoutsEnabled: true`
  - `defaultTestExecutionTimeAllowance: 60`
  - `maximumTestExecutionTimeAllowance: 120`
  - `testRepetitionMode: "retryOnFailure"`
  - `maximumTestRepetitions: 2`
  - `failureScreenshotsEnabled: true`
  - Code coverage enabled for the `Clarity` app target only

### 4.2 Scheme wiring changes

In `Clarity.xcscheme`:

- Set `shouldAutocreateTestPlan = "NO"`
- Replace the `<AutocreatedTestPlanReference/>` and the `<Testables>` block with a `<TestPlans>` reference pointing at `Clarity.xctestplan`
- Leave other schemes (Watch, Widgets, Internal Testflight) unchanged.

### 4.3 Optional second plan

If desired, add `ClarityUIOnly.xctestplan` containing only `ClarityUITests` for fast local UI-test iteration. This is optional and not in the initial scope unless requested.

---

## Verification checklist

- [ ] App builds with no errors or warnings after Phase 1.
- [ ] `TaskIndexView` and `TaskRowView` refactors pass existing unit tests.
- [ ] `ClarityUITests` target builds and links.
- [ ] All 8 UI test files pass on an iPhone simulator in the `Clarity` scheme.
- [ ] `Clarity.xctestplan` is picked up by the scheme and both test bundles run from it.
- [ ] `swift-format` leaves formatting consistent if run on edits.
- [ ] `docs/mvvm-findings.md` is created with the remaining violations.

---

## Risks and notes

- **Auto-retry masks flaky tests.** Keep `maximumTestRepetitions` at 2 and treat any retrying test as a bug to fix.
- **Pomodoro timing.** Real timer durations are not exercised; tests verify state transitions and UI appearance only.
- **Simulator-only capabilities.** HealthKit, Apple Intelligence, and StoreKit tests are limited to the unavailable/fallback paths.
- **Deployment target mismatch.** AGENTS.md says iOS 17; `project.pbxproj` says iOS 18.0. The UI tests target iOS 18.0 to match the project. Resolve the mismatch separately.
