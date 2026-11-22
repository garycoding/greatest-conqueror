// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Orders. Each is checked in full before it changes anything, and a refusal is
// also recorded as `GameEvent.refused` for the player's next view. Costs are
// paid when an order is accepted.
//
// Which refusal: `.notNow` whilst paused, after the outcome, or for a player
// of a defeated team; `.notYours` when an entity named is not the player's (or does not
// exist), or when none of the people named can carry the order out;
// `.invalidTarget` when the target cannot be acted on in that way, or is not in
// the player's sight; then the age, population and cost checks of the order.

extension Simulation {
    public mutating func apply(_ order: Order, from player: PlayerID) -> OrderResult {
        let result = evaluate(order, from: player)
        if case .refused(let why) = result, let p = slot(player) { record(.refused(why), for: p) }
        return result
    }

    mutating func evaluate(_ order: Order, from player: PlayerID) -> OrderResult {
        guard let p = slot(player) else { return .refused(.notYours) }
        if case .setPaused(let paused) = order {
            guard players[p].isHuman else { return .refused(.notYours) }
            isPaused = paused
            return .accepted
        }
        // A defeated player whose team stands still gives orders: a person
        // comes back through a founder (ruled 2026-11-22).
        if isPaused || outcome != nil || teams[players[p].teamIndex].isDefeated { return .refused(.notNow) }
        switch order {
        case .move(let units, let to): return move(units, to: to, player: player)
        case .gather(let units, let site): return gather(units, at: site, player: player)
        case .work(let units, let at): return work(units, at: at, player: player)
        case .demolish(let workers, let building): return demolish(workers, building, player: player)
        case .construct(let workers, let building, let at): return construct(workers, building, at: at, player: player)
        case .attack(let units, let target): return attack(units, target: target, player: player)
        case .train(let at, let unit): return train(unit, at: at, player: player)
        case .cancelTraining(let at): return cancelTraining(at: at, player: player)
        case .advanceAge(let at): return advanceAge(at: at, player: player)
        case .stop(let units): return stop(units, player: player)
        case .dismiss(let units): return dismiss(units, player: player)
        case .reseed(let farm): return reseed(farm, player: player)
        case .summonCar: return summonCar(player: player)
        case .setKillRadius(let cars, let on): return setKillRadius(cars, on: on, player: player)
        case .heal(let doctors, let target): return heal(doctors, target, player: player)
        case .board(let units, let ship): return board(units, ship, player: player)
        case .land(let ships, let at): return land(ships, at: at, player: player)
        case .found(let founder, let at): return found(founder, at: at, player: player)
        case .setPaused: return .accepted
        }
    }

    /// The indices of the people named, in id order, if every one is the player's.
    func ownPeople(_ ids: [EntityID], _ player: PlayerID) -> [Int]? {
        var out: [Int] = []
        for id in ids {
            guard let i = index(of: id), entities[i].owner == player, entities[i].isPerson else { return nil }
            out.append(i)
        }
        out.sort()
        var unique: [Int] = []
        for i in out where unique.last != i { unique.append(i) }
        return unique.isEmpty ? nil : unique
    }

    /// The index of a building, if it is the player's.
    func ownBuilding(_ id: EntityID, _ player: PlayerID) -> Int? {
        guard let i = index(of: id), entities[i].owner == player, !entities[i].isPerson else { return nil }
        return i
    }

    /// Pay a cost, or say what is short.
    mutating func pay(_ cost: ResourceAmounts, _ player: Int) -> OrderRefusal? {
        let held = players[player].resources
        guard held.covers(cost) else { return .notEnough(held.shortfall(for: cost)) }
        players[player].resources = held - cost
        return nil
    }

    // MARK: People

    mutating func move(_ ids: [EntityID], to point: MapPosition, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        guard point.x >= 0, point.y >= 0, point.x < Double(width), point.y < Double(height) else {
            return .refused(.invalidTarget)
        }
        // People on foot and vessels each go to the nearest tile they may enter:
        // land for the one, water for the other.
        for afloat in [false, true] {
            let group = people.filter { entities[$0].isAfloat == afloat }
            guard !group.isEmpty else { continue }
            var centre = point
            if !open(point.tile.x, point.tile.y, afloat: afloat) {
                guard let free = nearestTile(to: point.tile, afloat: afloat) else { return .refused(.invalidTarget) }
                centre = free.centre
            }
            // People sent together spread over a small square around the point.
            let side = Int(Double(group.count).squareRoot().rounded(.up))
            for (k, i) in group.enumerated() {
                let col = Double(k % side) - Double(side - 1) / 2, row = Double(k / side) - Double(side - 1) / 2
                var spot = MapPosition(x: centre.x + col * Rule.formationSpacing, y: centre.y + row * Rule.formationSpacing)
                if !(spot.x >= 0 && spot.y >= 0 && spot.x < Double(width) && spot.y < Double(height))
                    || !open(spot.tile.x, spot.tile.y, afloat: afloat) {
                    spot = centre
                }
                assign(i, .move(spot))
            }
        }
        return .accepted
    }

