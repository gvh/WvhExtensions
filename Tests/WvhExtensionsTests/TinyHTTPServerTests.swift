//
//  TinyHTTPServerTests.swift
//  WvhExtensionsTests
//
//  Drives a real TinyHTTPServer over loopback with a raw TCP client, since the
//  behaviour under test — partial requests, stalled peers, port collisions —
//  only exists on a socket.
//

import Testing
import Foundation
import Network
import Darwin
@testable import WvhExtensions

// MARK: - Helpers

/// A port that was free a moment ago.
private func freePort() -> UInt16 {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    defer { close(fd) }
    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = 0
    addr.sin_addr.s_addr = 0
    _ = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &bound) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(fd, $0, &length)
        }
    }
    return UInt16(bigEndian: bound.sin_port)
}

private var serverCounter = 0

/// This Mac's first non-loopback IPv4 address, if it has one.
private func lanAddress() -> String? {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return nil }
    defer { freeifaddrs(head) }
    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let ifa = cursor {
        defer { cursor = ifa.pointee.ifa_next }
        guard let sa = ifa.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
        let flags = Int32(ifa.pointee.ifa_flags)
        guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(sa, socklen_t(sa.pointee.sa_len), &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST)
        return String(cString: buffer)
    }
    return nil
}

private func makeServer(
    port: UInt16,
    label: String = "test",
    loopbackOnly: Bool = true,
    maxRequestBytes: Int = 16 * 1024 * 1024,
    requestTimeout: TimeInterval = 30,
    maxConnections: Int = 128,
    handler: @escaping (HTTPRequestInfo) async -> HTTPResponseInfo
) -> TinyHTTPServer {
    serverCounter += 1
    return TinyHTTPServer(
        port: NWEndpoint.Port(rawValue: port)!,
        bindToLoopbackOnly: loopbackOnly,
        listenerQueueLabel: "\(label).listener.\(serverCounter)",
        connectionQueueLabel: "\(label).connection.\(serverCounter)",
        maxRequestBytes: maxRequestBytes,
        requestTimeout: requestTimeout,
        maxConnections: maxConnections,
        handler: handler
    )
}

/// Answers with the path, the query value `x`, and the raw request's byte count.
private let echoHandler: (HTTPRequestInfo) async -> HTTPResponseInfo = { request in
    .ok(text: "path=\(request.path) x=\(request.query["x"] ?? "-") bytes=\(request.rawRequest.count)")
}

private final class ReadState: @unchecked Sendable {
    let lock = NSLock()
    var data = Data()
    var done = false
}

