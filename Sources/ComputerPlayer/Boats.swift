// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Boats, for the water's fish and rocks (ruled 2026-11-21): a boat house is
/// wanted beside the nearest water that holds them (`wanted`), it trains a few
/// boats, and each idle boat goes to the nearest site in the water.
extension Turn {
    /// The boats a computer player keeps.
    static let boatsWanted = 3

    /// The nearest site in the water, with something left and of an age the
    /// player has reached, within `reach` tiles of `point`.
    func nearestWaterSite(to point: MapPosition, within reach: Double) -> ResourceSite? {
        var best: ResourceSite?
        var bestDistance = reach
        let width = view.mapWidth, age = view.age
        view.sites.withUnsafeBufferPointer { sites in
            for i in 0..<sites.count where sites[i].remaining > 0 && sites[i].kind.firstAge <= age
                && view.terrain[sites[i].tile.y * width + sites[i].tile.x].isWater {
                let d = sites[i].tile.centre.distance(to: point)
                if d < bestDistance || (d == bestDistance && best.map { sites[i].id < $0.id } ?? false) {
                    best = sites[i]
                    bestDistance = d
                }
            }
        }
        return best
    }

    /// A complete boat house trains boats up to `boatsWanted`, one at a time.
    func trainBoats() {
        guard boats.count + training[UnitKind.boat.rawValue] < Self.boatsWanted else { return }
        let stats = catalogue.stats(.boat)
        for house in completeBuildings(.boatHouse) where isFree(house) && queueLength(house) == 0 {
            guard projectedPopulation + stats.population <= view.populationLimit, canPay(stats.cost) else { return }
            train(.boat, at: house)
            return
        }
    }

    /// Each idle boat gathers at the nearest site in the water.
    func sendBoats() {
        for boat in boats where isFree(boat) && boat.activity == .idle {
            guard let site = nearestWaterSite(to: boat.position, within: 60) else { return }
            give(.gather(units: [boat.id], site: site.id), to: [boat.id])
        }
    }
}
