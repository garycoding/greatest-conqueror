// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
@testable import GameNetwork
import Testing

extension LANTests {
    /// The pause holds for everyone in the match (requirement 30): any person
    /// may pause and resume, every view shows who paused, nothing moves, and an
    /// order given meanwhile is refused.
    @Test func aPauseHoldsForEveryMacAndShowsWhoPausedIt() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        hyun.session?.issue(.setPaused(true))
        try await until("both views show Hyun's pause") {
            hyun.session?.view.pausedBy == PlayerID(1) && mira.session?.view.pausedBy == PlayerID(1)
                && mira.session?.view.isPaused == true
        }
        let held = lan.match!.host.tick
        try await Task.sleep(for: .milliseconds(300))
        #expect(lan.match!.host.tick == held)
        #expect(mira.session?.view.tick == held && hyun.session?.view.tick == held)
        mira.session?.issue(.move(units: [StubSimulation.mark(of: PlayerID(2))], to: MapPosition(x: 9.5, y: 9.5)))
        try await until("Mira's order is refused") { mira.session?.lastRefusal == .notNow }
        // The host's own view shows the pause too.
        #expect(lan.match!.host.view(for: PlayerID(0)).pausedBy == PlayerID(1))

        // Another person resumes it.
        mira.session?.issue(.setPaused(false))
        try await until("the match moves on for both") {
            (hyun.session?.view.tick ?? 0) > held && mira.session?.view.isPaused == false && mira.session?.view.pausedBy == nil
        }
        #expect(hyun.notices.contains(.resumed(by: "Mira")))
    }

    /// The host's Apply (requirements 27 and 29): the match plays by the new
    /// tables, which change its checksum, and every joining Mac receives them;
    /// a Mac that joins afterwards receives them in the match's start.
    @Test func anApplyReachesAJoiningMacAndChangesTheChecksum() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        lan.ticking = false
        let before = lan.match!.host.checksum()
        var tuned = lan.match!.catalogue
        tuned.units[0].health += 15
        tuned.units[0].cost = ResourceAmounts([.food: 65])
        #expect(lan.server.adopt(tuned))
        #expect(lan.match!.catalogue == tuned)
        #expect(lan.match!.host.checksum() != before)
        try await until("both Macs play by the new tables") {
            hyun.session?.catalogue == tuned && mira.session?.catalogue == tuned && hyun.catalogue == tuned
        }
        // Hyun's Mac leaves and comes back: its start carries the new tables.
        hyun.breakConnection()
        try await until("Hyun is back") { hyun.state == .playing && hyun.start?.catalogue == tuned }
        #expect(hyun.session?.catalogue == tuned)
    }

    /// Only the host changes the tables (requirement 29): tables a joining Mac
    /// sends are ignored.
    @Test func onlyTheHostMayChangeTheTables() async throws {
        let (lan, hyun, mira) = try await Loopback.playing()
        defer { lan.stop() }
        let before = lan.match!.catalogue
        var tuned = before
        tuned.units[0].health += 40
        hyun.send(.tables(tuned, from: 0))
        let asked = hyun.ping()
        try await until("the host has read Hyun's messages") { hyun.lastPong >= asked }
        #expect(lan.match!.catalogue == before)
        #expect(mira.session?.catalogue == before && hyun.session?.catalogue == before)
    }
}
