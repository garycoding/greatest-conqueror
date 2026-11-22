// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
@testable import GameNetwork
import Testing

extension LANTests {
    /// Discovery through Bonjour, which the other tests leave out: it needs the
    /// LAN's multicast DNS and, outside a test, the person's leave to use the
    /// local network. Run it with `NETWORK_BONJOUR_TEST=1 swift test --filter Bonjour`.
    @Test(.disabled(if: ProcessInfo.processInfo.environment["NETWORK_BONJOUR_TEST"] == nil))
    func aMatchIsFoundThroughBonjourAndJoinedWithoutAnAddress() async throws {
        var lobby = eveningLobby()
        lobby.name = "Bonjour test \(UUID().uuidString.prefix(8))"
        let server = HostServer(lobby: lobby, build: testBuild)
        try server.open()
        defer { server.close() }
        let browser = MatchBrowser()
        browser.start()
        defer { browser.stop() }
        try await until("the match is found") { browser.matches.contains { $0.name == lobby.name } }
        let found = try #require(browser.matches.first { $0.name == lobby.name })
        let client = MatchClient(name: "Hyun", build: testBuild)
        client.join(found)
        defer { client.leave() }
        do {
            try await until("Hyun is seated") { client.state == .inLobby && client.lobby != nil }
        } catch {
            Issue.record("the client is \(client.state), joining \(found.endpoint); the server's problem: \(server.problem ?? "none")")
            throw error
        }
        #expect(client.lobby?.name == lobby.name)
        #expect(server.lobby.seats[1].holder == "Hyun")
    }
}
