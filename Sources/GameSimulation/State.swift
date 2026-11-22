// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Constants of the rules that the catalogue does not hold: distances that mean
/// "beside", and limits that keep a tick's work bounded.
enum Rule {
    /// A person within this distance of a footprint, or of a site's tile, is beside it.
    static let besideReach = 0.75
    /// A person sent to a point stops within this distance of it.
    static let pointReach = 0.02
    /// The most path searches one tick carries out; the people beyond it wait a tick.
    static let searchesPerTick = 32
    /// The most tiles one path search examines.
    static let searchLimit = 16_384
    /// How often, at most, a person re-plans a route to a target that has moved tile.
    static let replanInterval = 10
    /// A person whose way stays blocked for this many ticks gives up.
    static let stuckLimit = 40
    /// A thing under attack is reported again only after this many ticks without harm.
    static let underAttackInterval = Tick.rate * 3
    /// The events kept for a player who has not asked for a view; older ones are dropped.
    static let eventLimit = 1_000
    /// The spacing of people sent together to one point.
    static let formationSpacing = 0.6
    /// How far from an exhausted site a worker looks for another of its kind.
    static let resiteRadius = 8.0
    /// The side of a cell of the spatial index, in tiles.
    static let bucketSize = 8
}

/// A grid of flags, packed into words, for what each team has explored.
struct BitGrid: Codable, Sendable, Hashable {
    private(set) var words: [UInt64]

    init(count: Int) { words = Array(repeating: 0, count: (count + 63) / 64) }

    subscript(index: Int) -> Bool {
        get { words[index >> 6] & (1 << UInt64(index & 63)) != 0 }
        set {
            if newValue { words[index >> 6] |= 1 << UInt64(index & 63) } else { words[index >> 6] &= ~(1 << UInt64(index & 63)) }
        }
    }
}

struct PlayerState: Codable, Sendable, Hashable {
    var id: PlayerID
    var civilization: Civilization
    var team: TeamID
    /// Index into `Simulation.teams`.
    var teamIndex: Int
    var isHuman: Bool
    var age: Age = .towns
    var resources: ResourceAmounts
    var isDefeated = false
    /// Events since the player's last view. Not part of the checksum: they depend
    /// on when views are taken, not on the match.
    var events: [GameEvent] = []
}

struct TeamState: Codable, Sendable, Hashable {
    var id: TeamID
    /// Indices into `Simulation.players`, in player order.
    var members: [Int]
    /// Tiles any member has ever seen. Sight is shared, so exploration is too.
    var explored: BitGrid
    var isDefeated = false
}

/// What a worker carries home.
struct Cargo: Codable, Sendable, Hashable {
    var kind: SiteKind
    var amount: Int
}

/// What a person is doing this tick, for the view's `Activity`.
enum Doing: UInt8, CaseIterable, Codable, Sendable, Hashable {
    case idle, moving, gathering, carrying, working, constructing, fighting
}

/// What a person has been told to do.
enum Task: Codable, Sendable, Hashable {
    case idle
    case move(MapPosition)
    /// `kind` and `tile` are kept so that the worker can find another site of the
    /// same kind nearby once this one is exhausted.
    case gather(site: SiteID, kind: SiteKind, tile: GridPoint)
    case work(EntityID)
    case demolish(EntityID)
    case attack(EntityID)
}

/// The way a person is following toward its goal.
struct Route: Codable, Sendable, Hashable {
    /// Tiles whose centres are to be passed, the next one last.
    var waypoints: [GridPoint] = []
    /// Steering straight at the goal, the way being clear.
    var direct = false
    var planned = false
    /// The search ended short of the goal, which cannot be reached.
    var partial = false
    /// The straight way was blocked: the next plan searches.
    var forceSearch = false
    /// The goal's anchor tile when planned, to notice a target that has moved.
    var plannedFor = GridPoint(-1, -1)
    var plannedAt = 0
    /// Ticks in a row in which the way was blocked.
    var stuck = 0
}

