// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// What people and buildings do in a tick.

extension Simulation {
    mutating func updatePerson(_ i: Int) {
        if entities[i].unitKind == .car { clearAround(i) }
        if entities[i].cooldown > 0 { entities[i].cooldown -= 1 }
        if let pending = entities[i].upgrade {
            if pending.remaining <= 1 { finishUpgrade(i, to: pending.to) } else { entities[i].upgrade?.remaining -= 1 }
        }
        switch entities[i].task {
        case .idle: entities[i].doing = .idle
        case .move(let point): moveTask(i, to: point)
        case .gather(let site, let kind, let tile): gatherTask(i, site: site, kind: kind, tile: tile)
        case .work(let building): workTask(i, at: building)
        case .demolish(let building): demolishTask(i, building)
        case .attack(let target): attackTask(i, target: target)
        case .trade(let building, let give, let take): tradeTask(i, at: building, give: give, take: take)
        case .carry(let resource, let target): carryTask(i, resource, to: target)
        }
    }

    mutating func setIdle(_ i: Int) {
        returnCarried(i)
        entities[i].task = .idle
        entities[i].doing = .idle
        entities[i].route = Route()
        entities[i].rail = nil
    }

    /// Give a person a new task, forgetting its route.
    mutating func assign(_ i: Int, _ task: Task) {
        if entities[i].task != task { returnCarried(i) }
        entities[i].task = task
        entities[i].route = Route()
        entities[i].dropOff = nil
        // A railway journey belongs to the task it was taken for.
        entities[i].rail = nil
    }

    // MARK: Moving

    mutating func moveTask(_ i: Int, to point: MapPosition) {
        switch approach(i, .point(point, reach: Rule.pointReach)) {
        case .arrived, .unreachable: setIdle(i)
        case .moving: entities[i].doing = .moving
        }
    }

    // MARK: Gathering

    /// Units of a site's yield a worker takes per tick.
    func gatheringRate(_ kind: SiteKind, player: Int) -> Double {
        let tools = players[player].improvements.reduce(1.0) { $0 * catalogue.stats($1).gatheringMultiplier }
        return catalogue.gathering.perSecond(kind) * tools / Double(Tick.rate)
    }

