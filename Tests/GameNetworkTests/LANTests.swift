// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
@testable import GameNetwork
import Testing

extension LANTests {
    @Test func twoPeopleFillTheLobbyChooseCivilizationsAndPlay() async throws {
        let lan = try Loopback()
        defer { lan.stop() }
        let hyun = try await lan.join("Hyun")
        try await until("Hyun is seated") { hyun.state == .inLobby && hyun.lobby != nil }
        let mira = try await lan.join("Mira")
        try await until("Mira is seated") { mira.state == .inLobby && mira.lobby?.seats[2].holder == "Mira" }
        // People take the open seats in order; the host's and the computer's are not open.
        #expect(hyun.seat == PlayerID(1))
        #expect(mira.seat == PlayerID(2))
        #expect(lan.server.lobby.seats.map(\.holder) == ["Gary", "Hyun", "Mira", nil])
        try await until("Hyun sees Mira") { hyun.lobby?.seats[2].holder == "Mira" }

        // A civilization another seat holds is refused: by the client from its
        // lobby, and by the host when two ask at once.
        #expect(!hyun.chooseCivilization(.sumer))
        #expect(hyun.chooseCivilization(.harappa))
        try await until("Mira sees Harappa taken") { mira.lobby?.seats[1].civilization == .harappa }
        #expect(!mira.chooseCivilization(.harappa))
        mira.send(.chooseCivilization(.harappa))
        let asked = mira.ping()
        try await until("the host has answered") { mira.lastPong >= asked }
        #expect(lan.server.lobby.seats[1].civilization == .harappa)
        #expect(lan.server.lobby.seats[2].civilization == nil)
        #expect(!lan.server.lobby.isReady)
        #expect(!lan.server.start(StubMatch(Samples.twoPlayerSetup())))
        #expect(mira.chooseCivilization(.shang))
        try await until("the lobby is ready") { lan.server.lobby.isReady }

        let hyunReceived = Received(hyun)
        let miraReceived = Received(mira)
        lan.start()
        try await until("both play") { hyun.session != nil && mira.session != nil }
        #expect(hyun.state == .playing && mira.state == .playing)
        #expect(hyun.start?.player == PlayerID(1) && mira.start?.player == PlayerID(2))
        // The terrain is sent once, at the start, and restored to every view.
        #expect(hyun.session?.view.terrain == Samples.map().terrain)

        // Both people's orders reach the simulation, as from their seats, and
        // their effects and refusals come back in their views.
        let hyunGoes = MapPosition(x: 7.5, y: 9.5), miraGoes = MapPosition(x: 11.5, y: 3.5)
        hyun.session?.issue(.move(units: [StubSimulation.mark(of: PlayerID(1))], to: hyunGoes))
        mira.session?.issue(.move(units: [StubSimulation.mark(of: PlayerID(2))], to: miraGoes))
        mira.session?.issue(.advanceAge)
        try await until("the orders are applied") {
            lan.simulation.orders[1].contains(.move(units: [StubSimulation.mark(of: PlayerID(1))], to: hyunGoes))
                && lan.simulation.orders[2].contains(.move(units: [StubSimulation.mark(of: PlayerID(2))], to: miraGoes))
        }
        try await until("each sees the effect") {
            hyun.session?.view.entity(StubSimulation.mark(of: PlayerID(1)))?.position == hyunGoes
                && mira.session?.view.entity(StubSimulation.mark(of: PlayerID(1)))?.position == hyunGoes
                && mira.session?.view.entity(StubSimulation.mark(of: PlayerID(2)))?.position == miraGoes
        }
        try await until("Mira sees her refusal") { mira.session?.lastRefusal == .studyIncomplete }
        #expect(hyun.session?.lastRefusal == nil)

        // Play on; every event reaches each person once and in order.
        let target = lan.match!.host.tick + 60
        try await until("sixty more ticks") { lan.match!.host.tick >= target }
        lan.ticking = false
        let last = lan.match!.host.tick
        try await until("every event is delivered") { hyunReceived.ticks.last == last && miraReceived.ticks.last == last }
        #expect(hyunReceived.ticks == Array(1...last))
        #expect(miraReceived.ticks == Array(1...last))
    }

    @Test func aPersonWhoDropsHoldsTheMatchUntilTheyReconnectByName() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        hyun.reconnectDelays = [.seconds(2)]
        let session = hyun.session
        let received = Received(hyun)
        try await until("ticks run") { lan.match!.host.tick > 10 && !received.ticks.isEmpty }
        // The connection breaks once every event has reached Hyun (views lost
        // on the way are the subject of `viewsLostWhenAConnectionBreaksHaveTheirEventsSentAgain`).
        lan.ticking = false
        let before = lan.match!.host.tick
        try await until("Hyun has every event") { received.ticks.last == before }

