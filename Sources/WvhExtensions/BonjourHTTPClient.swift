//
//  BonjourHTTPClient.swift
//  WvhExtensions
//

import Foundation
import Network

/// A response from `BonjourHTTPClient.request(...)`: the parsed status code and the
/// response body (everything after the blank line separating headers from body).
public struct BonjourHTTPResponse {
    public let statusCode: Int
    public let body: Data
}

public enum BonjourHTTPClientError: Error {
    /// No Bonjour endpoint has been discovered yet, and no manual host override is set.
    case noEndpoint
    /// The connection closed without ever sending a recognizable HTTP response.
    case malformedResponse
    /// The request did not complete within the given timeout.
    case timedOut
}

/// Discovers a Bonjour-advertised HTTP service and issues raw HTTP/1.0 requests against
/// it directly over `NWConnection` — no `URL`/`URLSession` involved anywhere.
///
/// This exists because reconstructing a `URL` from a resolved Bonjour endpoint is fragile
/// in two independent ways: (1) gluing the Bonjour *instance name* onto the domain only
/// produces a connectable hostname if the advertised name happens to match the machine's
/// real mDNS hostname, and (2) a literal IP address harvested from one connection's
/// `currentPath.remoteEndpoint` can be an IPv6 *link-local* address that's only routable
/// via the specific interface/zone that resolved it — reusing that bare literal in a
/// separate `URLSession` request has no way to recover the zone and fails to route, even
/// though the network is otherwise fine.
///
/// This type avoids both problems by never converting the endpoint into a string at all:
/// each `request(...)` call opens a fresh `NWConnection` directly to the tracked
/// `NWEndpoint`, so `Network.framework` re-resolves and re-races (Happy Eyeballs) a
/// working route every time, the same way `WvhNfl`'s `FeedPoller` has always worked.
public final class BonjourHTTPClient {

    /// Lifecycle/connectivity state, surfaced for UI status display.
    public enum State: Equatable {
        case searching
        case discovered
        case manualOverride
    }

    private let bonjourType: String
    private let browseQueue: DispatchQueue
    private let onStateChange: ((State) -> Void)?

    private let lock = NSLock()
    private var browser: NWBrowser?
    private var discoveredEndpoint: NWEndpoint?
    private var manualEndpoint: NWEndpoint?
    private var manualHostPortString: String?
    private let defaultEndpoint: NWEndpoint?
    private let defaultHostPortString: String?

    /// - Parameters:
    ///   - bonjourType: e.g. `"_airporttracker._tcp"`.
    ///   - queueLabel: label for the browser's dispatch queue.
    ///   - defaultHostPort: an optional `"host:port"` fallback target to use until
    ///     discovery succeeds (or forever, if it never does) — e.g. `"localhost:8765"`
    ///     when the client usually runs on the same machine as the service, so the very
    ///     first request doesn't have to wait for Bonjour. Superseded by a real
    ///     discovered endpoint or an explicit manual override, in that priority order.
    ///   - onStateChange: called on an arbitrary queue whenever discovery state changes
    ///     (searching / discovered / manual override) — hop to your own actor/queue if needed.
    public init(
        bonjourType: String,
        queueLabel: String,
        defaultHostPort: String? = nil,
        onStateChange: ((State) -> Void)? = nil
    ) {
        self.bonjourType = bonjourType
        self.browseQueue = DispatchQueue(label: queueLabel)
        self.onStateChange = onStateChange
        self.defaultHostPortString = defaultHostPort
        self.defaultEndpoint = defaultHostPort.flatMap(Self.parseHostPort)
    }

    // MARK: - Discovery

    /// Starts Bonjour browsing. No-op if a manual host override is currently set —
    /// call `clearManualHost()` first to resume discovery.
    public func start() {
        guard manualHostPortString == nil else { return }
        startBrowsing()
    }

    public func stop() {
        browser?.cancel()
        browser = nil
    }

    /// Bypasses Bonjour discovery entirely and targets a fixed `"host:port"` string —
    /// e.g. for connecting to a daemon on a different machine, or a manually-typed
    /// override. Stops any in-progress browsing.
    public func setManualHost(_ hostPort: String) {
        stop()
        lock.lock()
        manualHostPortString = hostPort
        manualEndpoint = Self.parseHostPort(hostPort)
        lock.unlock()
        onStateChange?(.manualOverride)
    }

    /// Clears any manual host override and resumes Bonjour discovery.
    public func clearManualHost() {
        lock.lock()
        manualHostPortString = nil
        manualEndpoint = nil
        lock.unlock()
        start()
    }

    /// The endpoint a new connection would currently target, in priority order: an
    /// explicit manual override, else the most recently discovered Bonjour endpoint,
    /// else the `defaultHostPort` fallback given at init (or `nil` if none apply).
    public var currentEndpoint: NWEndpoint? {
        lock.lock()
        defer { lock.unlock() }
        return manualEndpoint ?? discoveredEndpoint ?? defaultEndpoint
    }

