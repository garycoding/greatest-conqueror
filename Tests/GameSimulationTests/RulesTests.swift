// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

// The rules of step 5: repair, healing, the age upgrades, the navy ship, units
// and defeat, and the founder (docs/requirements.md, requirements 12, 13, 16,
// 18, 19 and 24, and the rulings of 2026-11-22).

/// A lake from (10, 10) to (19, 19), its shore on every side.
private let lake = (10...19).flatMap { y in (10...19).map { GridPoint($0, y) } }

extension Simulation {
    /// Wound an entity to a health.
    mutating func wound(_ id: EntityID, to health: Int) { entities[index(of: id)!].health = health }
}

@Suite struct Repair {
    @Test func repairAddsUpAcrossWorkersAtTheTablesRate() {
        func repaired(by workers: Int) -> Int {
            var sim = duel()
            _ = sim.apply(.dismiss(units: sim.people(me, .worker)), from: me)
            let house = sim.add(.house, me, 8, 2)
            sim.wound(house, to: 20)
            let crew = (0..<workers).map { sim.add(.worker, me, 7.5, 2.5 + Double($0) * 0.5) }
            #expect(sim.apply(.work(units: crew, at: house), from: me) == .accepted)
            sim.run(until: { s in crew.allSatisfy { s.living($0).doing == .working } }, limit: 200)
            let start = sim.living(house).health
            sim.run(4 * Tick.rate)
            return sim.living(house).health - start
        }
        let rate = Catalogue.standard.stats(.worker).repairing!
        #expect(abs(Double(repaired(by: 1)) - 4 * rate) <= 1)
        #expect(abs(Double(repaired(by: 2)) - 8 * rate) <= 2)
    }

    @Test func anIdleWorkerRepairsADamagedBuildingWithinItsRadiusAndNotBeyond() {
        var sim = duel()
        _ = sim.apply(.dismiss(units: sim.people(me, .worker)), from: me)
        let radius = Catalogue.standard.stats(.worker).radius!
        let near = sim.add(.house, me, 10, 10)
        let far = sim.add(.house, me, 10, 10 + Int(radius) + 6)
        sim.wound(near, to: 100)
        sim.wound(far, to: 100)
        let worker = sim.add(.worker, me, 9.5, 13.5)
        let repaired = sim.run(until: { $0.living(near).health == $0.living(near).maxHealth }, limit: 60 * Tick.rate)
        #expect(repaired)
        #expect(sim.living(far).health == 100)
        #expect(sim.view(for: me).entity(worker)?.job != nil)
    }

    @Test func aBuildingUnderConstructionIsNotRepairedByTheIdle() {
        var sim = duel()
        let site = sim.add(.house, me, 10, 10, complete: false)
        _ = sim.add(.worker, me, 9.5, 12.5)
        sim.run(5 * Tick.rate)
        #expect(sim.living(site).built == 0)
    }
}

@Suite struct Healing {
    private func hospitalAge() -> Simulation {
        var sim = duel()
        sim.players[0].age = .hospitals
        return sim
    }

    @Test func doctorsHealAtTheTablesRateAndMoreHealFaster() {
        func healed(by doctors: Int) -> Int {
            var sim = hospitalAge()
            let soldier = sim.add(.soldier1, me, 12.5, 12.5)
            sim.wound(soldier, to: 5)
            let team = (0..<doctors).map { sim.add(.doctor, me, 12.5, 13.0 + Double($0) * 0.3) }
            #expect(sim.apply(.heal(doctors: team, target: soldier), from: me) == .accepted)
            sim.run(until: { s in team.allSatisfy { s.living($0).doing == .working } }, limit: 200)
            let start = sim.living(soldier).health
            sim.run(4 * Tick.rate)
            return sim.living(soldier).health - start
        }
        let rate = Catalogue.standard.stats(.doctor).healing!
        #expect(abs(Double(healed(by: 1)) - 4 * rate) <= 1)
        #expect(abs(Double(healed(by: 2)) - 8 * rate) <= 2)
    }

    @Test func anIdleDoctorHealsAWoundedUnitOfItsPlayerWithinItsRadiusToItsMaximum() {
        var sim = hospitalAge()
        let radius = Catalogue.standard.stats(.doctor).radius!
        let near = sim.add(.soldier1, me, 12.5, 12.5)
        let far = sim.add(.soldier1, me, 12.5, 12.5 + radius + 6)
        let theirs = sim.add(.soldier1, them, 13.5, 12.5)
        sim.wound(near, to: 10)
        sim.wound(far, to: 10)
        sim.wound(theirs, to: 10)
        sim.players[1].age = .farms
        _ = sim.add(.doctor, me, 12.5, 14.5)
        let healed = sim.run(until: { $0.living(near).health == $0.living(near).maxHealth }, limit: 60 * Tick.rate)
        #expect(healed)
        #expect(sim.living(far).health == 10)
    }

