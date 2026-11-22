// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

extension Turn {
    static let warfighterKinds = UnitKind.allCases.filter(\.isWarfighter)

    /// Keeps a fading count of the opponents' warfighters seen, by kind, from
    /// which the army's mix is chosen.
    func remember() {
        var now = [Int](repeating: 0, count: UnitKind.allCases.count)
        for enemy in enemyUnits {
            if let kind = Turn.unitKind(enemy), kind.isWarfighter { now[kind.rawValue] += 1 }
        }
        for i in memory.seen.indices where i < now.count { memory.seen[i] = max(memory.seen[i] * tuning.recall, Double(now[i])) }
        var places = memory.lastSeenPeople ?? []
        for enemy in enemyUnits {
            places.removeAll { $0.distance(to: enemy.position) < 6 }
            places.append(enemy.position)
        }
        // A place looked at again and found empty is forgotten.
        places.removeAll { place in view.visibility(at: place.tile) == .visible && !enemyUnits.contains { $0.position.distance(to: place) < 6 } }
        memory.lastSeenPeople = Array(places.suffix(8))
    }

    /// Where an army with no building to attack goes: the nearest place an
    /// opponent's person was last seen, else ground not seen or not in sight.
    func huntingGround(from point: MapPosition) -> MapPosition? {
        if let place = (memory.lastSeenPeople ?? []).min(by: { $0.distance(to: point) < $1.distance(to: point) }) { return place }
        return frontier(from: point, orFog: true)
    }

    // MARK: Defence

    /// Where the player's people or buildings have been struck, or opponents
    /// stand among its buildings, its warfighters attack them. A raid of some
    /// size calls an attacking army home.
    func defend() {
        let recent = memory.strikes.filter { view.tick - $0.tick <= Tick.seconds(10) }
        // Opponents outside the box around its buildings and strikes are passed over at once.
        let points = buildings.map(\.position) + recent.map(\.position)
        let low = MapPosition(x: (points.map(\.x).min() ?? 0) - 10, y: (points.map(\.y).min() ?? 0) - 10)
        let high = MapPosition(x: (points.map(\.x).max() ?? 0) + 10, y: (points.map(\.y).max() ?? 0) + 10)
        intruders = enemyUnits.filter { enemy in
            let p = enemy.position
            guard p.x >= low.x, p.y >= low.y, p.x <= high.x, p.y <= high.y else { return false }
            return buildings.contains { $0.position.distance(to: p) <= 10 } || recent.contains { $0.position.distance(to: p) <= 8 }
        }
        // An opponent's worker among the buildings is attacked, but
        // only warfighters, or a strike, make the player threatened.
        raiders = intruders.filter { Turn.unitKind($0)?.isWarfighter ?? false }.count
        threatened = raiders > 0 || !recent.isEmpty
        guard threatened || !intruders.isEmpty else { return }
        let focus = recent.last?.position ?? Turn.nearest(intruders, to: base)?.position ?? base
        if memory.campaign != nil, raiders >= 3 || (threatened && raiders * 2 >= warfighters.count) {
            memory.campaign = nil
        }
        let defenders = warfighters.filter {
            isFree($0) && $0.activity != .fighting && (memory.campaign == nil || $0.position.distance(to: focus) <= 20)
        }
        if intruders.isEmpty {
            let ids = defenders.filter { $0.activity == .idle && $0.position.distance(to: focus) > 3 }.map(\.id)
            if !ids.isEmpty { give(.move(units: ids, to: clamped(focus)), to: ids) }
        } else if raiders == 0 {
            // A worker alone is seen off by the two nearest.
            let nearest = defenders.sorted {
                let a = $0.position.distance(to: focus), b = $1.position.distance(to: focus)
                return a != b ? a < b : $0.id < $1.id
            }
            attack(intruders, with: Array(nearest.prefix(2)))
        } else {
            attack(intruders, with: defenders)
        }
    }

