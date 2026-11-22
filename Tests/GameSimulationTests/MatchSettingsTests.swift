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
        match.startingAge = age == .towns ? nil : age
        return Simulation(setup: match)
    }

    @Test func aMatchBegunInTheAgeOfTownsIsTheStandardStart() {
        let sim = match(in: .towns)
        for p in sim.players {
            #expect(p.age == .towns)
            #expect(p.resources == Catalogue.standard.startingResources)
        }
    }

    @Test(arguments: [Age.farms, .ships, .cannons, .hospitals])
    func everyPlayerBeginsInTheAgeWithWhatTheAdvancesWouldHaveCost(age: Age) {
        var sim = match(in: age)
        var stock = Catalogue.standard.startingResources
        var a = Age.towns
        while a < age { stock = stock + Catalogue.standard.advance(from: a)!.cost; a = a.next! }
        for p in sim.players {
            #expect(p.age == age)
            #expect(p.resources == stock)
        }
        #expect(sim.view(for: PlayerID(0)).age == age)
        // The start itself is the standard one: a town centre and its people.
        #expect(sim.entities.filter { $0.buildingKind == .townCentre }.count == 2)
    }

    @Test func aPlayerBegunInTheAgeOfHospitalsAdvancesNoFurther() {
        var sim = match(in: .hospitals)
        let centre = sim.entities.first { $0.owner == PlayerID(0) && $0.buildingKind == .townCentre }!.id
        #expect(sim.apply(.advanceAge(at: centre), from: PlayerID(0)) == .refused(.invalidTarget))
    }
}
