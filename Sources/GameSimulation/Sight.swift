// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Sight and views. Each entity stamps the tiles within its sight onto its
// team's count grid, and removes the stamp when it moves to another tile, dies
// or changes kind; a tile is visible to a team while its count is above zero,
// and stamping marks it explored for good. Sight is shared within a team
// (docs/requirements.md, "Co-operative play"); sites are not: a player sees a
// site only once it has reached the site kind's age (requirement 19).

extension Simulation {
    /// Add (`by: 1`) or remove (`by: -1`) an entity's sight from its team's grid.
    /// A person sees the tiles whose centres lie within its sight of its tile's
    /// centre; a building, those within its sight of its footprint.
    mutating func stampSight(of i: Int, by delta: Int32) {
        let e = entities[i]
        let team = teamOf(e.owner)
        let origin = e.stamp, size = e.size
        let r = Int(e.sight.rounded(.down))
        let r2 = e.sight * e.sight
        let x0 = max(0, origin.x - r), x1 = min(width - 1, origin.x + size.x - 1 + r)
        let y0 = max(0, origin.y - r), y1 = min(height - 1, origin.y + size.y - 1 + r)
        guard x0 <= x1, y0 <= y1 else { return }
        let base = team * width * height
        for y in y0...y1 {
            let dy = max(0, origin.y - y, y - (origin.y + size.y - 1))
            for x in x0...x1 {
                let dx = max(0, origin.x - x, x - (origin.x + size.x - 1))
                guard Double(dx * dx + dy * dy) <= r2 else { continue }
                let k = y * width + x
                seen[base + k] += delta
                if delta > 0 { teams[team].explored[k] = true }
            }
        }
    }

    /// Whether a team sees an entity now: a person's tile, or any tile of a footprint.
    func isVisible(_ e: Entity, to team: Int) -> Bool {
        let base = team * width * height
        if e.isPerson { return seen[base + tileIndex(e.position.tile)] > 0 }
        for dy in 0..<e.size.y {
            for dx in 0..<e.size.x {
                let t = GridPoint(e.origin.x + dx, e.origin.y + dy)
                if inMap(t) && seen[base + tileIndex(t)] > 0 { return true }
            }
        }
        return false
    }

    func isExplored(_ t: GridPoint, by team: Int) -> Bool { inMap(t) && teams[team].explored[tileIndex(t)] }

    /// Whether a player's orders may use the whole map: a person under
    /// `MapSight.mapShown` or `.everything` builds and works anywhere, all
    /// being revealed (ruled 2026-11-21); a computer player always explores.
    func mapRevealed(for p: Int) -> Bool { players[p].isHuman && (sight ?? .explore) != .explore }

    /// Whether a player sees every entity, and may target it: a person under `MapSight.everything`.
    func seesEverything(_ p: Int) -> Bool { players[p].isHuman && sight == .everything }

    /// Whether a player's orders may use a tile: explored by the player's team, or revealed to the player.
    func isExplored(_ t: GridPoint, byPlayer p: Int) -> Bool {
        inMap(t) && (mapRevealed(for: p) || teams[players[p].teamIndex].explored[tileIndex(t)])
    }

    /// What each player owns: anything but a founder, and a founder.
    func ownership() -> (others: [Bool], founders: [Bool]) {
        var others = Array(repeating: false, count: players.count)
        var founders = Array(repeating: false, count: players.count)
        for e in entities where e.alive {
            // A person's car keeps nobody in the match (ruled 2026-11-21).
            if e.unitKind == .car { continue }
            // Nor does a bridge (the session's decision, 2026-11-21).
            if e.buildingKind == .bridge { continue }
            if e.isFounder { founders[e.owner.rawValue] = true } else { others[e.owner.rawValue] = true }
        }
        return (others, founders)
    }

    public mutating func view(for player: PlayerID) -> PlayerView { view(for: player, asComputer: false) }

    /// A computer player always explores (ruled 2026-11-20), even in a person's seat.
    public mutating func computerView(for player: PlayerID) -> PlayerView { view(for: player, asComputer: true) }

