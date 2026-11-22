// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameInterface

/// The host, a seat open for a person, and two computer players against each other.
func hostedModel() -> NewMatchModel {
    var m = NewMatchModel(maxPlayers: 6, hostName: "Gary")
    m.setOpen(true, forSeat: m.seats[1].id)
    m.addComputerPlayer(difficulty: .hard)
    m.addComputerPlayer(difficulty: .easy)
    m.setTeam(m.seats[2].team, forSeat: m.seats[3].id)
    return m
}

// MARK: New match

@Test func anOpenSeatIsOnTheHostsTeamAndTheMatchGoesToTheLobby() {
    let m = hostedModel()
    #expect(m.seats.map(\.isOpen) == [false, true, false, false])
    #expect(m.seats[1].team == m.seats[0].team)
    #expect(m.problem == nil)
    #expect(m.canHost && !m.canStart)
    let lobby = m.lobby
    #expect(lobby.name == "Gary\u{2019}s match")
    #expect(lobby.seats == [
        Seat(player: PlayerID(0), team: TeamID(0), kind: .host, civilization: .sumer, holder: "Gary"),
        Seat(player: PlayerID(1), team: TeamID(0), kind: .person),
        Seat(player: PlayerID(2), team: TeamID(1), kind: .computer(.hard), civilization: .egypt),
        Seat(player: PlayerID(3), team: TeamID(1), kind: .computer(.easy), civilization: .harappa),
    ])
    #expect(!lobby.isReady)
}

@Test func theTypedNameNamesTheLobby() {
    var m = hostedModel()
    m.matchName = "  Saturday  "
    #expect(m.lobby.name == "Saturday")
}

@Test func aComputerSeatMayBeOpenedAndGivenBack() {
    var m = NewMatchModel(maxPlayers: 6, hostName: "Gary")
    m.addComputerPlayer(); m.addComputerPlayer()
    let id = m.seats[2].id
    m.setOpen(true, forSeat: id)
    #expect(m.seats[2].isOpen && m.seats[2].isHuman && m.seats[2].team == m.seats[0].team)
    #expect(m.lobby.seats[2].kind == .person && m.lobby.seats[2].civilization == nil)
    m.setOpen(false, forSeat: id, difficulty: .hard)
    #expect(!m.seats[2].isOpen && m.seats[2].difficulty == .hard)
    #expect(m.lobby.seats[2].civilization != nil)
}

@Test func theHostCannotBeOpenedOrRemovedAndAtMostThreePeoplePlay() {
    var m = NewMatchModel(maxPlayers: 6)
    m.setOpen(true, forSeat: m.seats[0].id)
    #expect(m.seats[0].isHost)
    #expect(m.addOpenSeat() && m.addOpenSeat())
    #expect(!m.canAddOpenSeat && !m.addOpenSeat())
    m.setOpen(true, forSeat: m.seats[1].id)   // the computer seat: a fourth person
    #expect(!m.seats[1].isOpen)
    m.removeSeat(m.seats[0].id)
    #expect(m.seats[0].isHost)
    m.removeSeat(m.seats[2].id)
    #expect(m.openSeatCount == 1)
}

@Test func anOpenSeatHoldsNoCivilizationAndFollowsTheHostsTeam() {
    var m = hostedModel()
    // Choosing for the host the civilization an open seat nominally carries swaps nothing into it.
    let open = m.seats[1]
    m.setCivilization(.egypt, forSeat: m.seats[0].id)
    #expect(m.seats[0].civilization == .egypt && m.seats[2].civilization == .sumer)
    m.setCivilization(.rome, forSeat: open.id)
    #expect(m.lobby.seats[1].civilization == nil)
    #expect(m.problem == nil)
    m.setTeam(5, forSeat: open.id)
    #expect(m.seats[1].team == m.seats[0].team)
    m.setTeam(7, forSeat: m.seats[0].id)
    #expect(m.seats[1].team == 7)
}