/// A bare TCP client: no HTTP smarts, so tests control exactly which bytes
/// arrive and when.
private final class RawClient: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "test.rawclient")

    init(port: UInt16, host: String = "127.0.0.1") {
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    }

    /// Whether the TCP connection reached `.ready`.
    func connect() async -> Bool {
        await withCheckedContinuation { continuation in
            let resumed = ReadState()
            connection.stateUpdateHandler = { state in
                resumed.lock.lock(); defer { resumed.lock.unlock() }
                guard !resumed.done else { return }
                switch state {
                case .ready:
                    resumed.done = true
                    continuation.resume(returning: true)
                case .failed, .cancelled, .waiting:
                    // A refused connection sits in `.waiting` (it would retry);
                    // for these tests that is a definitive "nobody's listening".
                    resumed.done = true
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ string: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.send(content: Data(string.utf8), completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
    }

    /// Reads until the peer closes or `timeout` passes. `closed` says which.
    func readToEnd(timeout: TimeInterval) async -> (text: String, closed: Bool) {
        await withCheckedContinuation { continuation in
            let state = ReadState()
            func finish(closed: Bool) {
                state.lock.lock()
                guard !state.done else { state.lock.unlock(); return }
                state.done = true
                let text = String(decoding: state.data, as: UTF8.self)
                state.lock.unlock()
                continuation.resume(returning: (text, closed))
            }
            let timer = DispatchWorkItem { finish(closed: false) }
            queue.asyncAfter(deadline: .now() + timeout, execute: timer)

            func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let data {
                        state.lock.lock(); state.data.append(data); state.lock.unlock()
                    }
                    if isComplete || error != nil {
                        timer.cancel()
                        finish(closed: true)
                    } else {
                        receiveNext()
                    }
                }
            }
            receiveNext()
        }
    }

    func close() { connection.cancel() }
}

private func pause(_ milliseconds: Int) async {
    try? await Task.sleep(for: .milliseconds(milliseconds))
}

/// One GET, answered in full. `nil` if the connection couldn't be made.
private func get(_ path: String, port: UInt16, host: String = "127.0.0.1", timeout: TimeInterval = 3) async -> String? {
    let client = RawClient(port: port, host: host)
    defer { client.close() }
    guard await client.connect() else { return nil }
    await client.send("GET \(path) HTTP/1.1\r\nHost: localhost\r\n\r\n")
    let result = await client.readToEnd(timeout: timeout)
    return result.text.isEmpty ? nil : result.text
}

// MARK: - Tests

@Suite(.serialized)
struct TinyHTTPServerTests {

    @Test func servesASimpleGet() async {
        let port = freePort()
        let server = makeServer(port: port, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        let response = await get("/hello?x=42", port: port)
        #expect(response?.hasPrefix("HTTP/1.1 200 OK") == true)
        #expect(response?.contains("path=/hello x=42") == true)
    }

    @Test func reassemblesARequestSplitAcrossSegments() async {
        let port = freePort()
        let server = makeServer(port: port, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        let client = RawClient(port: port)
        defer { client.close() }
        #expect(await client.connect())
        let head = "POST /p HTTP/1.1\r\nHost: localhost\r\nContent-Length: 10\r\n\r\n"
        await client.send(head + "12345")
        await pause(150)
        await client.send("67890")

        let result = await client.readToEnd(timeout: 3)
        #expect(result.text.hasPrefix("HTTP/1.1 200 OK"))
        #expect(result.text.contains("bytes=\(head.utf8.count + 10)"))
    }

    @Test func rejectsARequestOverTheSizeCapWith413() async {
        let port = freePort()
        let server = makeServer(port: port, maxRequestBytes: 1024, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        // Declared size is enormous and no body ever follows; the server must
        // answer from the header alone instead of waiting for (and buffering) it.
        let client = RawClient(port: port)
        defer { client.close() }
        #expect(await client.connect())
        await client.send("POST /p HTTP/1.1\r\nContent-Length: 999999999999\r\n\r\n")
        let result = await client.readToEnd(timeout: 3)
        #expect(result.text.hasPrefix("HTTP/1.1 413"))
        #expect(result.closed)
    }

    @Test func rejectsANegativeContentLength() async {
        let port = freePort()
        let server = makeServer(port: port, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        let client = RawClient(port: port)
        defer { client.close() }
        #expect(await client.connect())
        await client.send("POST /p HTTP/1.1\r\nContent-Length: -5\r\n\r\n")
        let result = await client.readToEnd(timeout: 3)
        // Malformed: dropped without dispatching to the handler.
        #expect(result.closed)
        #expect(!result.text.contains("200 OK"))
    }

    @Test func dropsAPeerThatNeverFinishesItsRequest() async {
        let port = freePort()
        let server = makeServer(port: port, requestTimeout: 0.5, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        let client = RawClient(port: port)
        defer { client.close() }
        #expect(await client.connect())
        await client.send("GET / HT")   // …and then silence

        let started = Date()
        let result = await client.readToEnd(timeout: 5)
        #expect(result.closed)
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test func capsOpenConnectionsAndFreesTheSlotOnClose() async {
        let port = freePort()
        let server = makeServer(port: port, maxConnections: 2, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        let first = RawClient(port: port)
        let second = RawClient(port: port)
        let third = RawClient(port: port)
        defer { first.close(); second.close(); third.close() }
        #expect(await first.connect())
        #expect(await second.connect())
        await pause(200)                       // let the server register both

        // The third is over the cap: the server drops it straight away…
        #expect(await third.connect())
        let overflow = await third.readToEnd(timeout: 2)
        #expect(overflow.closed)

        // …while the two within the cap are left alone.
        let stillOpen = await first.readToEnd(timeout: 0.3)
        #expect(!stillOpen.closed)

        // Closing one frees its slot for a new client.
        first.close()
        await pause(300)
        let response = await get("/again", port: port)
        #expect(response?.hasPrefix("HTTP/1.1 200 OK") == true)
    }

    @Test func rebuildsItsListenerAfterAPortCollisionClears() async {
        let port = freePort()
        let holder = makeServer(port: port, label: "holder") { _ in .ok(text: "holder") }
        holder.start()
        await pause(300)

        // Same port, already taken: the listener fails and must keep retrying
        // rather than staying up-but-deaf.
        let waiting = makeServer(port: port, label: "waiting") { _ in .ok(text: "waiting") }
        waiting.start()
        defer { waiting.stop(); holder.stop() }
        await pause(400)
        #expect(await get("/", port: port)?.contains("holder") == true)

        holder.stop()

        // Backoff starts at 1s; allow a few attempts.
        var served = false
        for _ in 0..<20 {
            await pause(500)
            if await get("/", port: port, timeout: 1)?.contains("waiting") == true {
                served = true
                break
            }
        }
        #expect(served)
    }

    @Test func stopPreventsAnyFurtherRestart() async {
        let port = freePort()
        let holder = makeServer(port: port, label: "holder") { _ in .ok(text: "holder") }
        holder.start()
        await pause(300)

        let stopped = makeServer(port: port, label: "stopped") { _ in .ok(text: "stopped") }
        stopped.start()
        await pause(300)
        stopped.stop()
        holder.stop()

        // Port is free now, but a stopped server must not grab it.
        await pause(2500)
        #expect(await get("/", port: port, timeout: 1) == nil)
    }

    @Test func loopbackOnlyRefusesConnectionsOnTheLANAddress() async throws {
        guard let lan = lanAddress() else { return }   // no network interface to test against
        let port = freePort()
        let server = makeServer(port: port, loopbackOnly: true, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        #expect(await get("/", port: port)?.hasPrefix("HTTP/1.1 200 OK") == true)
        #expect(await get("/", port: port, host: lan, timeout: 2) == nil)
    }

    @Test func defaultModeIsReachableOnTheLANAddress() async throws {
        guard let lan = lanAddress() else { return }
        let port = freePort()
        let server = makeServer(port: port, loopbackOnly: false, handler: echoHandler)
        server.start()
        defer { server.stop() }
        await pause(300)

        #expect(await get("/", port: port)?.hasPrefix("HTTP/1.1 200 OK") == true)
        #expect(await get("/", port: port, host: lan)?.hasPrefix("HTTP/1.1 200 OK") == true)
    }

    @Test func startingTwiceDoesNotDoubleBind() async {
        let port = freePort()
        let server = makeServer(port: port, handler: echoHandler)
        server.start()
        server.start()
        defer { server.stop() }
        await pause(300)

        #expect(await get("/x", port: port)?.hasPrefix("HTTP/1.1 200 OK") == true)
    }
}
