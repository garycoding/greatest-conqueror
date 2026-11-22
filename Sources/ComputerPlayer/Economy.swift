// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Where a worker is sent: a site, or a farm to tend.
enum Workplace: Hashable {
    case site(SiteID)
    case pen(EntityID)
}

/// The sites workers may be sent to in this action, by kind and in id order,
/// each with the workers it already has and whether it is closed: being
/// avoided, or found unreachable.
struct OpenSites {
    struct Entry {
        var site: ResourceSite
        var load = 0
        var closed = false
    }

    private(set) var byKind: [[Entry]]

    init(view: PlayerView, memory: Memory) {
        var byKind = [[Entry]](repeating: [], count: SiteKind.allCases.count)
        let width = view.mapWidth
        // Through a buffer: this loop visits every site (see `Ground.init`). The
        // water's sites are the boats' (`sendBoats`), never the workers'.
        view.sites.withUnsafeBufferPointer { sites in
            for i in 0..<sites.count where sites[i].remaining > 0
                && !view.terrain[sites[i].tile.y * width + sites[i].tile.x].isWater {
                byKind[sites[i].kind.rawValue].append(Entry(site: sites[i]))
            }
        }
        self.byKind = byKind
        for avoided in memory.avoidedSites { close(avoided.site) }
        for assignment in memory.assignments {
            guard let site = assignment.site, let kind = assignment.task.site, let i = index(of: site, kind),
                  let worker = view.entity(assignment.worker), worker.activity != .idle else { continue }
            byKind[kind.rawValue][i].load += 1
        }
    }

    /// Found by binary search: each kind's entries are in id order, as the view's sites are.
    func index(of site: SiteID, _ kind: SiteKind) -> Int? {
        let entries = byKind[kind.rawValue]
        var low = 0, high = entries.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if entries[mid].site.id == site { return mid }
            if entries[mid].site.id < site { low = mid + 1 } else { high = mid - 1 }
        }
        return nil
    }

    func has(_ kind: SiteKind) -> Bool { byKind[kind.rawValue].contains { !$0.closed } }

    func isClosed(_ site: SiteID) -> Bool {
        SiteKind.allCases.contains { kind in index(of: site, kind).map { byKind[kind.rawValue][$0].closed } ?? false }
    }

    mutating func close(_ site: SiteID) {
        for kind in SiteKind.allCases {
            if let i = index(of: site, kind) { byKind[kind.rawValue][i].closed = true }
        }
    }

    mutating func close(_ kind: SiteKind, at i: Int) { byKind[kind.rawValue][i].closed = true }

    mutating func addWorker(_ site: SiteID, _ kind: SiteKind) {
        if let i = index(of: site, kind) { byKind[kind.rawValue][i].load += 1 }
    }
}

/// A complete farm and the workers it has: a farm takes one.
struct Pen {
    var building: EntityView
    var herders: Int
    var room: Int { 1 }
}

extension Turn {
    /// Once it has the workers the difficulty sets, it holds the advance's cost
    /// back from other spending and orders the advance at its town centre when
    /// the cost is covered.
    func advance() {
        guard view.age.next != nil, let advance = catalogue.advance(from: view.age) else { return }
        // An advance under way: nothing more to do.
        if view.ageProgress > 0 || buildings.contains(where: { if case .advancing = $0.activity { true } else { false } }) {
            return
        }
        // Beyond the age of farms, an army comes first: the advance waits for the first attack's worth.
        if view.age >= .farms && warfighters.count < tuning.attackSize { return }
        guard workers.count + builders.count >= tuning.workersBeforeAdvance,
              let centre = Turn.nearest(completeBuildings(.townCentre), to: base) else { return }
        if canPay(advance.cost, urgent: true) {
            give(.advanceAge(at: centre.id), to: [])
            pay(advance.cost)
        } else {
            setAside(advance.cost)
        }
    }

    /// The town centre trains workers up to the numbers the difficulty sets,
    /// builders included.
    func trainAtTownCentre() {
        let wanted = tuning.workers(at: view.age) + tuning.builders(at: view.age)
        for centre in completeBuildings(.townCentre) where isFree(centre) && queueLength(centre) < tuning.queue {
            let have = workers.count + builders.count + training[UnitKind.worker.rawValue]
            guard have < wanted else { return }
            let stats = catalogue.stats(.worker)
            guard projectedPopulation + stats.population <= view.populationLimit else { return }
            guard canPay(stats.cost, urgent: have < 6) else { return }
            train(.worker, at: centre)
        }
    }

    // MARK: Workers