@Test func withoutOpenSeatsTheMatchStartsAsBefore() {
    var m = NewMatchModel(maxPlayers: 6)
    m.addOpenSeat(); m.addComputerPlayer()
    m.removeSeat(m.seats[2].id)
    m.addComputerPlayer()
    #expect(!m.hasOpenSeats && m.canStart && !m.canHost)
    #expect(m.choice.players.map(\.controller) == [.human, .computer(.standard), .computer(.standard), .computer(.standard)])
}

// MARK: Lobby

func sampleLobby(joinerName: String? = "Hyun", joinerCivilization: Civilization? = nil, fixed: Bool = false) -> Lobby {
    var lobby = hostedModel().lobby
    lobby.seats[1].holder = joinerName
    lobby.seats[1].civilization = joinerCivilization
    if fixed { for i in lobby.seats.indices { lobby.seats[i].civilizationFixed = true } }
    return lobby
}

@Test func theLobbyShowsEachSeat() {
    let model = LobbyModel(lobby: sampleLobby(joinerName: nil), me: PlayerID(0))
    #expect(model.isHost && model.name == "Gary\u{2019}s match")
    #expect(model.rows.map(\.kindText) == ["Host", "Person", "Computer, hard", "Computer, easy"])
    #expect(model.rows.map(\.holderText) == ["Gary", "Waiting for a person", "Computer player", "Computer player"])
    #expect(model.rows.map(\.teamText) == ["Team 1", "Team 1", "Team 2", "Team 2"])
    #expect(model.rows.map(\.civilizationText) == ["Sumer", "choosing\u{2026}", "Egypt", "Harappa"])
    #expect(model.rows.map(\.isMine) == [true, false, false, false])
}

@Test func startIsEnabledForTheHostOnlyOnceTheLobbyIsReady() {
    let empty = LobbyModel(lobby: sampleLobby(joinerName: nil), me: PlayerID(0))
    #expect(!empty.canStart && empty.waitingFor == "Waiting for a person to join.")
    let choosing = LobbyModel(lobby: sampleLobby(), me: PlayerID(0))
    #expect(!choosing.canStart && choosing.waitingFor == "Waiting for Hyun to choose a civilization.")
    let ready = LobbyModel(lobby: sampleLobby(joinerCivilization: .rome), me: PlayerID(0))
    #expect(ready.canStart && ready.waitingFor == nil)
    // The joiner never starts the match.
    let joiner = LobbyModel(lobby: sampleLobby(joinerCivilization: .rome), me: PlayerID(1))
    #expect(!joiner.isHost && !joiner.canStart)
    // A joiner still choosing is not told it waits for itself.
    #expect(LobbyModel(lobby: sampleLobby(), me: PlayerID(1)).waitingFor == nil)
}

@Test func aJoinerIsOfferedOnlyTheCivilizationsNotTaken() {
    let joiner = LobbyModel(lobby: sampleLobby(), me: PlayerID(1))
    #expect(joiner.showsPicker && joiner.rows[1].isMine)
    #expect(joiner.offered == Civilization.allCases.filter { ![.sumer, .egypt, .harappa].contains($0) })
    // Their own choice stays among those offered.
    let chosen = LobbyModel(lobby: sampleLobby(joinerCivilization: .rome), me: PlayerID(1))
    #expect(chosen.offered.contains(.rome) && !chosen.offered.contains(.sumer) && chosen.myCivilization == .rome)
    // The host chooses on the new-match screen, not here.
    #expect(LobbyModel(lobby: sampleLobby(), me: PlayerID(0)).offered.isEmpty)
}

@Test func aFixedSeatOffersNoCivilization() {
    let joiner = LobbyModel(lobby: sampleLobby(joinerCivilization: .rome, fixed: true), me: PlayerID(1))
    #expect(!joiner.showsPicker && joiner.offered.isEmpty)
    #expect(joiner.fixedLine != nil)
}

// MARK: Join

