// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameSimulation

/// A lake from (10, 10) to (19, 19), its shore on every side.
private let lake = (10...19).flatMap { y in (10...19).map { GridPoint($0, y) } }

/// A duel beside the lake, with a shoal of fish (2 × 2) in it, a gold rock
/// in it, and a gold mine on land.
private func lakeside() -> Simulation {
    duel(sites: [(.fish, 12, 12), (.fish, 13, 12), (.fish, 12, 13), (.fish, 13, 13), (.gold, 16, 16), (.gold, 6, 6)],
         water: lake)
}

/// Boat houses, boats and the water's resources (ruled 2026-11-21).
@Suite struct Boats {
    @Test func aBoatHouseStandsOnTheShoreOnly() {
        var terrain = Array(repeating: Terrain.grass, count: 40 * 40)
        for t in lake { terrain[t.y * 40 + t.x] = .deepWater }
        func can(_ x: Int, _ y: Int) -> Bool {
            Placement.canPlace(.boatHouse, at: GridPoint(x, y), width: 40, height: 40, terrain: terrain, occupied: [],
                               explored: { _ in true })
        }
        #expect(can(8, 12))          // its right edge touches the lake at x = 10
        #expect(!can(4, 12))         // inland
        #expect(!can(11, 12))        // in the water
        #expect(can(12, 20))         // below the lake, touching it at y = 19
    }

    @Test func aBoatComesOutOnTheWaterAndSailsOnlyThere() {
        var sim = lakeside()
        sim.players[0].age = .farms
        sim.exploreAll(me)
        sim.give(me, [.wood: 200])
        let house = sim.add(.boatHouse, me, 8, 12)
        #expect(sim.apply(.train(at: house, unit: .fishingBoat), from: me) == .accepted)
        let made = sim.run(until: { !$0.people(me, .fishingBoat).isEmpty }, limit: 30 * Tick.rate)
        #expect(made)
        let boat = sim.people(me, .fishingBoat)[0]
        let at = sim.living(boat).position.tile
        #expect(sim.terrain[sim.tileIndex(at)].isWater)
        // Across the lake it sails; onto the land it cannot go, and stops at the water's edge.
        #expect(sim.apply(.move(units: [boat], to: MapPosition(x: 18.5, y: 18.5)), from: me) == .accepted)
        let crossed = sim.run(until: { $0.living(boat).position.distance(to: MapPosition(x: 18.5, y: 18.5)) < 0.6 },
                              limit: 40 * Tick.rate)
        #expect(crossed)
        #expect(sim.apply(.move(units: [boat], to: MapPosition(x: 25.5, y: 18.5)), from: me) == .accepted)
        sim.run(30 * Tick.rate)
        #expect(sim.terrain[sim.tileIndex(sim.living(boat).position.tile)].isWater)
    }

    @Test func boatsFishAndBringTheCatchToTheBoatHouse() {
        var sim = lakeside()
        sim.exploreAll(me)
        _ = sim.add(.boatHouse, me, 8, 12)
        let boat = sim.add(.fishingBoat, me, 10.5, 12.5)
        let fish = sim.sites.first { $0.kind == .fish }!.id
        let food = sim.resources(me)[.food]
        #expect(sim.apply(.gather(units: [boat], site: fish), from: me) == .accepted)
        let landed = sim.run(until: { $0.resources(me)[.food] > food }, limit: 60 * Tick.rate)
        #expect(landed, "no catch was landed")
    }

    @Test func boatsMineRocksInTheWaterAndWorkersDoNot() {
        var sim = lakeside()
        sim.exploreAll(me)
        _ = sim.add(.boatHouse, me, 8, 12)
        let boat = sim.add(.fishingBoat, me, 15.5, 15.5)
        let worker = sim.add(.worker, me, 9.5, 16.5)
        let rock = sim.sites.first { $0.kind == .gold && $0.tile == GridPoint(16, 16) }!.id
        let quarry = sim.sites.first { $0.kind == .gold && $0.tile == GridPoint(6, 6) }!.id
        #expect(sim.apply(.gather(units: [worker], site: rock), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.gather(units: [boat], site: quarry), from: me) == .refused(.invalidTarget))
        let gold = sim.resources(me)[.gold]
        #expect(sim.apply(.gather(units: [boat], site: rock), from: me) == .accepted)
        let landed = sim.run(until: { $0.resources(me)[.gold] > gold }, limit: 90 * Tick.rate)
        #expect(landed, "no gold was landed from the rock")
        // The worker mines the quarry on land, its gold added as it mines (ruled 2026-11-22).
        let mined = sim.resources(me)[.gold]
        #expect(sim.apply(.gather(units: [worker], site: quarry), from: me) == .accepted)
        let more = sim.run(until: { $0.resources(me)[.gold] > mined + 20 }, limit: 120 * Tick.rate)
        #expect(more)
    }
}
