// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Fixed sample maps and views, so that the drawing, the interface and the
/// computer player can be built and tested before the simulation exists. They
/// are deterministic: the same call gives the same value.
public enum Samples {
    /// A building's footprint origin, or the tile a person stands on.
    private static func tile(_ kind: EntityKind, _ position: MapPosition) -> GridPoint {
        if case .building(let b) = kind { return Placement.origin(b, centre: position) }
        return position.tile
    }

    /// A 32 × 32 map for two players: grass, a forest to the north-west, a lake
    /// to the south-east, and sites of every kind on land.
    public static func map() -> GameMap {
        let w = 32, h = 32
        var terrain = Array(repeating: Terrain.grass, count: w * h)
        func set(_ x: Int, _ y: Int, _ t: Terrain) { terrain[y * w + x] = t }
        for y in 0..<6 { for x in 0..<8 { set(x, y, .forest) } }
        for y in 22..<28 { for x in 22..<29 { set(x, y, (x == 22 || y == 22) ? .shallowWater : .deepWater) } }
        for x in 10..<14 { set(x, 14, .dirt) }
        var sites: [ResourceSite] = []
        func site(_ kind: SiteKind, _ x: Int, _ y: Int) {
            let amount = Catalogue.standard.gathering.amount(kind)
            sites.append(ResourceSite(id: SiteID(sites.count), kind: kind, tile: GridPoint(x, y), remaining: amount))
        }
        for y in 0..<6 { for x in 0..<8 where (x + y) % 2 == 0 { site(.tree, x, y) } }
        site(.prey, 12, 4); site(.prey, 13, 4); site(.prey, 12, 5)
        site(.gold, 3, 12); site(.gold, 4, 12)
        site(.gold, 16, 9); site(.gold, 18, 9); site(.gold, 9, 18)
        site(.prey, 25, 14); site(.gold, 27, 18); site(.gold, 20, 20); site(.gold, 18, 26); site(.gold, 26, 8)
        return GameMap(width: w, height: h, terrain: terrain, sites: sites, starts: [GridPoint(8, 8), GridPoint(20, 12)])
    }

    /// The opening of a match for player 0 in the age of towns: a town centre
    /// and five workers, with the near half of the map explored.
    public static func townsAgeOpening() -> PlayerView {
        let map = map()
        let me = PlayerID(0)
        var entities: [EntityView] = []
        func add(_ kind: EntityKind, _ owner: PlayerID, _ x: Double, _ y: Double, _ activity: Activity = .idle, health: Int? = nil) {
            let maxHealth: Int
            switch kind {
            case .unit(let k): maxHealth = Catalogue.standard.stats(k).health
            case .building(let k): maxHealth = Catalogue.standard.stats(k).health
            }
            let position = MapPosition(x: x, y: y)
            entities.append(EntityView(id: EntityID(entities.count + 1), owner: owner, kind: kind, position: position,
                                       tile: tile(kind, position), facing: .right, health: health ?? maxHealth,
                                       maxHealth: maxHealth, activity: activity))
        }
        add(.building(.townCentre), me, 9.5, 9.5)
        add(.unit(.worker), me, 12, 9, .gathering(.prey))
        add(.unit(.worker), me, 5, 6, .gathering(.tree))
        add(.unit(.worker), me, 11, 12, .carrying(.food, 6))
        add(.unit(.worker), me, 8, 12, .gathering(.gold))
        add(.unit(.worker), me, 13, 11, .moving)
        var visibility = Array(repeating: TileVisibility.unexplored, count: map.width * map.height)
        for y in 0..<map.height { for x in 0..<map.width {
            let d = MapPosition(x: Double(x) + 0.5, y: Double(y) + 0.5).distance(to: MapPosition(x: 9.5, y: 9.5))
            visibility[y * map.width + x] = d < 9 ? .visible : (d < 14 ? .explored : .unexplored)
        } }
        let sites = map.sites.filter { visibility[$0.tile.y * map.width + $0.tile.x] != .unexplored }
        return PlayerView(
            tick: Tick.seconds(60), player: me, age: .towns,
            resources: ResourceAmounts([.food: 180, .wood: 140, .gold: 50]),
            population: 5, populationLimit: 5, ageProgress: 0.15,
            players: [
                PlayerSummary(id: me, civilization: .sumer, team: TeamID(0), isHuman: true, age: .towns, isDefeated: false),
                PlayerSummary(id: PlayerID(1), civilization: .egypt, team: TeamID(1), isHuman: false, age: .towns, isDefeated: false),
            ],
            mapWidth: map.width, mapHeight: map.height, terrain: map.terrain, visibility: visibility,
            entities: entities, sites: sites, events: [.trained(EntityID(5), .worker)], outcome: nil, isPaused: false)
    }

