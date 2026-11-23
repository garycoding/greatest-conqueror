// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// One action of the computer player. The view is sorted once into what the
/// player owns and what its allies and opponents show; each part of the action
/// (Economy.swift, Construction.swift, Military.swift) then adds orders,
/// spending from `budget` and marking every entity it orders, so that no entity
/// is given two orders and nothing is ordered that cannot be paid for.
///
/// It is a class, made and discarded within one call of `decide`, because its
/// parts call one another many times, and a debug build copies a struct of this
/// size at each such call.
final class Turn {
    let view: PlayerView
    let catalogue: Catalogue
    let tuning: Tuning
    let me: PlayerSummary
    var memory: Memory
    var generator: SeededGenerator
    /// The map's land and water regions (`Regions`).
    let regions: Regions
    var orders: [Order] = []

    /// What remains to spend: the view's resources, less what the buildings
    /// already ordered will cost, less what this action has spent.
    var budget: ResourceAmounts
    /// Held back for something wanted that cannot yet be paid for. Only urgent
    /// spending may use it.
    var reserve = ResourceAmounts()
    /// What the plan for the coming age costs (`demand`), worked out once in an action.
    var planned: ResourceAmounts?
    /// The buildings wanted (`wanted`), worked out once in an action.
    var wantedNow: [(BuildingKind, MapPosition, ClosedRange<Int>)]?
    /// Whether each entity, by `EntityID.rawValue`, has been given an order in
    /// this action (a person) or a training order (a building).
    private var ordered: [Bool]

    // What the player owns.
    /// Workers that gather and farm.
    var workers: [EntityView] = []
    /// Workers set aside to build and repair (`Tuning.builders`): the oldest.
    var builders: [EntityView] = []
    var warfighters: [EntityView] = []
    var doctors: [EntityView] = []
    var boats: [EntityView] = []
    var navy: [EntityView] = []
    /// Warfighters, doctors and workers aboard its navy ships: out of the view, but its own.
    var aboard = 0
    var buildings: [EntityView] = []
    /// People in training at its buildings, by `UnitKind.rawValue`, with those
    /// queued in this action. A queue is counted as the kind it is training.
    var training = [Int](repeating: 0, count: UnitKind.allCases.count)
    /// The population places those people will take.
    var trainingPopulation = 0
    /// Where the player stands: its town centre, or failing that its other
    /// buildings or its people.
    var base: MapPosition

    // What others show.
    /// Opponents' units in sight on land, cars and founders left out: nothing
    /// harms either, and what is on the water is out of reach from the land.
    var enemyUnits: [EntityView] = []
    /// Opponents' fishing boats and navy ships in sight, for its navy ships.
    var enemyVessels: [EntityView] = []
    /// The warfighters of allied computer players.
    var allyWarfighters: [EntityView] = []
    var allyBuildings: [EntityView] = []

    // Found during the action.
    /// Opponents' people among the player's buildings or near where it was struck (`defend`).
    var intruders: [EntityView] = []
    /// The warfighters among the intruders.
    var raiders = 0
    /// Whether raiders stand among its buildings, or it was struck in the last ten seconds.
    var threatened = false
    /// Every building in the view, whoever owns it, for the ground.
    private var placed: [(kind: BuildingKind, origin: GridPoint)] = []
    /// The occupied ground, made when it is first needed (`prepareGround`).
    var ground: Ground?
    /// The tiles its workers can walk to (`walkable`), found when first needed.
    private var reach: [Bool]?
    /// The sites around the base, gathered when first needed.
    private var nearby: Surroundings?
    /// The players by `PlayerID.rawValue`.
    private let summaries: [PlayerSummary?]
    /// `Catalogue.bonus` as a table, by attacker and defender `rawValue`.
    private let multipliers: [Double]
    private static let unitKinds = UnitKind.allCases.count

