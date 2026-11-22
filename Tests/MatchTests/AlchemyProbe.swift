// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameNetwork

/// Prints, for each seed and map size, when each player reached each age and
/// what it held in the Alchemy age (`ALCHEMY_PROBE=1`).
@Test(.disabled(if: ProcessInfo.processInfo.environment["ALCHEMY_PROBE"] == nil))
func alchemyProbe() {
    let sizes = (ProcessInfo.processInfo.environment["ALCHEMY_SIZES"] ?? "64").split(separator: ",").compactMap { Int($0) }
    let seeds = (ProcessInfo.processInfo.environment["ALCHEMY_SEEDS"] ?? "3").split(separator: ",").compactMap { UInt64($0) }
    for size in sizes {
        for seed in seeds {
            var host = Host(setup: computerMatch(seed: seed, size: size, difficulties: [.hard, .hard]))
            var reached: [String] = []
            var ages: [Age] = [.stone, .stone]
            while host.outcome == nil && host.tick < Tick.seconds(60 * 60) {
                host.advance()
                guard host.tick % 200 == 0 else { continue }
                for p in 0..<2 {
                    let v = host.peek(for: PlayerID(p))
                    if v.age != ages[p] { ages[p] = v.age; reached.append("p\(p) \(v.age) \(host.tick / Tick.rate / 60)m") }
                    if v.age >= .iron && host.tick % Tick.seconds(60) == 0 && p == 1 {
                        let own = v.entities.filter { $0.owner == PlayerID(p) }
                        func n(_ k: EntityKind) -> Int { own.filter { $0.kind == k }.count }
                        print("  \(size)/\(seed) t\(host.tick / Tick.rate / 60) p\(p) stone \(v.resources[.stone]) gold \(v.resources[.gold]) food \(v.resources[.food]) iron \(v.resources[.iron]) unfinished \(own.filter { if case .underConstruction = $0.activity { return true } else { return false } }.map { "\($0.kind)".replacingOccurrences(of: "building(GameCore.BuildingKind.", with: "") }) castleState \(own.filter { $0.kind == .building(.castle) }.map { "\($0.activity)" }) engineers \(n(.unit(.engineer))) quarrying \(own.filter { $0.activity == .gathering(.stone) }.count) powder \(v.resources[.gunpowder]) wood \(v.resources[.wood]) workshop \(n(.building(.alchemistsWorkshop))) castle \(n(.building(.castle))) knights \(n(.unit(.knight))) musketeers \(n(.unit(.musketeer))) cannon \(n(.unit(.cannon))) working \(own.filter { $0.kind == .unit(.worker) && $0.activity == .working }.count)")
                    }
                }
            }
            print("size \(size) seed \(seed): \(reached.joined(separator: ", ")) -> \(String(describing: host.outcome)) at \(host.tick / Tick.rate / 60)m")
        }
    }
}
