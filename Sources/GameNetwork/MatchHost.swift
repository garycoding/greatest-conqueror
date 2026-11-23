// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The match as the Mac that runs it holds it: the simulation and the computer
/// players, advanced one tick at a time (docs/architecture.md). The app drives
/// it from a timer and the match tests drive it in a loop, so both run the same
/// code.
///
/// It is a value and `Codable`, so encoding it saves the whole match,
/// computer players included (requirement 23).
public struct MatchHost<Simulation: GameSimulating, Computer: ComputerPlaying>: Codable, Sendable {
    /// Ticks between two decisions of one computer player: four a second.
    public static var decisionInterval: Int { Tick.rate / 4 }

    public private(set) var simulation: Simulation
    public private(set) var computers: [Computer]
    /// The player each computer controls, in the order of `computers`.
    public private(set) var computerPlayers: [PlayerID]
    /// The tables the match plays by; the host's editor may replace them (`adopt`).
    public private(set) var catalogue: Catalogue
    /// People whose Macs have left and whose seats are not yet handed on: while
    /// any remain the match holds still (ruling of 2026-11-18). Not saved: a
    /// reopened match has its own rule for absent people.
    public private(set) var dropped: [PlayerID] = []

    enum CodingKeys: String, CodingKey { case simulation, computers, computerPlayers, catalogue }

    /// Starts a match: one computer player for each player the setup gives to a computer.
    public init(setup: MatchSetup) {
        simulation = Simulation(setup: setup)
        catalogue = setup.catalogue
        var computers: [Computer] = []
        var players: [PlayerID] = []
        for (i, p) in setup.players.enumerated() {
            guard case .computer(let difficulty) = p.controller else { continue }
            // Each computer player draws from its own stream, derived from the match's seed.
            computers.append(Computer(player: p.id, difficulty: difficulty,
                                      seed: setup.seed &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(i + 1)))
            players.append(p.id)
        }
        self.computers = computers
        computerPlayers = players
    }

    public var tick: Int { simulation.tick }
    public var outcome: MatchOutcome? { simulation.outcome }
    /// Paused by a person, or held for a person who dropped out.
    public var isPaused: Bool { simulation.isPaused || !dropped.isEmpty }

    /// An order from a person at this Mac (or, in a later milestone, another Mac).
    /// While a dropped person's seat holds the match, it is paused for everyone:
    /// every order is refused but a request to pause.
    @discardableResult
    public mutating func apply(_ order: Order, from player: PlayerID) -> OrderResult {
        if !dropped.isEmpty, order != .setPaused(true) { return .refused(.notNow) }
        return simulation.apply(order, from: player)
    }

    /// A person's Mac has left: the match holds still until they rejoin or the
    /// seat is handed to a computer player.
    public mutating func drop(_ player: PlayerID) {
        if !dropped.contains(player) && !isComputer(player) { dropped.append(player) }
    }

    /// The person is back in their seat; a computer player that was playing it stops.
    public mutating func rejoin(_ player: PlayerID) {
        dropped.removeAll { $0 == player }
        takeBack(player)
    }

    /// The match as a spectator sees one player's side, without taking that
    /// player's events (for reports and tests).
    public func peek(for player: PlayerID) -> PlayerView {
        var copy = simulation
        return copy.view(for: player)
    }

    /// One tick: each computer player whose turn it is decides from its own view,
    /// its orders are applied, and the simulation steps. The computer players'
    /// turns are spread across the interval so that no tick carries them all.
    public mutating func advance() {
        guard outcome == nil, !isPaused else { return }
        let interval = Self.decisionInterval
        for k in computers.indices where (simulation.tick + k) % interval == 0 {
            let player = computerPlayers[k]
            let view = simulation.computerView(for: player)
            for order in computers[k].decide(view: view, catalogue: catalogue) {
                // A refused order reaches the computer player as an event in its next view.
                _ = simulation.apply(order, from: player)
            }
        }
        simulation.step()
    }

    /// What a person may know now. It takes the events since that player's last
    /// view, so call it once per update for each person.
    public mutating func view(for player: PlayerID) -> PlayerView {
        var view = simulation.view(for: player)
        if !dropped.isEmpty { view.isPaused = true }
        return view
    }

    public func checksum() -> UInt64 { simulation.checksum() }

    /// The match plays by new tables from the next tick, the computer players
    /// with it (requirement 27).
    public mutating func adopt(_ catalogue: Catalogue) {
        self.catalogue = catalogue
        simulation.adopt(catalogue)
    }

    /// Whether a computer player now plays this player's seat.
    public func isComputer(_ player: PlayerID) -> Bool { computerPlayers.contains(player) }

    /// A computer player takes a person's seat (ruling of 2026-11-18: the host
    /// may hand a dropped person's seat to the computer). It begins with fresh
    /// memory, from a seed drawn from the match's state, so that it is the same
    /// on every run of the same match.
    public mutating func handToComputer(_ player: PlayerID, difficulty: Difficulty) {
        dropped.removeAll { $0 == player }
        guard !isComputer(player) else { return }
        let seed = simulation.checksum() &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(player.rawValue + 1)
        computers.append(Computer(player: player, difficulty: difficulty, seed: seed))
        computerPlayers.append(player)
    }

    /// The person takes their seat back from the computer player.
    public mutating func takeBack(_ player: PlayerID) {
        guard let k = computerPlayers.firstIndex(of: player) else { return }
        computers.remove(at: k)
        computerPlayers.remove(at: k)
    }
}
