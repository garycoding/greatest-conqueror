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
    /// Once the difficulty's time for the age has come, it has the workers the
    /// difficulty sets and, beyond the age of towns, the army, and it has made
    /// the best tier of each kind of warfighter the age allows at its makers
    /// (`madeTheAgesTiers`), it holds the advance's cost back from other
    /// spending and orders the advance at its town centre when the cost is covered.
    func advance() {
        guard view.age.next != nil, let advance = catalogue.advance(from: view.age) else { return }
        // An advance under way: nothing more to do.
        if view.ageProgress > 0 || buildings.contains(where: { if case .advancing = $0.activity { true } else { false } }) {
            return
        }
        guard view.tick >= tuning.advanceAt(view.age) else { return }
        if view.age >= .farms && armySize < tuning.armyBeforeAdvance(view.age) { return }
        guard workers.count + builders.count >= tuning.workersBeforeAdvance, madeTheAgesTiers(),
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
        let shares = workShares(open)
        // A worker idle soon after it was sent to a site did not reach it: that
        // site is left alone for a while.
        for worker in idle {
            guard let last = memory.assignment(of: worker.id), let site = last.site,
                  view.tick - last.tick < Tick.seconds(8), !open.isClosed(site) else { continue }
            memory.avoidedSites.append(AvoidedSite(site: site, until: view.tick + Tick.seconds(90)))
            open.close(site)
        }
        let pens = farms()
        send(idle, limit: tuning.assignments, on: &on, shares: shares, open: &open, pens: pens)
        prospect(open)
    }

    /// When the plan lacks a resource of which it knows no site on its land,
    /// someone goes to look at the nearest ground not yet explored: the sites
    /// the view shows are those on explored ground.
    func prospect(_ open: OpenSites) {
        let plan = demand()
        let lacking = Resource.allCases.filter { plan[$0] > view.resources[$0] }
        let unknown = lacking.contains { resource in
            switch resource {
            case .food: return !open.has(.prey) && !open.has(.fruit) && completeBuildings(.farm).isEmpty
            case .wood: return !open.has(.tree)
            case .gold: return !open.has(.gold)
            }
        }
        guard unknown, let place = frontier(from: base) else { return }
        lookAt(place)
    }

    /// The complete farms, each with its farmer: a worker farming on it (a
    /// builder that finished a farm tends it), or one sent to it and on its way.
    private func farms() -> [Pen] {
        var pens = completeBuildings(.farm).map { farm in
            Pen(building: farm, herders: memory.tendedFarms.contains { $0.id == farm.id } ? 1 : 0)
        }
        guard !pens.isEmpty else { return pens }
        for worker in workers + builders where worker.job == .working(.farm) || (worker.job == nil && worker.activity == .working) {
            // The view does not say which farm: the nearest without a farmer, beside it.
            let size = catalogue.stats(.farm).footprint
            let beside = pens.indices.filter { i in
                let o = pens[i].building.tile, t = worker.tile
                return t.x >= o.x - 1 && t.y >= o.y - 1 && t.x <= o.x + size.x && t.y <= o.y + size.y
            }
            let free = beside.filter { pens[$0].herders == 0 }
            let pick = (free.isEmpty ? beside : free).min {
                pens[$0].building.position.distance(to: worker.position) < pens[$1].building.position.distance(to: worker.position)
            }
            if let i = pick { pens[i].herders += 1 }
        }
        for assignment in memory.assignments {
            guard let pen = assignment.building, let i = pens.firstIndex(where: { $0.building.id == pen }),
                  view.entity(assignment.worker)?.activity == .moving else { continue }
            pens[i].herders += 1
        }
        return pens
    }

    /// Sends up to `limit` of `workers` to the work each is wanted for, in groups by place.
    private func send(_ workers: [EntityView], limit: Int, on: inout [Int], shares: [Double], open: inout OpenSites,
                      pens initial: [Pen], only resource: Resource? = nil) {
        var pens = initial
        var groups: [(place: Workplace, workers: [EntityID])] = []
        var given = 0
        for worker in workers where given < limit {
            let found = resource.map { place(for: $0, worker: worker, on: on, open: &open, pens: pens) }
                ?? work(for: worker, on: on, shares: shares, open: &open, pens: pens)
            guard let (task, place) = found else { continue }
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
            case .pen(let id):
                give(.work(units: group.workers, at: id), to: group.workers)
                memory.farmOrders.append(id)
            }
        }
    }

    /// What a worker is doing, as far as its activity and its last assignment show.
    func task(of worker: EntityView) -> Task? {
        switch worker.activity {
        case .gathering(let kind):
            return Task(site: kind)
        case .working:
            return .herding
        case .moving:
            return memory.assignment(of: worker.id)?.task
        default:
            return nil
        }
    }

    /// Moves busy workers from the resource furthest above its share to the one
    /// furthest below, when each is two workers or more from its share: up to
    /// `Tuning.moves` in one action, at most every ten seconds, and only
    /// workers that have been at their work half a minute.
    func rebalanceWorkers() {
        guard workers.count >= 6 else { return }
        if let last = memory.lastMove, view.tick >= last, view.tick - last < Tick.seconds(10) { return }
        var on = [Int](repeating: 0, count: Task.allCases.count)
        for worker in workers { if let task = task(of: worker) { on[task.rawValue] += 1 } }
        var open = OpenSites(view: view, memory: memory)
        let shares = workShares(open)
        var have = [Double](repeating: 0, count: Resource.allCases.count)
        for task in Task.allCases { have[task.resource.rawValue] += Double(on[task.rawValue]) }
        let total = Double(workers.count)
        let gaps = Resource.allCases.map { shares[$0.rawValue] * total - have[$0.rawValue] }
        guard let short = Resource.allCases.max(by: { gaps[$0.rawValue] < gaps[$1.rawValue] }),
              let over = Resource.allCases.min(by: { gaps[$0.rawValue] < gaps[$1.rawValue] }),
              gaps[short.rawValue] >= 2, gaps[over.rawValue] <= -2 else { return }
        let movable = workers.filter { worker in
            guard isFree(worker), let task = task(of: worker), task.resource == over,
                  worker.activity == .working || { if case .gathering = worker.activity { true } else { false } }()
            else { return false }
            return memory.assignment(of: worker.id).map { view.tick - $0.tick >= Tick.seconds(30) } ?? true
        }
        let count = min(tuning.moves, Int(min(gaps[short.rawValue], -gaps[over.rawValue]) / 2))
        guard count > 0, !movable.isEmpty else { return }
        memory.lastMove = view.tick
        send(movable, limit: count, on: &on, shares: shares, open: &open, pens: farms(), only: short)
    }

    /// The share of the workers each resource should have, by `Resource.rawValue`:
    /// what the player's plan for the coming age still lacks of each
    /// (`demand`), with a tenth of the whole plan's cost besides so that no
    /// resource is left untended, each divided by the rate at which a worker
    /// gathers it, so that the shares are of workers; nothing for a resource it
    /// cannot gather.
    func workShares(_ open: OpenSites) -> [Double] {
        let plan = demand()
        let worker = catalogue.stats(.worker)
        var share = [Double](repeating: 0, count: Resource.allCases.count)
        for resource in Resource.allCases {
            let lacking = max(0, plan[resource] - view.resources[resource])
            let rate = resource == .food ? max(worker.gathers(.food), worker.farming) : worker.gathers(resource)
            share[resource.rawValue] = (Double(lacking) + 0.1 * Double(plan[resource]) + 10) / max(0.05, rate)
        }
        if !open.has(.prey) && !open.has(.fruit) && completeBuildings(.farm).isEmpty { share[Resource.food.rawValue] = 0 }
        if !open.has(.tree) { share[Resource.wood.rawValue] = 0 }
        if !open.has(.gold) { share[Resource.gold.rawValue] = 0 }
        let total = share.reduce(0, +)
        return total > 0 ? share.map { $0 / total } : share
    }

    /// What the player's plan for the coming age costs, read from the tables:
    /// the advance to the next age (`ages.csv`), the buildings it still wants
    /// (`wanted`), the workers, warfighters, doctors and navy ships it still
    /// means to make, and what it holds back.
    func demand() -> ResourceAmounts {
        if let cached = planned { return cached }
        var plan = reserve
        if view.age.next != nil, let advance = catalogue.advance(from: view.age) { plan = plan + advance.cost }
        for (kind, _, _) in wanted() { plan = plan + catalogue.stats(kind).cost }
        let workersShort = tuning.workers(at: view.age) + tuning.builders(at: view.age) - workers.count - builders.count
        if workersShort > 0 { plan = plan + catalogue.stats(.worker).cost.share(Double(min(workersShort, 10))) }
        // The army: up to ten more of the best tiers it can make in this age, or in the next if it can make none yet.
        let kinds = bestTiers(at: view.age).isEmpty ? (view.age.next.map { bestTiers(at: $0) } ?? []) : bestTiers(at: view.age)
        let armyShort = min(10, max(0, tuning.armyCap(at: view.age) - armySize))
        if !kinds.isEmpty && armyShort > 0 {
            var each = ResourceAmounts()
            for kind in kinds { each = each + catalogue.stats(kind).cost }
            for resource in Resource.allCases { each[resource] = each[resource] * armyShort / kinds.count }
            plan = plan + each
        }
        if doctorsWanted > doctors.count { plan = plan + catalogue.stats(.doctor).cost.share(Double(doctorsWanted - doctors.count)) }
        if navyWanted > navy.count { plan = plan + catalogue.stats(.navyShip).cost.share(Double(navyWanted - navy.count)) }
        planned = plan
        return plan
    }

    /// The work for an idle worker: the resource furthest below its share, at
    /// the nearest suitable place. A resource with no such place gives way to the next.
    func work(for worker: EntityView, on: [Int], shares: [Double], open: inout OpenSites,
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

    func place(for resource: Resource, worker: EntityView, on: [Int], open: inout OpenSites,
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
        // A builder idle soon after it was sent to a building did not reach it:
        // that building is left alone for a while.
        for errand in memory.errands where view.tick - errand.tick < Tick.seconds(8) && view.tick > errand.tick {
            guard view.entity(errand.builder)?.activity == .idle,
                  !memory.unreachable.contains(where: { $0.id == errand.building }) else { continue }
            memory.unreachable.append(Avoided(id: errand.building, until: view.tick + Tick.seconds(90)))
        }
        let open = { (building: EntityView) in !self.memory.unreachable.contains { $0.id == building.id } }
        let jobs = (unfinished.filter(open).isEmpty ? damaged : unfinished).filter(open)
        var groups: [(building: EntityID, builders: [EntityID])] = []
        for builder in builders where isFree(builder) && builder.activity == .idle && !planned.contains(builder.id) {
            guard let job = Turn.nearest(jobs, to: builder.position) else { break }
            if let i = groups.firstIndex(where: { $0.building == job.id }) {
                groups[i].builders.append(builder.id)
            } else {
                groups.append((job.id, [builder.id]))
            }
        }
        for group in groups {
            give(.work(units: group.builders, at: group.building), to: group.builders)
            for builder in group.builders {
                memory.errands.removeAll { $0.builder == builder }
                memory.errands.append(Errand(builder: builder, building: group.building, tick: view.tick))
            }
        }
    }
}
