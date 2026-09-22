# Companion Chat iMessage-Style Redesign + Habits Integration

## Context

Current date: Sunday, August 9, 2026.

This plan was originally drafted Saturday, August 8, 2026. This revision incorporates a status pass against the current codebase and adds a new habits-integration workstream.

---

## 0. Implementation status

**None of the original iMessage redesign is implemented yet.** The codebase is in the exact "before" state. Verified facts and corrected references:

| Plan item | Status | Current reference |
|---|---|---|
| `ChatMessage.swift` / `CompanionChatStore.swift` / `CompanionChatView.swift` | ❌ Files do not exist | — |
| `CompanionService` history state, gating, session history block | ❌ Not implemented | `show(_:)` at `CompanionService.swift:497–511`; `clearHistory()` at `:562–567` |
| Old `CompanionChatSheet` | Unchanged | `CompanionView.swift:207–329`; sheet wired at `:44–46` |
| `.moodSelected` removal | ❌ Still fires | `PomodoroView.swift:74` (`.pomodoroCompleted` at `:89`) |
| `allowsTaskSuggestion` | ❌ Not implemented | `CompanionTrigger` at `CompanionService.swift:71–80` (8 cases) |
| Per-trigger suggestion language | ❌ Suggestion guidance still unconditional | `Otto.swift:25`, `Goose.swift:27` |
| `loadChatHistory()` in `ContentView.task` | ❌ Not added | `.task` at `ContentView.swift:85–94` |
| Streaming | ➖ Intentionally unchanged | `respond(to:)` at `CompanionService.swift:431,446` |

**Changes since the original draft:**
1. The shared SwiftData schema is now **6 entities** (`ToDoTask`, `Category`, `GlobalTargetSettings`, `TaskSwipeAndTapOptions`, `Habit`, `HabitOccurrence`) at `ClarityModelActor.swift:921–958`. `ChatMessage` is in no schema — the app-only container decision is **confirmed and settled**.
2. A `.habitSuggestion(categories:completedCount:)` trigger already exists (`CompanionService.swift:79`, fired at `StatsView.swift:239`, backed by `Shared/Models/HabitSuggestionService.swift`). It is the stats-screen "suggest new habits" nudge and is **unrelated** to habit completion. It maps to `allowsTaskSuggestion == false`.
3. A `ClarityTests` target exists (`ClarityTests/HabitStreakCalculatorTests.swift`). The original plan's "no test target" claim was inaccurate; the streak-state resolver is a good candidate for unit tests.

---

## 1. Goals / Non-goals

### Goals
1. Replace the single-message `CompanionChatSheet` with a scrolling iMessage-style conversation (companion = gray/left with avatar, user = blue/right).
2. Show an animated 3-dot typing bubble while the model generates.
3. Attach a suggested task / "Start" button **only** for task completions (`.taskCompleted`, `.pomodoroCompleted`); all other triggers are reply-only.
4. Eliminate the repetitive pomodoro-completed → mood-selected double message.
5. Persist the conversation locally, retain ~48 hours, prune automatically, and use recent history as LLM context.
6. **Wire up habit completion events:** generate a companion message whenever a habit is completed, with tone that is aware of the current streak state.

### Non-goals
- The floating companion overlay bubble stays as-is (entry point + transient notification card).
- No character-by-character streaming (Foundation Models `respond(to:)` returns complete output; streaming API is a future enhancement).
- No CloudKit sync of chat history (privacy + simplicity).
- No companion reaction to widget/watch/HealthKit habit completions in v1 (the companion service is app-process only; detecting unacknowledged out-of-process completions on next launch is a future enhancement).

---

## 2. Current state findings

