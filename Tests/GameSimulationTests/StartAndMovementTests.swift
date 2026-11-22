// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

@Suite struct Start {
    @Test func eachPlayerBeginsWithATownCentreWorkersAndTheStartingResourcesInTheAgeOfTowns() {
        let match = Samples.twoPlayerSetup(seed: 7)
        let catalogue = match.catalogue
        var sim = Simulation(setup: match)
        for (i, player) in match.players.enumerated() {
            let view = sim.view(for: player.id)
            #expect(view.age == .towns)
            #expect(view.resources == catalogue.startingResources)
            let mine = view.entities.filter { $0.owner == player.id }
            let centres = mine.filter { $0.kind == .building(.townCentre) }
            #expect(centres.count == 1)
            #expect(centres.first?.tile == match.map.starts[i])
            #expect(centres.first?.activity == .idle)
            let footprint = Goal.tiles(match.map.starts[i], catalogue.stats(.townCentre).footprint, reach: 0)
            let workers = mine.filter { $0.kind == .unit(.worker) }
            #expect(workers.count == catalogue.startingPeople)
            for w in workers {
                #expect(footprint.distance(to: w.position) <= 1.5)
                #expect(sim.open(w.tile))
            }
            #expect(view.population == catalogue.startingPeople)
            #expect(view.populationLimit == catalogue.stats(.townCentre).housing)
        }
    }
}

@Suite struct Movement {
    /// A wall across the way, of water, a house's footprint and two trees, open
    /// only below y = 22.
    static func walled() -> Simulation {
        var water: [GridPoint] = []
        for y in 0..<22 where !(8..<10).contains(y) && !(14..<16).contains(y) { water.append(GridPoint(15, y)) }
        var sim = Simulation(setup: setup(openMap(width: 30, height: 30, starts: [GridPoint(1, 26), GridPoint(26, 26)],
                                                  sites: [(.tree, 15, 14), (.tree, 15, 15)], water: water),
                                          teams: [0, 1]))
        sim.add(.house, me, 15, 8)
        return sim
    }

    @Test func peopleFindAWayAroundBlockedTiles() {
        var sim = Self.walled()
        let worker = sim.add(.worker, me, 10.5, 5.5)
        let goal = MapPosition(x: 20.5, y: 5.5)
        #expect(sim.apply(.move(units: [worker], to: goal), from: me) == .accepted)
        var lowest = 0.0
        let arrived = sim.run(until: { s in
            let e = s.entity(worker)!
            lowest = max(lowest, e.position.y)
            return e.task == .idle
        }, limit: 3_000)
        #expect(arrived)
        #expect(sim.entity(worker)!.position.distance(to: goal) < 0.05)
        // It went round below the wall, which a straight walk of 10 tiles would not.
        #expect(lowest >= 21)
        #expect(sim.tick > 600)
    }

