//
//  DatabaseManager.swift
//
//  Generic SQLite database downloader.
//  Drop into any project — no app-specific dependencies.
//  Configure the call site in AppData (or equivalent) with your baseURL and file list.
//

import Foundation
import OSLog

class DatabaseManager {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.app"
    private static let logger = Logger(subsystem: subsystem, category: "DatabaseManager")

    private static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    // MARK: - Public API

    /// Download a list of files from `baseURL` if the server has newer versions.
    ///
    /// - Parameters:
    ///   - baseURL: Root URL; each file name is appended to form the full URL.
    ///   - files:   Array of `(name, optional)` tuples.
    ///              When `optional` is true a 404 response is not treated as an error.
    ///   - progressCallback: Called on MainActor with a 0–1 fraction and a status string.
    @MainActor
    static func updateDatabases(
        from baseURL: String,
        files: [(name: String, optional: Bool)],
        progressCallback: (@MainActor @Sendable (Double, String) -> Void)? = nil
    ) async -> Bool {

        guard !files.isEmpty else {
            progressCallback?(1.0, "Nothing to download")
            return true
        }

        let slotWidth = 1.0 / Double(files.count)
        var success = true

        for (index, file) in files.enumerated() {
            let baseProgress = Double(index) * slotWidth
            progressCallback?(baseProgress, "Checking \(file.name)...")
            let result = await downloadIfNeeded(
                name: file.name,
                optional: file.optional,
                baseURL: baseURL,
                baseProgress: baseProgress,
                slotWidth: slotWidth,
                progressCallback: progressCallback
            )
            if !result {
                success = false
            }
        }

        progressCallback?(1.0, "Download complete")
        return success
    }

//    /// Returns true if the main database exists locally and appears valid.
//    static func databasesExist() -> Bool {
//        return FileManager.default.fileExists(atPath: mainDBPath.path)
//    }

    // MARK: - Private

    @MainActor
    private static func downloadIfNeeded(
        name: String,
        optional: Bool,
        baseURL: String,
        baseProgress: Double,
        slotWidth: Double,
        progressCallback: (@MainActor @Sendable (Double, String) -> Void)?
    ) async -> Bool {

        guard let remoteURL = URL(string: baseURL + name) else {
            logger.error("Invalid URL for \(name)")
            return false
        }

        let localPath = documentsDirectory.appendingPathComponent(name)

        let localModDate = try? FileManager.default.attributesOfItem(
            atPath: localPath.path)[.modificationDate] as? Date
        let localFileSize = (try? FileManager.default.attributesOfItem(
            atPath: localPath.path)[.size] as? Int) ?? 0
        let localFileIsValid = localFileSize > 4096

        do {
            // HEAD request — check Last-Modified and Content-Length
            var headRequest = URLRequest(url: remoteURL)
            headRequest.httpMethod = "HEAD"
            let (_, headResponse) = try await URLSession.shared.data(for: headRequest)

            guard let http = headResponse as? HTTPURLResponse else {
                logger.error("Invalid HEAD response for \(name)")
                return false
            }

            if http.statusCode == 404 && optional {
                logger.info("\(name) not on server yet (optional, skipping)")
                return true
            }
            guard http.statusCode == 200 else {
                logger.error("\(name) HEAD returned HTTP \(http.statusCode)")
                return false
            }

            let expectedBytes = Int(http.value(forHTTPHeaderField: "Content-Length") ?? "") ?? 0

            // Decide whether to download
            var shouldDownload: Bool
            if let serverModDate = http.value(forHTTPHeaderField: "Last-Modified")
                .flatMap(DateFormatter.httpDateFormatter.date(from:)) {
                if let localDate = localModDate, localFileIsValid {
                    shouldDownload = serverModDate > localDate
                    if shouldDownload {
                        logger.info("\(name) server newer (server: \(serverModDate), local: \(localDate))")
                    }
                } else {
                    shouldDownload = true
                    logger.info("\(name) not found locally or invalid — will download")
                }
            } else {
                shouldDownload = !localFileIsValid
            }

            guard shouldDownload else {
                logger.info("\(name) is up to date")
                return true
            }

            // Download with real byte-level progress via URLSessionDownloadDelegate.
            // URLSession streams to a temp file internally — no byte-by-byte overhead.
            progressCallback?(baseProgress, "Downloading \(name) 0%...")
            logger.info("Downloading \(name) (expected \(expectedBytes) bytes)...")

            let delegate = DownloadProgressDelegate { fraction in
                Task { @MainActor in
                    progressCallback?(
                        baseProgress + fraction * slotWidth * 0.9,
                        "Downloading \(name) \(Int(fraction * 100))%..."
                    )
                }
            }

            let (tempURL, dlResponse) = try await URLSession.shared.download(from: remoteURL, delegate: delegate)
            guard let dlHttp = dlResponse as? HTTPURLResponse, dlHttp.statusCode == 200 else {
                logger.error("Failed to download \(name)")
                return false
            }

            progressCallback?(baseProgress + slotWidth * 0.92, "Saving \(name)...")

            // Move URLSession's temp file to final location atomically.
            if FileManager.default.fileExists(atPath: localPath.path) {
                try FileManager.default.removeItem(at: localPath)
            }
            try FileManager.default.moveItem(at: tempURL, to: localPath)

            let savedSize = (try? FileManager.default.attributesOfItem(atPath: localPath.path)[.size] as? Int) ?? 0
            progressCallback?(baseProgress + slotWidth, "Saved \(name)")
            logger.info("Downloaded \(name) — \(savedSize) bytes")
            return true

        } catch {
            logger.error("Error updating \(name): \(error.localizedDescription)")
            return FileManager.default.fileExists(atPath: localPath.path)
        }
    }
}

// MARK: - Download progress delegate

/// Receives URLSession chunk callbacks on a background queue and forwards
/// the 0–1 fraction to the caller's closure.  The caller is responsible for
/// hopping to the correct actor before touching UI state.
private final class DownloadProgressDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    // Required by URLSessionDownloadDelegate; handled by the async/await API.
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {}
}

// MARK: - HTTP date parsing

extension DateFormatter {
    static let httpDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "GMT")
        return f
    }()
}