- `CompanionChatSheet` (`CompanionView.swift:207–329`) shows one face + one message, no transcript. `CompanionService` holds only `currentMessage`.
- `CompanionService.show(_:)` (`CompanionService.swift:497–511`) resolves `suggestedTask` from **any** generated output → any trigger can surface the Start button.
- Repetition source: `PomodoroView.swift:89` fires `.pomodoroCompleted`, then the mood sheet save (`:74`) fires `.moodSelected` — two generated messages for one event. `.moodSelected` has no other call site.
- The `LanguageModelSession` keeps in-session turns natively, but nothing survives relaunch.
- Persistence today: shared SwiftData schema (`[ToDoTask, Category, GlobalTargetSettings, TaskSwipeAndTapOptions, Habit, HabitOccurrence]`) duplicated across `Containers.liveApp()` (CloudKit ON), `liveExtension()`, `inMemory()`.
- A `HabitStreakCalculator` exists (`Shared/Models/HabitStreakCalculator.swift`) with its own test suite. Habit completion UI is expected in `Clarity/Views/Habits/HabitRowView.swift` / `HabitsIndexView.swift` (to be verified before implementation).

---

## 3. Architecture

### 3.1 Persistence — new, separate local store (recommended)

Rather than touching the shared schema (which is compiled into widgets/extensions/watch and synced via CloudKit), chat history gets its **own app-target-only SwiftData container**. This avoids: CloudKit syncing private conversations, extension/watch schema churn, and any migration risk to task/habit data.

#### New file: `Clarity/Models/ChatMessage.swift`

```swift
enum ChatSender: String, Codable, Sendable { case user, companion }

@Model
final class ChatMessage {
    var timestamp: Date = Date()
    var senderRaw: String = ChatSender.companion.rawValue
    var text: String = ""
    var emotionRaw: String? = nil            // per-bubble avatar emotion
    var suggestedTaskUUID: UUID? = nil
    var suggestedTaskName: String? = nil
}
```

All attributes optional-or-defaulted, no unique constraints — CloudKit-safe if ever synced later.

#### New file: `Clarity/Models/CompanionChatStore.swift`

Owns the container and all queries:
- **Init**: builds `ModelContainer(Schema([ChatMessage.self]))` with a named local config (`companion-chat.sqlite`, no app group, no CloudKit). On failure → fall back to an in-memory container and log (chat keeps working, just unpersisted).
- **Fetch**: `fetchRecent() -> [ChatMessage]` — ascending by timestamp.
- **Append**: `append(_ message)` — insert + save on `mainContext` (low volume; service is already `@MainActor`).
- **Prune**: `prune(olderThan:)` — delete messages older than **48h** (a `static let retentionInterval` constant) and enforce a hard cap (**100 messages**, oldest first). Called on store init, on every append, and via a `.task` timer while the chat UI is open.
- **Reset**: `deleteAll()` — for the existing "Reset Conversation History" button.

### 3.2 `CompanionService` changes

- New observable state: `private(set) var chatHistory: [ChatMessage] = []` and `private let chatStore: CompanionChatStore`.
- **Load history**: `loadChatHistory()` — called once from `ContentView.task` alongside `loadContext(from:)`; prunes, loads, invalidates session.
- **User message**: `chat(_:)` appends the **user** message to history immediately (drives instant UI), then generates as today.
- **Companion reply**: `show(_ output:)` and fallbacks append the **companion** message to history. Fallback messages are persisted too, so the thread is truthful when Apple Intelligence is off.
- **Suggestion gating**: add a property on the trigger enum:
  ```swift
  var allowsTaskSuggestion: Bool {
      switch self {
      case .taskCompleted, .pomodoroCompleted: return true
      default: return false
      }
  }
  ```
  In `show(_:)`, only resolve `suggestedTask` when `fallbackEvent?.allowsTaskSuggestion == true`. Free-form chat (`nil` event) never attaches a suggestion. `errorFallback` keeps its overdue-task CTA — it is a rare recovery path, not a repetitive one.
- **History as context**: in `currentSession()`, append a `recentConversationBlock` (last ~8 persisted messages, rendered as `User: … / <Name>: …`) after the existing `instructionsBlock`. This is composed in the service, so the `CompanionPersonality` protocol signature does **not** change. Fresh turns within a live session are handled natively by the session; the injected block covers relaunches and post-prune session rebuilds.
- **Habits as context**: extend `loadContext(from:)` / `CompanionTaskContext` with a compact `HABITS` block listing habit name, schedule summary, current streak, and done-today status, sourced from the existing `ClarityModelActor` habit API.
- **Habit completion trigger**: new `CompanionTrigger` case with streak-aware payload, and a small resolver reusing `HabitStreakCalculator`.
- **Clear history**: `clearHistory()` now also calls `chatStore.deleteAll()` and clears `chatHistory`. The Settings button already calls this — no Settings UI change required.

