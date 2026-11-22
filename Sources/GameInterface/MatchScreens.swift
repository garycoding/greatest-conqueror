// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import SwiftUI

// The screens around a match: setting it up, the lobby, joining one on the LAN,
// and the notices while it runs. Each takes its model and closures for what the
// person does; the app wires the closures to the connection.

// MARK: Parts

/// A rounded button of the match screens.
struct PillButton: View {
    let title: String
    var fill: Color = Palette.paper
    var enabled = true
    var size: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button { if enabled { action() } } label: {
            Text(title).font(Typeface.text(size, bold: true))
                .foregroundStyle(enabled ? Palette.ink : Palette.inkSoft)
                .padding(.horizontal, size + 4).padding(.vertical, size * 0.55)
                .cartoonBox(fill: enabled ? fill : Palette.paperDeep, radius: 100, lineWidth: 1.3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// A small button inside a seat's panel.
struct SmallButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(Typeface.text(10.5, bold: true)).padding(.horizontal, 7).padding(.vertical, 3)
                .cartoonBox(fill: Palette.paper, radius: 8, lineWidth: 0.9)
        }
        .buttonStyle(.plain)
    }
}

/// The eleven civilizations, or those offered, as buttons; the chosen one marked.
struct CivilizationGrid: View {
    var offered: [Civilization] = Civilization.allCases
    let chosen: Civilization?
    var columns = 3
    let choose: (Civilization) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: columns), spacing: 5) {
            ForEach(offered, id: \.self) { civ in
                let isChosen = civ == chosen
                Button { choose(civ) } label: {
                    HStack(spacing: 5) {
                        CivilizationDot(civilization: civ)
                        Text(civ.name).font(Typeface.text(11.5, bold: isChosen)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 5)
                    .cartoonBox(fill: isChosen ? Palette.ochre.opacity(0.6) : Palette.paper, radius: 5,
                                lineWidth: isChosen ? 1.8 : 0.9)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(civ.name)
                .accessibilityAddTraits(isChosen ? .isSelected : [])
            }
        }
    }
}

struct CivilizationDot: View {
    let civilization: Civilization?
    var size: CGFloat = 12

    var body: some View {
        Circle().fill(civilization.map(Palette.colour(of:)) ?? Palette.paper)
            .overlay(Circle().stroke(Palette.ink, style: StrokeStyle(lineWidth: 1, dash: civilization == nil ? [2, 2] : [])))
            .frame(width: size, height: size)
    }
}

/// Easy, standard and hard, the chosen one marked.
struct DifficultyRow: View {
    let chosen: Difficulty
    let choose: (Difficulty) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Difficulty.allCases, id: \.self) { d in
                let isChosen = d == chosen
                Button { choose(d) } label: {
                    Text(InterfaceText.name(of: d)).font(Typeface.text(12, bold: isChosen)).frame(maxWidth: .infinity).padding(.vertical, 6)
                        .cartoonBox(fill: isChosen ? Palette.teal.opacity(0.35) : Palette.paper, radius: 5,
                                    lineWidth: isChosen ? 1.8 : 0.9)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChosen ? .isSelected : [])
            }
        }
    }
}

/// A caption over a group of controls.
struct Caption: View {
    let text: String

    var body: some View {
        Text(text).font(Typeface.text(10, bold: true)).foregroundStyle(Palette.inkSoft)
    }
}

/// A one-line text field drawn as the rest of the interface.
struct CartoonTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(Palette.inkSoft.opacity(0.7)))
            .textFieldStyle(.plain)
            .font(Typeface.text(14))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .cartoonBox(fill: Color.white.opacity(0.55), radius: 6, lineWidth: 1.2)
    }
}

// MARK: New match

/// Choose your civilization, the computer opponents' and their difficulty. The
/// choice goes to `onStart`; the map comes from elsewhere. One seat per player,
/// so that more players and teams are more seats.
///
/// With `onHost`, seats may also be left open for people at other Macs, who
/// join the host's team (requirement 5) and choose their own civilization; the
/// match then goes to the lobby as a `Lobby`, under the name typed here.
public struct NewMatchView: View {
    @State private var model: NewMatchModel
    let onStart: (NewMatchChoice) -> Void
    let onHost: ((Lobby) -> Void)?
    let onCancel: (() -> Void)?
    let onJoin: (() -> Void)?

