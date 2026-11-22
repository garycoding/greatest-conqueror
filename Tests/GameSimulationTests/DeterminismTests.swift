// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameSimulation

/// A fixed script for both players of `Samples.twoPlayerSetup`: orders at tick 1
/// and every 100 ticks, each worked out from the player's view as a computer
/// player would, so that the same match is played in every process.
enum Script {
    static let length = 12_000

    static func isOrderTick(_ t: Int) -> Bool { t == 1 || t % 100 == 0 }

    static func orders(at t: Int, view: PlayerView, catalogue: Catalogue = .standard) -> [Order] {
        let mine = view.entities.filter { $0.owner == view.player }
        guard let centre = mine.first(where: { $0.kind == .building(.townCentre) }) else { return [] }
        let held = view.resources
        let bronze = view.age >= .bronze
        func people(_ kind: UnitKind) -> [EntityView] { mine.filter { $0.kind == .unit(kind) } }
        func idle(_ kind: UnitKind) -> [EntityID] { people(kind).filter { $0.activity == .idle }.map(\.id) }
        func buildings(_ kind: BuildingKind) -> [EntityView] { mine.filter { $0.kind == .building(kind) } }
        func complete(_ kind: BuildingKind) -> EntityView? {
            buildings(kind).first { if case .underConstruction = $0.activity { false } else { true } }
        }
        func nearest(_ kind: SiteKind) -> SiteID? {
            view.sites.filter { $0.kind == kind }.min {
                ($0.tile.centre.distance(to: centre.position), $0.id) < ($1.tile.centre.distance(to: centre.position), $1.id)
            }?.id
        }
        func spot(_ kind: BuildingKind, near c: GridPoint) -> GridPoint? {
            for r in 2...12 {
                for dy in -r...r {
                    for dx in -r...r where max(abs(dx), abs(dy)) == r {
                        let o = GridPoint(c.x + dx, c.y + dy)
                        if Placement.canPlace(kind, at: o, in: view, catalogue: catalogue) { return o }
                    }
                }
            }
            return nil
        }
        var out: [Order] = []
        if t == 1 {
            let workers = people(.worker).map(\.id)
            if let prey = nearest(.prey) { out.append(.gather(units: Array(workers.prefix(2)), site: prey)) }
            if let tree = nearest(.tree) { out.append(.gather(units: Array(workers.dropFirst(2)), site: tree)) }
            out.append(.train(at: centre.id, unit: .engineer))
            return out
        }
        // Idle workers go where the need is: food first, then wood, and in the
        // Bronze age to the stock pen, copper and tin.
        var herders = people(.worker).filter { $0.activity == .working }.count
        var sent: [EntityID] = []
        if let pen = complete(.stockPen) {
            for worker in idle(.worker) + people(.worker).filter({ $0.activity != .working }).map(\.id)
            where herders < 2 && !sent.contains(worker) {
                out.append(.work(units: [worker], at: pen.id))
                herders += 1
                sent.append(worker)
            }
        }
        for (k, worker) in idle(.worker).enumerated() where !sent.contains(worker) {
            let kinds: [SiteKind] = bronze ? [.copper, .tin, .tree]
                : held[.food] < 300 && nearest(.prey) != nil ? [.prey] : held[.wood] < 300 ? [.tree] : [.stone, .tree]
            if let site = nearest(kinds[k % kinds.count]) ?? nearest(.tree) { out.append(.gather(units: [worker], site: site)) }
        }
        if let engineer = idle(.engineer).first {
            let tree = nearest(.tree).flatMap { id in view.sites.first { $0.id == id }?.tile } ?? centre.tile
            let crowded = view.populationLimit - view.population <= 1 && buildings(.house).count < 3
            if buildings(.storagePit).isEmpty, let at = spot(.storagePit, near: tree) {
                out.append(.construct(engineers: [engineer], building: .storagePit, at: at))
            } else if crowded, let at = spot(.house, near: centre.tile) {
                out.append(.construct(engineers: [engineer], building: .house, at: at))
            } else if bronze, buildings(.stockPen).isEmpty, let at = spot(.stockPen, near: centre.tile) {
                out.append(.construct(engineers: [engineer], building: .stockPen, at: at))
            } else if bronze, buildings(.barracks).isEmpty, let at = spot(.barracks, near: centre.tile) {
                out.append(.construct(engineers: [engineer], building: .barracks, at: at))
            } else if bronze, buildings(.watchTower).isEmpty, let at = spot(.watchTower, near: centre.tile) {
                out.append(.construct(engineers: [engineer], building: .watchTower, at: at))
            }
        }
        let scholars = idle(.scholar)
        if !scholars.isEmpty { out.append(.work(units: scholars, at: centre.id)) }
        // One person in training at a time, scholars and workers before warfighters.
        if case .training = centre.activity {} else {
            if people(.scholar).count < 2 { out.append(.train(at: centre.id, unit: .scholar)) }
            else if people(.worker).count < 5 { out.append(.train(at: centre.id, unit: .worker)) }
            else if t > 2_500 && held[.food] >= (bronze ? 150 : 400) { out.append(.train(at: centre.id, unit: .clubman)) }
        }
        if let barracks = complete(.barracks), t % 300 == 0 {
            out.append(.train(at: barracks.id, unit: .spearman))
            let clubmen = people(.clubman).map(\.id)
            if !clubmen.isEmpty { out.append(.upgrade(units: clubmen, to: .spearman, at: barracks.id)) }
        }
        if view.ageProgress >= 1 { out.append(.advanceAge) }
        if bronze && !view.improvements.contains(.betterTools) {
            out.append(.research(at: centre.id, improvement: .betterTools))
        }
        if t >= 4_000 && t % 200 == 0 {
            let fighters = mine.filter { e in
                if case .unit(let k) = e.kind { return k.isWarfighter && e.activity != .fighting }
                return false
            }
            let opponents = view.entities.filter { !view.isAlly($0.owner) }
            for f in fighters {
                let target = opponents.min {
                    ($0.position.distance(to: f.position), $0.id) < ($1.position.distance(to: f.position), $1.id)
                }
                if let target, target.position.distance(to: f.position) < 8 {
                    out.append(.attack(units: [f.id], target: target.id))
                } else {
                    out.append(.move(units: [f.id], to: Samples.map().starts[1 - view.player.rawValue].centre))
                }
            }
        }
        return out
    }

