//
//  LaunchAgentController.swift
//  WvhExtensions
//

#if os(macOS)
import Foundation

/// Controls a manual-start LaunchAgent (no `RunAtLoad`, no `KeepAlive`) via
/// `launchctl`, so a GUI app can start/stop a companion background daemon
/// without owning its process lifecycle directly.
///
/// launchd guarantees at most one instance of a given label is ever running,
/// which is what makes this the right tool for daemon control: there's no
/// liveness-check-then-spawn race, no PID tracking, and no need to identify
/// the process by name (`pgrep`/`pkill`) — launchd already knows.
///
/// All `launchctl` calls block on `waitUntilExit()`, so call `launch()`/`stop()`
/// from a background task, not the main actor/thread.
public struct LaunchAgentController {
    public let label: String

    private var domainTarget: String { "gui/\(getuid())" }
    private var serviceTarget: String { "\(domainTarget)/\(label)" }

    /// Where the LaunchAgent plist must be installed for this controller to find it:
    /// `~/Library/LaunchAgents/<label>.plist`.
    public var installedPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public var isPlistInstalled: Bool {
        FileManager.default.fileExists(atPath: installedPlistURL.path)
    }

    public init(label: String) {
        self.label = label
    }

    public enum LaunchResult: Equatable {
        case launched
        case notInstalled
        case bootstrapFailed(Int32)
        case kickstartFailed(Int32)
    }

    /// Bootstraps the job (if launchd doesn't already know about it) and
    /// kickstarts it — `-k` kills and restarts if it happens to be running,
    /// so this always results in a single fresh instance.
    @discardableResult
    public func launch() -> LaunchResult {
        guard isPlistInstalled else { return .notInstalled }
        if !isBootstrapped() {
            let status = run("/bin/launchctl", ["bootstrap", domainTarget, installedPlistURL.path])
            guard status == 0 else { return .bootstrapFailed(status) }
        }
        let status = run("/bin/launchctl", ["kickstart", "-k", serviceTarget])
        return status == 0 ? .launched : .kickstartFailed(status)
    }

    public enum StopResult: Equatable {
        case stopped
        case notInstalled
        case failed(Int32)
    }

    /// Stops the running job. Since the job has no `KeepAlive`/`RunAtLoad`, it
    /// stays stopped until `launch()` (or a manual `launchctl kickstart`) runs again.
    @discardableResult
    public func stop() -> StopResult {
        guard isPlistInstalled else { return .notInstalled }
        let status = run("/bin/launchctl", ["stop", label])
        return status == 0 ? .stopped : .failed(status)
    }

    public func isBootstrapped() -> Bool {
        run("/bin/launchctl", ["print", serviceTarget]) == 0
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
#endif