    /// Idle workers go to the nearest suitable sites, in the shares the age and
    /// the player's savings call for.
    func employWorkers() {
        var on = [Int](repeating: 0, count: Task.allCases.count)
        var idle: [EntityView] = []
        for worker in workers where isFree(worker) {
            if let task = task(of: worker) {
                on[task.rawValue] += 1
            } else if worker.activity == .idle {
                idle.append(worker)
            }
        }
        guard !idle.isEmpty else { return }
        var open = OpenSites(view: view, memory: memory)
        // A worker idle soon after it was sent to a site did not reach it: that
        // site is left alone for a while.
        for worker in idle {
            guard let last = memory.assignment(of: worker.id), let site = last.site,
                  view.tick - last.tick < Tick.seconds(8), !open.isClosed(site) else { continue }
            memory.avoidedSites.append(AvoidedSite(site: site, until: view.tick + Tick.seconds(90)))
            open.close(site)
        }
        let shares = workShares(open)
        var pens = completeBuildings(.farm).map { Pen(building: $0, herders: 0) }
        if !pens.isEmpty {
            for assignment in memory.assignments {
                guard let pen = assignment.building, let i = pens.firstIndex(where: { $0.building.id == pen }),
                      view.entity(assignment.worker)?.activity != .idle else { continue }
                pens[i].herders += 1
            }
        }
        var groups: [(place: Workplace, workers: [EntityID])] = []
        var given = 0
        for worker in idle where given < tuning.assignments {
            guard let (task, place) = work(for: worker, on: on, shares: shares, open: &open, pens: pens) else { continue }
            on[task.rawValue] += 1
            given += 1
            var assignment = Assignment(worker: worker.id, task: task, site: nil, building: nil, tick: view.tick)
            switch place {
            case .site(let id):
                assignment.site = id
                if let kind = task.site { open.addWorker(id, kind) }
            case .pen(let id):
                assignment.building = id
                if let i = pens.firstIndex(where: { $0.building.id == id }) { pens[i].herders += 1 }
            }
            memory.assign(assignment)
            if let i = groups.firstIndex(where: { $0.place == place }) {
                groups[i].workers.append(worker.id)
            } else {
                groups.append((place, [worker.id]))
            }
        }
        for group in groups {
            switch group.place {
            case .site(let id): give(.gather(units: group.workers, site: id), to: group.workers)
            case .pen(let id): give(.work(units: group.workers, at: id), to: group.workers)
            }
        }
    }

    /// What a worker is doing, as far as its activity and its last assignment show.
    private func task(of worker: EntityView) -> Task? {
        switch worker.activity {
        case .gathering(let kind):
            return Task(site: kind)
        case .working:
            return .herding
        case .carrying(let resource, _):
            if let last = memory.assignment(of: worker.id), last.task.resource == resource { return last.task }
            switch resource {
            case .food: return .hunting
            case .wood: return .felling
            case .gold: return .gold
            }
        case .moving:
            return memory.assignment(of: worker.id)?.task
        default:
            return nil
        }
    }

    /// The share of the workers each resource should have, by `Resource.rawValue`:
    /// a table by age, leaning toward what the player is saving for, and nothing
    /// for a resource it cannot gather.
    private func workShares(_ open: OpenSites) -> [Double] {
        var share = [Double](repeating: 0, count: Resource.allCases.count)
        func set(_ resource: Resource, _ value: Double) { share[resource.rawValue] = value }
        if view.age == .towns {
            set(.food, 0.5); set(.wood, 0.35); set(.gold, 0.15)
        } else {
            set(.food, 0.4); set(.wood, 0.3); set(.gold, 0.3)
            // The castle needs wood.
            if view.age >= .cannons { set(.wood, 0.35); set(.gold, 0.3); set(.food, 0.35) }
        }
        for resource in Resource.allCases where share[resource.rawValue] > 0 {
            let short = max(0, reserve[resource] - view.resources[resource])
            share[resource.rawValue] *= 1 + min(1, Double(short) / 200)
        }
        if !open.has(.prey) && !open.has(.fruit) && completeBuildings(.farm).isEmpty { set(.food, 0) }
        if !open.has(.tree) { set(.wood, 0) }
        if !open.has(.gold) { set(.gold, 0) }
        let total = share.reduce(0, +)
        return total > 0 ? share.map { $0 / total } : share
    }