    init(view: PlayerView, catalogue: Catalogue, tuning: Tuning, me: PlayerSummary, memory: Memory,
         generator: SeededGenerator, regions: Regions) {
        self.view = view
        self.catalogue = catalogue
        self.tuning = tuning
        self.me = me
        self.memory = memory
        self.generator = generator
        self.regions = regions
        var held = view.resources
        for plan in memory.plans { held = held - plan.cost }
        for resource in Resource.allCases where held[resource] < 0 { held[resource] = 0 }
        budget = held
        base = MapPosition(x: Double(view.mapWidth) / 2, y: Double(view.mapHeight) / 2)
        ordered = Array(repeating: false, count: max(0, view.entities.last?.id.rawValue ?? 0) + 1)
        var summaries = [PlayerSummary?](repeating: nil, count: (view.players.map(\.id.rawValue).max() ?? -1) + 1)
        for summary in view.players where summary.id.rawValue >= 0 { summaries[summary.id.rawValue] = summary }
        self.summaries = summaries
        let kinds = Turn.unitKinds
        var multipliers = [Double](repeating: 1, count: kinds * kinds)
        // In reverse, so that the first listed wins, as in `Catalogue.bonus`.
        for bonus in catalogue.bonuses.reversed() {
            multipliers[bonus.attacker.rawValue * kinds + bonus.defender.rawValue] = bonus.multiplier
        }
        self.multipliers = multipliers

        // Through a buffer: this loop visits every entity (see `Ground.init`).
        view.entities.withUnsafeBufferPointer { entities in
            for i in 0..<entities.count {
                let entity = entities[i]
                if case .building(let kind) = entity.kind { placed.append((kind, entity.tile)) }
                if entity.owner == view.player {
                    switch entity.kind {
                    case .unit(let kind):
                        switch kind {
                        case .worker: workers.append(entity)
                        case .doctor: doctors.append(entity)
                        case .fishingBoat: boats.append(entity)
                        case .navyShip:
                            navy.append(entity)
                            aboard += entity.passengers ?? 0
                            if case .training(let kind, _, let queued)? = entity.making {
                                training[kind.rawValue] += queued
                                trainingPopulation += queued * catalogue.stats(kind).population
                            }
                        // A founder is never the computer player's to order (ruled 2026-11-22).
                        default: if kind.isWarfighter { warfighters.append(entity) }
                        }
                    case .building:
                        buildings.append(entity)
                        if case .training(let kind, _, let queued) = entity.activity {
                            training[kind.rawValue] += queued
                            trainingPopulation += queued * catalogue.stats(kind).population
                        }
                    }
                    continue
                }
                guard let owner = summary(entity.owner) else { continue }
                if owner.team == me.team {
                    switch entity.kind {
                    case .unit(let kind): if kind.isWarfighter && !owner.isHuman { allyWarfighters.append(entity) }
                    case .building: allyBuildings.append(entity)
                    }
                } else if !owner.isDefeated, case .unit(let kind) = entity.kind, kind.isUnit {
                    if kind.isAfloat { enemyVessels.append(entity) } else { enemyUnits.append(entity) }
                }
            }
        }
        // The oldest workers build (`Tuning.builders`), one for every five
        // workers, two from six; the view lists entities in id order.
        let setAside = min(tuning.builders(at: view.age), max(workers.count >= 6 ? 2 : 1, workers.count / 5), workers.count)
        builders = Array(workers.prefix(setAside))
        workers.removeFirst(setAside)
        if let centre = buildings.first(where: { $0.kind == .building(.townCentre) && Turn.isComplete($0) }) {
            base = centre.position
        } else if let first = buildings.first {
            base = first.position
        } else if let middle = Turn.mean((workers + builders + warfighters).map(\.position)) {
            base = middle
        }
    }

    func summary(_ player: PlayerID) -> PlayerSummary? {
        player.rawValue >= 0 && player.rawValue < summaries.count ? summaries[player.rawValue] : nil
    }

    /// Whether a player is an opponent: known, not defeated, and on another team.
    func isOpponent(_ owner: PlayerID) -> Bool {
        guard owner != view.player, let summary = summary(owner) else { return false }
        return summary.team != me.team && !summary.isDefeated
    }

    /// How much harder `attacker` strikes `defender` than `defender` strikes it back (`Catalogue.bonuses`).
    func edge(_ attacker: UnitKind, over defender: UnitKind) -> Double {
        let kinds = Turn.unitKinds
        return multipliers[attacker.rawValue * kinds + defender.rawValue] - multipliers[defender.rawValue * kinds + attacker.rawValue]
    }

