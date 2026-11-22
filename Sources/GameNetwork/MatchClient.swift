// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Network
import Observation

/// A Mac that joins a match. It connects to the host, takes a seat, and once
/// the match starts feeds a `PlayerSession` with the views the host sends and
/// sends the host the session's orders. If the connection drops it reconnects
/// to the same host by itself. How the app drives it is described at the top
/// of `GameNetwork.swift`.
@MainActor
@Observable
public final class MatchClient {
    public enum State: Hashable, Sendable {
        /// Not yet asked to join.
        case idle
        /// Connecting to the host for the first time.
        case connecting
        /// Holding a seat in the match being set up.
        case inLobby
        case playing
        /// The connection was lost; trying to make it again, the `attempt`th time.
        case reconnecting(attempt: Int)
        /// The host refused this Mac, for the reason given in words for the person.
        case turnedAway(reason: String)
        /// The host could not be reached, or reached again.
        case gaveUp(reason: String)
        /// The host closed the match; its latest automatic save is on the host's Mac.
        case hostLeft
        /// The person left the match.
        case left

        /// Whether the client has stopped for good: nothing more is tried.
        public var isFinal: Bool {
            switch self {
            case .turnedAway, .gaveUp, .hostLeft, .left: true
            case .idle, .connecting, .inLobby, .playing, .reconnecting: false
            }
        }
    }

    /// The person's name, by which the host gives their seat back after a drop.
    public let name: String
    /// The build stamp, which must match the host's.
    public let build: String
    public private(set) var state: State = .idle
    /// The seat the host gave this Mac.
    public private(set) var seat: PlayerID?
    /// The match being set up, as the host last sent it.
    public private(set) var lobby: Lobby?
    /// What the host sent when the match started, or when this Mac rejoined it.
    public private(set) var start: MatchStart?
    /// The person's session, from the first view of the match on; the same
    /// session for the whole match, across reconnections.
    public private(set) var session: PlayerSession?
    /// How many times the normal rate the match runs.
    public private(set) var speed: Double = 1
    /// Every notice the host has sent, the oldest first.
    public private(set) var notices: [Notice] = []
    /// The time a ping took to the host and back, the latest measured.
    public private(set) var roundTrip: Duration?
    /// How many views of the match in play have arrived, across reconnections;
    /// sent in `hello` on coming back, so that the host can send again the events of any lost.
    private(set) var viewsReceived = 0
    /// For tests: views that arrive are dropped, as if lost when a connection breaks.
    @ObservationIgnored var losesViews = false
    /// Called with each notice, after it has been added to `notices`.
    @ObservationIgnored public var onNotice: (@MainActor (Notice) -> Void)?
    /// Called with each view as it arrives, terrain restored, after the session
    /// has been updated with it.
    @ObservationIgnored public var onView: (@MainActor (PlayerView) -> Void)?

    /// The waits before each attempt to reconnect after a drop: six attempts
    /// over about a minute.
    @ObservationIgnored public var reconnectDelays: [Duration] = [1, 2, 4, 8, 15, 30].map { .seconds($0) }
    /// How long one attempt to connect may take, waiting meanwhile for a host
    /// or a network that cannot be reached yet, or for the person's leave to
    /// use the local network.
    @ObservationIgnored public var connectLimit: Duration = .seconds(5)
    /// How long the first attempt may take: longer, as macOS may first ask the
    /// person whether the app may use the local network.
    @ObservationIgnored public var firstConnectLimit: Duration = .seconds(60)
    /// A host from which nothing arrives for this long is taken to be lost. It
    /// sends views 20 times a second during a match and answers pings.
    @ObservationIgnored public var silenceLimit: Duration = .seconds(6)
    @ObservationIgnored public var pingInterval: Duration = .seconds(1)