        hyun.breakConnection()
        try await until("Mira is told") { mira.notices.contains(.dropped(player: PlayerID(1), name: "Hyun")) }
        #expect(lan.server.notices.contains(.dropped(player: PlayerID(1), name: "Hyun")))
        #expect(lan.server.dropped == [PlayerID(1)])
        #expect(hyun.state == .reconnecting(attempt: 1))
        // The match holds: no tick runs though the frames ask for them, Mira's
        // views say it is paused, and her attempt to resume is refused, which
        // she is told.
        lan.ticking = true
        let held = lan.match!.host.tick
        try await until("Mira's view shows the hold") { mira.session?.view.isPaused == true }
        mira.session?.issue(.setPaused(false))
        try await until("Mira sees the refusal") { mira.session?.lastRefusal == .notNow }
        #expect(lan.match!.host.tick == held)

        // Hyun's Mac reconnects by itself and is given back his seat by name;
        // his session, with its camera and selection, carries on.
        try await until("Hyun is back") { hyun.state == .playing && lan.server.dropped.isEmpty }
        #expect(hyun.seat == PlayerID(1))
        #expect(hyun.session === session)
        try await until("Mira is told") { mira.notices.contains(.rejoined(player: PlayerID(1), name: "Hyun")) }
        try await until("play resumes") { lan.match!.host.tick > held + 20 }
        try await until("Hyun's view moves on") { (hyun.session?.view.tick ?? 0) > held + 10 && hyun.session?.view.isPaused == false }
        // The events of the time he was away reach him once he is back.
        lan.ticking = false
        let last = lan.match!.host.tick
        try await until("every event is delivered") { received.ticks.last == last }
        #expect(received.ticks == Array(received.ticks[0]...last))
    }

    @Test func aDroppedSeatHandedToTheComputerPlaysOnAndIsTakenBack() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        #expect(!lan.server.handToComputer(PlayerID(1), difficulty: .easy), "Hyun is still here")
        hyun.leave()
        try await until("the seat is held for Hyun") { lan.server.dropped == [PlayerID(1)] }
        #expect(lan.server.handToComputer(PlayerID(1), difficulty: .easy))
        try await until("Mira is told") { mira.notices.contains(.handedToComputer(player: PlayerID(1), difficulty: .easy)) }
        #expect(lan.server.notices.contains(.handedToComputer(player: PlayerID(1), difficulty: .easy)))
        #expect(lan.server.dropped.isEmpty)
        #expect(lan.match!.host.isComputer(PlayerID(1)))

        // The match plays on, the computer player giving the seat's orders.
        let orders = lan.simulation.orders[1].count, tick = lan.match!.host.tick
        try await until("the computer plays Hyun's seat") {
            lan.simulation.orders[1].count > orders + 3 && lan.match!.host.tick > tick + 20
        }

        // Hyun comes back, on a new client, and takes his seat back.
        let back = try await lan.join("Hyun")
        try await until("Hyun plays again") { back.session != nil }
        #expect(back.seat == PlayerID(1))
        #expect(!lan.match!.host.isComputer(PlayerID(1)))
        try await until("Mira is told") { mira.notices.contains(.rejoined(player: PlayerID(1), name: "Hyun")) }
    }

    @Test func aMacOfAnotherBuildIsTurnedAwayWithBothBuildsNamed() async throws {
        let lan = try Loopback()
        defer { lan.stop() }
        let other = try await lan.join("Hyun", build: "other-build")
        try await until("it is turned away") { other.state.isFinal }
        guard case .turnedAway(let reason) = other.state else {
            Issue.record("ended as \(other.state)")
            return
        }
        #expect(reason.contains("other-build") && reason.contains(testBuild))
        #expect(lan.server.lobby.seats[1].holder == nil)
    }

    @Test func aPausedMatchStillDeliversViewsAndEveryoneIsToldOfPausesAndSpeeds() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        hyun.session?.issue(.setPaused(true))
        try await until("everyone is told") {
            mira.notices.contains(.paused(by: "Hyun")) && hyun.notices.contains(.paused(by: "Hyun"))
                && lan.server.notices.contains(.paused(by: "Hyun"))
        }
        try await until("the views show the pause") { mira.session?.view.isPaused == true && hyun.session?.view.isPaused == true }
        let paused = lan.match!.host.tick
        let received = Received(mira)
        try await Task.sleep(for: .milliseconds(500))
        // About ten views in half a second; fewer on a busy machine.
        #expect(received.views >= 3)
        #expect(lan.match!.host.tick == paused)
        // An order whilst paused is refused, and the refusal arrives.
        mira.session?.issue(.stop(units: []))
        try await until("Mira sees the refusal") { mira.session?.lastRefusal == .notNow }

        // Any person may change the speed, and everyone is told.
        mira.setSpeed(2)
        try await until("everyone is told") {
            hyun.notices.contains(.speedChanged(to: 2, by: "Mira")) && lan.server.notices.contains(.speedChanged(to: 2, by: "Mira"))
                && mira.speed == 2
        }
        #expect(lan.match!.speed == 2 && lan.server.speed == 2 && hyun.speed == 2 && mira.speed == 2)
        // A speed beyond the range is brought within it.
        lan.server.setSpeed(10)
        try await until("Hyun is told") { hyun.notices.contains(.speedChanged(to: 4, by: "Gary")) }

        // The host's person resumes.
        lan.server.issue(.setPaused(false))
        try await until("Mira is told") { mira.notices.contains(.resumed(by: "Gary")) && mira.session?.view.isPaused == false }
        #expect(lan.server.notices.last == .resumed(by: "Gary"))
    }

    @Test func aPersonWhoLeavesTheLobbyOpensTheirSeatAgain() async throws {
        let lan = try Loopback()
        defer { lan.stop() }
        let (hyun, mira) = try await lan.fill()
        hyun.leave()
        try await until("the seat is open again") { lan.server.lobby.seats[1].holder == nil }
        #expect(lan.server.lobby.seats[1].civilization == nil)
        try await until("Mira sees it open") { mira.lobby?.seats[1].holder == nil }
        let ana = try await lan.join("Ana")
        try await until("Ana takes it") { ana.seat == PlayerID(1) && ana.state == .inLobby }
    }

    @Test func aCivilizationFixedByASavedMatchCannotBeChanged() async throws {
        var lobby = eveningLobby()
        lobby.seats[1].civilization = .rome
        lobby.seats[1].civilizationFixed = true
        let lan = try Loopback(lobby: lobby)
        defer { lan.stop() }
        let hyun = try await lan.join("Hyun")
        try await until("Hyun is seated") { hyun.state == .inLobby && hyun.lobby != nil }
        #expect(hyun.seat == PlayerID(1))
        #expect(!hyun.chooseCivilization(.greece))
        hyun.send(.chooseCivilization(.greece))
        let asked = hyun.ping()
        try await until("the host has answered") { hyun.lastPong >= asked }
        #expect(lan.server.lobby.seats[1].civilization == .rome)
        // Nor may the host change it, or choose for a person; it chooses for
        // its own seat and the computers', each civilization once.
        #expect(!lan.server.chooseCivilization(.greece, for: PlayerID(1)))
        #expect(!lan.server.chooseCivilization(.rome, for: PlayerID(0)))
        #expect(lan.server.chooseCivilization(.olmec, for: PlayerID(3)))
        try await until("Hyun sees the computer's new civilization") { hyun.lobby?.seats[3].civilization == .olmec }
        // A fixed civilization stays with its seat when the person leaves.
        hyun.leave()
        try await until("the seat is open again") { lan.server.lobby.seats[1].holder == nil }
        #expect(lan.server.lobby.seats[1].civilization == .rome)
    }

    @Test func aMatchWithoutAnOpenSeatTurnsAJoinerAway() async throws {
        let lan = try Loopback()
        defer { lan.stop() }
        _ = try await lan.fill()
        let late = try await lan.join("Ana")
        try await until("Ana is turned away") { late.state.isFinal }
        #expect(late.state == .turnedAway(reason: "The match Evening has no open seat."))
        // Nor may anyone take the host's name.
        let twin = try await lan.join("Gary")
        try await until("the second Gary is turned away") { twin.state.isFinal }
        guard case .turnedAway = twin.state else { Issue.record("ended as \(twin.state)"); return }
    }

    @Test func aSecondConnectionUnderTheSameNameTakesTheSeat() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        // Hyun's Mac lost its connection without the host noticing, and made a new one.
        let again = try await lan.join("Hyun")
        try await until("the new connection plays") { again.session != nil && again.seat == PlayerID(1) }
        try await until("the old one is turned away") { hyun.state.isFinal }
        guard case .turnedAway = hyun.state else { Issue.record("ended as \(hyun.state)"); return }
        try await until("Mira is told") { mira.notices.contains(.rejoined(player: PlayerID(1), name: "Hyun")) }
        #expect(lan.server.dropped.isEmpty)
        try await until("play goes on") { (again.session?.view.tick ?? 0) > (mira.session?.view.tick ?? 0) - 5 }
    }

    @Test func everyoneIsToldWhenTheHostLeaves() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        lan.server.close()
        try await until("both are told") { hyun.state == .hostLeft && mira.state == .hostLeft }
        #expect(hyun.notices.last == .hostLeaving)
        #expect(lan.server.notices.last == .hostLeaving)
    }

    @Test func aClientGivesUpWhenTheHostCannotBeReachedAgain() async throws {
        let (lan, hyun, _) = try await Loopback.playing()
        defer { lan.stop() }
        lan.server.vanish()
        try await until("Hyun tries again") { hyun.state == .reconnecting(attempt: 1) || hyun.state.isFinal }
        try await until("Hyun gives up") { hyun.state.isFinal }
        #expect(hyun.state == .gaveUp(reason: "The connection to the host was lost and could not be made again."))
    }

    @Test func aMatchThatCannotBeReachedIsReported() async throws {
        let client = MatchClient(name: "Hyun", build: testBuild)
        client.connectLimit = .milliseconds(300)
        client.firstConnectLimit = .milliseconds(300)
        client.join(host: "127.0.0.1", port: 9)
        try await until("it gives up") { client.state.isFinal }
        #expect(client.state == .gaveUp(reason: "The host could not be reached."))
    }
}