    @Test func doctorsDoNotAttackAndDoNotHealBuildings() {
        var sim = hospitalAge()
        let doctor = sim.add(.doctor, me, 12.5, 12.5)
        let enemy = sim.add(.soldier1, them, 13.5, 12.5)
        sim.exploreAll(me)
        sim.run(1)
        #expect(sim.apply(.attack(units: [doctor], target: enemy), from: me) == .refused(.notYours))
        let house = sim.add(.house, me, 15, 15)
        sim.wound(house, to: 50)
        #expect(sim.apply(.heal(doctors: [doctor], target: house), from: me) == .refused(.invalidTarget))
    }
}

@Suite struct Upgrades {
    @Test func towersKeepTheirShareOfHealthAndTakeTheNewAgesRow() {
        var sim = duel()
        sim.players[0].age = .farms
        let tower = sim.add(.tower, me, 10, 10)
        sim.wound(tower, to: 200)
        let stats = Catalogue.standard.stats(.tower)
        sim.players[0].age = .ships
        sim.upgrade(player: 0)
        let ships = stats.figures(at: .ships)
        #expect(sim.living(tower).maxHealth == ships.health)
        #expect(sim.living(tower).health == (200 * ships.health + 200) / 400)
        #expect(sim.attack(of: sim.index(of: tower)!) == ships.attack)
        // One built after the age is reached begins with the age's figures.
        let later = sim.add(.tower, me, 14, 10)
        #expect(sim.living(later).maxHealth == ships.health && sim.living(later).health == ships.health)
    }

    @Test func reachingAnAgeUpgradesTheNavyShipsOfThatPlayerOnly() {
        var sim = duel(water: lake)
        sim.players[0].age = .ships
        sim.players[1].age = .ships
        let mine = sim.add(.navyShip, me, 14.5, 14.5)
        let theirs = sim.add(.navyShip, them, 16.5, 16.5)
        sim.players[0].resources = sim.players[0].resources + Catalogue.standard.advance(from: .ships)!.cost
        #expect(sim.apply(.advanceAge(at: sim.townCentre(me)), from: me) == .accepted)
        sim.run(Catalogue.standard.advance(from: .ships)!.time + 1)
        let cannons = Catalogue.standard.stats(.navyShip).figures(at: .cannons)
        #expect(sim.players[0].age == .cannons)
        #expect(sim.living(mine).maxHealth == cannons.health)
        #expect(sim.living(theirs).maxHealth == Catalogue.standard.stats(.navyShip).health)
    }
}

@Suite struct NavyShips {
    /// A ship of player 0's at the lake's western shore, and troops on the land beside it.
    private func harbour(troops: Int, age: Age = .ships) -> (Simulation, EntityID, [EntityID]) {
        var sim = duel(water: lake)
        sim.players[0].age = age
        sim.exploreAll(me)
        let ship = sim.add(.navyShip, me, 10.5, 12.5)
        let men = (0..<troops).map { sim.add(.soldier1, me, 6.5 + Double($0 % 3) * 0.4, 11.5 + Double($0 / 3) * 0.4) }
        return (sim, ship, men)
    }

    @Test func troopsBoardAShipAtTheShoreUpToItsCargoAndLeaveTheMap() {
        var (sim, ship, men) = harbour(troops: 22)
        let population = sim.population[0]
        #expect(sim.atShore(sim.index(of: ship)!))
        #expect(sim.apply(.board(units: men, ship: ship), from: me) == .accepted)
        sim.run(until: { $0.cargo(of: $0.index(of: ship)!) == Catalogue.standard.shipCargo }, limit: 30 * Tick.rate)
        sim.run(5 * Tick.rate)
        #expect(sim.cargo(of: sim.index(of: ship)!) == 20)
        #expect(men.filter { sim.entity($0) != nil }.count == 2)
        #expect(sim.population[0] == population)
        let view = sim.view(for: me)
        #expect(view.entity(ship)?.passengers == 20)
        #expect(view.entity(men[0]) == nil)
    }

    @Test func aShipAwayFromTheShoreTakesNoOneAboard() {
        var (sim, _, men) = harbour(troops: 1)
        let offshore = sim.add(.navyShip, me, 15.5, 15.5)
        #expect(sim.apply(.board(units: men, ship: offshore), from: me) == .refused(.invalidTarget))
    }

