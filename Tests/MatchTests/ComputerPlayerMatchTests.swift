// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import ComputerPlayer
import GameCore
@testable import GameSimulation
import MapGeneration
import Testing

// The computer player through whole matches (step 7 of the plan): at each
// difficulty a match ends with a winner; a hard player goes through the five
// ages, making every tier, a doctor and a navy ship; and a match whose starts
// the water divides is won by troops the navy ships carry across.

/// The land region of each tile, by `y * width + x`: tiles a person on foot
/// can reach from one another, joined along their sides; 0 on water.
private func landRegions(_ map: GameMap) -> [Int] {
    var label = [Int](repeating: 0, count: map.width * map.height)
    var next = 0
    for start in label.indices where label[start] == 0 && map.terrain[start].isPassable {
        next += 1
        label[start] = next
        var stack = [start]
        while let here = stack.popLast() {
            let x = here % map.width, y = here / map.width
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                where nx >= 0 && ny >= 0 && nx < map.width && ny < map.height {
                let k = ny * map.width + nx
                if label[k] == 0 && map.terrain[k].isPassable { label[k] = next; stack.append(k) }
            }
        }
    }
    return label
}

/// The map with a channel of deep water, `width` tiles across, laid across it
/// midway between the first two starts and square to the line between them,
/// and the sites in the channel taken away: the two starts are then on
/// different land.
private func dividedByWater(_ map: GameMap, width: Double = 5) -> GameMap {
    var out = map
    let a = map.starts[0].centre, b = map.starts[1].centre
    let mid = MapPosition(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    let length = a.distance(to: b)
    let dx = (b.x - a.x) / length, dy = (b.y - a.y) / length
    var channel: [Bool] = Array(repeating: false, count: map.width * map.height)
    for y in 0..<map.height {
        for x in 0..<map.width {
            let along = (Double(x) + 0.5 - mid.x) * dx + (Double(y) + 0.5 - mid.y) * dy
            if abs(along) <= width / 2 {
                out.terrain[y * map.width + x] = .deepWater
                channel[y * map.width + x] = true
            }
        }
    }
    out.sites.removeAll { channel[$0.tile.y * map.width + $0.tile.x] }
    return out
}

/// Each difficulty against itself: the match ends with a winner, within forty
/// minutes, or sixty at `easy`, whose slower pace makes its matches longer
/// (twenty to fifty minutes on seeds 1 to 6 and 12, on 2026-11-22).
@Test(arguments: [(Difficulty.easy, UInt64(1)), (.standard, 13), (.hard, 14)])
func computerPlayersOfOneDifficultyPlayAMatchToAWinner(difficulty: Difficulty, seed: UInt64) {
    let limit = difficulty == .easy ? Tick.seconds(60 * 60) : matchLimit
    let host = play(computerMatch(seed: seed, size: 64, difficulties: [difficulty, difficulty]), limit: limit)
    print("\(difficulty) against \(difficulty), seed \(seed): \(String(describing: host.outcome)) at \(host.tick / Tick.rate / 60) minutes")
    #expect(host.outcome != nil, "no winner after \(host.tick / Tick.rate / 60) minutes")
}

/// A hard computer player from the age of towns, with the stock a match
/// begins with, on a map with water, opposite a player who gives no orders:
/// it reaches the age of hospitals, makes every tier of soldier, knight and
/// cannon, a doctor and a navy ship.
@Test func aHardComputerPlayerReachesTheAgeOfHospitalsAndMakesEveryTier() {
    let seed: UInt64 = 3
    let setup = computerMatch(seed: seed, size: 96, difficulties: [.hard, .hard])
    var players = setup.players
    players[1].controller = .human
    var sim = Simulation(setup: MatchSetup(map: setup.map, players: players, seed: seed, catalogue: setup.catalogue))
    var computer = ComputerPlayer(player: PlayerID(0), difficulty: .hard, seed: seed)
    let wanted = Set(UnitKind.allCases.filter(\.isWarfighter) + [.doctor, .navyShip])
    var made = Set<UnitKind>()
    var reached: [Age: Int] = [:]
    let limit = Tick.seconds(50 * 60)
    while sim.tick < limit && !(made.isSuperset(of: wanted) && reached[.hospitals] != nil) {
        // The opponent's defeat does not end the test: what is followed is the player's own play.
        sim.outcome = nil
        if sim.tick % (Tick.rate / 4) == 0 {
            let view = sim.view(for: PlayerID(0))
            for event in view.events {
                if case .trained(_, let kind) = event { made.insert(kind) }
                if case .ageReached(let age) = event { reached[age] = reached[age] ?? sim.tick / Tick.rate / 60 }
            }
            for order in computer.decide(view: view, catalogue: sim.catalogue) { _ = sim.apply(order, from: PlayerID(0)) }
        }
        sim.step()
    }
    let ages = Age.allCases.compactMap { age in reached[age].map { "\(age.name) \($0)" } }.joined(separator: ", ")
    print("hard, seed \(seed): ages reached at minutes \(ages); after \(sim.tick / Tick.rate / 60) minutes made \(made.map { "\($0)" }.sorted())")
    #expect(reached[.hospitals] != nil, "the age of hospitals not reached; ages \(ages)")
    #expect(made.isSuperset(of: wanted), "not made: \(wanted.subtracting(made).map { "\($0)" }.sorted())")
}

/// Two computer players whose starts a channel of water divides, from the age
/// of ships: the match ends with a winner, whose troops stood on the loser's
/// land, where only a navy ship can have brought them.
@Test func aMatchAcrossTheWaterIsWonByTroopsTheShipsCarry() {
    let seed: UInt64 = 7
    var setup = computerMatch(seed: seed, size: 96, difficulties: [.hard, .standard])
    setup.map = dividedByWater(setup.map)
    setup.startingAge = .ships
    let regions = landRegions(setup.map)
    let land = setup.map.starts.map { regions[$0.y * setup.map.width + $0.x] }
    #expect(land[0] != 0 && land[1] != 0 && land[0] != land[1], "the water does not divide the starts")
    var host = Host(setup: setup)
    var landed = [false, false]
    let limit = Tick.seconds(50 * 60)
    while host.outcome == nil && host.tick < limit {
        host.advance()
        guard host.tick % Tick.rate == 0 else { continue }
        for p in 0..<2 where !landed[p] {
            let view = host.peek(for: PlayerID(p))
            landed[p] = view.entities.contains { e in
                guard e.owner == PlayerID(p), case .unit(let kind) = e.kind, kind.boardsShips else { return false }
                return regions[e.tile.y * view.mapWidth + e.tile.x] == land[1 - p]
            }
        }
    }
    print("across the water, seed \(seed): \(String(describing: host.outcome)) at \(host.tick / Tick.rate / 60) minutes; troops landed \(landed)")
    #expect(host.outcome != nil, "no winner after \(host.tick / Tick.rate / 60) minutes")
    if case .won(let team)? = host.outcome {
        #expect(landed[team.rawValue], "the winner's troops never stood on the loser's land")
    }
}
