// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import Artwork
import ComputerPlayer
import Foundation
import GameCore
import GameInterface
import GameNetwork
import GameSimulation
import MapGeneration
import Observation

typealias Host = MatchHost<Simulation, ComputerPlayer>

/// Carries the person's orders from the session to the match, which is made
/// after the session it feeds.
@MainActor
private final class OrderRelay {
    weak var match: Match?
}

/// A match run on this Mac: the host that runs it, the person's session, and
/// the clock that advances it twenty ticks a second. When it is hosted across
/// the LAN, `server` sends the others their views and carries every person's
/// orders and changes of speed.
@MainActor
final class Match: HostedMatch {
    private(set) var host: Host
    let player: PlayerID
    let session: PlayerSession
    private var clock: Timer?
    private var lastTime: TimeInterval?
    private var owed = 0.0

    /// The server of a match hosted across the LAN; `nil` for a match on this Mac alone.
    weak var server: HostServer?
    /// The lobby the hosted match began from, kept in its saves so that it can be hosted again.
    var lobby: Lobby?
    /// The texts of the tables the match plays by, for the editor; nil for a
    /// match saved before the editor existed.
    var tables: TableTexts?

    /// At most this many frames' worth of ticks are run at once, so that a stall
    /// (the Mac asleep, a window being dragged) does not make the match race.
    static let catchUpFrames = 5.0

    /// The speeds the person may choose: how many times the normal rate the match runs.
    static let speeds: [Double] = [1, 1.5, 2, 3, 4]

    /// How many times the normal rate the match runs. It changes only the clock,
    /// so the rules and the computer players are the same at every speed.
    var speed = 1.0

    init(host: Host, player: PlayerID, camera: Camera? = nil, name: String) {
        self.name = name
        var host = host
        let view = host.view(for: player)
        let relay = OrderRelay()
        self.host = host
        self.player = player
        session = PlayerSession(view: view, catalogue: host.catalogue,
                                camera: camera ?? Camera(centre: Self.home(in: view)),
                                sink: { order in relay.match?.issue(order) })
        relay.match = self
    }

    /// The person's town centre, or else the middle of the map.
    static func home(in view: PlayerView) -> MapPosition {
        view.entities.first { $0.owner == view.player && $0.kind == .building(.townCentre) }?.position
            ?? MapPosition(x: Double(view.mapWidth) / 2, y: Double(view.mapHeight) / 2)
    }

    func start() {
        guard clock == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.frame() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    func stop() {
        clock?.invalidate()
        clock = nil
        // The time stopped is not owed: the match resumes where it stood.
        lastTime = nil
    }

    var isOver: Bool { host.outcome != nil }

    /// The match's name, under which its automatic saves are kept.
    var name: String
    /// Seconds of play since the last automatic save; a pause does not count.
    private var playedSinceAutosave: TimeInterval = 0
    /// Called every `Autosaves.interval` seconds of play.
    var autosave: ((Match) -> Void)?

    /// The person's order: through the server when hosting, so that a pause is told to everyone.
    fileprivate func issue(_ order: Order) {
        let result = server.map { $0.issue(order) } ?? host.apply(order, from: player)
        // A refusal the simulation does not report (the match held for a dropped person) is shown all the same.
        if case .refused(let refusal) = result, server != nil { session.lastRefusal = refusal }
    }

    /// One frame: run the ticks owed since the last frame, give the session
    /// the person's view, and let the server send the others theirs.
    private func frame() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = lastTime.map { now - $0 } ?? 0
        lastTime = now
        owed = min(owed + elapsed * Double(Tick.rate) * speed, Self.catchUpFrames * speed)
        if !host.isPaused && host.outcome == nil {
            playedSinceAutosave += elapsed
            if playedSinceAutosave >= Autosaves.interval {
                playedSinceAutosave = 0
                autosave?(self)
            }
        }
        while owed >= 1 {
            host.advance()
            owed -= 1
        }
        session.update(host.view(for: player))
        server?.frame()
    }

    // MARK: HostedMatch

