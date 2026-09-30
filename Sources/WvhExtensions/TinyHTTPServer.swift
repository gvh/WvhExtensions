//
//  TinyHTTPServer.swift
//  WvhExtensions
//

import Foundation
import Network

/// A parsed request: just enough of HTTP/1.1 for a small local JSON API —
/// method, path, query parameters, and the raw request bytes (for a POST body).
public struct HTTPRequestInfo: Sendable {
    public let method: String
    public let path: String
    public let query: [String: String]
    public let rawRequest: Data
}

/// A response to send back: status line, content type, and body.
public struct HTTPResponseInfo: Sendable {
    public let status: String
    public let contentType: String
    public let body: Data

    public init(status: String, contentType: String, body: Data) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    public static func ok(json body: Data) -> HTTPResponseInfo {
        .init(status: "200 OK", contentType: "application/json", body: body)
    }

    public static func ok(text body: String) -> HTTPResponseInfo {
        .init(status: "200 OK", contentType: "text/plain", body: Data(body.utf8))
    }

    public static func notFound(_ message: String = "not found") -> HTTPResponseInfo {
        .init(status: "404 Not Found", contentType: "text/plain", body: Data(message.utf8))
    }

    public static func badRequest(_ message: String) -> HTTPResponseInfo {
        .init(status: "400 Bad Request", contentType: "text/plain", body: Data(message.utf8))
    }

    public static func payloadTooLarge(_ message: String = "request too large") -> HTTPResponseInfo {
        .init(status: "413 Payload Too Large", contentType: "text/plain", body: Data(message.utf8))
    }

    public static func serverError(_ message: String) -> HTTPResponseInfo {
        .init(status: "500 Internal Server Error", contentType: "text/plain", body: Data(message.utf8))
    }

    public static func serviceUnavailable(_ message: String) -> HTTPResponseInfo {
        .init(status: "503 Service Unavailable", contentType: "text/plain", body: Data(message.utf8))
    }
}

/// A minimal hand-rolled HTTP/1.1 server over `Network.framework`, with an
/// optional Bonjour advertisement. Parses only what a small local JSON API
/// needs — the request line's method/path/query string — and leaves routing
/// entirely to the caller's `handler`.
///
/// This owns the listener lifecycle and wire format only; snapshot/state
/// storage and route logic belong in the caller, which is why `handler`
/// receives just the parsed request and returns a response, rather than this
/// type owning any domain state.
///
/// It is meant to face a LAN, so it defends itself against a stalled or
/// hostile peer: requests are capped in size (`maxRequestBytes`), must arrive
/// within `requestTimeout`, and only `maxConnections` may be open at once. If
/// the listener fails (port taken, network stack reset) it is rebuilt with
/// exponential backoff until `stop()`.
///
/// `@unchecked Sendable`: this type's own mutable state is guarded by a lock
/// and its callbacks run on its own queues. The `handler`/`onInfo`/`onError`
/// closures are the caller's — they are invoked from those queues, and any
/// state they capture must be safe to touch from there.
public final class TinyHTTPServer: @unchecked Sendable {
    public let port: NWEndpoint.Port
    private let bindToLoopbackOnly: Bool
    private let bonjourType: String?
    private let bonjourName: String?
    private let maxRequestBytes: Int
    private let requestTimeout: TimeInterval
    private let maxConnections: Int
    private let handler: (HTTPRequestInfo) async -> HTTPResponseInfo
    private let onInfo: ((String) -> Void)?
    private let onError: ((String) -> Void)?

    private let listenerQueue: DispatchQueue
    private let connectionQueue: DispatchQueue

    // Everything below is guarded by `lock`.
    private let lock = NSLock()
    private var listener: NWListener?
    private var isStopped = true
    private var restartDelay = TinyHTTPServer.initialRestartDelay
    private var openConnections = 0

    private static let initialRestartDelay: TimeInterval = 1
    private static let maxRestartDelay: TimeInterval = 30
    private static let maxHeaderBytes = 65536
    private static let receiveChunkBytes = 65536

