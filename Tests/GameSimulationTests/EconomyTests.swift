// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

// Player 0's town centre covers (2...4, 2...4) on the duel map; its starting
// workers stand beside it.

private let load = Catalogue.standard.gathering.load

@Suite struct Gathering {
    @Test func workersFellTreesAndCarryALoadToTheNearestBuildingThatAcceptsIt() {
        var sim = duel(sites: [(.tree, 14, 3)])
        sim.exploreAll(me)
        sim.add(.townCentre, me, 10, 5)
        let worker = sim.people(me, .worker)[0]
        let wood = sim.resources(me)[.wood]
        #expect(sim.apply(.gather(units: [worker], site: SiteID(0)), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(worker).doing == .carrying }, limit: 1_500); #expect(reached) }
        let carrying = sim.view(for: me).entity(worker)?.activity
        #expect(carrying == .carrying(.wood, load))
        do { let reached = sim.run(until: { $0.resources(me)[.wood] > wood }, limit: 500); #expect(reached) }
        #expect(sim.resources(me)[.wood] == wood + load)
        // Delivered beside the second town centre, which is nearer than the first.
        let pit = Goal.tiles(GridPoint(10, 5), GridPoint(3, 3), reach: 0)
        #expect(pit.distance(to: sim.living(worker).position) <= Rule.besideReach)
        #expect(sim.sites[0].remaining == Catalogue.standard.gathering.amount(.tree) - load)
        // And it goes back for more.
        do { let reached = sim.run(until: { $0.living(worker).doing == .gathering }, limit: 300); #expect(reached) }
    }

    @Test(arguments: [SiteKind.prey, .gold])
    func workersHuntAndMineGoldFromTheAgeOfTowns(_ kind: SiteKind) {
        var sim = duel(sites: [(kind, 9, 3)])
        sim.exploreAll(me)
        let worker = sim.people(me, .worker)[0]
        let before = sim.resources(me)[kind.yield]
        #expect(sim.apply(.gather(units: [worker], site: SiteID(0)), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.resources(me)[kind.yield] > before }, limit: 2_000); #expect(reached) }
        #expect(sim.resources(me)[kind.yield] == before + load)
    }

    @Test func anExhaustedSiteVanishesAndItsWorkerTurnsToTheNextOfItsKind() {
        var sim = duel(sites: [(.tree, 8, 3), (.tree, 10, 3)])
        sim.exploreAll(me)
        sim.sites[0].remaining = 4
        let worker = sim.people(me, .worker)[0]
        _ = sim.apply(.gather(units: [worker], site: SiteID(0)), from: me)
        do { let reached = sim.run(until: { $0.sites[0].remaining == 0 }, limit: 1_000); #expect(reached) }
        #expect(!sim.view(for: me).sites.contains { $0.id == SiteID(0) })
        #expect(sim.open(GridPoint(8, 3)))
        sim.step()
        if case .gather(let site, _, _) = sim.living(worker).task { #expect(site == SiteID(1)) } else { Issue.record("not gathering") }
    }

    @Test func aWorkerWithNoSiteLeftCarriesHomeWhatItHolds() {
        var sim = duel(sites: [(.tree, 8, 3)])
        sim.exploreAll(me)
        sim.sites[0].remaining = 4
        let worker = sim.people(me, .worker)[0]
        let wood = sim.resources(me)[.wood]
        _ = sim.apply(.gather(units: [worker], site: SiteID(0)), from: me)
        do { let reached = sim.run(until: { $0.resources(me)[.wood] > wood }, limit: 1_000); #expect(reached) }
        #expect(sim.resources(me)[.wood] == wood + 4)
        sim.step()
        #expect(sim.living(worker).task == .idle)
    }

    @Test func aFarmFeedsOneWorker() {
        var sim = duel()
        sim.players[0].age = .ships
        let farm = sim.add(.farm, me, 8, 8)
        let workers = sim.people(me, .worker)
        #expect(workers.count >= 2)
        // Two workers sent to one farm: one tends it, the other is left as it was.
        #expect(sim.apply(.work(units: [workers[0], workers[1]], at: farm), from: me) == .accepted)
        #expect(sim.living(workers[0]).task == .work(farm))
        #expect(sim.living(workers[1]).task != .work(farm))
        #expect(sim.apply(.work(units: [workers[1]], at: farm), from: me) == .refused(.invalidTarget))
        do { let reached = sim.run(until: { $0.living(workers[0]).doing == .working }, limit: 300); #expect(reached) }
        let perSecond = Catalogue.standard.gathering.farmingPerSecond
        let food = sim.resources(me)[.food]
        sim.run(60 * Tick.rate)
        #expect(abs(Double(sim.resources(me)[.food] - food) - 60 * perSecond) <= 1)
        #expect(sim.view(for: me).entity(workers[0])?.job == .working(.farm))
        // Much later the farm still yields: its farmer reseeds it from the stock's wood.
        sim.players[0].resources = ResourceAmounts([.wood: 1000])
        sim.run(20 * 60 * Tick.rate)
        #expect(sim.resources(me)[.wood] < 1000)
        #expect(sim.living(workers[0]).task == .work(farm))
    }

    @Test func aFarmRunsDryAndIsReseededByItsFarmerOrByOrder() {
        var sim = duel()
        sim.players[0].age = .ships
        let farm = sim.add(.farm, me, 8, 8)
        let farmer = sim.people(me, .worker)[0]
        let full = Catalogue.standard.gathering.farmYield, cost = Catalogue.standard.gathering.farmReseed
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

    @Test func aWorkerGathersAtTheRateTheCatalogueSets() {
        var sim = duel(sites: [(.tree, 8, 3)])
        sim.exploreAll(me)
        let worker = sim.people(me, .worker)[0]
        _ = sim.apply(.gather(units: [worker], site: SiteID(0)), from: me)
        var ticks = 0
        while (sim.living(worker).cargo?.amount ?? 0) < load && ticks < 2_000 {
            sim.step()
            if sim.living(worker).doing == .gathering { ticks += 1 }
        }
        let expected = Double(load) / (Catalogue.standard.gathering.perSecond(.tree) / Double(Tick.rate))
        #expect(abs(Double(ticks) - expected) <= 1)
    }

    @Test func onlyWorkersGatherOnLand() {
        var sim = duel(sites: [(.gold, 8, 6)])
        sim.exploreAll(me)
        let spearman = sim.add(.spearman, me, 6.5, 6.5)
        #expect(sim.apply(.gather(units: [spearman], site: SiteID(0)), from: me) == .refused(.notYours))
    }
}

@Suite struct Construction {
    @Test func workersConstructAndTheCostIsPaidWhenOrdered() {
        var sim = duel()
        let builder = sim.add(.worker, me, 6.5, 6.5)
        let wood = sim.resources(me)[.wood]
        #expect(sim.apply(.construct(workers: [builder], building: .house, at: GridPoint(8, 2)), from: me) == .accepted)
        #expect(sim.resources(me)[.wood] == wood - Catalogue.standard.stats(.house).cost[.wood])
        let house = sim.buildings(me, .house)[0]
        #expect(sim.view(for: me).entity(house)?.activity == .underConstruction(0))
        do { let reached = sim.run(until: { $0.living(house).complete }, limit: 1_000); #expect(reached) }
        let view = sim.view(for: me)
        #expect(view.events.contains(.constructed(house, .house)))
        #expect(view.populationLimit == 10)
        sim.step()
        #expect(sim.living(builder).task == .idle)
    }

    @Test func aBuilderGoesOnToTheNextBuildingUnderConstructionNearby() {
        var sim = duel()
        let builder = sim.add(.worker, me, 6.5, 6.5)
        #expect(sim.apply(.construct(workers: [builder], building: .house, at: GridPoint(8, 2)), from: me) == .accepted)
        let first = sim.buildings(me, .house)[0]
        let second = sim.add(.house, me, 11, 2, complete: false)
        let far = sim.add(.house, me, 30, 30, complete: false)
        do { let reached = sim.run(until: { $0.living(first).complete }, limit: 1_000); #expect(reached) }
        sim.step()
        #expect(sim.living(builder).task == .work(second))
        do { let reached = sim.run(until: { $0.living(second).complete }, limit: 2_000); #expect(reached) }
        sim.step()
        // The far house is beyond the radius: the builder stands idle.
        #expect(sim.living(builder).task == .idle)
        #expect(!sim.living(far).complete)
    }

    @Test func aPersonsJobIsShownToItsPlayerOnly() {
        var sim = duel(sites: [(.tree, 8, 6)])
        sim.exploreAll(me)
        let worker = sim.people(me, .worker)[0], builder = sim.add(.worker, me, 6.5, 6.5)
        #expect(sim.apply(.gather(units: [worker], site: SiteID(0)), from: me) == .accepted)
        #expect(sim.apply(.construct(workers: [builder], building: .house, at: GridPoint(11, 2)), from: me) == .accepted)
        sim.step()
        var view = sim.view(for: me)
        #expect(view.entity(worker)?.job == .gathering(.tree))
        #expect(view.entity(builder)?.job == .constructing)
        // Carrying the wood back, the lumberjack keeps the job.
        let carrying = sim.run(until: { $0.living(worker).cargo != nil && $0.living(worker).doing != .gathering },
                               limit: 60 * Tick.rate)
        #expect(carrying)
        view = sim.view(for: me)
        #expect(view.entity(worker)?.job == .gathering(.tree))
        // An opponent's people carry no job in this player's view.
        let theirs = sim.add(.worker, them, 7.5, 7.5)
        #expect(sim.view(for: me).entity(theirs)?.job == nil)
    }

    @Test func constructionIsRefusedWherePlacementForbidsIt() {
        var sim = duel(sites: [(.tree, 8, 6)], water: [GridPoint(12, 8)])
        let builder = sim.add(.worker, me, 6.5, 6.5)
        let held = sim.resources(me)
        func build(_ kind: BuildingKind, _ x: Int, _ y: Int) -> OrderResult {
            sim.apply(.construct(workers: [builder], building: kind, at: GridPoint(x, y)), from: me)
        }
        #expect(build(.house, 7, 5) == .refused(.placementBlocked))     // over a tree
        #expect(build(.house, 3, 3) == .refused(.placementBlocked))     // over the town centre
        #expect(build(.house, 11, 7) == .refused(.placementBlocked))    // over water
        #expect(build(.house, 39, 20) == .refused(.placementBlocked))   // off the map
        #expect(build(.house, 25, 25) == .refused(.placementBlocked))   // unexplored
        #expect(build(.barracks, 8, 2) == .refused(.ageNotReached(.farms)))
        let boat = sim.add(.boat, me, 6.5, 7.5)
        #expect(sim.apply(.construct(workers: [boat], building: .house, at: GridPoint(8, 2)), from: me) == .refused(.notYours))
        sim.players[0].resources[.wood] = 10
        #expect(build(.house, 8, 2) == .refused(.notEnough(ResourceAmounts([.wood: 20]))))
        sim.players[0].resources = held
        #expect(sim.resources(me) == held)
        #expect(sim.buildings(me, .house).isEmpty)
    }

    /// Ticks from the first worker-tick to completion of a house.
    static func ticksToBuild(builders count: Int) -> Int {
        var sim = duel()
        let builders = (0..<count).map { _ in sim.add(.worker, me, 6.5, 6.5) }
        _ = sim.apply(.construct(workers: builders, building: .house, at: GridPoint(8, 2)), from: me)
        let house = sim.buildings(me, .house)[0]
        sim.run(until: { $0.living(house).built > 0 }, limit: 500)
        let start = sim.tick
        sim.run(until: { $0.living(house).complete }, limit: 1_000)
        return sim.tick - start
    }

    @Test func moreWorkersFinishSooner() {
        let buildTime = Catalogue.standard.stats(.house).buildTime
        #expect(abs(Self.ticksToBuild(builders: 1) - buildTime) <= 1)
        #expect(abs(Self.ticksToBuild(builders: 2) - buildTime / 2) <= 1)
    }

    @Test func workersRepairADamagedBuilding() {
        var sim = duel()
        let house = sim.add(.house, me, 8, 2)
        let i = sim.index(of: house)!
        sim.entities[i].health = 50
        let builder = sim.add(.worker, me, 6.5, 6.5)
        #expect(sim.apply(.work(units: [builder], at: house), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(builder).doing == .working }, limit: 200); #expect(reached) }
        let start = sim.living(house).health
        sim.run(100)
        // At full health per buildTime worker-ticks.
        let stats = Catalogue.standard.stats(.house)
        #expect(sim.living(house).health - start == 100 * stats.health / stats.buildTime)
        do { let reached = sim.run(until: { $0.living(house).health == stats.health }, limit: 1_000); #expect(reached) }
        sim.step()
        #expect(sim.living(builder).task == .idle)
        #expect(sim.apply(.work(units: [builder], at: house), from: me) == .refused(.invalidTarget))
    }
}

@Suite struct Demolition {
    @Test func workersPullDownAHouseOverHalfItsTimeForHalfItsCost() {
        var sim = duel()
        let house = sim.add(.house, me, 8, 2)
        let limit = sim.view(for: me).populationLimit
        let builder = sim.add(.worker, me, 6.5, 6.5)
        let before = sim.resources(me)
        #expect(sim.apply(.demolish(workers: [builder], building: house), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(builder).doing == .constructing }, limit: 200); #expect(reached) }
        let stats = Catalogue.standard.stats(.house)
        var ticks = 1
        while sim.entity(house) != nil, ticks < stats.buildTime { sim.step(); ticks += 1 }
        #expect(sim.entity(house) == nil)
        #expect(ticks == max(1, stats.buildTime / 2))
        #expect(sim.resources(me) == before + stats.cost.halved)
        let view = sim.view(for: me)
        #expect(view.populationLimit == limit - stats.housing)
        #expect(view.events.contains(.destroyed(house)))
        sim.step()
        #expect(sim.living(builder).task == .idle)
    }

    @Test func trainingUnderWayIsRefundedInFull() {
        var sim = duel()
        let centre = sim.townCentre(me)
        sim.give(me, [.food: 500])
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .accepted)
        let afterPaying = sim.resources(me)
        // Nearly pulled down already, so that it comes down before the worker is trained.
        let c = sim.index(of: centre)!
        sim.entities[c].demolished = Simulation.demolitionTime(Catalogue.standard.stats(.townCentre).buildTime) - 1
        let builder = sim.add(.worker, me, 6.5, 6.5)
        #expect(sim.apply(.demolish(workers: [builder], building: centre), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.entity(centre) == nil }, limit: 200); #expect(reached) }
        #expect(sim.people(me, .worker).count == sim.view(for: me).entities.filter { $0.kind == .unit(.worker) }.count)
        let back = Catalogue.standard.stats(.townCentre).cost.halved + Catalogue.standard.stats(.worker).cost
        #expect(sim.resources(me) == afterPaying + back)
    }

    @Test func onlyWorkersDemolishAndOnlyTheirOwnBuildings() {
        var sim = duel()
        let spearman = sim.add(.spearman, me, 6.5, 6.5)
        let builder = sim.add(.worker, me, 7.5, 6.5)
        #expect(sim.apply(.demolish(workers: [spearman], building: sim.townCentre(me)), from: me) == .refused(.notYours))
        #expect(sim.apply(.demolish(workers: [builder], building: sim.townCentre(them)), from: me) == .refused(.invalidTarget))
    }
}

@Suite struct Training {
    @Test func aQueuedPersonIsPaidForWhenQueuedAndAppearsBesideTheBuilding() {
        var sim = duel()
        let centre = sim.townCentre(me)
        let food = sim.resources(me)[.food]
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .accepted)
        #expect(sim.resources(me)[.food] == food - Catalogue.standard.stats(.worker).cost[.food])
        _ = sim.view(for: me)
        do { let reached = sim.run(until: { $0.people(me, .worker).count == 4 }, limit: 400); #expect(reached) }
        #expect(sim.tick == Catalogue.standard.stats(.worker).trainTime)
        let trained = sim.people(me, .worker).last!
        #expect(sim.view(for: me).events.contains(.trained(trained, .worker)))
        let footprint = Goal.tiles(GridPoint(2, 2), GridPoint(3, 3), reach: 0)
        #expect(footprint.distance(to: sim.living(trained).position) <= 1.5)
    }

    @Test func cancellingRemovesTheLastInTheQueueAndRefundsIt() {
        var sim = duel()
        let centre = sim.townCentre(me)
        let held = sim.resources(me)
        _ = sim.apply(.train(at: centre, unit: .worker), from: me)
        _ = sim.apply(.train(at: centre, unit: .worker), from: me)
        #expect(sim.living(centre).queue == [.worker, .worker])
        sim.run(5)
        #expect(sim.apply(.cancelTraining(at: centre), from: me) == .accepted)
        #expect(sim.living(centre).queue == [.worker])
        #expect(sim.resources(me) == held - Catalogue.standard.stats(.worker).cost)
        #expect(sim.living(centre).trainProgress == 5)
        #expect(sim.apply(.cancelTraining(at: centre), from: me) == .accepted)
        #expect(sim.resources(me) == held)
        #expect(sim.apply(.cancelTraining(at: centre), from: me) == .refused(.invalidTarget))
    }

    @Test func thePopulationLimitIsTheSumOfHousingCappedAtTheMaximum() {
        var sim = duel()
        sim.give(me, [.food: 1_000, .wood: 1_000])
        let centre = sim.townCentre(me)
        // Three workers and the town centre's five places: room for two more, queued ones counted.
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .accepted)
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .accepted)
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .refused(.populationLimit))
        sim.add(.house, me, 8, 2)
        #expect(sim.view(for: me).populationLimit == 10)
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .accepted)
        // A house under construction houses no one.
        sim.add(.house, me, 8, 6, complete: false)
        #expect(sim.view(for: me).populationLimit == 10)

        var capped = Catalogue.standard
        capped.populationMaximum = 7
        var small = duel(catalogue: capped)
        small.add(.house, me, 8, 2)
        small.add(.house, me, 8, 6)
        #expect(small.view(for: me).populationLimit == 7)
    }

    @Test func trainingNeedsTheAgeAndABuildingThatTrainsTheKind() {
        var sim = duel()
        sim.give(me, [.gold: 100])
        let centre = sim.townCentre(me)
        let barracks = sim.add(.barracks, me, 8, 8)
        #expect(sim.apply(.train(at: barracks, unit: .spearman), from: me) == .refused(.ageNotReached(.farms)))
        #expect(sim.apply(.train(at: centre, unit: .spearman), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.train(at: centre, unit: .car), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.train(at: sim.townCentre(them), unit: .worker), from: me) == .refused(.notYours))
        sim.players[0].resources = ResourceAmounts()
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .refused(.notEnough(ResourceAmounts([.food: 50]))))
    }
}

@Suite struct Advance {
    /// A catalogue whose first advance takes 400 ticks.
    static var quickAdvance: Catalogue {
        var c = Catalogue.standard
        c.advances[0].time = 400
        return c
    }

    @Test func theAdvanceIsPaidAtATownCentreAndTakesItsTime() {
        let catalogue = Self.quickAdvance
        var sim = duel(catalogue: catalogue)
        sim.give(me, [.food: 300])
        let centre = sim.townCentre(me)
        let held = sim.resources(me)
        #expect(sim.apply(.advanceAge(at: centre), from: me) == .accepted)
        #expect(sim.resources(me) == held - catalogue.advances[0].cost)
        // One advance at a time.
        #expect(sim.apply(.advanceAge(at: centre), from: me) == .refused(.notNow))
        sim.run(100)
        #expect(abs(sim.view(for: me).ageProgress - 100.0 / 400) < 1e-9)
        #expect(sim.view(for: me).entity(centre)?.activity == .advancing(100.0 / 400))
        #expect(sim.players[0].age == .towns)
        sim.run(300)
        let view = sim.view(for: me)
        #expect(view.age == .farms)
        #expect(view.ageProgress == 0)
        #expect(view.events.contains(.ageReached(.farms)))
        // Workers take the new age's look at once.
        let worker = view.entities.first { $0.kind == .unit(.worker) && $0.owner == me }!
        #expect(SpriteSubject.of(worker, ownerAge: view.age) == .unit(.worker, .bronze))
    }

    @Test func theAdvanceNeedsACompleteTownCentreAndTheCost() {
        var sim = duel(catalogue: Self.quickAdvance)
        sim.players[0].resources = ResourceAmounts([.food: 100])
        let centre = sim.townCentre(me)
        #expect(sim.apply(.advanceAge(at: centre), from: me) == .refused(.notEnough(ResourceAmounts([.food: 200, .wood: 100]))))
        let house = sim.add(.house, me, 8, 2)
        #expect(sim.apply(.advanceAge(at: house), from: me) == .refused(.invalidTarget))
        let unfinished = sim.add(.townCentre, me, 12, 2, complete: false)
        sim.give(me, [.food: 1000, .wood: 1000])
        #expect(sim.apply(.advanceAge(at: unfinished), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.advanceAge(at: sim.townCentre(them)), from: me) == .refused(.notYours))
        #expect(sim.players[0].age == .towns)
    }

    @Test func everyAgeLeadsToTheNextAndTheLastToNone() {
        var sim = duel()
        sim.give(me, [.food: 10_000, .wood: 10_000, .gold: 10_000])
        let centre = sim.townCentre(me)
        for age in Age.allCases.dropLast() {
            #expect(sim.players[0].age == age)
            #expect(sim.apply(.advanceAge(at: centre), from: me) == .accepted)
            sim.run(Catalogue.standard.advance(from: age)!.time)
        }
        #expect(sim.players[0].age == .hospitals)
        #expect(sim.apply(.advanceAge(at: centre), from: me) == .refused(.invalidTarget))
    }

    @Test func pullingDownATownCentreRefundsTheAdvanceUnderWay() {
        var sim = duel(catalogue: Self.quickAdvance)
        sim.give(me, [.food: 300])
        let centre = sim.townCentre(me)
        let held = sim.resources(me)
        #expect(sim.apply(.advanceAge(at: centre), from: me) == .accepted)
        let c = sim.index(of: centre)!
        sim.entities[c].demolished = Simulation.demolitionTime(Catalogue.standard.stats(.townCentre).buildTime) - 1
        let worker = sim.people(me, .worker)[0]
        #expect(sim.apply(.demolish(workers: [worker], building: centre), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.entity(centre) == nil }, limit: 200); #expect(reached) }
        #expect(sim.resources(me) == held + Catalogue.standard.stats(.townCentre).cost.halved)
        #expect(sim.players[0].age == .towns)
    }
}