    var catalogue: Catalogue { host.catalogue }
    func apply(_ order: Order, from player: PlayerID) -> OrderResult { host.apply(order, from: player) }
    func view(for player: PlayerID) -> PlayerView { host.view(for: player) }
    func drop(_ player: PlayerID) { host.drop(player) }
    func rejoin(_ player: PlayerID) { host.rejoin(player) }
    func handToComputer(_ player: PlayerID, difficulty: Difficulty) { host.handToComputer(player, difficulty: difficulty) }
    func adopt(_ catalogue: Catalogue) {
        host.adopt(catalogue)
        session.catalogue = catalogue
    }
    var tick: Int { host.tick }
    func takeBack(_ player: PlayerID) { host.takeBack(player) }
    func isComputer(_ player: PlayerID) -> Bool { host.isComputer(player) }

    /// What a save file holds: the match, whose player this Mac is, and where it was looking.
    struct Saved: Codable {
        var host: Host
        var player: PlayerID
        var camera: Camera
        /// Absent in saves made before speeds existed.
        var speed: Double?
        /// Absent in saves made before autosaves existed.
        var name: String?
        /// The lobby a match hosted across the LAN began from; absent for a match on one Mac.
        var lobby: Lobby?
        /// The texts of the tables played by; absent in saves made before the editor existed.
        var tables: TableTexts?
    }

    var saved: Saved {
        Saved(host: host, player: player, camera: session.camera, speed: speed, name: name, lobby: lobby, tables: tables)
    }

    /// Whether the match is paused, by a person or for one who dropped out.
    var isPaused: Bool { host.isPaused }

    /// The person's order, as a button of the app gives it.
    func give(_ order: Order) { issue(order) }
}

/// The app's state: the screen shown, the match in play, if any, and the
/// artwork every match shares.
@MainActor
@Observable
final class GameController {
    /// The match this Mac runs, alone or as the host of a match across the LAN.
    private(set) var match: Match?
    /// The server of a match this Mac hosts, from its lobby to its end.
    private(set) var server: HostServer?
    /// A saved match being hosted again: its saved state, waiting for the lobby to fill.
    private var resuming: Match.Saved?
    /// The list of matches on the LAN, while the person looks for one to join.
    private(set) var browser: MatchBrowser?
    /// This Mac's place in a match another Mac hosts.
    private(set) var client: MatchClient?
    /// What the person is told of the match across the LAN.
    var notices = MatchNotices(isHost: false)
    /// The player's folder of tables, and the catalogue read from it at the start
    /// (requirements 25 and 26), by which every new match on this Mac is played.
    let tableFolder = TableFolder()
    /// The tables every new match on this Mac is played by: those read at the
    /// start, or those last applied or loaded from a zip.
    private(set) var catalogue: Catalogue
    /// The texts of `catalogue`, for the editor and the zip.
    private(set) var tableTexts: TableTexts
    /// The artwork for this Mac's own tables.
    private(set) var sprites: GameSprites
    /// The artwork for another catalogue: a joining Mac's is made from the
    /// host's tables (requirement 29), and a match's anew when its tables change.
    @ObservationIgnored private var otherSprites: (catalogue: Catalogue, sprites: GameSprites)?
    /// The table editor, whilst it is open (requirement 27).
    private(set) var editor: TableEditor?
    /// Whether opening the editor paused the match, so that closing it resumes it.
    @ObservationIgnored private var editorPaused = false
    var problem: String?
    let autosaves = Autosaves()
    /// The automatic saves, newest first, for the File menu.
    private(set) var recentAutosaves: [Autosaves.Entry] = []
    /// Holds off the Mac's idle sleep and its Wi-Fi power saving while a match runs across the LAN.
    @ObservationIgnored private var activity: NSObjectProtocol?

    /// The name by which others see this person, kept between launches: the
    /// host gives a returning person's seat back by it.
    var personName: String {
        didSet { UserDefaults.standard.set(personName, forKey: "personName") }
    }

    /// The build stamp `make-app.sh` writes into the bundle; a Mac may join only a host of the same build.
    static let build = Bundle.main.object(forInfoDictionaryKey: "GreatestConquerorBuild") as? String ?? "development"