    /// `onJoin`, when given, offers to join a match another Mac on the LAN is hosting instead.
    public init(model: NewMatchModel = NewMatchModel(), onStart: @escaping (NewMatchChoice) -> Void,
                onHost: ((Lobby) -> Void)? = nil, onCancel: (() -> Void)? = nil, onJoin: (() -> Void)? = nil) {
        _model = State(initialValue: model)
        self.onStart = onStart
        self.onHost = onHost
        self.onCancel = onCancel
        self.onJoin = onJoin
    }

    public var body: some View {
        // Two seats to a row, three once there are more than four, so that five or six fit in two rows.
        let columns = model.seats.count > 4 ? 3 : 2
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("New match").font(Typeface.text(28, bold: true))
                Spacer()
                if let onJoin {
                    PillButton(title: "Join a match on this network", size: 12, action: onJoin)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: columns),
                      alignment: .leading, spacing: 14) {
                ForEach(model.seats) { seat in SeatPanel(model: $model, seatID: seat.id, hosting: onHost != nil) }
            }
            Text(onHost == nil
                 ? "Each player has a different civilization: choosing one that another player holds swaps the two."
                 : "Each player has a different civilization: choosing one that another player holds swaps the two. A person who joins an open seat plays on your team and chooses a civilization in the lobby.")
                .font(Typeface.text(11)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if model.canAddComputerPlayer {
                    PillButton(title: "Add a computer player", size: 12) { model.addComputerPlayer() }
                }
                if onHost != nil, model.canAddOpenSeat {
                    PillButton(title: "Add a seat for a person", size: 12) { model.addOpenSeat() }
                }
            }
            SightPicker(sight: $model.sight)
            BridgesPicker(bridges: $model.bridges)
            StartingAgePicker(age: $model.startingAge)
            MapSizePicker(size: $model.mapSize)
            if onHost != nil, model.hasOpenSeats {
                HStack(spacing: 10) {
                    Caption(text: "MATCH NAME")
                    CartoonTextField(placeholder: model.lobbyName, text: $model.matchName).frame(width: 300)
                    Text("Shown to the Macs that look for a match, and used for its saves.")
                        .font(Typeface.text(10.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                if let problem = model.problem {
                    Text(problem).font(Typeface.text(12)).foregroundStyle(Palette.brick)
                }
                Spacer()
                if let onCancel {
                    PillButton(title: "Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                }
                if let onHost, model.hasOpenSeats {
                    PillButton(title: "Open the lobby", fill: Palette.ochre, enabled: model.canHost) { onHost(model.lobby) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    PillButton(title: "Start the match", fill: Palette.ochre, enabled: model.canStart) { onStart(model.choice) }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(24)
        .frame(width: columns == 3 ? 1120 : 760)
        .cartoonBox(fill: Palette.paper, radius: 10, lineWidth: 2)
    }
}

private struct SeatPanel: View {
    @Binding var model: NewMatchModel
    let seatID: Int
    let hosting: Bool

    var body: some View {
        if let seat = model.seats.first(where: { $0.id == seatID }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(seat.isHost ? "You" : seat.isOpen ? "Open for a person" : "Computer player")
                        .font(Typeface.text(15, bold: true)).lineLimit(1)
                    Spacer()
                    if seat.isOpen {
                        // A seat open for a person follows the host's team (requirement 5).
                        Text("Team \(seat.team + 1)").font(Typeface.text(11)).foregroundStyle(Palette.inkSoft)
                    } else {
                        Menu {
                            ForEach(0..<max(2, model.seats.count), id: \.self) { team in
                                Button("Team \(team + 1)") { model.setTeam(team, forSeat: seatID) }
                            }
                        } label: {
                            Text("Team \(seat.team + 1)").font(Typeface.text(11, bold: true)).foregroundStyle(Palette.ink)
                        }
                        .tint(Palette.ink)
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .accessibilityLabel("Team for this seat")
                    }
                    if !seat.isHost && model.seats.count > 2 {
                        Button { model.removeSeat(seatID) } label: { Text("Remove").font(Typeface.text(11, bold: true)) }
                            .buttonStyle(.plain)
                    }
                }
                if seat.isOpen {
                    HStack(alignment: .top, spacing: 8) {
                        PersonGlyph(kind: .worker).frame(width: 30, height: 30)
                        Text("A person at another Mac joins this seat, on your team, and chooses a civilization in the lobby.")
                            .font(Typeface.text(11.5)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartoonBox(fill: Palette.sage.opacity(0.25), radius: 6, lineWidth: 0.9)
                    SmallButton(title: "A computer player instead") { model.setOpen(false, forSeat: seatID) }
                } else {
                    Caption(text: "Civilization")
                    CivilizationGrid(chosen: seat.civilization) { model.setCivilization($0, forSeat: seatID) }
                    if let difficulty = seat.difficulty {
                        Caption(text: "Difficulty")
                        DifficultyRow(chosen: difficulty) { model.setDifficulty($0, forSeat: seatID) }
                        if hosting, model.canOpenSeat {
                            SmallButton(title: "Open for a person") { model.setOpen(true, forSeat: seatID) }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
            .cartoonBox(fill: seat.isOpen ? Palette.paperDeep.opacity(0.45) : Palette.paper, radius: 8, lineWidth: 1.4)
        }
    }
}

// MARK: Lobby

/// The lobby, shown on every Mac while the match is set up: each seat with its
/// kind, holder, team and civilization. The host sees the match's name and
/// Start, enabled once every seat is held and has a civilization; a person who
/// joined sees their seat marked and chooses from the civilizations not taken.
public struct LobbyView: View {
    let model: LobbyModel
    let onStart: () -> Void
    let onChooseCivilization: (Civilization) -> Void
    let onLeave: () -> Void

    public init(model: LobbyModel, onStart: @escaping () -> Void = {},
                onChooseCivilization: @escaping (Civilization) -> Void = { _ in }, onLeave: @escaping () -> Void) {
        self.model = model; self.onStart = onStart; self.onChooseCivilization = onChooseCivilization; self.onLeave = onLeave
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Caption(text: model.isHost ? "YOU ARE HOSTING" : "THE MATCH YOU JOINED")
                Text(model.name).font(Typeface.text(28, bold: true)).lineLimit(1)
            }
            VStack(spacing: 6) {
                ForEach(model.rows) { row in LobbyRow(row: row) }
            }
            Text("What you see: \((model.lobby.sight ?? .explore).name). \((model.lobby.sight ?? .explore).explanation)")
                .font(Typeface.text(11.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            Text(model.lobby.bridges ? "Bridges: allowed." : "Bridges: not allowed; nobody may build one in this match.")
                .font(Typeface.text(11.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            Text("Starting age: the \(model.lobby.firstAge.name) age. Map: \(model.lobby.size.title). \(model.lobby.size.explanation)")
                .font(Typeface.text(11.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            if model.showsPicker {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.myCivilization == nil ? "Choose your civilization" : "Your civilization: \(model.myCivilization!.name)")
                        .font(Typeface.text(14, bold: true))
                    Text("Each player has a different civilization; those another player holds are not offered.")
                        .font(Typeface.text(10.5)).foregroundStyle(Palette.inkSoft)
                    CivilizationGrid(offered: model.offered, chosen: model.myCivilization, columns: 5,
                                     choose: onChooseCivilization)
                }
                .padding(12)
                .cartoonBox(fill: Palette.paper, radius: 8, lineWidth: 1.4)
            } else if let fixed = model.fixedLine {
                Text(fixed).font(Typeface.text(12)).foregroundStyle(Palette.inkSoft)
            }
            HStack {
                if let waiting = model.waitingFor {
                    Text(waiting).font(Typeface.text(12)).foregroundStyle(model.isHost ? Palette.brick : Palette.inkSoft)
                } else if !model.isHost && model.lobby.isReady {
                    Text("Ready. The host starts the match.").font(Typeface.text(12)).foregroundStyle(Palette.teal)
                }
                Spacer()
                PillButton(title: model.isHost ? "Close the lobby" : "Leave", action: onLeave).keyboardShortcut(.cancelAction)
                if model.isHost {
                    PillButton(title: "Start the match", fill: Palette.ochre, enabled: model.canStart, action: onStart)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(24)
        .frame(width: 760)
        .cartoonBox(fill: Palette.paper, radius: 10, lineWidth: 2)
    }
}

private struct LobbyRow: View {
    let row: LobbyModel.Row

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if row.kindText.hasPrefix("Computer") {
                    BuildingGlyph(kind: .townCentre)
                } else {
                    PersonGlyph(kind: .worker)
                }
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(row.holderText).font(Typeface.text(14, bold: true))
                        .foregroundStyle(row.isWaiting && row.civilization == nil && row.holderText.hasPrefix("Waiting") ? Palette.inkSoft : Palette.ink)
                    if row.isMine {
                        Text("YOU").font(Typeface.text(9, bold: true)).padding(.horizontal, 5).padding(.vertical, 1)
                            .cartoonBox(fill: Palette.ochre, radius: 4, lineWidth: 0.8)
                    }
                }
                Text(row.kindText).font(Typeface.text(10.5)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Text(row.teamText).font(Typeface.text(11.5)).foregroundStyle(Palette.inkSoft).frame(width: 60, alignment: .leading)
            HStack(spacing: 6) {
                CivilizationDot(civilization: row.civilization, size: 14)
                Text(row.civilizationText).font(Typeface.text(13, bold: row.civilization != nil))
                    .foregroundStyle(row.civilization == nil ? Palette.inkSoft : Palette.ink)
            }
            .frame(width: 130, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .cartoonBox(fill: row.isMine ? Palette.ochre.opacity(0.35) : Palette.paper, radius: 6, lineWidth: row.isMine ? 1.8 : 1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Join

/// The matches hosted on the LAN, each with Join, and the person's name. The
/// name is kept by the app between launches: it passes the stored one in and
/// stores what `onNameChange` reports.
public struct JoinView: View {
    let matches: [FoundMatch]
    let message: String?
    let onNameChange: (String) -> Void
    let onJoin: (FoundMatch, String) -> Void
    let onCancel: () -> Void
    @State private var name: String

    /// `message` is a line from the connection, such as why a host turned this Mac away.
    public init(matches: [FoundMatch], name: String, message: String? = nil, onNameChange: @escaping (String) -> Void = { _ in },
                onJoin: @escaping (FoundMatch, String) -> Void, onCancel: @escaping () -> Void) {
        self.matches = matches; self.message = message; self.onNameChange = onNameChange; self.onJoin = onJoin
        self.onCancel = onCancel
        _name = State(initialValue: name)
    }

    public var body: some View {
        let model = JoinModel(name: name, matches: matches)
        VStack(alignment: .leading, spacing: 14) {
            Text("Join a match").font(Typeface.text(28, bold: true))
            HStack(spacing: 10) {
                Caption(text: "YOUR NAME")
                CartoonTextField(placeholder: "Your name", text: $name).frame(width: 260)
                    .onChange(of: name) { _, new in onNameChange(new) }
                if let problem = model.problem {
                    Text(problem).font(Typeface.text(10.5)).foregroundStyle(Palette.brick).fixedSize(horizontal: false, vertical: true)
                }
            }
            Caption(text: "MATCHES ON THIS NETWORK")
            VStack(spacing: 6) {
                if model.rows.isEmpty {
                    Text(model.emptyLine).font(Typeface.text(13)).foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .cartoonBox(fill: Palette.paperDeep.opacity(0.5), radius: 6, lineWidth: 1)
                }
                ForEach(model.rows) { row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.name).font(Typeface.text(15, bold: true))
                            if !row.hostLine.isEmpty {
                                Text(row.hostLine).font(Typeface.text(11)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        Spacer()
                        Text(row.seatsLine).font(Typeface.text(12))
                            .foregroundStyle((row.match.openSeats ?? 1) > 0 ? Palette.ink : Palette.inkSoft)
                        PillButton(title: "Join", fill: Palette.ochre, enabled: row.canJoin, size: 13) {
                            onJoin(row.match, model.trimmedName)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .cartoonBox(fill: Palette.paper, radius: 6, lineWidth: 1)
                }
            }
            if let message {
                Text(message).font(Typeface.text(12, bold: true)).foregroundStyle(Palette.brick)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                PillButton(title: "Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(24)
        .frame(width: 760)
        .cartoonBox(fill: Palette.paper, radius: 10, lineWidth: 2)
    }
}

// MARK: Notices

/// A notice for everyone in the match, shown for a few seconds as the refusal
/// banner is; `onExpire` is called after `seconds` unless another banner replaced it.
public struct NoticeBanner: View {
    let banner: MatchNotices.Banner?
    var seconds: Double
    let onExpire: (MatchNotices.Banner) -> Void

    public init(banner: MatchNotices.Banner?, seconds: Double = 4, onExpire: @escaping (MatchNotices.Banner) -> Void = { _ in }) {
        self.banner = banner; self.seconds = seconds; self.onExpire = onExpire
    }

    public var body: some View {
        if let banner {
            Text(banner.text)
                .font(Typeface.text(14, bold: true))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .cartoonBox(fill: Palette.tealPale, radius: 8, lineWidth: 1.4)
                .task(id: banner) {
                    try? await Task.sleep(for: .seconds(seconds))
                    if !Task.isCancelled { onExpire(banner) }
                }
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// Over the map while a person is dropped out: who dropped and that the match
/// waits for them; on the host's Mac, "Continue with a computer player" at a
/// difficulty the host picks.
public struct DropPanel: View {
    let model: DropPanelModel
    let onHandToComputer: (PlayerID, Difficulty) -> Void
    @State private var difficulty: Difficulty = .standard

    public init(model: DropPanelModel, onHandToComputer: @escaping (PlayerID, Difficulty) -> Void = { _, _ in }) {
        self.model = model; self.onHandToComputer = onHandToComputer
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text(model.title).font(Typeface.text(26, bold: true)).multilineTextAlignment(.center)
            Text(model.message).font(Typeface.text(15)).multilineTextAlignment(.center)
            if model.offersComputerPlayer {
                VStack(alignment: .leading, spacing: 8) {
                    Caption(text: "OR LET A COMPUTER PLAYER TAKE THE SEAT")
                    DifficultyRow(chosen: difficulty) { difficulty = $0 }
                    Text(model.handOverLine).font(Typeface.text(10.5)).foregroundStyle(Palette.inkSoft)
                }
                .frame(width: 340)
                .padding(.top, 4)
                PillButton(title: model.handOverTitle, fill: Palette.ochre) { onHandToComputer(model.player, difficulty) }
            } else {
                Text("The host may hand the seat to a computer player.")
                    .font(Typeface.text(11.5)).foregroundStyle(Palette.inkSoft)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 40).padding(.vertical, 28)
        .cartoonBox(fill: Palette.paper, radius: 10, lineWidth: 2)
    }
}

/// On a joining Mac once the host has left or the connection is lost: the match
/// is saved on the host's Mac, and a button leads back to the start.
public struct HostLeftPanel: View {
    let model: HostLeftModel
    let onBack: () -> Void

    public init(model: HostLeftModel = HostLeftModel(), onBack: @escaping () -> Void) { self.model = model; self.onBack = onBack }

    public var body: some View {
        VStack(spacing: 12) {
            Text(model.title).font(Typeface.text(30, bold: true)).foregroundStyle(Palette.brick)
            Text(model.message).font(Typeface.text(15)).multilineTextAlignment(.center).frame(width: 380)
                .fixedSize(horizontal: false, vertical: true)
            PillButton(title: model.buttonTitle, fill: Palette.ochre, action: onBack).keyboardShortcut(.defaultAction)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 44).padding(.vertical, 30)
        .cartoonBox(fill: Palette.paper, radius: 10, lineWidth: 2)
    }
}

/// Every notice over the map, in one layer to lay over `GameHUD`'s map: the
/// banner at the top; the host-left panel or the drop panel over a dimmed map.
public struct MatchNoticeLayer: View {
    let notices: MatchNotices
    let onBannerExpired: (MatchNotices.Banner) -> Void
    let onHandToComputer: (PlayerID, Difficulty) -> Void
    let onLeave: () -> Void

    public init(notices: MatchNotices, onBannerExpired: @escaping (MatchNotices.Banner) -> Void,
                onHandToComputer: @escaping (PlayerID, Difficulty) -> Void, onLeave: @escaping () -> Void) {
        self.notices = notices; self.onBannerExpired = onBannerExpired; self.onHandToComputer = onHandToComputer
        self.onLeave = onLeave
    }

    public var body: some View {
        ZStack {
            if let hostLeft = notices.hostLeftPanel {
                Palette.ink.opacity(0.35)
                HostLeftPanel(model: hostLeft, onBack: onLeave)
            } else if let drop = notices.dropPanel {
                Palette.ink.opacity(0.35)
                DropPanel(model: drop, onHandToComputer: onHandToComputer).id(drop.player)
            }
            VStack {
                NoticeBanner(banner: notices.banner, onExpire: onBannerExpired).padding(.top, 62)
                Spacer()
            }
        }
    }
}

extension Palette {
    /// Teal laid thinly over paper, opaque: the fill of a notice, apart from a refusal's ochre.
    static let tealPale = Color(red: 0.70, green: 0.78, blue: 0.72)
}

/// The setting "What you see" (ruled 2026-11-20): three values, one chosen,
/// with what the chosen one means beneath. It applies to the people in the
/// match; computer players always explore.
struct SightPicker: View {
    @Binding var sight: MapSight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Caption(text: "WHAT YOU SEE")
                ForEach(MapSight.allCases, id: \.self) { value in
                    PillButton(title: value.name, fill: value == sight ? Palette.ochre : Palette.paper, size: 12) {
                        sight = value
                    }
                }
            }
            Text(sight.explanation + " Computer players always explore.")
                .font(Typeface.text(11)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The setting "Bridges" (ruled 2026-11-21): allowed or not allowed, for every
/// player in the match, computer players included.
struct BridgesPicker: View {
    @Binding var bridges: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Caption(text: "BRIDGES")
                ForEach([true, false], id: \.self) { value in
                    PillButton(title: value ? "Allowed" : "Not allowed", fill: value == bridges ? Palette.ochre : Palette.paper,
                               size: 12) {
                        bridges = value
                    }
                }
            }
            Text(bridges ? "Engineers may build bridges across water." : "Nobody may build a bridge in this match; water divides the map.")
                .font(Typeface.text(11)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The setting "Starting age" (ruled 2026-11-21): the age every player begins
/// in, from the Stone age to the last age the game has.
struct StartingAgePicker: View {
    @Binding var age: Age

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Caption(text: "STARTING AGE")
                ForEach(Age.allCases.filter { $0 <= Catalogue.standard.lastAge }, id: \.self) { value in
                    PillButton(title: value.name, fill: value == age ? Palette.ochre : Palette.paper, size: 12) {
                        age = value
                    }
                }
            }
            Text(age == .stone ? "Every player begins in the Stone age."
                 : "Every player begins in the \(age.name) age, with the standard start and, besides, what the advances to it would have cost.")
                .font(Typeface.text(11)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The setting "Map" (ruled 2026-11-21): the standard map, or one four times as big.
struct MapSizePicker: View {
    @Binding var size: MapSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Caption(text: "MAP")
                ForEach(MapSize.allCases, id: \.self) { value in
                    PillButton(title: value.title, fill: value == size ? Palette.ochre : Palette.paper, size: 12) {
                        size = value
                    }
                }
            }
            Text(size.explanation)
                .font(Typeface.text(11)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }
}
