// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Navy ships (requirements 16 and 18). A ship carries up to
// `Catalogue.shipCargo` troops (soldiers, knights and cannons). Troops board
// a ship of their player that is at the shore, walking to within
// `Rule.shoreReach` of it; aboard, they are out of the map: they are not
// drawn, seen, harmed or counted by any rule but the population and defeat,
// and they are lost with the ship. A ship told to land sails to the water
// tile nearest a point on land and, if it is then at the shore, sets its
// troops down at the end of the tick: on its shore tile nearest that point
// and the open tiles around it.
//
// A ship makes units as a building does, from its queue, but only whilst it
// is at the shore; each unit appears on the open land tile nearest the ship.

extension Simulation {
    /// The open land tiles whose centres lie within `Rule.shoreReach` of a ship,
    /// nearest first; ties go in row order.
    func shoreTiles(of i: Int) -> [GridPoint] {
        let p = entities[i].position, t = p.tile
        var tiles: [(GridPoint, Double)] = []
        for y in (t.y - 2)...(t.y + 2) {
            for x in (t.x - 2)...(t.x + 2) where open(x, y) {
                let d = GridPoint(x, y).centre.distance(to: p)
                if d <= Rule.shoreReach { tiles.append((GridPoint(x, y), d)) }
            }
        }
        return tiles.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 < $1.0 }.map(\.0)
    }

    /// Whether a ship is at the shore.
    func atShore(_ i: Int) -> Bool { !shoreTiles(of: i).isEmpty }

    /// The troops aboard a ship.
    func cargo(of i: Int) -> Int { entities[i].passengers?.count ?? 0 }

    /// Whether a unit kind may board a navy ship: the troops.
    static func boards(_ kind: UnitKind?) -> Bool { kind?.boardsShips ?? false }

    /// A troop walks to a ship at the shore and boards it, if there is room.
    mutating func boardTask(_ i: Int, _ ship: EntityID) {
        guard let s = index(of: ship), entities[s].unitKind == .navyShip, entities[s].owner == entities[i].owner,
              Self.boards(entities[i].unitKind), atShore(s), cargo(of: s) < catalogue.shipCargo else { setIdle(i); return }
        switch approach(i, .point(entities[s].position, reach: Rule.shoreReach, moving: true)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        // Aboard, the troop leaves the map at the end of the tick; it stays in the population.
        var aboard = entities[i]
        aboard.task = .idle
        aboard.doing = .idle
        aboard.route = Route()
        aboard.cooldown = 0
        entities[s].passengers = (entities[s].passengers ?? []) + [aboard]
        stampSight(of: i, by: -1)
        entities[i].alive = false
        deathsPending = true
    }

    /// A ship sails to the shore near a point on land; there it lands its troops.
    mutating func landTask(_ i: Int, at point: MapPosition) {
        guard let water = nearestTile(to: point.tile, afloat: true) else { setIdle(i); return }
        switch approach(i, .point(water.centre, reach: 0.5)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        if atShore(i) { landings.append((entities[i].id, point)) }
        setIdle(i)
    }

    /// The troops of every ship that reached the shore this tick go ashore,
    /// on the open tiles nearest the point it was sent to, and rejoin the map
    /// in the order of their ids.
    mutating func landPassengers() {
        var landed: [EntityID] = []
        for (ship, point) in landings {
            guard let s = index(of: ship), let passengers = entities[s].passengers, !passengers.isEmpty else { continue }
            entities[s].passengers = nil
            var spots = [GridPoint]()
            let shore = shoreTiles(of: s).min { $0.centre.distance(to: point) < $1.centre.distance(to: point) }
            if let first = shore ?? nearestOpenTile(to: point.tile) {
                spots.append(first)
                var k = 0
                while spots.count < passengers.count && k < passengers.count * 8 {
                    let t = freeTile(beside: first, size: GridPoint(1, 1), index: k)
                    if !spots.contains(t) { spots.append(t) }
                    k += 1
                }
            }
            for (k, var person) in passengers.enumerated() {
                let tile = spots.isEmpty ? entities[s].position.tile : spots[k % spots.count]
                person.position = tile.centre
                person.stamp = tile
                person.alive = true
                entities.append(person)
                landed.append(person.id)
            }
        }
        landings.removeAll()
        guard !landed.isEmpty else { return }
        entities.sort { $0.id < $1.id }
        for i in entities.indices where entities[i].alive { indexOfEntity[entities[i].id.rawValue] = Int32(i) }
        for id in landed { if let i = index(of: id) { stampSight(of: i, by: 1) } }
        buckets.rebuild(entities: entities, width: width, height: height)
    }

    /// A ship at the shore makes the head of its queue; the unit appears on the
    /// open land tile nearest it (requirement 18).
    mutating func makeAtShore(_ i: Int) {
        guard let head = entities[i].queue.first, let maker = entities[i].unitKind else { return }
        let shore = shoreTiles(of: i)
        guard !shore.isEmpty else { return }
        let time = tables.trainTime(head, at: .unit(maker))
        if entities[i].trainProgress < time { entities[i].trainProgress += 1 }
        let p = entities[i].owner.rawValue
        guard entities[i].trainProgress >= time, population[p] + tables.unit(head).population <= populationLimit(p) else { return }
        entities[i].queue.removeFirst()
        entities[i].trainProgress = 0
        let spot = shore[entities[i].spawned % shore.count]
        entities[i].spawned += 1
        let id = spawnPerson(head, owner: entities[i].owner, at: spot.centre)
        record(.trained(id, head), for: p)
    }
}
