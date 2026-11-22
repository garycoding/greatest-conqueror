// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Merchants (requirement 15, "Sectors"): they exchange one resource for another
// at a town centre, and carry resources to an ally.

extension Simulation {
    /// A merchant at an own town centre turns `give` into `take`, a little each
    /// tick, until `give` runs out.
    mutating func tradeTask(_ i: Int, at building: EntityID, give: Resource, take: Resource) {
        guard let rates = catalogue.merchants, let b = index(of: building), entities[b].alive, entities[b].complete,
              entities[b].owner == entities[i].owner else { setIdle(i); return }
        switch approach(i, .tiles(entities[b].origin, entities[b].size, reach: Rule.besideReach)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        let p = entities[i].owner.rawValue
        guard players[p].resources[give] > 0 else { setIdle(i); return }
        face(i, dx: entities[b].position.x - entities[i].position.x, dy: entities[b].position.y - entities[i].position.y)
        entities[i].doing = .working
        // `fraction` counts the units of `give` owed; each whole unit goes, and its worth in `take` comes.
        entities[i].fraction += rates.exchangePerSecond / Double(Tick.rate)
        while entities[i].fraction >= 1 && players[p].resources[give] > 0 {
            entities[i].fraction -= 1
            players[p].resources[give] -= 1
            // Rounded down, so that the exchange never makes more than its rate gives.
            let banking = players[p].improvements.reduce(1.0) { $0 * (catalogue.stats($1).exchangeMultiplier ?? 1) }
            entities[i].healthCredit += Int((rates.exchangeRate * banking * 1000).rounded(.down))
            while entities[i].healthCredit >= 1000 {
                entities[i].healthCredit -= 1000
                players[p].resources[take] += 1
            }
        }
    }

    /// A merchant fetches a load from its owner's nearest building that
    /// accepts the resource, takes it to the ally's building, and goes back.
    mutating func carryTask(_ i: Int, _ resource: Resource, to target: EntityID) {
        guard let rates = catalogue.merchants else { setIdle(i); return }
        let owner = entities[i].owner
        guard let t = index(of: target), entities[t].alive, entities[t].complete, entities[t].owner != owner,
              teamOf(entities[t].owner) == teamOf(owner), accepts(t, resource, from: entities[t].owner) else {
            returnGoods(i, resource)
            setIdle(i)
            return
        }
        if (entities[i].goods ?? 0) > 0 {
            entities[i].doing = .carrying
            switch approach(i, .tiles(entities[t].origin, entities[t].size, reach: Rule.besideReach)) {
            case .moving: return
            case .unreachable: returnGoods(i, resource); setIdle(i); return
            case .arrived: break
            }
            players[entities[t].owner.rawValue].resources[resource] += entities[i].goods ?? 0
            entities[i].goods = nil
            entities[i].route = Route()
            return
        }
        let p = owner.rawValue
        guard players[p].resources[resource] > 0, let home = nearestDropOff(for: i, accepting: resource) else {
            setIdle(i)
            return
        }
        switch approach(i, .tiles(entities[home].origin, entities[home].size, reach: Rule.besideReach)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        let taken = min(rates.load, players[p].resources[resource])
        players[p].resources[resource] -= taken
        entities[i].goods = taken
        entities[i].route = Route()
    }

    /// Goods a merchant holds go back to its owner's stock.
    mutating func returnGoods(_ i: Int, _ resource: Resource) {
        if let goods = entities[i].goods, goods > 0 { players[entities[i].owner.rawValue].resources[resource] += goods }
        entities[i].goods = nil
    }

    mutating func exchange(_ ids: [EntityID], give: Resource, take: Resource, player: PlayerID) -> OrderResult {
        guard catalogue.merchants != nil else { return .refused(.invalidTarget) }
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let merchants = people.filter { entities[$0].unitKind == .merchant }
        guard !merchants.isEmpty else { return .refused(.notYours) }
        let p = player.rawValue
        guard give != take, give.firstAge <= players[p].age, take.firstAge <= players[p].age else {
            return .refused(.invalidTarget)
        }
        guard players[p].resources[give] > 0 else { return .refused(.notEnough(ResourceAmounts([give: 1]))) }
        let position = entities[merchants[0]].position
        let centres = entities.indices.filter {
            entities[$0].alive && entities[$0].complete && entities[$0].owner == player && entities[$0].buildingKind == .townCentre
        }
        guard let centre = centres.min(by: { entities[$0].position.distance(to: position) < entities[$1].position.distance(to: position) })
        else { return .refused(.invalidTarget) }
        for i in merchants {
            returnCarried(i)
            entities[i].fraction = 0
            entities[i].healthCredit = 0
            assign(i, .trade(at: entities[centre].id, give: give, take: take))
        }
        return .accepted
    }

    mutating func carry(_ ids: [EntityID], _ resource: Resource, to target: EntityID, player: PlayerID) -> OrderResult {
        guard catalogue.merchants != nil else { return .refused(.invalidTarget) }
        guard let people = ownPeople(ids, player) else { return .refused(.notYours) }
        let merchants = people.filter { entities[$0].unitKind == .merchant }
        guard !merchants.isEmpty else { return .refused(.notYours) }
        guard let t = index(of: target), entities[t].alive, entities[t].complete, entities[t].owner != player,
              teamOf(entities[t].owner) == teamOf(player), resource.firstAge <= players[player.rawValue].age,
              accepts(t, resource, from: entities[t].owner) else { return .refused(.invalidTarget) }
        for i in merchants {
            returnCarried(i)
            assign(i, .carry(resource, to: target))
        }
        return .accepted
    }

    /// A merchant given new work first puts back what it was carrying.
    mutating func returnCarried(_ i: Int) {
        if case .carry(let resource, _) = entities[i].task { returnGoods(i, resource) }
    }
}
