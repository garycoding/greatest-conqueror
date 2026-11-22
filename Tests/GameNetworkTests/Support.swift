// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
@testable import GameNetwork
import Testing

/// The tests that connect Macs, here a host and its clients on this Mac's
/// loopback interface. They run one at a time, so that the timing of one does
/// not disturb another.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(2)))
struct LANTests {}

let testBuild = "test-build"

/// A stand-in for the rules, which this target does not import. It accepts
/// every order but `advanceAge` (refused: no town centre of the stub's answers), and refuses
/// every order but a pause whilst paused, reporting each refusal as an event.
/// A `move` puts the player's first person (`mark(of:)`) where it was sent.
/// Every tick gives every player one event, `trained` with the tick's number,
/// so that views which lost an event show a gap. Each player owns a town
/// centre and `Catalogue.startingPeople` people, all visible to everyone, and
/// every site of the map is shown: so the map and the catalogue set the size
/// of a view.
struct StubSimulation: GameSimulating {
    private(set) var tick = 0
    var outcome: MatchOutcome?
    var isPaused = false
    let map: GameMap
    let players: [PlayerSetup]
    let people: Int
    let resources: ResourceAmounts
    /// The orders each player gave that were accepted, by player number.
    private(set) var orders: [[Order]]
    private var events: [[GameEvent]]
    private var marks: [MapPosition]

    init(setup: MatchSetup) {
        map = setup.map
        players = setup.players
        people = setup.catalogue.startingPeople
        resources = setup.catalogue.startingResources
        orders = Array(repeating: [], count: setup.players.count)
        events = Array(repeating: [], count: setup.players.count)
        marks = setup.players.indices.map { MapPosition(x: 2.5 + 3 * Double($0), y: 2.5) }
    }

    /// The first person of a player, whom a `move` sends.
    static func mark(of player: PlayerID) -> EntityID { EntityID(player.rawValue * 1_000 + 2) }

    mutating func apply(_ order: Order, from player: PlayerID) -> OrderResult {
        let p = player.rawValue
        let result: OrderResult
        switch order {
        case .setPaused(let paused):
            isPaused = paused
            result = .accepted
        case _ where isPaused || outcome != nil:
            result = .refused(.notNow)
        case .advanceAge:
            result = .refused(.invalidTarget)
        case .move(_, let to):
            marks[p] = to
            result = .accepted
        default:
            result = .accepted
        }
        switch result {
        case .accepted: orders[p].append(order)
        case .refused(let why): events[p].append(.refused(why))
        }
        return result
    }

    mutating func step() {
        guard !isPaused, outcome == nil else { return }
        tick += 1
        for p in events.indices { events[p].append(.trained(EntityID(tick), .worker)) }
    }

    mutating func view(for player: PlayerID) -> PlayerView {
        let taken = events[player.rawValue]
        events[player.rawValue] = []
        var entities: [EntityView] = []
        for (q, setup) in players.enumerated() {
            let mark = marks[q]
            let centre = MapPosition(x: 2.5 + 3 * Double(q), y: 6.5)
            entities.append(EntityView(id: EntityID(q * 1_000 + 1), owner: setup.id, kind: .building(.townCentre),
                                       position: centre, tile: Placement.origin(.townCentre, centre: centre), facing: .right,
                                       health: 1_200, maxHealth: 1_200, activity: .idle))
            for k in 0..<people {
                let position = k == 0 ? mark : MapPosition(x: mark.x + Double(k % 6) * 0.5, y: mark.y + Double(k / 6) * 0.5 + 0.25)
                entities.append(EntityView(id: EntityID(q * 1_000 + 2 + k), owner: setup.id, kind: .unit(.worker),
                                           position: position, tile: position.tile, facing: k % 2 == 0 ? .right : .left,
                                           health: 25, maxHealth: 25, activity: k % 3 == 0 ? .moving : .gathering(.tree)))
            }
        }
        let summaries = players.map {
            PlayerSummary(id: $0.id, civilization: $0.civilization, team: $0.team, isHuman: $0.controller == .human,
                          age: .towns, isDefeated: false)
        }
        return PlayerView(tick: tick, player: player, age: .towns, resources: resources, population: people,
                          populationLimit: 5, ageProgress: 0.25, players: summaries,
                          mapWidth: map.width, mapHeight: map.height, terrain: map.terrain,
                          visibility: Array(repeating: .visible, count: map.width * map.height), entities: entities,
                          sites: map.sites, events: taken, outcome: outcome, isPaused: isPaused)
    }

