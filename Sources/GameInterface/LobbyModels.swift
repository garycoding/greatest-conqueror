// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The models of the screens of a match across the LAN: the lobby, the list of
// matches to join, and the notices during a match (rulings of 2026-11-18 in
// docs/design.md, "Network"). Plain values, so that they are tested without a
// screen; the app feeds them what the connection reports.

// MARK: Lobby

/// The lobby, as one Mac in it sees it: every seat with its kind, holder, team
/// and civilization; for the host, whether the match may start; for a person
/// who joined, the civilizations they may choose.
public struct LobbyModel: Hashable, Sendable {
    public struct Row: Identifiable, Hashable, Sendable {
        public var id: PlayerID
        /// "Host", "Person" or "Computer, hard".
        public var kindText: String
        /// The holder's name, "Computer player", or "Waiting for a person".
        public var holderText: String
        public var teamText: String
        /// The civilization's name, or "choosing…".
        public var civilizationText: String
        public var civilization: Civilization?
        /// The seat of the person at this Mac.
        public var isMine: Bool
        public var isWaiting: Bool
    }

    public var lobby: Lobby
    /// The seat of the person at this Mac: the host's, or the one the host gave a joining Mac.
    public var me: PlayerID

    public init(lobby: Lobby, me: PlayerID) { self.lobby = lobby; self.me = me }

    public var name: String { lobby.name }

    private var mySeat: Seat? { lobby.seats.first { $0.player == me } }

    /// This Mac hosts the match.
    public var isHost: Bool { mySeat?.kind == .host }

    public var rows: [Row] {
        lobby.seats.map { seat in
            let kind: String, holder: String
            switch seat.kind {
            case .host:
                kind = "Host"; holder = seat.holder ?? "Host"
            case .person:
                kind = "Person"; holder = seat.holder ?? "Waiting for a person"
            case .computer(let d):
                kind = "Computer, \(InterfaceText.name(of: d).lowercased())"; holder = "Computer player"
            }
            return Row(id: seat.player, kindText: kind, holderText: holder, teamText: "Team \(seat.team.rawValue + 1)",
                       civilizationText: seat.civilization?.name ?? InterfaceText.choosing, civilization: seat.civilization,
                       isMine: seat.player == me, isWaiting: seat.isWaiting)
        }
    }

    /// The host may start once every seat is held and has a civilization.
    public var canStart: Bool { isHost && lobby.isReady }

    /// What the match waits for from others, or `nil` when it waits for nobody
    /// but, perhaps, the person at this Mac, whose picker says so.
    public var waitingFor: String? {
        let empty = lobby.seats.filter { $0.kind == .person && $0.holder == nil }.count
        if empty > 0 { return empty == 1 ? "Waiting for a person to join." : "Waiting for \(empty) people to join." }
        let choosing = lobby.seats.filter { $0.isWaiting && $0.player != me }.compactMap(\.holder)
        if !choosing.isEmpty { return "Waiting for \(InterfaceText.list(choosing)) to choose a civilization." }
        return nil
    }

    /// The person at this Mac chooses a civilization here: a joining person whose
    /// seat's civilization is not fixed by a saved match.
    public var showsPicker: Bool {
        guard let seat = mySeat, seat.kind == .person else { return false }
        return !seat.civilizationFixed
    }

    /// The civilizations a joining person may choose: those no other seat holds
    /// (requirement 10), their own choice among them. None for the host, whose
    /// civilization was chosen on the new-match screen, or for a fixed seat.
    public var offered: [Civilization] {
        guard showsPicker else { return [] }
        let others = lobby.seats.filter { $0.player != me }.compactMap(\.civilization)
        return Civilization.allCases.filter { !others.contains($0) }
    }

    /// The civilization the person at this Mac holds, if any.
    public var myCivilization: Civilization? { mySeat?.civilization }

    /// The line under a fixed seat, for a resumed match.
    public var fixedLine: String? {
        guard let seat = mySeat, seat.kind == .person, seat.civilizationFixed else { return nil }
        return "Your civilization was chosen when the match began."
    }
}

// MARK: Join

/// A match another Mac on the LAN is hosting, as the list shows it. The app makes
/// it from what the connection finds.
public struct FoundMatch: Identifiable, Hashable, Sendable {
    /// Whatever identifies the match to the connection (its service name, say).
    public var id: String
    public var name: String
    /// The host's name, or empty when the connection does not say.
    public var host: String
    /// How many seats are open, or `nil` when the connection does not say.
    public var openSeats: Int?

    public init(id: String, name: String, host: String = "", openSeats: Int? = nil) {
        self.id = id; self.name = name; self.host = host; self.openSeats = openSeats
    }
}

/// The join screen: the matches found on the LAN, and the person's name, which
/// the app keeps between launches.
public struct JoinModel: Hashable, Sendable {
    public struct Row: Identifiable, Hashable, Sendable {
        public var match: FoundMatch
        public var id: String { match.id }
        public var name: String { match.name }
        /// Empty when the host's name is not known.
        public var hostLine: String { match.host.isEmpty ? "" : "Hosted by \(match.host)" }
        /// Empty when the number of open seats is not known.
        public var seatsLine: String {
            switch match.openSeats {
            case nil: ""
            case 0?: "No seat open"
            case 1?: "1 seat open"
            case let n?: "\(n) seats open"
            }
        }
        /// A seat is open and the person has given a name.
        public var canJoin: Bool
    }

