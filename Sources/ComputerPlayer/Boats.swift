// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Boats, for the water's fish and gold (ruled 2026-11-21): a boat house is
/// wanted beside the nearest water that holds them (`wanted`), it makes
/// `Tuning.boats` boats, and each idle boat goes to the nearest site in its
/// water of the resource, fish (food) or gold, that the player's plan lacks
/// more (`workShares`): what a boat gathers is added at once to the stock.
extension Turn {
    /// The nearest site in the water, with something left, within `reach`
    /// tiles of `point`; with `kind`, of that kind; with `water`, in that water region.
    func nearestWaterSite(to point: MapPosition, within reach: Double, kind: SiteKind? = nil,
                          water: Int32? = nil) -> ResourceSite? {
        var best: ResourceSite?
        var bestDistance = reach
        let width = view.mapWidth
        view.sites.withUnsafeBufferPointer { sites in
            for i in 0..<sites.count where sites[i].remaining > 0
                && view.terrain[sites[i].tile.y * width + sites[i].tile.x].isWater {
                if let kind, sites[i].kind != kind { continue }
                if let water, regions.region(sites[i].tile) != water { continue }
                let d = sites[i].tile.centre.distance(to: point)
                if d < bestDistance || (d == bestDistance && best.map { sites[i].id < $0.id } ?? false) {
                    best = sites[i]
                    bestDistance = d
                }
            }
        }
        return best
    }

    /// A complete boat house by water that holds fish or gold makes boats up
    /// to `Tuning.boats`, one at a time.
    func trainBoats() {
        // Twice as many once the land's gold is gone and the water holds some.
        let goldAfloat = !OpenSites(view: view, memory: memory).has(.gold)
            && nearestWaterSite(to: base, within: 60, kind: .gold) != nil
        guard boats.count + training[UnitKind.fishingBoat.rawValue] < tuning.boats * (goldAfloat ? 2 : 1),
              let made = catalogue.production(of: .fishingBoat, at: .boatHouse), made.age <= view.age else { return }
        let stats = catalogue.stats(.fishingBoat)
        for house in completeBuildings(.boatHouse) where isFree(house) && queueLength(house) == 0 {
            guard nearestWaterSite(to: house.position, within: 40) != nil else { continue }
            guard projectedPopulation + stats.population <= view.populationLimit, canPay(stats.cost) else { return }
            train(.fishingBoat, at: house)
            return
        }
    }

    /// Each idle boat gathers at the nearest site in its water of the resource
    /// the plan lacks more, in the shares the workers follow, or failing that of the other.
    func sendBoats() {
        let idle = boats.filter { isFree($0) && $0.activity == .idle }
        guard !idle.isEmpty else { return }
        let shares = workShares(OpenSites(view: view, memory: memory))
        var on = [Int](repeating: 0, count: Resource.allCases.count)
        for boat in boats { if case .gathering(let kind) = boat.activity { on[kind.yield.rawValue] += 1 } }
        for boat in idle {
            let water = regions.region(boat.position)
            let total = Double(boats.count)
            let kinds = [SiteKind.fish, .gold].sorted { a, b in
                let x = shares[a.yield.rawValue] * total - Double(on[a.yield.rawValue])
                let y = shares[b.yield.rawValue] * total - Double(on[b.yield.rawValue])
                return x != y ? x > y : a.rawValue > b.rawValue
            }
            for kind in kinds {
                guard let site = nearestWaterSite(to: boat.position, within: 60, kind: kind, water: water) else { continue }
                give(.gather(units: [boat.id], site: site.id), to: [boat.id])
                on[kind.yield.rawValue] += 1
                break
            }
        }
    }
}
