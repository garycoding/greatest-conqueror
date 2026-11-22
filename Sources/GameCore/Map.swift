// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// A tile of the map. `x` runs toward the lower right of the screen and `y`
/// toward the lower left (docs/architecture.md, "Projection").
public struct GridPoint: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int
    public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    public init(x: Int, y: Int) { self.x = x; self.y = y }

    /// Row-major order, so that sorting grid points is deterministic.
    public static func < (a: GridPoint, b: GridPoint) -> Bool { (a.y, a.x) < (b.y, b.x) }

    /// The centre of this tile as a map position.
    public var centre: MapPosition { MapPosition(x: Double(x) + 0.5, y: Double(y) + 0.5) }

    public var description: String { "(\(x), \(y))" }
}

/// A point on the map in tile units: (0, 0) is the outer corner of tile (0, 0),
/// and (1, 1) the opposite corner of the same tile.
public struct MapPosition: Hashable, Codable, Sendable, CustomStringConvertible {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }

    /// The tile this position lies in.
    public var tile: GridPoint { GridPoint(Int(x.rounded(.down)), Int(y.rounded(.down))) }

    public func distance(to other: MapPosition) -> Double {
        let dx = other.x - x, dy = other.y - y
        return (dx * dx + dy * dy).squareRoot()
    }

    public var description: String { "(\(x), \(y))" }
}

/// The ground of a tile. Forest is the trees' ground; the trees themselves are
/// resource sites, which block the tile until felled (`Placement`). Water
/// cannot be crossed (requirement 25).
public enum Terrain: Int, CaseIterable, Codable, Sendable, Hashable {
    case grass, dirt, sand, forest, shallowWater, deepWater

    /// Whether people on foot and vehicles can enter the tile.
    public var isPassable: Bool { self != .shallowWater && self != .deepWater }

    /// Whether a building may stand on the tile.
    public var isBuildable: Bool { isPassable }
}

/// The kinds of resource site on the map (requirement 9).
public enum SiteKind: Int, CaseIterable, Codable, Sendable, Hashable {
    /// A tree, felled for wood.
    case tree
    /// Deer, hunted for food.
    case prey
    /// A gold mine: a rock on land, mined by workers, or in the water, mined by boats.
    case gold
    /// One tile of a shoal of fish in the water, 2 × 2 tiles to a shoal
    /// (ruled 2026-11-21); only boats gather it, and they sail over it.
    case fish
    /// A fruit bush on land, gathered by workers for food (ruled 2026-11-22).
    /// Last, so that the other kinds keep their raw values.
    case fruit

    /// Whether the site occupies its tile, so that nothing walks or is built
    /// there whilst it remains. Prey and fish do not; trees, gold and fruit
    /// bushes do (`Placement`; the bush ruled 2026-11-22).
    public var blocksTile: Bool { self != .prey && self != .fish }

    /// What gathering at the site yields.
    public var yield: Resource {
        switch self {
        case .tree: .wood
        case .prey, .fish, .fruit: .food
        case .gold: .gold
        }
    }
}

extension Terrain {
    /// Whether the tile is water, on which only boats move (ruled 2026-11-21).
    public var isWater: Bool { self == .shallowWater || self == .deepWater }
}

/// A resource site and what remains in it.
public struct ResourceSite: Hashable, Codable, Sendable {
    public var id: SiteID
    public var kind: SiteKind
    public var tile: GridPoint
    public var remaining: Int

    public init(id: SiteID, kind: SiteKind, tile: GridPoint, remaining: Int) {
        self.id = id; self.kind = kind; self.tile = tile; self.remaining = remaining
    }
}

/// What a map generator is asked for.
/// How big the map is, chosen when the match is set up (ruled 2026-11-21): the
/// standard map, or one twice as wide and twice as tall, with four times the
/// room and four times the resources.
public enum MapSize: String, Hashable, Codable, Sendable, CaseIterable {
    case standard
    case large

    /// The map's width and height, in tiles.
    public var side: Int {
        switch self {
        case .standard: 96
        case .large: 192
        }
    }

    public var title: String {
        switch self {
        case .standard: "Standard"
        case .large: "Large"
        }
    }

    public var explanation: String {
        switch self {
        case .standard: "A map of 96 by 96 tiles."
        case .large: "A map of 192 by 192 tiles: four times the room, and four times the resources."
        }
    }
}

public struct MapRequest: Hashable, Codable, Sendable {
    public var width: Int
    public var height: Int
    /// The number of players, each of whom needs a fair start.
    public var playerCount: Int
    public var seed: UInt64
    /// Read for what each site holds (`GatheringStats.amount`).
    public var catalogue: Catalogue

    public init(width: Int = 96, height: Int = 96, playerCount: Int, seed: UInt64, catalogue: Catalogue = .standard) {
        self.width = width; self.height = height; self.playerCount = playerCount; self.seed = seed
        self.catalogue = catalogue
    }

    public init(size: MapSize, playerCount: Int, seed: UInt64, catalogue: Catalogue = .standard) {
        self.init(width: size.side, height: size.side, playerCount: playerCount, seed: seed, catalogue: catalogue)
    }
}

/// A generated map: its terrain, its resource sites, and a start for each player.
public struct GameMap: Hashable, Codable, Sendable {
    public var width: Int
    public var height: Int
    /// Row-major: the terrain of tile (x, y) is `terrain[y * width + x]`.
    public var terrain: [Terrain]
    /// Ordered by `SiteID`.
    public var sites: [ResourceSite]
    /// One per player, in player order: the tile on which the town centre's
    /// footprint begins (its smallest x and y).
    public var starts: [GridPoint]

    public init(width: Int, height: Int, terrain: [Terrain], sites: [ResourceSite], starts: [GridPoint]) {
        precondition(terrain.count == width * height, "terrain must hold width × height tiles")
        self.width = width; self.height = height; self.terrain = terrain; self.sites = sites; self.starts = starts
    }

    public func contains(_ p: GridPoint) -> Bool { p.x >= 0 && p.y >= 0 && p.x < width && p.y < height }

    public subscript(p: GridPoint) -> Terrain {
        get { terrain[p.y * width + p.x] }
        set { terrain[p.y * width + p.x] = newValue }
    }
}
