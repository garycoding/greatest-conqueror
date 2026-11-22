// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The work a worker is given: a kind of site, or farming at a farm. Fruit
/// gathering is last, so that the others keep their raw values.
enum Task: Int, Codable, Sendable, CaseIterable {
    case hunting, felling, gold, herding, picking

    init?(site kind: SiteKind) {
        switch kind {
        case .prey: self = .hunting
        case .tree: self = .felling
        case .gold: self = .gold
        case .fruit: self = .picking
        case .fish: return nil
        }
    }

    /// The kind of site worked; farming works at a building instead.
    var site: SiteKind? {
        switch self {
        case .hunting: .prey
        case .felling: .tree
        case .gold: .gold
        case .picking: .fruit
        case .herding: nil
        }
    }

    var resource: Resource { site?.yield ?? .food }
}

/// An opponent's building the player has seen, remembered after it passes out of sight.
struct KnownBuilding: Codable, Sendable, Hashable {
    var id: EntityID
    var owner: PlayerID
    var kind: BuildingKind
    var position: MapPosition
}

/// A building the player has ordered and has not yet seen begun.
struct Plan: Codable, Sendable, Hashable {
    var kind: BuildingKind
    var origin: GridPoint
    var builders: [EntityID]
    var tick: Int
    /// What the building costs, held back from spending until it is begun.
    var cost: ResourceAmounts
}

/// What a worker was last sent to do.
struct Assignment: Codable, Sendable, Hashable {
    var worker: EntityID
    var task: Task
    var site: SiteID?
    /// The farm, for farming.
    var building: EntityID?
    var tick: Int
}

/// Where one of the player's people or buildings was struck.
struct Strike: Codable, Sendable, Hashable {
    var position: MapPosition
    var tick: Int
}

/// A site a worker was sent to and did not reach.
struct AvoidedSite: Codable, Sendable, Hashable {
    var site: SiteID
    var until: Int
}

/// A place where a building was refused.
struct RefusedSite: Codable, Sendable, Hashable {
    var kind: BuildingKind
    var origin: GridPoint
    var until: Int
}

/// The unit exploring, and where it was sent.
struct Scouting: Codable, Sendable, Hashable {
    var unit: EntityID
    var destination: MapPosition
    var tick: Int
}

/// An attack under way: what it is aimed at and how it was last ordered.
struct Campaign: Codable, Sendable, Hashable {
    enum Stance: Int, Codable, Sendable { case marching, attacking, engaging }

    /// The opponent's building attacked, or `nil` whilst the army explores to find one.
    var target: EntityID?
    var destination: MapPosition
    /// Warfighters at the start; the army withdraws when fewer than a third remain.
    var size: Int
    var launched: Int
    var stance: Stance
    /// The tick at which the army was last sent to `destination` with no
    /// target, hunting; nil before it hunts.
    var aimed: Int?
}

/// What the computer player keeps from one view to the next. Every collection
/// is an array in a fixed order, never a dictionary or a set, so that the
/// player encodes in the same way in every process (docs/architecture.md,
/// "Determinism").
struct Memory: Codable, Sendable, Hashable {
    /// The tick of the last action.
    var lastAction: Int?
    /// Opponents' buildings seen, kept whilst their ground is out of sight; ordered by id.
    var enemies: [KnownBuilding] = []
    /// Where its people or buildings were struck, most recent last.
    var strikes: [Strike] = []
    /// Buildings ordered and not yet seen begun.
    var plans: [Plan] = []
    /// What each worker was last sent to do; ordered by worker.
    var assignments: [Assignment] = []
    var avoidedSites: [AvoidedSite] = []
    var refusedSites: [RefusedSite] = []
    var campaign: Campaign?
    /// Attacks ended so far; each makes the next wait for a larger army.
    var waves = 0
    /// Warfighters the next attack waits for beyond the rule, drawn at random after each attack.
    var extra = 0
    var scout: Scouting?
    /// Destinations already given to scouts, most recent last.
    var scouted: [MapPosition] = []
    /// A fading count of the opponents' warfighters seen, by `UnitKind.rawValue`.
    var seen: [Double] = Array(repeating: 0, count: UnitKind.allCases.count)
    /// Where opponents' people were last seen, newest last, for an army hunting
    /// the last of them.
    var lastSeenPeople: [MapPosition]?