    /// Whether a real Bonjour endpoint or manual override is active — `false` while
    /// only the `defaultHostPort` fallback is in play.
    public var isDiscovered: Bool {
        lock.lock()
        defer { lock.unlock() }
        return manualEndpoint != nil || discoveredEndpoint != nil
    }

    /// A human-readable description of the current target, for UI status display only —
    /// never used for connecting, so it carries none of the fragility `request(...)` avoids.
    public var currentEndpointDescription: String? {
        lock.lock()
        let manual = manualHostPortString
        let discovered = discoveredEndpoint
        lock.unlock()

        if let manual { return manual }
        if let discovered {
            if case .service(let name, _, let domain, _) = discovered {
                let trimmedDomain = domain.hasSuffix(".") ? String(domain.dropLast()) : domain
                return "\(name).\(trimmedDomain)"
            }
            return "\(discovered)"
        }
        return defaultHostPortString
    }

    private func startBrowsing() {
        browser?.cancel()
        onStateChange?(.searching)

        let params = NWParameters()
        params.includePeerToPeer = true
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: bonjourType, domain: nil), using: params)
        browser = b

        b.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.browseQueue.asyncAfter(deadline: .now() + 5) { self?.startBrowsing() }
            }
        }

        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, let result = results.first else { return }
            self.lock.lock()
            self.discoveredEndpoint = result.endpoint
            self.lock.unlock()
            self.onStateChange?(.discovered)
        }

        b.start(queue: browseQueue)
    }

    // MARK: - Requests

    /// Issues a raw HTTP/1.0 request against the current endpoint and returns the status
    /// code + body. Throws `BonjourHTTPClientError.noEndpoint` if nothing has been
    /// discovered yet and no manual host is set.
    public func request(
        method: String = "GET",
        path: String,
        body: Data? = nil,
        timeout: TimeInterval = 10
    ) async throws -> BonjourHTTPResponse {
        guard let endpoint = currentEndpoint else {
            throw BonjourHTTPClientError.noEndpoint
        }
        return try await Self.httpRequest(endpoint: endpoint, method: method, path: path, body: body, timeout: timeout)
    }

    private static func httpRequest(
        endpoint: NWEndpoint,
        method: String,
        path: String,
        body: Data?,
        timeout: TimeInterval
    ) async throws -> BonjourHTTPResponse {
        try await withCheckedThrowingContinuation { continuation in
            let conn = NWConnection(to: endpoint, using: .tcp)
            let resumeLock = NSLock()
            var resumed = false
            var timeoutWorkItem: DispatchWorkItem?

            func finish(_ result: Result<BonjourHTTPResponse, Error>) {
                resumeLock.lock()
                guard !resumed else { resumeLock.unlock(); return }
                resumed = true
                resumeLock.unlock()
                timeoutWorkItem?.cancel()
                conn.cancel()
                switch result {
                case .success(let response): continuation.resume(returning: response)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }

            let workItem = DispatchWorkItem { finish(.failure(BonjourHTTPClientError.timedOut)) }
            timeoutWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout, execute: workItem)

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var requestText = "\(method) \(path) HTTP/1.0\r\nConnection: close\r\n"
                    if let body {
                        requestText += "Content-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n"
                    } else {
                        requestText += "\r\n"
                    }
                    var requestData = Data(requestText.utf8)
                    if let body { requestData.append(body) }

                    conn.send(content: requestData, completion: .contentProcessed { error in
                        if let error { finish(.failure(error)) }
                    })

                    var buffer = Data()
                    func readLoop() {
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { chunk, _, isComplete, error in
                            if let chunk { buffer.append(chunk) }
                            if let error { finish(.failure(error)); return }
                            if isComplete {
                                guard let sep = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                                    finish(.failure(BonjourHTTPClientError.malformedResponse))
                                    return
                                }
                                let header = String(data: buffer[buffer.startIndex..<sep.lowerBound], encoding: .utf8) ?? ""
                                let statusLine = header.split(separator: "\r\n", maxSplits: 1).first ?? ""
                                let statusCode = Int(statusLine.split(separator: " ", maxSplits: 2).dropFirst().first ?? "") ?? 0
                                finish(.success(BonjourHTTPResponse(statusCode: statusCode, body: Data(buffer[sep.upperBound...]))))
                            } else {
                                readLoop()
                            }
                        }
                    }
                    readLoop()
                case .failed(let error):
                    finish(.failure(error))
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }
    }

    /// Parses a manually-entered `"host:port"` string into an `NWEndpoint`.
    private static func parseHostPort(_ hostPort: String) -> NWEndpoint? {
        let parts = hostPort.split(separator: ":")
        guard parts.count == 2, let portValue = UInt16(parts[1]), let port = NWEndpoint.Port(rawValue: portValue) else {
            return nil
        }
        return NWEndpoint.hostPort(host: NWEndpoint.Host(String(parts[0])), port: port)
    }
}
