//
//  DaemonFileLogTests.swift
//  WvhExtensionsTests
//
//  DaemonFileLog always logs under ~/Library/Logs, so each test uses a unique
//  throwaway subdirectory and removes it afterwards.
//

#if os(macOS)
import Testing
import Foundation
@testable import WvhExtensions

@Suite(.serialized)
struct DaemonFileLogTests {

    private struct Scratch {
        let directoryName = "WvhExtensionsTests-\(UUID().uuidString)"
        let fileName = "test.log"

        var directoryURL: URL {
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs")
                .appendingPathComponent(directoryName)
        }
        var fileURL: URL { directoryURL.appendingPathComponent(fileName) }

        func makeLog() -> DaemonFileLog {
            DaemonFileLog(directory: directoryName, fileName: fileName)
        }
        func contents() -> String? {
            try? String(contentsOf: fileURL, encoding: .utf8)
        }
        func cleanUp() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    @Test func appendsLinesInOrder() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        let log = scratch.makeLog()

        log.append("one")
        log.append("two")
        log.append("three")
        log.flush()

        #expect(scratch.contents() == "one\ntwo\nthree\n")
    }

    @Test func flushWaitsForEverythingQueuedBeforeIt() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        let log = scratch.makeLog()

        for i in 0..<500 { log.append("line \(i)") }
        log.flush()

        let lines = scratch.contents()?.split(separator: "\n") ?? []
        #expect(lines.count == 500)
        #expect(lines.last == "line 499")
    }

    @Test func flushWithNothingPendingReturns() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        let log = scratch.makeLog()
        log.flush()
        log.flush()
    }

    @Test func recreatesTheFileIfItIsDeleted() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        let log = scratch.makeLog()

        log.append("before")
        log.flush()
        try? FileManager.default.removeItem(at: scratch.fileURL)
        log.append("after")
        log.flush()

        #expect(scratch.contents() == "after\n")
    }

    @Test func survivesAnUnwritableTargetAndRecovers() throws {
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        let log = scratch.makeLog()

        log.append("before")
        log.flush()

        // Put a directory where the file was: opening it for writing fails.
        // The line must be dropped quietly — not trap the process — and the
        // log must start working again once the obstruction is gone.
        try FileManager.default.removeItem(at: scratch.fileURL)
        try FileManager.default.createDirectory(at: scratch.fileURL, withIntermediateDirectories: false)
        log.append("dropped")
        log.flush()

        try FileManager.default.removeItem(at: scratch.fileURL)
        log.append("recovered")
        log.flush()

        #expect(scratch.contents() == "recovered\n")
    }

    @Test func isSafeToShareAcrossThreads() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        let log = scratch.makeLog()

        DispatchQueue.concurrentPerform(iterations: 200) { i in
            log.append("n\(i)")
        }
        log.flush()

        let lines = scratch.contents()?.split(separator: "\n") ?? []
        #expect(lines.count == 200)
        #expect(Set(lines).count == 200)
    }
}
#endif