### 3.3 Trigger-flow & prompt changes

- `PomodoroView.swift:74` — **remove the `.moodSelected` trigger call**; mood is still recorded (`markMoodLogged`, `recordMood`). The pomodoro completion message (which may suggest a task) stands alone.
- **Cleanup**: delete the now-dead `.moodSelected` case from `CompanionTrigger` plus its branches in `Otto.swift` and `Goose.swift` (both `prompt` and `fallbackMessage` switches are exhaustive and must be updated if the case is removed).
- **Prompt engineering** — make the suggestion instruction conditional:
  - `systemInstructions` currently always says *"When suggesting a task…"* — move that sentence out of the base instructions.
  - In each personality's `prompt(for:)`, completion triggers append: *"You may suggest one task from UPCOMING TASKS by setting suggestedTaskName."* All other triggers append: *"Do not set suggestedTaskName."* (Both Otto and Goose, prompt + fallback paths.)
  - The `@Guide` on `suggestedTaskName` already says "otherwise leave empty" — keep.
- **Habit completion personality branches**: Otto + Goose each add `habitCompleted` to `prompt(for:)` and `fallbackMessage(for:)`, with four streak-aware tones (continued, milestone, saved, restarted) and the same *"Do not set suggestedTaskName."* append.

### 3.4 UI — new `Clarity/Views/Companion/CompanionChatView.swift`

Replace `CompanionChatSheet`'s body (keep the type name/signature so `CompanionOverlayView`'s `.sheet` wiring is untouched), structured like Messages:

- **Nav bar**: small circular `CompanionFaceView` + `displayName`, inline title; existing "Done".
- **Transcript**: `ScrollView` + `LazyVStack` driven by `companion.chatHistory`, with `.defaultScrollAnchor(.bottom)` and scroll-to-bottom on new message / keyboard appear.
  - **Companion bubble**: leading-aligned, `secondarySystemBackground` gray, 17pt corner radius (small radius on the anchor corner for the iMessage tail feel), 28pt circular face at the bubble's leading edge showing the **message's stored emotion**.
  - **User bubble**: trailing-aligned, accent blue, white text, no avatar.
  - **Day/time separators**: `RelativeDateTimeFormatter` between messages on different days (or >2h gaps).
  - **Suggestion pill**: when a companion message has `suggestedTask*`, render an attachment-style pill directly beneath its bubble — timer icon + *Start "<name>"* — wired to the existing `requestStartTask(_:)` → `ContentView.onChange(of: startTaskRequest)` flow (unchanged). Persisted UUID/name means it still renders after relaunch; the existing fetch-by-UUID already fails gracefully if the task is gone.
- **Typing indicator** (`TypingIndicatorView`): a companion-side gray bubble containing three 8pt circles animating opacity/scale with staggered 0.15s delays, shown whenever `companion.isGenerating`; respects Reduce Motion (static dots). Replaces the ProgressView in the send button.
- **Input bar**: keep the existing multiline capsule `TextField` + `arrow.up.circle.fill`, iMessage-style spacing; send disabled while generating or empty.
- **Unavailable state**: keep the Apple Intelligence notice, but history still displays.
- **Detents**: `[.medium, .large]` (thread needs room), drag indicator kept.
- **Preview**: new `#Preview` with a seeded mock transcript (user/companion/typing/suggestion states) using the in-memory store.

---

## 4. Habits integration (detailed)

### 4.1 New trigger case

Add to `CompanionTrigger` (`CompanionService.swift:71–80`):

```swift
case habitCompleted(habitName: String, streak: HabitStreakState)

enum HabitStreakState: Sendable {
    case continued(days: Int)          // normal extension
    case milestone(days: Int)          // 7 / 30 / 100 / 365
    case saved(days: Int)              // completed when the streak was about to break
    case restarted(previousDays: Int)  // completing after a broken streak
}
```

