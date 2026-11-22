// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import ComputerPlayer
import Foundation
import GameCore
import GameNetwork
import GameSimulation
import MapGeneration
import Testing
import Foundation

typealias Host = MatchHost<Simulation, ComputerPlayer>

/// A match between computer players on a generated map, as the app sets one up.
func computerMatch(seed: UInt64, size: Int, difficulties: [Difficulty]) -> MatchSetup {
    let civilizations: [Civilization] = [.sumer, .egypt, .harappa, .shang, .olmec, .caral]
    let map = MapGenerator().generate(MapRequest(width: size, height: size, playerCount: difficulties.count, seed: seed))
    let players = difficulties.enumerated().map { i, d in
        PlayerSetup(id: PlayerID(i), civilization: civilizations[i], team: TeamID(i), controller: .computer(d))
    }
    return MatchSetup(map: map, players: players, seed: seed)
}

/// Runs a match until it ends or `limit` ticks pass; returns the host at the end.
func play(_ setup: MatchSetup, limit: Int) -> Host {
    var host = Host(setup: setup)
    while host.outcome == nil && host.tick < limit { host.advance() }
    return host
}

/// Forty minutes of game time.
let matchLimit = Tick.seconds(40 * 60)

@Test func twoComputerPlayersPlayAMatchToAWinner() {
    let host = play(computerMatch(seed: 11, size: 64, difficulties: [.hard, .easy]), limit: matchLimit)
    print("match ended at tick \(host.tick) (\(host.tick / Tick.rate / 60) min): \(String(describing: host.outcome))")
    #expect(host.outcome != nil, "no winner after \(host.tick) ticks")
}

@Test func aMatchIsTheSameEachTimeAndResumesFromASave() throws {
    let setup = computerMatch(seed: 5, size: 64, difficulties: [.standard, .standard])
    var first = Host(setup: setup)
    for _ in 0..<Tick.seconds(4 * 60) { first.advance() }
    let saved = try JSONEncoder().encode(first)
    var resumed = try JSONDecoder().decode(Host.self, from: saved)
    for _ in 0..<Tick.seconds(4 * 60) { first.advance(); resumed.advance() }
    var again = Host(setup: setup)
    for _ in 0..<Tick.seconds(8 * 60) { again.advance() }
    #expect(first.checksum() == resumed.checksum())
    #expect(first.checksum() == again.checksum())
}

@Test(.disabled(if: ProcessInfo.processInfo.environment["MATCH_REPORT"] == nil))
func reportHowEqualsPlay() {
    for seed: UInt64 in [3, 4] {
        var host = Host(setup: computerMatch(seed: seed, size: 64, difficulties: [.standard, .standard]))
        var farmsAt: [Int: Int] = [:]
        while host.outcome == nil && host.tick < matchLimit {
            host.advance()
            if host.tick % 200 == 0 {
                for p in host.peek(for: PlayerID(0)).players where p.age == .farms && farmsAt[p.id.rawValue] == nil {
                    farmsAt[p.id.rawValue] = host.tick / Tick.rate
                }
            }
        }
        let v = host.peek(for: PlayerID(0))
        let own = v.entities.filter { $0.owner == PlayerID(0) }
        print("seed \(seed): tick \(host.tick / Tick.rate / 60) min, outcome \(String(describing: host.outcome)), farms at s \(farmsAt), p0 entities \(own.count), p0 resources \(v.resources)")
    }
}

@Test func aSeatHandedToTheComputerIsPlayedAndReturnsToThePerson() {
    let civilizations: [Civilization] = [.sumer, .egypt]
    let map = MapGenerator().generate(MapRequest(width: 64, height: 64, playerCount: 2, seed: 9))
    let setup = MatchSetup(map: map, players: [
        PlayerSetup(id: PlayerID(0), civilization: civilizations[0], team: TeamID(0), controller: .human),
        PlayerSetup(id: PlayerID(1), civilization: civilizations[1], team: TeamID(1), controller: .computer(.standard)),
    ], seed: 9)
    var host = Host(setup: setup)
    #expect(!host.isComputer(PlayerID(0)))
    host.handToComputer(PlayerID(0), difficulty: .standard)
    #expect(host.isComputer(PlayerID(0)))
    for _ in 0..<Tick.seconds(90) { host.advance() }
    // The computer played the person's seat: it trained or built something.
    #expect(host.peek(for: PlayerID(0)).entities.filter { $0.owner == PlayerID(0) }.count > 4)
    host.takeBack(PlayerID(0))
    #expect(!host.isComputer(PlayerID(0)))
    #expect(host.computerPlayers == [PlayerID(1)])
}

@Test func aDroppedPersonHoldsTheMatchUntilTheyRejoinOrTheSeatIsHandedOn() {
    let map = MapGenerator().generate(MapRequest(width: 64, height: 64, playerCount: 2, seed: 4))
    let setup = MatchSetup(map: map, players: [
        PlayerSetup(id: PlayerID(0), civilization: .sumer, team: TeamID(0), controller: .human),
        PlayerSetup(id: PlayerID(1), civilization: .egypt, team: TeamID(0), controller: .human),
    ], seed: 4)
    var host = Host(setup: setup)
    host.advance()
    host.drop(PlayerID(1))
    let held = host.tick
    for _ in 0..<40 { host.advance() }
    #expect(host.tick == held)
    #expect(host.view(for: PlayerID(0)).isPaused)
    #expect(host.apply(.setPaused(false), from: PlayerID(0)) == .refused(.notNow))
    host.rejoin(PlayerID(1))
    host.advance()
    #expect(host.tick == held + 1)
    // A pause a person set before a drop survives the rejoin.
    host.apply(.setPaused(true), from: PlayerID(0))
    host.drop(PlayerID(1))
    host.handToComputer(PlayerID(1), difficulty: .easy)
    #expect(host.dropped.isEmpty)
    #expect(host.isPaused)
    // The hold is not saved.
    host.drop(PlayerID(0))
    let reopened = try! JSONDecoder().decode(Host.self, from: JSONEncoder().encode(host))
    #expect(reopened.dropped.isEmpty)
}

/// Two hard computer players on seed 5: both reach the age of farms, and the
/// match ends with a winner. (Cities of Progress asked for its third age; the
/// computer players of Greatest Conqueror, with no warfighter before the age
/// of farms, win before the age of ships until they are taught the new rules.)
@Test func twoHardComputerPlayersReachTheAgeOfFarmsAndFinish() {
    var host = Host(setup: computerMatch(seed: 5, size: 64, difficulties: [.hard, .hard]))
    var reached = false
    while host.outcome == nil && host.tick < matchLimit {
        host.advance()
        if !reached, host.tick % 100 == 0 { reached = host.peek(for: PlayerID(0)).players.allSatisfy { $0.age >= .farms } }
    }
    #expect(reached, "not both reached the age of farms; \(String(describing: host.outcome)) at \(host.tick / Tick.rate / 60) minutes")
    #expect(host.outcome != nil, "no winner after \(host.tick) ticks")
}
