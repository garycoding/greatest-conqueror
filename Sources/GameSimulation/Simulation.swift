// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The rules of the game, for a match of two to six players in
/// any grouping of teams: the module's conformance to `GameSimulating`
/// (docs/architecture.md, "The seams").
///
/// Every figure comes from the setup's `Catalogue`.
///
/// Determinism: entities are kept in an array ordered by `EntityID` and sites in
/// one ordered by `SiteID`; each tick processes them in that order, and the
/// effect of a blow, a harvest or a death is immediate, so a later entity in
/// the same tick sees it. No outcome depends on the order of a `Dictionary` or a
/// `Set`. Within a tick: people and buildings act in ID order; the dead are then
/// removed; then defeat and the outcome are settled.
///
/// The cached grids (passability, sight counts, the spatial index, path-search
/// buffers) are derived from the state, rebuilt when a saved match is decoded,
/// and are neither encoded nor part of the checksum. Nor are the events awaiting
/// each player's next view, which depend on when views are taken and not on the
/// match itself.
public struct Simulation: GameSimulating {
    // MARK: The state, encoded and covered by the checksum

    /// The tables played by; the host's editor may replace them during play (`adopt`).
    internal(set) var catalogue: Catalogue
    let width: Int
    let height: Int
    let terrain: [Terrain]
    public internal(set) var tick = 0
    public internal(set) var outcome: MatchOutcome?
    public var isPaused = false
    /// The person who paused the match, whilst it is paused by one (requirement 30).
    public internal(set) var pausedBy: PlayerID?
    /// What the people see of the map; nil is `.explore` (`MapSight`).
    public internal(set) var sight: MapSight?
    /// In player order; `players[i].id == PlayerID(i)`.
    var players: [PlayerState]
    /// Ordered by `TeamID`.
    var teams: [TeamState]
    /// Ordered by `EntityID`. The dead stay, flagged, until the end of the tick.
    var entities: [Entity] = []
    /// Ordered by `SiteID`. An exhausted site stays with nothing remaining; views leave it out.
    var sites: [ResourceSite]
    var nextEntity = 1
    /// The match's source of chance. No rule draws on it yet; it is part of the state so that a saved match keeps its sequence.
    var generator: SeededGenerator

    // MARK: Caches, derived from the state

    var tables: Tables
    /// `EntityID.rawValue` → index into `entities`, or -1.
    var indexOfEntity: [Int32] = []
    /// `SiteID.rawValue` → index into `sites`, or -1.
    var indexOfSite: [Int32] = []
    /// Per tile: impassable terrain, a footprint, or a blocking site (`Placement`).
    var blocked: [Bool] = []
    /// Per tile: the id of the building whose footprint covers it, or -1.
    var buildingAt: [Int32] = []
    /// Per tile: the index of the blocking site that remains on it, or -1.
    var siteAt: [Int32] = []
    /// Per team and tile (`team * width * height + tile`): how many of the team's entities see it.
    var seen: [Int32] = []
    /// Per player: population places taken by living people.
    var population: [Int] = []
    /// Per player: housing of complete buildings.
    var housing: [Int] = []
    var buckets = Buckets()
    var search = PathSearch()
    /// Path searches allowed in one tick (`Rule.searchesPerTick`).
    var searchBudget = Rule.searchesPerTick
    var searchesLeft = 0
    var deathsPending = false
    /// Defeat and founders are settled at the end of a tick in which something
    /// died or a founder's town centre was finished.
    var settlePending = false
    /// Navy ships that reached the shore this tick, to land their troops once
    /// every entity has acted (`landPassengers`).
    var landings: [(ship: EntityID, at: MapPosition)] = []

    // MARK: Starting a match

