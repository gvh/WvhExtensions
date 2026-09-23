//
//  DaemonFileLog.swift
//  WvhExtensions
//

#if os(macOS)
import Darwin
import Foundation

/// Minimal append-only line logger for a background daemon's own log file —
/// independent of how the process was started, since launchd's
/// StandardOutPath/StandardErrorPath redirection only applies when launchd
/// itself launches the process, not when run from Xcode/Terminal directly.
///
/// This owns only the file-write mechanics (self-healing `FileHandle`, serial
/// write queue, directory creation). Callers own formatting — timestamps,
/// levels, categories — so each daemon's on-disk log format is unaffected by
/// using this.
public final class DaemonFileLog {
    private let url: URL
    private var fileHandle: FileHandle?
    private let writeQueue: DispatchQueue

    /// - Parameters:
    ///   - directory: Subdirectory under `~/Library/Logs`, or `nil` for a flat
    ///     file directly under `~/Library/Logs`.
    ///   - fileName: The log file's name, e.g. `"MyDaemon.log"`.
    public init(directory: String? = nil, fileName: String) {
        var dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        if let directory {
            dir = dir.appendingPathComponent(directory)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(fileName)
        self.writeQueue = DispatchQueue(label: "wvh.daemonfilelog.\(fileName)")
        self.fileHandle = Self.openForAppending(at: self.url)
    }

    /// Appends `line` plus a trailing newline to the log file, off the caller's thread.
    ///
    /// Before each write, confirms the cached handle still points at the file
    /// currently on disk at `url` (comparing inode, not just checking for a
    /// write error) — a file deleted/replaced out from under the process
    /// (external log rotation, manual deletion) leaves writes to the old,
    /// now-unlinked inode succeeding silently, so an error-based check alone
    /// would never catch it. If the handle is missing entirely (e.g. the very
    /// first open failed — permissions, disk full) this also retries opening
    /// it on every call, instead of staying silently broken forever.
    public func append(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        writeQueue.async { [weak self] in
            guard let self else { return }
            if !Self.handle(self.fileHandle, matchesFileAt: self.url) {
                self.fileHandle = Self.openForAppending(at: self.url)
            }
            guard let fileHandle = self.fileHandle else { return }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        }
    }

    private static func openForAppending(at url: URL) -> FileHandle? {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        return try? FileHandle(forWritingTo: url)
    }

    private static func handle(_ handle: FileHandle?, matchesFileAt url: URL) -> Bool {
        guard let handle else { return false }
        var handleStat = stat()
        guard fstat(handle.fileDescriptor, &handleStat) == 0 else { return false }
        var pathStat = stat()
        guard stat(url.path, &pathStat) == 0 else { return false }
        return handleStat.st_ino == pathStat.st_ino && handleStat.st_dev == pathStat.st_dev
    }
}
#endif