extension LANTests {
    @Test func openSeatsGoToComputersSoThatAResumedMatchCanStartWithoutAnAbsentPerson() async throws {
        let lan = try Loopback()
        defer { lan.stop() }
        let hyun = try await lan.join("Hyun")
        try await until("Hyun is seated") { hyun.state == .inLobby && hyun.lobby != nil }
        #expect(hyun.chooseCivilization(.harappa))
        try await until("Hyun has chosen") { lan.server.lobby.seats[1].civilization == .harappa }
        #expect(!lan.server.lobby.isReady)
        #expect(lan.server.giveOpenSeatsToComputers(difficulty: .hard) == [PlayerID(2)])
        #expect(lan.server.lobby.seats[2].kind == .computer(.hard))
        #expect(lan.server.lobby.seats[2].civilization != nil)
        #expect(Set(lan.server.lobby.taken).count == lan.server.lobby.seats.count)
        #expect(lan.server.lobby.isReady)
        try await until("Hyun sees the computer") { hyun.lobby?.seats[2].kind == .computer(.hard) }
    }
}

extension LANTests {
    @Test func viewsLostWhenAConnectionBreaksHaveTheirEventsSentAgain() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        hyun.reconnectDelays = [.milliseconds(200)]
        let received = Received(hyun)
        try await until("ticks run") { lan.match!.host.tick > 10 && !received.ticks.isEmpty }

