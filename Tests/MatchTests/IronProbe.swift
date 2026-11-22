// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import ComputerPlayer
import Foundation
import GameCore
import GameNetwork
import GameSimulation
import Testing

@Test(.disabled(if: ProcessInfo.processInfo.environment["IRON_PROBE"] == nil))
func ironProbe() {
    var host = Host(setup: computerMatch(seed: 11, size: 64, difficulties: [.hard, .easy]))
    while host.outcome == nil && host.tick < matchLimit {
        host.advance()
        if host.tick % Tick.seconds(120) == 0 {
            for p in 0..<2 {
                let v = host.peek(for: PlayerID(p))
                let own = v.entities.filter { $0.owner == PlayerID(p) }
                var kinds: [String: Int] = [:]
                for e in own { kinds["\(e.kind)".replacingOccurrences(of: "unit(GameCore.UnitKind.", with: "").replacingOccurrences(of: "building(GameCore.BuildingKind.", with: "B.").replacingOccurrences(of: ")", with: ""), default: 0] += 1 }
                if p == 1 && v.entities.filter({ $0.owner == PlayerID(1) }).count < 4 {
                    let seer = host.peek(for: PlayerID(0))
                    for e in v.entities where e.owner == PlayerID(1) {
                        print("   p1 \(e.kind) at \(Int(e.position.x)),\(Int(e.position.y)) \(e.activity) seen by p0: \(seer.visibility(at: e.tile))")
                    }
                    let army = seer.entities.filter { $0.owner == PlayerID(0) && ($0.kind == .unit(.archer) || $0.kind == .unit(.spearman)) }
                    var acts: [String: Int] = [:]
                    for a in army { acts["\(a.activity)", default: 0] += 1 }
                    let mx = army.map(\.position.x).reduce(0, +) / Double(max(1, army.count)), my = army.map(\.position.y).reduce(0, +) / Double(max(1, army.count))
                    print("   p0 army \(acts) centre \(Int(mx)),\(Int(my)); unexplored tiles \(seer.visibility.filter { $0 == .unexplored }.count)")
                }
                print("t\(host.tick / Tick.rate / 60) p\(p) \(v.age) pop \(v.population)/\(v.populationLimit) paused \(v.isPaused) res \(Resource.allCases.filter { $0.firstAge <= v.age }.map { "\($0.name.prefix(2))\(v.resources[$0])" }) \(kinds.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" })")
            }
        }
    }
}

@Test(.disabled(if: ProcessInfo.processInfo.environment["IRON_SEEDS"] == nil))
func whichSeedsReachIron() {
    for seed: UInt64 in 1...10 {
        var host = Host(setup: computerMatch(seed: seed, size: 64, difficulties: [.hard, .hard]))
        var at: Int?
        while host.outcome == nil && host.tick < matchLimit {
            host.advance()
            if at == nil, host.tick % 100 == 0, host.peek(for: PlayerID(0)).players.contains(where: { $0.age == .iron }) { at = host.tick }
        }
        print("seed \(seed): iron at \(at.map { "\($0 / Tick.rate / 60) min" } ?? "never"), outcome \(String(describing: host.outcome)) at \(host.tick / Tick.rate / 60) min")
    }
}