    /// The mean position of the sites within twelve tiles of the base, and
    /// whether wild food (prey or fruit bushes) remains within fourteen: one
    /// pass over the sites, made once.
    func surroundings() -> Surroundings {
        if let nearby { return nearby }
        var x = 0.0, y = 0.0, n = 0.0
        var wildFoodNear = false
        let bx = base.x, by = base.y
        view.sites.withUnsafeBufferPointer { sites in
            for i in 0..<sites.count where sites[i].remaining > 0 {
                let sx = Double(sites[i].tile.x) + 0.5, sy = Double(sites[i].tile.y) + 0.5
                let d = ((sx - bx) * (sx - bx) + (sy - by) * (sy - by)).squareRoot()
                if d < 12 { x += sx; y += sy; n += 1 }
                if d < 14 && (sites[i].kind == .prey || sites[i].kind == .fruit) { wildFoodNear = true }
            }
        }
        let found = Surroundings(resources: n > 0 ? MapPosition(x: x / n, y: y / n) : nil, wildFoodNear: wildFoodNear)
        nearby = found
        return found
    }

    /// The parts of an action, in their order of priority.
    func play() {
        memory.farmOrders = []
        remember()
        advance()
        defend()
        build()
        trainAtTownCentre()
        trainArmy()
        trainNavy()
        trainDoctors()
        campaign()
        ferry()
        scout()
        employWorkers()
        rebalanceWorkers()
        employBuilders()
        trainBoats()
        sendBoats()
        sendNavy()
        accompanyArmy()
        guardTheShore()
    }

    // MARK: Spending and ordering

    /// Whether `cost` can be paid from what remains; only urgent spending may use the reserve.
    func canPay(_ cost: ResourceAmounts, urgent: Bool = false) -> Bool {
        let needed = cost.amounts, held = budget.amounts, kept = reserve.amounts
        for i in needed.indices where needed[i] > 0 && held[i] - (urgent ? 0 : kept[i]) < needed[i] { return false }
        return true
    }

    func pay(_ cost: ResourceAmounts) { budget = budget - cost }

    /// Holds `cost` back from spending of lower priority in this action.
    func setAside(_ cost: ResourceAmounts) { reserve = reserve + cost }

    func give(_ order: Order, to entities: [EntityID]) {
        orders.append(order)
        for id in entities where id.rawValue >= 0 && id.rawValue < ordered.count { ordered[id.rawValue] = true }
    }

    /// Whether an entity in the view has not yet been given an order in this action.
    func isFree(_ entity: EntityView) -> Bool { !wasOrdered(entity.id) }

    private func wasOrdered(_ id: EntityID) -> Bool { id.rawValue >= 0 && id.rawValue < ordered.count && ordered[id.rawValue] }

    func train(_ kind: UnitKind, at building: EntityView) {
        let stats = catalogue.stats(kind)
        give(.train(at: building.id, unit: kind), to: [building.id])
        pay(stats.cost)
        training[kind.rawValue] += 1
        trainingPopulation += stats.population
    }

    /// The population the player will have once its queues are trained.
    var projectedPopulation: Int { view.population + trainingPopulation }

    /// The units queued at a maker, a building or a navy ship, counting a training order given in this action.
    func queueLength(_ building: EntityView) -> Int {
        var length = 0
        if case .training(_, _, let queued) = building.activity { length = queued }
        if case .training(_, _, let queued)? = building.making { length = queued }
        return length + (wasOrdered(building.id) ? 1 : 0)
    }

    func completeBuildings(_ kind: BuildingKind) -> [EntityView] {
        buildings.filter { $0.kind == .building(kind) && Turn.isComplete($0) }
    }

    /// The warfighters it has, those aboard its navy ships counted (all but a few of those aboard are warfighters).
    var armySize: Int { warfighters.count + aboard }

    /// The land region of the base.
    var homeLand: Int32 { regions.region(base) }

    /// Whether a point on land can be reached on foot from the base.
    func isReachableOnFoot(_ point: MapPosition) -> Bool {
        let home = homeLand
        let there = regions.region(point)
        return home <= 0 || there <= 0 || home == there
    }

    /// Buildings of a kind standing, begun or ordered.
    func count(_ kind: BuildingKind) -> Int {
        buildings.filter { $0.kind == .building(kind) }.count + memory.plans.filter { $0.kind == kind }.count
    }

