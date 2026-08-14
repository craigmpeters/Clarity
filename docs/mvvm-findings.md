# MVVM Findings

Date: 2026-08-13

This document lists the remaining MVVM violations found while adding UI tests to Clarity. The two worst offenders (`TaskIndexView` and `TaskRowView`) were refactored as part of this work; the rest are deferred for future cleanup.

## Already resolved

- `TaskIndexView` (Clarity/Views/Tasks/TaskIndexView.swift): logic, store access, filtering, and task actions extracted into `TaskIndexViewModel` (Clarity/ViewModels/TaskIndexViewModel.swift).
- `TaskRowView` (Clarity/Views/Tasks/TaskRowView.swift): removed the `currentTaskSwipeAndTapOptions` computed property that inserted and saved a default `TaskSwipeAndTapOptions` model on every view evaluation. Swipe options are now resolved once by the parent and passed in as a value.

## Remaining violations

### `HabitsIndexView` (Clarity/Views/Habits/HabitsIndexView.swift)

- Owns the `ClarityModelActor` store.
- Performs HealthKit sync (`HabitHealthKitSync.shared.syncAllHabits()`).
- Handles Image Playground art generation (`generateArt`, `saveArtwork`).
- Contains business logic for streak/occurrence refresh and habit mutations (increment, set amount, complete anyway, use freeze, archive, delete).
- Suggested refactor: extract a `HabitsIndexViewModel` that owns the store, refresh logic, and all mutations; keep the view responsible only for rendering and forwarding user events.

### `ClarityApp` (Clarity/ClarityApp.swift)

- The App struct still creates the SwiftData container and runs migrations (`populateUUIDsIfNeeded`).
- Some lifecycle logic (widget snapshot refresh, pending timer intent consumption) lives in the App body.
- Suggested refactor: introduce a dedicated `AppLaunchCoordinator` or move container creation behind a factory owned by the `AppDelegate` / environment so the app entry point is purely declarative.

### `CategoryManagementView` (Clarity/Views/Settings/SettingsView.swift)

- Directly deletes categories from `modelContext` and removes the category from each related task inside the view.
- Suggested refactor: move delete logic into `ClarityModelActor` or a view model, and have the view call `store.deleteCategory(_)`.

### `PomodoroView` (Clarity/Views/Tasks/PomodoroView.swift)

- Creates `ClarityModelActor(modelContainer: context.container)` inside sheet and toast callbacks.
- Suggested refactor: inject a store or view model that provides `recordMood(valence:taskUUID:)` and `uncompleteTask(_)` methods so the view does not create actors on the fly.

### `HabitWizardView` / `HabitFormView` (Clarity/Views/Habits/)

- Both views create and manage the `ClarityModelActor` store directly and orchestrate saving/updating habits.
- Suggested refactor: share a `HabitFormViewModel` (or two small view models) that owns the store and form validation/save logic. `HabitFormState` already encapsulates validation; the remaining store work should move to a model.

### `TaskFormView` (Clarity/Views/Tasks/TaskFormView.swift)

- Owns the `ClarityModelActor` store and calls `addTask`/`updateTask` directly from the view.
- Suggested refactor: extract a `TaskFormViewModel` that owns the store and save logic; the view should hold only form state and UI presentation.

### `SettingsView` (Clarity/Views/Settings/SettingsView.swift)

- Reads and writes `UserDefaults` directly in the view (e.g., `healthKitEnabled`).
- Contains `buildInformation()` and `CategoryManagementView` as nested types.
- Suggested refactor: a lightweight `SettingsViewModel` can own the user-defaults state and expose the version string; category management should move to its own view model as noted above.

## Recommended next steps

1. Extract `HabitsIndexViewModel` (highest impact after the already-completed work).
2. Move category delete logic into the model actor.
3. Create `PomodoroViewModel` to remove actor creation from view callbacks.
4. Unify `TaskFormViewModel` and `HabitFormViewModel`.
5. Finally, move container/migration logic out of `ClarityApp`.
