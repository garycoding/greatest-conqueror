// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// What people and buildings do in a tick.

extension Simulation {
    mutating func updatePerson(_ i: Int) {
        if entities[i].unitKind == .car { clearAround(i) }
        if entities[i].cooldown > 0 { entities[i].cooldown -= 1 }
        switch entities[i].task {
        case .idle:
            entities[i].doing = .idle
            lookForCare(i)
        case .move(let point): moveTask(i, to: point)
        case .gather(let site, let kind, let tile): gatherTask(i, site: site, kind: kind, tile: tile)
        case .work(let building): workTask(i, at: building)
        case .demolish(let building): demolishTask(i, building)
        case .attack(let target): attackTask(i, target: target)
        case .heal(let target): healTask(i, target)
        case .board(let ship): boardTask(i, ship)
        case .land(let point): landTask(i, at: point)
        }
        if entities[i].alive, !entities[i].queue.isEmpty { makeAtShore(i) }
    }

    mutating func setIdle(_ i: Int) {
        entities[i].task = .idle
        entities[i].doing = .idle
        entities[i].route = Route()
    }

    /// Give a person a new task, forgetting its route.
    mutating func assign(_ i: Int, _ task: Task) {
        entities[i].task = task
        entities[i].route = Route()
        entities[i].dropOff = nil
    }

    // MARK: Moving

    mutating func moveTask(_ i: Int, to point: MapPosition) {
        switch approach(i, .point(point, reach: Rule.pointReach)) {
        case .arrived, .unreachable: setIdle(i)
        case .moving: entities[i].doing = .moving
        }
    }

    // MARK: Gathering

    /// Units of a site's yield a unit of a kind takes per tick (`UnitStats.gathering`).
    func gatheringRate(_ kind: SiteKind, by unit: UnitKind) -> Double {
        tables.unit(unit).gathers(kind.yield) / Double(Tick.rate)
    }

