// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Play across the LAN (docs/design.md, "Network"). The Mac that hosts runs the
// match; each other Mac joins a seat, sends its person's orders and receives
// that person's views. The Macs exchange `NetMessage`s, encoded as JSON, in
// frames that carry their length, over TCP (`Link`).
//
// How the app drives this module.
//
// Hosting:
// 1. The host sets the match up as now and leaves seats open for people
//    (`SeatKind.person`). The app makes a `HostServer(lobby:build:)` and calls
//    `open()`: the server listens and announces the match under the lobby's
//    name, as `NetService.type`.
// 2. Whilst people join, `server.lobby` (observable) shows who holds each seat
//    and which civilization they chose. The host chooses its own seat's
//    civilization, and the computers', with `chooseCivilization(_:for:)`.
//    `server.lobby.isReady` says when the match may start.
// 3. To start, the app makes the map and its `MatchHost` from
//    `server.lobby.setup(map:seed:)` as now (or opens a saved match), keeps the
//    host beside the server in its own match object, which conforms to
//    `HostedMatch`, and calls `server.start(match)`. Each person is then sent
//    the match's start and their views.
// 4. In each 60 Hz frame, the app advances its `MatchHost` by the ticks owed
//    at `match.speed`, and updates its own person's session from it, both as
//    now; then it calls `server.frame()`, which sends each person who joined
//    their view about 20 times a second, whether or not ticks ran. An order
//    from another Mac is applied the moment it arrives, and the person who
//    gave it is sent a view at once.
// 5. The host's own person gives orders through `server.issue(_:)` (the
//    session's sink) and changes the speed with `server.setSpeed(_:)`, so that
//    a pause or a change of speed is told to everyone. The server sets
//    `match.speed` whenever anyone changes it. New tables from the host's
//    editor go through `server.adopt(_:)`, which puts them into the match and
//    sends them to every Mac in it (`NetMessage.tables`).
// 6. `server.notices` (observable) and `server.onNotice` give every notice,
//    those about the host's own person included; `server.dropped` lists the
//    seats of people whose Macs have left; `server.handToComputer(_:difficulty:)`
//    is "Continue with a computer player". `server.close()` tells everyone
//    that the host is leaving.
//
// Joining:
// 1. `MatchBrowser` lists the matches announced on the LAN; nobody types an
//    address.
// 2. `MatchClient(name:build:)`, then `join(_:)` with the match chosen.
//    `client.state`, `client.lobby` and `client.seat` show the lobby;
//    `chooseCivilization(_:)` chooses.
// 3. When the match starts, `client.session` is the `PlayerSession` the app
//    passes to the drawing and the panels. It is made once a match and kept
//    across reconnections; its orders go to the host, and each view that
//    arrives updates it at once, so the app's frame has nothing to call on the
//    client: it draws the session as it does on the host.
// 4. `client.setSpeed(_:)` changes the speed for everyone; `client.speed`,
//    `client.notices` and `client.onNotice` follow the host, and so does
//    `client.catalogue`, the host's tables, which the session plays by and from
//    which the app makes the Mac's sprite source.
// 5. If the connection drops, the client reconnects to the same host by
//    itself, a few times over about a minute, and the host gives back the
//    seat held under the same name. `client.state` is `.reconnecting` meanwhile,
//    and ends as `.turnedAway`, `.gaveUp` or `.hostLeft`.
//
// Both sides pass the build stamp that `scripts/make-app.sh` writes into the
// bundle as `GreatestConquerorBuild`; a host turns away a Mac whose stamp, or
// `NetMessage.protocolVersion`, differs from its own.

/// What the host server needs of the match the app runs. The app's own match
/// object conforms, keeps its `MatchHost` as before and forwards these calls to
/// it. The server holds it weakly and calls it on the main actor only.
@MainActor
public protocol HostedMatch: AnyObject {
    /// The tables of the match, sent once to each person (`MatchStart.catalogue`).
    var catalogue: Catalogue { get }
    /// How many times the normal rate the match runs. The server sets it when
    /// anyone changes the speed, and when the match starts.
    var speed: Double { get set }
    /// `MatchHost.apply(_:from:)`.
    func apply(_ order: Order, from player: PlayerID) -> OrderResult
    /// `MatchHost.view(for:)`. It takes the player's events, so the server
    /// calls it only for a view it sends.
    func view(for player: PlayerID) -> PlayerView
    /// `MatchHost.drop(_:)`.
    func drop(_ player: PlayerID)
    /// `MatchHost.rejoin(_:)`.
    func rejoin(_ player: PlayerID)
    /// `MatchHost.handToComputer(_:difficulty:)`.
    func handToComputer(_ player: PlayerID, difficulty: Difficulty)
    /// `MatchHost.adopt(_:)`: the host's new tables, from the next tick.
    func adopt(_ catalogue: Catalogue)
    /// `MatchHost.tick`.
    var tick: Int { get }
    /// The match has an outcome; a person who leaves then is not waited for.
    var isOver: Bool { get }
}

extension HostedMatch {
    public var isOver: Bool { false }
}
