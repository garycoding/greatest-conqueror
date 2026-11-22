// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

/// The budget of a tick: 1,200 people moving and fighting on a 96 × 96 map, in a
/// release build (`swift test -c release --filter Performance`), take under 5 ms
/// a step on average. A debug build runs a few ticks of the same battle, to keep
/// the scenario working without timing it.
@Suite struct Performance {
    /// Two teams of two, 300 warfighters each, either side of a river with three
    /// fords, each sent against an opponent across it. Health is raised fivefold
    /// so that the battle is still at full size when the measurement ends.
    static func battle() -> Simulation {
        var catalogue = Catalogue.standard
        catalogue.populationMaximum = 2_000
        for k in catalogue.units.indices where catalogue.units[k].kind.isWarfighter { catalogue.units[k].health *= 5 }
        let size = 96
        var water: [GridPoint] = []
        for y in 0..<size where !(20..<24).contains(y) && !(46..<50).contains(y) && !(72..<76).contains(y) {
            water.append(GridPoint(47, y))
            water.append(GridPoint(48, y))
        }
        var trees: [(SiteKind, Int, Int)] = []
        for y in 30..<40 { for x in 38..<42 { trees.append((.tree, x, y)) } }
        for y in 56..<66 { for x in 54..<58 { trees.append((.tree, x, y)) } }
        let map = openMap(width: size, height: size,
                          starts: [GridPoint(2, 2), GridPoint(2, 91), GridPoint(91, 2), GridPoint(91, 91)],
                          sites: trees, water: water, catalogue: catalogue)
        var sim = Simulation(setup: setup(map, teams: [0, 0, 1, 1], catalogue: catalogue))
        let kinds: [UnitKind] = [.spearman, .musketeer, .spearman, .musketeer, .horseman]
        var west: [EntityID] = [], east: [EntityID] = []
        for k in 0..<600 {
            let row = Double(k / 20), col = Double(k % 20)
            let kind = kinds[k % kinds.count]
            west.append(sim.add(kind, PlayerID(k % 2), 20 + col, 18 + row * 2))
            east.append(sim.add(kind, PlayerID(2 + k % 2), 56 + col, 18 + row * 2))
        }
        // Each side marches on the other, through the fords.
        for k in 0..<600 {
            let y = 18 + Double(k / 20) * 2
            _ = sim.apply(.move(units: [west[k]], to: MapPosition(x: 66, y: y)), from: PlayerID(k % 2))
            _ = sim.apply(.move(units: [east[k]], to: MapPosition(x: 30, y: y)), from: PlayerID(2 + k % 2))
        }
        return sim
    }

    @Test func twelveHundredPeopleStepWithinFiveMilliseconds() {
        var sim = Self.battle()
        let people = sim.entities.filter { $0.isPerson }.count
        #expect(people >= 1_200)
        let healthBefore = sim.entities.filter(\.isPerson).map(\.health).reduce(0, +)
        let positionsBefore = sim.entities.filter(\.isPerson).map(\.position)
        #if DEBUG
        let ticks = 10
        #else
        let ticks = 400
        #endif
        let clock = ContinuousClock()
        var total = Duration.zero
        var fewest = people
        for _ in 0..<ticks {
            total += clock.measure { sim.step() }
            fewest = min(fewest, sim.entities.filter(\.isPerson).count)
            // Orders between steps are not timed: as a computer player would, each
            // warfighter not yet fighting is sent against the nearest opponent in sight.
            if sim.tick % 10 == 0 { Self.engage(&sim) }
        }
        let average = total / ticks
        let milliseconds = Double(average.components.attoseconds) / 1e15 + Double(average.components.seconds) * 1e3
        let doing = Doing.allCases.map { d in "\(d) \(sim.entities.filter { $0.isPerson && $0.doing == d }.count)" }
        print("Performance: \(ticks) steps, \(fewest) or more people, average step \(milliseconds) ms; at the end: \(doing.joined(separator: ", "))")
        let moved = zip(positionsBefore, sim.entities.filter(\.isPerson).map(\.position)).filter { $0 != $1 }.count
        #expect(fewest >= 1_100)
        #if DEBUG
        #expect(moved > 0)
        #else
        #expect(moved > people / 2)
        let healthAfter = sim.entities.filter(\.isPerson).map(\.health).reduce(0, +)
        #expect(healthAfter < healthBefore)
        #expect(sim.entities.contains { $0.doing == .fighting })
        #expect(milliseconds < 5)
        #endif
    }

    /// Send each warfighter that is not attacking against the nearest opponent it can see.
    static func engage(_ sim: inout Simulation) {
        for i in sim.entities.indices where sim.entities[i].alive && sim.entities[i].isPerson {
            if case .attack = sim.entities[i].task { continue }
            guard let target = sim.nearestTarget(for: i) else { continue }
            _ = sim.apply(.attack(units: [sim.entities[i].id], target: sim.entities[target].id), from: sim.entities[i].owner)
        }
    }
}