@Test func theJoinListNeedsANameAndAnOpenSeat() {
    let matches = [FoundMatch(id: "a", name: "Saturday", host: "Gary", openSeats: 2),
                   FoundMatch(id: "b", name: "Full", host: "Ana", openSeats: 0)]
    let unnamed = JoinModel(name: "  ", matches: matches)
    #expect(unnamed.rows.map(\.canJoin) == [false, false] && unnamed.problem != nil)
    let named = JoinModel(name: " Hyun ", matches: matches)
    #expect(named.rows.map(\.canJoin) == [true, false] && named.problem == nil && named.trimmedName == "Hyun")
    #expect(named.rows.map(\.seatsLine) == ["2 seats open", "No seat open"])
    #expect(named.rows[0].hostLine == "Hosted by Gary")
}

// MARK: Notices

@Test func passingNoticesBecomeBanners() {
    var n = MatchNotices(isHost: false, lobby: sampleLobby())
    n.receive(.paused(by: "Hyun"))
    #expect(n.banner?.text == "Paused by Hyun.")
    n.receive(.resumed(by: "Gary"))
    #expect(n.banner?.text == "Resumed by Gary.")
    n.receive(.speedChanged(to: 2, by: "Hyun"))
    #expect(n.banner?.text == "Speed changed to 2\u{00D7} by Hyun.")
    n.receive(.speedChanged(to: 1.5, by: "Gary"))
    #expect(n.banner?.text == "Speed changed to 1.5\u{00D7} by Gary.")
    n.receive(.rejoined(player: PlayerID(1), name: "Hyun"))
    #expect(n.banner?.text == "Hyun has rejoined the match.")
    n.receive(.handedToComputer(player: PlayerID(1), difficulty: .hard))
    #expect(n.banner?.text == "Hyun\u{2019}s base is now played by a computer player (hard).")
    #expect(n.dropPanel == nil && n.hostLeftPanel == nil)
}

@Test func aBannerIsClearedOnlyWhileItIsTheOneShown() {
    var n = MatchNotices(isHost: true)
    n.receive(.paused(by: "Hyun"))
    let first = n.banner!
    n.receive(.paused(by: "Hyun"))
    #expect(n.banner != first)
    n.clearBanner(first)
    #expect(n.banner != nil)
    n.clearBanner(n.banner!)
    #expect(n.banner == nil)
}

@Test func aDropOffersTheComputerPlayerOnTheHostOnly() {
    var host = MatchNotices(isHost: true)
    var joiner = MatchNotices(isHost: false)
    for i in [0, 1] {
        var n = i == 0 ? host : joiner
        n.receive(.dropped(player: PlayerID(2), name: "Ana"))
        #expect(n.banner == nil)
        #expect(n.dropPanel?.title == "Ana has dropped out")
        #expect(n.dropPanel?.message == "The match waits for Ana to return.")
        if i == 0 { host = n } else { joiner = n }
    }
    #expect(host.dropPanel?.offersComputerPlayer == true && host.dropPanel?.difficulties == Difficulty.allCases)
    #expect(joiner.dropPanel?.offersComputerPlayer == false && joiner.dropPanel?.difficulties == [])
    // Two drops: the panel shows each until it is resolved.
    host.receive(.dropped(player: PlayerID(1), name: "Hyun"))
    host.receive(.handedToComputer(player: PlayerID(2), difficulty: .standard))
    #expect(host.dropPanel?.name == "Hyun")
    host.receive(.rejoined(player: PlayerID(1), name: "Hyun"))
    #expect(host.dropPanel == nil)
}

@Test func theHostLeavingOrALostConnectionShowsTheHostLeftPanelOnAJoiner() {
    var joiner = MatchNotices(isHost: false)
    joiner.receive(.hostLeaving)
    #expect(joiner.hostLeftPanel?.title == "The host has left")
    #expect(joiner.hostLeftPanel?.message.hasPrefix("The match is saved on the host\u{2019}s Mac") == true)
    #expect(joiner.banner == nil)
    var lost = MatchNotices(isHost: false)
    lost.connectionLost()
    #expect(lost.hostLeftPanel == HostLeftModel())
    var host = MatchNotices(isHost: true)
    host.receive(.hostLeaving); host.connectionLost()
    #expect(host.hostLeftPanel == nil)
}
