// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

extension Turn {
    /// Engineers build a house before the population limit stops training, a
    /// town centre if none stands, the Bronze age's stock pen, barracks and
    /// watch tower, and a storage pit beside resources gathered far from any
    /// building that accepts them.
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
        if view.age >= .bronze {
            let barracks = (BuildingKind.barracks, Turn.toward(base, front, by: 7), 0...8)
            let pen = (BuildingKind.stockPen, homeSide(by: 6), 0...8)
            // Whilst prey remains near, the barracks comes first; otherwise the herds.
            let first = surroundings().preyNear ? [barracks, pen] : [pen, barracks]
            for want in first where count(want.0) == 0 { out.append(want) }
            if count(.watchTower) == 0 { out.append((.watchTower, Turn.toward(base, front, by: 5), 0...6)) }
            if count(.barracks) < tuning.barracks && !completeBuildings(.barracks).isEmpty { out.append(barracks) }
            let herders = herders
            let pens = count(.stockPen)
            if pens > 0 && pens < 3 && herders >= 6 * pens { out.append(pen) }
        }
        if view.age >= .iron {
            // Farms, reseeded by their farmers when they run dry, as the herds and prey thin; then the stable and the siege workshop.
            // A farm is wanted once the pens are full and no prey is near, at most a quarter of the workers.
            let farms = count(.farm), wantedFarms = tuning.workers(at: view.age) / 4
            let herders = herders
            let full = herders >= 6 * count(.stockPen) + completeBuildings(.farm).count
            if farms < wantedFarms && full && !surroundings().preyNear && memory.plans.allSatisfy({ $0.kind != .farm }) {
                out.append((.farm, homeSide(by: 6), 0...10))
            }
            if count(.stable) == 0 { out.append((.stable, Turn.toward(base, front, by: 7), 0...8)) }
            if count(.siegeWorkshop) == 0 && count(.stable) > 0 {
                out.append((.siegeWorkshop, Turn.toward(base, front, by: 6), 0...8))
            }
        }
        if view.age >= .alchemy {
            // The alchemist's workshop first, for the gunpowder every Alchemy warfighter needs; then the castle.
            if count(.alchemistsWorkshop) == 0 { out.append((.alchemistsWorkshop, homeSide(by: 6), 0...10)) }
            if count(.castle) == 0 && count(.alchemistsWorkshop) > 0 {
                out.append((.castle, Turn.toward(base, front, by: 7), 0...10))
            }
        }
        if view.age >= .industrial {
            // An oil well on the nearest field with oil and no well, the nearer fields first and then the
            // distant ones as those run dry; the factory; a railway depot at home and a second toward the front.
            if let field = unclaimedOilField() { out.append((.oilWell, field, 0...1)) }
            if count(.factory) == 0 { out.append((.factory, Turn.toward(base, front, by: 7), 0...10)) }
            if count(.railwayDepot) == 0 {
                out.append((.railwayDepot, homeSide(by: 5), 0...8))
            } else if count(.railwayDepot) == 1 && !completeBuildings(.railwayDepot).isEmpty {
                out.append((.railwayDepot, Turn.toward(base, front, by: 16), 0...8))
            }
        }
        if count(.storagePit) < 4, let cluster = distantCluster() { out.append((.storagePit, cluster, 0...5)) }
        // A boat house on the shore of the nearest water that holds fish or rocks (ruled 2026-11-21).
        if count(.boatHouse) == 0, completeBuildings(.townCentre).count > 0, let water = nearestWaterSite(to: base, within: 20) {
            out.append((.boatHouse, water.tile.centre, 1...8))
        }
        out += wall()
        // The newest age's buildings first, so that the age's own come before more of the older ones.
        let ranked = out.enumerated().sorted { a, b in
            let x = catalogue.stats(a.element.0).age, y = catalogue.stats(b.element.0).age
            return x != y ? x > y : a.offset < b.offset
        }
        return ranked.map(\.element)
    }

    /// Engineers construct a building near `anchor`, if one can be spared, the
    /// cost can be paid, and a place can be found; a cost that cannot yet be paid
    /// is held back from spending of lower priority.
    @discardableResult
    func construct(_ kind: BuildingKind, near anchor: MapPosition, rings: ClosedRange<Int>,
                   builders wanted: Int = 1, urgent: Bool = false) -> Bool {
        let stats = catalogue.stats(kind)
        guard stats.age <= view.age else { return false }
        let team = spareEngineers(near: anchor, count: wanted, urgent: urgent)
        guard !team.isEmpty else { return false }
        guard canPay(stats.cost, urgent: urgent) else {
            setAside(stats.cost)
            return false
        }
        guard let origin = site(for: kind, near: anchor, rings: rings) else { return false }
        let ids = team.map(\.id)
        give(.construct(engineers: ids, building: kind, at: origin), to: ids)
        pay(stats.cost)
        memory.plans.append(Plan(kind: kind, origin: origin, builders: ids, tick: view.tick, cost: stats.cost))
        ground?.add(kind, at: origin)
        return true
    }

    /// Engineers not already building: the idle first, then those doing
    /// something else, and those constructing only when the need is urgent.
    /// Beyond the first, only idle engineers are taken.
    private func spareEngineers(near point: MapPosition, count: Int, urgent: Bool) -> [EntityView] {
        let planned = memory.plans.flatMap(\.builders)
        var scored: [(score: Double, engineer: EntityView)] = []
        for engineer in engineers where isFree(engineer) && !planned.contains(engineer.id) {
            var score = engineer.position.distance(to: point)
            switch engineer.activity {
            case .idle: break
            case .constructing:
                if !urgent { continue }
                score += 1000
            default: score += 20
            }
            scored.append((score, engineer))
        }
        scored.sort { $0.score != $1.score ? $0.score < $1.score : $0.engineer.id < $1.engineer.id }
        guard let first = scored.first else { return [] }
        let others = scored.dropFirst().filter { $0.engineer.activity == .idle }.prefix(count - 1).map(\.engineer)
        return [first.engineer] + others
    }

    /// The side of the base away from its resources, so that houses and pens do
    /// not stand between workers and their work.
    /// Once the barracks stands, a short wall across the side facing the
    /// opponents, nine tiles out: a palisade in the Bronze age, stone in the
    /// Iron age. One tile is wanted at a time, the nearest gap first.
    private func wall() -> [(BuildingKind, MapPosition, ClosedRange<Int>)] {
        guard view.age >= .bronze, !completeBuildings(.barracks).isEmpty, !threatened else { return [] }
        let kind: BuildingKind = view.age >= .iron ? .stoneWall : .palisade
        let middle = Turn.toward(base, front, by: 9)
        let dx = middle.x - base.x, dy = middle.y - base.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        // Across the line to the front, a tile apart.
        let across = MapPosition(x: -dy / length, y: dx / length)
        let walls = buildings.filter { $0.kind == .building(.palisade) || $0.kind == .building(.stoneWall) }
        for k in [0, 1, -1, 2, -2, 3, -3] {
            let spot = MapPosition(x: middle.x + across.x * Double(k), y: middle.y + across.y * Double(k))
            let taken = walls.contains { $0.position.distance(to: spot) < 1 }
                || memory.plans.contains { $0.origin.centre.distance(to: spot) < 1 }
            // A spot that cannot hold the wall (water, a rock, a site) is passed over for the next.
            if !taken, site(for: kind, near: spot, rings: 0...0) != nil { return [(kind, spot, 0...0)] }
        }
        return []
    }

    /// The centre of the nearest oil field with oil left, within 40 tiles of the
    /// base, that no well of the player's stands on or is planned for; at most
    /// four wells at a time.
    private func unclaimedOilField() -> MapPosition? {
        guard count(.oilWell) < 4, memory.plans.allSatisfy({ $0.kind != .oilWell }) else { return nil }
        // A field under anyone's well, an ally's or an opponent's too, is taken.
        let wells = view.entities.filter { $0.kind == .building(.oilWell) }
        let fields = view.sites.filter { site in
            site.kind == .oilField && site.remaining > 0 && site.tile.centre.distance(to: base) <= 40
                && !wells.contains { $0.position.distance(to: site.tile.centre) < 1.5 }
        }
        return fields.min { ($0.tile.centre.distance(to: base), $0.id) < ($1.tile.centre.distance(to: base), $1.id) }?.tile.centre
    }

    private func homeSide(by distance: Double) -> MapPosition {
        let resources = surroundings().resources ?? front
        return Turn.toward(base, MapPosition(x: 2 * base.x - resources.x, y: 2 * base.y - resources.y), by: distance)
    }

    /// Where workers gather a resource a storage pit accepts, more than seven
    /// tiles from the edge of every building, standing or planned, that accepts
    /// it, with at least two of them close together.
    private func distantCluster() -> MapPosition? {
        let accepted = catalogue.stats(.storagePit).accepts
        var gatherers: [(position: MapPosition, resource: Resource)] = []
        for worker in workers {
            if case .gathering(let kind) = worker.activity, accepted.contains(kind.yield) {
                gatherers.append((worker.position, kind.yield))
            }
        }
        guard !gatherers.isEmpty else { return nil }
        var depots: [(centre: MapPosition, reach: Double, accepts: [Resource])] = []
        for building in buildings {
            guard case .building(let kind) = building.kind else { continue }
            let stats = catalogue.stats(kind)
            if !stats.accepts.isEmpty { depots.append((building.position, Double(stats.footprint.x) / 2, stats.accepts)) }
        }
        for plan in memory.plans {
            let stats = catalogue.stats(plan.kind)
            if !stats.accepts.isEmpty {
                depots.append((Placement.centre(plan.kind, origin: plan.origin, catalogue: catalogue),
                               Double(stats.footprint.x) / 2, stats.accepts))
            }
        }
        let far = gatherers.filter { gatherer in
            !depots.contains { $0.accepts.contains(gatherer.resource) && gatherer.position.distance(to: $0.centre) - $0.reach <= 7 }
        }.map(\.position)
        guard let first = far.first else { return nil }
        let near = far.filter { $0.distance(to: first) <= 6 }
        return near.count >= 2 ? Turn.mean(near) : nil
    }

    // MARK: Founding

    /// A player holding only a founder founds a town centre near an ally's
    /// buildings; it does nothing else in that action. Returns whether it holds only founders.
    func found() -> Bool {
        guard !founders.isEmpty, buildings.isEmpty, workers.isEmpty, engineers.isEmpty, scholars.isEmpty,
              warfighters.isEmpty, merchants.isEmpty else { return false }
        for founder in founders where !memory.plans.contains(where: { $0.builders.contains(founder.id) }) {
            let centres = allyBuildings.filter { $0.kind == .building(.townCentre) }
            let ally = Turn.nearest(centres, to: founder.position) ?? Turn.nearest(allyBuildings, to: founder.position)
            guard let origin = site(for: .townCentre, near: ally?.position ?? founder.position, rings: 5...16) else {
                continue
            }
            give(.found(founder: founder.id, at: origin), to: [founder.id])
            memory.plans.append(Plan(kind: .townCentre, origin: origin, builders: [founder.id], tick: view.tick,
                                     cost: ResourceAmounts()))
            ground?.add(.townCentre, at: origin)
        }
        return true
    }

    // MARK: Placement

    /// The nearest origin to `anchor`, ring by ring, where a building of `kind`
    /// may stand (`Placement.canPlace`, through `Ground.allows`) with a tile of
    /// open ground between it and every other building; failing that, without
    /// the open ground. Rings beyond `Turn.widestRing` are not searched.
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
                      !refused.contains(origin), ground.allows(kind, at: origin, in: view) else { continue }
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
