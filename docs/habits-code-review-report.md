# Habits Feature — Code Review & Refactoring Report

**For:** coding model handoff  
**Date:** 2026-08-08  
**Baseline:** `docs/habits-architecture.md` (the "doc")  
**Scope:** All new/modified files in the uncommitted Habits diff (see `git status`)

---

## 0. How to read this report

- **Part 1 — Bugs (must fix):** functional defects that ship broken behavior.
- **Part 2 — Design deviations (must reconcile):** code that diverges from the doc; either fix the code or amend the doc.
- **Part 3 — Refactoring recommendations:** structural/code-quality improvements, prioritized.
- **Part 4 — Feature work (user-requested):** (a) AI-suggested habit defaults to replace the free-text Unit field, (b) per-habit AI-generated background art, (c) additional improvements.
- **Part 5 — Acceptance checklist delta:** what still must be true before merge.

Every finding cites file and line. No code below is applied — this is instruction only.

---

## PART 1 — BUGS (functional defects)

### P0 — Freeze economy is never credited (dead feature)
**Files:** `Shared/Models/HabitStreakCalculator.swift:127`, `Shared/Data/ClarityModelActor.swift:225-248`  
`HabitStreakCalculator` computes `freezesEarned = currentStreak / 7` but **no code anywhere adds earned freezes to `Habit.streakFreezes`**. `spendFreeze` only decrements. Result: `streakFreezes` stays `0` forever → `atRisk` is always `false` (calculator guards `freezes > 0`) → the "Streak at Risk" section and "Use Freeze" button are **unreachable dead UI**.

**Fix:** After any mutation that advances a streak (in `logHabitProgress` / `setHabitProgress` post-pipeline), compute `freezesEarned` and reconcile `habit.streakFreezes = min(earned - spent, 3)`. Persist a running `freezesSpent` counter or recompute deterministically from history. Enforce the cap-3 here (currently unenforced anywhere). Add a unit test (see P0-2).

### P0 — No unit tests at all
**Missing:** `ClarityTests/HabitStreakCalculatorTests.swift` (doc §5.2 mandates it). There is **no test target/file in the repo**. The streak loop has three subtle defects (below) that are only catchable by tests.

**Fix:** Create the test target and the cases the doc lists: daily 7/7, 3×/week, freeze-preserves-streak, grace-window expiry, week-boundary edges.

### P1 — Weekly dots can only ever fill *today's* dot
**Files:** `Clarity/Views/Habits/HabitRowView.swift:122-130` + `Clarity/Views/Habits/HabitsIndexView.swift:108-117`  
`WeeklyDotsView.dayCompleted(_:)` compares against a single `occurrence`, and the index view only passes **today's** occurrence (`history.first { inSameDayAs: Date() }`). The other 6 dots can never fill. Doc §8.3 requires "7 circles, filled for completed/frozen days this week."

**Fix:** Pass the full 7-day `[HabitOccurrenceDTO]` into `HabitRowView`/`WeeklyDotsView` and look up each day.

### P1 — Log-amount sheet prefill is always 0
**Files:** `Clarity/Views/Habits/HabitsIndexView.swift:190-222` (sheet), `:218` (`amount = habit.currentAmount`)  
The sheet seeds from `HabitDTO.currentAmount`, but `HabitDTO.init(from:)` **never populates** the occurrence-derived fields (`Shared/Models/HabitDTO.swift:66-81`), and the index view keeps occurrence data in a *separate* `occurrences` dictionary. The doc says "Log amount… sets the occurrence's currentAmount to an absolute value" (the correct/undo path) — but it always opens at 0, so the user can't see what they're correcting.

**Fix:** Seed the sheet from the same `occurrences[habit.uuid]` map the row uses.

### P1 — Archived habits can never be deleted or unarchived
**File:** `Shared/Data/ClarityModelActor.swift:97-107, 174-184`  
`habitByUUID` throws "Habit is archived" (code 11) for archived habits. Both `archiveHabit` and `deleteHabit` call it — so an archived habit is undeletable and un-unarchivable.

**Fix:** Add a `fetchHabitIncludingArchived(_:)` for delete/unarchive paths; keep the archived-guard only on progress/logging methods.

### P1 — Crash risk on watch: unclamped index into live array
**File:** `Watch/Views/WatchHabitsView.swift:29`  
`habits[selectedIndex].name` is guarded only by `isEmpty`. `habits` is computed from a live snapshot; if it shrinks (habit archived on phone) while `selectedIndex` is past the end → **index-out-of-range crash**.