    /// Each unit attacks the opponent it is best placed to beat: near it, and
    /// weak against it by `Catalogue.bonuses`, warfighters before other people.
    func attack(_ targets: [EntityView], with units: [EntityView]) {
        // The targets come from `enemyUnits`, which holds opponents' units alone, cars left out.
        let kinds = targets.map { Turn.unitKind($0) ?? .worker }
        let positions = targets.map(\.position)
        var groups: [(target: Int, units: [EntityID])] = []
        for unit in units {
            guard let mine = Turn.unitKind(unit) else { continue }
            var best = -1
            var bestScore = Double.infinity
            for i in 0..<positions.count {
                let dx = positions[i].x - unit.position.x, dy = positions[i].y - unit.position.y
                var score = (dx * dx + dy * dy).squareRoot() - tuning.counters * 3 * edge(mine, over: kinds[i])
                if !kinds[i].isWarfighter { score += 5 }
                if score < bestScore { best = i; bestScore = score }
            }
            guard best >= 0 else { continue }
            if let g = groups.firstIndex(where: { $0.target == best }) {
                groups[g].units.append(unit.id)
            } else {
                groups.append((best, [unit.id]))
            }
        }
        for group in groups { give(.attack(units: group.units, target: targets[group.target].id), to: group.units) }
    }

    // MARK: The army

    /// From the age of farms, buildings that train warfighters train a mixed army.
    func trainArmy() {
        guard view.age >= .farms else { return }
        var army = Turn.warfighterKinds.reduce(warfighters.count) { $0 + training[$1.rawValue] }
        let barracks = buildings.filter { building in
            guard Turn.isComplete(building), case .building(let kind) = building.kind else { return false }
            let trains = catalogue.stats(kind).trains
            return trains.contains(where: \.isWarfighter) && !trains.contains(.worker)
        }
        let cap = tuning.armyCap
        for building in barracks where isFree(building) && queueLength(building) < tuning.queue {
            guard army < cap else { return }
            guard let kind = nextWarfighter(at: building) else { continue }
            guard projectedPopulation + catalogue.stats(kind).population <= view.populationLimit else { return }
            train(kind, at: building)
            army += 1
        }
    }

    /// The kind of the newest age trainable at a building whose share of the
    /// army is furthest below the share `mix` gives it, of those that can be
    /// paid for; when none of the newest age can be, those of the age before
    /// (a new age's warfighters may cost a resource not yet mined).
    private func nextWarfighter(at building: EntityView) -> UnitKind? {
        guard case .building(let kind) = building.kind else { return nil }
        let trainable = catalogue.stats(kind).trains.filter { $0.isWarfighter && catalogue.stats($0).age <= view.age }
        let ages = Set(trainable.map { catalogue.stats($0).age }).sorted(by: >)
        for age in ages.prefix(view.age >= .ships ? 2 : 1) {
            if let kind = nextWarfighter(of: trainable.filter { catalogue.stats($0).age == age }) { return kind }
        }
        return nil
    }

    private func nextWarfighter(of kinds: [UnitKind]) -> UnitKind? {
        guard !kinds.isEmpty else { return nil }
        let weights = Turn.mix(kinds, seen: memory.seen, counters: tuning.counters, catalogue: catalogue)
        let total = weights.reduce(0, +)
        let have = kinds.map { kind in warfighters.filter { $0.kind == .unit(kind) }.count + training[kind.rawValue] }
        let size = Double(have.reduce(0, +) + 1)
        let gaps = kinds.indices.map { weights[$0] / total - Double(have[$0]) / size }
        let order = kinds.indices.sorted { gaps[$0] != gaps[$1] ? gaps[$0] > gaps[$1] : $0 < $1 }
        for i in order where canPay(catalogue.stats(kinds[i]).cost, urgent: threatened) { return kinds[i] }
        return nil
    }

    /// The share of the army each kind should have: an even mix, by places
    /// under the population limit, leaning by `counters` toward the kinds that
    /// strike the warfighters seen harder than those strike back.
    static func mix(_ kinds: [UnitKind], seen: [Double], counters: Double, catalogue: Catalogue) -> [Double] {
        let opponents = UnitKind.allCases.filter { $0.isWarfighter && $0.rawValue < seen.count && seen[$0.rawValue] > 0 }
        let total = opponents.reduce(0.0) { $0 + seen[$1.rawValue] }
        return kinds.map { kind in
            var edge = 0.0
            for other in opponents {
                edge += seen[other.rawValue] / total
                    * (catalogue.bonus(kind, against: other) - catalogue.bonus(other, against: kind))
            }
            return max(0.1, 1 + counters * edge) / Double(max(1, catalogue.stats(kind).population))
        }
    }

    // MARK: Attack

