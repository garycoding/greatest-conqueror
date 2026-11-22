// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

extension PlayerView {
    /// Adds an entity with the next free id, as the samples do, so that the
    /// entities stay ordered by id.
    @discardableResult
    mutating func add(_ kind: EntityKind, owner: PlayerID, at x: Double, _ y: Double, _ activity: Activity = .idle) -> EntityID {
        let id = EntityID((entities.map(\.id.rawValue).max() ?? 0) + 1)
        let position = MapPosition(x: x, y: y)
        let health: Int
        let tile: GridPoint
        switch kind {
        case .unit(let unit):
            health = Catalogue.standard.stats(unit).health
            tile = position.tile
        case .building(let building):
            health = Catalogue.standard.stats(building).health
            tile = Placement.origin(building, centre: position)
        }
        entities.append(EntityView(id: id, owner: owner, kind: kind, position: position, tile: tile, facing: .right,
                                   health: health, maxHealth: health, activity: activity))
        return id
    }

    mutating func set(_ id: EntityID, _ activity: Activity) {
        if let i = entities.firstIndex(where: { $0.id == id }) { entities[i].activity = activity }
    }

    mutating func remove(_ ids: [EntityID]) { entities.removeAll { ids.contains($0.id) } }

    mutating func setVisibility(_ visibility: TileVisibility, where included: (GridPoint) -> Bool) {
        for y in 0..<mapHeight {
            for x in 0..<mapWidth where included(GridPoint(x, y)) { self.visibility[y * mapWidth + x] = visibility }
        }
    }

    /// The first entity of a kind belonging to a player.
    func first(_ kind: EntityKind, of owner: PlayerID) -> EntityView? {
        entities.first { $0.kind == kind && $0.owner == owner }
    }

    func owned(by owner: PlayerID) -> [EntityView] { entities.filter { $0.owner == owner } }
}

/// Views built from the samples, each changed to put the player in one situation.
enum TestViews {
    static let me = PlayerID(0)
    static let enemy = PlayerID(1)
    static let ally = PlayerID(2)

    /// The opening in the age of towns with a house that raises the limit to
    /// ten, and the lumberjack (#3) idle.
    static func openingWithRoom() -> PlayerView {
        var view = Samples.townsAgeOpening()
        view.add(.building(.house), owner: me, at: 6, 10)
        view.populationLimit = 10
        view.set(EntityID(3), .idle)
        return view
    }

    /// The opening in the age of towns with the workers to advance (nine, two
    /// houses' worth of room) and the advance's cost in hand.
    static func openingReadyToAdvance() -> PlayerView {
        var view = Samples.townsAgeOpening()
        view.add(.building(.house), owner: me, at: 6, 10)
        view.add(.building(.house), owner: me, at: 3, 10)
        for k in 0..<4 { view.add(.unit(.worker), owner: me, at: 11 + Double(k), 7, .gathering(.tree)) }
        view.population = 9
        view.populationLimit = 15
        view.ageProgress = 0
        view.resources = ResourceAmounts([.food: 420, .wood: 260, .gold: 50])
        return view
    }

    /// The skirmish in the age of farms after the fight: the opponents' force and the
    /// attack gone, at `tick`, with `extra` spearmen and archers idle beside the
    /// barracks and population room to spare.
    static func farmsArmy(extra: Int, tick: Int = Tick.seconds(20 * 60)) -> PlayerView {
        var view = Samples.farmsAgeSkirmish()
        view.remove(view.owned(by: enemy).filter { if case .unit = $0.kind { return true }; return false }.map(\.id))
        view.events = []
        view.tick = tick
        for i in 0..<extra {
            view.add(.unit(i % 2 == 0 ? .soldier1 : .soldier3), owner: me, at: 11 + Double(i % 5), 12 + Double(i / 5))
        }
        view.population = 15 + extra
        view.populationLimit = 40
        return view
    }

