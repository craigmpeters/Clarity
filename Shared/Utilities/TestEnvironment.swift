import Foundation

enum TestEnvironment {
    /// True when the process is running under an Xcode/xctest test host.
    ///
    /// Uses multiple independent signals because Xcode injects different
    /// environment variables / launch arguments depending on the test kind
    /// (unit, UI, xcodebuild vs Xcode IDE) and parallelization mode.
    nonisolated static var isRunningTests: Bool {
        let process = ProcessInfo.processInfo
        let env = process.environment

        let envSignals = [
            "XCODE_TEST_PLAN_NAME",
            "XCTestConfigurationFilePath",
            "XCTestBundlePath",
            "XCTestSessionIdentifier",
            "XCInjectBundleInto",
        ]
        let envMatch = envSignals.contains { env[$0] != nil }

        let argSignals = [
            ".xctest",
            "--uitesting",
            "--clarity-running-tests",
        ]
        let argMatch = process.arguments.contains { arg in
            argSignals.contains { arg.contains($0) }
        }

        return envMatch || argMatch
    }
}
