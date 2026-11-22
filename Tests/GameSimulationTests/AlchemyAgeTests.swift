// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

@Suite struct AlchemyAge {
    @Test func theIronAgeLeadsToTheAlchemyAge() {
        var sim = duel()
        sim.players[0].age = .iron
        sim.players[0].study = Catalogue.standard.advance(from: .iron)!.study
        sim.give(me, [.food: 1000, .iron: 1000, .gold: 1000])
        #expect(sim.apply(.advanceAge, from: me) == .accepted)
        #expect(sim.players[0].age == .alchemy)
        #expect(Catalogue.standard.advance(from: .alchemy) != nil)
        #expect(UnitKind.worker.stageName(at: .alchemy) == "Craftsman")
    }

    @Test func craftsmenMakeGunpowderFromWoodThreeToAWorkshop() {
        var sim = duel()
        sim.players[0].age = .alchemy
        let workshop = sim.add(.alchemistsWorkshop, me, 8, 8)
        for k in 0..<2 { sim.add(.worker, me, 6.5 + Double(k), 6.5) }
        let workers = sim.people(me, .worker)
        #expect(workers.count >= 4)
        sim.players[0].resources = ResourceAmounts([.wood: 1000])
        #expect(sim.apply(.work(units: Array(workers.prefix(4)), at: workshop), from: me) == .accepted)
        #expect(workers.prefix(4).filter { sim.living($0).task == .work(workshop) }.count == 3)
        sim.run(until: { s in workers.prefix(3).allSatisfy { s.living($0).doing == .working } }, limit: 300)
        let before = sim.resources(me)
        sim.run(60 * Tick.rate)
        let made = sim.resources(me)[.gunpowder] - before[.gunpowder]
        #expect(abs(Double(made) - 3 * 60 * Catalogue.standard.workshop!.perSecond) <= 3)
        #expect(before[.wood] - sim.resources(me)[.wood] == made * 2)
        // With no wood, nothing is made.
        sim.players[0].resources = ResourceAmounts()
        sim.run(10 * Tick.rate)
        #expect(sim.resources(me)[.gunpowder] == 0)
    }

    @Test func theCastleTrainsTheAlchemyWarfightersShootsAndHouses() {
        let castle = Catalogue.standard.stats(.castle)
        #expect(Set(castle.trains) == [.knight, .musketeer, .cannon])
        #expect(castle.attack != nil && castle.housing > 0)
        #expect(BuildingKind.allCases.allSatisfy { $0 == .castle || Catalogue.standard.stats($0).health < castle.health })
        var sim = duel()
        sim.players[0].age = .alchemy
        sim.give(me, [.food: 1000, .gold: 1000, .gunpowder: 1000, .wood: 1000, .iron: 1000])
        let c = sim.add(.castle, me, 10, 10)
        #expect(sim.apply(.train(at: c, unit: .musketeer), from: me) == .accepted)
    }

    @Test func theAlchemyCountersUpgradesAndImprovements() {
        #expect(Combat.harm(.unit(.musketeer), .unit(.knight)) == 12 * 2 - 3)
        #expect(Combat.harm(.unit(.spearman), .unit(.knight)) == Int((5 * 2.5).rounded()) - 3)
        #expect(Combat.harm(.unit(.knight), .unit(.swordsman), attackerHas: [.betterPowder]) == Int((12 * 1.5).rounded()) - 2)
        #expect(Combat.harm(.unit(.knight), .unit(.knight), defenderHas: [.plateArmour]) == 10 - 5)
        #expect(Catalogue.standard.upgrade(from: .swordsman)?.to == .musketeer)
        #expect(Catalogue.standard.upgrade(from: .horseman)?.to == .knight)
        #expect(Catalogue.standard.upgrade(from: .catapult)?.to == .cannon)
    }
}