    mutating func gather(_ ids: [EntityID], at site: SiteID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player),
              people.contains(where: { [.worker, .fishingBoat].contains(entities[$0].unitKind) }) else { return .refused(.notYours) }
        let p = player.rawValue
        guard let s = siteIndex(of: site), isExplored(sites[s].tile, byPlayer: p) else {
            return .refused(.invalidTarget)
        }
        // Workers gather on land, boats in the water (ruled 2026-11-21).
        let gatherer: UnitKind = isAfloat(sites[s]) ? .fishingBoat : .worker
        let workers = people.filter { entities[$0].unitKind == gatherer }
        guard !workers.isEmpty else { return .refused(.invalidTarget) }
        let kind = sites[s].kind
        guard tables.unit(gatherer).gathers(kind.yield) > 0 else { return .refused(.invalidTarget) }
        for i in workers {
            if let cargo = entities[i].cargo, cargo.kind != kind { entities[i].cargo = nil }
            entities[i].fraction = 0
            assign(i, .gather(site: site, kind: kind, tile: sites[s].tile))
        }
        return .accepted
    }

    mutating func work(_ ids: [EntityID], at building: EntityID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        // A founder works only at the town centre it founded (`hasWork`).
        let able = people.filter { entities[$0].unitKind == .worker || entities[$0].isFounder }
        guard !able.isEmpty else { return .refused(.notYours) }
        guard let b = ownBuilding(building, player) else { return .refused(.invalidTarget) }
        var busy = able.filter { hasWork(at: b, person: $0) }
        if entities[b].buildingKind == .farm, entities[b].complete, entities[b].health >= entities[b].maxHealth,
           let first = busy.first {
            // One worker tends a farm; the others selected are left as they were.
            busy.removeAll { $0 != first }
        }
        guard !busy.isEmpty else { return .refused(.invalidTarget) }
        for i in busy {
            entities[i].fraction = 0
            assign(i, .work(building))
        }
        return .accepted
    }

    mutating func demolish(_ ids: [EntityID], _ building: EntityID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let workers = people.filter { entities[$0].unitKind == .worker }
        guard !workers.isEmpty else { return .refused(.notYours) }
        guard ownBuilding(building, player) != nil else { return .refused(.invalidTarget) }
        for i in workers { assign(i, .demolish(building)) }
        return .accepted
    }

    mutating func construct(_ ids: [EntityID], _ kind: BuildingKind, at origin: GridPoint, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let workers = people.filter { entities[$0].unitKind == .worker }
        guard !workers.isEmpty else { return .refused(.notYours) }
        let p = player.rawValue
        let stats = tables.building(kind)
        guard players[p].age >= stats.age else { return .refused(.ageNotReached(stats.age)) }
        guard canPlace(kind, at: origin, player: p) else { return .refused(.placementBlocked) }
        if let short = pay(stats.cost, p) { return .refused(short) }
        let b = placeBuilding(kind, owner: player, origin: origin, complete: false)
        let id = entities[b].id
        for i in workers { assign(i, .work(id)) }
        return .accepted
    }

    /// `Placement`'s rule, applied to the full state and the team's exploration.
    func canPlace(_ kind: BuildingKind, at origin: GridPoint, player p: Int) -> Bool {
        var occupied = Set<GridPoint>()
        for t in Placement.footprint(kind, at: origin, catalogue: catalogue) where inMap(t) {
            let k = tileIndex(t)
            if buildingAt[k] >= 0 || siteAt[k] >= 0 { occupied.insert(t) }
        }
        return Placement.canPlace(kind, at: origin, width: width, height: height, terrain: terrain, occupied: occupied,
                                  explored: { isExplored($0, byPlayer: p) }, catalogue: catalogue)
    }

    mutating func attack(_ ids: [EntityID], target: EntityID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let team = players[player.rawValue].teamIndex
        // A car burns buildings with its laser (ruled 2026-11-21): an opponent's building only.
        let cars = people.filter { entities[$0].unitKind == .car }
        if !cars.isEmpty, let t = index(of: target), !entities[t].isPerson, teamOf(entities[t].owner) != team,
           seesEverything(player.rawValue) || isVisible(entities[t], to: team) {
            for i in cars { assign(i, .attack(target)) }
        }
        let able = people.filter { i in entities[i].unitKind.map { tables.unit($0).attack != nil } ?? false }
        if able.isEmpty && !cars.isEmpty {
            return cars.contains(where: { entities[$0].task == .attack(target) }) ? .accepted : .refused(.cannotAttack)
        }
        guard !able.isEmpty else { return .refused(.notYours) }
        guard let t = index(of: target), seesEverything(player.rawValue) || isVisible(entities[t], to: team) else {
            return .refused(.invalidTarget)
        }
        guard teamOf(entities[t].owner) != team, !entities[t].isUnharmable else { return .refused(.cannotAttack) }
        for i in able { assign(i, .attack(target)) }
        return .accepted
    }

    mutating func stop(_ ids: [EntityID], player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        for i in people { setIdle(i) }
        return .accepted
    }

    /// A founder cannot be dismissed (as in Cities of Progress).
    mutating func dismiss(_ ids: [EntityID], player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let leaving = people.filter { !entities[$0].isFounder }
        guard !leaving.isEmpty else { return .refused(.notYours) }
        for i in leaving { kill(i) }
        return .accepted
    }

    // MARK: Buildings

    /// The index of a maker of the player's: a building, or a unit that makes
    /// units (a navy ship).
    func ownMaker(_ id: EntityID, _ player: PlayerID) -> Int? {
        guard let i = index(of: id), entities[i].owner == player else { return nil }
        if entities[i].isPerson { return entities[i].unitKind.map { tables.unit($0).trains.isEmpty } == false ? i : nil }
        return i
    }

    mutating func train(_ kind: UnitKind, at building: EntityID, player: PlayerID) -> OrderResult {
        guard let b = ownMaker(building, player) else { return .refused(.notYours) }
        guard entities[b].complete, let made = catalogue.production(of: kind, at: entities[b].kind),
              let stats = tables.units[kind.rawValue]
        else { return .refused(.invalidTarget) }
        let p = player.rawValue
        guard players[p].age >= made.age else { return .refused(.ageNotReached(made.age)) }
        guard population[p] + queuedPopulation(p) + stats.population <= populationLimit(p) else {
            return .refused(.populationLimit)
        }
        if let short = pay(stats.cost, p) { return .refused(short) }
        entities[b].queue.append(kind)
        return .accepted
    }

    mutating func cancelTraining(at building: EntityID, player: PlayerID) -> OrderResult {
        guard let b = ownMaker(building, player) else { return .refused(.notYours) }
        guard let last = entities[b].queue.popLast() else { return .refused(.invalidTarget) }
        if entities[b].queue.isEmpty { entities[b].trainProgress = 0 }
        let p = player.rawValue
        players[p].resources = players[p].resources + tables.unit(last).cost
        return .accepted
    }

    // MARK: The player

    /// The advance to the next age begins at a complete town centre of the
    /// player's, paying its cost; one advance at a time (requirement 6).
    mutating func advanceAge(at building: EntityID, player: PlayerID) -> OrderResult {
        let p = player.rawValue
        guard let b = ownBuilding(building, player) else { return .refused(.notYours) }
        guard entities[b].buildingKind == .townCentre, entities[b].complete else { return .refused(.invalidTarget) }
        guard players[p].age.next != nil, let advance = catalogue.advance(from: players[p].age) else {
            return .refused(.invalidTarget)
        }
        guard !entities.contains(where: { $0.alive && $0.owner == player && $0.advancing != nil }) else {
            return .refused(.notNow)
        }
        if let short = pay(advance.cost, p) { return .refused(short) }
        entities[b].advancing = 0
        return .accepted
    }

    /// A farm that has run dry is sown again, at `GatheringStats.farmReseed`.
    mutating func reseed(_ farm: EntityID, player: PlayerID) -> OrderResult {
        guard let b = index(of: farm), entities[b].owner == player else { return .refused(.notYours) }
        guard entities[b].buildingKind == .farm, entities[b].complete,
              (entities[b].farmUsed ?? 0) >= catalogue.gathering.farmYield else { return .refused(.invalidTarget) }
        let cost = catalogue.gathering.farmReseed
        let held = players[player.rawValue].resources
        guard held.covers(cost) else { return .refused(.notEnough(held.shortfall(for: cost))) }
        players[player.rawValue].resources = held - cost
        entities[b].farmUsed = 0
        return .accepted
    }

    /// A person's car beside the player's first standing town centre, up to
    /// `CarStats.perPerson` of them (ruled 2026-11-21); computer players have none.
    mutating func summonCar(player: PlayerID) -> OrderResult {
        let p = player.rawValue
        guard let car = catalogue.car, players[p].isHuman else { return .refused(.notYours) }
        let made = entities.lazy.filter { $0.alive && $0.owner == player && $0.unitKind == .car }.count
        guard made < car.perPerson else { return .refused(.notNow) }
        guard let centre = entities.indices.first(where: {
            entities[$0].alive && entities[$0].owner == player && entities[$0].buildingKind == .townCentre && entities[$0].complete
        }) else { return .refused(.invalidTarget) }
        let spot = freeTile(besideBuilding: centre, index: entities[centre].spawned)
        entities[centre].spawned += 1
        let id = spawnPerson(.car, owner: player, at: spot.centre)
        record(.trained(id, .car), for: p)
        return .accepted
    }

    /// Turn the kill radius of the player's own cars among `ids` on or off
    /// (ruled 2026-11-21): off, a car harms nobody by driving near, and still fires its laser.
    mutating func setKillRadius(_ ids: [EntityID], on: Bool, player: PlayerID) -> OrderResult {
        let cars = ids.compactMap(index(of:)).filter {
            entities[$0].alive && entities[$0].owner == player && entities[$0].unitKind == .car
        }
        guard !cars.isEmpty else { return .refused(.notYours) }
        for i in cars { entities[i].killRadiusOff = on ? nil : true }
        return .accepted
    }
}

