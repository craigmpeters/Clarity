# AGENTS.md

## Stack
- Swift 6 with strict concurrency enabled, SwiftUI, Swift Package Manager
- Deployment targets: iOS 17 / macOS 14
- Swift Testing for all new tests (XCTest only when extending legacy suites)

## Code style
- Format with swift-format (runs automatically on edit)
- No force unwraps, force try, or implicitly unwrapped optionals outside tests
- Prefer structs and value semantics; classes only when identity or reference semantics are required
- Concurrency: async/await and actors only; no completion handlers or DispatchQueue in new code
- Naming follows the Swift API Design Guidelines

## Architecture
- MVVM with @Observable models
- Dependencies injected via initializers; no new singletons

## Workflow
- After every code change run `swift build` and `swift test`; fix all errors and warnings before considering the task done
- Keep diffs minimal; do not refactor unrelated code
- Never hardcode secrets or API keys; use Secrets.xcconfig (gitignored)

## Design Decisions
* Tasks themselves in ToDoTask have a UUID, this is unique for the task but not the instance of the task - this behaviour is intended
* Habit progress dots (WeeklyDotsView on iOS, weekCompletionBitmap on watchOS) show a rolling 7-day window (today plus the previous 6 days, oldest first, today last) rather than a fixed calendar week. Streak calculation (HabitStreakCalculator) remains calendar-week based (Sunday start) and is intentionally unchanged.
* Pomodoro durations are capped at a maximum of 25 minutes (5–25 in 5-minute steps). This is a deliberate business rule: MinutePickerView only offers 5...25, the Apple Intelligence duration suggestion clamps to 25 (PomodoroSuggestion / PomodoroSuggestionService), and AI task-splitting subtask estimates clamp to 25 (TaskSplitParser). Do not raise these caps.
