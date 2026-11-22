// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// How one player sees one tile.
public enum TileVisibility: UInt8, Codable, Sendable, Hashable {
    /// Never seen: drawn black.
    case unexplored
    /// Seen before: the terrain is shown, but not what stands there now.
    case explored
    /// In sight of the player or an ally now.
    case visible
}

/// What a person or building is doing, for the drawing and the interface.
public enum Activity: Hashable, Codable, Sendable {
    case idle
    case moving
    case gathering(SiteKind)
    /// Working at a building (farming, repairing).
    case working
    case constructing
    case fighting
    /// A building whose construction is in progress, from 0 to 1.
    case underConstruction(Double)
    /// A building training a person, from 0 to 1, with the queue's length.
    case training(UnitKind, Double, queued: Int)
    /// A town centre at which the advance to the next age is under way, from 0 to 1.
    case advancing(Double)
}

/// What a person has been set to do, as its player sees it: the job it keeps
/// whilst it walks from one site to the next (a lumberjack chopping and one
/// walking to the next tree both have the job `gathering(.tree)`), so that a double-click can select
/// people at the same work (ruled 2026-11-20).
public enum Job: Hashable, Codable, Sendable {
    case idle
    case moving
    case gathering(SiteKind)
    /// Working at a building of this kind: farming.
    case working(BuildingKind)
    case constructing
    case repairing
    case demolishing
    case attacking
    /// A doctor healing a unit, or walking to it.
    case healing
    /// A troop walking to a navy ship to board it.
    case boarding
    /// A navy ship sailing to the shore to land its troops.
    case landing
}

/// A person or building as a player sees it.
public struct EntityView: Hashable, Codable, Sendable {
    public var id: EntityID
    public var owner: PlayerID
    public var kind: EntityKind
    /// For a person, where it stands; for a building, the centre of its footprint.
    public var position: MapPosition
    /// For a building, the origin tile of its footprint (`Placement.origin`);
    /// for a person, the tile it stands on.
    public var tile: GridPoint
    public var facing: Facing
    public var health: Int
    public var maxHealth: Int
    public var activity: Activity
    /// For the player's own people, the job they have been set (`Job`); nil otherwise.
    public var job: Job?
    /// For a farm, the food it has left before it must be reseeded; for an oil
    /// well, the oil left beneath it; nil for everything else.
    public var remaining: Int?
    /// For a car firing its laser, the centre of the building it burns.
    public var laserTarget: MapPosition?
    /// For a car whose person has turned its kill radius off, true; nil otherwise.
    public var killRadiusOff: Bool?
    /// For a navy ship, the troops aboard (requirement 16); nil for everything else.
    public var passengers: Int?
    /// For a navy ship making a unit, `Activity.training`; nil otherwise.
    public var making: Activity?

    public init(id: EntityID, owner: PlayerID, kind: EntityKind, position: MapPosition, tile: GridPoint,
                facing: Facing, health: Int, maxHealth: Int, activity: Activity, remaining: Int? = nil) {
        self.id = id; self.owner = owner; self.kind = kind; self.position = position; self.tile = tile
        self.facing = facing; self.health = health; self.maxHealth = maxHealth; self.activity = activity
        self.remaining = remaining
    }
}

/// Another player, as everyone may know them.
public struct PlayerSummary: Hashable, Codable, Sendable {
    public var id: PlayerID
    public var civilization: Civilization
    public var team: TeamID
    public var isHuman: Bool
    public var age: Age
    public var isDefeated: Bool

    public init(id: PlayerID, civilization: Civilization, team: TeamID, isHuman: Bool, age: Age,
                isDefeated: Bool) {
        self.id = id; self.civilization = civilization; self.team = team; self.isHuman = isHuman
        self.age = age; self.isDefeated = isDefeated
    }
}