/// A person or a building.
struct Entity: Codable, Sendable, Hashable {
    var id: EntityID
    var owner: PlayerID
    var kind: EntityKind
    /// A person's position; a building's footprint centre.
    var position: MapPosition
    /// A building's footprint origin; for a person, unused.
    var origin: GridPoint
    /// A building's footprint; 1 × 1 for a person.
    var size: GridPoint
    var facing: Facing = .right
    var health: Int
    var maxHealth: Int
    var alive = true
    /// Ticks until the next blow.
    var cooldown = 0
    /// The tick of the last harm taken.
    var lastHurt = -1_000_000
    var sight: Double
    /// Where its sight was last stamped from: a person's tile, a building's origin.
    var stamp: GridPoint

    // People
    var task: Task = .idle
    var doing: Doing = .idle
    var route = Route()
    var cargo: Cargo?
    /// The building a worker is carrying its load to.
    var dropOff: EntityID?
    /// Part of a unit gathered or herded, carried over between ticks.
    var fraction = 0.0

    // Buildings
    /// Worker-ticks of construction done.
    var built = 0
    var complete = true
    /// Health owed by construction or repair, in units of 1 / buildTime.
    var healthCredit = 0
    /// Food a farm has yielded since it was last sown; nil being none.
    var farmUsed: Int?
    /// For a car whose person has turned its kill radius off (ruled 2026-11-21), true; nil being on.
    var killRadiusOff: Bool?
    /// Worker-ticks of demolition done.
    var demolished = 0
    var queue: [UnitKind] = []
    var trainProgress = 0
    /// At a town centre where the advance to the next age is under way, the
    /// ticks of it done (requirement 6); nil elsewhere.
    var advancing: Int?
    /// People trained here so far, to spread them around the building.
    var spawned = 0

    var unitKind: UnitKind? { if case .unit(let k) = kind { k } else { nil } }
    var buildingKind: BuildingKind? { if case .building(let k) = kind { k } else { nil } }
    var isPerson: Bool { if case .unit = kind { true } else { false } }
    /// Whether this is a boat, which moves on water only (ruled 2026-11-21).
    var isBoat: Bool { kind == .unit(.boat) }
    /// Nothing harms a person's car, and it is no target.
    var isUnharmable: Bool { unitKind == .car }
}

/// The catalogue's figures by kind, in arrays indexed by raw value, for the tick's hot loops.
struct Tables: Sendable {
    var units: [UnitStats?]
    var buildings: [BuildingStats?]
    /// Tiles per tick, by unit kind.
    var speedPerTick: [Double]
    /// `Catalogue.bonus`, by attacker and defender raw value.
    var bonus: [Double]
    /// Production times, by maker and unit raw value; 0 where the maker does not make the unit.
    var time: [Int]

    init(_ catalogue: Catalogue) {
        units = UnitKind.allCases.map { kind in catalogue.units.first { $0.kind == kind } }
        buildings = BuildingKind.allCases.map { kind in catalogue.buildings.first { $0.kind == kind } }
        speedPerTick = units.map { ($0?.speed ?? 0) / Double(Tick.rate) }
        let n = UnitKind.allCases.count
        bonus = Array(repeating: 1, count: n * n)
        for a in UnitKind.allCases { for d in UnitKind.allCases { bonus[a.rawValue * n + d.rawValue] = catalogue.bonus(a, against: d) } }
        time = Array(repeating: 0, count: BuildingKind.allCases.count * n)
        for item in catalogue.production { time[item.maker.rawValue * n + item.unit.rawValue] = item.time }
    }

    func unit(_ kind: UnitKind) -> UnitStats {
        guard let stats = units[kind.rawValue] else { preconditionFailure("the catalogue has no \(kind)") }
        return stats
    }

    func building(_ kind: BuildingKind) -> BuildingStats {
        guard let stats = buildings[kind.rawValue] else { preconditionFailure("the catalogue has no \(kind)") }
        return stats
    }

    /// Ticks a maker takes to make a unit (`production.csv`).
    func trainTime(_ unit: UnitKind, at maker: BuildingKind) -> Int { max(1, time[maker.rawValue * UnitKind.allCases.count + unit.rawValue]) }

    func bonus(_ attacker: UnitKind, against defender: UnitKind) -> Double {
        bonus[attacker.rawValue * UnitKind.allCases.count + defender.rawValue]
    }
}
