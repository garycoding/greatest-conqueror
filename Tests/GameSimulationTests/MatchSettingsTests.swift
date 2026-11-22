// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameSimulation

/// The starting age, a setting of the match (ruled 2026-11-21).
@Suite struct StartingAge {
    private func match(in age: Age) -> Simulation {
        var match = setup(openMap(starts: [GridPoint(4, 4), GridPoint(30, 30)]), teams: [0, 1])
        match.startingAge = age == .stone ? nil : age
        return Simulation(setup: match)
    }

    @Test func aMatchBegunInTheStoneAgeIsTheStandardStart() {
        let sim = match(in: .stone)
        for p in sim.players {
            #expect(p.age == .stone)
            #expect(p.resources == Catalogue.standard.startingResources)
        }
    }

    @Test(arguments: [Age.bronze, .iron, .alchemy, .industrial])
    func everyPlayerBeginsInTheAgeWithWhatTheAdvancesWouldHaveCost(age: Age) {
        var sim = match(in: age)
        var stock = Catalogue.standard.startingResources
        var a = Age.stone
        while a < age { stock = stock + Catalogue.standard.advance(from: a)!.cost; a = a.next! }
        for p in sim.players {
            #expect(p.age == age)
            #expect(p.resources == stock)
        }
        #expect(sim.view(for: PlayerID(0)).age == age)
        // The start itself is the standard one: a town centre and its people.
        #expect(sim.entities.filter { $0.buildingKind == .townCentre }.count == 2)
    }

    @Test func aPlayerBegunInTheIndustrialAgeAdvancesNoFurther() {
        var sim = match(in: .industrial)
        #expect(sim.apply(.advanceAge, from: PlayerID(0)) == .refused(.invalidTarget))
    }
}
