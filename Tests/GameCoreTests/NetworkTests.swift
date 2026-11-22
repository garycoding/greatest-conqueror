// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
@testable import GameCore
import Testing

private func lobby() -> Lobby {
    Lobby(name: "Evening", seats: [
        Seat(player: PlayerID(0), team: TeamID(0), kind: .host, civilization: .sumer, holder: "Gary"),
        Seat(player: PlayerID(1), team: TeamID(0), kind: .person),
        Seat(player: PlayerID(2), team: TeamID(1), kind: .computer(.standard), civilization: .egypt),
        Seat(player: PlayerID(3), team: TeamID(1), kind: .computer(.hard), civilization: .shang),
    ])
}

@Test func aLobbyIsReadyOnlyWhenEveryPersonsSeatIsHeldWithACivilization() {
    var l = lobby()
    #expect(!l.isReady)
    #expect(l.setup(map: Samples.map(), seed: 1) == nil)
    l.seats[1].holder = "Hyun"
    #expect(!l.isReady)
    l.seats[1].civilization = .harappa
    #expect(l.isReady)
    let setup = l.setup(map: Samples.map(), seed: 1)!
    #expect(setup.players.map(\.controller) == [.human, .human, .computer(.standard), .computer(.hard)])
    #expect(setup.players.map(\.civilization) == [.sumer, .harappa, .egypt, .shang])
    #expect(l.taken == [.sumer, .harappa, .egypt, .shang])
}

@Test func everyMessageEncodesAndDecodesToItself() throws {
    let view = Samples.stoneAgeOpening()
    let start = MatchStart(player: PlayerID(0), mapWidth: view.mapWidth, mapHeight: view.mapHeight,
                           terrain: view.terrain, catalogue: .standard, speed: 2)
    let messages: [NetMessage] = [
        .hello(protocolVersion: NetMessage.protocolVersion, build: "abc1234", name: "Hyun", rejoining: nil, viewsReceived: nil),
        .hello(protocolVersion: 2, build: "abc1234", name: "Hyun", rejoining: PlayerID(1), viewsReceived: 412),
        .chooseCivilization(.harappa), .order(.stop(units: [EntityID(3)])), .setSpeed(1.5), .ping(7),
        .welcome(seat: PlayerID(1), run: 7), .turnedAway(reason: "Another version"), .lobby(lobby()), .start(start),
        .view(view.withoutTerrain), .notice(.dropped(player: PlayerID(1), name: "Hyun")), .notice(.hostLeaving), .pong(7),
    ]
    for message in messages {
        let data = try JSONEncoder().encode(message)
        #expect(try JSONDecoder().decode(NetMessage.self, from: data) == message)
    }
}

@Test func aViewTravelsWithoutItsTerrainAndRegainsIt() {
    let view = Samples.stoneAgeOpening()
    let start = MatchStart(player: view.player, mapWidth: view.mapWidth, mapHeight: view.mapHeight,
                           terrain: view.terrain, catalogue: .standard, speed: 1)
    #expect(view.withoutTerrain.terrain.isEmpty)
    #expect(view.withoutTerrain.restoringTerrain(from: start) == view)
}