    /// The work for an idle worker: the resource furthest below its share, at
    /// the nearest suitable place. A resource with no such place gives way to the next.
    private func work(for worker: EntityView, on: [Int], shares: [Double], open: inout OpenSites,
                      pens: [Pen]) -> (Task, Workplace)? {
        var have = [Int](repeating: 0, count: Resource.allCases.count)
        for task in Task.allCases { have[task.resource.rawValue] += on[task.rawValue] }
        var excluded = [Bool](repeating: false, count: Resource.allCases.count)
        let total = Double(workers.count)
        for _ in Resource.allCases {
            var best: Resource?
            var bestGap = -Double.infinity
            for resource in Resource.allCases where shares[resource.rawValue] > 0 && !excluded[resource.rawValue] {
                let gap = shares[resource.rawValue] * total - Double(have[resource.rawValue])
                if gap > bestGap { best = resource; bestGap = gap }
            }
            guard let resource = best else { return nil }
            if let found = place(for: resource, worker: worker, on: on, open: &open, pens: pens) { return found }
            excluded[resource.rawValue] = true
        }
        return nil
    }

    private func place(for resource: Resource, worker: EntityView, on: [Int], open: inout OpenSites,
                       pens: [Pen]) -> (Task, Workplace)? {
        switch resource {
        case .food:
            // Wild food first, prey or fruit bushes, whichever is nearer, as long as it lasts near by.
            let wild = [(Task.hunting, nearestSite(.prey, to: worker.position, open: &open)),
                        (Task.picking, nearestSite(.fruit, to: worker.position, open: &open))]
                .compactMap { task, site in site.map { (task: task, site: $0) } }
                .min { $0.site.tile.centre.distance(to: worker.position) < $1.site.tile.centre.distance(to: worker.position) }
            if let wild, wild.site.tile.centre.distance(to: worker.position) <= 12 { return (wild.task, .site(wild.site.id)) }
            // A farm without a farmer.
            let farms = pens.filter { $0.herders < $0.room }.map(\.building)
            if let farm = Turn.nearest(farms, to: worker.position) { return (.herding, .pen(farm.id)) }
            if let wild { return (wild.task, .site(wild.site.id)) }
            return nil
        default:
            guard let kind = SiteKind.allCases.first(where: { $0.yield == resource }), let task = Task(site: kind),
                  let site = nearestSite(kind, to: worker.position, open: &open) else { return nil }
            return (task, .site(site.id))
        }
    }

    /// The nearest open site of a kind that a worker can reach, preferring one
    /// with fewer workers already; one found unreachable is closed.
    func nearestSite(_ kind: SiteKind, to point: MapPosition, open: inout OpenSites) -> ResourceSite? {
        let crowding = kind == .tree ? 6.0 : 3.0
        let x = point.x - 0.5, y = point.y - 0.5
        for _ in 0..<8 {
            var best = -1
            var bestScore = Double.infinity
            var i = 0
            for entry in open.byKind[kind.rawValue] {
                if !entry.closed {
                    let dx = Double(entry.site.tile.x) - x, dy = Double(entry.site.tile.y) - y
                    let score = (dx * dx + dy * dy).squareRoot() + crowding * Double(entry.load)
                    if score < bestScore { best = i; bestScore = score }
                }
                i += 1
            }
            guard best >= 0 else { return nil }
            let site = open.byKind[kind.rawValue][best].site
            if !site.kind.blocksTile || isReachable(site) { return site }
            open.close(kind, at: best)
        }
        return nil
    }

    /// Whether a person can stand beside a site that blocks its own tile.
    private func isReachable(_ site: ResourceSite) -> Bool {
        prepareGround()
        let t = site.tile
        for next in [GridPoint(t.x + 1, t.y), GridPoint(t.x - 1, t.y), GridPoint(t.x, t.y + 1), GridPoint(t.x, t.y - 1)] {
            if ground?.canStand(next, in: view) == true { return true }
        }
        return false
    }

    /// Workers farming, builders among them: a builder that finishes a farm tends it.
    var herders: Int { (workers + builders).filter { $0.job == .working(.farm) || ($0.job == nil && $0.activity == .working) }.count }

    /// Idle builders finish what is begun, and otherwise repair what is
    /// damaged and out of the opponents' reach.
    func employBuilders() {
        let planned = memory.plans.flatMap(\.builders)
        let unfinished = buildings.filter { !Turn.isComplete($0) }
        let damaged = buildings.filter { building in
            Turn.isComplete(building) && building.health * 10 < building.maxHealth * 7
                && !intruders.contains { $0.position.distance(to: building.position) <= 8 }
        }
        let jobs = unfinished.isEmpty ? damaged : unfinished
        var groups: [(building: EntityID, builders: [EntityID])] = []
        for builder in builders where isFree(builder) && builder.activity == .idle && !planned.contains(builder.id) {
            guard let job = Turn.nearest(jobs, to: builder.position) else { break }
            if let i = groups.firstIndex(where: { $0.building == job.id }) {
                groups[i].builders.append(builder.id)
            } else {
                groups.append((job.id, [builder.id]))
            }
        }
        for group in groups { give(.work(units: group.builders, at: group.building), to: group.builders) }
    }
}
