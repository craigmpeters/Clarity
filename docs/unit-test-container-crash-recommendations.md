# Unit-Test Core Data Crash — Recommendations

**Status:** Ready to execute
**Date:** 2026-08-14
**Scope:** `ClarityTests` unit-test target crashes with `NSInternalInconsistencyException: No eligible connection available` (misreported as `Runner._applyScopingTraits`).

> **Instruction to the executing agent:** This document is a plan. Do NOT execute it autonomously. Only write/modify files when the user explicitly asks you to in the new context.

---

## 1. Root cause (confirmed from logs)

The app-hosted unit-test bundle boots the real `Clarity.app`, which creates the **live CloudKit-backed** `ModelContainer` (`Containers.liveApp()` → `default.store`). Repeated CloudKit `NSCloudKitMirroringDelegate` setup/teardown in the test host (`BUG IN CLIENT OF CLOUDKIT … already been registered`) exhausts Core Data's shared `NSSQLDefaultConnectionManager` connection pool. The next container that fetches — even an unrelated **in-memory** test container — throws `NSInternalInconsistencyException: No eligible connection available`. Swift Testing catches it and the nearest Testing frame is `Runner._applyScopingTraits`, which is why the failure is **misattributed** to scoping traits.

**`@MainActor` annotations are irrelevant to this crash.** Do not add or remove them as a fix.

## 2. Verified facts

- `ClarityApp.makeContainer()` and `AppContainer.shared` each build a `liveApp()` container → **two CloudKit containers in one process** (likely the source of the "already registered" errors even in production).
- The `.xctestrun` for `ClarityTests` confirms `IsAppHostedTestBundle => true`, `TestHostPath => Clarity.app`, `ParallelizationEnabled => true`.
- `TestingEnvironmentVariables` reliably includes `XCODE_TEST_PLAN_NAME` and `XCODE_SCHEME_NAME`. **`XCTestConfigurationFilePath` is NOT present** for Xcode-hosted runs (only for `xcodebuild test-without-building`).
- The project uses `PBXFileSystemSynchronizedRootGroup` for `Shared/Utilities` and `Shared/Data`. New files added to these folders are automatically included in targets via `membershipExceptions`. A new file must be added to the exception list for **each** target that compiles `ClarityModelActor.swift` (Clarity, ClarityAppIntentsExtension, Widgets, ClarityWatch, ClarityWatchWidgetsExtension).

## 3. Recommended changes

### R1 — Revert incorrect `@MainActor` annotations
- `ClarityTests/ClarityModelActorHabitTests.swift` — remove the `@MainActor` line added earlier (keep `@Suite(.serialized)`).
- `ClarityTests/SwiftDataHostCheckTests.swift` — remove the `@MainActor` line added earlier.
- **Keep** `@MainActor` on `UserDefaultsExtensionsTests` (semantically correct — mutates `UserDefaults.standard`).
- Leave `CompanionChatStoreTests`, `HabitFormStateTests`, `ClarityAppShellTests` untouched (already correctly `@MainActor`).

### R2 — Add a single test-environment detector
Create `Shared/Utilities/TestEnvironment.swift`:

```swift
import Foundation

enum TestEnvironment {
    /// True when the process is running under an Xcode/xctest test host.
    /// `XCODE_TEST_PLAN_NAME` is reliably present in the generated `.xctestrun`
    /// for Xcode-hosted unit and UI test runs (confirmed for `ClarityTests`).
    /// `XCTestConfigurationFilePath` is a fallback for `xcodebuild test-without-building`.
    nonisolated static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCODE_TEST_PLAN_NAME"] != nil
            || env["XCTestConfigurationFilePath"] != nil
    }
}
```

**Important:** Because the project uses `PBXFileSystemSynchronizedRootGroup`, after creating this file you must add `TestEnvironment.swift` to the `membershipExceptions` list for the `Utilities` folder in **every** target that compiles `Shared/Data/ClarityModelActor.swift`:
- `Clarity`
- `ClarityAppIntentsExtension`
- `Widgets`
- `ClarityWatch`
- `ClarityWatchWidgetsExtension`

If you cannot edit `project.pbxproj` directly, the fallback is to inline the `TestEnvironment` check into `ClarityApp.swift` and `ClarityModelActor.swift` instead of creating a new file.

### R3 — Gate all live/CloudKit container creation behind the detector
- `Clarity/ClarityApp.swift` — `makeContainer()`: add a test guard **before** the live-container path (after the existing `--uitesting` block):
  ```swift
  if TestEnvironment.isRunningTests {
      return try Containers.inMemory()
  }
  ```
- `Shared/Data/ClarityModelActor.swift` — `AppContainer.shared`: gate the lazy live container:
  ```swift
  enum AppContainer {
      nonisolated static let shared: ModelContainer = {
          if TestEnvironment.isRunningTests {
              return try! Containers.inMemory()
          }
          return try! Containers.liveApp()
      }()
  }
  ```
- `ClarityServices.sharedContainer()` is covered transitively via `AppContainer.shared`.

### R4 — Consolidate duplicate live containers (product-side fix)
`ClarityApp.makeContainer()` and `AppContainer.shared` each build a `liveApp()` container. Change `ClarityApp.makeContainer()`'s non-test, non-UITesting path to return `AppContainer.shared` instead of `try Containers.liveApp()`, keeping the existing `do/catch` → in-memory fallback. Net effect: exactly one live container per process.

### R5 — Verify
1. `swift build` (or Xcode build) — clean, no warnings.
2. Run `ClarityTests` scheme alone → expect 307/307, no `Runner._applyScopingTraits` / "No eligible connection available", and no `BUG IN CLIENT OF CLOUDKIT` lines in the console log.
3. Run full `Clarity` plan (unit + UI) → expect green.
4. Confirm `UserDefaultsExtensionsTests` still passes with `@MainActor` retained.

### R6 — Update `docs/clarity-ui-test-progress.md`
In "Next steps," replace the "investigate Swift Testing scoping traits" bullet with the real root cause (CloudKit container churn in the app-hosted unit-test process poisoning Core Data's connection pool) and note the fix.

## 4. Files to modify

| File | Change |
|---|---|
| `Shared/Utilities/TestEnvironment.swift` | **new** — detector (must add to target membership exceptions) |
| `Clarity/ClarityApp.swift` | test guard + use `AppContainer.shared` |
| `Shared/Data/ClarityModelActor.swift` | gate `AppContainer.shared` |
| `ClarityTests/ClarityModelActorHabitTests.swift` | revert `@MainActor` |
| `ClarityTests/SwiftDataHostCheckTests.swift` | revert `@MainActor` |
| `docs/clarity-ui-test-progress.md` | correct the root-cause note |

## 5. Out of scope / not recommended
- **Don't** blanket-serialize all container-creating suites or disable parallelization — that masks the real problem and slows the suite.
- **Don't** gate CloudKit off while keeping the live store — simpler and safer to use the in-memory container for tests.
- **Don't** add `@MainActor` to more suites as a fix — it does not address the root cause.
