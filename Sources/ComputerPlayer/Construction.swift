// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

extension Turn {
    /// Builders build a house before the population limit stops training, a
    /// town centre if none stands, and the buildings of each age (`wanted`).
    func build() {
        buildHouse()
        if count(.townCentre) == 0 { construct(.townCentre, near: base, rings: 0...10, builders: 2) }
        var underway = buildings.filter { !Turn.isComplete($0) && $0.kind != .building(.house) }.count
            + memory.plans.filter { $0.kind != .house }.count
        for (kind, anchor, rings) in wanted() {
            guard underway < tuning.builds else { return }
            let builders = kind == .barracks || kind == .townCentre ? 2 : kind == .castle ? 3 : 1
            if construct(kind, near: anchor, rings: rings, builders: builders) { underway += 1 }
        }
    }

    private func buildHouse() {
        let ceiling = catalogue.populationMaximum
        guard view.populationLimit < ceiling, catalogue.stats(.house).housing > 0 else { return }
        var coming = 0, houses = 0
        for building in buildings where !Turn.isComplete(building) {
            guard case .building(let kind) = building.kind else { continue }
            coming += catalogue.stats(kind).housing
            if kind == .house { houses += 1 }
        }
        for plan in memory.plans {
            coming += catalogue.stats(plan.kind).housing
            if plan.kind == .house { houses += 1 }
        }
        // Room for the next person trained, and a margin while the house goes up.
        let room = min(ceiling, view.populationLimit + coming) - (projectedPopulation + 1)
        let margin = tuning.houseMargin + 2 * completeBuildings(.barracks).count
        guard room < margin, houses < (tuning.builds > 2 ? 2 : 1) else { return }
        construct(.house, near: homeSide(by: 4), rings: 0...8, urgent: view.populationLimit <= projectedPopulation)
    }

    /// The buildings wanted besides houses, in order, each with where to look for a place.
    private func wanted() -> [(BuildingKind, MapPosition, ClosedRange<Int>)] {
        var out: [(BuildingKind, MapPosition, ClosedRange<Int>)] = []
        if view.age >= .farms {
            let barracks = (BuildingKind.barracks, Turn.toward(base, front, by: 7), 0...8)
            if count(.barracks) == 0 { out.append(barracks) }
            if count(.tower) == 0 { out.append((.tower, Turn.toward(base, front, by: 5), 0...6)) }
            if count(.barracks) < tuning.barracks && !completeBuildings(.barracks).isEmpty { out.append(barracks) }
            // Farms, reseeded by their farmers when they run dry: the food once the prey
            // thins, since no other building yields it. A farm is wanted once every farm
            // has its farmer and the prey near is gone or food runs short, at most a
            // quarter of the workers.
            let farms = count(.farm), wantedFarms = tuning.workers(at: view.age) / 4
            let full = herders >= completeBuildings(.farm).count
            let hungry = !surroundings().wildFoodNear || view.resources[.food] < 200
            if farms < wantedFarms && full && hungry && memory.plans.allSatisfy({ $0.kind != .farm }) {
                out.append((.farm, homeSide(by: 6), 0...10))
            }
        }
        if view.age >= .ships, count(.stable) == 0 {
            out.append((.stable, Turn.toward(base, front, by: 7), 0...8))
        }
        if view.age >= .cannons, count(.castle) == 0 {
            out.append((.castle, Turn.toward(base, front, by: 7), 0...10))
        }
        // A boat house on the shore of the nearest water that holds fish or rocks (ruled 2026-11-21).
        if count(.boatHouse) == 0, completeBuildings(.townCentre).count > 0, let water = nearestWaterSite(to: base, within: 20) {
            out.append((.boatHouse, water.tile.centre, 1...8))
        }
        // The newest age's buildings first, so that the age's own come before more of the older ones.
        let ranked = out.enumerated().sorted { a, b in
            let x = catalogue.stats(a.element.0).age, y = catalogue.stats(b.element.0).age
            return x != y ? x > y : a.offset < b.offset
        }
        return ranked.map(\.element)
    }