    func checksum() -> UInt64 {
        var sum = StableChecksum()
        sum.add("\(tick) \(isPaused) \(orders.map(\.count))")
        return sum.value
    }
}

/// A stand-in for the computer player: at each decision it sends its first
/// person somewhere new.
struct StubComputer: ComputerPlaying {
    let player: PlayerID
    private(set) var decisions = 0

    init(player: PlayerID, difficulty: Difficulty, seed: UInt64) { self.player = player }

    mutating func decide(view: PlayerView, catalogue: Catalogue) -> [Order] {
        decisions += 1
        return [.move(units: [StubSimulation.mark(of: player)], to: MapPosition(x: Double(decisions % 20) + 0.5, y: 1.5))]
    }
}

typealias StubHost = MatchHost<StubSimulation, StubComputer>

/// The app's match object as the server sees it: it keeps the `MatchHost`
/// and forwards to it.
@MainActor
final class StubMatch: HostedMatch {
    var host: StubHost
    var speed = 1.0

    init(_ setup: MatchSetup) { host = StubHost(setup: setup) }

    var catalogue: Catalogue { host.catalogue }
    func apply(_ order: Order, from player: PlayerID) -> OrderResult { host.apply(order, from: player) }
    func view(for player: PlayerID) -> PlayerView { host.view(for: player) }
    func drop(_ player: PlayerID) { host.drop(player) }
    func rejoin(_ player: PlayerID) { host.rejoin(player) }
    func handToComputer(_ player: PlayerID, difficulty: Difficulty) { host.handToComputer(player, difficulty: difficulty) }
}

/// The match of the tests: the host's seat (Gary), two seats open for people,
/// all three on one team, and a computer opponent.
func eveningLobby() -> Lobby {
    Lobby(name: "Evening", seats: [
        Seat(player: PlayerID(0), team: TeamID(0), kind: .host, civilization: .sumer, holder: "Gary"),
        Seat(player: PlayerID(1), team: TeamID(0), kind: .person),
        Seat(player: PlayerID(2), team: TeamID(0), kind: .person),
        Seat(player: PlayerID(3), team: TeamID(1), kind: .computer(.standard), civilization: .egypt),
    ])
}

/// An open map of grass with `sites` trees, for views of a realistic size.
func grassMap(size: Int, sites: Int) -> GameMap {
    let trees = (0..<sites).map {
        ResourceSite(id: SiteID($0), kind: .tree, tile: GridPoint($0 % size, size - 1 - $0 / size), remaining: 100)
    }
    return GameMap(width: size, height: size, terrain: Array(repeating: .grass, count: size * size), sites: trees,
                   starts: [GridPoint(4, 4), GridPoint(size - 8, 4), GridPoint(4, size - 8), GridPoint(size - 8, size - 8)])
}

/// The host's Mac and the Macs that join it, all on this Mac's loopback
/// interface. Once the match starts, it plays the app's frames: every five
/// milliseconds a tick, unless `ticking` is off, and the server's frame.
@MainActor
final class Loopback {
    let server: HostServer
    private(set) var match: StubMatch?
    var ticking = true
    private var frames: Task<Void, Never>?
    private var clients: [MatchClient] = []