// MARK: Doctors, ships and founders

extension Simulation {
    /// The open tile nearest a tile that a person on foot, or a vessel, may enter.
    func nearestTile(to t: GridPoint, afloat: Bool) -> GridPoint? {
        if open(t.x, t.y, afloat: afloat) { return t }
        for r in 1...max(width, height) {
            var best: GridPoint?
            var bestDistance = Int.max
            for y in (t.y - r)...(t.y + r) {
                for x in (t.x - r)...(t.x + r) where abs(x - t.x) == r || abs(y - t.y) == r {
                    guard open(x, y, afloat: afloat) else { continue }
                    let d = (x - t.x) * (x - t.x) + (y - t.y) * (y - t.y)
                    if d < bestDistance { best = GridPoint(x, y); bestDistance = d }
                }
            }
            if let best { return best }
        }
        return nil
    }

    /// Doctors heal a wounded unit of the player's (requirement 13).
    mutating func heal(_ ids: [EntityID], _ target: EntityID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let doctors = people.filter { entities[$0].unitKind.flatMap { tables.unit($0).healing } ?? 0 > 0 }
        guard !doctors.isEmpty else { return .refused(.notYours) }
        guard let t = index(of: target), doctors.contains(where: { canHeal($0, t) }) else { return .refused(.invalidTarget) }
        for i in doctors where canHeal(i, t) {
            entities[i].fraction = 0
            assign(i, .heal(target))
        }
        return .accepted
    }