    public init(setup: MatchSetup) {
        let map = setup.map
        precondition(setup.players.enumerated().allSatisfy { $0.element.id.rawValue == $0.offset },
                     "players are numbered from 0 in setup order")
        precondition(map.starts.count >= setup.players.count, "the map has a start for every player")
        catalogue = setup.catalogue
        sight = setup.sight
        width = map.width
        height = map.height
        terrain = map.terrain
        generator = SeededGenerator(seed: setup.seed)
        sites = map.sites.sorted { $0.id < $1.id }
        let teamIDs = Array(Set(setup.players.map(\.team))).sorted()
        teams = teamIDs.map { team in
            TeamState(id: team, members: setup.players.indices.filter { setup.players[$0].team == team },
                      explored: BitGrid(count: map.width * map.height))
        }
        players = setup.players.map { p in
            PlayerState(id: p.id, civilization: p.civilization, team: p.team,
                        teamIndex: teamIDs.firstIndex(of: p.team) ?? 0, isHuman: p.controller == .human,
                        resources: setup.catalogue.startingResources)
        }
        // A match begun in a later age (ruled 2026-11-21): every player is in
        // that age from the start, and holds besides the standard stock what
        // the advances to it would have cost, so that the age's own work can begin.
        var age = Age.towns
        while age < setup.firstAge, let advance = catalogue.advance(from: age), let next = age.next {
            for p in players.indices { players[p].resources = players[p].resources + advance.cost }
            age = next
        }
        for p in players.indices { players[p].age = age }
        tables = Tables(setup.catalogue)
        rebuildCaches()
        for (i, p) in setup.players.enumerated() {
            let centre = placeBuilding(.townCentre, owner: p.id, origin: map.starts[i], complete: true)
            for k in 0..<catalogue.startingPeople {
                spawnPerson(.worker, owner: p.id, at: freeTile(besideBuilding: centre, index: k).centre)
            }
        }
    }

    // MARK: Encoding

    enum CodingKeys: String, CodingKey {
        case catalogue, width, height, terrain, tick, outcome, isPaused, players, teams, entities, sites, nextEntity, generator
        case sight, pausedBy
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        catalogue = try c.decode(Catalogue.self, forKey: .catalogue)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        terrain = try c.decode([Terrain].self, forKey: .terrain)
        tick = try c.decode(Int.self, forKey: .tick)
        outcome = try c.decodeIfPresent(MatchOutcome.self, forKey: .outcome)
        isPaused = try c.decode(Bool.self, forKey: .isPaused)
        pausedBy = try c.decodeIfPresent(PlayerID.self, forKey: .pausedBy)
        sight = try c.decodeIfPresent(MapSight.self, forKey: .sight)
        players = try c.decode([PlayerState].self, forKey: .players)
        teams = try c.decode([TeamState].self, forKey: .teams)
        entities = try c.decode([Entity].self, forKey: .entities)
        sites = try c.decode([ResourceSite].self, forKey: .sites)
        nextEntity = try c.decode(Int.self, forKey: .nextEntity)
        generator = try c.decode(SeededGenerator.self, forKey: .generator)
        tables = Tables(catalogue)
        rebuildCaches()
    }

    /// Rebuild every cache from the state: at the start, and after decoding.
    mutating func rebuildCaches() {
        tables = Tables(catalogue)
        let count = width * height
        blocked = terrain.map { !$0.isPassable }
        buildingAt = Array(repeating: -1, count: count)
        siteAt = Array(repeating: -1, count: count)
        indexOfSite = Array(repeating: -1, count: (sites.map(\.id.rawValue).max() ?? -1) + 1)
        for (i, site) in sites.enumerated() {
            indexOfSite[site.id.rawValue] = Int32(i)
            if site.kind.blocksTile && site.remaining > 0 && inMap(site.tile) {
                siteAt[tileIndex(site.tile)] = Int32(i)
                blocked[tileIndex(site.tile)] = true
            }
        }
        indexOfEntity = Array(repeating: -1, count: nextEntity)
        seen = Array(repeating: 0, count: teams.count * count)
        population = Array(repeating: 0, count: players.count)
        housing = Array(repeating: 0, count: players.count)
        for i in entities.indices {
            let e = entities[i]
            indexOfEntity[e.id.rawValue] = Int32(i)
            guard e.alive else { continue }
            if let kind = e.buildingKind {
                for t in footprintTiles(origin: e.origin, size: e.size) where inMap(t) {
                    buildingAt[tileIndex(t)] = Int32(e.id.rawValue)
                    blocked[tileIndex(t)] = true
                }
                if e.complete { housing[e.owner.rawValue] += tables.building(kind).housing }
            } else if let kind = e.unitKind {
                population[e.owner.rawValue] += tables.unit(kind).population
                for passenger in e.passengers ?? [] {
                    population[e.owner.rawValue] += passenger.unitKind.map { tables.unit($0).population } ?? 0
                }
            }
            stampSight(of: i, by: 1)
        }
        search = PathSearch(count: count)
        buckets = Buckets()
    }

    // MARK: The tick