    /// Where opponents are expected: the nearest known opponent's building, or
    /// failing that the middle of the map.
    var front: MapPosition {
        (nearestEnemyBuilding(to: base, onFoot: true) ?? nearestEnemyBuilding(to: base))?.position
            ?? MapPosition(x: Double(view.mapWidth) / 2, y: Double(view.mapHeight) / 2)
    }

    /// The known opponent's building nearest a point; with `onFoot`, of those
    /// on the same land as the point.
    func nearestEnemyBuilding(to point: MapPosition, onFoot: Bool = false) -> KnownBuilding? {
        var best: KnownBuilding?
        var bestDistance = Double.infinity
        for building in memory.enemies where (!onFoot || isReachableFrom(point, building.position))
            && !memory.passedOver.contains(where: { $0.id == building.id }) {
            let d = building.position.distance(to: point)
            if d < bestDistance { best = building; bestDistance = d }
        }
        return best
    }

    /// The tiles its workers can walk to as the ground stands now, by
    /// `y * width + x`: found once in an action, when first needed, from the
    /// tiles its workers stand on, through every tile a person can stand on.
    func walkable() -> [Bool] {
        if let reach { return reach }
        prepareGround()
        let w = view.mapWidth, h = view.mapHeight
        var out = [Bool](repeating: false, count: w * h)
        guard let ground else { return out }
        var stack: [Int] = []
        for person in workers + builders {
            let t = person.position.tile
            guard ground.isInside(t), !out[t.y * w + t.x] else { continue }
            out[t.y * w + t.x] = true
            stack.append(t.y * w + t.x)
        }
        while let here = stack.popLast() {
            let x = here % w, y = here / w
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                guard nx >= 0, ny >= 0, nx < w, ny < h, !out[ny * w + nx],
                      ground.canStand(GridPoint(nx, ny), in: view) else { continue }
                out[ny * w + nx] = true
                stack.append(ny * w + nx)
            }
        }
        reach = out
        return out
    }

    /// Makes the ground from the view's buildings and the player's plans, if it is not yet made.
    func prepareGround() {
        guard ground == nil else { return }
        let plans = memory.plans.map { (kind: $0.kind, origin: $0.origin) }
        ground = Ground(placed: placed + plans, sites: view.sites, width: view.mapWidth, height: view.mapHeight,
                        catalogue: catalogue)
    }

    /// A point kept inside the map.
    func clamped(_ p: MapPosition) -> MapPosition {
        MapPosition(x: min(max(p.x, 0.5), Double(view.mapWidth) - 0.5),
                    y: min(max(p.y, 0.5), Double(view.mapHeight) - 0.5))
    }

    // MARK: Geometry

    static func isComplete(_ entity: EntityView) -> Bool {
        if case .underConstruction = entity.activity { return false }
        return true
    }

    static func unitKind(_ entity: EntityView) -> UnitKind? {
        if case .unit(let kind) = entity.kind { return kind }
        return nil
    }

    /// The nearest of `entities` to a point; of two as near, the first.
    static func nearest(_ entities: [EntityView], to point: MapPosition) -> EntityView? {
        var best: EntityView?
        var bestDistance = Double.infinity
        for entity in entities {
            let d = entity.position.distance(to: point)
            if d < bestDistance { best = entity; bestDistance = d }
        }
        return best
    }

    static func mean(_ points: [MapPosition]) -> MapPosition? {
        guard !points.isEmpty else { return nil }
        var x = 0.0, y = 0.0
        for p in points { x += p.x; y += p.y }
        return MapPosition(x: x / Double(points.count), y: y / Double(points.count))
    }

    /// The point `distance` from `a` in the direction of `b`, or `a` itself if they coincide.
    static func toward(_ a: MapPosition, _ b: MapPosition, by distance: Double) -> MapPosition {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0.001 else { return a }
        return MapPosition(x: a.x + dx / length * distance, y: a.y + dy / length * distance)
    }
}

/// What lies around the base (`Turn.surroundings`).
struct Surroundings {
    var resources: MapPosition?
    /// Whether prey or fruit bushes remain near the base.
    var wildFoodNear: Bool
}

