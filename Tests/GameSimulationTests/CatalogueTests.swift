// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameSimulation

/// The catalogue is part of the match (requirement 25): the simulation plays by
/// the tables it was set up with, saves them, and counts them in its checksum.
@Suite struct MatchCatalogue {
    /// The standard tables with workers cheaper and quicker to train.
    static var tuned: Catalogue {
        var texts = TableTexts.defaults
        texts.stats = texts.stats.replacingOccurrences(of: "worker,towns,50,", with: "worker,towns,30,")
        texts.production = texts.production.replacingOccurrences(of: "townCentre,worker,towns,12", with: "townCentre,worker,towns,6")
        return try! Catalogue(tables: texts)
    }

    @Test func theMatchPlaysByItsTables() {
        var sim = duel(catalogue: Self.tuned)
        let food = sim.resources(me)[.food]
        #expect(sim.apply(.train(at: sim.townCentre(me), unit: .worker), from: me) == .accepted)
        #expect(sim.resources(me)[.food] == food - 30)
        let trained = sim.run(until: { $0.people(me, .worker).count == 4 }, limit: Tick.seconds(12))
        #expect(trained && sim.tick == Tick.seconds(6))
    }

    @Test func aSavedMatchKeepsItsTables() throws {
        var sim = duel(catalogue: Self.tuned)
        sim.run(10)
        let reopened = try JSONDecoder().decode(Simulation.self, from: JSONEncoder().encode(sim))
        #expect(reopened.catalogue == Self.tuned)
        #expect(reopened.checksum() == sim.checksum())
    }

    @Test func theChecksumCountsTheTables() {
        #expect(duel(catalogue: Self.tuned).checksum() != duel().checksum())
    }
}