    /// Player 0 in the age of farms, with buildings of both ages, warfighters
    /// (a knight among them, of a later age, for the tests of the computer
    /// player's choices), an opponent's force in sight, and work under way.
    /// Its population is at its limit (15 of 15), so training is refused.
    public static func farmsAgeSkirmish() -> PlayerView {
        var view = townsAgeOpening()
        view.tick = Tick.seconds(600)
        view.age = .farms
        view.ageProgress = 0
        view.resources = ResourceAmounts([.food: 420, .wood: 310, .gold: 60])
        view.population = 15
        view.populationLimit = 15
        view.players[0].age = .farms
        view.players[1].age = .farms
        let me = PlayerID(0), them = PlayerID(1)
        var next = (view.entities.map(\.id.rawValue).max() ?? 0) + 1
        func add(_ kind: EntityKind, _ owner: PlayerID, _ x: Double, _ y: Double, _ activity: Activity, facing: Facing = .right, damage: Int = 0) {
            let maxHealth: Int
            switch kind {
            case .unit(let k): maxHealth = Catalogue.standard.stats(k).health
            case .building(let k): maxHealth = Catalogue.standard.stats(k).health
            }
            let position = MapPosition(x: x, y: y)
            view.entities.append(EntityView(id: EntityID(next), owner: owner, kind: kind, position: position, tile: tile(kind, position),
                                            facing: facing, health: maxHealth - damage, maxHealth: maxHealth, activity: activity))
            next += 1
        }
        add(.building(.house), me, 6, 10, .idle)
        add(.building(.house), me, 3, 10, .idle)
        add(.building(.boatHouse), me, 4, 8, .idle)
        add(.building(.barracks), me, 13.5, 6.5, .training(.spearman, 0.4, queued: 2))
        add(.building(.watchTower), me, 6.5, 14.5, .idle)
        add(.building(.watchTower), me, 15.5, 13.5, .underConstruction(0.6))
        add(.building(.watchTower), me, 14.5, 9.5, .idle)
        add(.unit(.worker), me, 16, 9.5, .gathering(.gold))
        add(.unit(.worker), me, 18, 9.5, .gathering(.gold))
        add(.unit(.worker), me, 15, 14, .constructing)
        add(.unit(.worker), me, 10, 15, .moving)
        add(.unit(.spearman), me, 17, 12, .fighting)
        add(.unit(.spearman), me, 16, 11, .fighting)
        add(.unit(.spearman), me, 18, 13, .fighting, damage: 12)
        add(.unit(.spearman), me, 15, 12, .fighting)
        add(.unit(.knight), me, 17, 14, .moving)
        add(.unit(.spearman), them, 19, 13, .fighting, facing: .left)
        add(.unit(.swordsman), them, 21, 12, .fighting, facing: .left, damage: 20)
        add(.unit(.spearman), them, 20, 14, .fighting, facing: .left)
        add(.building(.townCentre), them, 21.5, 13.5, .idle)
        for y in 0..<view.mapHeight { for x in 0..<view.mapWidth where x < 24 && y < 18 {
            view.visibility[y * view.mapWidth + x] = .visible
        } }
        let map = map()
        view.sites = map.sites.filter { view.visibility(at: $0.tile) != .unexplored }
        view.events = [.underAttack(EntityID(next - 6)), .ageReached(.farms)]
        return view
    }

    /// A two-player setup on the sample map: player 0 human (Sumer), player 1 a
    /// computer at standard difficulty (Egypt), on separate teams.
    public static func twoPlayerSetup(seed: UInt64 = 1) -> MatchSetup {
        MatchSetup(map: map(), players: [
            PlayerSetup(id: PlayerID(0), civilization: .sumer, team: TeamID(0), controller: .human),
            PlayerSetup(id: PlayerID(1), civilization: .egypt, team: TeamID(1), controller: .computer(.standard)),
        ], seed: seed)
    }
}
