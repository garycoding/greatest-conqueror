// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

@Suite struct IndustrialAge {
    @Test func theAlchemyAgeLeadsToTheIndustrialAgeAndNoFurther() {
        var sim = duel()
        sim.players[0].age = .alchemy
        let advance = Catalogue.standard.advance(from: .alchemy)!
        sim.players[0].study = advance.study
        sim.give(me, [.food: 2000, .iron: 1000, .gold: 1000, .gunpowder: 1000])
        #expect(sim.apply(.advanceAge, from: me) == .accepted)
        #expect(sim.players[0].age == .industrial)
        #expect(Catalogue.standard.lastAge == .industrial)
        #expect(sim.apply(.advanceAge, from: me) != .accepted)
        #expect(UnitKind.worker.stageName(at: .industrial) == "Factory hand")
        #expect(UnitKind.merchant.stageName(at: .industrial) == "Industrialist")
    }

    @Test func anOilWellStandsOnlyOnAnOilFieldAndNothingElseDoes() {
        var sim = duel(sites: [(.oilField, 10, 10)])
        sim.exploreAll(me)
        sim.players[0].age = .industrial
        sim.give(me, [.wood: 1000, .iron: 1000, .stone: 1000])
        let engineer = sim.add(.engineer, me, 8.5, 8.5)
        func build(_ kind: BuildingKind, _ x: Int, _ y: Int) -> OrderResult {
            sim.apply(.construct(engineers: [engineer], building: kind, at: GridPoint(x, y)), from: me)
        }
        #expect(build(.oilWell, 14, 14) == .refused(.placementBlocked))   // no oil there
        #expect(build(.house, 10, 10) == .refused(.placementBlocked))     // a house over the field
        #expect(build(.oilWell, 9, 9) == .accepted)                       // the field under its footprint
    }

    @Test func anOilWellPumpsWithoutWorkersUntilTheFieldRunsDry() {
        var sim = duel(sites: [(.oilField, 10, 10)])
        sim.players[0].age = .industrial
        let well = sim.add(.oilWell, me, 10, 10)
        let perSecond = Catalogue.standard.oilWell!.perSecond
        sim.run(60 * Tick.rate)
        #expect(abs(Double(sim.resources(me)[.oil]) - 60 * perSecond) <= 1)
        #expect(sim.view(for: me).entity(well)?.remaining == Catalogue.standard.gathering.amount(.oilField) - sim.resources(me)[.oil])
        // Refining pumps more.
        sim.players[0].improvements.append(.refining)
        let before = sim.resources(me)[.oil]
        sim.run(60 * Tick.rate)
        #expect(abs(Double(sim.resources(me)[.oil] - before) - 60 * perSecond * 1.5) <= 1)
        // Once the field is empty, the well stops.
        sim.sites[0].remaining = 3
        sim.run(30 * Tick.rate)
        let dry = sim.resources(me)[.oil]
        sim.run(30 * Tick.rate)
        #expect(sim.resources(me)[.oil] == dry)
        #expect(sim.view(for: me).entity(well)?.remaining == 0)
    }

    @Test func peopleTakeTheTrainBetweenTheirDepotsWhenItIsQuicker() {
        func journey(depots: Bool) -> Int {
            var sim = duel()
            sim.players[0].age = .industrial
            if depots {
                sim.add(.railwayDepot, me, 4, 8)
                sim.add(.railwayDepot, me, 32, 22)
            }
            let rifleman = sim.add(.rifleman, me, 6.5, 12.5)
            let goal = MapPosition(x: 33.5, y: 26.5)
            #expect(sim.apply(.move(units: [rifleman], to: goal), from: me) == .accepted)
            var ticks = 0
            while ticks < 120 * Tick.rate && sim.living(rifleman).position.distance(to: goal) > 1.5 {
                sim.step(); ticks += 1
            }
            return ticks
        }
        let walking = journey(depots: false), riding = journey(depots: true)
        #expect(riding < walking * 3 / 5, "riding \(riding) ticks, walking \(walking)")
        #expect(riding >= Catalogue.standard.railway!.journeyTime)
    }

