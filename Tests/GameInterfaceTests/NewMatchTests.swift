// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameInterface

@Test func theDefaultMatchIsOneHumanAgainstOneComputerAndCanStart() {
    let m = NewMatchModel()
    #expect(m.canStart && m.problem == nil)
    let c = m.choice
    #expect(c.players == [
        PlayerSetup(id: PlayerID(0), civilization: .sumer, team: TeamID(0), controller: .human),
        PlayerSetup(id: PlayerID(1), civilization: .egypt, team: TeamID(1), controller: .computer(.standard)),
    ])
}

@Test func anyOfTheElevenCivilizationsMayBeChosenForEitherSeat() {
    #expect(Civilization.allCases.count == 11)
    for civ in Civilization.allCases {
        var m = NewMatchModel()
        m.setCivilization(civ, forSeat: 0)
        #expect(m.seats[0].civilization == civ)
        #expect(m.canStart)
        var n = NewMatchModel()
        n.setCivilization(civ, forSeat: 1)
        #expect(n.seats[1].civilization == civ)
        #expect(n.canStart)
    }
}

@Test func choosingTheOpponentsCivilizationSwapsThem() {
    var m = NewMatchModel()   // Sumer, Egypt
    m.setCivilization(.egypt, forSeat: 0)
    #expect(m.seats[0].civilization == .egypt && m.seats[1].civilization == .sumer)
    #expect(m.canStart)
}

@Test func theDifficultyIsChosenForTheComputerSeatOnly() {
    var m = NewMatchModel()
    m.setDifficulty(.hard, forSeat: 1)
    #expect(m.choice.players[1].controller == .computer(.hard))
    m.setDifficulty(.easy, forSeat: 0)
    #expect(m.choice.players[0].controller == .human)
}

@Test func theChoiceBecomesAMatchSetup() {
    var m = NewMatchModel()
    m.setDifficulty(.easy, forSeat: 1)
    let setup = m.choice.setup(map: Samples.map(), seed: 7)
    #expect(setup.players.count == 2 && setup.seed == 7 && setup.map == Samples.map())
    #expect(setup.players[1].controller == .computer(.easy))
}

@Test func seatsBeyondTheFirstMilestoneAreAddedToTheSameList() {
    var m = NewMatchModel(maxPlayers: 6)
    #expect(m.canAddComputerPlayer)
    let added = m.addComputerPlayer()
    #expect(added)
    #expect(m.canStart && m.seats.count == 3)   // any number from two to six (ruled 2026-11-21)
    let addedAgain = m.addComputerPlayer()
    #expect(addedAgain)
    #expect(m.canStart && m.seats.count == 4)
    // Each seat has its own civilization; computer players are on teams of their own until grouped.
    #expect(Set(m.seats.map(\.civilization)).count == 4)
    #expect(Set(m.choice.players.map(\.team)).count == 4)
    // Computer players may be grouped, or placed on the human team.
    m.setTeam(0, forSeat: 2)
    m.setTeam(1, forSeat: 3)
    #expect(m.canStart)
    #expect(m.choice.players.map(\.team) == [TeamID(0), TeamID(1), TeamID(0), TeamID(1)])
}

@Test func aSingleTeamCannotStart() {
    var m = NewMatchModel()
    m.setTeam(0, forSeat: 1)
    #expect(!m.canStart && m.problem == "A match needs at least two teams.")
}

@Test func theFirstMilestoneHoldsTwoPlayersAndTheHumanSeatStays() {
    var m = NewMatchModel()
    let added = m.addComputerPlayer()
    #expect(!m.canAddComputerPlayer && !added)
    m.removeSeat(0)
    #expect(m.seats.count == 2)
    m.removeSeat(1)
    #expect(m.seats.count == 1 && m.seats[0].isHuman && !m.canStart)
}