    @ObservationIgnored private var endpoint: NWEndpoint?
    @ObservationIgnored private var link: Link?
    /// Numbers each connection made, so that what an old one still says is ignored.
    @ObservationIgnored private var linkNumber = 0
    @ObservationIgnored private var connected = false
    /// The link `breakConnection` broke, whose messages still on their way are ignored (for tests).
    @ObservationIgnored private var brokenLink: Int?
    /// Whether the host has ever given this Mac a seat; a drop is retried only then.
    @ObservationIgnored private var welcomed = false
    /// The host's opening of the match, from its `welcome`.
    @ObservationIgnored private var run: UInt64?
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var connectDeadline: ContinuousClock.Instant?
    @ObservationIgnored private var reconnectAt: ContinuousClock.Instant?
    @ObservationIgnored private var heard = ContinuousClock.now
    @ObservationIgnored private var lastPing: ContinuousClock.Instant?
    @ObservationIgnored private var nextPing: UInt64 = 1
    @ObservationIgnored private var pings: [UInt64: ContinuousClock.Instant] = [:]
    /// The latest ping answered (for tests: everything sent before it has been handled).
    @ObservationIgnored private(set) var lastPong: UInt64 = 0
    @ObservationIgnored private var clock: Task<Void, Never>?

    public init(name: String, build: String) {
        self.name = name
        self.build = build
    }

    // MARK: Joining and leaving

    /// Joins a match found on the LAN.
    public func join(_ match: FoundMatch) { join(match.endpoint) }

    /// Joins the match hosted at an address and port (for tests and the match
    /// tests, on this Mac's loopback interface; people choose a `FoundMatch`).
    public func join(host: String, port: UInt16) {
        guard let port = NWEndpoint.Port(rawValue: port) else { return }
        join(.hostPort(host: NWEndpoint.Host(host), port: port))
    }

