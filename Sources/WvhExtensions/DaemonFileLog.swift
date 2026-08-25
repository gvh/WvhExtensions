//
//  DaemonFileLog.swift
//  WvhExtensions
//

#if os(macOS)
import Foundation

/// Minimal append-only line logger for a background daemon's own log file —
/// independent of how the process was started, since launchd's
/// StandardOutPath/StandardErrorPath redirection only applies when launchd
/// itself launches the process, not when run from Xcode/Terminal directly.
///
/// This owns only the file-write mechanics (lazy `FileHandle`, serial write
/// queue, directory creation). Callers own formatting — timestamps, levels,
/// categories — so each daemon's on-disk log format is unaffected by using this.
public final class DaemonFileLog {
    private let fileHandle: FileHandle?
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
        let url = dir.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: url)
        writeQueue = DispatchQueue(label: "wvh.daemonfilelog.\(fileName)")
    }

    /// Appends `line` plus a trailing newline to the log file, off the caller's thread.
    public func append(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        writeQueue.async { [fileHandle] in
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(data)
        }
    }
}
#endif