    public mutating func step() {
        guard !isPaused, outcome == nil else { return }
        tick += 1
        searchesLeft = searchBudget
        buckets.rebuild(entities: entities, width: width, height: height)
        let count = entities.count
        for i in 0..<count where entities[i].alive {
            if entities[i].isPerson { updatePerson(i) } else { updateBuilding(i) }
        }
        if !landings.isEmpty { landPassengers() }
        if deathsPending || settlePending {
            if deathsPending { removeDead() }
            settleTeams()
        }
    }

    /// Take the dead out of `entities`, keeping the order of the living.
    mutating func removeDead() {
        var kept = 0
        for i in entities.indices where entities[i].alive {
            if kept != i { entities.swapAt(kept, i) }
            kept += 1
        }
        for i in kept..<entities.count { indexOfEntity[entities[i].id.rawValue] = -1 }
        entities.removeLast(entities.count - kept)
        for i in entities.indices { indexOfEntity[entities[i].id.rawValue] = Int32(i) }
        deathsPending = false
        // The spatial index holds indices into `entities`, which have just moved.
        buckets.rebuild(entities: entities, width: width, height: height)
    }

    // MARK: Lookups

    @inline(__always) func inMap(_ t: GridPoint) -> Bool { t.x >= 0 && t.y >= 0 && t.x < width && t.y < height }
    @inline(__always) func inMap(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }
    @inline(__always) func tileIndex(_ t: GridPoint) -> Int { t.y * width + t.x }
    /// Whether a person may stand on or cross the tile.
    @inline(__always) func open(_ x: Int, _ y: Int) -> Bool { inMap(x, y) && !blocked[y * width + x] }
    @inline(__always) func open(_ t: GridPoint) -> Bool { open(t.x, t.y) }

    /// Whether a boat may enter a tile (ruled 2026-11-21): water, and no rock
    /// standing in it.
    @inline(__always) func openAfloat(_ x: Int, _ y: Int) -> Bool {
        guard inMap(x, y) else { return false }
        let k = y * width + x
        guard terrain[k].isWater else { return false }
        let s = siteAt[k]
        return s < 0 || !sites[Int(s)].kind.blocksTile
    }

    /// `open` for people on foot, `openAfloat` for boats.
    @inline(__always) func open(_ x: Int, _ y: Int, afloat: Bool) -> Bool { afloat ? openAfloat(x, y) : open(x, y) }

    /// The index of a living entity.
    func index(of id: EntityID) -> Int? {
        guard id.rawValue >= 0, id.rawValue < indexOfEntity.count else { return nil }
        let i = Int(indexOfEntity[id.rawValue])
        return i >= 0 && entities[i].alive ? i : nil
    }

    /// The entity with this id, alive, for tests and the interface's questions.
    func entity(_ id: EntityID) -> Entity? { index(of: id).map { entities[$0] } }

    /// The index of a site that still holds something.
    func siteIndex(of id: SiteID) -> Int? {
        guard id.rawValue >= 0, id.rawValue < indexOfSite.count else { return nil }
        let i = Int(indexOfSite[id.rawValue])
        return i >= 0 && sites[i].remaining > 0 ? i : nil
    }

    /// The player slot of an id, if the player is in the match.
    func slot(_ player: PlayerID) -> Int? { player.rawValue >= 0 && player.rawValue < players.count ? player.rawValue : nil }

    @inline(__always) func teamOf(_ player: PlayerID) -> Int { players[player.rawValue].teamIndex }

    func footprintTiles(origin: GridPoint, size: GridPoint) -> [GridPoint] {
        var tiles: [GridPoint] = []
        for dy in 0..<size.y { for dx in 0..<size.x { tiles.append(GridPoint(origin.x + dx, origin.y + dy)) } }
        return tiles
    }

    func populationLimit(_ player: Int) -> Int { min(housing[player], catalogue.populationMaximum) }

    /// Population places held by people queued at the player's buildings.
    func queuedPopulation(_ player: Int) -> Int {
        var total = 0
        for e in entities where e.alive && e.owner.rawValue == player && !e.queue.isEmpty {
            for kind in e.queue { total += tables.unit(kind).population }
        }
        return total
    }

    /// Record an event for a player's next view.
    mutating func record(_ event: GameEvent, for player: Int) {
        players[player].events.append(event)
        if players[player].events.count > Rule.eventLimit { players[player].events.removeFirst() }
    }

    // MARK: Creating entities

