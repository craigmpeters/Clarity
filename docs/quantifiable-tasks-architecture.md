# Architecture: Quantifiable Tasks ("Progress Tasks") for Clarity

**Status:** Approved design
**Scope:** iOS app, Widgets, App Intents (Siri/Shortcuts)
**Out of scope:** Watch UI, per-increment history logging
**Date:** 2026-08-07

---

## 1. Goal & Locked Design Decisions

Enable tasks like "Drink 5 glasses of water" that accumulate progress and complete when a target is reached.

| Decision | Choice |
| --- | --- |
| Coexistence | Opt-in per task (`isQuantifiable`); boolean tasks untouched |
| Completion | Auto-complete when `currentAmount >= targetAmount` |
| Reset | Reuse existing recurring mechanism — next occurrence starts at 0 |
| Increments | Fixed-step `+1` button AND arbitrary amount entry; counter only, no log/history model |
| Force complete | Allowed via context menu "Complete Anyway" (Option A) |
| Surfaces | Main app (list + form), interactive widget, App Intents |

---

## 2. Data Model Changes

**File:** `Shared/Models/Todo.swift`

### 2.1 `ToDoTask` (`@Model`) — add four stored properties

```swift
var isQuantifiable: Bool = false
var targetAmount: Double? = nil        // e.g. 5 (glasses); nil treated as 1
var incrementStep: Double = 1.0        // step for the quick-increment button
var currentAmount: Double = 0          // running tally
```

All properties have default values. This lets SwiftData lightweight migration and CloudKit schema evolution work without a custom migration plan. Do not make any of them non-optional without a default.

Add computed helpers (not stored):

```swift
var isTargetReached: Bool { isQuantifiable && currentAmount >= (targetAmount ?? 1) }

var progressFraction: Double {
    guard isQuantifiable, let t = targetAmount, t > 0 else { return 0 }
    return min(currentAmount / t, 1.0)
}
```

Do **not** change the stored `completed` semantics. Auto-completion writes `completed = true` when the target is hit, so every existing query (`#Predicate { !$0.completed }` in `TaskIndexView.swift:21`, widget `TaskEntity` query, statistics) keeps working unchanged.

### 2.2 `ToDoTaskDTO` — mirror the four fields

- Add the four fields to the struct, the memberwise `init` (with the same defaults), and `CodingKeys`.
- In `init(from decoder:)`, use `decodeIfPresent` with defaults (`false`, `nil`, `1.0`, `0`). **Required** so widget JSON files written by older app versions still decode through the `WidgetFileCoordinator` snapshot pipeline.
- In `encode(to:)`, encode `isQuantifiable`, `incrementStep`, `currentAmount`; `encodeIfPresent(targetAmount)`.
- Update `init(from model:)` to copy the four fields.

---

## 3. Repository Changes

**File:** `Shared/Data/ClarityModelActor.swift`

### 3.1 New method — `incrementTask`

```swift
func incrementTask(_ id: UUID, amount: Double? = nil) throws
```

Logic (mirrors `completeTask` at lines 316–363):

1. Fetch `ToDoTask` where `uuid == id && !completed`. Guard `task.isQuantifiable`; otherwise log and return.
2. `task.currentAmount += (amount ?? task.incrementStep)`.
3. If `task.currentAmount >= (task.targetAmount ?? 1)`:
   - Set `completed = true`, `completedAt = Date.now`.
   - If `repeating == true`, call `createNextOccurrence(task.id)` and `insertTask` (same pattern as lines 342–350).
4. Run the standard post-mutation pipeline: `modelContext.save()` → `WidgetFileCoordinator.shared.writeTasks(fetchRecentTasks())` → `WidgetCenter.shared.reloadAllTimelines()` → fire `onTaskMutated` (and `onTaskCompleted` if it auto-completed) → `deduplicateTasksByUUID()`.

The actor already serializes concurrent increments via the `@ModelActor`; no extra in-flight guard is needed.

### 3.2 New method — `setTaskProgress` (arbitrary entry / correction)

