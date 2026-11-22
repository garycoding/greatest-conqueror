// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameSimulation

/// The car's laser (ruled 2026-11-21).
@Suite struct Laser {
    @Test func itBurnsAnyOpponentsBuildingDownInAboutFourSeconds() {
        var sim = duel()
        sim.exploreAll(me)
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        let at = sim.living(car).position.tile
        let barracks = sim.add(.barracks, them, at.x + 6, at.y)
        let castle = sim.add(.castle, them, at.x, at.y + 6)
        #expect(sim.apply(.attack(units: [car], target: barracks), from: me) == .accepted)
        sim.step()
        let view = sim.view(for: me)
        #expect(view.entities.first { $0.id == car }?.laserTarget == sim.living(barracks).position)
        let time = Catalogue.standard.car!.laserTime
        let barracksGone = sim.run(until: { $0.entity(barracks) == nil }, limit: time + Tick.rate / 2)
        #expect(barracksGone)
        #expect(sim.apply(.attack(units: [car], target: castle), from: me) == .accepted)
        let castleGone = sim.run(until: { $0.entity(castle) == nil }, limit: time + Tick.rate / 2)
        #expect(castleGone)
        #expect(sim.living(car).task == .idle)
    }

    @Test func itDrivesWithinEightTilesFirst() {
        var sim = duel()
        sim.exploreAll(me)
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        let house = sim.add(.house, them, 24, 6)
        _ = sim.add(.worker, me, 23.5, 10.5)     // someone of the player's in sight of it
        #expect(sim.apply(.attack(units: [car], target: house), from: me) == .accepted)
        var nearest = Double.infinity
        let gone = sim.run(until: { s in
            if s.living(car).doing == .fighting { nearest = min(nearest, s.living(car).position.distance(to: s.living(house).position)) }
            return s.entity(house) == nil
        }, limit: 30 * Tick.rate)
        #expect(gone)
        #expect(nearest <= Catalogue.standard.car!.laserRange + 1.5)
    }

    @Test func notOwnOrAlliedBuildingsNorPeople() {
        var sim = duel()
        sim.exploreAll(me)
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        let at = sim.living(car).position
        #expect(sim.apply(.attack(units: [car], target: sim.townCentre(me)), from: me) == .refused(.cannotAttack))
        let spearman = sim.add(.spearman, them, at.x + 15, at.y)
        #expect(sim.apply(.attack(units: [car], target: spearman), from: me) == .refused(.cannotAttack))
    }
}
