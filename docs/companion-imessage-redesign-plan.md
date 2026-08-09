# Companion Chat iMessage-Style Redesign

## Context

Current date: Saturday, August 8, 2026

## 1. Goals / Non-goals

### Goals
1. Replace the single-message `CompanionChatSheet` with a scrolling iMessage-style conversation (companion = gray/left with avatar, user = blue/right).
2. Show an animated 3-dot typing bubble while the model generates.
3. Attach a suggested task / "Start" button **only** for task completions (`.taskCompleted`, `.pomodoroCompleted`); all other triggers are reply-only.
4. Eliminate the repetitive pomodoro-completed → mood-selected double message.
5. Persist the conversation locally, retain ~48 hours, prune automatically, and use recent history as LLM context.

### Non-goals
- The floating companion overlay bubble stays as-is (entry point + transient notification card).
- No character-by-character streaming (Foundation Models `respond(to:)` returns complete output; streaming API is a future enhancement).
- No CloudKit sync of chat history (privacy + simplicity).

## 2. Current state findings

- `CompanionChatSheet` (`Clarity/Views/Companion/CompanionView.swift:207`) shows one face + one message, no transcript. `CompanionService` holds only `currentMessage`.
- `CompanionService.show(_:)` (`CompanionService.swift:498`) resolves `suggestedTask` from **any** generated output → any trigger can surface the Start button.
- Repetition source: `PomodoroView.swift:89` fires `.pomodoroCompleted`, then the mood sheet save (`:74`) fires `.moodSelected` — two generated messages for one event. `.moodSelected` has no other call site.
- The `LanguageModelSession` keeps in-session turns natively, but nothing survives relaunch.
- Persistence today: shared SwiftData schema (`[ToDoTask, Category, GlobalTargetSettings, TaskSwipeAndTapOptions]`) duplicated across `Containers.liveApp()` (CloudKit ON), `liveExtension()`, `inMemory()`.

## 3. Architecture

### 3.1 Persistence — new, separate local store (recommended)

Rather than touching the shared schema (which is compiled into widgets/extensions/watch and synced via CloudKit), chat history gets its **own app-target-only SwiftData container**. This avoids: CloudKit syncing private conversations, extension/watch schema churn, and any migration risk to task data.

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
- **Clear history**: `clearHistory()` now also calls `chatStore.deleteAll()` and clears `chatHistory`. The Settings button already calls this — no Settings UI change required.

### 3.3 Trigger-flow & prompt changes

- `PomodoroView.swift:74` — **remove the `.moodSelected` trigger call**; mood is still recorded (`markMoodLogged`, `recordMood`). The pomodoro completion message (which may suggest a task) stands alone.
- **Optional cleanup**: delete the now-dead `.moodSelected` case from `CompanionTrigger` plus its branches in `Otto.swift` and `Goose.swift` (both `prompt` and `fallbackMessage` switches are exhaustive and must be updated if the case is removed).
- **Prompt engineering** — make the suggestion instruction conditional:
  - `systemInstructions` currently always says *"When suggesting a task…"* — move that sentence out of the base instructions.
  - In each personality's `prompt(for:)`, completion triggers append: *"You may suggest one task from UPCOMING TASKS by setting suggestedTaskName."* All other triggers append: *"Do not set suggestedTaskName."* (Both Otto and Goose, prompt + fallback paths.)
  - The `@Guide` on `suggestedTaskName` already says "otherwise leave empty" — keep.

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

## 4. File-by-file change list

| File | Change |
|---|---|
| `Clarity/Models/ChatMessage.swift` | **New** — `@Model` + `ChatSender` |
| `Clarity/Models/CompanionChatStore.swift` | **New** — container, fetch/append/prune/deleteAll, in-memory fallback |
| `Clarity/Models/CompanionService.swift` | History state + appends, `allowsTaskSuggestion` gating in `show(_:)`, conversation block in `currentSession()`, `loadChatHistory()`, `clearHistory()` wipes store |
| `Clarity/Views/Companion/CompanionChatView.swift` | **New** — thread, bubbles, typing indicator, suggestion pill, separators |
| `Clarity/Views/Companion/CompanionView.swift` | Remove old `CompanionChatSheet` body (or re-point sheet to new view); overlay unchanged |
| `Clarity/Companions/Otto.swift`, `Goose.swift` | Conditional suggestion instruction per trigger; remove `.moodSelected` branches |
| `Clarity/Views/Tasks/PomodoroView.swift` | Delete `.moodSelected` trigger call (mood still recorded) |
| `Clarity/Views/ContentView.swift` | One line: `await companion.loadChatHistory()` in the existing `.task` |
| `CompanionSettingsView.swift` | None required ("Reset Conversation History" already calls `clearHistory()`) |

## 5. Edge cases

- **AI off / model downloading**: fallbacks are appended to history, so the thread and typing bubble behave identically.
- **Pruning while open**: timer-based prune; deleted rows animate out of the LazyVStack.
- **Rapid triggers** (complete → uncomplete): each appends its own bubble — the transcript actually makes this *less* confusing than today.
- **Empty history**: thread shows the current "What's on your mind?" empty state above the input.
- **Task deleted/completed after suggestion**: `requestStartTask` already guards on fetch failure.
- **Session continuity**: new in-session turns rely on the native session; injected history is only for cold starts — no double-context.

## 6. Validation plan

No test target exists in the repo, so use seeded-transcript previews for all bubble states, plus a manual matrix:
1. AI on/off.
2. Complete a task → message **with** Start button.
3. Finish pomodoro → exactly **one** message, Start button present.
4. Pick mood → **no** companion message.
5. App launch / streak / habit triggers → no Start button.
6. Relaunch within 48h → history restored and referenced in responses.
7. Relaunch after 48h → pruned.
8. Reset History → thread empty.
9. Typing indicator appears and is replaced by the reply.

## 7. Risks and mitigations

- **Chat container creation failure** → mitigated by in-memory fallback.
- **Prompt changes altering tone** → personalities keep their base instructions; only the suggestion sentence moves per-trigger.
- **Two containers open per process** → trivial memory cost; chat store is app-target only, extensions never load it.

## 8. Defaults baked into this plan

- Retention: **48 hours**.
- Hard message cap: **100 messages**.
- Error-fallback keeps its "tackle <overdue task>?" CTA since it is a rare recovery path, not repetitive.