/// Something that happened since the last view, for sounds and messages.
public enum GameEvent: Hashable, Codable, Sendable {
    case trained(EntityID, UnitKind)
    case constructed(EntityID, BuildingKind)
    case ageReached(Age)
    case underAttack(EntityID)
    case destroyed(EntityID)
    case allyDefeated(PlayerID)
    /// An order this player gave was refused. The simulation reports every
    /// refusal this way, in the view after the order; the session shows it.
    case refused(OrderRefusal)
}

public enum MatchOutcome: Hashable, Codable, Sendable {
    /// The team that defeated every player who is not an ally (requirement 7).
    case won(TeamID)
}

/// Everything one player may know at one tick. It is what the drawing and the
/// interface show, what a computer player decides from, and what the Mac that
/// runs a match will send to another Mac in a later milestone.
///
/// Two rules shape it. Sight is shared within a team: a tile is visible if any
/// ally sees it (docs/requirements.md, "Co-operative play").
public struct PlayerView: Hashable, Codable, Sendable {
    public var tick: Int
    public var player: PlayerID
    public var age: Age
    public var resources: ResourceAmounts
    public var population: Int
    public var populationLimit: Int
    /// The advance to the next age under way at one of the player's town
    /// centres, from 0 to 1; 0 when none is under way.
    public var ageProgress: Double
    public var players: [PlayerSummary]
    /// The map's dimensions and terrain, which never change in a match.
    public var mapWidth: Int
    public var mapHeight: Int
    public var terrain: [Terrain]
    /// Row-major, as the terrain.
    public var visibility: [TileVisibility]
    /// The player's own and allies' entities, and others' where visible; ordered by id.
    public var entities: [EntityView]
    /// The sites on explored tiles whose age this player has reached; ordered by id.
    public var sites: [ResourceSite]
    /// Explored tiles of rock that hides what lies there: shown as plain rock,
    /// which blocks the tile; ordered by y, then x. The simulation leaves it
    /// empty, since every site can be seen from the age of towns.
    public var outcrops: [GridPoint]
    public var events: [GameEvent]
    public var outcome: MatchOutcome?
    public var isPaused: Bool

    public init(tick: Int, player: PlayerID, age: Age, resources: ResourceAmounts, population: Int,
                populationLimit: Int, ageProgress: Double, players: [PlayerSummary],
                mapWidth: Int, mapHeight: Int, terrain: [Terrain], visibility: [TileVisibility],
                entities: [EntityView], sites: [ResourceSite], outcrops: [GridPoint] = [], events: [GameEvent],
                outcome: MatchOutcome?, isPaused: Bool) {
        self.outcrops = outcrops
        self.tick = tick; self.player = player; self.age = age; self.resources = resources
        self.population = population; self.populationLimit = populationLimit; self.ageProgress = ageProgress
        self.players = players; self.mapWidth = mapWidth
        self.mapHeight = mapHeight; self.terrain = terrain; self.visibility = visibility
        self.entities = entities; self.sites = sites; self.events = events; self.outcome = outcome
        self.isPaused = isPaused
    }

    public func visibility(at p: GridPoint) -> TileVisibility { visibility[p.y * mapWidth + p.x] }
    public func terrain(at p: GridPoint) -> Terrain { terrain[p.y * mapWidth + p.x] }
    /// Found by binary search: `entities` is ordered by id.
    public func entity(_ id: EntityID) -> EntityView? {
        var low = 0, high = entities.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if entities[mid].id == id { return entities[mid] }
            if entities[mid].id < id { low = mid + 1 } else { high = mid - 1 }
        }
        return nil
    }
    public var me: PlayerSummary? { players.first { $0.id == player } }

    /// Whether `other` is this player or an ally.
    public func isAlly(_ other: PlayerID) -> Bool {
        guard let mine = me?.team, let theirs = players.first(where: { $0.id == other })?.team else { return false }
        return mine == theirs
    }

    /// The resources the interface shows: all three, from the start (requirement 8).
    public var shownResources: [Resource] { Resource.allCases }
}