    /// From the difficulty's earliest attack time, with an army large enough,
    /// the player attacks the nearest known opponent's building, or the one an
    /// allied computer player is seen attacking, which it joins with a smaller
    /// army. Opponents' warfighters met on the way are fought first. The army
    /// withdraws when fewer than a third remain; each attack ended makes the next
    /// wait for two more warfighters, and for a few more drawn at random.
    func campaign() {
        let army = warfighters.filter { isFree($0) && memory.scout?.unit != $0.id }
        guard var current = memory.campaign else {
            launch(army)
            return
        }
        if warfighters.count < 2 || warfighters.count * 3 < current.size {
            withdraw(army)
            return
        }
        let centre = Turn.mean(army.map(\.position)) ?? base
        var retarget = false
        let known = current.target.map { id in memory.enemies.contains { $0.id == id } } ?? false
        if !known {
            if let next = allyTarget() ?? nearestEnemyBuilding(to: centre) {
                current.target = next.id
                current.destination = next.position
                retarget = true
            } else if current.target != nil || army.filter({ $0.activity == .idle }).count * 2 >= army.count
                        || centre.distance(to: current.destination) < 6
                        || view.tick - (current.aimed ?? current.launched) > Tick.seconds(90) {
                // A hunt goes on to new ground once the army is there, or after a
                // minute and a half, so that ground it cannot reach holds it no longer.
                guard let destination = huntingGround(from: centre) else {
                    withdraw(army)
                    return
                }
                current.target = nil
                current.destination = destination
                current.aimed = view.tick
                memory.scouted.append(destination)
                if memory.scouted.count > 24 { memory.scouted.removeFirst(memory.scouted.count - 24) }
                retarget = true
            }
        }
        // With no building of the opponents' left to find, any of their people in reach is fought.
        let contact = enemyUnits.filter {
            ((Turn.unitKind($0)?.isWarfighter ?? false) || memory.enemies.isEmpty) && $0.position.distance(to: centre) <= 8
        }
        let visible = current.target.map { view.entity($0) != nil } ?? false
        let stance: Campaign.Stance = !contact.isEmpty ? .engaging : (visible ? .attacking : .marching)
        let units = army.filter { $0.activity != .fighting && (retarget || stance != current.stance || $0.activity == .idle) }
        current.stance = stance
        order(units, in: current, contact: contact)
        memory.campaign = current
    }

    private func launch(_ army: [EntityView]) {
        guard view.age >= .farms, view.tick >= tuning.firstAttack, !threatened else {
            rally(army)
            return
        }
        let needed = tuning.attackSize + min(8, 2 * memory.waves) + memory.extra
        let joint = army.count >= tuning.joinSize ? allyTarget() : nil
        guard joint != nil || army.count >= needed else {
            rally(army)
            return
        }
        let target = joint ?? nearestEnemyBuilding(to: base)
        guard let destination = target?.position ?? huntingGround(from: Turn.mean(army.map(\.position)) ?? base) else {
            rally(army)
            return
        }
        let visible = target.map { view.entity($0.id) != nil } ?? false
        let campaign = Campaign(target: target?.id, destination: destination, size: army.count, launched: view.tick,
                                stance: visible ? .attacking : .marching)
        order(army.filter { $0.activity != .fighting }, in: campaign, contact: [])
        memory.campaign = campaign
    }

    private func order(_ units: [EntityView], in campaign: Campaign, contact: [EntityView]) {
        guard !units.isEmpty else { return }
        let ids = units.map(\.id)
        switch campaign.stance {
        case .engaging:
            attack(contact, with: units)
        case .attacking:
            if let target = campaign.target, let building = view.entity(target), isOpponent(building.owner) {
                give(.attack(units: ids, target: target), to: ids)
            }
        case .marching:
            give(.move(units: ids, to: clamped(campaign.destination)), to: ids)
        }
    }

    /// The army falls back to its rallying point, and the next attack waits for more.
    private func withdraw(_ army: [EntityView]) {
        let ids = army.map(\.id)
        if !ids.isEmpty { give(.move(units: ids, to: rallyPoint), to: ids) }
        memory.campaign = nil
        memory.waves += 1
        memory.extra = Int(generator.next() % 3)
    }

    /// Idle warfighters gather between the base and the front.
    private func rally(_ army: [EntityView]) {
        let point = rallyPoint
        let strays = army.filter { $0.activity == .idle && $0.position.distance(to: point) > 7 }.map(\.id)
        if !strays.isEmpty { give(.move(units: strays, to: point), to: strays) }
    }

