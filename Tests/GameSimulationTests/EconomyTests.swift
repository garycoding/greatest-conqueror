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
        sim.add(.storagePit, me, 10, 5)
        let worker = sim.people(me, .worker)[0]
        let wood = sim.resources(me)[.wood]
        #expect(sim.apply(.gather(units: [worker], site: SiteID(0)), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(worker).doing == .carrying }, limit: 1_500); #expect(reached) }
        let carrying = sim.view(for: me).entity(worker)?.activity
        #expect(carrying == .carrying(.wood, load))
        do { let reached = sim.run(until: { $0.resources(me)[.wood] > wood }, limit: 500); #expect(reached) }
        #expect(sim.resources(me)[.wood] == wood + load)
        // Delivered beside the storage pit, which is nearer than the town centre.
        let pit = Goal.tiles(GridPoint(10, 5), GridPoint(2, 2), reach: 0)
        #expect(pit.distance(to: sim.living(worker).position) <= Rule.besideReach)
        #expect(sim.sites[0].remaining == Catalogue.standard.gathering.amount(.tree) - load)
        // And it goes back for more.
        do { let reached = sim.run(until: { $0.living(worker).doing == .gathering }, limit: 300); #expect(reached) }
    }

    @Test(arguments: [SiteKind.prey, .stone, .gold])
    func workersHuntQuarryAndMine(_ kind: SiteKind) {
        var sim = duel(sites: [(kind, 9, 3)])
        sim.exploreAll(me)
        sim.players[0].age = .bronze
        let worker = sim.people(me, .worker)[0]
        let before = sim.resources(me)[kind.yield]
        #expect(sim.apply(.gather(units: [worker], site: SiteID(0)), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.resources(me)[kind.yield] > before }, limit: 2_000); #expect(reached) }
        #expect(sim.resources(me)[kind.yield] == before + load)
    }

    @Test func copperAndTinMinedTogetherMakeBronze() {
        var sim = duel(sites: [(.copper, 8, 6), (.tin, 9, 8)])
        sim.exploreAll(me)
        sim.players[0].age = .bronze
        let workers = sim.people(me, .worker)
        #expect(sim.apply(.gather(units: [workers[0]], site: SiteID(0)), from: me) == .accepted)
        #expect(sim.apply(.gather(units: [workers[1]], site: SiteID(1)), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.resources(me)[.bronze] > 0 }, limit: 2_000); #expect(reached) }
        #expect(sim.resources(me)[.bronze] == load)
        #expect(sim.view(for: me).resources[.bronze] == load)
    }

    @Test func copperAndTinPairOnDeliveryAndUnpairedOreIsHeldUpToOneLoad() {
        var sim = duel()
        let worker = sim.people(me, .worker)[0]
        let i = sim.index(of: worker)!
        func deliver(_ kind: SiteKind, _ amount: Int) {
            sim.entities[i].cargo = Cargo(kind: kind, amount: amount)
            sim.deliver(i)
        }
        deliver(.copper, load)
        #expect(sim.resources(me)[.bronze] == 0 && sim.players[0].copperOre == load)
        deliver(.copper, load)
        #expect(sim.players[0].copperOre == load)   // the second load is lost
        deliver(.tin, 6)
        #expect(sim.resources(me)[.bronze] == 6)
        #expect(sim.players[0].copperOre == load - 6 && sim.players[0].tinOre == 0)
        deliver(.tin, load)
        #expect(sim.resources(me)[.bronze] == load)
        #expect(sim.players[0].copperOre == 0 && sim.players[0].tinOre == 6)
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

    @Test func herdingAtAStockPenEarnsFood() {
        var sim = duel()
        sim.players[0].age = .bronze
        let pen = sim.add(.stockPen, me, 8, 8)
        let worker = sim.people(me, .worker)[0]
        #expect(sim.apply(.work(units: [worker], at: pen), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(worker).doing == .working }, limit: 300); #expect(reached) }
        let food = sim.resources(me)[.food]
        sim.run(10 * Tick.rate)
        let earned = Double(sim.resources(me)[.food] - food)
        #expect(abs(earned - 10 * Catalogue.standard.gathering.herdingPerSecond) <= 1)
        #expect(sim.view(for: me).entity(worker)?.activity == .working)
    }

    /// Ticks a worker spends at a tree filling one load.
    static func ticksToFillALoad(betterTools: Bool) -> Int {
        var sim = duel(sites: [(.tree, 8, 3)])
        sim.exploreAll(me)
        if betterTools { sim.players[0].improvements = [.betterTools] }
        let worker = sim.people(me, .worker)[0]
        _ = sim.apply(.gather(units: [worker], site: SiteID(0)), from: me)
        var ticks = 0
        while (sim.living(worker).cargo?.amount ?? 0) < load && ticks < 2_000 {
            sim.step()
            if sim.living(worker).doing == .gathering { ticks += 1 }
        }
        return ticks
    }

    @Test func betterToolsRaisesGatheringByAFifth() {
        let plain = Self.ticksToFillALoad(betterTools: false)
        let improved = Self.ticksToFillALoad(betterTools: true)
        let expected = Double(load) / (Catalogue.standard.gathering.perSecond(.tree) / Double(Tick.rate))
        #expect(abs(Double(plain) - expected) <= 1)
        #expect(abs(Double(plain) / Double(improved) - Catalogue.standard.stats(.betterTools).gatheringMultiplier) < 0.01)
    }

    @Test func depositsCannotBeMinedBeforeTheirAge() {
        var sim = duel(sites: [(.copper, 8, 6)])
        sim.exploreAll(me)
        let worker = sim.people(me, .worker)[0]
        #expect(sim.apply(.gather(units: [worker], site: SiteID(0)), from: me) == .refused(.ageNotReached(.bronze)))
        let scholar = sim.add(.scholar, me, 6.5, 6.5)
        #expect(sim.apply(.gather(units: [scholar], site: SiteID(0)), from: me) == .refused(.notYours))
    }
}

@Suite struct Construction {
    @Test func engineersConstructAndTheCostIsPaidWhenOrdered() {
        var sim = duel()
        let engineer = sim.add(.engineer, me, 6.5, 6.5)
        let wood = sim.resources(me)[.wood]
        #expect(sim.apply(.construct(engineers: [engineer], building: .house, at: GridPoint(8, 2)), from: me) == .accepted)
        #expect(sim.resources(me)[.wood] == wood - Catalogue.standard.stats(.house).cost[.wood])
        let house = sim.buildings(me, .house)[0]
        #expect(sim.view(for: me).entity(house)?.activity == .underConstruction(0))
        do { let reached = sim.run(until: { $0.living(house).complete }, limit: 1_000); #expect(reached) }
        let view = sim.view(for: me)
        #expect(view.events.contains(.constructed(house, .house)))
        #expect(view.populationLimit == 10)
        sim.step()
        #expect(sim.living(engineer).task == .idle)
    }

    @Test func anEngineerGoesOnToTheNextBuildingUnderConstructionNearby() {
        var sim = duel()
        let engineer = sim.add(.engineer, me, 6.5, 6.5)
        #expect(sim.apply(.construct(engineers: [engineer], building: .house, at: GridPoint(8, 2)), from: me) == .accepted)
        let first = sim.buildings(me, .house)[0]
        let second = sim.add(.house, me, 11, 2, complete: false)
        let far = sim.add(.house, me, 30, 30, complete: false)
        do { let reached = sim.run(until: { $0.living(first).complete }, limit: 1_000); #expect(reached) }
        sim.step()
        #expect(sim.living(engineer).task == .work(second))
        do { let reached = sim.run(until: { $0.living(second).complete }, limit: 2_000); #expect(reached) }
        sim.step()
        // The far house is beyond the radius: the engineer stands idle.
        #expect(sim.living(engineer).task == .idle)
        #expect(!sim.living(far).complete)
    }

    @Test func aPersonsJobIsShownToItsPlayerOnly() {
        var sim = duel(sites: [(.tree, 8, 6)])
        sim.exploreAll(me)
        let worker = sim.people(me, .worker)[0], engineer = sim.add(.engineer, me, 6.5, 6.5)
        #expect(sim.apply(.gather(units: [worker], site: SiteID(0)), from: me) == .accepted)
        #expect(sim.apply(.construct(engineers: [engineer], building: .house, at: GridPoint(11, 2)), from: me) == .accepted)
        sim.step()
        var view = sim.view(for: me)
        #expect(view.entity(worker)?.job == .gathering(.tree))
        #expect(view.entity(engineer)?.job == .constructing)
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
        let engineer = sim.add(.engineer, me, 6.5, 6.5)
        let held = sim.resources(me)
        func build(_ kind: BuildingKind, _ x: Int, _ y: Int) -> OrderResult {
            sim.apply(.construct(engineers: [engineer], building: kind, at: GridPoint(x, y)), from: me)
        }
        #expect(build(.house, 7, 5) == .refused(.placementBlocked))     // over a tree
        #expect(build(.house, 3, 3) == .refused(.placementBlocked))     // over the town centre
        #expect(build(.house, 11, 7) == .refused(.placementBlocked))    // over water
        #expect(build(.house, 39, 20) == .refused(.placementBlocked))   // off the map
        #expect(build(.house, 25, 25) == .refused(.placementBlocked))   // unexplored
        #expect(build(.barracks, 8, 2) == .refused(.ageNotReached(.bronze)))
        let worker = sim.people(me, .worker)[0]
        #expect(sim.apply(.construct(engineers: [worker], building: .house, at: GridPoint(8, 2)), from: me) == .refused(.notYours))
        sim.players[0].resources[.wood] = 10
        #expect(build(.house, 8, 2) == .refused(.notEnough(ResourceAmounts([.wood: 20]))))
        sim.players[0].resources = held
        #expect(sim.resources(me) == held)
        #expect(sim.buildings(me, .house).isEmpty)
    }

    /// Ticks from the first engineer-tick to completion of a house.
    static func ticksToBuild(engineers count: Int) -> Int {
        var sim = duel()
        let engineers = (0..<count).map { _ in sim.add(.engineer, me, 6.5, 6.5) }
        _ = sim.apply(.construct(engineers: engineers, building: .house, at: GridPoint(8, 2)), from: me)
        let house = sim.buildings(me, .house)[0]
        sim.run(until: { $0.living(house).built > 0 }, limit: 500)
        let start = sim.tick
        sim.run(until: { $0.living(house).complete }, limit: 1_000)
        return sim.tick - start
    }

    @Test func moreEngineersFinishSooner() {
        let buildTime = Catalogue.standard.stats(.house).buildTime
        #expect(abs(Self.ticksToBuild(engineers: 1) - buildTime) <= 1)
        #expect(abs(Self.ticksToBuild(engineers: 2) - buildTime / 2) <= 1)
    }

    @Test func engineersRepairADamagedBuilding() {
        var sim = duel()
        let house = sim.add(.house, me, 8, 2)
        let i = sim.index(of: house)!
        sim.entities[i].health = 50
        let engineer = sim.add(.engineer, me, 6.5, 6.5)
        #expect(sim.apply(.work(units: [engineer], at: house), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(engineer).doing == .working }, limit: 200); #expect(reached) }
        let start = sim.living(house).health
        sim.run(100)
        // At full health per buildTime engineer-ticks.
        let stats = Catalogue.standard.stats(.house)
        #expect(sim.living(house).health - start == 100 * stats.health / stats.buildTime)
        do { let reached = sim.run(until: { $0.living(house).health == stats.health }, limit: 1_000); #expect(reached) }
        sim.step()
        #expect(sim.living(engineer).task == .idle)
        #expect(sim.apply(.work(units: [engineer], at: house), from: me) == .refused(.invalidTarget))
    }
}

@Suite struct Demolition {
    @Test func engineersPullDownAHouseOverHalfItsTimeForHalfItsCost() {
        var sim = duel()
        let house = sim.add(.house, me, 8, 2)
        let limit = sim.view(for: me).populationLimit
        let engineer = sim.add(.engineer, me, 6.5, 6.5)
        let before = sim.resources(me)
        #expect(sim.apply(.demolish(engineers: [engineer], building: house), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.living(engineer).doing == .constructing }, limit: 200); #expect(reached) }
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
        #expect(sim.living(engineer).task == .idle)
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
        let engineer = sim.add(.engineer, me, 6.5, 6.5)
        #expect(sim.apply(.demolish(engineers: [engineer], building: centre), from: me) == .accepted)
        do { let reached = sim.run(until: { $0.entity(centre) == nil }, limit: 200); #expect(reached) }
        #expect(sim.people(me, .worker).count == sim.view(for: me).entities.filter { $0.kind == .unit(.worker) }.count)
        let back = Catalogue.standard.stats(.townCentre).cost.halved + Catalogue.standard.stats(.worker).cost
        #expect(sim.resources(me) == afterPaying + back)
    }

    @Test func onlyEngineersDemolishAndOnlyTheirOwnBuildings() {
        var sim = duel()
        let worker = sim.add(.worker, me, 6.5, 6.5)
        let engineer = sim.add(.engineer, me, 7.5, 6.5)
        #expect(sim.apply(.demolish(engineers: [worker], building: sim.townCentre(me)), from: me) == .refused(.notYours))
        #expect(sim.apply(.demolish(engineers: [engineer], building: sim.townCentre(them)), from: me) == .refused(.invalidTarget))
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
        do { let reached = sim.run(until: { $0.people(me, .worker).count == 3 }, limit: 400); #expect(reached) }
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
        _ = sim.apply(.train(at: centre, unit: .engineer), from: me)
        #expect(sim.living(centre).queue == [.worker, .engineer])
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
        #expect(sim.apply(.train(at: centre, unit: .merchant), from: me) == .refused(.ageNotReached(.bronze)))
        #expect(sim.apply(.train(at: centre, unit: .spearman), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.train(at: centre, unit: .founder), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.train(at: sim.townCentre(them), unit: .worker), from: me) == .refused(.notYours))
        sim.players[0].resources = ResourceAmounts()
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .refused(.notEnough(ResourceAmounts([.food: 50]))))
    }
}

@Suite struct Scholars {
    /// A catalogue whose advance needs 400 scholar-ticks of study.
    static var quickStudy: Catalogue {
        var c = Catalogue.standard
        c.advances[0].study = 400
        return c
    }

    @Test func scholarsAtATownCentreStudyOnePointEachPerTick() {
        var sim = duel(catalogue: Self.quickStudy)
        let scholars = [sim.add(.scholar, me, 6.5, 6.5), sim.add(.scholar, me, 6.5, 6.5)]
        let centre = sim.townCentre(me)
        #expect(sim.apply(.work(units: scholars, at: centre), from: me) == .accepted)
        do { let reached = sim.run(until: { s in scholars.allSatisfy { s.living($0).doing == .working } }, limit: 200); #expect(reached) }
        let study = sim.players[0].study
        sim.run(50)
        #expect(sim.players[0].study == study + 100)
        #expect(abs(sim.view(for: me).ageProgress - Double(study + 100) / 400) < 1e-9)
    }

    @Test func advancingNeedsCompleteStudyAndPaysTheCost() {
        let catalogue = Self.quickStudy
        var sim = duel(catalogue: catalogue)
        sim.give(me, [.food: 300])
        let scholars = [sim.add(.scholar, me, 6.5, 6.5), sim.add(.scholar, me, 6.5, 6.5)]
        _ = sim.apply(.work(units: scholars, at: sim.townCentre(me)), from: me)
        #expect(sim.apply(.advanceAge, from: me) == .refused(.studyIncomplete))
        do { let reached = sim.run(until: { $0.players[0].study >= 400 }, limit: 600); #expect(reached) }
        let held = sim.resources(me)
        #expect(sim.apply(.advanceAge, from: me) == .accepted)
        #expect(sim.resources(me) == held - catalogue.advances[0].cost)
        let view = sim.view(for: me)
        #expect(view.age == .bronze)
        #expect(view.events.contains(.ageReached(.bronze)))
        // Peaceful people take the new age's stage at once.
        let worker = view.entities.first { $0.kind == .unit(.worker) && $0.owner == me }!
        #expect(SpriteSubject.of(worker, ownerAge: view.age) == .unit(.worker, .bronze))
        #expect(UnitKind.worker.stageName(at: view.age) == "Herder")
        // The Iron age is next, and its study starts again from nothing.
        #expect(sim.apply(.advanceAge, from: me) == .refused(.studyIncomplete))
    }

    @Test func advancingIsRefusedWithoutTheCost() {
        var sim = duel(catalogue: Self.quickStudy)
        sim.players[0].study = 400
        sim.players[0].resources = ResourceAmounts([.food: 100])
        #expect(sim.apply(.advanceAge, from: me) == .refused(.notEnough(ResourceAmounts([.food: 200, .wood: 100]))))
        #expect(sim.players[0].age == .stone)
    }
}

@Suite struct Research {
    @Test func researchIsPaidWhenOrderedAndScholarsWorkingThereCompleteIt() {
        var sim = duel()
        let centre = sim.townCentre(me)
        let held = sim.resources(me)
        #expect(sim.apply(.research(at: centre, improvement: .betterTools), from: me) == .accepted)
        let stats = Catalogue.standard.stats(.betterTools)
        #expect(sim.resources(me) == held - stats.cost)
        #expect(sim.view(for: me).entity(centre)?.activity == .researching(.betterTools, 0))
        let scholars = [sim.add(.scholar, me, 6.5, 6.5), sim.add(.scholar, me, 6.5, 6.5)]
        _ = sim.apply(.work(units: scholars, at: centre), from: me)
        do { let reached = sim.run(until: { $0.players[0].has(.betterTools) }, limit: 1_000); #expect(reached) }
        // Scholars at a town centre research what is under way there rather than study.
        #expect(sim.players[0].study == 0)
        #expect(sim.view(for: me).events.contains(.researched(.betterTools)))
        #expect(sim.view(for: me).improvements == [.betterTools])
        #expect(sim.apply(.research(at: centre, improvement: .betterTools), from: me) == .refused(.invalidTarget))
        sim.run(1)
        #expect(sim.players[0].study == 2)
    }

    @Test func researchNeedsABuildingThatResearchesItAndTheAge() {
        var sim = duel()
        sim.give(me, [.bronze: 200])
        let centre = sim.townCentre(me)
        #expect(sim.apply(.research(at: centre, improvement: .shields), from: me) == .refused(.invalidTarget))
        let barracks = sim.add(.barracks, me, 8, 8)
        #expect(sim.apply(.research(at: barracks, improvement: .shields), from: me) == .refused(.ageNotReached(.bronze)))
        sim.players[0].age = .bronze
        #expect(sim.apply(.research(at: barracks, improvement: .shields), from: me) == .accepted)
        #expect(sim.apply(.research(at: barracks, improvement: .bronzeWeapons), from: me) == .refused(.invalidTarget))
    }
}

@Suite struct Upgrades {
    @Test func warfightersPaidForBecomeTheNewKind() {
        var sim = duel()
        sim.players[0].age = .bronze
        sim.give(me, [.bronze: 100])
        let barracks = sim.add(.barracks, me, 8, 8)
        let clubmen = [sim.add(.clubman, me, 14.5, 4.5), sim.add(.clubman, me, 15.5, 4.5)]
        sim.entities[sim.index(of: clubmen[0])!].health = 20
        let held = sim.resources(me)
        #expect(sim.apply(.upgrade(units: clubmen, to: .spearman, at: barracks), from: me) == .accepted)
        let upgrade = Catalogue.standard.upgrade(from: .clubman)!
        #expect(sim.resources(me) == held - upgrade.cost - upgrade.cost)
        sim.run(upgrade.time)
        let spearman = Catalogue.standard.stats(.spearman)
        #expect(clubmen.allSatisfy { sim.living($0).unitKind == .spearman })
        #expect(sim.living(clubmen[0]).health == 20 * spearman.health / Catalogue.standard.stats(.clubman).health)
        #expect(sim.living(clubmen[1]).health == spearman.health)
        #expect(sim.living(clubmen[1]).sight == spearman.sight)
    }

    @Test func upgradesAreRefusedWithoutTheAgeTheBuildingOrAKindThatUpgrades() {
        var sim = duel()
        sim.give(me, [.bronze: 100])
        let barracks = sim.add(.barracks, me, 8, 8)
        let clubman = sim.add(.clubman, me, 14.5, 4.5)
        let slinger = sim.add(.slinger, me, 15.5, 4.5)
        #expect(sim.apply(.upgrade(units: [clubman], to: .spearman, at: barracks), from: me) == .refused(.ageNotReached(.bronze)))
        sim.players[0].age = .bronze
        #expect(sim.apply(.upgrade(units: [clubman], to: .spearman, at: sim.townCentre(me)), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.upgrade(units: [slinger], to: .spearman, at: barracks), from: me) == .refused(.notYours))
        sim.players[0].resources = ResourceAmounts()
        #expect(sim.apply(.upgrade(units: [clubman], to: .spearman, at: barracks), from: me)
            == .refused(.notEnough(Catalogue.standard.upgrade(from: .clubman)!.cost)))
    }
}
