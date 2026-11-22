// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// How a level of difficulty plays. Every level plays by the same rules and is
/// given nothing extra (docs/requirements.md, "The computer players"); the
/// levels differ only in how quickly the player acts, how large an economy and
/// army it aims for, when and with how many it attacks, and how closely its
/// army answers the opponents' warfighters.
struct Tuning: Sendable {
    /// Ticks between actions. The player reads every view it is given, so that
    /// no event is missed, but acts only this often.
    var reaction: Int
    /// The most idle workers it sets to work in one action.
    var assignments: Int
    /// Workers it aims for, by age; the last entry serves every later age.
    var workers: [Int]
    /// Engineers it aims for, by age; the last entry serves every later age.
    var engineers: [Int]
    /// Scholars it aims for whilst an advance lies ahead.
    var scholars: Int
    /// Workers it has before it trains a scholar.
    var workersBeforeScholars: Int
    /// The longest queue it keeps at a building.
    var queue: Int
    /// Population places it keeps in hand: it begins a house when fewer remain.
    var houseMargin: Int
    /// Buildings other than houses it has under way at once.
    var builds: Int
    /// Barracks it builds from the Bronze age.
    var barracks: Int
    /// Warfighters it gathers before its first attack; each later attack waits for two more.
    var attackSize: Int
    /// The earliest tick at which it attacks.
    var firstAttack: Int
    /// Warfighters it needs to join an allied computer player's attack.
    var joinSize: Int
    /// How far the mix of its army leans toward the kinds that beat the
    /// warfighters it has seen; 0 is not at all.
    var counters: Double
    /// The share of its memory of the opponents' warfighters that it keeps from
    /// one action to the next.
    var recall: Double
    /// The most warfighters it keeps.
    var armyCap: Int

    func workers(at age: Age) -> Int { workers[min(age.rawValue, workers.count - 1)] }
    func engineers(at age: Age) -> Int { engineers[min(age.rawValue, engineers.count - 1)] }

    static func of(_ difficulty: Difficulty) -> Tuning {
        let s = Tick.seconds
        switch difficulty {
        case .easy:
            return Tuning(reaction: s(3), assignments: 3, workers: [10, 16], engineers: [1, 2], scholars: 2,
                          workersBeforeScholars: 7, queue: 1, houseMargin: 2, builds: 1, barracks: 1,
                          attackSize: 6, firstAttack: s(15 * 60), joinSize: 4, counters: 0.25, recall: 0.8, armyCap: 14)
        case .standard:
            return Tuning(reaction: s(1), assignments: 6, workers: [14, 24], engineers: [2, 3], scholars: 4,
                          workersBeforeScholars: 6, queue: 2, houseMargin: 4, builds: 2, barracks: 1,
                          attackSize: 9, firstAttack: s(10 * 60), joinSize: 4, counters: 0.7, recall: 0.9, armyCap: 24)
        case .hard:
            return Tuning(reaction: s(0.4), assignments: 8, workers: [16, 30], engineers: [2, 4], scholars: 5,
                          workersBeforeScholars: 5, queue: 2, houseMargin: 6, builds: 3, barracks: 2,
                          attackSize: 10, firstAttack: s(7 * 60), joinSize: 4, counters: 1.2, recall: 0.97, armyCap: 34)
        }
    }
}
