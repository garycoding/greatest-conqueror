// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

@Suite struct Merchants {
    /// Three players on a 40 × 40 map: me (0) and my ally (2) on one team, them (1) on the other.
    static func allies() -> Simulation {
        var sim = Simulation(setup: setup(openMap(starts: [GridPoint(2, 2), GridPoint(34, 34), GridPoint(2, 20)]), teams: [0, 1, 0]))
        sim.players[0].age = .bronze
        return sim
    }

    @Test func aMerchantExchangesOneResourceForAnotherAtTheTownCentre() {
        var sim = Self.allies()
        let merchant = sim.add(.merchant, me, 6.5, 6.5)
        sim.players[0].resources = ResourceAmounts([.wood: 60])
        #expect(sim.apply(.exchange(merchants: [merchant], give: .wood, take: .gold), from: me) == .accepted)
        #expect(sim.apply(.exchange(merchants: [merchant], give: .wood, take: .wood), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.exchange(merchants: [merchant], give: .wood, take: .iron), from: me) == .refused(.invalidTarget))
        sim.apply(.exchange(merchants: [merchant], give: .wood, take: .gold), from: me)
        sim.run(90 * Tick.rate)
        // All 60 wood is traded, at two thirds rounded down, and then the merchant stops.
        #expect(sim.resources(me)[.wood] == 0)
        #expect(sim.resources(me)[.gold] == 39)
        #expect(sim.living(merchant).task == .idle)
    }

    @Test func aMerchantCarriesLoadsToAnAllyUntilTheStockRunsOut() {
        var sim = Self.allies()
        let ally = PlayerID(2)
        let merchant = sim.add(.merchant, me, 4.5, 6.5)
        sim.players[0].resources = ResourceAmounts([.wood: 50])
        let allyFood = sim.resources(ally)[.wood]
        #expect(sim.apply(.carry(merchants: [merchant], resource: .wood, to: sim.townCentre(them)), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.carry(merchants: [merchant], resource: .wood, to: sim.townCentre(ally)), from: me) == .accepted)
        sim.run(until: { $0.resources(ally)[.wood] == allyFood + 50 && $0.living(merchant).task == .idle }, limit: 300 * Tick.rate)
        #expect(sim.resources(ally)[.wood] == allyFood + 50)
        #expect(sim.resources(me)[.wood] == 0)
    }

    @Test func goodsInHandGoBackWhenTheMerchantIsGivenOtherWork() {
        var sim = Self.allies()
        let ally = PlayerID(2)
        let merchant = sim.add(.merchant, me, 4.5, 6.5)
        sim.players[0].resources = ResourceAmounts([.wood: 50])
        sim.apply(.carry(merchants: [merchant], resource: .wood, to: sim.townCentre(ally)), from: me)
        sim.run(until: { ($0.living(merchant).goods ?? 0) > 0 }, limit: 60 * Tick.rate)
        #expect(sim.resources(me)[.wood] == 30)
        #expect(sim.apply(.stop(units: [merchant]), from: me) == .accepted)
        #expect(sim.resources(me)[.wood] == 50)
    }

    @Test func aDismissedMerchantsGoodsGoBackToTheStock() {
        var sim = Self.allies()
        let merchant = sim.add(.merchant, me, 4.5, 6.5)
        sim.players[0].resources = ResourceAmounts([.wood: 50])
        sim.apply(.carry(merchants: [merchant], resource: .wood, to: sim.townCentre(PlayerID(2))), from: me)
        sim.run(until: { ($0.living(merchant).goods ?? 0) > 0 }, limit: 60 * Tick.rate)
        #expect(sim.apply(.dismiss(units: [merchant]), from: me) == .accepted)
        #expect(sim.resources(me)[.wood] == 50)
    }
}