One case, payload carries the resolved streak state. Personalities get simple switch branches; the LLM never computes streaks itself. `allowsTaskSuggestion` returns `false` for this case (and for the existing `.habitSuggestion`).

### 4.2 Streak-state resolution

Reuse the existing `Shared/Models/HabitStreakCalculator.swift` (semantics confirmed by `ClarityTests/HabitStreakCalculatorTests.swift`). A small resolver maps `(habit, occurrences, completion timestamp)` → `HabitStreakState`:

- Streak extended and hits **7 / 30 / 100 / 365** → `.milestone`
- Streak extended on the last scheduled day before a break would occur → `.saved`
- First completion after a broken streak → `.restarted(previousDays:)`
- Otherwise → `.continued`

Do not duplicate streak logic; call the existing calculator and classify from its output.

### 4.3 Fire site

`companion.trigger(.habitCompleted(...))` at the canonical in-app completion path. The exact view and line number will be pinned in the pre-implementation verification step (see §7). Expected candidates: `HabitRowView.swift` / `HabitsIndexView.swift`, and the in-app `HabitHealthKitSync.swift` path.

Out-of-process completions (widget `LogHabitProgressIntent`, watch `WatchHabitsView`) do **not** fire v1 — the companion service is app-process only.

### 4.4 Personality branches

Otto + Goose each add `habitCompleted` to `prompt(for:)` and `fallbackMessage(for:)`, with four tones:

- `.continued(days:)` — brief encouragement, references the streak length.
- `.milestone(days:)` — big celebration (e.g., 7, 30, 100, 365 days).
- `.saved(days:)` — relief, "that was close" energy; positive, never shaming.
- `.restarted(previousDays:)` — warm welcome-back; never guilt-tripping.

All branches append *"Do not set suggestedTaskName."*

### 4.5 Habits in LLM context

Extend `loadContext(from:)` / `CompanionTaskContext` (around `CompanionService.swift:279–344`) with a compact `HABITS` block alongside the existing task sections. Example block:

```
HABITS:
- Morning run (daily) — streak 5 days, done today: yes
- Read 10 pages (weekdays) — streak 2 days, done today: no
```

Sourced from the existing `ClarityModelActor` habit API. This lets the companion reference habits in free-form chat and in triggered replies, without requiring the model to compute streaks.

---

## 5. File-by-file change list

| File | Change |
|---|---|
| `Clarity/Models/ChatMessage.swift` | **New** — `@Model` + `ChatSender` |
| `Clarity/Models/CompanionChatStore.swift` | **New** — container, fetch/append/prune/deleteAll, in-memory fallback |
| `Clarity/Models/CompanionService.swift` | History state + appends; `allowsTaskSuggestion` gating; conversation block + HABITS block in context; `loadChatHistory()`; `clearHistory()` wipes store; new `habitCompleted` case + `HabitStreakState` + streak resolver |
| `Clarity/Views/Companion/CompanionChatView.swift` | **New** — thread, bubbles, typing indicator, suggestion pill, separators |
| `Clarity/Views/Companion/CompanionView.swift` | Remove/re-point old `CompanionChatSheet`; overlay unchanged |
| `Clarity/Companions/Otto.swift`, `Goose.swift` | Conditional suggestion language per trigger; remove `.moodSelected` branches; add `habitCompleted` branches |
| `Clarity/Views/Tasks/PomodoroView.swift` | Delete `.moodSelected` call (`:74`); mood still recorded |
| `Clarity/Views/ContentView.swift` | One line: `await companion.loadChatHistory()` in the existing `.task` |
| Habit completion view(s) + `HabitHealthKitSync.swift` | Fire `.habitCompleted` on completion (paths pinned in §7) |
| `CompanionSettingsView.swift` | None required ("Reset Conversation History" already calls `clearHistory()`) |
| `ClarityTests/HabitStreakCalculatorTests.swift` or new test file | Unit tests for the streak-state resolver |

---

## 6. Edge cases

