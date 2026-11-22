// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Orders. Each is checked in full before it changes anything, and a refusal is
// also recorded as `GameEvent.refused` for the player's next view. Costs are
// paid when an order is accepted.
//
// Which refusal: `.notNow` whilst paused, after the outcome, or for a defeated
// player; `.notYours` when an entity named is not the player's (or does not
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
        if isPaused || outcome != nil || players[p].isDefeated { return .refused(.notNow) }
        switch order {
        case .move(let units, let to): return move(units, to: to, player: player)
        case .gather(let units, let site): return gather(units, at: site, player: player)
        case .work(let units, let at): return work(units, at: at, player: player)
        case .exchange(let merchants, let give, let take): return exchange(merchants, give: give, take: take, player: player)
        case .carry(let merchants, let resource, let to): return carry(merchants, resource, to: to, player: player)
        case .demolish(let engineers, let building): return demolish(engineers, building, player: player)
        case .construct(let engineers, let building, let at): return construct(engineers, building, at: at, player: player)
        case .attack(let units, let target): return attack(units, target: target, player: player)
        case .train(let at, let unit): return train(unit, at: at, player: player)
        case .cancelTraining(let at): return cancelTraining(at: at, player: player)
        case .research(let at, let improvement): return research(improvement, at: at, player: player)
        case .advanceAge: return advanceAge(player: player)
        case .found(let founder, let at): return found(founder, at: at, player: player)
        case .upgrade(let units, let to, let at): return upgrade(units, to: to, at: at, player: player)
        case .stop(let units): return stop(units, player: player)
        case .dismiss(let units): return dismiss(units, player: player)
        case .reseed(let farm): return reseed(farm, player: player)
        case .summonCar: return summonCar(player: player)
        case .setKillRadius(let cars, let on): return setKillRadius(cars, on: on, player: player)
        case .buildBridge(let engineers, let from, let to): return buildBridge(engineers, from: from, to: to, player: player)
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
        var centre = point
        if !open(point.tile) {
            guard let free = nearestOpenTile(to: point.tile) else { return .refused(.invalidTarget) }
            centre = free.centre
        }
        // People sent together spread over a small square around the point.
        let side = Int(Double(people.count).squareRoot().rounded(.up))
        for (k, i) in people.enumerated() {
            let col = Double(k % side) - Double(side - 1) / 2, row = Double(k / side) - Double(side - 1) / 2
            var spot = MapPosition(x: centre.x + col * Rule.formationSpacing, y: centre.y + row * Rule.formationSpacing)
            if !(spot.x >= 0 && spot.y >= 0 && spot.x < Double(width) && spot.y < Double(height)) || !open(spot.tile) {
                spot = centre
            }
            assign(i, .move(spot))
        }
        return .accepted
    }

    mutating func gather(_ ids: [EntityID], at site: SiteID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player),
              people.contains(where: { [.worker, .boat].contains(entities[$0].unitKind) }) else { return .refused(.notYours) }
        let p = player.rawValue
        guard let s = siteIndex(of: site), isExplored(sites[s].tile, byPlayer: p) else {
            return .refused(.invalidTarget)
        }
        // Workers gather on land, boats in the water (ruled 2026-11-21).
        let gatherer: UnitKind = isAfloat(sites[s]) ? .boat : .worker
        let workers = people.filter { entities[$0].unitKind == gatherer }
        guard !workers.isEmpty else { return .refused(.invalidTarget) }
        let kind = sites[s].kind
        guard players[p].age >= kind.firstAge else { return .refused(.ageNotReached(kind.firstAge)) }
        guard catalogue.gathering.perSecond(kind) > 0 else { return .refused(.invalidTarget) }
        for i in workers {
            if let cargo = entities[i].cargo, cargo.kind != kind { entities[i].cargo = nil }
            entities[i].fraction = 0
            assign(i, .gather(site: site, kind: kind, tile: sites[s].tile))
        }
        return .accepted
    }

    mutating func work(_ ids: [EntityID], at building: EntityID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let able = people.filter { [.worker, .engineer, .scholar].contains(entities[$0].unitKind) }
        guard !able.isEmpty else { return .refused(.notYours) }
        guard let b = ownBuilding(building, player) else { return .refused(.invalidTarget) }
        var busy = able.filter { hasWork(entities[$0].unitKind ?? .worker, at: b, person: $0) }
        if entities[b].buildingKind == .farm, let first = busy.first(where: { entities[$0].unitKind == .worker }) {
            // One worker tends a farm; the others selected are left as they were.
            busy.removeAll { entities[$0].unitKind == .worker && $0 != first }
        }
        if entities[b].buildingKind == .alchemistsWorkshop, let workshop = catalogue.workshop {
            // A workshop takes as many craftsmen as it has room for; the rest are left as they were.
            var room = workshop.workers - crafters(at: b, besides: nil)
            busy.removeAll { i in
                guard entities[i].unitKind == .worker else { return false }
                if entities[i].task == .work(building) { return false }
                if room > 0 { room -= 1; return false }
                return true
            }
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
        let engineers = people.filter { entities[$0].unitKind == .engineer }
        guard !engineers.isEmpty else { return .refused(.notYours) }
        guard ownBuilding(building, player) != nil else { return .refused(.invalidTarget) }
        for i in engineers { assign(i, .demolish(building)) }
        return .accepted
    }

    mutating func construct(_ ids: [EntityID], _ kind: BuildingKind, at origin: GridPoint, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let engineers = people.filter { entities[$0].unitKind == .engineer }
        guard !engineers.isEmpty else { return .refused(.notYours) }
        let p = player.rawValue
        let stats = tables.building(kind)
        guard players[p].age >= stats.age else { return .refused(.ageNotReached(stats.age)) }
        guard canPlace(kind, at: origin, player: p) else { return .refused(.placementBlocked) }
        if let short = pay(stats.cost, p) { return .refused(short) }
        let b = placeBuilding(kind, owner: player, origin: origin, complete: false)
        let id = entities[b].id
        for i in engineers { assign(i, .work(id)) }
        return .accepted
    }

    /// A bridge (ruled 2026-11-21): two tiles wide, a piece on each water tile
    /// of both rows (`Placement.bridgeRows`), all paid for at once; the
    /// engineers begin at the piece beside `from`, and each, on finishing a
    /// piece, goes on to the next (`nextConstruction`).
    mutating func buildBridge(_ ids: [EntityID], from: GridPoint, to: GridPoint, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let engineers = people.filter { entities[$0].unitKind == .engineer }
        guard !engineers.isEmpty else { return .refused(.notYours) }
        let p = player.rawValue
        // Bridges may be forbidden by the match's setup (ruled 2026-11-21).
        guard noBridges != true else { return .refused(.invalidTarget) }
        let stats = tables.building(.bridge)
        guard players[p].age >= stats.age else { return .refused(.ageNotReached(stats.age)) }
        guard let rows = Placement.bridgeRows(from: from, to: to, width: width, height: height, terrain: terrain),
              let run = BridgeRun.of(from: from, to: to),
              (Placement.bridgeEnds(from: from, to: to) + rows.flatMap { $0 }).allSatisfy({ isExplored($0, byPlayer: p) }),
              rows.flatMap({ $0 }).allSatisfy({ buildingAt[tileIndex($0)] < 0 })
        else { return .refused(.placementBlocked) }
        let pieces = rows.flatMap { $0 }
        var cost = ResourceAmounts()
        for r in Resource.allCases { cost[r] = stats.cost[r] * pieces.count }
        if let short = pay(cost, p) { return .refused(short) }
        var first: EntityID?
        let count = rows[0].count
        for (lane, row) in rows.enumerated() {
            let low = row.map { run == .alongX ? $0.x : $0.y }.min()!
            for t in row {
                let b = placeBuilding(.bridge, owner: player, origin: t, complete: false)
                entities[b].bridgePlace = BridgePlace(run: run, lane: lane, index: (run == .alongX ? t.x : t.y) - low,
                                                      count: count)
                if first == nil { first = entities[b].id }
            }
        }
        for i in engineers { assign(i, .work(first!)) }
        return .accepted
    }

    /// `Placement`'s rule, applied to the full state and the team's exploration.
    func canPlace(_ kind: BuildingKind, at origin: GridPoint, player p: Int) -> Bool {
        var occupied = Set<GridPoint>(), wanted = Set<GridPoint>()
        let needed = Placement.site(for: kind)
        for t in Placement.footprint(kind, at: origin, catalogue: catalogue) where inMap(t) {
            let k = tileIndex(t)
            if buildingAt[k] >= 0 || siteAt[k] >= 0 { occupied.insert(t) }
            if buildingAt[k] < 0, siteAt[k] >= 0, let needed, sites[Int(siteAt[k])].kind == needed,
               sites[Int(siteAt[k])].remaining > 0 { wanted.insert(t) }
        }
        return Placement.canPlace(kind, at: origin, width: width, height: height, terrain: terrain, occupied: occupied,
                                  explored: { isExplored($0, byPlayer: p) }, catalogue: catalogue, wanted: wanted)
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
        guard !able.isEmpty else {
            return .refused(people.contains { entities[$0].isFounder } ? .cannotAttack : .notYours)
        }
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

    mutating func dismiss(_ ids: [EntityID], player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let leaving = people.filter { !entities[$0].isFounder }
        guard !leaving.isEmpty else { return .refused(.invalidTarget) }
        for i in leaving {
            // What a merchant carries goes back to the stock: the person leaves, not the goods.
            returnCarried(i)
            kill(i)
        }
        return .accepted
    }

    mutating func upgrade(_ ids: [EntityID], to kind: UnitKind, at building: EntityID, player: PlayerID) -> OrderResult {
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        guard let b = ownBuilding(building, player), entities[b].complete, let buildingKind = entities[b].buildingKind,
              tables.building(buildingKind).trains.contains(kind) else { return .refused(.invalidTarget) }
        let p = player.rawValue
        let stats = tables.unit(kind)
        guard players[p].age >= stats.age else { return .refused(.ageNotReached(stats.age)) }
        var cost = ResourceAmounts()
        var able: [(index: Int, time: Int)] = []
        for i in people where entities[i].upgrade == nil {
            guard let from = entities[i].unitKind, let upgrade = catalogue.upgrade(from: from), upgrade.to == kind else { continue }
            cost = cost + upgrade.cost
            able.append((i, upgrade.time))
        }
        guard !able.isEmpty else { return .refused(.notYours) }
        if let short = pay(cost, p) { return .refused(short) }
        for (i, time) in able { entities[i].upgrade = PendingUpgrade(to: kind, remaining: max(1, time)) }
        return .accepted
    }

    // MARK: Buildings

    mutating func train(_ kind: UnitKind, at building: EntityID, player: PlayerID) -> OrderResult {
        guard let b = ownBuilding(building, player) else { return .refused(.notYours) }
        guard entities[b].complete, let buildingKind = entities[b].buildingKind,
              tables.building(buildingKind).trains.contains(kind), let stats = tables.units[kind.rawValue],
              stats.trainedAt.contains(buildingKind) else { return .refused(.invalidTarget) }
        let p = player.rawValue
        guard players[p].age >= stats.age else { return .refused(.ageNotReached(stats.age)) }
        guard population[p] + queuedPopulation(p) + stats.population <= populationLimit(p) else {
            return .refused(.populationLimit)
        }
        if let short = pay(stats.cost, p) { return .refused(short) }
        entities[b].queue.append(kind)
        return .accepted
    }

    mutating func cancelTraining(at building: EntityID, player: PlayerID) -> OrderResult {
        guard let b = ownBuilding(building, player) else { return .refused(.notYours) }
        guard let last = entities[b].queue.popLast() else { return .refused(.invalidTarget) }
        if entities[b].queue.isEmpty { entities[b].trainProgress = 0 }
        let p = player.rawValue
        players[p].resources = players[p].resources + tables.unit(last).cost
        return .accepted
    }

    mutating func research(_ improvement: Improvement, at building: EntityID, player: PlayerID) -> OrderResult {
        guard let b = ownBuilding(building, player) else { return .refused(.notYours) }
        guard entities[b].complete, let buildingKind = entities[b].buildingKind,
              tables.building(buildingKind).researches.contains(improvement) else { return .refused(.invalidTarget) }
        let p = player.rawValue
        let stats = catalogue.stats(improvement)
        guard players[p].age >= stats.age else { return .refused(.ageNotReached(stats.age)) }
        let underWay = entities.contains { $0.alive && $0.owner == player && $0.research == improvement }
        guard entities[b].research == nil, !players[p].has(improvement), !underWay else { return .refused(.invalidTarget) }
        if let short = pay(stats.cost, p) { return .refused(short) }
        entities[b].research = improvement
        entities[b].researchProgress = 0
        return .accepted
    }

    // MARK: The player

    mutating func advanceAge(player: PlayerID) -> OrderResult {
        let p = player.rawValue
        guard let next = players[p].age.next, let advance = catalogue.advance(from: players[p].age) else {
            return .refused(.invalidTarget)
        }
        guard players[p].study >= advance.study else { return .refused(.studyIncomplete) }
        if let short = pay(advance.cost, p) { return .refused(short) }
        // Peaceful people change stage at once: their stage follows the owner's age.
        players[p].age = next
        players[p].study = 0
        record(.ageReached(next), for: p)
        return .accepted
    }

    /// A founder builds a town centre, free, with `founderPeople` workers beside
    /// it, and becomes an engineer (requirement 26, ruled 2026-11-21), so that
    /// the player begins again as every player begins.
    mutating func found(_ founder: EntityID, at origin: GridPoint, player: PlayerID) -> OrderResult {
        guard let f = index(of: founder), entities[f].owner == player, entities[f].isFounder else {
            return .refused(.notYours)
        }
        let p = player.rawValue
        guard canPlace(.townCentre, at: origin, player: p) else { return .refused(.placementBlocked) }
        finishUpgrade(f, to: .engineer)
        setIdle(f)
        let centre = placeBuilding(.townCentre, owner: player, origin: origin, complete: true)
        record(.constructed(entities[centre].id, .townCentre), for: p)
        for k in 0..<catalogue.founderPeople {
            spawnPerson(.worker, owner: player, at: freeTile(besideBuilding: centre, index: k).centre)
        }
        return .accepted
    }

    /// A farm that has run dry is sown again, at `GatheringStats.farmReseed`.
    mutating func reseed(_ farm: EntityID, player: PlayerID) -> OrderResult {
        guard let b = index(of: farm), entities[b].owner == player else { return .refused(.notYours) }
        guard entities[b].buildingKind == .farm, entities[b].complete, let full = catalogue.gathering.farmYield,
              (entities[b].farmUsed ?? 0) >= full else { return .refused(.invalidTarget) }
        let cost = catalogue.gathering.farmReseed ?? ResourceAmounts()
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
