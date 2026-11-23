// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Bytes for `StableChecksum`, gathered value by value, little-endian, so that
/// the sum is the same in every process.
struct Digest {
    private var bytes: [UInt8] = []

    init(capacity: Int) { bytes.reserveCapacity(capacity) }

    mutating func add(_ v: UInt64) {
        for k in 0..<8 { bytes.append(UInt8(truncatingIfNeeded: v >> UInt64(8 * k))) }
    }

    mutating func add(_ v: Int) { add(UInt64(bitPattern: Int64(v))) }
    mutating func add(_ v: Bool) { bytes.append(v ? 1 : 0) }
    mutating func add(_ v: Double) { add(v.bitPattern) }
    mutating func add(_ p: GridPoint) { add(p.x); add(p.y) }
    mutating func add(_ p: MapPosition) { add(p.x); add(p.y) }
    mutating func add(_ amounts: ResourceAmounts) { for a in amounts.amounts { add(a) } }
    mutating func add(_ v: Double?) { if let v { add(true); add(v) } else { add(false) } }
    mutating func add(_ kind: EntityKind) {
        switch kind {
        case .unit(let k): add(0); add(k.rawValue)
        case .building(let k): add(1); add(k.rawValue)
        }
    }
    mutating func add(_ levels: [AgeUpgrade]) {
        add(levels.count); for l in levels { add(l.age.rawValue); add(l.health); add(l.attack) }
    }
    mutating func add(_ attack: Attack?) {
        guard let attack else { add(false); return }
        add(true); add(attack.damage); add(attack.range); add(attack.interval); add(attack.area)
    }

    /// Every figure of the catalogue, so that two Macs, or a save and its
    /// match, playing by different tables have different checksums.
    mutating func add(_ c: Catalogue) {
        for u in c.units {
            add(u.kind.rawValue); add(u.age.rawValue); add(u.cost); add(u.health); add(u.armour); add(u.speed); add(u.sight)
            add(u.attack); add(u.population); for g in u.gathering { add(g) }; add(u.farming)
            add(u.healing); add(u.repairing); add(u.radius)
            add(u.trainedAt.count); for b in u.trainedAt { add(b) }
            add(u.trains.count); for t in u.trains { add(t.rawValue) }
            add(u.levels)
        }
        for b in c.buildings {
            add(b.kind.rawValue); add(b.age.rawValue); add(b.cost); add(b.buildTime); add(b.health); add(b.armour)
            add(b.footprint); add(b.sight); add(b.attack); add(b.housing)
            add(b.trains.count); for u in b.trains { add(u.rawValue) }
            add(b.levels); add(b.demolishTime); add(b.demolishReturn)
        }
        add(c.production.count)
        for p in c.production { add(p.maker); add(p.unit.rawValue); add(p.age.rawValue); add(p.time) }
        add(c.advances.count)
        for a in c.advances { add(a.from.rawValue); add(a.cost); add(a.time) }
        add(c.gathering.farmYield); add(c.gathering.farmReseed)
        for a in c.gathering.amountBySite { add(a) }
        add(c.bonuses.count)
        for b in c.bonuses { add(b.attacker.rawValue); add(b.defender.rawValue); add(b.multiplier) }
        add(c.startingResources); add(c.startingPeople); add(c.founderPeople); add(c.shipCargo); add(c.populationMaximum)
        if let car = c.car { add(true); add(car.killRadius); add(car.perPerson); add(car.laserRange); add(car.laserTime) } else { add(false) }
    }

    var value: UInt64 {
        var sum = StableChecksum()
        sum.add(bytes: bytes)
        return sum.value
    }
}

extension Simulation {
    /// A checksum of the match, field by field from the ordered arrays: the
    /// catalogue, the tick, the pause, the outcome, the generator, the players,
    /// what each team has explored, the sites and the entities. The caches are derived from these,
    /// and the events awaiting views are left out (see `Simulation`).
    public func checksum() -> UInt64 {
        var d = Digest(capacity: 4096 + entities.count * 256 + teams.count * width * height / 8)
        d.add(catalogue)
        d.add(tick)
        d.add(isPaused)
        d.add(pausedBy?.rawValue ?? -1)
        if case .won(let team) = outcome { d.add(team.rawValue) } else { d.add(-1) }
        d.add(nextEntity)
        var copy = generator
        d.add(copy.next())
        for p in players {
            d.add(p.id.rawValue); d.add(p.age.rawValue); d.add(p.resources); d.add(p.isDefeated)
        }
        for t in teams {
            d.add(t.id.rawValue); d.add(t.isDefeated)
            for w in t.explored.words { d.add(w) }
        }
        for s in sites { d.add(s.id.rawValue); d.add(s.kind.rawValue); d.add(s.tile); d.add(s.remaining) }
        for e in entities { add(e, to: &d) }
        return d.value
    }

    private func add(_ e: Entity, to d: inout Digest) {
        d.add(e.id.rawValue); d.add(e.owner.rawValue)
        switch e.kind {
        case .unit(let k): d.add(0); d.add(k.rawValue)
        case .building(let k): d.add(1); d.add(k.rawValue)
        }
        d.add(e.position); d.add(e.origin); d.add(e.size); d.add(e.facing.rawValue)
        d.add(e.health); d.add(e.maxHealth); d.add(e.alive); d.add(e.cooldown); d.add(e.lastHurt)
        d.add(e.sight); d.add(e.stamp); d.add(e.killRadiusOff == true)
        switch e.task {
        case .idle: d.add(0)
        case .move(let p): d.add(1); d.add(p)
        case .gather(let site, let kind, let tile): d.add(2); d.add(site.rawValue); d.add(kind.rawValue); d.add(tile)
        case .work(let b): d.add(3); d.add(b.rawValue)
        case .attack(let t): d.add(4); d.add(t.rawValue)
        case .demolish(let b): d.add(5); d.add(b.rawValue)
        case .heal(let t): d.add(6); d.add(t.rawValue)
        case .board(let s): d.add(7); d.add(s.rawValue)
        case .land(let p): d.add(8); d.add(p)
        }
        d.add(Int(e.doing.rawValue))
        let r = e.route
        d.add(r.waypoints.count)
        for w in r.waypoints { d.add(w) }
        d.add(r.direct); d.add(r.planned); d.add(r.partial); d.add(r.forceSearch); d.add(r.plannedFor)
        d.add(r.plannedAt); d.add(r.stuck)
        d.add(e.farmUsed ?? -1)
        d.add(e.fraction)
        d.add(e.built); d.add(e.complete); d.add(e.healthCredit); d.add(e.demolished)
        d.add(e.queue.count)
        for k in e.queue { d.add(k.rawValue) }
        d.add(e.trainProgress); d.add(e.advancing ?? -1); d.add(e.spawned)
        d.add(e.foundedBy?.rawValue ?? -1); d.add(e.restUntil ?? -1)
        d.add(e.passengers?.count ?? 0)
        for passenger in e.passengers ?? [] { add(passenger, to: &d) }
    }
}
