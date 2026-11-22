// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
@testable import GameSimulation

// Small fixed maps and helpers for the rule tests. Each test builds the state it
// needs through the simulation's own operations (`spawnPerson`, `placeBuilding`)
// and then plays it by orders and ticks.

/// An open grass map with sites, water tiles and a start for each player.
func openMap(width: Int = 40, height: Int = 40, starts: [GridPoint], sites: [(SiteKind, Int, Int)] = [],
             water: [GridPoint] = [], catalogue: Catalogue = .standard) -> GameMap {
    var terrain = Array(repeating: Terrain.grass, count: width * height)
    for t in water { terrain[t.y * width + t.x] = .deepWater }
    let list = sites.enumerated().map { k, s in
        ResourceSite(id: SiteID(k), kind: s.0, tile: GridPoint(s.1, s.2), remaining: catalogue.gathering.amount(s.0))
    }
    return GameMap(width: width, height: height, terrain: terrain, sites: list, starts: starts)
}

/// A setup with players on the given teams; player 0 is human, the rest computers.
func setup(_ map: GameMap, teams: [Int], catalogue: Catalogue = .standard, seed: UInt64 = 1) -> MatchSetup {
    let civilizations = Civilization.allCases
    let players = teams.enumerated().map { k, team in
        PlayerSetup(id: PlayerID(k), civilization: civilizations[k], team: TeamID(team),
                    controller: k == 0 ? .human : .computer(.standard))
    }
    return MatchSetup(map: map, players: players, seed: seed, catalogue: catalogue)
}

/// Two opponents far apart on a 40 × 40 map, their town centres at (2, 2) and (34, 34).
func duel(sites: [(SiteKind, Int, Int)] = [], water: [GridPoint] = [], catalogue: Catalogue = .standard) -> Simulation {
    Simulation(setup: setup(openMap(starts: [GridPoint(2, 2), GridPoint(34, 34)], sites: sites, water: water,
                                    catalogue: catalogue), teams: [0, 1], catalogue: catalogue))
}

let me = PlayerID(0)
let them = PlayerID(1)

extension Simulation {
    mutating func run(_ ticks: Int) { for _ in 0..<ticks { step() } }

    /// Step until a condition holds, at most `limit` ticks; returns whether it held.
    @discardableResult
    mutating func run(until condition: (Simulation) -> Bool, limit: Int) -> Bool {
        for _ in 0..<limit {
            if condition(self) { return true }
            step()
        }
        return condition(self)
    }

    /// The ids of a player's people of a kind, in id order.
    func people(_ player: PlayerID, _ kind: UnitKind) -> [EntityID] {
        entities.filter { $0.alive && $0.owner == player && $0.unitKind == kind }.map(\.id)
    }

    /// The ids of a player's buildings of a kind, in id order.
    func buildings(_ player: PlayerID, _ kind: BuildingKind) -> [EntityID] {
        entities.filter { $0.alive && $0.owner == player && $0.buildingKind == kind }.map(\.id)
    }

    func townCentre(_ player: PlayerID) -> EntityID { buildings(player, .townCentre)[0] }

    func resources(_ player: PlayerID) -> ResourceAmounts { players[player.rawValue].resources }

    mutating func give(_ player: PlayerID, _ amounts: [Resource: Int]) {
        players[player.rawValue].resources = players[player.rawValue].resources + ResourceAmounts(amounts)
    }

    /// Mark every tile explored by a player's team, as if scouted.
    mutating func exploreAll(_ player: PlayerID) {
        let t = players[player.rawValue].teamIndex
        for k in 0..<(width * height) { teams[t].explored[k] = true }
    }

    /// A person put straight on the map, as the start and training do.
    @discardableResult
    mutating func add(_ kind: UnitKind, _ player: PlayerID, _ x: Double, _ y: Double) -> EntityID {
        spawnPerson(kind, owner: player, at: MapPosition(x: x, y: y))
    }

    /// A building put straight on the map.
    @discardableResult
    mutating func add(_ kind: BuildingKind, _ player: PlayerID, _ x: Int, _ y: Int, complete: Bool = true) -> EntityID {
        entities[placeBuilding(kind, owner: player, origin: GridPoint(x, y), complete: complete)].id
    }

    func health(_ id: EntityID) -> Int? { entity(id)?.health }

    /// An entity the test knows to be alive.
    func living(_ id: EntityID) -> Entity {
        guard let e = entity(id) else { preconditionFailure("\(id) is not alive") }
        return e
    }
}
