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
            let size = catalogue.stats(kind).footprint
            let builders = size.x * size.y >= 16 ? 3 : size.x * size.y >= 9 && kind != .farm ? 2 : 1
            if construct(kind, near: anchor, rings: rings, builders: builders) {
                underway += 1
            } else if view.visibility(at: clamped(anchor).tile) == .unexplored {
                lookAt(anchor)
            }
        }
    }

    /// A building is wanted on ground not yet explored (a boathouse by distant
    /// water): an idle warfighter, or failing that an idle builder, goes to look,
    /// since nothing can be built on ground the player has not seen.
    func lookAt(_ point: MapPosition) {
        if let lookout = memory.lookout, let unit = view.entity(lookout.unit), unit.owner == view.player,
           unit.activity != .idle, view.tick - lookout.tick < Tick.seconds(60) { return }
        let candidates = warfighters.filter { isFree($0) && $0.activity == .idle }
            + builders.filter { isFree($0) && $0.activity == .idle }
        guard let unit = Turn.nearest(candidates, to: point) else { return }
        let goal = clamped(point)
        give(.move(units: [unit.id], to: goal), to: [unit.id])
        memory.lookout = Scouting(unit: unit.id, destination: goal, tick: view.tick)
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

    /// The buildings wanted besides houses and the town centre, in order, each
    /// with where to look for a place: every kind of building the age allows
    /// (`stats.csv`) that has a use: one of each maker that makes something in
    /// this age (`production.csv`), `Tuning.barracks` of the barracks, a tower,
    /// farms as the food requires, and a boathouse by the water.
    func wanted() -> [(BuildingKind, MapPosition, ClosedRange<Int>)] {
        if let wantedNow { return wantedNow }
        var out: [(BuildingKind, MapPosition, ClosedRange<Int>)] = []
        for stats in catalogue.buildings where stats.age <= view.age {
            let kind = stats.kind
            switch kind {
            case .townCentre, .house:
                continue
            case .farm:
                // Farms, reseeded by their farmers when they run dry: the food once the prey
                // thins. A farm is wanted once every farm has its farmer and the wild food
                // near is gone or food runs short, at most a quarter of the workers.
                let farms = count(.farm), wantedFarms = tuning.workers(at: view.age) / 4
                let full = herders >= completeBuildings(.farm).count
                let hungry = !surroundings().wildFoodNear || view.resources[.food] < 200
                if farms < wantedFarms && full && hungry && memory.plans.allSatisfy({ $0.kind != .farm }) {
                    out.append((.farm, homeSide(by: 6), 0...10))
                }
            case .boatHouse:
                // On the shore of the nearest water that holds fish or gold (ruled 2026-11-21);
                // and, once navy ships can be made, on the shore of the largest water near,
                // where they can sail farthest.
                guard completeBuildings(.townCentre).count > 0, makesNow(.boatHouse),
                      memory.plans.allSatisfy({ $0.kind != .boatHouse }),
                      !buildings.contains(where: { $0.kind == .building(.boatHouse) && !Turn.isComplete($0) }) else { continue }
                if count(.boatHouse) == 0, let water = nearestWaterSite(to: base, within: 20) {
                    out.append((.boatHouse, water.tile.centre, 1...8))
                } else if navyWanted > 0, let sea = openWater(near: base, within: 30), !hasBoatHouse(on: regions.region(sea)) {
                    out.append((.boatHouse, sea.centre, 1...8))
                }
            case .tower:
                if count(.tower) == 0 { out.append((.tower, Turn.toward(base, front, by: 5), 0...6)) }
            default:
                guard makesNow(kind) else { continue }
                let fights = catalogue.made(by: .building(kind)).contains { $0.unit.isWarfighter }
                let anchor = fights ? Turn.toward(base, front, by: 7) : homeSide(by: 6)
                let rings = stats.footprint.x > 3 ? 0...10 : 0...8
                if count(kind) == 0 || (kind == .barracks && count(kind) < tuning.barracks && !completeBuildings(kind).isEmpty) {
                    out.append((kind, anchor, rings))
                }
            }
        }
        // The newest age's buildings first, so that the age's own come before more of the older ones.
        let ranked = out.enumerated().sorted { a, b in
            let x = catalogue.stats(a.element.0).age, y = catalogue.stats(b.element.0).age
            return x != y ? x > y : a.offset < b.offset
        }
        let found = ranked.map(\.element)
        wantedNow = found
        return found
    }

    /// Whether a building makes some unit in the player's age (`production.csv`).
    func makesNow(_ kind: BuildingKind) -> Bool {
        catalogue.made(by: .building(kind)).contains { $0.age <= view.age }
    }

    /// Whether a boathouse of the player's stands on the shore of a water region.
    func hasBoatHouse(on water: Int32) -> Bool {
        buildings.contains { house in
            guard house.kind == .building(.boatHouse) else { return false }
            let size = catalogue.stats(.boatHouse).footprint
            for y in (house.tile.y - 1)...(house.tile.y + size.y) {
                for x in (house.tile.x - 1)...(house.tile.x + size.x) where regions.region(GridPoint(x, y)) == water { return true }
            }
            return false
        }
    }

    /// The water tile beside the base's land nearest `point`, within `reach`
    /// tiles, in the largest body of water within that reach, if it is large
    /// enough to sail (forty tiles or more).
    func openWater(near point: MapPosition, within reach: Int) -> GridPoint? {
        let land = regions.region(point)
        guard land > 0 else { return nil }
        var best: GridPoint?
        var bestDistance = Double.infinity, bestSize = 0
        let c = point.tile
        for y in max(0, c.y - reach)...min(view.mapHeight - 1, c.y + reach) {
            for x in max(0, c.x - reach)...min(view.mapWidth - 1, c.x + reach) {
                let tile = GridPoint(x, y)
                let water = regions.region(tile)
                let size = regions.size(of: water)
                guard water < 0, size >= 40, size >= bestSize, regions.borders(tile, land) else { continue }
                let d = tile.centre.distance(to: point)
                if size > bestSize || d < bestDistance { best = tile; bestDistance = d; bestSize = size }
            }
        }
        return best
    }

    /// Builders construct a building near `anchor`, if one can be spared, the
    /// cost can be paid, and a place can be found; a cost that cannot yet be paid
    /// is held back from spending of lower priority.
    @discardableResult
    func construct(_ kind: BuildingKind, near anchor: MapPosition, rings: ClosedRange<Int>,
                   builders wanted: Int = 1, urgent: Bool = false, orFarther: Bool = true) -> Bool {
        let stats = catalogue.stats(kind)
        guard stats.age <= view.age else { return false }
        let team = spareBuilders(near: anchor, count: wanted, urgent: urgent)
        guard !team.isEmpty else { return false }
        guard canPay(stats.cost, urgent: urgent) else {
            setAside(stats.cost)
            return false
        }
        // Where the rings near the anchor are full, farther out, unless the place must be near.
        guard let origin = site(for: kind, near: anchor, rings: rings)
                ?? (orFarther && rings.upperBound < Turn.widestRing
                    ? site(for: kind, near: anchor, rings: (rings.upperBound + 1)...Turn.widestRing) : nil)
        else { return false }
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
    /// worker can reach it to build it, and, but for a boathouse or a tower, it
    /// must not close a way through (`Ground.closesAWay`). Rings beyond
    /// `Turn.widestRing` are not searched.
    func site(for kind: BuildingKind, near anchor: MapPosition, rings: ClosedRange<Int>) -> GridPoint? {
        let low = max(0, rings.lowerBound), high = min(Turn.widestRing, rings.upperBound)
        guard low <= high else { return nil }
        prepareGround()
        guard let ground else { return nil }
        let size = ground.size(of: kind)
        let centre = Placement.origin(kind, centre: anchor, catalogue: catalogue)
        let offsets = Turn.ringOffsets, first = Turn.ringStart(low), end = Turn.ringStart(high + 1)
        let refused = memory.refusedSites.filter { $0.kind == kind }.map(\.origin)
        // A side its workers can walk to; with no workers to walk, any open side.
        let walk = workers.isEmpty && builders.isEmpty ? [] : walkable(), width = view.mapWidth
        for spaced in [true, false] {
            var i = first
            while i < end {
                let origin = GridPoint(centre.x + offsets[i].x, centre.y + offsets[i].y)
                i += 1
                guard ground.isFree(size: size, at: origin), !spaced || ground.isClear(size: size, at: origin),
                      kind == .boatHouse || kind == .tower || !ground.closesAWay(size: size, at: origin, in: view),
                      !refused.contains(origin), ground.allows(kind, at: origin, in: view),
                      ground.hasOpenSide(size: size, at: origin, in: view, reachable: { walk.isEmpty || walk[$0.y * width + $0.x] })
                else { continue }
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