    /// Troops board a navy ship of the player's that is at the shore, as many
    /// as it has room for, in id order (requirement 16).
    mutating func board(_ ids: [EntityID], _ ship: EntityID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let troops = people.filter { Self.boards(entities[$0].unitKind) }
        guard !troops.isEmpty else { return .refused(.notYours) }
        guard let s = index(of: ship), entities[s].owner == player, entities[s].unitKind == .navyShip,
              atShore(s) else { return .refused(.invalidTarget) }
        let room = catalogue.shipCargo - cargo(of: s)
        guard room > 0 else { return .refused(.invalidTarget) }
        for i in troops.prefix(room) { assign(i, .board(ship)) }
        return .accepted
    }

    /// Navy ships of the player's that carry troops sail to the shore near a
    /// point on land, and land them there (requirement 16).
    mutating func land(_ ids: [EntityID], at point: MapPosition, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let ships = people.filter { entities[$0].unitKind == .navyShip && cargo(of: $0) > 0 }
        guard !ships.isEmpty else { return .refused(.notYours) }
        guard point.x >= 0, point.y >= 0, point.x < Double(width), point.y < Double(height),
              open(point.tile) else { return .refused(.invalidTarget) }
        for i in ships { assign(i, .land(point)) }
        return .accepted
    }

    /// A founder lays out a town centre, free, and goes to build it (ruled
    /// 2026-11-22); one at a time, until one is finished.
    mutating func found(_ founder: EntityID, at origin: GridPoint, player: PlayerID) -> OrderResult {
        guard let f = index(of: founder), entities[f].owner == player, entities[f].isFounder else {
            return .refused(.notYours)
        }
        guard !entities.contains(where: { $0.alive && $0.foundedBy == founder }) else { return .refused(.notNow) }
        let p = player.rawValue
        guard canPlace(.townCentre, at: origin, player: p) else { return .refused(.placementBlocked) }
        let b = placeBuilding(.townCentre, owner: player, origin: origin, complete: false)
        entities[b].foundedBy = founder
        if let f = index(of: founder) { assign(f, .work(entities[b].id)) }
        return .accepted
    }
}
