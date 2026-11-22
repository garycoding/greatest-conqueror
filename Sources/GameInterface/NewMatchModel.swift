// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

/// What the new-match screen hands back: the players, ready to join a map and a
/// seed into a `MatchSetup`. The map comes from elsewhere.
public struct NewMatchChoice: Hashable, Sendable {
    public var players: [PlayerSetup]
    /// What the people see of the map.
    public var sight: MapSight
    /// The age the match begins in (ruled 2026-11-21).
    public var startingAge: Age
    /// The map's size (ruled 2026-11-21).
    public var mapSize: MapSize

    public init(players: [PlayerSetup], sight: MapSight = .explore, startingAge: Age = .towns,
                mapSize: MapSize = .standard) {
        self.players = players; self.sight = sight
        self.startingAge = startingAge; self.mapSize = mapSize
    }

    public func setup(map: GameMap, seed: UInt64, catalogue: Catalogue = .standard) -> MatchSetup {
        MatchSetup(map: map, players: players, seed: seed, catalogue: catalogue, sight: sight,
                   startingAge: startingAge)
    }
}

/// The new-match screen's state: one seat for each player, each with a
/// civilization, a controller and a team. A match has two to six seats
/// (requirement 4); the default is one human against one computer player
/// (`maxPlayers` 2), and further seats, for people or computer players, are
/// added to the same list.
///
/// The first seat is the host's: the person at this Mac. A match across the LAN
/// also has seats open for a person, whom the host leaves to choose their own
/// civilization; such a match goes to the lobby (`lobby`) instead of starting
/// at once (`choice`).
public struct NewMatchModel: Hashable, Sendable {
    public struct Seat: Identifiable, Hashable, Sendable {
        public var id: Int
        /// Ignored for a seat open for a person, who chooses in the lobby.
        public var civilization: Civilization
        public var controller: Controller
        public var team: Int
        /// Open for a person at another Mac, who joins it from the lobby.
        public var isOpen: Bool = false

        /// A person's seat: the host's or one open for a person.
        public var isHuman: Bool { controller == .human }
        /// The seat of the person at this Mac.
        public var isHost: Bool { isHuman && !isOpen }
        public var difficulty: Difficulty? {
            if case .computer(let d) = controller { return d }
            return nil
        }
    }

    /// The most people in one match, the host among them (requirement 4).
    public static let maxPeople = 3

    /// How many players a match may have, people and computer players together (requirement 4).
    public static let playerRange = 2...6

    public private(set) var seats: [Seat]
    public var maxPlayers: Int
    /// The host's name, shown to the Macs that join.
    public var hostName: String
    /// The name under which the match is announced and saved; blank for the default.
    public var matchName: String
    /// What the people in the match see of the map (ruled 2026-11-20).
    public var sight: MapSight = .explore
    /// The age the match begins in (ruled 2026-11-21: a setting of the match).
    public var startingAge: Age = .towns
    /// The map's size (ruled 2026-11-21: a setting of the match).
    public var mapSize: MapSize = .standard
    private var nextID: Int

    public init(maxPlayers: Int = 2, civilization: Civilization = .sumer, opponent: Civilization = .egypt,
                difficulty: Difficulty = .standard, hostName: String = "", matchName: String = "") {
        self.maxPlayers = maxPlayers
        self.hostName = hostName
        self.matchName = matchName
        seats = [
            Seat(id: 0, civilization: civilization, controller: .human, team: 0),
            Seat(id: 1, civilization: opponent == civilization ? Self.firstUnused([civilization]) : opponent,
                 controller: .computer(difficulty), team: 1),
        ]
        nextID = 2
    }

    private static func firstUnused(_ taken: [Civilization]) -> Civilization {
        Civilization.allCases.first { !taken.contains($0) } ?? .sumer
    }

    /// The civilizations the host has chosen: every seat's but the open ones'.
    private var chosenCivilizations: [Civilization] { seats.filter { !$0.isOpen }.map(\.civilization) }

    /// Choose a civilization for a seat. Each player has a different one
    /// (requirement 10), so a civilization another seat holds changes places.
    /// A seat open for a person has none until that person chooses in the lobby.
    public mutating func setCivilization(_ civilization: Civilization, forSeat id: Int) {
        guard let i = seats.firstIndex(where: { $0.id == id }), !seats[i].isOpen else { return }
        let previous = seats[i].civilization
        if let j = seats.firstIndex(where: { $0.civilization == civilization && $0.id != id && !$0.isOpen }) {
            seats[j].civilization = previous
        }
        seats[i].civilization = civilization
    }

    public mutating func setDifficulty(_ difficulty: Difficulty, forSeat id: Int) {
        guard let i = seats.firstIndex(where: { $0.id == id }), !seats[i].isHuman else { return }
        seats[i].controller = .computer(difficulty)
    }

    /// Put a seat on a team. A seat open for a person stays on the host's team
    /// (requirement 5); moving the host moves the open seats with it.
    public mutating func setTeam(_ team: Int, forSeat id: Int) {
        guard let i = seats.firstIndex(where: { $0.id == id }), !seats[i].isOpen else { return }
        seats[i].team = team
        if seats[i].isHost {
            for j in seats.indices where seats[j].isOpen { seats[j].team = team }
        }
    }