    /// A view in the age of farms of three players: the player and an allied computer player
    /// on one team against an opponent. The ally has a house nearer the player
    /// than any opponent's building and idle warfighters among the player's
    /// buildings; if `allyAttacking`, three of its warfighters fight beside an
    /// opponent's house in the far north-east. The player has eight warfighters.
    static func alliedAttack(allyAttacking: Bool) -> (view: PlayerView, farHouse: EntityID) {
        var view = farmsArmy(extra: 3)
        view.players.append(PlayerSummary(id: ally, civilization: .shang, team: TeamID(0), isHuman: false, age: .farms,
                                          isDefeated: false))
        view.population = 18
        view.populationLimit = 30
        for id in [18, 19, 20, 21] { view.set(EntityID(id), .idle) }
        let farHouse = view.add(.building(.house), owner: enemy, at: 29, 5)
        view.add(.building(.house), owner: ally, at: 16, 3)
        view.add(.unit(.soldier1), owner: ally, at: 11, 11)
        view.add(.unit(.soldier1), owner: ally, at: 12, 11)
        if allyAttacking {
            for (x, y) in [(27.0, 6.0), (28.0, 7.0), (30.0, 6.0)] {
                view.add(.unit(.soldier1), owner: ally, at: x, y, .fighting)
            }
        }
        view.setVisibility(.visible) { $0.x >= 24 && $0.y < 12 }
        return (view, farHouse)
    }

    /// A sequence of views with advancing ticks, through both ages, for the
    /// tests of determinism and of saving.
    static func sequence() -> [PlayerView] {
        var views: [PlayerView] = []
        let opening = Samples.townsAgeOpening()
        views.append(opening)
        var room = openingWithRoom()
        room.tick = opening.tick + Tick.seconds(2)
        views.append(room)
        var ready = openingReadyToAdvance()
        ready.tick = opening.tick + Tick.seconds(4)
        views.append(ready)
        var unknown = Samples.farmsAgeSkirmish()
        unknown.remove(unknown.owned(by: enemy).map(\.id))
        unknown.events = []
        unknown.tick = Tick.seconds(590)
        views.append(unknown)
        views.append(Samples.farmsAgeSkirmish())
        views.append(farmsArmy(extra: 10))
        var remembered = farmsArmy(extra: 10, tick: Tick.seconds(20 * 60 + 2))
        remembered.remove(remembered.owned(by: enemy).map(\.id))
        remembered.setVisibility(.explored) { $0.x >= 19 }
        views.append(remembered)
        return views
    }