    /// Add a person at a position, beside which nothing is checked.
    @discardableResult
    mutating func spawnPerson(_ kind: UnitKind, owner: PlayerID, at position: MapPosition) -> EntityID {
        let stats = tables.unit(kind)
        let health = stats.figures(at: players[owner.rawValue].age).health
        let id = EntityID(nextEntity)
        nextEntity += 1
        let entity = Entity(id: id, owner: owner, kind: .unit(kind), position: position, origin: position.tile,
                            size: GridPoint(1, 1), health: health, maxHealth: health, sight: stats.sight,
                            stamp: position.tile)
        indexOfEntity.append(Int32(entities.count))
        entities.append(entity)
        population[owner.rawValue] += stats.population
        stampSight(of: entities.count - 1, by: 1)
        return id
    }

    /// Add a building, complete or just begun, blocking its footprint and moving
    /// anyone standing there to the nearest open tile. Returns its index.
    @discardableResult
    mutating func placeBuilding(_ kind: BuildingKind, owner: PlayerID, origin: GridPoint, complete: Bool) -> Int {
        let stats = tables.building(kind)
        let health = stats.figures(at: players[owner.rawValue].age).health
        let id = EntityID(nextEntity)
        nextEntity += 1
        var entity = Entity(id: id, owner: owner, kind: .building(kind),
                            position: Placement.centre(kind, origin: origin, catalogue: catalogue), origin: origin,
                            size: stats.footprint, health: complete ? health : 1, maxHealth: health,
                            sight: stats.sight, stamp: origin)
        entity.complete = complete
        entity.built = complete ? stats.buildTime : 0
        indexOfEntity.append(Int32(entities.count))
        entities.append(entity)
        let index = entities.count - 1
        let tiles = footprintTiles(origin: origin, size: stats.footprint).filter(inMap)
        for t in tiles {
            buildingAt[tileIndex(t)] = Int32(id.rawValue)
            blocked[tileIndex(t)] = true
        }
        if complete { housing[owner.rawValue] += stats.housing }
        stampSight(of: index, by: 1)
        moveAside(from: tiles)
        return index
    }

    /// Move the people standing on newly blocked tiles to the nearest open tile.
    mutating func moveAside(from tiles: [GridPoint]) {
        guard let first = tiles.first else { return }
        var low = first, high = first
        for t in tiles { low = GridPoint(min(low.x, t.x), min(low.y, t.y)); high = GridPoint(max(high.x, t.x), max(high.y, t.y)) }
        for i in entities.indices where entities[i].alive && entities[i].isPerson {
            let t = entities[i].position.tile
            guard t.x >= low.x, t.y >= low.y, t.x <= high.x, t.y <= high.y, blocked[tileIndex(t)] else { continue }
            if let free = nearestOpenTile(to: t) {
                entities[i].position = free.centre
                entities[i].route = Route()
                restamp(i)
            }
        }
    }

    /// The open tile nearest a tile, the tile itself if open.
    func nearestOpenTile(to t: GridPoint) -> GridPoint? {
        if open(t) { return t }
        for r in 1...max(width, height) {
            var best: GridPoint?
            var bestDistance = Int.max
            for y in (t.y - r)...(t.y + r) {
                for x in (t.x - r)...(t.x + r) where abs(x - t.x) == r || abs(y - t.y) == r {
                    guard open(x, y) else { continue }
                    let d = (x - t.x) * (x - t.x) + (y - t.y) * (y - t.y)
                    if d < bestDistance { best = GridPoint(x, y); bestDistance = d }
                }
            }
            if let best { return best }
        }
        return nil
    }

    /// An open tile beside a building's footprint: the open tiles of the nearest
    /// ring around it that has any, the front of the building (toward the viewer)
    /// first, taken in turn by `index`.
    func freeTile(besideBuilding building: Int, index: Int, afloat: Bool = false) -> GridPoint {
        freeTile(beside: entities[building].origin, size: entities[building].size, index: index, afloat: afloat)
    }

    /// The same, on the water for a boat.
    func freeTile(beside origin: GridPoint, size: GridPoint, index: Int, afloat: Bool = false) -> GridPoint {
        for r in 1...max(width, height) {
            var ring: [GridPoint] = []
            let x0 = origin.x - r, x1 = origin.x + size.x - 1 + r, y0 = origin.y - r, y1 = origin.y + size.y - 1 + r
            for y in y0...y1 {
                for x in x0...x1 where (x == x0 || x == x1 || y == y0 || y == y1) && open(x, y, afloat: afloat) {
                    ring.append(GridPoint(x, y))
                }
            }
            if !ring.isEmpty {
                ring.sort { a, b in a.x + a.y != b.x + b.y ? a.x + a.y > b.x + b.y : a.x < b.x }
                return ring[index % ring.count]
            }
        }
        return origin
    }
}
