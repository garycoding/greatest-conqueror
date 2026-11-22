// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Network

/// How messages travel on a connection: each `NetMessage` is encoded as JSON
/// and sent as one frame, its length first, in four bytes with the most
/// significant first, then the JSON itself.
enum Framing {
    static let headerLength = 4
    /// A longer frame is taken as a sign of a corrupt stream and ends the
    /// connection. The largest view of a 96 × 96 map is a few hundred kilobytes.
    static let maximumLength = 32 << 20

    /// The frame that carries `payload`.
    static func frame(_ payload: Data) -> Data {
        let n = UInt32(payload.count)
        var out = Data(capacity: headerLength + payload.count)
        out.append(contentsOf: [UInt8(n >> 24), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)])
        out.append(payload)
        return out
    }

    /// The payload length a header announces.
    static func length(ofHeader header: Data) -> Int {
        header.reduce(0) { $0 << 8 | Int($1) }
    }

    /// The parameters of every connection of the game: TCP, without Nagle's
    /// delay, since a frame is worth sending the moment it is ready.
    static func parameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 5
        return NWParameters(tls: nil, tcp: tcp)
    }
}

/// One TCP connection that carries framed messages. The connection runs on a
/// queue of its own, where messages are encoded and decoded, so that a large
/// view costs the main actor nothing; what arrives is handed to the main actor
/// in the order in which it arrived, followed by the end of the connection.
final class Link: @unchecked Sendable {
    /// Why a connection ended.
    enum End: Sendable, Equatable {
        /// Closed by either side, or the other side's stream ended.
        case closed
        /// The network or the other side failed, or a frame could not be read.
        case failed(String)
    }

    /// What the link tells its owner, always on the main actor.
    struct Handlers: Sendable {
        var ready: @MainActor @Sendable () -> Void = {}
        var message: @MainActor @Sendable (NetMessage) -> Void
        var ended: @MainActor @Sendable (End) -> Void
    }

    private let connection: NWConnection
    private let handlers: Handlers
    private let queue = DispatchQueue(label: "GameNetwork.Link", qos: .userInteractive)
    // Touched only on `queue`.
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var finished = false

    init(connection: NWConnection, handlers: Handlers) {
        self.connection = connection
        self.handlers = handlers
    }

    /// A link to a host, not yet started.
    convenience init(to endpoint: NWEndpoint, handlers: Handlers) {
        self.init(connection: NWConnection(to: endpoint, using: Framing.parameters()), handlers: handlers)
    }

    deinit { connection.cancel() }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in self?.changed(to: state) }
        connection.start(queue: queue)
        receiveHeader()
    }

    /// Sends a message. `final` sends it as the last thing on the connection,
    /// which is then closed once the message has gone. `sent` learns, on the
    /// main actor, whether the message was handed to the network.
    func send(_ message: NetMessage, final: Bool = false, sent: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        queue.async { [self] in
            guard !finished, let payload = try? encoder.encode(message) else {
                if let sent { Self.onMain { sent(false) } }
                return
            }
            connection.send(content: Framing.frame(payload), contentContext: final ? .finalMessage : .defaultMessage,
                            isComplete: true, completion: .contentProcessed { [self] error in
                if final { finish(.closed) }
                if let sent { Self.onMain { sent(error == nil) } }
            })
        }
    }

    /// Closes the connection; the owner is told it ended, as for any other end.
    func close() {
        queue.async { [self] in finish(.closed) }
    }

    /// Ends the connection at once, without the closing handshake, as a failed
    /// network would (for tests).
    func breakOff() {
        queue.async { [self] in
            connection.forceCancel()
            finish(.failed("broken off"))
        }
    }

    // MARK: On the queue

    private func changed(to state: NWConnection.State) {
        switch state {
        case .ready:
            let ready = handlers.ready
            Self.onMain { ready() }
        case .waiting:
            // An outgoing connection that cannot be made yet: the host refuses
            // it, the network is down, or the system awaits the person's leave
            // to use the local network. The framework tries again by itself when
            // things change; the owner's deadline decides how long to wait.
            break
        case .failed(let error):
            finish(.failed(error.localizedDescription))
        case .cancelled:
            finish(.closed)
        default:
            break
        }
    }

    private func finish(_ end: End) {
        guard !finished else { return }
        finished = true
        connection.cancel()
        let ended = handlers.ended
        Self.onMain { ended(end) }
    }

    private func receiveHeader() {
        connection.receive(minimumIncompleteLength: Framing.headerLength, maximumLength: Framing.headerLength) {
            [weak self] data, _, _, error in
            guard let self else { return }
            if let error { return finish(.failed(error.localizedDescription)) }
            guard let data, data.count == Framing.headerLength else { return finish(.closed) }
            let length = Framing.length(ofHeader: data)
            guard length > 0, length <= Framing.maximumLength else {
                return finish(.failed("a frame of \(length) bytes"))
            }
            receiveBody(length)
        }
    }

    private func receiveBody(_ length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error { return finish(.failed(error.localizedDescription)) }
            guard let data, data.count == length else { return finish(.closed) }
            guard let message = try? decoder.decode(NetMessage.self, from: data) else {
                return finish(.failed("a message that could not be read"))
            }
            let deliver = handlers.message
            Self.onMain { deliver(message) }
            receiveHeader()
        }
    }

    /// Runs `body` on the main actor, after everything handed there before it.
    private static func onMain(_ body: @escaping @MainActor @Sendable () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { body() } }
    }
}
