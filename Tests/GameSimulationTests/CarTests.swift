// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

/// A person's car (ruled 2026-11-21).
@Suite struct Car {
    @Test func aPersonSummonsUpToFiveCarsBesideATownCentreAndAComputerNone() {
        var sim = duel()
        #expect(sim.apply(.summonCar, from: them) == .refused(.notYours))   // a computer player
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let cars = sim.people(me, .car)
        #expect(cars.count == 1)
        let centre = sim.living(sim.townCentre(me))
        #expect(sim.living(cars[0]).position.distance(to: centre.position) < 4)
        for _ in 2...5 { #expect(sim.apply(.summonCar, from: me) == .accepted) }
        #expect(sim.people(me, .car).count == 5)
        #expect(sim.apply(.summonCar, from: me) == .refused(.notNow))      // five each (ruled 2026-11-21)
        #expect(sim.people(me, .car).count == 5)
        // Free, and outside the population.
        #expect(sim.view(for: me).population == sim.people(me, .worker).count)
    }

    @Test func withoutATownCentreThereIsNoCar() {
        var sim = duel()
        sim.kill(sim.index(of: sim.townCentre(me))!)
        sim.removeDead()
        #expect(sim.apply(.summonCar, from: me) == .refused(.invalidTarget))
    }

    @Test func itDrivesAtTwiceAWorkersSpeed() {
        #expect(Catalogue.standard.stats(.car).speed == 2 * Catalogue.standard.stats(.worker).speed)
    }

    @Test func everyOpponentsUnitWithinElevenTilesDiesAndTheCarCannotBeHarmed() {
        var sim = duel()
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        let at = sim.living(car).position
        let near = sim.add(.cannon, them, at.x + 10.5, at.y)          // inside 11 tiles
        let far = sim.add(.spearman, them, at.x + 14, at.y)            // outside
        let mine = sim.add(.spearman, me, at.x + 2, at.y)              // the player's own
        let musketeer = sim.add(.musketeer, them, at.x + 12.5, at.y)
        sim.step()
        #expect(sim.entity(near) == nil)
        #expect(sim.entity(far) != nil && sim.entity(mine) != nil)
        // The musketeer may not target the car, nor harm it.
        #expect(sim.apply(.attack(units: [musketeer], target: car), from: them) != .accepted)
        #expect(!sim.canStrike(them, sim.index(of: car)!))
        #expect(sim.view(for: me).events.contains(.destroyed(near)))
    }

    @Test func theCarKeepsNobodyInTheMatch() {
        var sim = Simulation(setup: setup(openMap(starts: [GridPoint(2, 2), GridPoint(34, 34), GridPoint(2, 34)]),
                                          teams: [0, 1, 0]))
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        // Everything else of the player's is destroyed: whilst the ally stands, the car stays.
        for i in sim.entities.indices where sim.entities[i].owner == me && sim.entities[i].id != car { sim.kill(i) }
        sim.step()
        #expect(sim.entity(car) != nil)
        #expect(!sim.players[0].isDefeated && sim.outcome == nil)
        // With the ally's all gone too, the team is defeated, the car with it.
        for i in sim.entities.indices where sim.entities[i].owner == PlayerID(2) { sim.kill(i) }
        sim.step()
        #expect(sim.entity(car) == nil)
        #expect(sim.players[0].isDefeated && sim.outcome == .won(TeamID(1)))
    }

    /// The kill radius turned off and on (ruled 2026-11-21): off, the car kills
    /// nobody by driving near and still burns buildings with its laser.
    @Test func thePersonTurnsTheKillRadiusOffAndOn() {
        var sim = duel()
        sim.exploreAll(me)
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        #expect(sim.apply(.setKillRadius(cars: [car], on: false), from: them) == .refused(.notYours))
        #expect(sim.apply(.setKillRadius(cars: [car], on: false), from: me) == .accepted)
        #expect(sim.view(for: me).entities.first { $0.id == car }?.killRadiusOff == true)
        let at = sim.living(car).position
        let near = sim.add(.spearman, them, at.x + 3, at.y)
        sim.step()
        #expect(sim.entity(near) != nil, "the car killed with its radius off")
        let house = sim.add(.house, them, at.tile.x + 5, at.tile.y)
        #expect(sim.apply(.attack(units: [car], target: house), from: me) == .accepted)
        let burnt = sim.run(until: { $0.entity(house) == nil }, limit: Catalogue.standard.car!.laserTime + 2 * Tick.rate)
        #expect(burnt, "the laser did not burn the house with the radius off")
        #expect(sim.apply(.setKillRadius(cars: [car], on: true), from: me) == .accepted)
        sim.step()
        #expect(sim.entity(near) == nil, "the car did not kill with its radius on again")
    }
}
