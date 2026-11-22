// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import ComputerPlayer
import GameCore
@testable import GameSimulation
import Testing

/// A hard computer player that starts in a later age, with a stock to build
/// with, opposite a player who gives no orders, on a generated 96-tile map.
/// Whole matches between computer players seldom last into the later ages
/// (most end in the age of farms), so each later age's play is tested from its
/// own start: these follow the computer player until it has built and used
/// what the age brings.
private struct LateStart {
    var sim: Simulation
    var computer: ComputerPlayer
    let me = PlayerID(0)

    init(age: Age, seed: UInt64) {
        let setup = computerMatch(seed: seed, size: 96, difficulties: [.hard, .hard])
        var players = setup.players
        players[1].controller = .human
        sim = Simulation(setup: MatchSetup(map: setup.map, players: players, seed: seed, catalogue: setup.catalogue))
        sim.players[0].age = age
        sim.players[0].resources = ResourceAmounts([.food: 1500, .wood: 1500, .gold: 1500])
        computer = ComputerPlayer(player: me, difficulty: .hard, seed: seed)
    }

    /// Plays until `done` holds or `minutes` pass; returns the minutes taken, or nil.
    mutating func play(minutes: Int, until done: (PlayerView) -> Bool) -> Int? {
        let interval = Tick.rate / 4
        while sim.tick < Tick.seconds(Double(minutes * 60)) {
            // The opponent's defeat does not end the test: what is followed is the building.
            sim.outcome = nil
            if sim.tick % interval == 0 {
                let view = sim.view(for: me)
                if done(view) { return sim.tick / Tick.rate / 60 }
                for order in computer.decide(view: view, catalogue: sim.catalogue) { _ = sim.apply(order, from: me) }
            }
            sim.step()
        }
        return nil
    }
}

private func complete(_ kind: BuildingKind, in view: PlayerView) -> Bool {
    view.entities.contains { e in
        guard e.owner == view.player, e.kind == .building(kind) else { return false }
        if case .underConstruction = e.activity { return false }
        return true
    }
}

private func owns(_ kinds: [UnitKind], in view: PlayerView) -> Bool {
    view.entities.contains { e in e.owner == view.player && kinds.contains { e.kind == .unit($0) } }
}

/// In the age of ships it completes a stable and trains a horseman.
@Test func aHardComputerPlayerInTheAgeOfShipsBuildsAStableAndTrainsHorsemen() {
    var start = LateStart(age: .ships, seed: 3)
    let minutes = start.play(minutes: 30) { view in
        complete(.stable, in: view) && owns([.horseman], in: view)
    }
    #expect(minutes != nil, "no stable and horseman within 30 minutes")
    print("Ships: stable and horseman at \(minutes.map(String.init) ?? "never") minutes")
}

/// In the age of cannons it completes a castle and trains there or elsewhere
/// the warfighters the age brings.
@Test func aHardComputerPlayerInTheAgeOfCannonsBuildsACastleAndTrainsItsWarfighters() {
    var start = LateStart(age: .cannons, seed: 3)
    let minutes = start.play(minutes: 30) { view in
        complete(.castle, in: view) && owns([.musketeer, .knight, .cannon], in: view)
    }
    #expect(minutes != nil, "no castle and warfighters of the age within 30 minutes")
    print("Cannons: castle and warfighters at \(minutes.map(String.init) ?? "never") minutes")
}