    /// What a scripted run did, from the orders' results and the views' events.
    struct Log {
        var accepted = 0
        var refused = 0
        var constructed = 0
        var trained = 0
        var destroyed = 0
        var researched = 0
        var ages = 0
    }

    /// Play the script from one tick to another.
    static func play(_ sim: inout Simulation, from start: Int = 1, through end: Int = length, log: inout Log) {
        for t in start...end {
            if isOrderTick(t) {
                for p in sim.players.map(\.id) {
                    let view = sim.view(for: p)
                    for event in view.events {
                        switch event {
                        case .constructed: log.constructed += 1
                        case .trained: log.trained += 1
                        case .destroyed: log.destroyed += 1
                        case .researched: log.researched += 1
                        case .ageReached: log.ages += 1
                        default: break
                        }
                    }
                    for order in orders(at: t, view: view) {
                        if sim.apply(order, from: p) == .accepted { log.accepted += 1 } else { log.refused += 1 }
                    }
                }
            }
            sim.step()
        }
    }
}

@Suite struct Determinism {
    /// The checksum at the end of the scripted match. A second process must
    /// reproduce it; a change to the rules that changes the match changes it.
    static let storedChecksum: UInt64 = 0xD98A_E2B1_1D05_3CC3

    @Test func theScriptedMatchEndsWithTheStoredChecksum() {
        var sim = Simulation(setup: Samples.twoPlayerSetup(seed: 7))
        var log = Script.Log()
        Script.play(&sim, log: &log)
        print("Determinism: checksum \(String(sim.checksum(), radix: 16)), \(log)")
        // The milestones of the match: the script's orders did something.
        #expect(sim.tick == Script.length)
        #expect(log.accepted >= 30)
        #expect(log.constructed >= 4)
        #expect(log.trained >= 10)
        #expect(log.ages >= 1 && sim.players[0].age == .bronze)
        #expect(log.researched >= 1)
        #expect(log.destroyed >= 1)
        #expect(sim.checksum() == Self.storedChecksum, "\(String(sim.checksum(), radix: 16))")
    }

    @Test func aSavedMatchResumesExactly() throws {
        var straight = Simulation(setup: Samples.twoPlayerSetup(seed: 7))
        var log = Script.Log()
        Script.play(&straight, through: Script.length, log: &log)

        var first = Simulation(setup: Samples.twoPlayerSetup(seed: 7))
        var halves = Script.Log()
        Script.play(&first, through: 4_000, log: &halves)
        let saved = try JSONEncoder().encode(first)
        var resumed = try JSONDecoder().decode(Simulation.self, from: saved)
        #expect(resumed.checksum() == first.checksum())
        Script.play(&resumed, from: 4_001, through: Script.length, log: &halves)
        #expect(resumed.checksum() == straight.checksum())
    }

    @Test func theCachesKeptAsTheMatchGoesMatchOnesRebuiltFromTheState() {
        var sim = Simulation(setup: Samples.twoPlayerSetup(seed: 7))
        var log = Script.Log()
        Script.play(&sim, through: 4_000, log: &log)
        var rebuilt = sim
        rebuilt.rebuildCaches()
        #expect(rebuilt.seen == sim.seen)
        #expect(rebuilt.blocked == sim.blocked)
        #expect(rebuilt.buildingAt == sim.buildingAt)
        #expect(rebuilt.siteAt == sim.siteAt)
        #expect(rebuilt.population == sim.population)
        #expect(rebuilt.housing == sim.housing)
        #expect(rebuilt.indexOfEntity == sim.indexOfEntity)
        #expect(rebuilt.checksum() == sim.checksum())
    }

    @Test func theSameSetupAndOrdersGiveTheSameMatchAndAnotherSeedAnotherChecksum() {
        func run(_ seed: UInt64) -> UInt64 {
            var sim = Simulation(setup: Samples.twoPlayerSetup(seed: seed))
            var log = Script.Log()
            Script.play(&sim, through: 1_000, log: &log)
            return sim.checksum()
        }
        #expect(run(7) == run(7))
        #expect(run(7) != run(8))
    }
}