```swift
func setTaskProgress(_ id: UUID, amount: Double) throws
```

Sets `currentAmount = amount` (clamped to `>= 0`), then runs the identical target-check + post-mutation pipeline as `incrementTask`. This doubles as the undo/correct path since there is no history log.

### 3.3 Modify `uncompleteTask` (lines 366–396)

Also reset `task.currentAmount = 0`.

### 3.4 Modify `createNextOccurrence` (lines 438–520)

The new-occurrence `ToDoTaskDTO` must carry the quantifiable config and reset progress:

```swift
// add to the ToDoTaskDTO(...) constructor call:
isQuantifiable: task.isQuantifiable,
targetAmount: task.targetAmount,
incrementStep: task.incrementStep,
// currentAmount intentionally omitted → defaults to 0
```

### 3.5 `completeTask` (lines 316–363) — no guard in the actor

`completeTask` remains unconditional; it is the force-complete path. The "not yet at target" protection lives in the intent/UI layer (§4.2, §5.1), keeping the actor simple.

**Documented edge case:** the Pomodoro-finished path (`TaskIndexView.swift:89–100` → `store.completeTask`) force-completes a quantifiable task even when it is below target. Accepted behavior; do not special-case.

---

## 4. App Intents

**Directory:** `Widgets/Intents/`

### 4.1 New file: `IncrementTaskIntent.swift`

Mirror `CompleteTaskIntent.swift` structure:

- `static let title = "Log Task Progress"`, `openAppWhenRun = false`.
- `@Parameter(title: "Task") var task: TaskEntity`
- `@Parameter(title: "Amount") var amount: Double?` — optional; `nil` uses the task's `incrementStep`. Enables Shortcuts like "log 250 ml".
- `perform()`: resolve UUID from `task.id` → `store.fetchTaskByUuid` → guard `dto.isQuantifiable` (else dialog `"This task doesn't track progress."`) → `store.incrementTask(uuid, amount: amount)` → `ClarityServices.reloadWidgets(kind: "ClarityWidget")` → dialog `"Logged — \(newAmount) of \(target)"` (fetch DTO again post-mutation or compute from prior value + amount).

### 4.2 Modify `CompleteTaskIntent.swift`

Add `@Parameter(title: "Force") var force: Bool?` (default `nil`/`false`). In `perform()`, after fetching the DTO:

```swift
if dto.isQuantifiable && dto.currentAmount < (dto.targetAmount ?? 1) && force != true {
    return .result(dialog: "\(dto.name) is at \(Int(dto.currentAmount)) of \(Int(dto.targetAmount ?? 1)) — not at target yet.")
}
```

This prevents accidental below-target completion from the widget circle button while preserving force-complete for Shortcuts power users.

### 4.3 `TaskDetailEntity.swift`

Expose `isQuantifiable`, `currentAmount`, `targetAmount`, `incrementStep` as `@Property` fields so Shortcuts can read progress.

### 4.4 `TaskEntity.swift`

No change. Its query filters `!completed`, and auto-completion removes finished quantifiable tasks naturally.

---

## 5. Main App UI

### 5.1 `Clarity/Views/Tasks/TaskRowView.swift`

- Add callback `let onIncrement: () -> Void` alongside existing `onComplete`.
- When `task.isQuantifiable`:
  - Show progress: `Text("\(Int(task.currentAmount))/\(Int(task.targetAmount ?? 1))")` plus a small `ProgressView(value: task.progressFraction)` in the badge HStack.
  - Add a leading `+` button (`Image(systemName: "plus.circle.fill")`) calling `onIncrement`.
  - **Swipe-action mapping rule:** `SwipeAction.complete` in `performActionOption` calls `onIncrement()` when the task is quantifiable and below target; calls `onComplete()` otherwise. This prevents accidental force-complete via swipe.
  - Add `.contextMenu` on the row: **"Complete Anyway"** → `onComplete()`; **"Log Amount…"** → presents a sheet with a `TextField`/`Stepper` (Double) that calls a new `onSetProgress(Double)` callback.

