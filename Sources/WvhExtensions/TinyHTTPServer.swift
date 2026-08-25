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
    private let bonjourType: String
    private let bonjourName: String
    private let handler: (HTTPRequestInfo) async -> HTTPResponseInfo
    private let onInfo: ((String) -> Void)?
    private let onError: ((String) -> Void)?

    private var listener: NWListener?
    private let listenerQueue: DispatchQueue
    private let connectionQueue: DispatchQueue

    public init(
        port: NWEndpoint.Port,
        bonjourType: String,
        bonjourName: String,
        listenerQueueLabel: String,
        connectionQueueLabel: String,
        onInfo: ((String) -> Void)? = nil,
        onError: ((String) -> Void)? = nil,
        handler: @escaping (HTTPRequestInfo) async -> HTTPResponseInfo
    ) {
        self.port = port
        self.bonjourType = bonjourType
        self.bonjourName = bonjourName
        self.onInfo = onInfo
        self.onError = onError
        self.handler = handler
        self.listenerQueue = DispatchQueue(label: listenerQueueLabel)
        self.connectionQueue = DispatchQueue(label: connectionQueueLabel, attributes: .concurrent)
    }

    public func start() {
        guard let listener = try? NWListener(using: .tcp, on: port) else {
            onError?("failed to create listener on port \(port.rawValue)")
            return
        }

        listener.service = NWListener.Service(name: bonjourName, type: bonjourType)

        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.onInfo?("listening on port \(self.port.rawValue), advertising as \"\(self.bonjourName)\"")
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

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: connectionQueue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                Task {
                    let response = await self.buildResponse(for: data)
                    connection.send(content: response, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            } else {
                connection.cancel()
            }
        }
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