    init() {
        personName = UserDefaults.standard.string(forKey: "personName")
            ?? NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        recentAutosaves = autosaves.entries()
        let tables = tableFolder.load()
        catalogue = tables.catalogue
        tableTexts = tables.texts
        sprites = GameSprites(catalogue: tables.catalogue)
        // A fault in the tables is told once, as the app opens.
        problem = tables.problem
        AppDelegate.beforeQuitting = { [weak self] in
            self?.autosaveNow()
            let wasOnNetwork = self?.isOnNetwork ?? false
            self?.closeNetwork()
            return wasOnNetwork
        }
    }

    // MARK: Tables

    /// Opens the folder of tables in the Finder, with the stats table selected.
    func showTables() {
        try? tableFolder.seed()
        NSWorkspace.shared.activateFileViewerSelecting([tableFolder.url(.stats)])
    }

    // MARK: Saves

    /// Saves the match in play automatically, unless it is over.
    func autosaveNow() {
        guard let match, !match.isOver else { return }
        write(automatic: match)
    }

    private func write(automatic match: Match) {
        do {
            try autosaves.write(try JSONEncoder().encode(match.saved), match: match.name)
            recentAutosaves = autosaves.entries()
        } catch {
            // An automatic save that fails is tried again two minutes later; play goes on.
        }
    }

    /// A new match's name: the date and time it began.
    private static func newName(at date: Date = Date()) -> String {
        "Match of " + date.formatted(.dateTime.year().month().day().hour().minute())
    }

    // MARK: Speed

    private var localSpeed = 1.0

    /// The match's speed, shown in the Speed menu. Across the LAN it is the
    /// host's, and a change is sent so that everyone is told of it.
    var speed: Double {
        get {
            if let server { return server.speed }
            if let client, client.session != nil { return client.speed }
            return localSpeed
        }
        set {
            if let server { server.setSpeed(newValue); return }
            if let client, client.session != nil { client.setSpeed(newValue); return }
            localSpeed = newValue
            match?.speed = newValue
        }
    }

    /// One step faster or slower among `Match.speeds`, or back to normal.
    func changeSpeed(by steps: Int) {
        let speeds = Match.speeds
        let current = speeds.lastIndex { $0 <= speed } ?? 0
        speed = speeds[min(max(current + steps, 0), speeds.count - 1)]
    }

    // MARK: A match on this Mac

    func start(_ choice: NewMatchChoice) {
        let seed = UInt64.random(in: 1...UInt64.max)
        let map = MapGenerator().generate(MapRequest(size: choice.mapSize, playerCount: choice.players.count, seed: seed,
                                                     catalogue: catalogue))
        let setup = choice.setup(map: map, seed: seed, catalogue: catalogue)
        guard let person = setup.players.first(where: { $0.controller == .human }) else { return }
        let new = Match(host: Host(setup: setup), player: person.id, name: Self.newName())
        new.tables = tableTexts
        new.speed = speed
        begin(new)
    }

    private func begin(_ new: Match) {
        editor = nil
        editorPaused = false
        match?.stop()
        new.autosave = { [weak self] match in self?.write(automatic: match) }
        match = new
        new.start()
    }

    /// Whether a match across the LAN, hosted or joined, is in play or being set up.
    var isOnNetwork: Bool { server != nil || client != nil }

    /// Leave the match, or the lobby, and show the new-match screen.
    func endMatch() {
        if match == nil, client?.session == nil {
            closeNetwork()
            return
        }
        guard mayLeaveMatch(to: "start a new match") else { return }
        autosaveNow()
        editor = nil
        editorPaused = false
        match?.stop()
        match = nil
        closeNetwork()
    }

    /// Tells the others this Mac is leaving, and stops listening and looking.
    private func closeNetwork() {
        server?.close()
        server = nil
        resuming = nil
        client?.leave()
        client = nil
        browser?.stop()
        browser = nil
        notices = MatchNotices(isHost: false)
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }

    /// Whether the person agrees to leave a match still in play; the match is
    /// stopped while the question is open.
    private func mayLeaveMatch(to what: String) -> Bool {
        if match == nil, let session = client?.session, session.view.outcome == nil, !(client?.state.isFinal ?? true) {
            let alert = NSAlert()
            alert.messageText = "Leave this match?"
            alert.informativeText = "To \(what), you will leave this match. The others wait for you until the host hands your seat to a computer player."
            alert.addButton(withTitle: "Leave Match")
            alert.addButton(withTitle: "Keep Playing")
            return alert.runModal() == .alertFirstButtonReturn
        }
        guard let match, !match.isOver else { return true }
        // A hosted match runs on while the question is open, as the others are playing it.
        if server == nil { match.stop() }
        let alert = NSAlert()
        alert.messageText = "Leave this match?"
        alert.informativeText = server == nil
            ? "To \(what), this match will be closed. Save it first if you want to come back to it."
            : "To \(what), this match will be closed for everyone. It is saved automatically, and the others can join it again when you open that save."
        alert.addButton(withTitle: "Leave Match")
        alert.addButton(withTitle: "Keep Playing")
        let leave = alert.runModal() == .alertFirstButtonReturn
        if !leave { match.start() }
        return leave
    }

    // MARK: Hosting

    /// Opens the lobby of a new match across the LAN.
    func host(_ lobby: Lobby) {
        openLobby(lobby, speed: localSpeed)
    }

    private func openLobby(_ lobby: Lobby, speed: Double) {
        closeNetwork()
        let server = HostServer(lobby: lobby, build: Self.build, speed: speed,
                                speeds: Match.speeds.first!...Match.speeds.last!)
        do {
            try server.open()
        } catch {
            problem = "The match could not be offered on this network: \(error.localizedDescription)"
            return
        }
        server.onNotice = { [weak self] notice in self?.notices.receive(notice) }
        self.server = server
        notices = MatchNotices(isHost: true, lobby: lobby)
        holdActivity()
    }

    /// The host's own civilization, or a computer's, in the lobby.
    func chooseCivilization(_ civilization: Civilization) {
        if let server, let seat = server.hostSeat {
            server.chooseCivilization(civilization, for: seat)
        } else if let client {
            _ = client.chooseCivilization(civilization)
        }
    }

    /// The host starts the match from the lobby: a new one on a new map, or the saved one being resumed.
    func startHosted() {
        guard let server, let seat = server.hostSeat else { return }
        let lobby = server.lobby
        let new: Match
        if let saved = resuming {
            new = Match(host: saved.host, player: saved.player, camera: saved.camera, name: saved.name ?? lobby.name)
            new.tables = saved.tables
        } else {
            let seed = UInt64.random(in: 1...UInt64.max)
            let map = MapGenerator().generate(MapRequest(size: lobby.size, playerCount: lobby.seats.count, seed: seed,
                                                         catalogue: catalogue))
            guard let setup = lobby.setup(map: map, seed: seed, catalogue: catalogue) else { return }
            new = Match(host: Host(setup: setup), player: seat, name: lobby.name)
            new.tables = tableTexts
        }
        new.server = server
        new.lobby = resuming?.lobby ?? lobby
        guard server.start(new) else { return }
        if resuming != nil {
            // Each person's seat is played by its person if they came back, and by a computer player if not.
            for seat in lobby.seats {
                switch seat.kind {
                case .person where new.isComputer(seat.player): new.takeBack(seat.player)
                case .computer(let difficulty) where !new.isComputer(seat.player):
                    new.handToComputer(seat.player, difficulty: difficulty)
                default: break
                }
            }
        }
        resuming = nil
        notices = MatchNotices(isHost: true, lobby: lobby)
        begin(new)
    }

    /// Whether the lobby belongs to a saved match being hosted again.
    var isResuming: Bool { resuming != nil }

    /// A saved match is started without a person who has not come back: a computer player takes their seat.
    func startWithoutAbsentPeople() {
        server?.giveOpenSeatsToComputers(difficulty: .standard)
        startHosted()
    }

