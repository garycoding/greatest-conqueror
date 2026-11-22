// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// The protocols at the seams between modules. Each module implements or uses
// these and nothing of another module's internals (docs/architecture.md).

/// Who controls a player.
public enum Controller: Hashable, Codable, Sendable {
    case human
    case computer(Difficulty)
}

public struct PlayerSetup: Hashable, Codable, Sendable {
    public var id: PlayerID
    public var civilization: Civilization
    public var team: TeamID
    public var controller: Controller

    public init(id: PlayerID, civilization: Civilization, team: TeamID, controller: Controller) {
        self.id = id; self.civilization = civilization; self.team = team; self.controller = controller
    }
}

/// What the people in a match see of the map (ruled 2026-11-20): one setting
/// with three values, chosen when the match is set up. It applies to the
/// people only; computer players always explore.
public enum MapSight: String, Hashable, Codable, Sendable, CaseIterable {
    /// The map starts black: ground is shown once explored, and what is
    /// happening only where the player's or an ally's units see.
    case explore
    /// The whole map's ground and deposits are shown from the start; what is
    /// happening, only where the player's or an ally's units see.
    case mapShown
    /// The whole map and everything on it, as it is, all the time.
    case everything

    public var name: String {
        switch self {
        case .explore: "Explore the map"
        case .mapShown: "Map shown"
        case .everything: "Everything in view"
        }
    }

    public var explanation: String {
        switch self {
        case .explore: "The map starts black. You see the ground once explored, and what is happening only where your units are."
        case .mapShown: "The whole map is shown from the start. You see what is happening only where your units are."
        case .everything: "You see the whole map and everything on it as it is, all the time."
        }
    }
}

/// Everything needed to start a match.
public struct MatchSetup: Hashable, Codable, Sendable {
    public var map: GameMap
    /// In player order; `map.starts[i]` is the start of `players[i]`.
    public var players: [PlayerSetup]
    public var seed: UInt64
    public var catalogue: Catalogue
    /// What the people see of the map; optional so that older saves open, nil being `.explore`.
    public var sight: MapSight?
    /// Whether bridges may be built (ruled 2026-11-21: a setting of the match);
    /// optional so that older saves open, nil being allowed.
    public var noBridges: Bool?
    /// The age every player begins in (ruled 2026-11-21: a setting of the
    /// match); optional so that older saves open, nil being the Stone age.
    public var startingAge: Age?

    public init(map: GameMap, players: [PlayerSetup], seed: UInt64, catalogue: Catalogue = .standard,
                sight: MapSight = .explore, bridges: Bool = true, startingAge: Age = .stone) {
        self.map = map; self.players = players; self.seed = seed; self.catalogue = catalogue
        self.sight = sight == .explore ? nil : sight
        self.noBridges = bridges ? nil : true
        self.startingAge = startingAge == .stone ? nil : startingAge
    }

    /// The age every player begins in.
    public var firstAge: Age { startingAge ?? .stone }

    /// Whether bridges may be built in this match.
    public var bridges: Bool { noBridges != true }
}

/// The rules of the game (module `GameSimulation`).
///
/// It is a value: copying it copies the match, and encoding it saves the match,
/// random generator included, so that a saved match resumes exactly. It uses no
/// Apple frameworks and no unseeded randomness, and it never lets the order of a
/// `Dictionary` or `Set` decide an outcome, so that the same setup and the same
/// orders at the same ticks give the same result in any process.
public protocol GameSimulating: Codable, Sendable {
    init(setup: MatchSetup)
    var tick: Int { get }
    var outcome: MatchOutcome? { get }
    var isPaused: Bool { get set }
    /// Apply an order from a player at the current tick. A refusal is also
    /// reported as `GameEvent.refused` in that player's next view.
    mutating func apply(_ order: Order, from player: PlayerID) -> OrderResult
    /// Advance one tick (1 / `Tick.rate` seconds), unless paused.
    mutating func step()
    /// What the player may know now, with the events since the player's last view.
    mutating func view(for player: PlayerID) -> PlayerView
    /// The same for a computer player playing that seat, which always explores
    /// whatever `MapSight` the people were given.
    mutating func computerView(for player: PlayerID) -> PlayerView
    /// A checksum of the whole state, the same in every process for the same
    /// state. Computed field by field from the simulation's own ordered arrays,
    /// never by hashing an encoding that contains a dictionary. It leaves out
    /// the events waiting for each player's next view, since those depend on
    /// when views are taken.
    func checksum() -> UInt64
}

extension GameSimulating {
    public mutating func computerView(for player: PlayerID) -> PlayerView { view(for: player) }
}

/// The map generator (module `MapGeneration`). The same request gives the same map.
public protocol MapGenerating: Sendable {
    func generate(_ request: MapRequest) -> GameMap
}

/// A computer player (module `ComputerPlayer`). It sees only what its player's
/// view shows and acts only through orders, as a person does (requirement 22).
public protocol ComputerPlaying: Codable, Sendable {
    init(player: PlayerID, difficulty: Difficulty, seed: UInt64)
    /// Called a few times a second, never more than once a tick.
    mutating func decide(view: PlayerView, catalogue: Catalogue) -> [Order]
}