    /// - Parameters:
    ///   - bindToLoopbackOnly: When true, the listener only accepts connections
    ///     from this Mac (127.0.0.1) — for a control channel meant for a
    ///     same-machine caller, not other devices on the LAN.
    ///   - bonjourType/bonjourName: Omit both to skip Bonjour advertisement
    ///     entirely, e.g. for a loopback-only control channel that callers
    ///     reach by a known port rather than discovery.
    ///   - maxRequestBytes: Largest request (headers plus body) accepted. A
    ///     request declaring more is answered `413` without being read.
    ///   - requestTimeout: How long a peer has to deliver a complete request
    ///     (and, separately, to accept the response) before the connection is
    ///     dropped. Time spent inside `handler` doesn't count.
    ///   - maxConnections: Connections open at once; further ones are dropped
    ///     immediately. Keep it well under the process's file-descriptor limit.
    public init(
        port: NWEndpoint.Port,
        bindToLoopbackOnly: Bool = false,
        bonjourType: String? = nil,
        bonjourName: String? = nil,
        listenerQueueLabel: String,
        connectionQueueLabel: String,
        maxRequestBytes: Int = 16 * 1024 * 1024,
        requestTimeout: TimeInterval = 30,
        maxConnections: Int = 128,
        onInfo: ((String) -> Void)? = nil,
        onError: ((String) -> Void)? = nil,
        handler: @escaping (HTTPRequestInfo) async -> HTTPResponseInfo
    ) {
        self.port = port
        self.bindToLoopbackOnly = bindToLoopbackOnly
        self.bonjourType = bonjourType
        self.bonjourName = bonjourName
        self.maxRequestBytes = maxRequestBytes
        self.requestTimeout = requestTimeout
        self.maxConnections = maxConnections
        self.onInfo = onInfo
        self.onError = onError
        self.handler = handler
        self.listenerQueue = DispatchQueue(label: listenerQueueLabel)
        self.connectionQueue = DispatchQueue(label: connectionQueueLabel, attributes: .concurrent)
    }

    // MARK: - Listener lifecycle

    /// Starts listening. Returns immediately; if the listener can't be created
    /// or later fails, it is retried in the background (see `onError`) until
    /// `stop()`. Calling it while already started does nothing.
    public func start() {
        lock.lock()
        guard isStopped else { lock.unlock(); return }
        isStopped = false
        restartDelay = Self.initialRestartDelay
        lock.unlock()
        startListener()
    }

    /// Stops listening and cancels any pending restart. Connections already
    /// being served run to completion.
    public func stop() {
        lock.lock()
        isStopped = true
        let current = listener
        listener = nil
        lock.unlock()
        current?.cancel()
    }

    private func startListener() {
        let parameters = NWParameters.tcp
        // Whether the loopback endpoint (which carries the port) is what binds
        // the listener, instead of `on: port`.
        var portComesFromParameters = false
        // Loopback binding is macOS-only in practice (daemons/CLI tools),
        // and NWParametersProvider.localEndpoint(_:) needs macOS 26 — which
        // this package only requires on macOS, not iOS/tvOS. Gating by
        // platform avoids forcing every iOS consumer up to iOS 26 for a
        // capability they'd never use.
        #if os(macOS)
        if bindToLoopbackOnly {
            _ = parameters.localEndpoint(NWEndpoint.hostPort(host: "127.0.0.1", port: port))
            portComesFromParameters = true
        }
        #endif

        let newListener: NWListener
        do {
            // A listener can't be given a required local endpoint *and* `on:
            // port` — NWListener throws EINVAL. When loopback-only, the
            // endpoint already names the port, so `on:` must be omitted.
            newListener = portComesFromParameters
                ? try NWListener(using: parameters)
                : try NWListener(using: parameters, on: port)
        } catch {
            onError?("failed to create listener on port \(port.rawValue): \(error)")
            scheduleRestart(replacing: nil)
            return
        }

        if let bonjourType, let bonjourName {
            newListener.service = NWListener.Service(name: bonjourName, type: bonjourType)
        }

        lock.lock()
        guard !isStopped else { lock.unlock(); return }   // stop() won the race
        listener = newListener
        lock.unlock()

        newListener.stateUpdateHandler = { [weak self, weak newListener] state in
            guard let self, let newListener else { return }
            self.listenerStateChanged(state, for: newListener)
        }
        newListener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        newListener.start(queue: listenerQueue)
    }