    /// Takes in a view: its events, the opponents' buildings in sight, and what
    /// has become of the player's plans, assignments and scout.
    mutating func observe(_ view: PlayerView) {
        guard let me = view.me else { return }
        let tick = view.tick
        for event in view.events {
            switch event {
            case .underAttack(let id):
                if let struck = view.entity(id), struck.owner == view.player {
                    strikes.append(Strike(position: struck.position, tick: tick))
                }
            case .destroyed(let id):
                enemies.removeAll { $0.id == id }
                if campaign?.target == id { campaign?.target = nil }
            case .refused(let refusal):
                refused(refusal, at: tick)
            default:
                break
            }
        }
        strikes.removeAll { tick - $0.tick > Tick.seconds(20) }
        if strikes.count > 8 { strikes.removeFirst(strikes.count - 8) }

        func isOpponent(_ owner: PlayerID) -> Bool {
            guard owner != view.player, let summary = view.players.first(where: { $0.id == owner }) else { return false }
            return summary.team != me.team && !summary.isDefeated
        }
        var inSight: [KnownBuilding] = []
        // Through a buffer: this loop visits every entity, every time the player is asked.
        view.entities.withUnsafeBufferPointer { entities in
            for i in 0..<entities.count {
                if case .building(let kind) = entities[i].kind, isOpponent(entities[i].owner) {
                    inSight.append(KnownBuilding(id: entities[i].id, owner: entities[i].owner, kind: kind,
                                                 position: entities[i].position))
                }
            }
        }
        // A remembered building is forgotten once its ground is in sight without it.
        let outOfSight = enemies.filter { known in
            isOpponent(known.owner) && view.entity(known.id) == nil && !Memory.isVisible(known.position.tile, in: view)
        }
        enemies = Memory.merged(inSight, outOfSight)

        plans.removeAll { plan in
            if tick - plan.tick > Tick.seconds(60) { return true }
            let begun = view.entities.contains {
                $0.owner == view.player && $0.kind == .building(plan.kind) && $0.tile == plan.origin
            }
            if begun { return true }
            let builders = plan.builders.compactMap { view.entity($0) }.filter { $0.owner == view.player }
            return builders.isEmpty || (tick - plan.tick >= Tick.seconds(3) && builders.allSatisfy { $0.activity == .idle })
        }
        assignments.removeAll { view.entity($0.worker)?.owner != view.player }
        avoidedSites.removeAll { $0.until <= tick }
        refusedSites.removeAll { $0.until <= tick }
        if let scout, view.entity(scout.unit)?.owner != view.player { self.scout = nil }
        if seen.count != UnitKind.allCases.count { seen = Array(repeating: 0, count: UnitKind.allCases.count) }
    }

    /// A refusal arrives in the view after the order; the orders of the last
    /// action are the ones it concerns. A refused place is avoided for a while.
    private mutating func refused(_ refusal: OrderRefusal, at tick: Int) {
        guard let last = lastAction else { return }
        switch refusal {
        case .placementBlocked:
            for plan in plans where plan.tick == last {
                refusedSites.append(RefusedSite(kind: plan.kind, origin: plan.origin, until: tick + Tick.seconds(120)))
            }
            plans.removeAll { $0.tick == last }
        case .notEnough(let short):
            plans.removeAll { plan in
                plan.tick == last && Resource.allCases.contains { short[$0] > 0 && plan.cost[$0] > 0 }
            }
        default:
            break
        }
    }

    func assignment(of worker: EntityID) -> Assignment? {
        let i = index(of: worker)
        return i < assignments.count && assignments[i].worker == worker ? assignments[i] : nil
    }

    mutating func assign(_ assignment: Assignment) {
        let i = index(of: assignment.worker)
        if i < assignments.count && assignments[i].worker == assignment.worker {
            assignments[i] = assignment
        } else {
            assignments.insert(assignment, at: i)
        }
    }

    /// The first index whose worker is not below `worker`.
    private func index(of worker: EntityID) -> Int {
        var low = 0, high = assignments.count
        while low < high {
            let mid = (low + high) / 2
            if assignments[mid].worker < worker { low = mid + 1 } else { high = mid }
        }
        return low
    }

    static func isVisible(_ tile: GridPoint, in view: PlayerView) -> Bool {
        tile.x >= 0 && tile.y >= 0 && tile.x < view.mapWidth && tile.y < view.mapHeight
            && view.visibility(at: tile) == .visible
    }

    /// Two lists ordered by id, merged into one.
    static func merged(_ a: [KnownBuilding], _ b: [KnownBuilding]) -> [KnownBuilding] {
        var out: [KnownBuilding] = []
        out.reserveCapacity(a.count + b.count)
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if j == b.count || (i < a.count && a[i].id < b[j].id) {
                out.append(a[i]); i += 1
            } else {
                out.append(b[j]); j += 1
            }
        }
        return out
    }
}