    @Test func aShipLandsItsTroopsOnTheShoreItIsSentTo() {
        var (sim, ship, men) = harbour(troops: 3)
        #expect(sim.apply(.board(units: men, ship: ship), from: me) == .accepted)
        sim.run(until: { $0.cargo(of: $0.index(of: ship)!) == 3 }, limit: 30 * Tick.rate)
        let shore = MapPosition(x: 21.5, y: 15.5)
        #expect(sim.apply(.land(ships: [ship], at: shore), from: me) == .accepted)
        let landed = sim.run(until: { s in men.allSatisfy { s.entity($0) != nil } }, limit: 60 * Tick.rate)
        #expect(landed)
        #expect(sim.cargo(of: sim.index(of: ship)!) == 0)
        for man in men {
            let tile = sim.living(man).position.tile
            #expect(!sim.terrain[sim.tileIndex(tile)].isWater && tile.x >= 20)
        }
        #expect(sim.entities.map(\.id) == sim.entities.map(\.id).sorted())
    }

    @Test func troopsAboardAreLostWithTheShip() {
        var (sim, ship, men) = harbour(troops: 4)
        #expect(sim.apply(.board(units: men, ship: ship), from: me) == .accepted)
        sim.run(until: { $0.cargo(of: $0.index(of: ship)!) == 4 }, limit: 30 * Tick.rate)
        let population = sim.population[0]
        sim.kill(sim.index(of: ship)!)
        sim.step()
        let shipPlaces = Catalogue.standard.stats(.navyShip).population
        #expect(sim.population[0] == population - shipPlaces - 4 * Catalogue.standard.stats(.soldier1).population)
        #expect(sim.view(for: me).events.contains(.destroyed(men[0])))
    }

    @Test func aShipMakesTroopsOnlyAtTheShoreFromTheAgeOfHospitals() {
        var (sim, ship, _) = harbour(troops: 0)
        sim.give(me, [.food: 500, .gold: 500])
        _ = sim.add(.house, me, 20, 2)
        _ = sim.add(.house, me, 23, 2)
        #expect(sim.apply(.train(at: ship, unit: .soldier1), from: me) == .refused(.ageNotReached(.hospitals)))
        sim.players[0].age = .hospitals
        let offshore = sim.add(.navyShip, me, 15.5, 15.5)
        #expect(sim.apply(.train(at: offshore, unit: .soldier1), from: me) == .accepted)
        #expect(sim.apply(.train(at: ship, unit: .knight3), from: me) == .accepted)
        let made = sim.run(until: { !$0.people(me, .knight3).isEmpty }, limit: 40 * Tick.rate)
        #expect(made)
        let tile = sim.living(sim.people(me, .knight3)[0]).position.tile
        #expect(!sim.terrain[sim.tileIndex(tile)].isWater)
        #expect(sim.people(me, .soldier1).isEmpty)
        #expect(sim.living(offshore).trainProgress == 0)
    }

    @Test func aShipFightsWithTheAttackOfItsOwnersAge() {
        var (sim, ship, _) = harbour(troops: 0)
        let target = sim.add(.soldier1, them, 8.5, 12.5)
        sim.run(1)
        #expect(sim.apply(.attack(units: [ship], target: target), from: me) == .accepted)
        let struck = sim.run(until: { ($0.health(target) ?? 0) < Catalogue.standard.stats(.soldier1).health }, limit: 10 * Tick.rate)
        #expect(struck)
    }
}

@Suite struct UnitsAndDefeat {
    @Test func aPlayerWithNoUnitAndNoMakerIsDefeatedThoughItKeepsAHouse() {
        var sim = trio()
        _ = sim.add(.house, PlayerID(1), 6, 40)
        for i in sim.entities.indices where sim.entities[i].owner == PlayerID(1) && sim.entities[i].buildingKind != .house {
            sim.kill(i)
        }
        sim.step()
        #expect(sim.players[1].isDefeated && !sim.teams[0].isDefeated)
        #expect(!sim.buildings(PlayerID(1), .house).isEmpty)
        #expect(sim.view(for: me).events.contains(.allyDefeated(PlayerID(1))))
    }

    @Test func aFishingBoatIsAUnitAndKeepsItsPlayerInTheMatch() {
        var sim = duel(water: lake)
        let boat = sim.add(.fishingBoat, them, 14.5, 14.5)
        for i in sim.entities.indices where sim.entities[i].owner == them && sim.entities[i].id != boat { sim.kill(i) }
        sim.step()
        #expect(!sim.players[1].isDefeated && sim.outcome == nil)
        sim.kill(sim.index(of: boat)!)
        sim.step()
        #expect(sim.outcome == .won(TeamID(0)))
    }

