// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Navy ships (requirements 16 and 18). From the age in which a boathouse
/// first makes them (`production.csv`), where the player has a boathouse, it
/// keeps `Tuning.navy` of them. They:
///
/// - **carry the army** to an opponent it cannot reach on foot (`ferry`): one
///   ship sails to the harbour beside the player's land, takes troops aboard,
///   sails to the opponent's shore and sets them down there, and goes back for more;
/// - **fight** the opponents' vessels in sight, and the opponents' units and
///   buildings in sight within reach of the water (`sendNavy`);
/// - **explore** the water when no opponent's building is known, and otherwise
///   keep watch off the shore of the nearest one known;
/// - **make units** at the shore, from the age the tables give (`trainArmy`).
///
/// A vessel on water no navy ship of its reaches is shot from the shore
/// instead, while no opponent's warfighter is in sight: a tower goes up beside it.
extension Turn {
    /// The navy ships it keeps: `Tuning.navy` once a boathouse stands and makes them in this age.
    var navyWanted: Int {
        guard let made = catalogue.production(of: .navyShip, at: .boatHouse), made.age <= view.age,
              catalogue.stats(.boatHouse).age <= view.age else { return 0 }
        return tuning.navy
    }

    /// A complete boathouse makes navy ships, one at a time, up to
    /// `navyWanted`; at once, from the reserve, when an opponent's vessel is in
    /// sight and no opponent's warfighter is, or when the army has an opponent
    /// to reach across the water.
    func trainNavy() {
        guard navy.count + training[UnitKind.navyShip.rawValue] < max(navyWanted, enemyVessels.isEmpty ? 0 : 1),
              let made = catalogue.production(of: .navyShip, at: .boatHouse), made.age <= view.age else { return }
        let needed = (!enemyVessels.isEmpty && !enemyUnits.contains(where: { Turn.unitKind($0)?.isWarfighter ?? false }))
            || (navy.isEmpty && memory.enemies.contains { !isReachableFrom(base, $0.position) }
                && nearestEnemyBuilding(to: base, onFoot: true) == nil)
        let stats = catalogue.stats(.navyShip)
        // At the boathouse on the largest water first.
        let houses = completeBuildings(.boatHouse).sorted { a, b in
            let x = largestWaterBeside(a), y = largestWaterBeside(b)
            return x != y ? x > y : a.id < b.id
        }
        for house in houses where isFree(house) && queueLength(house) == 0 {
            guard projectedPopulation + stats.population <= view.populationLimit else { return }
            guard canPay(stats.cost, urgent: needed) else {
                if needed { setAside(stats.cost) }
                return
            }
            train(.navyShip, at: house)
            return
        }
    }

    /// The size of the largest water region beside a building.
    func largestWaterBeside(_ building: EntityView) -> Int {
        guard case .building(let kind) = building.kind else { return 0 }
        let size = catalogue.stats(kind).footprint
        var largest = 0
        for y in (building.tile.y - 1)...(building.tile.y + size.y) {
            for x in (building.tile.x - 1)...(building.tile.x + size.x) {
                let water = regions.region(GridPoint(x, y))
                if water < 0 { largest = max(largest, regions.size(of: water)) }
            }
        }
        return largest
    }

    // MARK: Carrying troops

    /// Where the troops are set down to attack a point on other land: the open
    /// land tile on that land nearest the point that lies beside water one of
    /// the player's navy ships sails on, within twenty-four tiles; nil if there is none.
    func landingPoint(for point: MapPosition) -> MapPosition? {
        let land = regions.region(point)
        guard land > 0 else { return nil }
        prepareGround()
        for ship in navy.sorted(by: { $0.position.distance(to: base) < $1.position.distance(to: base) }) {
            let water = regions.region(ship.position)
            guard water < 0, let tile = regions.nearest(land, beside: water, to: point, within: 24, where: { tile in
                ground?.canStand(tile, in: view) ?? false
            }) else { continue }
            return tile.centre
        }
        return nil
    }

    /// The water tile beside the player's own land, nearest the base, on the
    /// water a ship sails on; nil if that water does not reach the player's land.
    func harbour(for ship: EntityView) -> MapPosition? {
        let water = regions.region(ship.position)
        guard water < 0, homeLand > 0 else { return nil }
        return regions.nearest(water, beside: homeLand, to: base, within: 40)?.centre
    }

