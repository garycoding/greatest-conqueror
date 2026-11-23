// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// How a level of difficulty plays. Every level plays by the same rules and
/// tables and is given nothing extra (docs/requirements.md, requirement 7 of
/// the computer player's step); the levels differ only in pace and judgement:
/// how quickly the player acts, how large an economy, army, fleet and staff of
/// doctors it aims for, how soon it advances, when and with how many it
/// attacks, how closely its army answers the opponents' warfighters, and how
/// readily it moves workers to the resource it lacks.
///
/// Lists by age are indexed by `Age.rawValue`; the last entry serves every later age.
struct Tuning: Sendable {
    /// Ticks between actions. The player reads every view it is given, so that
    /// no event is missed, but acts only this often.
    var reaction: Int
    /// The most idle workers it sets to work in one action.
    var assignments: Int
    /// The most busy workers it moves in one action to a resource that is short.
    var moves: Int
    /// Workers it aims for, by age.
    var workers: [Int]
    /// Workers it sets aside to build and repair, by age. They are counted apart from `workers`.
    var builders: [Int]
    /// Workers it has before it saves for the next age.
    var workersBeforeAdvance: Int
    /// The earliest tick at which it begins the advance out of each age, by age.
    var advanceAt: [Int]
    /// Warfighters it has, aboard ships included, before it advances out of each age, by age.
    var armyBeforeAdvance: [Int]
    /// The longest queue it keeps at a maker.
    var queue: Int
    /// Population places it keeps in hand: it begins a house when fewer remain.
    var houseMargin: Int
    /// Buildings other than houses it has under way at once.
    var builds: Int
    /// Barracks it builds; one of every other maker.
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
    /// The most warfighters it keeps, by age.
    var armyCap: [Int]
    /// Fishing boats it keeps where the water holds fish or gold.
    var boats: Int
    /// Navy ships it keeps where the map has water.
    var navy: Int
    /// Doctors it keeps.
    var doctors: Int

    func workers(at age: Age) -> Int { Tuning.at(age, workers) }
    func builders(at age: Age) -> Int { Tuning.at(age, builders) }
    func advanceAt(_ age: Age) -> Int { Tuning.at(age, advanceAt) }
    func armyBeforeAdvance(_ age: Age) -> Int { Tuning.at(age, armyBeforeAdvance) }
    func armyCap(at age: Age) -> Int { Tuning.at(age, armyCap) }

    private static func at(_ age: Age, _ list: [Int]) -> Int { list[min(age.rawValue, list.count - 1)] }

    static func of(_ difficulty: Difficulty) -> Tuning {
        let s = Tick.seconds
        func minutes(_ list: [Double]) -> [Int] { list.map { s($0 * 60) } }
        switch difficulty {
        case .easy:
            return Tuning(reaction: s(3), assignments: 3, moves: 1, workers: [10, 16, 18, 20], builders: [1, 2],
                          workersBeforeAdvance: 9, advanceAt: minutes([6, 15, 23, 31]),
                          armyBeforeAdvance: [0, 6, 8, 8], queue: 1, houseMargin: 2, builds: 1, barracks: 1,
                          attackSize: 6, firstAttack: s(15 * 60), joinSize: 4, counters: 0.25, recall: 0.8,
                          armyCap: [0, 14, 16, 18, 20], boats: 2, navy: 1, doctors: 2)
        case .standard:
            return Tuning(reaction: s(1), assignments: 6, moves: 2, workers: [14, 24, 28, 32], builders: [2, 3],
                          workersBeforeAdvance: 9, advanceAt: minutes([4, 11, 17, 23]),
                          armyBeforeAdvance: [0, 9, 10, 10], queue: 2, houseMargin: 4, builds: 2, barracks: 1,
                          attackSize: 9, firstAttack: s(10 * 60), joinSize: 4, counters: 0.7, recall: 0.9,
                          armyCap: [0, 24, 28, 32, 36], boats: 3, navy: 2, doctors: 3)
        case .hard:
            return Tuning(reaction: s(0.4), assignments: 8, moves: 3, workers: [16, 30, 36, 40], builders: [2, 4],
                          workersBeforeAdvance: 8, advanceAt: minutes([3, 8, 13, 18]),
                          armyBeforeAdvance: [0, 10, 10, 10], queue: 2, houseMargin: 6, builds: 3, barracks: 2,
                          attackSize: 10, firstAttack: s(7 * 60), joinSize: 4, counters: 1.2, recall: 0.97,
                          armyCap: [0, 34, 40, 46, 52], boats: 4, navy: 3, doctors: 4)
        }
    }
}
