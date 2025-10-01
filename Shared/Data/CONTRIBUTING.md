// Clarity: Contribution Guide

// This guide summarizes project-specific guardrails to avoid breaking cross-target behavior (iOS, watchOS, and shared code).

// ## Platform rules

// - Watch app must not depend on SwiftData
//   - No `import SwiftData` in watch targets
//   - No `.modelContainer(...)` injection in watch entry point
//   - Use `ClarityWatchConnectivity.TaskTransfer` as the only task model on watch
//   - Only use SwiftData on iOS, and keep any SwiftData APIs behind `#if os(iOS)` guards in shared files (like `WatchConnectivity.swift`)

// - Connectivity contract must remain stable
//   - Keys and types: `id: String`, `name: String`, `pomodoroTime: TimeInterval`, `due: TimeInterval (since 1970)`, `categories: [String]`
//   - If the payload changes, bump a version or add new keys without removing the old ones, and keep parsers tolerant to missing fields

// - Keep UI unchanged when asked
//   - Preserve the visual hierarchy and modifiers (row layout, swipe actions, colors)
//   - Only swap data sources or action handlers behind the scenes

// - Don’t reintroduce the Completion Service unless agreed
//   - If reintroduced, it must be iOS-only and not interfere with the watch’s data path

// ## Requesting changes

// When asking for changes, please specify:
// - Targets involved (watch only, iOS + shared, etc.)
// - Constraints (e.g., "Do not change UI", "No SwiftData on watch")
// - Intent (e.g., "Watch pulls tasks from phone; phone persists via SwiftData")
// - No-touch files if any (e.g., "Don’t modify Pomodoro UI")
// - Desired fallback behavior (e.g., "If phone isn’t reachable, show last snapshot")

// If you want a dry run first, say “propose a plan first.”

// ## Process & safety checks

// - Conditional compilation hygiene
//   - Put iOS-only SwiftData and repository calls under `#if os(iOS)`
//   - Keep watch-only APIs under `#if os(watchOS)`

// - Cross-target import discipline
//   - Never import SwiftData or UIKit in watch targets
//   - Keep shared files free of platform-specific imports unless guarded

// - Build all targets after changes
//   - Ensure watchOS, iOS, and shared code compile cleanly

// - Prefer additive over destructive changes
//   - Don’t remove existing APIs unless call sites are updated
//   - If neutralizing something, stub it as a no-op to avoid compile errors

// ## Quick pre-commit checklist

// - [ ] Watch target has no SwiftData imports or model container
// - [ ] Connectivity payload matches the agreed schema
// - [ ] iOS instantiates `ClarityWatchConnectivity.shared` at launch
// - [ ] Watch requests tasks on appear and updates `lastReceivedTasks`
// - [ ] UI unchanged (no modifier or layout changes)
// - [ ] All targets build successfully