/// The ground as the player sees it, made once per action from the view's
/// buildings and sites and the player's own plans, so that a search for a place
/// does not rebuild it for every tile it tries. It records, for each tile, the
/// building that covers it and the site on it.
///
/// Whether a building may stand is decided by `Placement.canPlace`.
/// `canPlace` asks only whether each tile of the footprint is occupied, so it
/// is given the tiles `Placement.occupied` finds for the buildings and sites on
/// the footprint's own tiles: on those tiles that set agrees with the one
/// `Placement.canPlace(_:at:in:)` builds for the whole view, with the player's
/// plans added. A place allowed here is therefore allowed by the view-level
/// rule too.
struct Ground {
    let width: Int
    let height: Int
    private var placed: [(kind: BuildingKind, origin: GridPoint)]
    private let sites: [ResourceSite]
    private let catalogue: Catalogue
    /// Footprint sizes by `BuildingKind.rawValue`.
    private let sizes: [GridPoint]
    /// The building covering each tile, by `y * width + x`, as an index into
    /// `placed` plus one; 0 where none does.
    private var building: [Int32]
    /// The site on each tile, by `y * width + x`, as an index into `sites` plus
    /// one, a site that blocks its tile preferred; 0 where none is.
    private var site: [Int32]

    init(placed: [(kind: BuildingKind, origin: GridPoint)], sites: [ResourceSite], width: Int, height: Int,
         catalogue: Catalogue) {
        self.width = width
        self.height = height
        self.placed = placed
        self.sites = sites
        self.catalogue = catalogue
        let sizes = BuildingKind.allCases.map { catalogue.stats($0).footprint }
        self.sizes = sizes
        var covering = [Int32](repeating: 0, count: width * height)
        for (i, building) in placed.enumerated() {
            Ground.mark(&covering, with: Int32(i + 1), size: sizes[building.kind.rawValue], at: building.origin,
                        width: width, height: height)
        }
        building = covering
        var on = [Int32](repeating: 0, count: width * height)
        // Through buffers: this loop visits every site, and a debug build's
        // checks on each array access would otherwise cost more than the work.
        on.withUnsafeMutableBufferPointer { grid in
            sites.withUnsafeBufferPointer { list in
                for i in 0..<list.count {
                    let t = list[i].tile
                    guard t.x >= 0, t.y >= 0, t.x < width, t.y < height else { continue }
                    let here = t.y * width + t.x
                    if grid[here] == 0 || (list[i].kind.blocksTile && list[i].remaining > 0) { grid[here] = Int32(i + 1) }
                }
            }
        }
        self.site = on
    }

    /// Adds a building the player has just ordered.
    mutating func add(_ kind: BuildingKind, at origin: GridPoint) {
        placed.append((kind, origin))
        let mark = Int32(placed.count), size = sizes[kind.rawValue], w = width, h = height
        Ground.mark(&building, with: mark, size: size, at: origin, width: w, height: h)
    }

    private static func mark(_ grid: inout [Int32], with value: Int32, size: GridPoint, at origin: GridPoint,
                             width: Int, height: Int) {
        guard origin.x < width, origin.y < height, origin.x + size.x > 0, origin.y + size.y > 0 else { return }
        for y in max(0, origin.y)..<min(height, origin.y + size.y) {
            for x in max(0, origin.x)..<min(width, origin.x + size.x) { grid[y * width + x] = value }
        }
    }

    func size(of kind: BuildingKind) -> GridPoint { sizes[kind.rawValue] }

    func isInside(_ tile: GridPoint) -> Bool { tile.x >= 0 && tile.y >= 0 && tile.x < width && tile.y < height }

    /// Whether a site that blocks its tile, with something left, stands at index `here`.
    private func isBlockedBySite(_ here: Int) -> Bool {
        let s = site[here]
        return s > 0 && sites[Int(s) - 1].kind.blocksTile && sites[Int(s) - 1].remaining > 0
    }

    /// Whether every tile of a footprint of `size` at `origin` is inside the
    /// map, with no building and no blocking site on it: a quick test, which the
    /// rule also makes, to pass over most places cheaply.
    func isFree(size: GridPoint, at origin: GridPoint) -> Bool {
        guard origin.x >= 0, origin.y >= 0, origin.x + size.x <= width, origin.y + size.y <= height else { return false }
        // `while` rather than `for` over ranges, here and in `isClear`: these run
        // for every place a search tries, and a debug build's range iterators
        // would otherwise cost more than the tests.
        var y = origin.y
        while y < origin.y + size.y {
            var x = origin.x
            while x < origin.x + size.x {
                let here = y * width + x
                if building[here] != 0 || isBlockedBySite(here) { return false }
                x += 1
            }
            y += 1
        }
        return true
    }

