// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

@Suite struct IronAge {
    @Test func theBronzeAgeLeadsToTheIronAge() {
        var sim = duel()
        sim.players[0].age = .bronze
        let advance = Catalogue.standard.advance(from: .bronze)!
        sim.players[0].study = advance.study
        sim.give(me, [.food: 1000, .bronze: 1000, .gold: 1000])
        #expect(sim.apply(.advanceAge, from: me) == .accepted)
        #expect(sim.players[0].age == .iron)
        #expect(Catalogue.standard.advance(from: .iron) != nil)
    }

    @Test func aFarmFeedsOneWorkerAndThePloughRaisesItsYield() {
        var sim = duel()
        sim.players[0].age = .iron
        let farm = sim.add(.farm, me, 8, 8)
        let workers = sim.people(me, .worker)
        #expect(workers.count >= 2)
        // Two workers sent to one farm: one tends it, the other is left as it was.
        #expect(sim.apply(.work(units: [workers[0], workers[1]], at: farm), from: me) == .accepted)
        #expect(sim.living(workers[0]).task == .work(farm))
        #expect(sim.living(workers[1]).task != .work(farm))
        #expect(sim.apply(.work(units: [workers[1]], at: farm), from: me) == .refused(.invalidTarget))
        do { let reached = sim.run(until: { $0.living(workers[0]).doing == .working }, limit: 300); #expect(reached) }
        let perSecond = Catalogue.standard.gathering.farmingPerSecond!
        var food = sim.resources(me)[.food]
        sim.run(60 * Tick.rate)
        #expect(abs(Double(sim.resources(me)[.food] - food) - 60 * perSecond) <= 1)
        // Much later the farm still yields: its farmer reseeds it from the stock's wood.
        sim.players[0].resources = ResourceAmounts([.wood: 1000])
        sim.run(20 * 60 * Tick.rate)
        #expect(sim.resources(me)[.wood] < 1000)
        food = sim.resources(me)[.food]
        sim.players[0].improvements.append(.plough)
        sim.run(60 * Tick.rate)
        #expect(abs(Double(sim.resources(me)[.food] - food) - 60 * perSecond * 1.25) <= 1)
        #expect(sim.living(workers[0]).task == .work(farm))
    }

    @Test func aFarmRunsDryAndIsReseededByItsFarmerOrByOrder() {
        var sim = duel()
        sim.players[0].age = .iron
        let farm = sim.add(.farm, me, 8, 8)
        let farmer = sim.people(me, .worker)[0]
        let full = Catalogue.standard.gathering.farmYield!, cost = Catalogue.standard.gathering.farmReseed!
        #expect(sim.view(for: me).entity(farm)?.remaining == full)
        // Without wood, the farm runs dry and the farmer waits there.
        sim.players[0].resources = ResourceAmounts()
        #expect(sim.apply(.work(units: [farmer], at: farm), from: me) == .accepted)
        do { let reached = sim.run(until: { ($0.entity(farm)?.farmUsed ?? 0) >= full }, limit: 20 * 60 * Tick.rate); #expect(reached) }
        #expect(sim.resources(me)[.food] == full)
        sim.run(30 * Tick.rate)
        #expect(sim.resources(me)[.food] == full)
        #expect(sim.living(farmer).task == .work(farm))
        // Once the wood is there, the farmer reseeds it and the farm yields again.
        sim.give(me, [.wood: 100])
        sim.run(30 * Tick.rate)
        #expect(sim.resources(me)[.wood] == 100 - cost[.wood])
        #expect(sim.resources(me)[.food] > full)
        // A farm without a farmer is reseeded by order, and only once it has run dry.
        #expect(sim.apply(.reseed(farm: farm), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.stop(units: [farmer]), from: me) == .accepted)
        sim.entities[sim.index(of: farm)!].farmUsed = full
        sim.players[0].resources = ResourceAmounts()
        #expect(sim.apply(.reseed(farm: farm), from: me) == .refused(.notEnough(cost)))
        sim.give(me, [.wood: 60])
        #expect(sim.apply(.reseed(farm: farm), from: me) == .accepted)
        #expect(sim.view(for: me).entity(farm)?.remaining == full)
    }

    @Test func theCatapultsStoneHarmsOpponentsAroundTheTargetAndNoAlly() {
        var sim = Simulation(setup: setup(openMap(starts: [GridPoint(2, 2), GridPoint(34, 34), GridPoint(2, 34)]),
                                          teams: [0, 1, 0]))
        let ally = PlayerID(2)
        let catapult = sim.add(.catapult, me, 10.5, 18.5)
        let target = sim.add(.swordsman, them, 18.5, 18.5)
        let beside = sim.add(.swordsman, them, 19.5, 18.5)
        let far = sim.add(.swordsman, them, 22.5, 18.5)
        let friend = sim.add(.swordsman, ally, 18.5, 19.5)
        let attack = Catalogue.standard.stats(.catapult).attack!
        sim.strike(from: sim.index(of: catapult)!, at: sim.index(of: target)!, attack: attack)
        let full = Catalogue.standard.stats(.swordsman).health
        #expect(sim.living(target).health < full)
        #expect(sim.living(beside).health < full)
        #expect(sim.living(far).health == full)
        #expect(sim.living(friend).health == full)
    }

    @Test func theIronCountersAndUpgrades() {
        #expect(Combat.harm(.unit(.spearman), .unit(.horseman)) == 5 * 3 - 1)
        #expect(Combat.harm(.unit(.horseman), .unit(.archer)) == 7 * 2)
        #expect(Combat.harm(.unit(.swordsman), .unit(.spearman)) == Int((7 * 1.5).rounded()) - 1)
        #expect(Combat.harm(.unit(.swordsman), .unit(.swordsman), attackerHas: [.ironWeapons]) == 9 - 2)
        #expect(Combat.harm(.unit(.swordsman), .unit(.swordsman), defenderHas: [.mail]) == 7 - 3)
        #expect(Catalogue.standard.upgrade(from: .spearman)?.to == .swordsman)
        #expect(Catalogue.standard.upgrade(from: .chariot)?.to == .horseman)
    }

    @Test func theNewBuildingsTrainTheNewWarfighters() {
        var sim = duel()
        sim.players[0].age = .iron
        sim.give(me, [.food: 1000, .wood: 1000, .iron: 1000])
        let stable = sim.add(.stable, me, 8, 8)
        let workshop = sim.add(.siegeWorkshop, me, 12, 8)
        for x in [16, 18] { sim.add(.house, me, x, 8) }
        #expect(sim.apply(.train(at: stable, unit: .horseman), from: me) == .accepted)
        #expect(sim.apply(.train(at: workshop, unit: .catapult), from: me) == .accepted)
        #expect(sim.apply(.train(at: stable, unit: .swordsman), from: me) != .accepted)
        sim.run(40 * Tick.rate)
        #expect(sim.people(me, .horseman).count == 1)
        #expect(sim.people(me, .catapult).count == 1)
    }
}