- **AI off / model downloading**: fallbacks are appended to history, so the thread and typing bubble behave identically.
- **Pruning while open**: timer-based prune; deleted rows animate out of the LazyVStack.
- **Rapid triggers** (complete → uncomplete): each appends its own bubble — the transcript actually makes this *less* confusing than today.
- **Empty history**: thread shows the current "What's on your mind?" empty state above the input.
- **Task deleted/completed after suggestion**: `requestStartTask` already guards on fetch failure.
- **Session continuity**: new in-session turns rely on the native session; injected history is only for cold starts — no double-context.
- **Habit completion out-of-process**: widget/watch/HealthKit sync may complete a habit without the app open. In v1, the companion does **not** react to these events. When the app next launches, the chat will simply not show a message for that completion. This is acceptable and noted as a non-goal.
- **Habit completion when the streak calculator changes**: the resolver calls the existing calculator, so behavior stays consistent with the rest of the app and its tests.

---

## 7. Validation plan

### iMessage redesign
1. AI on/off.
2. Complete a task → message **with** Start button.
3. Finish pomodoro → exactly **one** message, Start button present.
4. Pick mood → **no** companion message.
5. App launch / streak / habit triggers → no Start button.
6. Relaunch within 48h → history restored and referenced in responses.
7. Relaunch after 48h → pruned.
8. Reset History → thread empty.
9. Typing indicator appears and is replaced by the reply.

### Habits integration
10. Complete habit mid-streak → continuation message, no Start button.
11. Complete habit on milestone day (7 / 30 / 100 / 365) → celebration.
12. Complete habit on the last day before a lapse → "saved" message.
13. Complete habit after a broken streak → welcome-back message, no guilt tone.
14. Multiple habits completed back-to-back → one bubble each, no guard suppressing them.
15. Stats-screen `.habitSuggestion` trigger → still no Start button.
16. Widget/watch completion → no companion message in v1 (expected).

---

## 8. Risks and mitigations

- **Chat container creation failure** → mitigated by in-memory fallback.
- **Prompt changes altering tone** → personalities keep their base instructions; only the suggestion sentence moves per-trigger, and habit branches are self-contained.
- **Two containers open per process** → trivial memory cost; chat store is app-target only, extensions never load it.
- **Streak-state resolver diverging from existing calculator** → mitigated by reusing `HabitStreakCalculator` and adding unit tests.
- **Out-of-process habit completions not reflected in chat** → accepted as a v1 non-goal; documented above.

---

## 9. Defaults baked into this plan

- Retention: **48 hours**.
- Hard message cap: **100 messages**.
- Error-fallback keeps its "tackle <overdue task>?" CTA since it is a rare recovery path, not repetitive.
- Habit milestone thresholds: **7, 30, 100, 365** days.
- Habit triggers are **reply-only** (no task suggestions).
- Widget/watch/HealthKit habit completions are **not** wired to the companion in v1.

---

## 10. Build progress log

| Phase | Status | Notes |
|---|---|---|
| Plan updated | ✅ | Added status + habits section. |
| Habits verification | ✅ | Models, streak calculator, and fire sites verified. |
| Chat model/store | ✅ | `ChatMessage.swift` + `CompanionChatStore.swift` created with app-only container + in-memory fallback. |
| `CompanionService` refactor | ✅ | History, gating, context, habit trigger, `loadChatHistory`, `clearHistory` store wipe. |
| New chat UI | ✅ | `CompanionChatView.swift` created; `CompanionView.swift` updated to present it. |
| Otto/Goose updates | ✅ | `.moodSelected` removed, per-trigger suggestion instruction, `habitCompleted` branches. |
| Pomodoro/ContentView updates | ✅ | `.moodSelected` removed; `loadChatHistory()` wired on launch. |
| Habit fire-sites | ✅ | `HabitsIndexView` increment/setAmount/completeAnyway + `HabitHealthKitSync` wired. |
| Habit resolver tests | ✅ | `HabitStreakStateResolverTests.swift` added and passing. |
| Build + tests | ✅ | Project builds and 13 tests pass. |

(End of plan — updated Sunday, August 9, 2026.)