    /// What a player sees: `MapSight` decides for a person, a computer player always explores.
    mutating func view(for player: PlayerID, asComputer: Bool) -> PlayerView {
        guard let p = slot(player) else {
            return PlayerView(tick: tick, player: player, age: .stone, resources: ResourceAmounts(), population: 0,
                              populationLimit: 0, ageProgress: 0, improvements: [], players: summaries(),
                              mapWidth: width, mapHeight: height, terrain: terrain,
                              visibility: Array(repeating: .unexplored, count: width * height), entities: [], sites: [],
                              events: [], outcome: outcome, isPaused: isPaused)
        }
        let me = players[p]
        let team = me.teamIndex
        let count = width * height
        let base = team * count
        let mode = me.isHuman && !asComputer ? sight ?? .explore : .explore
        var visibility = Array(repeating: TileVisibility.unexplored, count: count)
        for k in 0..<count {
            if mode == .everything || seen[base + k] > 0 {
                visibility[k] = .visible
            } else if mode == .mapShown || teams[team].explored[k] {
                visibility[k] = .explored
            }
        }
        var shown: [EntityView] = []
        for e in entities where e.alive && (mode == .everything || teamOf(e.owner) == team || isVisible(e, to: team)) {
            var seen = entityView(e)
            if e.owner == player && e.isPerson { seen.job = job(of: e) }
            shown.append(seen)
        }
        let explored = teams[team].explored, width = self.width, height = self.height, revealed = mode != .explore
        func known(_ site: ResourceSite) -> Bool {
            revealed || (site.tile.x >= 0 && site.tile.y >= 0 && site.tile.x < width && site.tile.y < height
                         && explored[site.tile.y * width + site.tile.x])
        }
        let shownSites = sites.filter { $0.remaining > 0 && $0.kind.firstAge <= me.age && known($0) }
        // A deposit not yet revealed still blocks its tile, so the view shows it as plain rock.
        let outcrops = sites
            .filter { $0.remaining > 0 && $0.kind.blocksTile && $0.kind.firstAge > me.age && known($0) }
            .map(\.tile)
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        var progress = 0.0
        if me.age.next != nil, let advance = catalogue.advance(from: me.age) {
            progress = advance.study > 0 ? min(1, Double(me.study) / Double(advance.study)) : 1
        }
        let events = me.events
        players[p].events = []
        var view = PlayerView(tick: tick, player: player, age: me.age, resources: me.resources, population: population[p],
                              populationLimit: populationLimit(p), ageProgress: progress, improvements: me.improvements,
                              players: summaries(), mapWidth: width, mapHeight: height, terrain: terrain,
                              visibility: visibility, entities: shown, sites: shownSites, outcrops: outcrops, events: events,
                              outcome: outcome, isPaused: isPaused)
        view.noBridges = noBridges
        return view
    }

    func summaries() -> [PlayerSummary] {
        let owned = ownership()
        return players.map { p in
            PlayerSummary(id: p.id, civilization: p.civilization, team: p.team, isHuman: p.isHuman, age: p.age,
                          isDefeated: p.isDefeated,
                          isFounding: !p.isDefeated && owned.founders[p.id.rawValue] && !owned.others[p.id.rawValue])
        }
    }

    /// The job a person has been set, from its task.
    func job(of e: Entity) -> Job {
        switch e.task {
        case .idle: return .idle
        case .move: return .moving
        case .gather(_, let kind, _): return .gathering(kind)
        case .work(let building):
            guard let b = index(of: building), let kind = entities[b].buildingKind else { return .idle }
            if e.unitKind == .engineer { return entities[b].complete ? .repairing : .constructing }
            return .working(kind)
        case .demolish: return .demolishing
        case .attack: return .attacking
        case .trade: return .trading
        case .carry: return .carrying
        }
    }

    func entityView(_ e: Entity) -> EntityView {
        var view = EntityView(id: e.id, owner: e.owner, kind: e.kind, position: e.position,
                              tile: e.isPerson ? e.position.tile : e.origin, facing: e.facing, health: max(0, e.health),
                              maxHealth: e.maxHealth, activity: activity(of: e),
                              remaining: remaining(of: e))
        view.bridgePlace = e.bridgePlace
        view.killRadiusOff = e.killRadiusOff
        if e.unitKind == .car, e.doing == .fighting, case .attack(let target) = e.task, let t = index(of: target) {
            view.laserTarget = entities[t].position
        }
        return view
    }

    /// For a farm, the food left before it must be reseeded; for an oil well,
    /// the oil left beneath it; nil for everything else.
    func remaining(of e: Entity) -> Int? {
        guard e.complete else { return nil }
        switch e.buildingKind {
        case .farm: return catalogue.gathering.farmYield.map { max(0, $0 - (e.farmUsed ?? 0)) }
        case .oilWell: return index(of: e.id).map { oilLeft(under: $0) }
        default: return nil
        }
    }

    func activity(of e: Entity) -> Activity {
        if let kind = e.buildingKind {
            let stats = tables.building(kind)
            if !e.complete { return .underConstruction(min(1, Double(e.built) / Double(max(1, stats.buildTime)))) }
            if let head = e.queue.first {
                let time = max(1, tables.unit(head).trainTime)
                return .training(head, min(1, Double(e.trainProgress) / Double(time)), queued: e.queue.count)
            }
            if let research = e.research {
                let work = max(1, catalogue.stats(research).work)
                return .researching(research, min(1, Double(e.researchProgress) / Double(work)))
            }
            return .idle
        }
        switch e.doing {
        case .idle: return .idle
        case .moving: return .moving
        case .gathering:
            if case .gather(_, let kind, _) = e.task { return .gathering(kind) }
            return .working
        case .carrying:
            if let cargo = e.cargo { return .carrying(cargo.kind.yield, cargo.amount) }
            if case .carry(let resource, _) = e.task, let goods = e.goods, goods > 0 { return .carrying(resource, goods) }
            return .moving
        case .working: return .working
        case .constructing: return .constructing
        case .fighting: return .fighting
        }
    }
}