    mutating func gatherTask(_ i: Int, site: SiteID, kind: SiteKind, tile: GridPoint) {
        let owner = entities[i].owner.rawValue
        let load = catalogue.gathering.load
        var siteIndex = self.siteIndex(of: site)
        if siteIndex == nil, let next = nearestSite(kind, near: tile, player: owner, afloat: entities[i].isBoat) {
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
        var fraction = entities[i].fraction + gatheringRate(kind, player: owner)
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
            || (entities[d].buildingKind == .boatHouse) != entities[i].isBoat { drop = nil }
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
        let boat = entities[i].isBoat
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

    /// Credit a worker's load to its owner. Copper and tin ore pair into bronze,
    /// one unit of each to one of bronze; unpaired ore is held up to one load of
    /// each, and the rest is lost (`Order.gather`).
    mutating func deliver(_ i: Int) {
        guard let cargo = entities[i].cargo else { return }
        let p = entities[i].owner.rawValue
        let load = catalogue.gathering.load
        switch cargo.kind {
        case .copper, .tin:
            if cargo.kind == .copper { players[p].copperOre += cargo.amount } else { players[p].tinOre += cargo.amount }
            let pairs = min(players[p].copperOre, players[p].tinOre)
            players[p].resources[.bronze] += pairs
            players[p].copperOre = min(players[p].copperOre - pairs, load)
            players[p].tinOre = min(players[p].tinOre - pairs, load)
        default:
            players[p].resources[cargo.kind.yield] += cargo.amount
        }
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

    /// Workers tend a stock pen; engineers construct or repair; scholars research
    /// what is under way there or, at a town centre, study toward the next age.
    mutating func workTask(_ i: Int, at building: EntityID) {
        guard let b = index(of: building), entities[b].owner == entities[i].owner,
              let buildingKind = entities[b].buildingKind, let kind = entities[i].unitKind,
              hasWork(kind, at: b, person: i) else {
            // An engineer whose building is completed goes on to the next one under
            // construction nearby, as a gatherer goes on to the next site (ruled 2026-11-19).
            if entities[i].unitKind == .engineer, entities[i].doing == .constructing,
               index(of: building).map({ entities[$0].complete }) == true, let next = nextConstruction(for: i) {
                entities[i].task = .work(entities[next].id)
                return
            }
            setIdle(i); return
        }
        switch approach(i, .tiles(entities[b].origin, entities[b].size, reach: Rule.besideReach)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        face(i, dx: entities[b].position.x - entities[i].position.x, dy: entities[b].position.y - entities[i].position.y)
        let p = entities[i].owner.rawValue
        let stats = tables.building(buildingKind)
        switch kind {
        case .worker where buildingKind == .alchemistsWorkshop:
            // A craftsman makes gunpowder from the stock's wood (ruled 2026-11-19); with no wood he waits.
            guard let workshop = catalogue.workshop else { setIdle(i); return }
            entities[i].doing = .working
            let rate = workshop.perSecond * players[p].improvements.reduce(1.0) { $0 * (catalogue.stats($1).productionMultiplier ?? 1) }
            entities[i].fraction += rate / Double(Tick.rate)
            while entities[i].fraction >= 1 && players[p].resources[.wood] >= workshop.woodPerUnit {
                entities[i].fraction -= 1
                players[p].resources[.wood] -= workshop.woodPerUnit
                players[p].resources[.gunpowder] += 1
            }
            if players[p].resources[.wood] < workshop.woodPerUnit { entities[i].fraction = min(entities[i].fraction, 1) }
        case .worker:
            entities[i].doing = .working
            let full = buildingKind == .farm ? catalogue.gathering.farmYield : nil
            if let full, (entities[b].farmUsed ?? 0) >= full {
                // A farm that has run dry is reseeded by its farmer from the stock (ruled
                // 2026-11-19); while the stock lacks the cost, the farmer waits.
                let cost = catalogue.gathering.farmReseed ?? ResourceAmounts()
                guard players[p].resources.covers(cost) else { return }
                players[p].resources = players[p].resources - cost
                entities[b].farmUsed = 0
            }
            let perSecond = buildingKind == .farm ? farmingRate(player: p) : catalogue.gathering.herdingPerSecond
            let earned = entities[i].fraction + perSecond / Double(Tick.rate)
            var whole = Int(earned.rounded(.down))
            entities[i].fraction = earned - Double(whole)
            if let full {
                whole = min(whole, full - (entities[b].farmUsed ?? 0))
                entities[b].farmUsed = (entities[b].farmUsed ?? 0) + whole
            }
            players[p].resources[.food] += whole
        case .engineer:
            let buildTime = max(1, stats.buildTime)
            if !entities[b].complete {
                entities[i].doing = .constructing
                entities[b].built += 1
                credit(b, health: stats.health, per: buildTime)
                if entities[b].built >= buildTime { complete(b) }
            } else {
                entities[i].doing = .working
                credit(b, health: stats.health, per: buildTime)
                if entities[b].health >= entities[b].maxHealth { entities[b].healthCredit = 0 }
            }
        case .scholar:
            entities[i].doing = .working
            if let research = entities[b].research {
                entities[b].researchProgress += 1
                if entities[b].researchProgress >= catalogue.stats(research).work { finishResearch(b) }
            } else if buildingKind == .townCentre, let advance = catalogue.advance(from: players[p].age),
                      players[p].age.next != nil {
                players[p].study = min(advance.study, players[p].study + 1)
            }
        default:
            setIdle(i)
        }
    }

    /// Engineers pull a building down over half its construction time
    /// (requirement 28).
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
        if entities[b].demolished >= Self.demolitionTime(tables.building(kind).buildTime) { demolish(b) }
    }

    /// Engineer-ticks to pull down a building: half its construction time.
    static func demolitionTime(_ buildTime: Int) -> Int { max(1, buildTime / 2) }

    /// A building comes down: half its cost back, and whatever was under way
    /// there cancelled and refunded.
    mutating func demolish(_ b: Int) {
        guard let kind = entities[b].buildingKind else { return }
        let p = entities[b].owner.rawValue
        var back = tables.building(kind).cost.halved
        for unit in entities[b].queue { back = back + tables.unit(unit).cost }
        if let research = entities[b].research { back = back + catalogue.stats(research).cost }
        entities[b].queue = []
        entities[b].research = nil
        players[p].resources = players[p].resources + back
        record(.destroyed(entities[b].id), for: p)
        kill(b)
    }

    /// Food per second a worker earns at a farm; the plough makes it more. A
    /// farm runs dry after `GatheringStats.farmYield` and is reseeded (ruled 2026-11-19).
    func farmingRate(player: Int) -> Double {
        let plough = players[player].improvements.reduce(1.0) { $0 * (catalogue.stats($1).farmingMultiplier ?? 1) }
        return (catalogue.gathering.farmingPerSecond ?? 0) * plough
    }

    /// How many workers, other than `besides`, work at a building.
    func crafters(at b: Int, besides: Int?) -> Int {
        let id = entities[b].id
        return entities.indices.filter { j in
            j != besides && entities[j].alive && entities[j].unitKind == .worker && entities[j].task == .work(id)
        }.count
    }

    /// The nearest of the engineer's player's buildings still under construction,
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

    /// Whether a person of this kind has anything to do at a building.
    /// `person` is the one asking, who does not count as another farm's tender.
    func hasWork(_ kind: UnitKind, at b: Int, person: Int? = nil) -> Bool {
        let e = entities[b]
        guard let buildingKind = e.buildingKind else { return false }
        switch kind {
        case .worker:
            guard e.complete else { return false }
            if buildingKind == .stockPen { return true }
            // A farm is tended by one worker at a time.
            if buildingKind == .farm { return farmer(of: b, besides: person) == nil }
            // A workshop takes up to `WorkshopStats.workers` craftsmen.
            if buildingKind == .alchemistsWorkshop, let workshop = catalogue.workshop {
                return crafters(at: b, besides: person) < workshop.workers
            }
            return false
        case .engineer: return !e.complete || e.health < e.maxHealth
        case .scholar: return e.complete && (buildingKind == .townCentre || !tables.building(buildingKind).researches.isEmpty)
        default: return false
        }
    }

    /// Construction and repair restore a building's health at its full health per
    /// `buildTime` engineer-ticks, in whole points.
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
        if kind == .bridge, inMap(entities[b].origin) { blocked[tileIndex(entities[b].origin)] = false }
        record(.constructed(entities[b].id, kind), for: p)
    }

    mutating func finishResearch(_ b: Int) {
        guard let research = entities[b].research else { return }
        let p = entities[b].owner.rawValue
        entities[b].research = nil
        entities[b].researchProgress = 0
        if !players[p].has(research) { players[p].improvements.append(research) }
        record(.researched(research), for: p)
    }

    // MARK: Upgrades

    /// A warfighter becomes the kind it was paid to become, keeping its share of health.
    mutating func finishUpgrade(_ i: Int, to kind: UnitKind) {
        guard let old = entities[i].unitKind else { return }
        let stats = tables.unit(kind)
        let p = entities[i].owner.rawValue
        stampSight(of: i, by: -1)
        entities[i].kind = .unit(kind)
        entities[i].health = max(1, entities[i].health * stats.health / max(1, entities[i].maxHealth))
        entities[i].maxHealth = stats.health
        entities[i].sight = stats.sight
        entities[i].upgrade = nil
        stampSight(of: i, by: 1)
        population[p] += stats.population - tables.unit(old).population
    }

    // MARK: Buildings

    mutating func updateBuilding(_ b: Int) {
        guard entities[b].complete, let kind = entities[b].buildingKind else { return }
        if kind == .oilWell { pump(b) }
        if entities[b].cooldown > 0 { entities[b].cooldown -= 1 }
        if let attack = tables.building(kind).attack, entities[b].cooldown == 0 {
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
            if entities[b].trainProgress < stats.trainTime { entities[b].trainProgress += 1 }
            let p = entities[b].owner.rawValue
            if entities[b].trainProgress >= stats.trainTime && population[p] + stats.population <= populationLimit(p) {
                entities[b].queue.removeFirst()
                entities[b].trainProgress = 0
                // A boat comes out on the water beside its boat house (ruled 2026-11-21).
                let spot = freeTile(besideBuilding: b, index: entities[b].spawned, afloat: head == .boat)
                entities[b].spawned += 1
                let id = spawnPerson(head, owner: entities[b].owner, at: spot.centre)
                record(.trained(id, head), for: p)
            }
        }
    }

    /// An oil well pumps oil from the fields beneath it into its owner's stock,
    /// without workers, until they are empty (ruled 2026-11-19).
    mutating func pump(_ b: Int) {
        guard let well = catalogue.oilWell else { return }
        let p = entities[b].owner.rawValue
        let rate = well.perSecond * players[p].improvements.reduce(1.0) { $0 * (catalogue.stats($1).pumpingMultiplier ?? 1) }
        entities[b].fraction += rate / Double(Tick.rate)
        while entities[b].fraction >= 1 {
            guard let s = oilBeneath(b) else { entities[b].fraction = 0; return }
            entities[b].fraction -= 1
            sites[s].remaining -= 1
            players[p].resources[.oil] += 1
            if sites[s].remaining <= 0 { exhaust(s) }
        }
    }

    /// The first oil field with oil left beneath a building's footprint.
    func oilBeneath(_ b: Int) -> Int? {
        for t in footprintTiles(origin: entities[b].origin, size: entities[b].size) where inMap(t) {
            let s = Int(siteAt[tileIndex(t)])
            if s >= 0, sites[s].kind == .oilField, sites[s].remaining > 0 { return s }
        }
        return nil
    }

    /// The oil left beneath a building's footprint.
    func oilLeft(under b: Int) -> Int {
        var total = 0
        for t in footprintTiles(origin: entities[b].origin, size: entities[b].size) where inMap(t) {
            let s = Int(siteAt[tileIndex(t)])
            if s >= 0, sites[s].kind == .oilField { total += max(0, sites[s].remaining) }
        }
        return total
    }

    /// Every opponent's unit within a car's kill radius dies at once (ruled
    /// 2026-11-21), unless its person has turned the radius off; founders and
    /// cars, which nothing harms, are spared, and buildings are not touched.
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