    public var canAddComputerPlayer: Bool { seats.count < maxPlayers && seats.count < Civilization.allCases.count }

    /// Add a computer player on a team of its own, with the first civilization not yet taken.
    @discardableResult
    public mutating func addComputerPlayer(difficulty: Difficulty = .standard) -> Bool {
        guard canAddComputerPlayer else { return false }
        let team = (seats.map(\.team).max() ?? -1) + 1
        seats.append(Seat(id: nextID, civilization: Self.firstUnused(chosenCivilizations),
                          controller: .computer(difficulty), team: team))
        nextID += 1
        return true
    }

    /// The seats open for a person.
    public var openSeatCount: Int { seats.filter(\.isOpen).count }
    public var hasOpenSeats: Bool { openSeatCount > 0 }

    /// Whether one more seat may be opened for a person: the host and the open
    /// seats together are at most `maxPeople`.
    public var canOpenSeat: Bool { openSeatCount + 1 < Self.maxPeople }

    public var canAddOpenSeat: Bool { canOpenSeat && canAddComputerPlayer }

    /// Add a seat open for a person, on the host's team.
    @discardableResult
    public mutating func addOpenSeat() -> Bool {
        guard canAddOpenSeat else { return false }
        seats.append(Seat(id: nextID, civilization: Self.firstUnused(chosenCivilizations), controller: .human,
                          team: hostTeam, isOpen: true))
        nextID += 1
        return true
    }

    /// Open a computer player's seat for a person, who joins the host's team; or
    /// give an open seat back to a computer player, with the first civilization not
    /// taken, on the team it had.
    public mutating func setOpen(_ open: Bool, forSeat id: Int, difficulty: Difficulty = .standard) {
        guard let i = seats.firstIndex(where: { $0.id == id }), !seats[i].isHost, seats[i].isOpen != open else { return }
        if open {
            guard canOpenSeat else { return }
            seats[i].isOpen = true
            seats[i].controller = .human
            seats[i].team = hostTeam
        } else {
            seats[i].isOpen = false
            seats[i].controller = .computer(difficulty)
            seats[i].civilization = Self.firstUnused(chosenCivilizations)
        }
    }

    private var hostTeam: Int { seats.first(where: \.isHost)?.team ?? 0 }

    /// Remove a computer player's seat or an open seat; the host's seat stays.
    public mutating func removeSeat(_ id: Int) {
        seats.removeAll { $0.id == id && !$0.isHost }
    }

    /// Why the match cannot start, or `nil` if it can (requirements 4, 5 and 10).
    public var problem: String? {
        if !Self.playerRange.contains(seats.count) { return "A match has two to six players." }
        if Set(seats.map(\.team)).count < 2 { return "A match needs at least two teams." }
        if Set(chosenCivilizations).count != chosenCivilizations.count { return "Each player needs a different civilization." }
        if seats.filter(\.isHuman).contains(where: { $0.team != seats[0].team }) { return "All the human players are on one team." }
        if seats.filter(\.isHuman).count > Self.maxPeople { return "A match has at most three people." }
        return nil
    }

    /// The match can start on this Mac at once: it has no open seats.
    public var canStart: Bool { problem == nil && !hasOpenSeats }

    /// The match can go to the lobby, to wait for the people who join.
    public var canHost: Bool { problem == nil && hasOpenSeats }

    /// The name the match is announced and saved under: the one typed, or the host's.
    public var lobbyName: String {
        let typed = matchName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        let host = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? "A match" : "\(host)\u{2019}s match"
    }

    /// The match as the lobby begins it: the host's seat held by the host, the
    /// computer players as chosen, and the open seats waiting for a person, who
    /// will choose a civilization. Players and teams are numbered as in `choice`.
    public var lobby: Lobby {
        let players = choice.players
        let seats = zip(self.seats, players).map { seat, player -> GameCore.Seat in
            if seat.isOpen {
                return GameCore.Seat(player: player.id, team: player.team, kind: .person)
            }
            if let difficulty = seat.difficulty {
                return GameCore.Seat(player: player.id, team: player.team, kind: .computer(difficulty),
                                     civilization: seat.civilization)
            }
            let host = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
            return GameCore.Seat(player: player.id, team: player.team, kind: .host, civilization: seat.civilization,
                                 holder: host.isEmpty ? "Host" : host)
        }
        return Lobby(name: lobbyName, seats: seats, sight: sight, startingAge: startingAge, mapSize: mapSize)
    }

    /// The players in seat order, numbered from 0; teams are numbered by first
    /// appearance. For a match on this Mac alone, without open seats.
    public var choice: NewMatchChoice {
        var teams: [Int: Int] = [:]
        var players: [PlayerSetup] = []
        for (i, seat) in seats.enumerated() {
            let team = teams[seat.team] ?? teams.count
            teams[seat.team] = team
            players.append(PlayerSetup(id: PlayerID(i), civilization: seat.civilization, team: TeamID(team),
                                       controller: seat.controller))
        }
        return NewMatchChoice(players: players, sight: sight, startingAge: startingAge, mapSize: mapSize)
    }
}