    /// "Continue with a computer player" for a person who dropped out.
    func handToComputer(_ seat: PlayerID, difficulty: Difficulty) {
        server?.handToComputer(seat, difficulty: difficulty)
    }

    // MARK: Joining

    /// Shows the matches on the LAN.
    func lookForMatches() {
        closeNetwork()
        let browser = MatchBrowser()
        browser.start()
        self.browser = browser
    }

    /// The matches found, as the join screen lists them.
    var foundMatches: [GameInterface.FoundMatch] {
        (browser?.matches ?? []).map { GameInterface.FoundMatch(id: $0.id, name: $0.name) }
    }

    /// Why the last attempt to join ended, for the join screen.
    private(set) var joinProblem: String?

    func join(_ found: GameInterface.FoundMatch, as name: String) {
        guard let match = browser?.matches.first(where: { $0.id == found.id }) else { return }
        personName = name
        client?.leave()
        let client = MatchClient(name: name, build: Self.build)
        client.onNotice = { [weak self] notice in self?.notices.receive(notice) }
        notices = MatchNotices(isHost: false)
        joinProblem = nil
        self.client = client
        client.join(match)
        holdActivity()
    }

    /// The joining Mac's lobby and match screens follow the client's state; one
    /// that has stopped returns the person to the join screen with the reason.
    func clientStateChanged() {
        guard let client else { return }
        if let lobby = client.lobby, client.session != nil {
            notices.names = MatchNotices(isHost: false, lobby: lobby).names
        }
        switch client.state {
        case .turnedAway(let reason), .gaveUp(let reason):
            if client.session == nil {
                joinProblem = reason
                self.client = nil
            } else {
                notices.connectionLost()
            }
        case .hostLeft:
            if client.session == nil {
                joinProblem = "The host closed the match."
                self.client = nil
            } else {
                notices.receive(.hostLeaving)
            }
        case .left:
            self.client = nil
        case .playing:
            browser?.stop()
            browser = nil
        case .idle, .connecting, .inLobby, .reconnecting:
            break
        }
    }

    /// Leaves the lobby of a match another Mac hosts, back to the join screen.
    func leaveLobby() {
        client?.leave()
        client = nil
        if browser == nil { lookForMatches() }
    }

    private func holdActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical, .idleSystemSleepDisabled],
                                                         reason: "A match across the local network")
    }

    // MARK: Files

    func save() {
        guard let match else { return }
        // The match is saved as it stood when the person asked, and waits while they name the file;
        // a hosted match runs on, as the others are playing it.
        let snapshot = match.saved
        if server == nil { match.stop() }
        defer { match.start() }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Match.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            problem = "The match could not be saved: \(error.localizedDescription)"
        }
    }

    func open() {
        guard mayLeaveMatch(to: "open a saved match") else { return }
        // A hosted match runs on whilst the person chooses, as the others are playing it.
        if server == nil { match?.stop() }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { match?.start(); return }
        open(url)
    }

    /// Opens one of the automatic saves listed in the File menu.
    func openAutosave(_ entry: Autosaves.Entry) {
        guard mayLeaveMatch(to: "open a saved match") else { return }
        open(entry.url)
    }

    private func open(_ url: URL) {
        let saved: Match.Saved
        do {
            saved = try JSONDecoder().decode(Match.Saved.self, from: Data(contentsOf: url))
        } catch {
            problem = "That file is not a saved match."
            match?.start()
            return
        }
        match?.stop()
        match = nil
        closeNetwork()
        let name = saved.name ?? url.deletingPathExtension().lastPathComponent
        if let lobby = saved.lobby, lobby.seats.contains(where: { $0.kind == .person }) {
            // A match hosted across the LAN is hosted again: the people join as before, each into a
            // seat whose civilization was chosen long ago.
            var seats = lobby.seats
            for i in seats.indices {
                seats[i].civilizationFixed = true
                if seats[i].kind == .person {
                    seats[i].formerHolder = seats[i].holder
                    seats[i].holder = nil
                }
                if seats[i].kind == .host { seats[i].holder = personName }
            }
            var resumed = saved
            resumed.name = name
            openLobby(Lobby(name: name, seats: seats), speed: saved.speed ?? 1)
            resuming = resumed
            return
        }
        let opened = Match(host: saved.host, player: saved.player, camera: saved.camera, name: name)
        opened.tables = saved.tables
        opened.speed = saved.speed ?? 1
        localSpeed = opened.speed
        begin(opened)
    }
}