    private func listenerStateChanged(_ state: NWListener.State, for failing: NWListener) {
        switch state {
        case .ready:
            lock.lock()
            restartDelay = Self.initialRestartDelay
            lock.unlock()
            if let bonjourName {
                onInfo?("listening on port \(port.rawValue), advertising as \"\(bonjourName)\"")
            } else {
                onInfo?("listening on port \(port.rawValue) (loopback only, no Bonjour)")
            }
        case .failed(let error):
            onError?("listener failed: \(error)")
            failing.cancel()
            scheduleRestart(replacing: failing)
        default:
            break
        }
    }

    /// Rebuilds the listener after `delay` (doubling each consecutive failure,
    /// capped). `failed` is the listener that just died, or `nil` if one was
    /// never created; a report from a listener that is no longer current, or
    /// after `stop()`, is ignored.
    private func scheduleRestart(replacing failed: NWListener?) {
        lock.lock()
        if isStopped || (failed != nil && listener !== failed) {
            lock.unlock()
            return
        }
        if failed != nil { listener = nil }
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, Self.maxRestartDelay)
        lock.unlock()

        onInfo?("retrying listener on port \(port.rawValue) in \(Int(delay))s")
        listenerQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let shouldRestart = !self.isStopped && self.listener == nil
            self.lock.unlock()
            if shouldRestart { self.startListener() }
        }
    }

    // MARK: - Connection handling

    private enum Framing {
        case complete
        case incomplete
        case malformed
        case tooLarge
    }

    /// A request being accumulated across `receive()` callbacks. A request
    /// whose headers+body don't all land in one callback — a body over a few
    /// KB, or just bytes split across TCP segments — must be reassembled
    /// before it is handed to the handler. The header block is parsed once;
    /// after that only the byte count is compared, so a large body isn't
    /// rescanned on every chunk.
    private struct PendingRequest {
        var buffer = Data()
        /// Header block plus `Content-Length` body, known once the headers are complete.
        var expectedTotalBytes: Int?
    }

    /// Releases a connection's slot exactly once, however it ends.
    private final class ConnectionSlot {
        var isReleased = false
    }

    private func reserveConnectionSlot() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard openConnections < maxConnections else { return false }
        openConnections += 1
        return true
    }

    private func release(_ slot: ConnectionSlot) {
        lock.lock()
        if !slot.isReleased {
            slot.isReleased = true
            openConnections -= 1
        }
        lock.unlock()
    }

    private func handleConnection(_ connection: NWConnection) {
        guard reserveConnectionSlot() else {
            onError?("dropping connection: \(maxConnections) already open")
            connection.cancel()
            return
        }
        let slot = ConnectionSlot()
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .failed:
                connection?.cancel()
            case .cancelled:
                self?.release(slot)
            default:
                break
            }
        }
        connection.start(queue: connectionQueue)

        // The peer has `requestTimeout` to deliver the whole request.
        let deadline = DispatchWorkItem { [weak connection] in connection?.cancel() }
        connectionQueue.asyncAfter(deadline: .now() + requestTimeout, execute: deadline)
        receiveMore(on: connection, pending: PendingRequest(), deadline: deadline)
    }

    private func receiveMore(on connection: NWConnection, pending: PendingRequest, deadline: DispatchWorkItem) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.receiveChunkBytes) { [weak self] chunk, _, isComplete, error in
            guard let self else {
                deadline.cancel()
                connection.cancel()
                return
            }
            var pending = pending
            if let chunk { pending.buffer.append(chunk) }

            if error != nil || (pending.buffer.isEmpty && isComplete) {
                deadline.cancel()
                connection.cancel()
                return
            }

            switch self.advance(&pending) {
            case .complete:
                deadline.cancel()
                let requestData = pending.buffer
                Task {
                    let response = await self.buildResponse(for: requestData)
                    self.send(response, on: connection)
                }
            case .tooLarge:
                deadline.cancel()
                self.send(Self.encode(.payloadTooLarge()), on: connection)
            case .malformed:
                deadline.cancel()
                connection.cancel()
            case .incomplete:
                if isComplete {
                    // Connection closed before a full request ever arrived.
                    deadline.cancel()
                    connection.cancel()
                } else {
                    self.receiveMore(on: connection, pending: pending, deadline: deadline)
                }
            }
        }
    }

    /// Sends `data`, then closes. A peer that never reads gets `requestTimeout`
    /// to accept it before the connection is dropped.
    private func send(_ data: Data, on connection: NWConnection) {
        let deadline = DispatchWorkItem { connection.cancel() }
        connectionQueue.asyncAfter(deadline: .now() + requestTimeout, execute: deadline)
        connection.send(content: data, completion: .contentProcessed { _ in
            deadline.cancel()
            connection.cancel()
        })
    }

    // Headers are complete once "\r\n\r\n" appears; the body (if any) is
    // framed by Content-Length, since nothing here waits for the client to
    // close its side of the connection.
    private func advance(_ pending: inout PendingRequest) -> Framing {
        if pending.expectedTotalBytes == nil {
            guard let headerEnd = pending.buffer.range(of: Data("\r\n\r\n".utf8)) else {
                return pending.buffer.count > Self.maxHeaderBytes ? .malformed : .incomplete
            }
            let headerBytes = pending.buffer.distance(from: pending.buffer.startIndex, to: headerEnd.lowerBound)
            guard headerBytes <= Self.maxHeaderBytes else { return .malformed }

            let headerData = pending.buffer[pending.buffer.startIndex..<headerEnd.lowerBound]
            let headerString = String(data: headerData, encoding: .utf8) ?? ""
            let contentLength = Self.parseContentLength(from: headerString) ?? 0
            guard contentLength >= 0 else { return .malformed }
            // Checked before adding, so an absurd Content-Length can't overflow.
            guard contentLength <= maxRequestBytes else { return .tooLarge }

            let total = headerBytes + 4 + contentLength
            guard total <= maxRequestBytes else { return .tooLarge }
            pending.expectedTotalBytes = total
        }
        guard let expected = pending.expectedTotalBytes else { return .incomplete }
        return pending.buffer.count >= expected ? .complete : .incomplete
    }

    private static func parseContentLength(from headerString: String) -> Int? {
        for line in headerString.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  String(parts[0]).trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("Content-Length") == .orderedSame
            else { continue }
            return Int(String(parts[1]).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private func buildResponse(for requestData: Data) async -> Data {
        let requestLine = String(data: requestData.prefix(512), encoding: .utf8) ?? ""
        let parts = requestLine.components(separatedBy: " ")
        let method = parts.first ?? "GET"
        let rawPath = parts.count >= 2 ? parts[1] : "/"
        let path = rawPath.components(separatedBy: "?").first ?? "/"
        let query = Self.parseQueryParams(from: rawPath)

        let request = HTTPRequestInfo(method: method, path: path, query: query, rawRequest: requestData)
        let response = await handler(request)
        return Self.encode(response)
    }

    // Extracts query params from "GET /path?key=value&other=x HTTP/1.1\r\n..."
    private static func parseQueryParams(from rawPath: String) -> [String: String] {
        guard let queryString = rawPath.components(separatedBy: "?").dropFirst().first else { return [:] }
        var result: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            result[String(kv[0])] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
        }
        return result
    }

    private static func encode(_ response: HTTPResponseInfo) -> Data {
        let header = "HTTP/1.1 \(response.status)\r\nContent-Type: \(response.contentType)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(response.body)
        return data
    }
}