    @Test func aNewOrderEndsAJourneyAndAPersonsSightComesOutWithThem() {
        var sim = duel()
        sim.players[0].age = .industrial
        sim.add(.railwayDepot, me, 4, 8)
        sim.add(.railwayDepot, me, 32, 22)
        let rifleman = sim.add(.rifleman, me, 6.5, 12.5)
        #expect(sim.apply(.move(units: [rifleman], to: MapPosition(x: 33.5, y: 26.5)), from: me) == .accepted)
        sim.step()
        #expect(sim.living(rifleman).rail != nil)
        // An order to attack close by forgets the journey, as does a stop.
        let clubman = sim.add(.clubman, them, 8.5, 12.5)
        #expect(sim.apply(.attack(units: [rifleman], target: clubman), from: me) == .accepted)
        #expect(sim.living(rifleman).rail == nil)
        #expect(sim.apply(.stop(units: [rifleman]), from: me) == .accepted)
        // Ridden to the far depot, the person's sight goes with them.
        #expect(sim.apply(.move(units: [rifleman], to: MapPosition(x: 33.5, y: 26.5)), from: me) == .accepted)
        let out = sim.run(until: { $0.living(rifleman).position.x > 25 }, limit: 60 * Tick.rate)
        #expect(out)
        #expect(sim.living(rifleman).stamp == sim.living(rifleman).position.tile)
    }

    @Test func aSecondWellCannotBeOfferedOverAFieldThatHasOne() {
        var sim = duel(sites: [(.oilField, 10, 10)])
        sim.exploreAll(me)
        sim.players[0].age = .industrial
        sim.add(.oilWell, me, 10, 10)
        let view = sim.view(for: me)
        #expect(!Placement.canPlace(.oilWell, at: GridPoint(9, 9), in: view))
        #expect(!Placement.canPlace(.oilWell, at: GridPoint(11, 11), in: view))
    }

    @Test func aShortWalkDoesNotTakeTheTrain() {
        var sim = duel()
        sim.players[0].age = .industrial
        sim.add(.railwayDepot, me, 4, 8)
        sim.add(.railwayDepot, me, 32, 22)
        let rifleman = sim.add(.rifleman, me, 6.5, 12.5)
        #expect(sim.apply(.move(units: [rifleman], to: MapPosition(x: 9.5, y: 14.5)), from: me) == .accepted)
        sim.step()
        #expect(sim.living(rifleman).rail == nil)
    }

    @Test func aMerchantCarryingToAnAllyRidesToTheAllysDepot() {
        var sim = Simulation(setup: setup(openMap(starts: [GridPoint(2, 2), GridPoint(34, 34), GridPoint(2, 34)]),
                                          teams: [0, 1, 0]))
        let ally = PlayerID(2)
        sim.players[0].age = .industrial
        sim.add(.railwayDepot, me, 6, 2)
        let theirs = sim.add(.railwayDepot, ally, 6, 30)
        let merchant = sim.add(.merchant, me, 7.5, 6.5)
        sim.step()
        let i = sim.index(of: merchant)!
        let trip = sim.railTrip(i, .tiles(GridPoint(2, 34), GridPoint(3, 3), reach: 1))
        #expect(trip?.alight == theirs)
        // Not so for a warfighter: an ally's depot is not its own.
        let rifleman = sim.add(.rifleman, me, 7.5, 6.5)
        #expect(sim.railTrip(sim.index(of: rifleman)!, .tiles(GridPoint(2, 34), GridPoint(3, 3), reach: 1)) == nil)
    }

    @Test func theIndustrialCountersUpgradesAndImprovements() {
        #expect(Catalogue.standard.bonus(.rifleman, against: .knight) == 2)
        #expect(Catalogue.standard.bonus(.fieldGun, against: .armouredCar) == 2)
        #expect(Catalogue.standard.bonus(.armouredCar, against: .rifleman) == 2)
        #expect(Catalogue.standard.upgrade(from: .musketeer)?.to == .rifleman)
        #expect(Catalogue.standard.upgrade(from: .cannon)?.to == .fieldGun)
        #expect(Catalogue.standard.upgrade(from: .knight)?.to == .armouredCar)
        #expect(Set(Catalogue.standard.stats(.factory).trains) == [.fieldGun, .armouredCar])
        #expect(Catalogue.standard.stats(.factory).researches == [.rifling, .steelPlate, .refining])
        #expect(Catalogue.standard.stats(.townCentre).researches.contains(.machineTools))
    }
}