// MARK: The tables during play

extension GameController {
    /// The artwork to draw a match by: made from the match's own tables, the
    /// host's on a joining Mac (requirement 29).
    func sprites(for catalogue: Catalogue) -> GameSprites {
        if catalogue == self.catalogue { return sprites }
        if let other = otherSprites, other.catalogue == catalogue { return other.sprites }
        let made = GameSprites(catalogue: catalogue)
        otherSprites = (catalogue, made)
        return made
    }

    /// What the settings offer for the tables now.
    var tableSettings: TableSettingsModel {
        if match != nil { return TableSettingsModel(place: .hosting) }
        if client?.session != nil { return TableSettingsModel(place: .joined) }
        return TableSettingsModel(place: .noMatch)
    }

    /// Opens the editor on the match's tables and pauses the match, unless it
    /// was paused already (requirement 27). Only the host may: a joining Mac
    /// has no match of its own to edit (requirement 29).
    func openTableEditor() {
        guard editor == nil, let match, !match.isOver else { return }
        let texts = match.tables ?? tableTexts
        do {
            editor = try TableEditor(texts: texts)
        } catch {
            problem = "The tables could not be opened: \(error)"
            return
        }
        editorPaused = !match.isPaused
        if editorPaused { match.give(.setPaused(true)) }
    }

    /// Closes the editor; the match resumes if opening the editor paused it.
    func closeTableEditor() {
        guard editor != nil else { return }
        editor = nil
        if editorPaused, let match, match.isPaused { match.give(.setPaused(false)) }
        editorPaused = false
    }

    /// The editor's Apply, or a zip loaded during play: the three files are
    /// saved to the folder, and the match plays by the new tables from the
    /// next tick, on every Mac in it when hosted across the network.
    func applyTables(_ texts: TableTexts, _ catalogue: Catalogue) {
        do {
            try tableFolder.write(texts)
        } catch {
            problem = "The tables could not be saved to \(tableFolder.folder.path): \(error.localizedDescription)"
            return
        }
        useForNewMatches(texts, catalogue)
        guard let match else { return }
        match.tables = texts
        if let server { server.adopt(catalogue) } else { match.adopt(catalogue) }
    }

    private func useForNewMatches(_ texts: TableTexts, _ catalogue: Catalogue) {
        tableTexts = texts
        self.catalogue = catalogue
        sprites = GameSprites(catalogue: catalogue)
        otherSprites = nil
    }

    /// "Save the tables as a zip…": the tables in use (a match's, during
    /// one), wherever the person chooses (requirement 28).
    func saveTablesAsZip() {
        let texts = match?.tables ?? tableTexts
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Greatest Conqueror tables.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try TableZip.write(texts, to: url)
        } catch {
            problem = "The tables could not be saved as a zip: \(error)"
        }
    }

    /// "Load tables from a zip…": read with the reader used at the start; in
    /// place of the folder's files, and in a match as an Apply from the editor,
    /// for the host alone (requirement 28).
    func loadTablesFromZip() {
        if let why = tableSettings.loadUnavailable { problem = why; return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let texts: TableTexts, catalogue: Catalogue
        do {
            texts = try TableZip.read(from: url)
            catalogue = try Catalogue(tables: texts)
        } catch {
            problem = "The tables in \(url.lastPathComponent) were not loaded: \(error)."
            return
        }
        if match != nil {
            applyTables(texts, catalogue)
            return
        }
        do {
            try tableFolder.write(texts)
        } catch {
            problem = "The tables could not be saved to \(tableFolder.folder.path): \(error.localizedDescription)"
            return
        }
        useForNewMatches(texts, catalogue)
    }
}
