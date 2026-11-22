// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import ComputerPlayer
import GameCore
@testable import GameSimulation
import Testing

/// A hard computer player that starts in a later age, with a stock to build
/// with, opposite a player who gives no orders, on a generated 96-tile map.
/// Whole matches between computer players seldom last into the later ages
/// (most end in the Bronze age), so each later age's play is tested from its
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
        sim.players[0].resources = ResourceAmounts([.food: 1500, .wood: 1500, .stone: 1200, .bronze: 300, .gold: 800,
                                                    .iron: 800, .gunpowder: 200])
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

/// In the Alchemy age it completes a workshop and a castle and makes
/// gunpowder (plan step 4 of the Alchemy age).
@Test func aHardComputerPlayerInTheAlchemyAgeBuildsItsWorkshopAndCastleAndMakesGunpowder() {
    var start = LateStart(age: .alchemy, seed: 3)
    var made = false
    let minutes = start.play(minutes: 30) { view in
        if view.resources[.gunpowder] > 200 || owns([.musketeer, .cannon], in: view) { made = true }
        return made && complete(.alchemistsWorkshop, in: view) && complete(.castle, in: view)
    }
    #expect(minutes != nil, "no workshop, castle and gunpowder within 30 minutes")
    print("Alchemy: workshop, castle and gunpowder at \(minutes.map(String.init) ?? "never") minutes")
}

/// In the Industrial age it pumps oil from a well, completes a factory and two
/// railway depots, and trains a field gun or an armoured car (plan step 4 of
/// the Industrial age).
@Test func aHardComputerPlayerInTheIndustrialAgePumpsOilAndBuildsItsFactoryAndDepots() {
    var start = LateStart(age: .industrial, seed: 3)
    var pumped = false
    let minutes = start.play(minutes: 30) { view in
        if view.resources[.oil] > 0 { pumped = true }
        let depots = view.entities.filter { e in
            guard e.owner == view.player, e.kind == .building(.railwayDepot) else { return false }
            if case .underConstruction = e.activity { return false }
            return true
        }
        return pumped && complete(.oilWell, in: view) && complete(.factory, in: view) && depots.count >= 2
            && owns([.fieldGun, .armouredCar], in: view)
    }
    let v = start.sim.view(for: start.me)
    var have: [String: Int] = [:]
    for e in v.entities where e.owner == v.player { have["\(e.kind)", default: 0] += 1 }
    #expect(minutes != nil, """
        no well, oil, factory, two depots and machine within 30 minutes: tick \(start.sim.tick), \
        outcome \(String(describing: start.sim.outcome)), oil \(v.resources[.oil]), \(v.resources), \
        oil fields seen \(v.sites.filter { $0.kind == .oilField }.count), \(have.sorted { $0.key < $1.key })
        """)
    print("Industrial: well, factory, depots and machines at \(minutes.map(String.init) ?? "never") minutes")
}