    @Test func noOneStandsOnABlockedTile() {
        var sim = Self.walled()
        let walkers = (0..<6).map { k in sim.add(.worker, me, 8.5 + Double(k % 3), 4.5 + Double(k / 3) * 6) }
        _ = sim.apply(.move(units: walkers, to: MapPosition(x: 22, y: 10)), from: me)
        for _ in 0..<1_500 {
            sim.step()
            for id in walkers { #expect(sim.open(sim.entity(id)!.position.tile)) }
        }
        #expect(walkers.allSatisfy { sim.living($0).task == .idle })
    }

    @Test func speedComesFromTheCatalogue() {
        var sim = duel()
        let worker = sim.add(.worker, me, 10.5, 20.5)
        let horseman = sim.add(.horseman, me, 10.5, 24.5)
        _ = sim.apply(.move(units: [worker], to: MapPosition(x: 20.5, y: 20.5)), from: me)
        _ = sim.apply(.move(units: [horseman], to: MapPosition(x: 20.5, y: 24.5)), from: me)
        var arrival: [EntityID: Int] = [:]
        for _ in 0..<300 {
            sim.step()
            for id in [worker, horseman] where arrival[id] == nil && sim.living(id).task == .idle { arrival[id] = sim.tick }
        }
        // Ten tiles at 1 and at 2 tiles a second, 20 ticks a second.
        let workerTicks = 10 * Double(Tick.rate) / Catalogue.standard.stats(.worker).speed
        let horsemanTicks = 10 * Double(Tick.rate) / Catalogue.standard.stats(.horseman).speed
        #expect(abs(Double(arrival[worker] ?? 0) - workerTicks) <= 2)
        #expect(abs(Double(arrival[horseman] ?? 0) - horsemanTicks) <= 2)
    }

    @Test func peopleDoNotBlockOneAnother() {
        var sim = duel()
        // A crowd of the walker's own people and an opponent's, standing on its way.
        for k in 0..<5 { sim.add(.worker, me, 13.5 + Double(k), 20.5) }
        for k in 0..<5 { sim.add(.worker, them, 15.5 + Double(k) * 0.5, 20.5) }
        let walker = sim.add(.worker, me, 10.5, 20.5)
        _ = sim.apply(.move(units: [walker], to: MapPosition(x: 20.5, y: 20.5)), from: me)
        do { let reached = sim.run(until: { $0.living(walker).task == .idle }, limit: 400); #expect(reached) }
        #expect(abs(Double(sim.tick) - 10 * Double(Tick.rate)) <= 2)
    }

    @Test func peopleSentTogetherSpreadAroundThePoint() {
        var sim = duel()
        let group = (0..<9).map { k in sim.add(.spearman, me, 8.5 + Double(k), 16.5) }
        let point = MapPosition(x: 18, y: 18)
        _ = sim.apply(.move(units: group, to: point), from: me)
        do { let reached = sim.run(until: { s in group.allSatisfy { s.living($0).task == .idle } }, limit: 600); #expect(reached) }
        let spots = group.map { sim.living($0).position }
        #expect(Set(spots.map { "\($0.x),\($0.y)" }).count == group.count)
        #expect(spots.allSatisfy { $0.distance(to: point) <= 1.5 })
    }

    @Test func aChaserKeepsToItsRouteWhenNoSearchIsLeftToReplanIt() {
        var sim = Self.walled()
        let chaser = sim.add(.spearman, me, 10.5, 5.5)
        let target = sim.add(.worker, them, 20.5, 5.5)
        sim.add(.worker, me, 21.5, 6.5)                      // to see the target by
        #expect(sim.apply(.attack(units: [chaser], target: target), from: me) == .accepted)
        sim.step()
        #expect(!sim.living(chaser).route.waypoints.isEmpty)  // the wall forced a search
        _ = sim.apply(.move(units: [target], to: MapPosition(x: 22.5, y: 3.5)), from: them)
        sim.searchBudget = 0
        sim.run(25)
        // The target has changed tile and a re-plan is due, but none can be had.
        #expect(sim.living(target).position.tile != GridPoint(20, 5))
        let before = sim.living(chaser).position
        sim.run(20)
        #expect(sim.living(chaser).position != before)
        #expect(sim.living(chaser).task == .attack(target))
    }

    @Test func aMoveOffTheMapIsRefusedAndOntoWaterStopsAtTheShore() {
        var sim = Self.walled()
        let worker = sim.add(.worker, me, 10.5, 5.5)
        #expect(sim.apply(.move(units: [worker], to: MapPosition(x: -1, y: 5)), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.move(units: [worker], to: MapPosition(x: 15.5, y: 3.5)), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(worker).task == .idle }, limit: 400); #expect(reached) }
        let spot = sim.living(worker).position
        #expect(sim.open(spot.tile))
        #expect(spot.distance(to: MapPosition(x: 15.5, y: 3.5)) <= 1.5)
    }
}