    /// Builders construct a building near `anchor`, if one can be spared, the
    /// cost can be paid, and a place can be found; a cost that cannot yet be paid
    /// is held back from spending of lower priority.
    @discardableResult
    func construct(_ kind: BuildingKind, near anchor: MapPosition, rings: ClosedRange<Int>,
                   builders wanted: Int = 1, urgent: Bool = false) -> Bool {
        let stats = catalogue.stats(kind)
        guard stats.age <= view.age else { return false }
        let team = spareBuilders(near: anchor, count: wanted, urgent: urgent)
        guard !team.isEmpty else { return false }
        guard canPay(stats.cost, urgent: urgent) else {
            setAside(stats.cost)
            return false
        }
        guard let origin = site(for: kind, near: anchor, rings: rings) else { return false }
        let ids = team.map(\.id)
        give(.construct(workers: ids, building: kind, at: origin), to: ids)
        pay(stats.cost)
        memory.plans.append(Plan(kind: kind, origin: origin, builders: ids, tick: view.tick, cost: stats.cost))
        ground?.add(kind, at: origin)
        return true
    }

    /// Builders not already building: the idle first, then those doing
    /// something else, and those constructing only when the need is urgent.
    /// Beyond the first, only idle builders are taken.
    private func spareBuilders(near point: MapPosition, count: Int, urgent: Bool) -> [EntityView] {
        let planned = memory.plans.flatMap(\.builders)
        var scored: [(score: Double, builder: EntityView)] = []
        for builder in builders where isFree(builder) && !planned.contains(builder.id) {
            var score = builder.position.distance(to: point)
            switch builder.activity {
            case .idle: break
            case .constructing:
                if !urgent { continue }
                score += 1000
            default: score += 20
            }
            scored.append((score, builder))
        }
        scored.sort { $0.score != $1.score ? $0.score < $1.score : $0.builder.id < $1.builder.id }
        guard let first = scored.first else { return [] }
        let others = scored.dropFirst().filter { $0.builder.activity == .idle }.prefix(count - 1).map(\.builder)
        return [first.builder] + others
    }

    /// The side of the base away from its resources, so that houses and farms do
    /// not stand between workers and their work.
    private func homeSide(by distance: Double) -> MapPosition {
        let resources = surroundings().resources ?? front
        return Turn.toward(base, MapPosition(x: 2 * base.x - resources.x, y: 2 * base.y - resources.y), by: distance)
    }

    // MARK: Placement

    /// The nearest origin to `anchor`, ring by ring, where a building of `kind`
    /// may stand (`Placement.canPlace`, through `Ground.allows`) with a tile of
    /// open ground between it and every other building; failing that, without
    /// the open ground. Either way some tile beside it must be open, so that a
    /// worker can reach it to build it. Rings beyond `Turn.widestRing` are not searched.
    func site(for kind: BuildingKind, near anchor: MapPosition, rings: ClosedRange<Int>) -> GridPoint? {
        let low = max(0, rings.lowerBound), high = min(Turn.widestRing, rings.upperBound)
        guard low <= high else { return nil }
        prepareGround()
        guard let ground else { return nil }
        let size = ground.size(of: kind)
        let centre = Placement.origin(kind, centre: anchor, catalogue: catalogue)
        let offsets = Turn.ringOffsets, first = Turn.ringStart(low), end = Turn.ringStart(high + 1)
        let refused = memory.refusedSites.filter { $0.kind == kind }.map(\.origin)
        for spaced in [true, false] {
            var i = first
            while i < end {
                let origin = GridPoint(centre.x + offsets[i].x, centre.y + offsets[i].y)
                i += 1
                guard ground.isFree(size: size, at: origin), !spaced || ground.isClear(size: size, at: origin),
                      !refused.contains(origin), ground.allows(kind, at: origin, in: view),
                      ground.hasOpenSide(size: size, at: origin, in: view) else { continue }
                return origin
            }
        }
        return nil
    }

    static let widestRing = 16

    /// Offsets from a centre out to `widestRing`, ring by ring (Chebyshev
    /// distance), and within a ring nearest first. Ring `r` begins at `ringStart(r)`.
    static let ringOffsets: [GridPoint] = {
        var offsets: [(ring: Int, distance: Int, offset: GridPoint)] = []
        for dy in -widestRing...widestRing {
            for dx in -widestRing...widestRing {
                offsets.append((max(abs(dx), abs(dy)), dx * dx + dy * dy, GridPoint(dx, dy)))
            }
        }
        offsets.sort { ($0.ring, $0.distance, $0.offset) < ($1.ring, $1.distance, $1.offset) }
        return offsets.map(\.offset)
    }()

    /// Ring 0 is the centre alone; ring `r` holds `8 r` offsets after the `(2 r - 1)²` within it.
    static func ringStart(_ ring: Int) -> Int { ring == 0 ? 0 : (2 * ring - 1) * (2 * ring - 1) }
}
