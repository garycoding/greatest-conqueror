// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Combat. A blow does the attack's damage, times `Catalogue.bonus` where one
// unit kind strikes another, rounded, less the defender's armour, and never
// less than 1. A blow at or within `Attack.range` lands at once: melee and
// ranged differ only in reach. Allies never harm one another, and nothing
// harms a car or a founder. Towers, castles and navy ships strike with the
// attack of their owner's age (requirement 24). A blow with an area (a cannon's shot) also harms every
// opponent within that many tiles of the target, and never an ally.

extension Simulation {
    /// Whether people of a player may strike an entity.
    func canStrike(_ attacker: PlayerID, _ target: Int) -> Bool {
        let t = entities[target]
        return t.alive && !t.isUnharmable && teamOf(t.owner) != teamOf(attacker)
    }

    /// How far a blow reaches, at least to the next tile.
    func reach(of attack: Attack) -> Double { max(attack.range, 1) }

    mutating func attackTask(_ i: Int, target: EntityID) {
        if entities[i].unitKind == .car { laserTask(i, target: target); return }
        guard let kind = entities[i].unitKind, let attack = attack(of: i) else { setIdle(i); return }
        let owner = entities[i].owner
        let team = teamOf(owner)
        var targetIndex = index(of: target)
        if let t = targetIndex, !canStrike(owner, t) || !(seesEverything(owner.rawValue) || isVisible(entities[t], to: team)) {
            targetIndex = nil
        }
        if targetIndex == nil {
            // The target is gone: a warfighter or a navy ship takes the nearest opponent it can see, if any.
            guard kind.isWarfighter || kind == .navyShip, let next = nearestTarget(for: i) else { setIdle(i); return }
            assign(i, .attack(entities[next].id))
            targetIndex = next
        }
        guard let t = targetIndex else { return }
        let goal: Goal = entities[t].isPerson
            ? .point(entities[t].position, reach: reach(of: attack), moving: true)
            : .tiles(entities[t].origin, entities[t].size, reach: reach(of: attack))
        switch approach(i, goal) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        entities[i].doing = .fighting
        face(i, dx: entities[t].position.x - entities[i].position.x, dy: entities[t].position.y - entities[i].position.y)
        if entities[i].cooldown == 0 {
            strike(from: i, at: t, attack: attack)
            entities[i].cooldown = attack.interval
        }
    }

    /// A car drives to within `CarStats.laserRange` of an opponent's building and
    /// burns it down in `CarStats.laserTime` ticks, whatever its size (ruled
    /// 2026-11-21): each tick takes the building's full health divided by that time.
    mutating func laserTask(_ i: Int, target: EntityID) {
        guard let car = catalogue.car, let t = index(of: target), !entities[t].isPerson,
              canStrike(entities[i].owner, t) else { setIdle(i); return }
        switch approach(i, .tiles(entities[t].origin, entities[t].size, reach: car.laserRange)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: setIdle(i); return
        case .arrived: break
        }
        entities[i].doing = .fighting
        face(i, dx: entities[t].position.x - entities[i].position.x, dy: entities[t].position.y - entities[i].position.y)
        let burn = max(1, (entities[t].maxHealth + car.laserTime - 1) / max(1, car.laserTime))
        entities[t].health -= burn
        entities[t].lastHurt = tick
        guard entities[t].health <= 0 else { return }
        let owner = entities[t].owner.rawValue, killer = entities[i].owner.rawValue
        kill(t)
        record(.destroyed(entities[t].id), for: owner)
        if killer != owner { record(.destroyed(entities[t].id), for: killer) }
        setIdle(i)
    }

    /// The nearest opponent person a warfighter can see, within its sight.
    func nearestTarget(for i: Int) -> Int? {
        let e = entities[i]
        return nearestOpponent(of: teamOf(e.owner), minX: e.position.x, minY: e.position.y, maxX: e.position.x,
                               maxY: e.position.y, within: e.sight, visibleOnly: true)
    }

    /// The harm one blow does.
    func harm(from attacker: Int, to target: Int, attack: Attack) -> Int {
        let a = entities[attacker], t = entities[target]
        var damage = Double(attack.damage)
        if let ak = a.unitKind, let tk = t.unitKind { damage *= tables.bonus(ak, against: tk) }
        let armour: Int
        if let tk = t.unitKind {
            armour = tables.unit(tk).armour
        } else if let tk = t.buildingKind {
            armour = tables.building(tk).armour
        } else {
            armour = 0
        }
        return max(1, Int(damage.rounded()) - armour)
    }

    mutating func strike(from attacker: Int, at target: Int, attack: Attack) {
        guard canStrike(entities[attacker].owner, target) else { return }
        if let area = attack.area, area > 0 {
            let centre = entities[target].position, owner = entities[attacker].owner
            let around = entities.indices.filter { j in
                j != target && j != attacker && canStrike(owner, j) && entities[j].position.distance(to: centre) <= area
            }
            for j in around { hit(from: attacker, at: j, attack: attack) }
        }
        hit(from: attacker, at: target, attack: attack)
    }

    /// One blow on one entity: harm, death, the warning and the reply.
    private mutating func hit(from attacker: Int, at target: Int, attack: Attack) {
        guard canStrike(entities[attacker].owner, target) else { return }
        entities[target].health -= harm(from: attacker, to: target, attack: attack)
        let owner = entities[target].owner.rawValue
        if entities[target].health <= 0 {
            kill(target)
            record(.destroyed(entities[target].id), for: owner)
            let killer = entities[attacker].owner.rawValue
            if killer != owner { record(.destroyed(entities[target].id), for: killer) }
            return
        }
        if tick - entities[target].lastHurt >= Rule.underAttackInterval { record(.underAttack(entities[target].id), for: owner) }
        entities[target].lastHurt = tick
        // An idle warfighter or navy ship fights back.
        if let kind = entities[target].unitKind, kind.isWarfighter || kind == .navyShip, entities[target].task == .idle,
           canStrike(entities[target].owner, attacker) {
            assign(target, .attack(entities[attacker].id))
        }
    }

    /// Mark an entity dead and take it out of the grids at once; it leaves
    /// `entities` at the end of the tick.
    mutating func kill(_ i: Int) {
        guard entities[i].alive else { return }
        stampSight(of: i, by: -1)
        entities[i].alive = false
        entities[i].health = 0
        let p = entities[i].owner.rawValue
        if let kind = entities[i].unitKind {
            population[p] -= tables.unit(kind).population
            // The troops aboard a ship go down with it (requirement 16).
            for passenger in entities[i].passengers ?? [] {
                population[p] -= passenger.unitKind.map { tables.unit($0).population } ?? 0
                record(.destroyed(passenger.id), for: p)
            }
            entities[i].passengers = nil
        } else if let kind = entities[i].buildingKind {
            if entities[i].complete { housing[p] -= tables.building(kind).housing }
            for t in footprintTiles(origin: entities[i].origin, size: entities[i].size) where inMap(t) {
                let k = tileIndex(t)
                guard buildingAt[k] == Int32(entities[i].id.rawValue) else { continue }
                buildingAt[k] = -1
                blocked[k] = !terrain[k].isPassable || siteAt[k] >= 0 && sites[Int(siteAt[k])].kind.blocksTile
            }
        }
        deathsPending = true
    }
}