    public var name: String
    public var matches: [FoundMatch]

    public init(name: String, matches: [FoundMatch]) { self.name = name; self.matches = matches }

    /// The name as it is sent: without surrounding spaces.
    public var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var hasName: Bool { !trimmedName.isEmpty }

    public var rows: [Row] {
        matches.map { Row(match: $0, canJoin: hasName && ($0.openSeats ?? 1) > 0) }
    }

    /// Why no match may be joined, or `nil`.
    public var problem: String? { hasName ? nil : "Type your name, so that the others know who has joined." }

    public var emptyLine: String { "Looking for matches on this network\u{2026}" }
}

// MARK: Notices

/// What the person at this Mac is shown about the match while it runs: a banner
/// for a passing notice, a panel for each person who has dropped out, and a
/// panel once the host has left. The app feeds it each `Notice` and, on a
/// joining Mac, the loss of the connection.
public struct MatchNotices: Hashable, Sendable {
    public struct Banner: Hashable, Sendable {
        public var text: String
        /// Distinguishes two equal texts, so that the second shows afresh.
        public var serial: Int
    }

    /// A person whose Mac has left the match.
    public struct Drop: Identifiable, Hashable, Sendable {
        public var player: PlayerID
        public var name: String
        public var id: PlayerID { player }
    }

    /// This Mac hosts the match.
    public var isHost: Bool
    /// The names of the players, for notices that name a player by seat only.
    public var names: [PlayerID: String]
    public private(set) var banner: Banner?
    public private(set) var drops: [Drop] = []
    public private(set) var hostLeft = false
    private var serial = 0

    public init(isHost: Bool, names: [PlayerID: String] = [:]) { self.isHost = isHost; self.names = names }

    /// The names of the lobby's holders, by seat.
    public init(isHost: Bool, lobby: Lobby) {
        var names: [PlayerID: String] = [:]
        for seat in lobby.seats { if let holder = seat.holder { names[seat.player] = holder } }
        self.init(isHost: isHost, names: names)
    }

    public mutating func receive(_ notice: Notice) {
        switch notice {
        case .dropped(let player, let name):
            names[player] = name
            if !drops.contains(where: { $0.player == player }) { drops.append(Drop(player: player, name: name)) }
        case .rejoined(let player, let name):
            names[player] = name
            drops.removeAll { $0.player == player }
        case .handedToComputer(let player, _):
            drops.removeAll { $0.player == player }
        case .hostLeaving:
            if !isHost { hostLeft = true }
        case .paused, .resumed, .speedChanged:
            break
        }
        if let text = Self.bannerText(for: notice, names: names) {
            serial += 1
            banner = Banner(text: text, serial: serial)
        }
    }

    /// A joining Mac lost its connection to the host.
    public mutating func connectionLost() {
        if !isHost { hostLeft = true }
    }

    /// Take the banner down, if it is still the one given.
    public mutating func clearBanner(_ shown: Banner) {
        if banner == shown { banner = nil }
    }

    /// The panel over the map: the first person still dropped out.
    public var dropPanel: DropPanelModel? {
        drops.first.map { DropPanelModel(player: $0.player, name: $0.name, isHost: isHost) }
    }

    public var hostLeftPanel: HostLeftModel? { hostLeft ? HostLeftModel() : nil }

    /// The words of a banner, or `nil` for a notice shown as a panel.
    public static func bannerText(for notice: Notice, names: [PlayerID: String] = [:]) -> String? {
        switch notice {
        case .paused(let by): "Paused by \(by)."
        case .resumed(let by): "Resumed by \(by)."
        case .speedChanged(let speed, let by): "Speed changed to \(InterfaceText.speed(speed)) by \(by)."
        case .rejoined(_, let name): "\(name) has rejoined the match."
        case .handedToComputer(let player, let difficulty):
            "\(names[player] ?? "Player \(player.rawValue + 1)")\u{2019}s base is now played by a computer player (\(InterfaceText.name(of: difficulty).lowercased()))."
        case .dropped, .hostLeaving: nil
        }
    }
}

/// The panel shown while a person is dropped out: the match waits for them, and
/// the host alone may hand their seat to a computer player.
public struct DropPanelModel: Hashable, Sendable {
    public var player: PlayerID
    public var name: String
    public var isHost: Bool

    public init(player: PlayerID, name: String, isHost: Bool) { self.player = player; self.name = name; self.isHost = isHost }

    public var title: String { "\(name) has dropped out" }
    public var message: String { "The match waits for \(name) to return." }
    /// "Continue with a computer player", on the host's Mac only.
    public var offersComputerPlayer: Bool { isHost }
    public var handOverTitle: String { "Continue with a computer player" }
    public var handOverLine: String { "\(name) takes the seat back on returning." }
    public var difficulties: [Difficulty] { isHost ? Difficulty.allCases : [] }
}

/// The panel a joining Mac shows once the host has left, or the connection to it is lost.
public struct HostLeftModel: Hashable, Sendable {
    public init() {}

    public var title: String { "The host has left" }
    public var message: String { "The match is saved on the host\u{2019}s Mac. When the host opens it again, join it as before." }
    public var buttonTitle: String { "Back to the start" }
}