    /// Navy ships carry the troops on the player's land to the landing of an
    /// attack across the water, as many ships as the troops fill: they sail to
    /// the harbour, the troops there board them, and once they are full, or
    /// the troops are all aboard, or none has boarded for twenty seconds, they
    /// sail together to the landing and set them down; then they go back. While
    /// the opponents' navy ships in sight outnumber its own that are free to
    /// fight, loaded ships wait at the harbour. Ships that cannot go on for
    /// three minutes are given up.
    func ferry() {
        defer { bringBack() }
        guard let campaign = memory.campaign, let landing = campaign.landing else {
            memory.ferry = nil
            return
        }
        let waiting = warfighters.filter {
            isFree($0) && memory.scout?.unit != $0.id && $0.activity != .fighting && isReachableFrom($0.position, base)
        }
        var current: Ferry
        if let ferry = memory.ferry {
            current = ferry
        } else {
            // Ships on water that reaches the landing, those with troops still aboard
            // first, then the nearest to the base.
            let able = navy.filter { isFree($0) && harbour(for: $0) != nil && regions.borders(landing.tile, regions.region($0.position)) }
                .sorted { a, b in
                    let x = a.passengers ?? 0, y = b.passengers ?? 0
                    return x != y ? x > y : a.position.distance(to: base) < b.position.distance(to: base)
                }
            let carrying = able.reduce(0) { $0 + ($1.passengers ?? 0) }
            guard !waiting.isEmpty || carrying > 0, let first = able.first, let harbour = harbour(for: first) else {
                memory.ferry = nil
                return
            }
            let water = regions.region(first.position)
            let wanted = max(1, (waiting.count + carrying + catalogue.shipCargo - 1) / max(1, catalogue.shipCargo))
            let ships = able.filter { regions.region($0.position) == water }.prefix(wanted)
            current = Ferry(ships: ships.map(\.id).sorted(), stage: .toHarbour, harbour: harbour, landing: landing,
                            since: view.tick, aboard: 0, rose: view.tick)
        }
        let ships = current.ships.compactMap { view.entity($0) }
        guard !ships.isEmpty, view.tick - current.since <= Tick.seconds(180) else {
            memory.ferry = nil
            return
        }
        current.landing = landing
        let passengers = ships.reduce(0) { $0 + ($1.passengers ?? 0) }
        let room = ships.count * catalogue.shipCargo - passengers
        switch current.stage {
        case .toHarbour:
            let docked = ships.filter { $0.activity == .idle && isAtShore($0) && $0.position.distance(to: current.harbour) < 5 }
            if docked.count == ships.count {
                current.stage = .loading
                current.since = view.tick
                current.rose = view.tick
                current.aboard = passengers
            } else {
                // A ship that has just joined is sent at once, whatever it was doing; one
                // that has stopped short of the harbour is sent again.
                let fresh = view.tick == current.since
                let sailing = ships.filter { ship in
                    isFree(ship) && !docked.contains(ship) && (fresh || ship.activity != .moving)
                        && !(ship.activity == .idle && isAtShore(ship) && ship.position.distance(to: current.harbour) < 5)
                }.map(\.id)
                if !sailing.isEmpty { give(.move(units: sailing, to: current.harbour), to: sailing) }
            }
        case .loading:
            if passengers > current.aboard {
                current.aboard = passengers
                current.rose = view.tick
            }
            let boarding = waiting.filter { $0.job == .boarding }.count
            var idle = waiting.filter { $0.job != .boarding }
            if room > boarding && !idle.isEmpty {
                // Each ship takes the nearest of the troops for its room; a doctor or two go with them.
                for ship in ships where isFree(ship) {
                    let space = catalogue.shipCargo - (ship.passengers ?? 0)
                    guard space > 0, !idle.isEmpty else { continue }
                    idle.sort { $0.position.distance(to: ship.position) < $1.position.distance(to: ship.position) }
                    var troops = Array(idle.prefix(space))
                    idle.removeFirst(troops.count)
                    let medics = doctors.filter { isFree($0) && $0.job != .healing && isReachableFrom($0.position, base) }
                    troops += medics.prefix(max(0, min(2, space - troops.count)))
                    let ids = troops.map(\.id)
                    give(.board(units: ids, ship: ship.id), to: ids)
                }
            }
            let full = room <= 0
            let allAboard = passengers > 0 && waiting.isEmpty
            let stalled = passengers > 0 && view.tick - current.rose > Tick.seconds(20)
            let outnumbered = enemyNavyInSight > navy.filter({ !current.ships.contains($0.id) }).count + ships.count
            if (full || allAboard || stalled) && !outnumbered {
                let loaded = ships.filter { isFree($0) && ($0.passengers ?? 0) > 0 }.map(\.id)
                if !loaded.isEmpty { give(.land(ships: loaded, at: current.landing), to: loaded) }
                current.stage = .sailing
                current.since = view.tick
            } else if passengers == 0 && waiting.isEmpty {
                memory.ferry = nil
                return
            } else if outnumbered {
                current.since = view.tick
            }
        case .sailing:
            if passengers == 0 {
                current.stage = .toHarbour
                current.since = view.tick
                if waiting.isEmpty {
                    memory.ferry = nil
                    return
                }
            } else {
                let stopped = ships.filter { $0.activity == .idle && isFree($0) && ($0.passengers ?? 0) > 0 }.map(\.id)
                if !stopped.isEmpty { give(.land(ships: stopped, at: current.landing), to: stopped) }
            }
        }
        memory.ferry = current
    }