    /// Whether no building covers a tile of the ring around a footprint of
    /// `size` at `origin`, so that a tile of open ground surrounds it.
    func isClear(size: GridPoint, at origin: GridPoint) -> Bool {
        let left = origin.x - 1, right = origin.x + size.x, top = origin.y - 1, bottom = origin.y + size.y
        var x = left
        while x <= right {
            if covers(x, top) || covers(x, bottom) { return false }
            x += 1
        }
        var y = origin.y
        while y < bottom {
            if covers(left, y) || covers(right, y) { return false }
            y += 1
        }
        return true
    }

    private func covers(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height && building[y * width + x] != 0
    }

    /// Whether the rule (`Placement.canPlace`) lets a building stand there.
    func allows(_ kind: BuildingKind, at origin: GridPoint, in view: PlayerView) -> Bool {
        var near: [(kind: BuildingKind, origin: GridPoint)] = []
        var on: [ResourceSite] = []
        for tile in Placement.footprint(kind, at: origin, catalogue: catalogue) where isInside(tile) {
            let here = tile.y * width + tile.x
            if building[here] > 0 { near.append(placed[Int(building[here]) - 1]) }
            if site[here] > 0 { on.append(sites[Int(site[here]) - 1]) }
        }
        let occupied = Placement.occupied(buildings: near, sites: on, catalogue: catalogue)
        return Placement.canPlace(kind, at: origin, width: width, height: height, terrain: view.terrain,
                                  occupied: occupied, explored: { view.visibility(at: $0) != .unexplored },
                                  catalogue: catalogue)
    }

    /// Whether a person can stand on a tile: inside the map, passable, and
    /// clear of buildings and of sites that block their tiles.
    /// Whether a worker can stand beside a building at `origin`: some tile
    /// along a side of its footprint, not at a corner, is open, so that it can
    /// be built at all.
    /// `reachable` says whether a worker can come to a tile at all (it is on the builders' land).
    func hasOpenSide(size: GridPoint, at origin: GridPoint, in view: PlayerView,
                     reachable: (GridPoint) -> Bool = { _ in true }) -> Bool {
        func open(_ tile: GridPoint) -> Bool { canStand(tile, in: view) && reachable(tile) }
        for x in origin.x..<(origin.x + size.x) {
            if open(GridPoint(x, origin.y - 1)) || open(GridPoint(x, origin.y + size.y)) { return true }
        }
        for y in origin.y..<(origin.y + size.y) {
            if open(GridPoint(origin.x - 1, y)) || open(GridPoint(origin.x + size.x, y)) { return true }
        }
        return false
    }

    /// Whether a footprint of `size` at `origin` would close a way through: the
    /// ring of tiles around it is shut (by water, a building, or a site that
    /// blocks its tile) on two opposite sides, as on a strip of land between
    /// waters or a path cut through a wood. A building there could cut a
    /// player off from its opponents, or from its own land.
    func closesAWay(size: GridPoint, at origin: GridPoint, in view: PlayerView) -> Bool {
        func shut(_ x: Int, _ y: Int) -> Bool { !canStand(GridPoint(x, y), in: view) }
        var left = false, right = false, top = false, bottom = false
        var y = origin.y - 1
        while y <= origin.y + size.y {
            if shut(origin.x - 1, y) { left = true }
            if shut(origin.x + size.x, y) { right = true }
            y += 1
        }
        var x = origin.x - 1
        while x <= origin.x + size.x {
            if shut(x, origin.y - 1) { top = true }
            if shut(x, origin.y + size.y) { bottom = true }
            x += 1
        }
        return (left && right) || (top && bottom)
    }

    func canStand(_ tile: GridPoint, in view: PlayerView) -> Bool {
        guard isInside(tile) else { return false }
        let here = tile.y * width + tile.x
        return view.terrain(at: tile).isPassable && building[here] == 0 && !isBlockedBySite(here)
    }
}