    init(lobby: Lobby = eveningLobby()) throws {
        server = HostServer(lobby: lobby, build: testBuild)
        // The tests share a busy machine on CI; a connection is not taken for lost on a stall of a few seconds.
        server.silenceLimit = .seconds(60)
        try server.open(loopbackOnly: true)
    }

    /// The simulation of the match in play.
    var simulation: StubSimulation { match!.host.simulation }

    func port() async throws -> UInt16 {
        try await until("the server listens") { server.port != nil }
        return server.port!
    }

    /// A Mac that joins. After a drop it reconnects at once, then twice after a
    /// tenth of a second, and an attempt waits at most half a second.
    func join(_ name: String, build: String = testBuild) async throws -> MatchClient {
        let client = MatchClient(name: name, build: build)
        client.reconnectDelays = [.milliseconds(10), .milliseconds(100), .milliseconds(100)]
        client.connectLimit = .milliseconds(500)
        client.firstConnectLimit = .seconds(5)
        client.silenceLimit = .seconds(60)
        client.join(host: "127.0.0.1", port: try await port())
        clients.append(client)
        return client
    }

    /// Two people join, Hyun and then Mira, and choose Harappa and Shang.
    func fill() async throws -> (hyun: MatchClient, mira: MatchClient) {
        let hyun = try await join("Hyun")
        try await until("Hyun is seated") { hyun.state == .inLobby && hyun.lobby != nil }
        let mira = try await join("Mira")
        try await until("Mira is seated") { mira.state == .inLobby && mira.lobby?.seats[2].holder == "Mira" }
        #expect(hyun.chooseCivilization(.harappa))
        try await until("Mira sees Harappa taken") { mira.lobby?.seats[1].civilization == .harappa }
        #expect(mira.chooseCivilization(.shang))
        try await until("the lobby is ready") { server.lobby.isReady }
        return (hyun, mira)
    }

    /// Starts the match on `map`, each player with `people` people, and plays its frames.
    func start(map: GameMap = Samples.map(), people: Int = 3) {
        var catalogue = Catalogue.standard
        catalogue.startingPeople = people
        guard let setup = server.lobby.setup(map: map, seed: 1, catalogue: catalogue) else {
            Issue.record("the lobby is not ready")
            return
        }
        let match = StubMatch(setup)
        self.match = match
        #expect(server.start(match))
        frames = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if ticking { match.host.advance() }
                server.frame()
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
    }

    /// A lobby filled by Hyun and Mira, and its match started and seen by both.
    static func playing(map: GameMap = Samples.map(), people: Int = 3) async throws
        -> (lan: Loopback, hyun: MatchClient, mira: MatchClient) {
        let lan = try Loopback()
        let (hyun, mira) = try await lan.fill()
        lan.start(map: map, people: people)
        try await until("both play") { hyun.session != nil && mira.session != nil }
        return (lan, hyun, mira)
    }

    func stop() {
        frames?.cancel()
        for client in clients { client.leave() }
        server.close()
    }
}

/// What a client was sent, from its `onView`: how many views, and the ticks
/// of the `trained` events they carried, in order.
@MainActor
final class Received {
    private(set) var views = 0
    private(set) var ticks: [Int] = []

    init(_ client: MatchClient) {
        client.onView = { [weak self] view in self?.take(view) }
    }

    private func take(_ view: PlayerView) {
        views += 1
        for case .trained(let id, _) in view.events { ticks.append(id.rawValue) }
    }
}

struct Timeout: Error, CustomStringConvertible {
    let what: String
    var description: String { "timed out waiting until \(what)" }
}

/// Waits until `condition` holds, leaving the main actor free for the network
/// meanwhile; throws after `limit`, so that a lost message fails a test rather
/// than holding it.
@MainActor
func until(_ what: String, within limit: Duration = .seconds(60), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + limit
    while !condition() {
        guard ContinuousClock.now < deadline else { throw Timeout(what: what) }
        try await Task.sleep(for: .milliseconds(2))
    }
}