    /// A ship with troops aboard that is not carrying them to an attack across
    /// the water sets them down at its harbour, on the player's own land.
    private func bringBack() {
        for ship in navy where isFree(ship) && ship.activity == .idle && (ship.passengers ?? 0) > 0
            && !(memory.ferry?.ships.contains(ship.id) ?? false) {
            guard let harbour = harbour(for: ship),
                  let shore = regions.nearest(homeLand, beside: regions.region(ship.position), to: harbour, within: 6, where: { tile in
                      prepareGround()
                      return ground?.canStand(tile, in: view) ?? false
                  }) else { continue }
            give(.land(ships: [ship.id], at: shore.centre), to: [ship.id])
        }
    }

    /// The opponents' navy ships in sight.
    var enemyNavyInSight: Int { enemyVessels.filter { $0.kind == .unit(.navyShip) }.count }

    // MARK: Fighting and exploring

    /// Each idle navy ship not carrying troops attacks the nearest opponent's
    /// vessel in sight on its water; else the nearest opponent's unit or
    /// building in sight within its reach of that water; else, with no
    /// opponent's building known, explores the water; else keeps watch off the
    /// shore of the nearest one known.
    func sendNavy() {
        for ship in navy where isFree(ship) && ship.activity == .idle && !(memory.ferry?.ships.contains(ship.id) ?? false) {
            let water = regions.region(ship.position)
            let vessels = enemyVessels.filter { regions.region($0.position) == water }
            if let target = Turn.nearest(vessels, to: ship.position) {
                give(.attack(units: [ship.id], target: target.id), to: [ship.id])
                continue
            }
            if let target = shoreTarget(for: ship, water: water) {
                give(.attack(units: [ship.id], target: target.id), to: [ship.id])
                continue
            }
            if let seen = memory.lastSeenVessels.filter({ regions.region($0) == water })
                .min(by: { $0.distance(to: ship.position) < $1.distance(to: ship.position) }), seen.distance(to: ship.position) > 3 {
                give(.move(units: [ship.id], to: clamped(seen)), to: [ship.id])
                continue
            }
            if memory.enemies.isEmpty {
                if let place = frontier(from: ship.position) ?? huntingGround(from: ship.position) {
                    give(.move(units: [ship.id], to: clamped(place)), to: [ship.id])
                }
                continue
            }
            let known = memory.enemies.min { $0.position.distance(to: ship.position) < $1.position.distance(to: ship.position) }
            if let known, let off = regions.nearest(water, to: known.position, within: 8),
               off.centre.distance(to: ship.position) > 2 {
                give(.move(units: [ship.id], to: off.centre), to: [ship.id])
            }
        }
    }

    /// The opponent's unit or building in sight, on land, nearest a ship,
    /// within twenty tiles of it, that the ship can strike from its water.
    private func shoreTarget(for ship: EntityView, water: Int32) -> EntityView? {
        let reach = catalogue.stats(.navyShip).figures(at: view.age).attack?.range ?? 0
        guard reach > 0 else { return nil }
        var best: EntityView?
        var bestDistance = Double.infinity
        for entity in view.entities where isOpponent(entity.owner) {
            if case .unit(let kind) = entity.kind, !kind.isUnit || kind.isAfloat { continue }
            let d = entity.position.distance(to: ship.position)
            guard d < 20, d < bestDistance,
                  let off = regions.nearest(water, to: entity.position, within: Int(reach)),
                  off.centre.distance(to: entity.position) <= reach else { continue }
            best = entity
            bestDistance = d
        }
        return best
    }

    /// While an opponent's vessel is in sight and no opponent's warfighter is,
    /// a tower goes up on the shore beside the nearest one that no tower of its reaches.
    func guardTheShore() {
        guard !enemyVessels.isEmpty || (memory.enemies.isEmpty && !memory.lastSeenVessels.isEmpty),
              !enemyUnits.contains(where: { Turn.unitKind($0)?.isWarfighter ?? false }),
              memory.plans.allSatisfy({ $0.kind != .tower }), !buildings.contains(where: { tower in
                  tower.kind == .building(.tower) && !Turn.isComplete(tower)
                      && !memory.unreachable.contains { $0.id == tower.id } }) else { return }
        let reach = (catalogue.stats(.tower).figures(at: view.age).attack?.range ?? 0) - 1
        // A tower begun where its builders cannot come is no guard.
        let towers = buildings.filter { tower in
            tower.kind == .building(.tower) && (Turn.isComplete(tower) || !memory.unreachable.contains { $0.id == tower.id })
        }
        // The vessels in sight, and, once no opponent's building is known, those
        // last seen on water none of its navy ships sails on.
        let sailed = Set(navy.map { regions.region($0.position) })
        let remembered = memory.enemies.isEmpty ? memory.lastSeenVessels.filter { !sailed.contains(regions.region($0)) } : []
        let places = enemyVessels.map(\.position) + remembered
        let open = places.filter { place in !towers.contains { $0.position.distance(to: place) <= reach } }
        guard let target = open.min(by: { $0.distance(to: base) < $1.distance(to: base) }) else { return }
        construct(.tower, near: target, rings: 0...Int(max(1, reach - 1)), builders: 2, urgent: true, orFarther: false)
    }
}