**Fix:** Clamp (`min(selectedIndex, habits.count - 1)`) or key selection by habit `uuid` instead of positional index. Also change `ForEach(..., id: \.offset)` (line 21) to stable identity.

### P1 — Daily-target TextField bypasses its own stepper bounds
**File:** `Clarity/Views/Habits/HabitFormView.swift:33-39`  
The `Stepper` enforces `1...1000`, but the adjacent `TextField` has **no validation** — `0`, `-5`, `99999` all save. The actor also validates nothing.

**Fix:** Validate on save (clamp or reject with an alert) *and* validate in `addHabit`/`updateHabit` in the actor. See also Part 4a — this whole section is being redesigned.

### P2 — `Int()` truncation hides fractional progress
**Files:** `Clarity/Views/Habits/HabitRowView.swift:91`, `Shared/Models/HabitDTO.swift:55`, `Watch/Views/WatchHabitsView.swift:77`  
`"\(Int(currentAmount)) / \(Int(dailyTarget))"` truncates — a target of `2.5` shows "2"; progress `1.9/2.5` shows "1 / 2". Increment step supports `0.1` granularity but the UI can never display it.

**Fix:** Format with a `NumberFormatter`/`.formatted()` that trims trailing zeros (e.g. `2.5` not `2.50`, `3` not `3.0`).

### P2 — Watch "streak" is fake and watch dots are decorative
**File:** `Watch/Views/WatchHabitsView.swift:55, 80-86`  
Streak shows `currentAmount >= dailyTarget ? 1 : 0` (not a real streak); the 7 dots are hardcoded empty gray circles with no data binding. Neither is marked `// TODO`.

**Fix:** Either wire real data (streak + week occurrences must be added to the watch `Snapshot` — currently `Snapshot.habits` carries no occurrence/streak data, see Part 2-D4) or remove the placeholders for v1.

### P2 — Siri dialog malformed when `unitLabel` is nil + stale-read race
**File:** `Widgets/Intents/LogHabitProgressIntent.swift:44-50`  
- With nil unit, dialog renders `"Logged — 3 of 5 ."` (double space, dangling space).
- `IntentDialog(stringLiteral:)` over an interpolated string is **unlocalizable**.
- Reads `habits.json` immediately after `store.logHabitProgress` returns, assuming the actor's post-mutation write finished synchronously — implicit undocumented race; on a miss, `?? 0 / ?? 1` fallbacks make Siri announce "Logged — 0 of 1 ."

**Fix:** Have the actor return the updated `HabitOccurrenceDTO` and build the dialog from it (no file round-trip); conditionally include the unit; use a localizable `IntentDialog` with `LocalizedStringResource` interpolation.

### P2 — `readHabits` swallows corruption → empty-state cascade
**File:** `Shared/Data/FileCoordinator.swift:433-437`  
`readHabits() -> [HabitDTO]` is non-throwing; decode failure returns `[]`, indistinguishable from "no habits." `WatchSnapshotStore.requestInitialSnapshot` fallback then builds an empty snapshot and `persistSnapshot` **writes it back**, cascading a transient corruption into data loss. Also: doc §6.1 specifies `throws -> [HabitDTO]` — signature mismatch.

