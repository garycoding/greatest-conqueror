// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import GameSimulation
import MapGeneration
import Testing

// Matches of three and five players (requirement 4: any number from two to six,
// ruled 2026-11-21).

/// Each player begins with one town centre of its own, on its own start of the map.
private func expectEveryPlayerHasAStart(_ host: Host, _ setup: MatchSetup) {
    let starts = setup.map.starts
    #expect(starts.count == setup.players.count)
    #expect(Set(starts).count == starts.count, "two players share a start")
    for player in setup.players {
        let view = host.peek(for: player.id)
        let centres = view.entities.filter { $0.owner == player.id && $0.kind == .building(.townCentre) }
        #expect(centres.count == 1, "player \(player.id.rawValue) has \(centres.count) town centres")
        #expect(centres.first?.tile == starts[player.id.rawValue], "player \(player.id.rawValue) is not on its start")
    }
}

/// The people's seats filled: each joiner seated and with a civilization chosen.
private func lobby(_ seats: [Seat]) -> Lobby {
    let joiners: [Civilization] = [.rome, .olmec]
    var next = 0
    return Lobby(name: "A match", seats: seats.map { seat in
        guard seat.kind == .person else { return seat }
        var seated = seat
        seated.holder = "Person \(next + 1)"
        seated.civilization = joiners[next]
        next += 1
        return seated
    })
}

@Test(arguments: [3, 5])
func aLobbyOfThreeOrFivePlayersSetsUpAMatch(players: Int) throws {
    // The host and a person against computer players; in five, two of them allied with the people.
    let seats: [Seat] = players == 3
        ? [Seat(player: PlayerID(0), team: TeamID(0), kind: .host, civilization: .sumer, holder: "Host"),
           Seat(player: PlayerID(1), team: TeamID(0), kind: .person),
           Seat(player: PlayerID(2), team: TeamID(1), kind: .computer(.standard), civilization: .egypt)]
        : [Seat(player: PlayerID(0), team: TeamID(0), kind: .host, civilization: .sumer, holder: "Host"),
           Seat(player: PlayerID(1), team: TeamID(0), kind: .person),
           Seat(player: PlayerID(2), team: TeamID(0), kind: .computer(.easy), civilization: .egypt),
           Seat(player: PlayerID(3), team: TeamID(1), kind: .computer(.standard), civilization: .harappa),
           Seat(player: PlayerID(4), team: TeamID(2), kind: .computer(.hard), civilization: .shang)]
    let ready = lobby(seats)
    #expect(ready.isReady)
    let seed = UInt64(30 + players)
    let map = MapGenerator().generate(MapRequest(width: 64, height: 64, playerCount: ready.seats.count, seed: seed))
    let setup = try #require(ready.setup(map: map, seed: seed))
    #expect(setup.players.count == players)
    #expect(setup.players.filter { $0.controller == .human }.count == 2)
    var host = Host(setup: setup)
    expectEveryPlayerHasAStart(host, setup)
    for _ in 0..<Tick.seconds(60) { host.advance() }
    #expect(host.tick == Tick.seconds(60))
}

@Test(arguments: [3, 5])
func computerPlayersPlayAMatchOfThreeOrFive(players: Int) {
    let difficulties = Array([Difficulty.standard, .hard, .easy, .standard, .hard].prefix(players))
    let setup = computerMatch(seed: UInt64(40 + players), size: 64, difficulties: difficulties)
    var host = Host(setup: setup)
    expectEveryPlayerHasAStart(host, setup)
    let minutes = 8.0
    for _ in 0..<Tick.seconds(minutes * 60) { host.advance() }
    #expect(host.tick == Tick.seconds(minutes * 60) || host.outcome != nil)
    // Every computer player has played: each has trained or built beyond its start.
    for player in setup.players {
        let own = host.peek(for: player.id).entities.filter { $0.owner == player.id }
        #expect(own.count > 4, "player \(player.id.rawValue) has \(own.count) entities after \(Int(minutes)) minutes")
    }
}

/// Six computer players on the large map, begun in the Iron age (ruled
/// 2026-11-21): every player starts on its own start in that age, and a minute
/// of the match runs in less than a minute, faster than the game's own speed,
/// even in a debug build beside the other tests.
@Test func sixPlayersOnTheLargeMapBegunInTheIronAge() throws {
    let civilizations: [Civilization] = [.sumer, .egypt, .harappa, .shang, .rome, .olmec]
    let seats = (0..<6).map { i in
        Seat(player: PlayerID(i), team: TeamID(i), kind: .computer(.standard), civilization: civilizations[i])
    }
    let ready = Lobby(name: "Large", seats: seats, startingAge: .iron, mapSize: .large)
    let seed: UInt64 = 61
    let map = MapGenerator().generate(MapRequest(size: ready.size, playerCount: 6, seed: seed))
    #expect(map.width == 192 && map.height == 192)
    let setup = try #require(ready.setup(map: map, seed: seed))
    var host = Host(setup: setup)
    expectEveryPlayerHasAStart(host, setup)
    for player in setup.players { #expect(host.peek(for: player.id).age == .iron) }
    let clock = ContinuousClock()
    let elapsed = clock.measure { for _ in 0..<Tick.seconds(60) { host.advance() } }
    #expect(elapsed < .seconds(60), "a minute of play took \(elapsed)")
}
