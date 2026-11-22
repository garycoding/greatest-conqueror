// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import ComputerPlayer
import Foundation
import GameCore
import GameNetwork
import GameSimulation
import MapGeneration
import Testing

@Test(.disabled(if: ProcessInfo.processInfo.environment["SEAT_REPORT"] == nil))
func reportWhichSeatWins() {
    for seed: UInt64 in 1...8 {
        let map = MapGenerator().generate(MapRequest(width: 64, height: 64, playerCount: 2, seed: seed))
        var results: [String] = []
        for swapped in [false, true] {
            let civs: [Civilization] = swapped ? [.egypt, .sumer] : [.sumer, .egypt]
            let players = (0..<2).map { PlayerSetup(id: PlayerID($0), civilization: civs[$0], team: TeamID($0), controller: .computer(.standard)) }
            var host = Host(setup: MatchSetup(map: map, players: players, seed: seed))
            while host.outcome == nil && host.tick < matchLimit { host.advance() }
            results.append("civs \(civs.map(\.name)) -> \(String(describing: host.outcome)) at \(host.tick / Tick.rate / 60) min")
        }
        print("seed \(seed): " + results.joined(separator: "; "))
    }
}