    mutating func gatherTask(_ i: Int, site: SiteID, kind: SiteKind, tile: GridPoint) {
        let owner = entities[i].owner.rawValue
        let load = catalogue.gathering.load
        var siteIndex = self.siteIndex(of: site)
        if siteIndex == nil, let next = nearestSite(kind, near: tile, player: owner, afloat: entities[i].isAfloat) {
            // The site is exhausted: the worker turns to the nearest other of its kind.
            entities[i].task = .gather(site: sites[next].id, kind: kind, tile: sites[next].tile)
            entities[i].route = Route()
            siteIndex = next
        }
        let carried = entities[i].cargo?.amount ?? 0
        if carried >= load || (siteIndex == nil && carried > 0) {
            carryHome(i, kind: kind, thenIdle: siteIndex == nil)
            return
        }
        guard let s = siteIndex else { setIdle(i); return }
        let target = sites[s]
        switch approach(i, .tiles(target.tile, GridPoint(1, 1), reach: Rule.besideReach)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        entities[i].doing = .gathering
        face(i, dx: target.tile.centre.x - entities[i].position.x, dy: target.tile.centre.y - entities[i].position.y)
        var fraction = entities[i].fraction + gatheringRate(kind, by: entities[i].unitKind ?? .worker)
        var amount = carried, remaining = target.remaining
        while fraction >= 1 && amount < load && remaining > 0 {
            fraction -= 1
            amount += 1
            remaining -= 1
        }
        entities[i].fraction = amount >= load ? 0 : fraction
        entities[i].cargo = Cargo(kind: kind, amount: amount)
        if remaining != target.remaining {
            sites[s].remaining = remaining
            if remaining == 0 { exhaust(s) }
        }
    }

    /// Walk a load to the nearest own building that accepts it, and deliver it.
    mutating func carryHome(_ i: Int, kind: SiteKind, thenIdle: Bool) {
        entities[i].doing = .carrying
        var drop = entities[i].dropOff.flatMap { index(of: $0) }
        if let d = drop, !accepts(d, kind.yield, from: entities[i].owner)
            || (entities[d].buildingKind == .boatHouse) != entities[i].isAfloat { drop = nil }
        if drop == nil {
            drop = nearestDropOff(for: i, accepting: kind.yield)
            entities[i].dropOff = drop.map { entities[$0].id }
            entities[i].route = Route()
        }
        guard let d = drop else { return }
        switch approach(i, .tiles(entities[d].origin, entities[d].size, reach: Rule.besideReach)) {
        case .moving: return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        deliver(i)
        if thenIdle {
            setIdle(i)
        } else {
            entities[i].route = Route()
            entities[i].doing = .moving
        }
    }

    func accepts(_ building: Int, _ resource: Resource, from owner: PlayerID) -> Bool {
        let e = entities[building]
        guard e.alive, e.complete, e.owner == owner, let kind = e.buildingKind else { return false }
        return tables.building(kind).accepts.contains(resource)
    }

    /// The nearest complete own building that accepts a resource; ties go to the lower id.
    func nearestDropOff(for i: Int, accepting resource: Resource) -> Int? {
        let owner = entities[i].owner, position = entities[i].position
        var best: Int?
        var bestDistance = Double.infinity
        let boat = entities[i].isAfloat
        for j in entities.indices where !entities[j].isPerson && accepts(j, resource, from: owner)
            && (entities[j].buildingKind == .boatHouse) == boat {
            let d = Goal.tiles(entities[j].origin, entities[j].size, reach: 0).distance(to: position)
            if d < bestDistance { best = j; bestDistance = d }
        }
        return best
    }

    /// The nearest site of a kind with something left, near where the last one was,
    /// on a tile the player's orders may use (`isExplored(_:byPlayer:)`).
    func nearestSite(_ kind: SiteKind, near tile: GridPoint, player p: Int, afloat: Bool = false) -> Int? {
        var best: Int?
        var bestDistance = Double.infinity
        for s in sites.indices where sites[s].kind == kind && sites[s].remaining > 0 && isExplored(sites[s].tile, byPlayer: p)
            && isAfloat(sites[s]) == afloat {
            let d = sites[s].tile.centre.distance(to: tile.centre)
            if d <= Rule.resiteRadius && d < bestDistance { best = s; bestDistance = d }
        }
        return best
    }

    /// Whether a site stands in the water, where only boats gather (ruled 2026-11-21).
    func isAfloat(_ site: ResourceSite) -> Bool { inMap(site.tile) && terrain[tileIndex(site.tile)].isWater }

    /// Credit a worker's load to its owner.
    mutating func deliver(_ i: Int) {
        guard let cargo = entities[i].cargo else { return }
        let p = entities[i].owner.rawValue
        players[p].resources[cargo.kind.yield] += cargo.amount
        entities[i].cargo = nil
        entities[i].dropOff = nil
    }

    /// A site has run out: it vanishes from views and no longer blocks its tile.
    mutating func exhaust(_ s: Int) {
        let t = sites[s].tile
        guard inMap(t), siteAt[tileIndex(t)] == Int32(s) else { return }
        siteAt[tileIndex(t)] = -1
        blocked[tileIndex(t)] = !terrain[tileIndex(t)].isPassable || buildingAt[tileIndex(t)] >= 0
    }

    // MARK: Working at a building

    /// Workers construct a building, repair it once it is damaged, or tend it
    /// if it is a farm; a founder constructs the town centre it founded.
    mutating func workTask(_ i: Int, at building: EntityID) {
        guard let b = index(of: building), entities[b].owner == entities[i].owner,
              let buildingKind = entities[b].buildingKind, hasWork(at: b, person: i) else {
            // A builder whose building is completed goes on to the next one under
            // construction nearby, as a gatherer goes on to the next site (ruled 2026-11-19).
            if entities[i].doing == .constructing,
               index(of: building).map({ entities[$0].complete }) == true, let next = nextConstruction(for: i) {
                entities[i].task = .work(entities[next].id)
                return
            }
            setIdle(i); return
        }
        switch approach(i, .tiles(entities[b].origin, entities[b].size, reach: Rule.besideReach)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: rest(i); return
        case .arrived: break
        }
        face(i, dx: entities[b].position.x - entities[i].position.x, dy: entities[b].position.y - entities[i].position.y)
        let p = entities[i].owner.rawValue
        let stats = tables.building(buildingKind)
        let buildTime = max(1, stats.buildTime)
        if !entities[b].complete {
            entities[i].doing = .constructing
            entities[b].built += 1
            credit(b, health: entities[b].maxHealth, per: buildTime)
            if entities[b].built >= buildTime { complete(b) }
            return
        }
        if entities[b].health < entities[b].maxHealth {
            // Repair: each worker restores `repair_per_second`, so that more
            // workers repair sooner (requirement 12).
            entities[i].doing = .working
            let rate = entities[i].unitKind.flatMap { tables.unit($0).repairing } ?? 0
            let whole = accrue(i, rate)
            entities[b].health = min(entities[b].maxHealth, entities[b].health + whole)
            return
        }
        // A farm: its one worker earns food until it runs dry, and then reseeds
        // it from the stock (ruled 2026-11-19); while the stock lacks the cost, the farmer waits.
        entities[i].doing = .working
        let full = catalogue.gathering.farmYield
        if (entities[b].farmUsed ?? 0) >= full {
            let cost = catalogue.gathering.farmReseed
            guard players[p].resources.covers(cost) else { return }
            players[p].resources = players[p].resources - cost
            entities[b].farmUsed = 0
        }
        let earned = entities[i].fraction + tables.unit(entities[i].unitKind ?? .worker).farming / Double(Tick.rate)
        var whole = Int(earned.rounded(.down))
        entities[i].fraction = earned - Double(whole)
        whole = min(whole, full - (entities[b].farmUsed ?? 0))
        entities[b].farmUsed = (entities[b].farmUsed ?? 0) + whole
        players[p].resources[.food] += whole
    }

    /// Workers pull a building down over half its construction time.
    mutating func demolishTask(_ i: Int, _ building: EntityID) {
        guard let b = index(of: building), entities[b].owner == entities[i].owner,
              let kind = entities[b].buildingKind else { setIdle(i); return }
        switch approach(i, .tiles(entities[b].origin, entities[b].size, reach: Rule.besideReach)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        face(i, dx: entities[b].position.x - entities[i].position.x, dy: entities[b].position.y - entities[i].position.y)
        entities[i].doing = .constructing
        entities[b].demolished += 1
        if entities[b].demolished >= tables.building(kind).demolishTime { demolish(b) }
    }

    /// A building comes down: its share of its cost back (`demolish_return`), and whatever was under way
    /// there cancelled and refunded.
    mutating func demolish(_ b: Int) {
        guard let kind = entities[b].buildingKind else { return }
        let p = entities[b].owner.rawValue
        var back = tables.building(kind).cost.share(tables.building(kind).demolishReturn)
        for unit in entities[b].queue { back = back + tables.unit(unit).cost }
        if entities[b].advancing != nil, let advance = catalogue.advance(from: players[p].age) { back = back + advance.cost }
        entities[b].queue = []
        entities[b].advancing = nil
        players[p].resources = players[p].resources + back
        record(.destroyed(entities[b].id), for: p)
        kill(b)
    }

    /// The nearest of the worker's player's buildings still under construction,
    /// within the radius in which a gatherer looks for its next site.
    func nextConstruction(for i: Int) -> Int? {
        var best: Int?
        var bestDistance = Double.infinity
        for j in entities.indices where entities[j].alive && entities[j].owner == entities[i].owner
            && entities[j].buildingKind != nil && !entities[j].complete {
            let d = entities[j].position.distance(to: entities[i].position)
            if d <= Rule.resiteRadius && d < bestDistance { best = j; bestDistance = d }
        }
        return best
    }

    /// The worker tending a farm, other than `besides`, if any.
    func farmer(of farm: Int, besides: Int?) -> Int? {
        let id = entities[farm].id
        return entities.indices.first { j in
            j != besides && entities[j].alive && entities[j].unitKind == .worker && entities[j].task == .work(id)
        }
    }

    /// Whether a worker has anything to do at a building: construct it, repair
    /// it, or tend it if it is a farm that no other worker tends. `person` is
    /// the one asking, who does not count as another farm's tender.
    func hasWork(at b: Int, person: Int? = nil) -> Bool {
        let e = entities[b]
        guard let buildingKind = e.buildingKind else { return false }
        if let person, entities[person].isFounder { return !e.complete && e.foundedBy == entities[person].id }
        if !e.complete || e.health < e.maxHealth { return true }
        return buildingKind == .farm && farmer(of: b, besides: person) == nil
    }

    /// Construction and repair restore a building's health at its full health per
    /// `buildTime` worker-ticks, in whole points.
    mutating func credit(_ b: Int, health full: Int, per buildTime: Int) {
        entities[b].healthCredit += full
        while entities[b].healthCredit >= buildTime && entities[b].health < entities[b].maxHealth {
            entities[b].health += 1
            entities[b].healthCredit -= buildTime
        }
    }

    mutating func complete(_ b: Int) {
        guard let kind = entities[b].buildingKind else { return }
        entities[b].complete = true
        entities[b].healthCredit = 0
        entities[b].health = min(entities[b].health, entities[b].maxHealth)
        let p = entities[b].owner.rawValue
        housing[p] += tables.building(kind).housing
        record(.constructed(entities[b].id, kind), for: p)
        if let founder = entities[b].foundedBy {
            entities[b].foundedBy = nil
            founded(b, by: founder)
        }
    }

    // MARK: Buildings

    mutating func updateBuilding(_ b: Int) {
        guard entities[b].complete, let kind = entities[b].buildingKind else { return }
        if entities[b].advancing != nil { advance(b) }
        if entities[b].cooldown > 0 { entities[b].cooldown -= 1 }
        if let attack = attack(of: b), entities[b].cooldown == 0 {
            let e = entities[b]
            if let target = nearestOpponent(of: teamOf(e.owner), minX: Double(e.origin.x), minY: Double(e.origin.y),
                                            maxX: Double(e.origin.x + e.size.x), maxY: Double(e.origin.y + e.size.y),
                                            within: attack.range, visibleOnly: false) {
                strike(from: b, at: target, attack: attack)
                entities[b].cooldown = attack.interval
            }
        }
        if let head = entities[b].queue.first {
            let stats = tables.unit(head)
            let time = tables.trainTime(head, at: .building(kind))
            if entities[b].trainProgress < time { entities[b].trainProgress += 1 }
            let p = entities[b].owner.rawValue
            if entities[b].trainProgress >= time && population[p] + stats.population <= populationLimit(p) {
                entities[b].queue.removeFirst()
                entities[b].trainProgress = 0
                // A boat or a ship comes out on the water beside its boathouse.
                let spot = freeTile(besideBuilding: b, index: entities[b].spawned, afloat: head.isAfloat)
                entities[b].spawned += 1
                let id = spawnPerson(head, owner: entities[b].owner, at: spot.centre)
                record(.trained(id, head), for: p)
            }
        }
    }

    /// The advance to the next age under way at a town centre: when its time
    /// has passed, the player reaches the next age (requirement 6).
    mutating func advance(_ b: Int) {
        let p = entities[b].owner.rawValue
        guard let advance = catalogue.advance(from: players[p].age), let next = players[p].age.next else {
            entities[b].advancing = nil; return
        }
        let done = (entities[b].advancing ?? 0) + 1
        guard done >= advance.time else { entities[b].advancing = done; return }
        entities[b].advancing = nil
        players[p].age = next
        record(.ageReached(next), for: p)
        upgrade(player: p)
    }

    /// Every opponent's unit within a car's kill radius dies at once (ruled
    /// 2026-11-21), unless its person has turned the radius off; cars, which
    /// nothing harms, are spared, and buildings are not touched.
    mutating func clearAround(_ i: Int) {
        guard let radius = catalogue.car?.killRadius, entities[i].killRadiusOff != true else { return }
        let owner = entities[i].owner, here = entities[i].position
        for j in entities.indices where entities[j].alive && entities[j].isPerson && !entities[j].isUnharmable
            && teamOf(entities[j].owner) != teamOf(owner) && entities[j].position.distance(to: here) <= radius {
            let victim = entities[j].owner.rawValue
            record(.destroyed(entities[j].id), for: victim)
            record(.destroyed(entities[j].id), for: owner.rawValue)
            kill(j)
        }
    }
}
