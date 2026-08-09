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
