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

    var value: UInt64 {
        var sum = StableChecksum()
        sum.add(bytes: bytes)
        return sum.value
    }
}

extension Simulation {
    /// A checksum of the match, field by field from the ordered arrays: the tick,
    /// the pause, the outcome, the generator, the players, what each team has
    /// explored, the sites and the entities. The caches are derived from these,
    /// and the events awaiting views are left out (see `Simulation`).
    public func checksum() -> UInt64 {
        var d = Digest(capacity: 4096 + entities.count * 256 + teams.count * width * height / 8)
        d.add(tick)
        d.add(isPaused)
        if case .won(let team) = outcome { d.add(team.rawValue) } else { d.add(-1) }
        d.add(nextEntity)
        var copy = generator
        d.add(copy.next())
        for p in players {
            d.add(p.id.rawValue); d.add(p.age.rawValue); d.add(p.resources); d.add(p.study)
            d.add(p.improvements.count)
            for i in p.improvements { d.add(i.rawValue) }
            d.add(p.copperOre); d.add(p.tinOre); d.add(p.isDefeated)
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
        case .trade(let b, let give, let take): d.add(6); d.add(b.rawValue); d.add(give.rawValue); d.add(take.rawValue)
        case .carry(let r, let t): d.add(7); d.add(r.rawValue); d.add(t.rawValue)
        }
        d.add(Int(e.doing.rawValue))
        let r = e.route
        d.add(r.waypoints.count)
        for w in r.waypoints { d.add(w) }
        d.add(r.direct); d.add(r.planned); d.add(r.partial); d.add(r.forceSearch); d.add(r.plannedFor)
        d.add(r.plannedAt); d.add(r.stuck)
        if let c = e.cargo { d.add(c.kind.rawValue); d.add(c.amount) } else { d.add(-1) }
        d.add(e.dropOff?.rawValue ?? -1)
        // A merchant's goods; nothing is added for others, so that matches without merchants keep their checksums.
        if let goods = e.goods { d.add(goods) }
        // A farm's food yielded since sowing; likewise nothing for others.
        if let used = e.farmUsed { d.add(used) }
        // A railway journey; likewise nothing for others.
        if let trip = e.rail {
            d.add(trip.board.rawValue); d.add(trip.alight.rawValue); d.add(trip.departed ?? -1)
            d.add(trip.goal.x); d.add(trip.goal.y)
        }
        d.add(e.fraction)
        if let u = e.upgrade { d.add(u.to.rawValue); d.add(u.remaining) } else { d.add(-1) }
        d.add(e.built); d.add(e.complete); d.add(e.healthCredit); d.add(e.demolished)
        d.add(e.queue.count)
        for k in e.queue { d.add(k.rawValue) }
        d.add(e.trainProgress); d.add(e.research?.rawValue ?? -1); d.add(e.researchProgress); d.add(e.spawned)
    }
}
