// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import ComputerPlayer
import Foundation
import GameCore
import GameNetwork
import GameSimulation
import MapGeneration
import Testing

/// The match the host runs, as the app's own match object does: the real
/// simulation and computer players, with the orders from each seat counted.
@MainActor
private final class HostedRealMatch: HostedMatch {
    var host: Host
    var speed = 1.0
    private(set) var accepted: [PlayerID: Int] = [:]

    init(_ setup: MatchSetup) { host = Host(setup: setup) }

    var catalogue: Catalogue { host.catalogue }
    func apply(_ order: Order, from player: PlayerID) -> OrderResult {
        let result = host.apply(order, from: player)
        if result == .accepted { accepted[player, default: 0] += 1 }
        return result
    }
    func view(for player: PlayerID) -> PlayerView { host.view(for: player) }
    func drop(_ player: PlayerID) { host.drop(player) }
    func rejoin(_ player: PlayerID) { host.rejoin(player) }
    func handToComputer(_ player: PlayerID, difficulty: Difficulty) { host.handToComputer(player, difficulty: difficulty) }
}

/// A person's seat played by a computer player that decides from the views the
/// person's Mac receives and gives its orders through the person's session, as
/// a person at that Mac would.
@MainActor
private final class SeatPlayer {
    private var brain: ComputerPlayer
    private let catalogue: Catalogue
    private(set) var ticks: [Int] = []
    private(set) var orders = 0

    init(player: PlayerID, catalogue: Catalogue) {
        brain = ComputerPlayer(player: player, difficulty: .standard, seed: UInt64(player.rawValue) + 100)
        self.catalogue = catalogue
    }

    func decide(_ view: PlayerView, issue: (Order) -> Void) {
        ticks.append(view.tick)
        for order in brain.decide(view: view, catalogue: catalogue) {
            issue(order)
            orders += 1
        }
    }
}

@MainActor
private func until(_ what: String, within limit: Duration = .seconds(90), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + limit
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("timed out waiting until \(what)")
            throw CancellationError()
        }
        try await Task.sleep(for: .milliseconds(2))
    }
}

/// A host and two Macs that join, over this Mac's loopback interface: the
/// three people's seats, all on one team, are played by computer players that
/// see only what each Mac is sent, against a computer player on the other team.
@MainActor
@Test func aHostAndTwoJoiningMacsPlayAMatchAcrossTheNetwork() async throws {
    let build = "match-test"
    let lobby = Lobby(name: "Evening match", seats: [
        Seat(player: PlayerID(0), team: TeamID(0), kind: .host, civilization: .sumer, holder: "Gary"),
        Seat(player: PlayerID(1), team: TeamID(0), kind: .person),
        Seat(player: PlayerID(2), team: TeamID(0), kind: .person),
        Seat(player: PlayerID(3), team: TeamID(1), kind: .computer(.easy), civilization: .olmec),
    ])
    let server = HostServer(lobby: lobby, build: build)
    // The tests share a busy machine on CI; a connection is not taken for lost on a stall of a few seconds.
    server.silenceLimit = .seconds(60)
    try server.open(loopbackOnly: true)
    defer { server.close() }
    try await until("the server listens") { server.port != nil }

    let hyun = MatchClient(name: "Hyun", build: build)
    let mira = MatchClient(name: "Mira", build: build)
    for client in [hyun, mira] { client.silenceLimit = .seconds(60) }
    defer { hyun.leave(); mira.leave() }
    hyun.join(host: "127.0.0.1", port: server.port!)
    try await until("Hyun is seated and has the lobby") { hyun.state == .inLobby && hyun.seat != nil && hyun.lobby != nil }
    mira.join(host: "127.0.0.1", port: server.port!)
    try await until("Mira is seated and has the lobby") { mira.state == .inLobby && mira.seat != nil && mira.lobby != nil }
    #expect(hyun.chooseCivilization(.harappa))
    try await until("Mira sees Harappa taken") { mira.lobby?.seats.contains { $0.civilization == .harappa } == true }
    #expect(mira.chooseCivilization(.shang))
    try await until("the lobby is ready") { server.lobby.isReady }

    let seed: UInt64 = 21
    let map = MapGenerator().generate(MapRequest(width: 64, height: 64, playerCount: 4, seed: seed))
    let setup = try #require(server.lobby.setup(map: map, seed: seed))
    let match = HostedRealMatch(setup)
    #expect(server.start(match))
    try await until("both Macs play") { hyun.session != nil && mira.session != nil }
    #expect(hyun.session?.view.terrain == map.terrain)

    // Each joining Mac's player decides on each view it is sent; the host's decides every five ticks.
    let hyunPlayer = SeatPlayer(player: hyun.seat!, catalogue: match.catalogue)
    let miraPlayer = SeatPlayer(player: mira.seat!, catalogue: match.catalogue)
    hyun.onView = { view in hyunPlayer.decide(view) { hyun.session?.issue($0) } }
    mira.onView = { view in miraPlayer.decide(view) { mira.session?.issue($0) } }
    let hostPlayer = SeatPlayer(player: PlayerID(0), catalogue: match.catalogue)

    // Ten ticks for each frame, so that the match runs at many times its normal rate.
    let limit = matchLimit
    while match.host.outcome == nil && match.host.tick < limit {
        for _ in 0..<10 {
            match.host.advance()
            if match.host.tick % 5 == 0 {
                hostPlayer.decide(match.host.peek(for: PlayerID(0))) { server.issue($0) }
            }
        }
        server.frame()
        try await Task.sleep(for: .milliseconds(1))
        #expect(!hyun.state.isFinal && !mira.state.isFinal)
        if hyun.state.isFinal || mira.state.isFinal { break }
    }
    let last = match.host.tick
    // The server goes on sending views whilst no ticks run, as it does in a paused match.
    try await until("both Macs see the last tick") {
        server.frame()
        return hyun.session?.view.tick == last && mira.session?.view.tick == last
    }
    print("LAN match ended at tick \(last) (\(last / Tick.rate / 60) min): \(String(describing: match.host.outcome)); "
          + "orders accepted \(match.accepted.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\($0.key.rawValue): \($0.value)" }), "
          + "views \(hyunPlayer.ticks.count) and \(miraPlayer.ticks.count)")

    // Every person's orders reached the match, and each Mac's views came in order.
    for seat in [PlayerID(0), hyun.seat!, mira.seat!] {
        #expect((match.accepted[seat] ?? 0) > 0, "no order from seat \(seat.rawValue) was accepted")
    }
    #expect(hyunPlayer.ticks == hyunPlayer.ticks.sorted())
    #expect(miraPlayer.ticks == miraPlayer.ticks.sorted())
    #expect(hyun.session?.view.outcome == match.host.outcome)
}