    /// A view in the age of farms of four hundred entities on a 96 by 96 map, as a match
    /// of three players might show at twenty minutes, arranged so that one
    /// decision does as much as it can: the player is at its population limit,
    /// so a house must be placed, sixty workers are idle among some four
    /// hundred sites, raiders stand among its buildings, and an opponent's base
    /// and an ally's attack are in sight.
    static func crowded() -> PlayerView {
        let w = 96, h = 96
        var terrain = Array(repeating: Terrain.grass, count: w * h)
        var sites: [ResourceSite] = []
        func site(_ kind: SiteKind, _ x: Int, _ y: Int) {
            sites.append(ResourceSite(id: SiteID(sites.count), kind: kind, tile: GridPoint(x, y),
                                      remaining: Catalogue.standard.gathering.amount(kind)))
        }
        for (fx, fy) in [(2, 2), (40, 4), (4, 44), (60, 70)] {
            for y in fy..<(fy + 14) {
                for x in fx..<(fx + 14) {
                    terrain[y * w + x] = .forest
                    if (x + y) % 2 == 0 { site(.tree, x, y) }
                }
            }
        }
        for y in 30..<36 { for x in 44..<52 { terrain[y * w + x] = .deepWater } }
        for i in 0..<12 { site(.prey, 26 + i % 4, 8 + i / 4); site(.prey, 30 + i % 4, 80 + i / 4) }
        for i in 0..<6 { site(.gold, 8 + i, 30); site(.gold, 34, 20 + i); site(.gold, 36, 28 + i); site(.gold, 24 + i, 36) }
        for i in 0..<6 { site(.gold, 80 + i, 20); site(.gold, 70, 30 + i); site(.gold, 72, 70 + i); site(.gold, 50 + i, 90) }

        var view = PlayerView(
            tick: Tick.seconds(20 * 60), player: me, age: .farms,
            resources: ResourceAmounts([.food: 2000, .wood: 2000, .gold: 600]),
            population: 190, populationLimit: 190, ageProgress: 0,
            players: [
                PlayerSummary(id: me, civilization: .sumer, team: TeamID(0), isHuman: false, age: .farms, isDefeated: false),
                PlayerSummary(id: enemy, civilization: .egypt, team: TeamID(1), isHuman: false, age: .farms, isDefeated: false),
                PlayerSummary(id: ally, civilization: .shang, team: TeamID(0), isHuman: false, age: .farms, isDefeated: false),
            ],
            mapWidth: w, mapHeight: h, terrain: terrain, visibility: Array(repeating: .visible, count: w * h),
            entities: [], sites: sites, events: [], outcome: nil, isPaused: false)

        // The player's base, about (22, 22).
        let centre = view.add(.building(.townCentre), owner: me, at: 22.5, 22.5)
        for i in 0..<8 { view.add(.building(.house), owner: me, at: 16 + Double(i % 4) * 3, 16 + Double(i / 4) * 14) }
        view.add(.building(.barracks), owner: me, at: 30.5, 26.5, .training(.soldier1, 0.5, queued: 1))
        let pen = view.add(.building(.house), owner: me, at: 14, 26)
        view.add(.building(.boatHouse), owner: me, at: 18, 34)
        view.add(.building(.boatHouse), owner: me, at: 30, 12)
        view.add(.building(.tower), owner: me, at: 28.5, 30.5)
        for i in 0..<120 {
            let x = 14 + Double(i % 20), y = 18 + Double(i / 20) * 2
            let activity: Activity = switch i % 6 {
            case 0, 1, 2: .idle
            case 3: .gathering(.tree)
            case 4: .carrying(.wood, 6)
            default: .working
            }
            view.add(.unit(.worker), owner: me, at: x, y, activity)
        }
        for i in 0..<6 { view.add(.unit(.worker), owner: me, at: 20 + Double(i), 30, i < 3 ? .idle : .constructing) }
        for i in 0..<6 { view.add(.unit(.worker), owner: me, at: 21 + Double(i % 3), 21, .gathering(.gold)) }
        let kinds: [UnitKind] = [.soldier1, .soldier3, .knight1, .soldier1, .soldier3]
        for i in 0..<50 {
            view.add(.unit(kinds[i % 5]), owner: me, at: 32 + Double(i % 10), 20 + Double(i / 10), i % 3 == 0 ? .moving : .idle)
        }
        // Raiders among its buildings, one of which has struck a house.
        for i in 0..<6 { view.add(.unit(kinds[i % 3]), owner: enemy, at: 12 + Double(i), 28, .fighting) }
        view.events = [.underAttack(pen), .trained(centre, .worker)]

        // The ally's base, about (22, 78), and its attack on the opponent.
        view.add(.building(.townCentre), owner: ally, at: 22.5, 78.5)
        for i in 0..<6 { view.add(.building(.house), owner: ally, at: 16 + Double(i) * 3, 72) }
        view.add(.building(.barracks), owner: ally, at: 30.5, 80.5)
        for i in 0..<50 { view.add(.unit(.worker), owner: ally, at: 14 + Double(i % 10), 84 + Double(i / 10), .gathering(.tree)) }
        for i in 0..<30 {
            let attacking = i < 10
            view.add(.unit(kinds[i % 3]), owner: ally, at: attacking ? 70 + Double(i % 5) : 26 + Double(i % 10),
                     attacking ? 44 + Double(i / 5) : 74 + Double(i / 10), attacking ? .fighting : .idle)
        }

        // The opponent's base, about (76, 48).
        view.add(.building(.townCentre), owner: enemy, at: 76.5, 48.5)
        for i in 0..<6 { view.add(.building(.house), owner: enemy, at: 70 + Double(i) * 3, 56) }
        view.add(.building(.barracks), owner: enemy, at: 84.5, 44.5)
        view.add(.building(.tower), owner: enemy, at: 72.5, 42.5)
        for i in 0..<60 { view.add(.unit(.worker), owner: enemy, at: 66 + Double(i % 12), 58 + Double(i / 12), .gathering(.gold)) }
        for i in 0..<41 { view.add(.unit(kinds[i % 3]), owner: enemy, at: 80 + Double(i % 6), 50 + Double(i / 6), .idle) }
        return view
    }
}