        // The views of the next forty ticks are lost on the way, and then the connection breaks.
        hyun.losesViews = true
        let from = lan.match!.host.tick
        try await until("forty ticks pass") { lan.match!.host.tick > from + 40 }
        hyun.breakConnection()
        hyun.losesViews = false
        try await until("Hyun is back") { hyun.state == .playing && lan.server.dropped.isEmpty }
        try await until("Mira is told") { mira.notices.contains(.rejoined(player: PlayerID(1), name: "Hyun")) }

        // Every event reaches Hyun once and in order, those of the lost views included.
        try await until("play moves on") { lan.match!.host.tick > from + 80 }
        lan.ticking = false
        let last = lan.match!.host.tick
        try await until("every event is delivered") { received.ticks.last == last }
        #expect(received.ticks == Array(received.ticks[0]...last))
    }
}

extension LANTests {
    @Test func inAResumedMatchEachPersonIsGivenTheirOwnSeatBack() async throws {
        var lobby = eveningLobby()
        lobby.seats[1].formerHolder = "Mira"
        lobby.seats[2].formerHolder = "Hyun"
        let lan = try Loopback(lobby: lobby)
        defer { lan.stop() }
        // Hyun comes first, but is given the seat he held, not the first open one.
        let hyun = try await lan.join("Hyun")
        try await until("Hyun is seated") { hyun.state == .inLobby && hyun.seat != nil }
        #expect(hyun.seat == PlayerID(2))
        // Someone new is kept from a seat whose person may yet come, whilst another is open.
        let ana = try await lan.join("Ana")
        try await until("Ana is seated") { ana.state == .inLobby && ana.seat != nil }
        #expect(ana.seat == PlayerID(1), "the only seat left")
    }

    @Test func whilstTheMatchHoldsForADroppedPersonEveryOrderButAPauseIsRefused() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        hyun.leave()
        try await until("the match holds") { lan.server.dropped == [PlayerID(1)] }
        let goes = MapPosition(x: 11.5, y: 3.5)
        let move = Order.move(units: [StubSimulation.mark(of: PlayerID(2))], to: goes)
        mira.session?.issue(move)
        try await until("Mira sees the refusal") { mira.session?.lastRefusal == .notNow }
        #expect(!lan.simulation.orders[2].contains(move))
        #expect(lan.server.issue(.move(units: [StubSimulation.mark(of: PlayerID(0))], to: goes)) == .refused(.notNow))
        #expect(lan.server.issue(.setPaused(true)) == .accepted)
    }
}