**Fix:** Make it `throws`, propagate errors, and never persist a fallback-derived empty snapshot over a decode failure. Also add `NSFileCoordinator` protection (tasks have it; habits don't).

---

## PART 2 — DESIGN DEVIATIONS (reconcile code ↔ doc)

| # | Doc § | Deviation | Action |
|---|---|---|---|
| D1 | §2/§13 | Freeze auto-earn never wired; cap-3 unenforced | Fix (Part 1, P0) |
| D2 | §5.2 | Test target missing | Fix (P0) |
| D3 | §2/§5.1 | Grace window implemented as `missedPeriod + 1 day`, not "end of next period" | **Decide:** implement end-of-next-week grace, or amend doc. Currently freeze is spendable only on the Monday after a failed week — much harsher than spec. Duplicated in calculator *and* `spendFreeze` (magic `+1 day`). |
| D4 | §3.2 | `HabitDTO` carries stored occurrence fields (`currentAmount`, `completed`, `completedAt`, `freezeUsed`, `periodStart`) with a comment claiming "not persisted" — but synthesized `Codable` **does** encode them to `ClarityHabits.json` and the watch `Snapshot`. They're also never populated by `init(from:)`, so the DTO helpers `isTargetReached`/`progressFraction`/`periodDescription` are dead/wrong. | **Decide:** either (a) split occurrence state out of `HabitDTO` into a separate `HabitProgressDTO` (cleaner; UI already keeps them separate), or (b) populate them in a `init(from:with occurrence:)` and fix the comment. Recommend (a). |
| D5 | §3.2 | `HabitDTO`/`HabitOccurrenceDTO` lack custom `init(from:)` with `decodeIfPresent` defaults → any future schema field breaks decoding of existing `ClarityHabits.json` (the exact problem `Snapshot` already solves manually in `ConnectivityWireTypes.swift:52`). | Add `decodeIfPresent` custom decoding. |
| D6 | §5.1 | `freezesEarned = currentStreak / 7` where `current` counts **weeks** → 1 freeze per 7 *weeks*. Doc design table says "per 7-*day* streak." Doc self-contradicts; code follows §5.1 text. | **Decide & amend doc.** Resolve the day-vs-week rate. |
| D7 | §5.1 | In-progress current week zeroes `current` streak: on Tuesday of a 7×/week habit, `currentWeekSucceeded == false` → streak shows `0` all week even with 20 prior successful weeks. | **Decide:** treat in-progress week as streak-preserving until it fails, or accept and document. Recommend streak = past consecutive successful weeks + (current week if succeeded *or still in progress*). |
| D8 | §7.2 | `HabitQuery.allEntities()` returns **all** habits (no `isArchived`/incomplete filter); no `EntityStringQuery`/`entities(matching:)` for robust spoken-name resolution. | Filter archived; consider `EntityStringQuery` so "Log progress on Drink Water" resolves by name. |
| D9 | §8.2 | Toolbar leading **filter/category menu not implemented** (only trailing `+`). | Implement or amend doc. |
| D10 | §8.3 | Context-menu **Delete has no confirmation** (doc explicitly requires it). | Add `.confirmationDialog`. |
| D11 | §8.5 | `HabitStreaksView` in Stats **does not exist** — no per-habit streak/longest/freeze-balance UI. Only an unrelated task-streak `StreakView` and a `habitSuggestion` companion trigger. | Implement `HabitStreaksView`. |
| D12 | §10.1 | Watch tap target is the inner `+` button only, not "tap anywhere on the circle"; vertical paging vs doc's "swipe left/right" (doc self-contradicts). | Make the whole ring tappable; amend doc to "swipe up/down." |
| D13 | §10.2 | `WatchSnapshotStore.logHabitProgress(habit)` takes the whole DTO and does **no optimistic update** (doc requires optimistic update before sending). | Add optimistic local increment + reconciliation (tasks have `optimisticallyCompleted`; habits have nothing). |
| D14 | §6.1 | File named `ClarityHabits.json` vs doc's `habits.json`. | Trivial — amend doc. |
| D15 | §4.1 | `logHabitProgress(..., source: String)` accepts `source` then **discards it** — no `source` field on `HabitOccurrence`. | Add `source` to model or drop the param. Needed for HealthKit v2 attribution anyway. |
| D16 | §13 | **Localization failed:** ~28 new habit keys exist in `Localizable.xcstrings` with **zero translations** in any of en/de/es/fr/zh-Hans; several in-code strings have no keys at all (`"Today"`, `"Cancel"`, `"Save"`, `"Target"`, `"Categories"`, watch strings, the Siri dialog, the `"day"/"days"` manual plural). | Full localization pass. Replace manual plural with `^[%d day](inflect: true)` / stringsdict. |

---

## PART 3 — REFACTORING RECOMMENDATIONS (prioritized)

### R1 — Eliminate the dual source of truth in `HabitsIndexView`
**File:** `HabitsIndexView.swift:7-8, 83-85`  
Subscribes `@Query private var habits: [Habit]` but never renders from it — it's only a change trigger; rendering uses separately-fetched `habitDTOs`. Wasteful (SwiftData fetch + diff on every change) and confusing.

**Refactor:** Pick one. Either render from `@Query` and derive DTOs in-memory, or drop `@Query` and observe the actor's mutation hook. Given the actor owns occurrence merging, keep the actor as source and drive refresh off `onHabitMutated`.

### R2 — Fix N×2 sequential actor fetches per refresh
**File:** `HabitsIndexView.swift:101-121`  
`refresh()` loops every habit doing **two** sequential `fetchHabitHistory` calls (7-day + 365-day). The 7-day result is derivable from the 365-day one. This runs after *every* mutation.

**Refactor:** One fetch per habit (or a single batched `fetchHabitHistories(uuids:from:to:)`), run concurrently (`async let` / `TaskGroup`), derive today + week + streak from the single result set.

### R3 — Replace O(n) full-relationship scans in the actor
**File:** `ClarityModelActor.swift:104-121, 230-236`  
`todayOccurrence` force-loads `habit.occurrences` and linear-scans for a day match (365+ elements after a year, every tap). `spendFreeze` DTO-maps the *entire* history.

**Refactor:** Use a `FetchDescriptor<HabitOccurrence>` with a `#Predicate` on `habit.uuid == … && periodStart >= startOfDay && periodStart < endOfDay` — O(log n) at the store, no full fault.

### R4 — Consolidate the three periodDescription/progressFraction implementations
**Files:** `HabitDTO.swift:53-55`, `HabitRowView.swift:89-91`, `WatchHabitsView.swift:77, 91-93`  
The same formatting/fraction logic is hand-duplicated in three places (and the DTO's own version is dead because its fields aren't populated — Part 2 D4).

**Refactor:** After resolving D4, keep **one** canonical implementation on the DTO/progress type; views consume it. Fix the `Int()` truncation (P2) in that one place.

### R5 — Standardize error handling; kill stringly `NSError` codes and pervasive `try?`
**Files:** `ClarityModelActor.swift` (codes 10-13), `FileCoordinator.swift:433-437`, `WatchSnapshotStore.swift:66-68, 78`, `PhoneConnectivityCoordinator.swift:96-99`  

**Refactor:** Introduce a typed `HabitError: Error` enum (`notFound`, `archived`, `noFreezesAvailable`, `noFreezableMiss`, `persistenceFailed(underlying:)`). Replace `try?`-swallowing in the snapshot path with logged, surfaced failures. Add a negative-ack to the watch so a failed `logHabitProgress` doesn't get a success-looking broadcast (`PhoneConnectivityCoordinator.swift:96-102` currently logs + broadcasts regardless).

### R6 — Concurrency hygiene
**Files:** `ClarityModelActor.swift:27` (`nonisolated(unsafe) static var onHabitMutated`), `FileCoordinator.swift:58` (`@unchecked Sendable`, `nonisolated(unsafe) var presenter`)  

**Refactor:** The mutation hooks are unsynchronized cross-actor mutable statics (matches existing `onTaskMutated` house style, but a real Swift 6 data-race risk). Move to a `MainActor`-isolated registry or an `AsyncStream` of mutation events. Also: no in-flight dedup for habit logging (tasks have `inFlightCompletions`) — add one so rapid widget taps / WatchConnectivity `transferUserInfo` redelivery can't double-increment.

### R7 — De-duplicate actor logic
**File:** `ClarityModelActor.swift:123-197`  
The category-resolution block is copy-pasted verbatim between `addHabit` and `updateHabit` (and matches categories by `name` fallback → renaming a category silently re-links habits to a same-named different category).

**Refactor:** Extract `resolveCategories(from dtos:)`. Match by stable id, not name.

### R8 — Un-nest NavigationStacks
**File:** `Clarity/Views/ContentView.swift:31` + `HabitsIndexView.swift:17,55`  
`ContentView` wraps `HabitsIndexView()` in a `NavigationStack` with `.navigationTitle("Habits")`, and `HabitsIndexView` has its *own* `NavigationStack` + same title → nested stacks, dead outer title, SwiftUI toolbar/nav-bar quirks. Same pattern repeats for Tasks/Stats/Settings.

**Refactor:** Single `NavigationStack` owner — either the tab host or each tab root, not both.

### R9 — Magic numbers & constants
**Files:** `HabitStreakCalculator.swift` (7-day period, 1-day grace, /7 rate), `HabitsIndexView.swift:109` (`7*24*60*60`, `365*...`), `PhoneConnectivityCoordinator.swift:121` (500 ms debounce), `HabitFormView.swift` (1...1000, 0.1...100/0.5)  

**Refactor:** Centralize into a `HabitConfig` enum (`periodDays = 7`, `maxFreezes = 3`, `freezeEarnIntervalDays`, `gracePeriod`, `targetRange`, `stepRange`). The calculator's grace `+1 day` and `spendFreeze`'s `+1 day` must read from the same constant (Part 2 D3).

### R10 — Accessibility pass (currently zero)
All three Habits views and the watch view lack `.accessibilityLabel`/`.accessibilityValue`/`.accessibilityHint`. The primary interaction (progress ring `+` button) reads as "plus, button" with no habit context; freeze-vs-complete dots are color-only.

**Refactor:** Label the ring/button with habit name + "log progress," give the ring an `.accessibilityValue` of the fraction, differentiate dots by shape/label not just color.

### R11 — Misc cleanups
- `HabitOccurrenceDTO.swift:120` — orphaned occurrence falls back to `?? UUID()` (random habit uuid, silently corrupts attribution). Throw/skip instead.
- `HabitEntity.swift:10` — unused `XCGLogger` import; `dailyTarget`/`incrementStep` carried but never read.
- `HabitsIndexView.swift:6` — dead `@Environment(CompanionService.self)`; `:188` retroactive `HabitDTO: Identifiable` in a view file (move to DTO); `:124,136,152,164,176` repeated silent `guard let store`.
- `HabitFormView.swift:60` — redundant ternary `option == "None" ? "None" : option`; `:64` disabled HealthKit picker shipped (hide it instead of showing dead UI); `:76` `name.isEmpty` not trimmed; `:118-121` save errors only logged, no alert.
- `HabitStreakCalculator.swift:18-20` — redundant manual `Codable` re-declaring synthesized keys.
- `Shared/Models/Intelligence.swift:67` — leftover `print("Apple Intelligence Response: …")`; `:23` `temperature: 2.0` for a structured-parsing task (too high); `CompanionService.swift:529` — string-matching the FoundationModels error domain (fragile).
- `StatsView.swift:214` — CSV export appends trailing comma per row; `:544-566` `CategoryBadge` runs a `@Query` **per badge instance**.

---

## PART 4 — FEATURE WORK (user-requested)

### 4a. Replace the free-text Unit field with AI-suggested habit defaults
**User decision:** AI-suggested defaults.

**Current:** `HabitFormView.swift:29-31` — free-text `TextField("e.g. glasses, pages, minutes")`, no validation, no suggestions, purely cosmetic, not trimmed.

**Goal:** As the user types the habit name, use Foundation Models to propose **unit, daily target, and increment step** as a tappable suggestion. The fields stay editable; the suggestion is a starting point, not a lock-in.

**Implementation plan:**
1. **New service** `Shared/Models/HabitSuggestionService.swift`, modeled on the existing `TaskSplitterService`/`PomodoroSuggestionService` (`Shared/Models/Intelligence.swift`). Gate `@available(iOS 26.0, *)` and `#if canImport(FoundationModels)`, check `SystemLanguageModel.default.availability` (see `CompanionService.swift:223` for the pattern).
2. **Guided generation** — define a `@Generable struct HabitSuggestion` with `@Guide` fields, mirroring `CompanionOutput` (`CompanionService.swift:92-105`):
   - `unitLabel: String` (e.g. "glasses", "pages", "minutes")
   - `dailyTarget: Double`
   - `incrementStep: Double`
   Use a low temperature (~0.3–0.5) — this is structured extraction, not creative writing (contrast with the existing `temperature: 2.0` mistake in `TaskSplitterService`).
3. **UI** — in `HabitFormView`, debounce the `name` field; when a suggestion arrives and the user hasn't manually overridden the fields, show an inline suggestion chip (e.g. "💡 8 glasses, +1 step") that the user taps to accept, or auto-fill with a visible "Suggested" affordance and keep everything editable. Track a `didEditUnit` flag so typing over the suggestion doesn't get clobbered.
4. **Fallback:** if Apple Intelligence is unavailable (`SystemLanguageModel.default.availability != .available`), the form behaves exactly as today (plain text field). No preset picker needed per the user's decision.
5. **Validation:** regardless of AI, on save trim `unitLabel`, clamp `dailyTarget`/`incrementStep` to `HabitConfig` ranges (R9), and reject empty/whitespace.

### 4b. Per-habit AI-generated background art (Image Playground)
**User decision:** per-habit generated art.

**Note:** No `ImagePlayground`/`ImageCreator` code exists anywhere in the repo today — this is net-new (unlike 4a, which extends existing FoundationModels usage).

**Implementation plan:**
1. **New service** `Shared/Models/HabitArtService.swift` using the **ImagePlayground** framework (`ImagePlaygroundViewController` for a picker UI, or the on-device generation API) to generate an image from a prompt built from the habit name + unit (e.g. "minimalist soft gradient illustration, drinking water, calm").
2. **Storage** — persist the generated `CGImage`/PNG data to the **App Group container** (so the watch and widgets can read it via the existing `WidgetFileCoordinator` pattern), keyed by habit `uuid`. Store only a reference (filename) on the `Habit` model (`var artworkFilename: String?`) — do **not** store image blobs in SwiftData/CloudKit.
3. **Sync to watch** — image data does not ride the `Snapshot` (too large). Transfer the file via WatchConnectivity `transferFile` and cache on the watch side.
4. **UI** — render as a dimmed/blurred background behind the progress ring in `HabitRowView` and `WatchHabitPage`, with a scrim so the ring/text stay legible. Fall back to the current plain `Color.secondary.opacity(0.2)` track when no art exists.
5. **Availability/perf** — generation is async and best-effort; never block the row on it. Respect user opt-out and the existing `NSFoundationModelsUsageDescription` privacy string pattern.

### 4c. Additional improvements (recommended)
1. **Wire the freeze economy end-to-end** (Part 1 P0) — this is the single biggest user-facing gap; the entire "Streak at Risk"/"Use Freeze" loop is currently decorative.
2. **Optimistic watch increment** (Part 2 D13) — the watch UI currently lags a full phone round-trip + 500 ms debounce; optimistic local update makes it feel instant.
3. **Real watch streak + dots** (Part 1 P2) — add per-habit `currentStreak` and the 7-day occurrence bitmap to the `Snapshot` (small, fixed-size) so the watch shows real data instead of placeholders.
4. **Negative-ack + retry on watch commands** (R5) — failed logs currently vanish silently.
5. **`HabitStreaksView` in Stats** (Part 2 D11) — per-habit current/longest streak + freeze balance; data already exists via `HabitStreakCalculator`.
6. **Notification cadence** — the doc's §14 lists "smart reminders per-habit based on weekly frequency and current streak" as v2; consider pulling the at-risk reminder forward since `atRisk` is already computed.
7. **Feed habits into the Companion** — `CompanionService`'s `habitSuggestion` trigger currently only sees *task* data; injecting habit streaks/at-risk state would make the companion contextually aware of habits.

---

## PART 5 — ACCEPTANCE CHECKLIST DELTA (doc §13)

| Criterion | Status |
|---|---|
| `ToDoTask` behavior unchanged | ✅ (tasks untouched) |
| Habits/Tasks tab separation | ✅ |
| `+` logs `incrementStep` into today's occurrence | ✅ |
| "Log amount…" sets absolute `currentAmount` | ⚠️ works but prefill broken (P1) |
| `unitLabel` in rows/forms/dialogs/Siri | ⚠️ present; Siri dialog malformed on nil + unlocalizable (P2) |
| Target reached → `completed`/`completedAt` | ✅ |
| Weekly goal = frequency completed days | ⚠️ streak zeroes on in-progress week (D7) |
| Freeze auto-earn/cap-3/manual-spend-in-grace | ❌ auto-earn never wired; grace = 1 day not end-of-period (P0, D3) |
| Siri "Log progress on Drink Water" | ⚠️ no `EntityStringQuery` name matching (D8) |
| Watch one-per-page/tap-to-increment/snapshot round-trip | ⚠️ no optimistic update; fake streak/dots; crash risk (P1, D13) |
| Old task/watch snapshots still decode | ✅ (Snapshot `decodeIfPresent`) |
| CloudKit schema evolution | ✅ |
| Strings localized en/de/es/fr/zh-Hans | ❌ zero translations; missing keys (D16) |
| Unit tests (§5.2) | ❌ none exist (P0) |

---

## Suggested execution order for the coding model

1. **Correctness first:** P0 freeze wiring + tests → P1 bugs (dots, prefill, archived-delete, watch crash, target validation) → D3/D6/D7 streak semantics (decide then implement).
2. **Structural:** R1–R5 (source of truth, fetch batching, O(n) scans, dedupe formatting, error handling) while the streak code is open.
3. **Design reconciliation:** D4 DTO split, D5 `decodeIfPresent`, D8–D16 deviations; full localization pass.
4. **Features:** 4a AI-suggested defaults → 4b AI background art → 4c improvements.
5. **Polish:** R6–R11 concurrency/cleanup/a11y; verify all five targets build; on-device watch + Siri round-trip.
