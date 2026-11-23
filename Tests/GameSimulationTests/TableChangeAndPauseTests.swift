// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameSimulation

/// New tables during play (requirement 27) and the pause (requirement 30).
@Suite struct TableChangeAndPause {
    @Test func newTablesTakeEffectFromTheNextTickAndEnterTheChecksum() throws {
        var sim = duel()
        sim.run(20)
        let worker = sim.people(me, .worker)[0]
        let i = sim.entities.firstIndex { $0.id == worker }!
        let full = sim.entities[i].maxHealth
        sim.entities[i].health = full / 2
        let before = sim.checksum()
        var tuned = Catalogue.standard
        let w = tuned.units.firstIndex { $0.kind == .worker }!
        tuned.units[w].health = full * 2
        tuned.units[w].cost = ResourceAmounts([.food: 80])
        let tick = sim.tick
        sim.adopt(tuned)
        #expect(sim.tick == tick)
        #expect(sim.catalogue == tuned && sim.checksum() != before)
        // The worker is set to the new maximum (ruled 2026-11-22).
        #expect(sim.living(worker).maxHealth == full * 2 && sim.living(worker).health == full * 2)
        // The next worker trained costs the new price.
        let centre = sim.entities.first { $0.owner == me && $0.buildingKind == .townCentre }!.id
        let food = sim.resources(me)[.food]
        #expect(sim.apply(.train(at: centre, unit: .worker), from: me) == .accepted)
        #expect(sim.resources(me)[.food] == food - 80)
        // A saved match keeps the new tables.
        let reopened = try JSONDecoder().decode(Simulation.self, from: JSONEncoder().encode(sim))
        #expect(reopened.catalogue == tuned && reopened.checksum() == sim.checksum())
    }

    @Test func aPauseHoldsEverythingAndNamesWhoPausedIt() throws {
        var sim = duel()
        let worker = sim.people(me, .worker)[0]
        #expect(sim.apply(.setPaused(true), from: me) == .accepted)
        #expect(sim.view(for: me).pausedBy == me && sim.view(for: PlayerID(1)).pausedBy == me)
        let tick = sim.tick, position = sim.living(worker).position
        #expect(sim.apply(.move(units: [worker], to: MapPosition(x: 20.5, y: 20.5)), from: me) == .refused(.notNow))
        sim.run(40)
        #expect(sim.tick == tick && sim.living(worker).position == position)
        let reopened = try JSONDecoder().decode(Simulation.self, from: JSONEncoder().encode(sim))
        #expect(reopened.pausedBy == me && reopened.checksum() == sim.checksum())
        #expect(sim.apply(.setPaused(false), from: me) == .accepted)
        #expect(sim.view(for: me).pausedBy == nil && !sim.view(for: me).isPaused)
        sim.run(1)
        #expect(sim.tick == tick + 1)
    }
}
