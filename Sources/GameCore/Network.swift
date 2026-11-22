// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// What the Macs of one match say to one another (docs/design.md, "Network").
// The Mac that hosts runs the match; each other Mac joins a seat, sends its
// person's orders and receives that person's views. Rulings of 2026-11-18:
// the host sets the match up and leaves seats open for people, who choose
// their own civilization; a person who drops out pauses the match until they
// return or the host hands the seat to a computer player; any person may
// pause or change the speed, with a notice to all.

/// Who plays a seat.
public enum SeatKind: Hashable, Codable, Sendable {
    /// The person at the Mac that hosts.
    case host
    /// A person at another Mac: open until someone joins it.
    case person
    case computer(Difficulty)
}

/// One player's place in a match being set up.
public struct Seat: Hashable, Codable, Sendable, Identifiable {
    public var player: PlayerID
    public var team: TeamID
    public var kind: SeatKind
    /// Chosen by the host for the host's and computers' seats; by the person who
    /// joins for a person's seat, and `nil` until they have.
    public var civilization: Civilization?
    /// The name of the person in the seat; `nil` for a computer or an open seat.
    public var holder: String?
    /// The civilization cannot be changed: the seat belongs to a saved match
    /// being resumed, in which its civilization was chosen long ago.
    public var civilizationFixed: Bool
    /// In a saved match being resumed, the name of the person who held the
    /// seat; that person is given it back on joining.
    public var formerHolder: String?

    public var id: PlayerID { player }

    public init(player: PlayerID, team: TeamID, kind: SeatKind, civilization: Civilization? = nil, holder: String? = nil,
                civilizationFixed: Bool = false, formerHolder: String? = nil) {
        self.player = player; self.team = team; self.kind = kind; self.civilization = civilization; self.holder = holder
        self.civilizationFixed = civilizationFixed; self.formerHolder = formerHolder
    }

    /// A person's seat that nobody holds yet, or whose holder has not chosen a civilization.
    public var isWaiting: Bool {
        if case .computer = kind { return false }
        return holder == nil || civilization == nil
    }
}

/// A match being set up, as every Mac in it sees it.
public struct Lobby: Hashable, Codable, Sendable {
    /// The name under which the match is shown to Macs looking for one, and saved.
    public var name: String
    public var seats: [Seat]
    /// What the people will see of the map, chosen by the host; optional so that older lobbies decode, nil being `.explore`.
    public var sight: MapSight?
    /// The age the match begins in, chosen by the host (ruled 2026-11-21);
    /// nil being the age of towns.
    public var startingAge: Age?
    /// The map's size, chosen by the host (ruled 2026-11-21); optional so that
    /// older lobbies decode, nil being `.standard`.
    public var mapSize: MapSize?

    public init(name: String, seats: [Seat], sight: MapSight = .explore,
                startingAge: Age = .towns, mapSize: MapSize = .standard) {
        self.name = name; self.seats = seats; self.sight = sight == .explore ? nil : sight
        self.startingAge = startingAge == .towns ? nil : startingAge
        self.mapSize = mapSize == .standard ? nil : mapSize
    }

    /// The age the match begins in.
    public var firstAge: Age { startingAge ?? .towns }
    /// The map's size.
    public var size: MapSize { mapSize ?? .standard }

    /// The host may start once every seat is held and has a civilization.
    public var isReady: Bool { !seats.contains { $0.isWaiting } }

    /// The civilizations already taken, so that each player's differs (requirement 10).
    public var taken: [Civilization] { seats.compactMap(\.civilization) }

    /// The match this lobby sets up, once it is ready: people play as humans,
    /// the rest as computers.
    public func setup(map: GameMap, seed: UInt64, catalogue: Catalogue = .standard) -> MatchSetup? {
        guard isReady else { return nil }
        let players = seats.map { seat -> PlayerSetup in
            let controller: Controller
            switch seat.kind {
            case .host, .person: controller = .human
            case .computer(let difficulty): controller = .computer(difficulty)
            }
            return PlayerSetup(id: seat.player, civilization: seat.civilization ?? .sumer, team: seat.team, controller: controller)
        }
        return MatchSetup(map: map, players: players, seed: seed, catalogue: catalogue, sight: sight ?? .explore,
                          startingAge: firstAge)
    }
}

/// What a joining Mac needs once, when its match starts or it rejoins: the
/// parts of a view that never change, so that each view can leave them out,
/// and the host's tables, by which everyone in the match plays (requirement 29).
public struct MatchStart: Hashable, Codable, Sendable {
    public var player: PlayerID
    public var mapWidth: Int
    public var mapHeight: Int
    public var terrain: [Terrain]
    public var catalogue: Catalogue
    public var speed: Double

    public init(player: PlayerID, mapWidth: Int, mapHeight: Int, terrain: [Terrain], catalogue: Catalogue, speed: Double) {
        self.player = player; self.mapWidth = mapWidth; self.mapHeight = mapHeight; self.terrain = terrain
        self.catalogue = catalogue; self.speed = speed
    }
}

/// Something every person in the match is told.
public enum Notice: Hashable, Codable, Sendable {
    case paused(by: String)
    case resumed(by: String)
    case speedChanged(to: Double, by: String)
    /// A person's Mac left; the match is paused until they return or the host hands the seat on.
    case dropped(player: PlayerID, name: String)
    case rejoined(player: PlayerID, name: String)
    case handedToComputer(player: PlayerID, difficulty: Difficulty)
    /// The host is closing the match; the latest automatic save is on the host's Mac.
    case hostLeaving
}

/// One message between the host and a joining Mac.
public enum NetMessage: Hashable, Codable, Sendable {
    /// Raised whenever the shape of any message changes, so that two Macs that
    /// would not understand each other say so instead.
    public static let protocolVersion = 2

    // From a joining Mac.
    /// The first message. The host turns a Mac away unless both `protocolVersion`
    /// and `build` equal its own. A person coming back to a match is given back
    /// the dropped seat whose holder has the same `name`; `rejoining` is the seat
    /// they held, when their app still knows it, and only a hint.
    /// `viewsReceived` is how many views of the match in play the Mac has
    /// received, when it comes back to one: the host sends again the events
    /// of any view it sent after those, lost when the connection broke.
    case hello(protocolVersion: Int, build: String, name: String, rejoining: PlayerID?, viewsReceived: Int?)
    case chooseCivilization(Civilization)
    case order(Order)
    case setSpeed(Double)
    case ping(UInt64)

    // From the host.
    /// The seat the joining Mac now holds.
    /// `run` identifies this opening of the match by the host: a Mac that comes back
    /// to a host that has since closed and opened the match again starts afresh.
    case welcome(seat: PlayerID, run: UInt64)
    /// Why the host turned the joining Mac away, in words for the person.
    case turnedAway(reason: String)
    case lobby(Lobby)
    case start(MatchStart)
    /// The person's view, without its terrain (`PlayerView.withoutTerrain`).
    case view(PlayerView)
    case notice(Notice)
    case pong(UInt64)
}

extension PlayerView {
    /// The view as the host sends it: the terrain, which never changes, left out.
    public var withoutTerrain: PlayerView {
        var copy = self
        copy.terrain = []
        return copy
    }

    /// A view received from the host, with the terrain sent once at the start.
    public func restoringTerrain(from start: MatchStart) -> PlayerView {
        var copy = self
        copy.terrain = start.terrain
        return copy
    }
}

/// The Bonjour service type under which a hosting Mac announces its match.
public enum NetService {
    public static let type = "_greatconqueror._tcp"
}