@Test func theSightSettingTravelsToTheMatchAndTheLobby() {
    var m = NewMatchModel()
    #expect(m.sight == .explore)
    m.sight = .everything
    #expect(m.choice.setup(map: Samples.map(), seed: 7).sight == .everything)
    #expect(m.lobby.sight == .everything)
    var lobby = m.lobby
    lobby.seats = lobby.seats.map { var s = $0; if s.civilization == nil { s.civilization = .rome }; return s }
    #expect(lobby.setup(map: Samples.map(), seed: 7)?.sight == .everything)
    m.sight = .explore
    #expect(m.choice.setup(map: Samples.map(), seed: 7).sight == nil)
}

@Test func theStartingAgeAndTheMapSizeTravelToTheMatchAndTheLobby() {
    var m = NewMatchModel()
    #expect(m.startingAge == .towns && m.mapSize == .standard)
    #expect(m.choice.setup(map: Samples.map(), seed: 7).startingAge == nil)
    m.startingAge = .ships
    m.mapSize = .large
    #expect(m.choice.setup(map: Samples.map(), seed: 7).firstAge == .ships)
    #expect(m.choice.mapSize == .large)
    #expect(m.lobby.firstAge == .ships && m.lobby.size == .large)
    var lobby = m.lobby
    lobby.seats = lobby.seats.map { var s = $0; if s.civilization == nil { s.civilization = .rome }; return s }
    #expect(lobby.setup(map: Samples.map(), seed: 7)?.firstAge == .ships)
    // A lobby without these settings decodes as the age of towns on the standard map.
    let old = try! JSONDecoder().decode(Lobby.self, from: JSONEncoder().encode(Lobby(name: "Old", seats: lobby.seats)))
    #expect(old.firstAge == .towns && old.size == .standard)
    #expect(MapSize.large.side == 2 * MapSize.standard.side)
}

@Test(arguments: 2...6) func anyNumberOfPlayersFromTwoToSixCanStart(players: Int) {
    var m = NewMatchModel(maxPlayers: 6)
    while m.seats.count < players { m.addComputerPlayer() }
    #expect(m.seats.count == players)
    #expect(m.problem == nil && m.canStart)
    #expect(m.choice.players.count == players)
    #expect(m.choice.players.map(\.id) == (0..<players).map { PlayerID($0) })
}

@Test func aMatchOfFiveMayGroupItsComputerPlayersFreely() {
    // The host and one computer player against three computer players on one team.
    var m = NewMatchModel(maxPlayers: 6)
    for _ in 0..<3 { m.addComputerPlayer() }
    m.setTeam(m.seats[0].team, forSeat: m.seats[1].id)
    m.setTeam(m.seats[2].team, forSeat: m.seats[3].id)
    m.setTeam(m.seats[2].team, forSeat: m.seats[4].id)
    #expect(m.seats.count == 5 && m.canStart)
    #expect(m.choice.players.map(\.team) == [TeamID(0), TeamID(0), TeamID(1), TeamID(1), TeamID(1)])
    #expect(Set(m.choice.players.map(\.civilization)).count == 5)
}

@Test func aMatchHasNoFewerThanTwoAndNoMoreThanSixPlayers() {
    var m = NewMatchModel(maxPlayers: 6)
    m.removeSeat(m.seats[1].id)
    #expect(m.seats.count == 1 && m.problem == "A match has two to six players." && !m.canStart)
    for _ in 0..<6 { m.addComputerPlayer() }
    #expect(m.seats.count == 6 && !m.canAddComputerPlayer && m.canStart)
}

@Test func threePeopleNeedAMatchOfAtLeastFour() {
    // Two people and a computer player make a match of three; a third person needs a fourth seat.
    var m = NewMatchModel(maxPlayers: 6, hostName: "Gary")
    m.addOpenSeat()
    #expect(m.seats.count == 3 && m.canHost)
    m.setOpen(true, forSeat: m.seats[1].id)
    #expect(m.problem == "A match needs at least two teams.")
    m.addComputerPlayer()
    #expect(m.seats.count == 4 && m.canHost)
}