    private func join(_ endpoint: NWEndpoint) {
        guard state == .idle || state.isFinal else { return }
        self.endpoint = endpoint
        seat = nil
        lobby = nil
        start = nil
        session = nil
        viewsReceived = 0
        notices = []
        welcomed = false
        run = nil
        attempt = 0
        state = .connecting
        connect()
        clock?.cancel()
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self else { return }
                tick()
            }
        }
    }

    deinit {
        clock?.cancel()
    }

    /// Leaves the match. The host holds the match for this person, as for a
    /// drop, until they return or the host hands the seat on.
    public func leave() {
        guard state != .idle, !state.isFinal else { return }
        finish(.left)
    }

    /// Breaks the connection as a failing network would; the client reconnects
    /// as after any drop (for tests).
    /// What is still on its way over the broken link is ignored: the link is
    /// cancelled on its own queue, and a view arriving meanwhile would
    /// otherwise be counted after views the test treated as lost.
    func breakConnection() {
        brokenLink = linkNumber
        link?.breakOff()
    }

    // MARK: The lobby and the match

    /// Asks for a civilization for this person's seat. Returns false, sending
    /// nothing, when the lobby shows another seat holding it or the seat's
    /// civilization is fixed. The host decides between two people asking at
    /// once, and the lobby it sends shows the outcome.
    @discardableResult
    public func chooseCivilization(_ civilization: Civilization) -> Bool {
        guard state == .inLobby, let lobby, let seat,
              let mine = lobby.seats.first(where: { $0.player == seat }), !mine.civilizationFixed,
              !lobby.seats.contains(where: { $0.player != seat && $0.civilization == civilization }) else { return false }
        send(.chooseCivilization(civilization))
        return true
    }

    /// Changes the match's speed, for everyone; `speed` follows when the host
    /// confirms it with a notice.
    public func setSpeed(_ speed: Double) { send(.setSpeed(speed)) }

    /// Sends a message to the host, if connected. An order given while the
    /// connection is down is dropped, since the match holds until this person
    /// is back.
    func send(_ message: NetMessage) {
        guard connected, let link else { return }
        link.send(message)
    }

    /// Sends a ping, whose answer gives `roundTrip`, and returns its number.
    @discardableResult
    func ping() -> UInt64 {
        let n = nextPing
        nextPing += 1
        let now = ContinuousClock.now
        lastPing = now
        pings[n] = now
        if pings.count > 16, let oldest = pings.keys.min() { pings[oldest] = nil }
        send(.ping(n))
        return n
    }

    // MARK: The connection

    private func connect() {
        guard let endpoint else { return }
        linkNumber += 1
        let number = linkNumber
        let link = Link(to: endpoint, handlers: Link.Handlers(
            ready: { [weak self] in self?.linkReady(number) },
            message: { [weak self] message in self?.received(message, on: number) },
            ended: { [weak self] _ in self?.linkEnded(number) }))
        self.link = link
        connected = false
        connectDeadline = .now + (welcomed ? connectLimit : firstConnectLimit)
        link.start()
    }

    private func linkReady(_ number: Int) {
        guard number == linkNumber, let link else { return }
        connected = true
        connectDeadline = nil
        heard = .now
        link.send(.hello(protocolVersion: NetMessage.protocolVersion, build: build, name: name, rejoining: seat,
                         viewsReceived: start == nil ? nil : viewsReceived))
        ping()
    }

    private func linkEnded(_ number: Int) {
        guard number == linkNumber else { return }
        link = nil
        connected = false
        connectDeadline = nil
        pings = [:]
        guard !state.isFinal else { return }
        guard welcomed else { return finish(.gaveUp(reason: "The host could not be reached.")) }
        attempt += 1
        guard attempt <= reconnectDelays.count else {
            return finish(.gaveUp(reason: "The connection to the host was lost and could not be made again."))
        }
        state = .reconnecting(attempt: attempt)
        reconnectAt = .now + reconnectDelays[attempt - 1]
    }

    private func finish(_ final: State) {
        state = final
        linkNumber += 1
        link?.close()
        link = nil
        connected = false
        connectDeadline = nil
        reconnectAt = nil
        clock?.cancel()
        clock = nil
    }

    /// Twenty times a second: reconnects when it is time, gives up an attempt
    /// that takes too long or a host gone silent, and pings.
    private func tick() {
        let now = ContinuousClock.now
        if let at = reconnectAt {
            if now >= at {
                reconnectAt = nil
                connect()
            }
            return
        }
        guard let link else { return }
        if let deadline = connectDeadline {
            if now >= deadline {
                connectDeadline = nil
                link.close()
            }
            return
        }
        guard connected else { return }
        if heard.duration(to: now) > silenceLimit { return link.close() }
        if lastPing.map({ $0.duration(to: now) >= pingInterval }) ?? true { ping() }
    }

    private func received(_ message: NetMessage, on number: Int) {
        guard number == linkNumber, number != brokenLink else { return }
        heard = .now
        switch message {
        case .welcome(let seat, let run):
            if let previous = self.run, previous != run {
                // The host has opened the match again since this Mac last saw it: start afresh.
                start = nil
                session = nil
                viewsReceived = 0
            }
            self.run = run
            self.seat = seat
            welcomed = true
            attempt = 0
            // In a match under way the start follows, and with it `.playing`.
            if start == nil { state = .inLobby }
        case .turnedAway(let reason):
            finish(.turnedAway(reason: reason))
        case .lobby(let lobby):
            self.lobby = lobby
        case .start(let start):
            if session?.view.player != start.player {
                session = nil
                viewsReceived = 0
            }
            self.start = start
            speed = start.speed
            state = .playing
        case .view(let view):
            // For tests: a view that arrives is treated as lost on the way.
            if losesViews { return }
            viewsReceived += 1
            show(view)
        case .notice(let notice):
            notices.append(notice)
            if case .speedChanged(let to, _) = notice { speed = to }
            onNotice?(notice)
            if notice == .hostLeaving { finish(.hostLeft) }
        case .pong(let n):
            if let sent = pings.removeValue(forKey: n) { roundTrip = sent.duration(to: .now) }
            lastPong = max(lastPong, n)
        case .hello, .chooseCivilization, .order, .setSpeed, .ping:
            break
        }
    }

    private func show(_ received: PlayerView) {
        guard let start else { return }
        let view = received.restoringTerrain(from: start)
        if let session {
            session.update(view)
        } else {
            let session = PlayerSession(view: view, catalogue: start.catalogue, camera: Camera(centre: Self.home(in: view)),
                                        sink: { [weak self] order in self?.send(.order(order)) })
            // So that a refusal in the first view becomes `lastRefusal`, as in any other.
            session.update(view)
            self.session = session
        }
        onView?(view)
    }

    /// The person's town centre, or else the middle of the map, as the app
    /// centres a match it starts.
    static func home(in view: PlayerView) -> MapPosition {
        view.entities.first { $0.owner == view.player && $0.kind == .building(.townCentre) }?.position
            ?? MapPosition(x: Double(view.mapWidth) / 2, y: Double(view.mapHeight) / 2)
    }
}