### 5.2 `Clarity/Views/Tasks/TaskIndexView.swift`

- Add `private func incrementTask(_ task: ToDoTaskDTO)` → `Task { try? await store?.incrementTask(task.uuid) }` and `setProgress(_ task:amount:)` → `store?.setTaskProgress(...)`.
- Pass both as the new `TaskRowView` callbacks.
- No change to the `@Query` (line 21) — auto-completion flips `completed`.

### 5.3 `Clarity/Views/Tasks/TaskFormView.swift`

- New `@State` fields: `isQuantifiable`, `targetAmount`, `incrementStep` — initialized from `editingTask` in `init(task:)`.
- New `Section("Progress Tracking")`: `Toggle("Track progress", isOn: $isQuantifiable)`; when on, `Stepper("Target: …")` and `Stepper("Increment: …")` (or `TextField` with `.decimalPad`).
- In `saveTask()`, copy the three values into `toDoTask` before `addTask`/`updateTask`. When toggling a task from quantifiable to off, leave the amount fields in the DTO (ignored while `isQuantifiable == false`). When off to on, `currentAmount` stays 0.

---

## 6. Widget UI

**File:** `Widgets/Views/TaskRowInteractive.swift`

When `task.isQuantifiable`:

- Replace the Column-1 `CompleteTaskIntent` button with `Button(intent: IncrementTaskIntent(task:))` showing `plus.circle`.
- Show `"\(Int(task.currentAmount))/\(Int(task.targetAmount ?? 1))"` in the trailing metadata HStack alongside the category dot.
- Keep the Pomodoro play button.

**File:** `Widgets/Views/WidgetTaskRow.swift`

Show the same `n/m` progress text for quantifiable tasks.

---

## 7. What Explicitly Does Not Change

- `WidgetFileCoordinator` / snapshot pipeline — new DTO fields flow through `Codable`.
- `StatisticsCalculator` / weekly targets — auto-completed quantifiable tasks count like any completed task.
- Recurrence UUID-sharing and `deduplicateTasksByUUID` — untouched; increment always targets the single incomplete occurrence.
- Watch — receives updated snapshots via the existing `onTaskMutated` hook; no Watch UI work in this phase.

---

## 8. Implementation Order

1. `Todo.swift` — model + DTO + Codable + computed helpers
2. `ClarityModelActor.swift` — `incrementTask`, `setTaskProgress`, uncomplete reset, `createNextOccurrence` carry-over
3. Intents — new `IncrementTaskIntent`, `CompleteTaskIntent` force param/guard, `TaskDetailEntity` properties
4. App UI — `TaskFormView` section → `TaskRowView` progress/buttons/context menu → `TaskIndexView` wiring
5. Widgets — `TaskRowInteractive`, `WidgetTaskRow`
6. Build **all** targets (app, Widgets extension, AppIntents extension, Watch) and verify on-device: migration from existing store, CloudKit sync, widget timeline refresh, Siri phrase "Log progress on <task>".

---

## 9. Acceptance Checklist

- [ ] Existing boolean tasks behave identically (complete / uncomplete / recur)
- [ ] Quantifiable task: `+` increments by step; arbitrary entry sets exact amount
- [ ] Reaching target auto-completes (`completed = true`, `completedAt` set) and, if repeating, spawns next occurrence at 0 with same UUID
- [ ] "Complete Anyway" force-completes below target; widget/Shortcuts complete without `force` is refused with progress dialog
- [ ] Uncomplete resets `currentAmount` to 0
- [ ] Old widget JSON files still decode; old CloudKit records migrate without data loss
- [ ] Weekly progress counts auto-completed quantifiable tasks

---

## 10. Open / Optional Items

### 10.1 Decrement button

Currently progress can only be corrected via the **"Log Amount…"** context menu (absolute set). If desired, add a dedicated `−1` button next to the `+` button in `TaskRowView` and the widget. It would call `setTaskProgress(currentAmount - incrementStep)` (clamped to `>= 0`).

**Decision:** Leave out for now; re-evaluate if user testing shows the need for quick corrections.