    @Test func aMakerAloneKeepsItsPlayerInTheMatchAndAnUnfinishedOneDoesNot() {
        var sim = duel()
        let barracks = sim.add(.barracks, them, 30, 30)
        let site = sim.add(.stable, them, 26, 30, complete: false)
        for i in sim.entities.indices where sim.entities[i].owner == them && ![barracks, site].contains(sim.entities[i].id) {
            sim.kill(i)
        }
        sim.step()
        #expect(!sim.players[1].isDefeated)
        sim.kill(sim.index(of: barracks)!)
        sim.step()
        #expect(sim.players[1].isDefeated && sim.outcome == .won(TeamID(0)))
    }
}

@Suite struct Founders {
    @Test func aPersonWithoutWorkersOrTownCentresReceivesAFounderBesideAnAllysTownCentre() {
        var sim = trio()
        let soldier = sim.add(.soldier1, me, 8.5, 8.5)
        for i in sim.entities.indices where sim.entities[i].owner == me && sim.entities[i].id != soldier { sim.kill(i) }
        sim.step()
        #expect(!sim.players[0].isDefeated)
        let founders = sim.people(me, .founder)
        #expect(founders.count == 1)
        let ally = sim.living(sim.townCentre(PlayerID(1)))
        #expect(Goal.tiles(ally.origin, ally.size, reach: 0).distance(to: sim.living(founders[0]).position) < 2)
        // One founder only, however long the player waits.
        sim.run(20)
        #expect(sim.people(me, .founder).count == 1)
    }

    @Test func aComputerPlayerNeverReceivesAFounder() {
        var sim = trio(teams: [0, 1, 1])
        sim.destroyAll(PlayerID(1))
        #expect(sim.people(PlayerID(1), .founder).isEmpty && sim.players[1].isDefeated)
    }

    @Test func aPersonWithoutATeammateReceivesNone() {
        var sim = duel()
        let soldier = sim.add(.soldier1, me, 8.5, 8.5)
        for i in sim.entities.indices where sim.entities[i].owner == me && sim.entities[i].id != soldier { sim.kill(i) }
        sim.step()
        #expect(sim.people(me, .founder).isEmpty)
    }

    @Test func aFounderCannotBeHarmedAttackOrBeDismissed() {
        var sim = trio()
        sim.destroyAll(me)
        let founder = sim.people(me, .founder)[0]
        let enemy = sim.add(.soldier1, PlayerID(2), 4.5, 30.5)
        sim.exploreAll(PlayerID(2))
        #expect(!sim.canStrike(PlayerID(2), sim.index(of: founder)!))
        #expect(sim.apply(.attack(units: [enemy], target: founder), from: PlayerID(2)) == .refused(.invalidTarget)
                || sim.apply(.attack(units: [enemy], target: founder), from: PlayerID(2)) == .refused(.cannotAttack))
        #expect(sim.apply(.attack(units: [founder], target: enemy), from: me) == .refused(.notYours))
        #expect(sim.apply(.dismiss(units: [founder]), from: me) == .refused(.notYours))
        #expect(sim.population[0] == 0)
    }

    @Test func aDefeatedPersonComesBackThroughTheFoundersTownCentre() {
        var sim = trio()
        sim.destroyAll(me)
        #expect(sim.players[0].isDefeated && sim.outcome == nil)
        let founder = sim.people(me, .founder)[0]
        sim.exploreAll(me)
        let resources = sim.resources(me)
        #expect(sim.apply(.found(founder: founder, at: GridPoint(8, 30)), from: me) == .accepted)
        #expect(sim.resources(me) == resources)
        #expect(sim.apply(.found(founder: founder, at: GridPoint(14, 30)), from: me) == .refused(.notNow))
        let centre = sim.buildings(me, .townCentre)[0]
        #expect(!sim.living(centre).complete)
        let finished = sim.run(until: { $0.living(centre).complete }, limit: Catalogue.standard.stats(.townCentre).buildTime + 40 * Tick.rate)
        #expect(finished)
        sim.step()
        #expect(sim.people(me, .founder).isEmpty)
        #expect(sim.people(me, .worker).count == Catalogue.standard.founderPeople + 1)
        #expect(sim.people(me, .worker).contains(founder))
        #expect(!sim.players[0].isDefeated)
    }
}
