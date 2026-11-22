// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Healing, repair and the age upgrades (requirements 12, 13 and 24).
//
// A doctor restores `heal_per_second` to a wounded unit of its player, and a
// worker `repair_per_second` to a damaged building of its player; each counts
// for itself, so that several heal or repair sooner. An idle doctor or worker
// looks, every `Rule.careSearchInterval` ticks, for a wounded unit or a
// damaged building within its `radius`, and goes to stand beside it.
//
// When a player reaches an age, every tower, castle and navy ship of that
// player takes the age's row of `stats.csv`: its maximum health becomes the
// row's, and its health keeps the same share of the maximum, rounded to the
// nearest point; its attack is read from the row whenever it strikes.

extension Simulation {
    /// Add a rate a second to a person's carried fraction for one tick, and
    /// return the whole points it makes.
    mutating func accrue(_ i: Int, _ rate: Double) -> Int {
        let total = entities[i].fraction + rate / Double(Tick.rate)
        let whole = Int(total.rounded(.down))
        entities[i].fraction = total - Double(whole)
        return whole
    }

    /// An idle worker or doctor takes up the nearest repair or healing within its radius.
    mutating func lookForCare(_ i: Int) {
        guard (tick + entities[i].id.rawValue) % Rule.careSearchInterval == 0, (entities[i].restUntil ?? 0) <= tick,
              let kind = entities[i].unitKind else { return }
        let stats = tables.unit(kind)
        guard let radius = stats.radius else { return }
        if (stats.repairing ?? 0) > 0, let b = damagedBuilding(near: i, within: radius) {
            entities[i].fraction = 0
            assign(i, .work(entities[b].id))
        } else if (stats.healing ?? 0) > 0, let t = woundedUnit(near: i, within: radius) {
            entities[i].fraction = 0
            assign(i, .heal(entities[t].id))
        }
    }

    /// The nearest complete, damaged building of the person's player within a
    /// radius of it, measured to the footprint; ties go to the lower id.
    func damagedBuilding(near i: Int, within radius: Double) -> Int? {
        let owner = entities[i].owner, position = entities[i].position
        var best: Int?
        var bestDistance = Double.infinity
        for j in entities.indices where entities[j].alive && entities[j].owner == owner && !entities[j].isPerson
            && entities[j].complete && entities[j].health < entities[j].maxHealth {
            let d = Goal.tiles(entities[j].origin, entities[j].size, reach: 0).distance(to: position)
            if d <= radius && d < bestDistance { best = j; bestDistance = d }
        }
        return best
    }

    /// Whether a doctor may heal an entity: a wounded unit of its player, on
    /// land, other than itself.
    func canHeal(_ doctor: Int, _ t: Int) -> Bool {
        let e = entities[t]
        return t != doctor && e.alive && e.owner == entities[doctor].owner && (e.unitKind?.isUnit ?? false)
            && !e.isAfloat && e.health < e.maxHealth
    }

    /// The nearest wounded unit a doctor may heal within a radius of it; ties go to the lower id.
    func woundedUnit(near i: Int, within radius: Double) -> Int? {
        let position = entities[i].position
        var best: Int?
        var bestDistance = Double.infinity
        for j in entities.indices where canHeal(i, j) {
            let d = entities[j].position.distance(to: position)
            if d <= radius && d < bestDistance { best = j; bestDistance = d }
        }
        return best
    }

    /// A doctor walks beside a wounded unit and heals it to its maximum.
    mutating func healTask(_ i: Int, _ target: EntityID) {
        guard let kind = entities[i].unitKind, let rate = tables.unit(kind).healing, rate > 0,
              let t = index(of: target), canHeal(i, t) else { setIdle(i); return }
        switch approach(i, .point(entities[t].position, reach: Rule.besideReach, moving: true)) {
        case .moving: entities[i].doing = .moving; return
        case .unreachable: rest(i); return
        case .arrived: break
        }
        entities[i].doing = .working
        face(i, dx: entities[t].position.x - entities[i].position.x, dy: entities[t].position.y - entities[i].position.y)
        let whole = accrue(i, rate)
        entities[t].health = min(entities[t].maxHealth, entities[t].health + whole)
        if entities[t].health >= entities[t].maxHealth { setIdle(i) }
    }

    /// A worker or doctor that cannot reach its work goes idle, and looks for no
    /// more for `Rule.careRest` ticks.
    mutating func rest(_ i: Int) {
        setIdle(i)
        entities[i].restUntil = tick + Rule.careRest
    }

    /// The attack of a unit or building, in its owner's age for the kinds upgraded with the age.
    func attack(of i: Int) -> Attack? {
        let age = players[entities[i].owner.rawValue].age
        if let kind = entities[i].unitKind { return tables.unit(kind).figures(at: age).attack }
        if let kind = entities[i].buildingKind { return tables.building(kind).figures(at: age).attack }
        return nil
    }

    /// The upgrade of a player's towers, castles and navy ships to its age.
    mutating func upgrade(player p: Int) {
        let age = players[p].age
        for i in entities.indices where entities[i].alive && entities[i].owner.rawValue == p {
            let health: Int
            if let kind = entities[i].unitKind, kind.isUpgradedWithAge {
                health = tables.unit(kind).figures(at: age).health
            } else if let kind = entities[i].buildingKind, kind.isUpgradedWithAge {
                health = tables.building(kind).figures(at: age).health
            } else {
                continue
            }
            let old = max(1, entities[i].maxHealth)
            guard health != old else { continue }
            entities[i].health = max(1, (entities[i].health * health + old / 2) / old)
            entities[i].maxHealth = health
        }
    }
}
