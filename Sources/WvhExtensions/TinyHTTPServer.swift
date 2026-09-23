//
//  TinyHTTPServer.swift
//  WvhExtensions
//

import Foundation
import Network

/// A parsed request: just enough of HTTP/1.1 for a small local JSON API —
/// method, path, query parameters, and the raw request bytes (for a POST body).
public struct HTTPRequestInfo {
    public let method: String
    public let path: String
    public let query: [String: String]
    public let rawRequest: Data
}

/// A response to send back: status line, content type, and body.
public struct HTTPResponseInfo {
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
public final class TinyHTTPServer {
    public let port: NWEndpoint.Port
    private let bindToLoopbackOnly: Bool
    private let bonjourType: String?
    private let bonjourName: String?
    private let handler: (HTTPRequestInfo) async -> HTTPResponseInfo
    private let onInfo: ((String) -> Void)?
    private let onError: ((String) -> Void)?

    private var listener: NWListener?
    private let listenerQueue: DispatchQueue
    private let connectionQueue: DispatchQueue

    /// - Parameters:
    ///   - bindToLoopbackOnly: When true, the listener only accepts connections
    ///     from this Mac (127.0.0.1) — for a control channel meant for a
    ///     same-machine caller, not other devices on the LAN.
    ///   - bonjourType/bonjourName: Omit both to skip Bonjour advertisement
    ///     entirely, e.g. for a loopback-only control channel that callers
    ///     reach by a known port rather than discovery.
    public init(
        port: NWEndpoint.Port,
        bindToLoopbackOnly: Bool = false,
        bonjourType: String? = nil,
        bonjourName: String? = nil,
        listenerQueueLabel: String,
        connectionQueueLabel: String,
        onInfo: ((String) -> Void)? = nil,
        onError: ((String) -> Void)? = nil,
        handler: @escaping (HTTPRequestInfo) async -> HTTPResponseInfo
    ) {
        self.port = port
        self.bindToLoopbackOnly = bindToLoopbackOnly
        self.bonjourType = bonjourType
        self.bonjourName = bonjourName
        self.onInfo = onInfo
        self.onError = onError
        self.handler = handler
        self.listenerQueue = DispatchQueue(label: listenerQueueLabel)
        self.connectionQueue = DispatchQueue(label: connectionQueueLabel, attributes: .concurrent)
    }

    public func start() {
        let parameters = NWParameters.tcp
        // Loopback binding is macOS-only in practice (daemons/CLI tools),
        // and NWParametersProvider.localEndpoint(_:) needs macOS 26 — which
        // this package only requires on macOS, not iOS/tvOS. Gating by
        // platform avoids forcing every iOS consumer up to iOS 26 for a
        // capability they'd never use.
        #if os(macOS)
        if bindToLoopbackOnly {
            _ = parameters.localEndpoint(NWEndpoint.hostPort(host: "127.0.0.1", port: port))
        }
        #endif
        guard let listener = try? NWListener(using: parameters, on: port) else {
            onError?("failed to create listener on port \(port.rawValue)")
            return
        }

        if let bonjourType, let bonjourName {
            listener.service = NWListener.Service(name: bonjourName, type: bonjourType)
        }

        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if let bonjourName = self.bonjourName {
                    self.onInfo?("listening on port \(self.port.rawValue), advertising as \"\(bonjourName)\"")
                } else {
                    self.onInfo?("listening on port \(self.port.rawValue) (loopback only, no Bonjour)")
                }
            case .failed(let error):
                self.onError?("listener failed: \(error)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: listenerQueue)
        self.listener = listener
    }

    // MARK: - Connection handling

    // A request whose headers+body don't all land in a single `receive()`
    // callback — a body over ~8KB, or just bytes split across TCP segments —
    // used to be handed to `buildResponse` truncated, since the old
    // implementation treated the first callback's data as the whole request.
    // This accumulates across calls until the framed message (by
    // Content-Length, once headers are complete) is fully received.
    private enum RequestFraming {
        case complete(Data)
        case incomplete
        case malformed
    }

    private static let maxHeaderBytes = 65536

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: connectionQueue)
        receiveMore(on: connection, buffer: Data())
    }

    private func receiveMore(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] chunk, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let chunk { buffer.append(chunk) }

            if error != nil || (buffer.isEmpty && isComplete) {
                connection.cancel()
                return
            }

            switch Self.framing(of: buffer) {
            case .complete(let requestData):
                Task {
                    let response = await self.buildResponse(for: requestData)
                    connection.send(content: response, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            case .malformed:
                connection.cancel()
            case .incomplete:
                if isComplete {
                    // Connection closed before a full request ever arrived.
                    connection.cancel()
                } else {
                    self.receiveMore(on: connection, buffer: buffer)
                }
            }
        }
    }

    // Headers are complete once "\r\n\r\n" appears; the body (if any) is
    // framed by Content-Length, since nothing here waits for the client to
    // close its side of the connection.
    private static func framing(of buffer: Data) -> RequestFraming {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return buffer.count > maxHeaderBytes ? .malformed : .incomplete
        }
        let headerData = buffer[buffer.startIndex..<headerEnd.lowerBound]
        let headerString = String(data: headerData, encoding: .utf8) ?? ""
        let contentLength = parseContentLength(from: headerString) ?? 0
        let bodyBytesReceived = buffer.distance(from: headerEnd.upperBound, to: buffer.endIndex)
        return bodyBytesReceived >= contentLength ? .complete(buffer) : .incomplete
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