    private var rallyPoint: MapPosition { clamped(Turn.toward(base, front, by: 5)) }

    /// The known opponent's building with the most of an allied computer
    /// player's warfighters fighting or moving near it, two at least.
    func allyTarget() -> KnownBuilding? {
        var best: KnownBuilding?
        var bestCount = 1
        for building in memory.enemies {
            var count = 0
            for ally in allyWarfighters where ally.activity == .fighting || ally.activity == .moving {
                if ally.position.distance(to: building.position) <= 8 { count += 1 }
            }
            if count > bestCount { best = building; bestCount = count }
        }
        return best
    }

    // MARK: Scouting

    /// When no opponent's building is known and no army is out, one unit
    /// explores: the fastest warfighter not fighting, or failing that, once the
    /// economy has six workers, a worker. It returns when an opponent is found.
    func scout() {
        guard memory.enemies.isEmpty, memory.campaign == nil else {
            release()
            return
        }
        let current = memory.scout.flatMap { view.entity($0.unit) }.flatMap { $0.owner == view.player ? $0 : nil }
        guard let unit = current ?? pickScout(), isFree(unit), unit.activity != .fighting else { return }
        if let scouting = memory.scout, scouting.unit == unit.id, unit.activity != .idle,
           view.visibility(at: scouting.destination.tile) == .unexplored { return }
        guard let destination = frontier(from: unit.position) else {
            release()
            return
        }
        give(.move(units: [unit.id], to: destination), to: [unit.id])
        memory.scout = Scouting(unit: unit.id, destination: destination, tick: view.tick)
        memory.scouted.append(destination)
        if memory.scouted.count > 24 { memory.scouted.removeFirst(memory.scouted.count - 24) }
    }

    private func pickScout() -> EntityView? {
        let candidates = warfighters.filter { isFree($0) && $0.activity != .fighting }
        let fastest = candidates.min { a, b in
            let sa = Turn.unitKind(a).map { catalogue.stats($0).speed } ?? 0
            let sb = Turn.unitKind(b).map { catalogue.stats($0).speed } ?? 0
            return sa != sb ? sa > sb : a.id < b.id
        }
        if let fastest { return fastest }
        guard workers.count >= 6, view.tick >= Tick.seconds(90) else { return nil }
        return workers.last { isFree($0) && $0.activity != .fighting && !Turn.isCarrying($0) }
    }

    private func release() {
        guard let scouting = memory.scout else { return }
        memory.scout = nil
        guard let unit = view.entity(scouting.unit), unit.owner == view.player, isFree(unit),
              unit.activity != .fighting else { return }
        give(.move(units: [unit.id], to: Turn.unitKind(unit) == .worker ? clamped(base) : rallyPoint), to: [unit.id])
    }

    /// A point to explore: of the centres of six-tile cells not yet explored
    /// (with `orFog`, or not in sight) nor already given to a scout, one of the
    /// three nearest to `point` and farthest from the base, chosen at random.
    func frontier(from point: MapPosition, orFog: Bool = false) -> MapPosition? {
        // An army hunting the last of an opponent sweeps the ground out of sight
        // as well as the unexplored: a building begun and left stands on ground
        // the army may have seen before it.
        frontier(from: point, seeking: orFog ? [.unexplored, .explored] : [.unexplored])
    }

    private func frontier(from point: MapPosition, seeking wanted: Set<TileVisibility>) -> MapPosition? {
        let step = 6
        var best: [(score: Double, point: MapPosition)] = []
        var y = step / 2
        while y < view.mapHeight {
            var x = step / 2
            while x < view.mapWidth {
                let tile = GridPoint(x, y)
                x += step
                guard wanted.contains(view.visibility(at: tile)) else { continue }
                let candidate = tile.centre
                guard !memory.scouted.contains(where: { $0.distance(to: candidate) < 4 }) else { continue }
                let score = point.distance(to: candidate) - 0.5 * base.distance(to: candidate)
                if best.count < 3 || score < best[best.count - 1].score {
                    let i = best.firstIndex { score < $0.score } ?? best.count
                    best.insert((score, candidate), at: i)
                    if best.count > 3 { best.removeLast() }
                }
            }
            y += step
        }
        guard !best.isEmpty else { return nil }
        return best[Int(generator.next() % UInt64(best.count))].point
    }

    static func isCarrying(_ entity: EntityView) -> Bool {
        if case .carrying = entity.activity { return true }
        return false
    }
}
