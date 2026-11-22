// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Where a worker is sent: a site, or a stock pen to herd at.
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
        let age = view.age, width = view.mapWidth
        // Through a buffer: this loop visits every site (see `Ground.init`). The
        // water's sites are the boats' (`sendBoats`), never the workers'.
        view.sites.withUnsafeBufferPointer { sites in
            for i in 0..<sites.count where sites[i].remaining > 0 && sites[i].kind.firstAge <= age
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

/// A complete stock pen or farm and the workers it has: a pen takes six, a
/// farm one (Iron age; farms never run out).
struct Pen {
    var building: EntityView
    var herders: Int
    var isFarm: Bool { building.kind == .building(.farm) }
    var room: Int { isFarm ? 1 : 6 }
}

extension Turn {
    /// Orders the advance once study is complete and its cost covered, and from
    /// 0.6 of the study holds the cost back from other spending.
    func advance() {
        guard let advance = catalogue.advance(from: view.age) else { return }
        // Beyond the Bronze age, an army comes first: the advance waits for the first attack's worth.
        if view.age >= .bronze && warfighters.count < tuning.attackSize { return }
        if view.ageProgress >= 1, canPay(advance.cost, urgent: true) {
            give(.advanceAge, to: [])
            pay(advance.cost)
        } else if view.ageProgress >= 0.6 {
            setAside(advance.cost)
        }
    }

    /// The town centre trains workers, engineers and scholars up to the numbers
    /// the difficulty sets. With no engineer, one comes first, so that the last
    /// free place under the population limit never goes to someone who cannot
    /// build a house.
    func trainAtTownCentre() {
        // Under attack in the Stone age, the town centre trains warfighters instead (`trainArmy`).
        let defending = Turn.warfighterKinds.reduce(warfighters.count) { $0 + training[$1.rawValue] }
        if threatened && view.age == .stone && defending < raiders + 2 { return }
        for centre in completeBuildings(.townCentre) where isFree(centre) && queueLength(centre) < tuning.queue {
            guard let kind = nextCivilian() else { return }
            let stats = catalogue.stats(kind)
            guard projectedPopulation + stats.population <= view.populationLimit else { return }
            let urgent = kind == .engineer || (kind == .worker && workers.count + training[UnitKind.worker.rawValue] < 6)
            guard canPay(stats.cost, urgent: urgent) else { return }
            train(kind, at: centre)
        }
    }

    private func nextCivilian() -> UnitKind? {
        let w = workers.count + training[UnitKind.worker.rawValue]
        let e = engineers.count + training[UnitKind.engineer.rawValue]
        let s = scholars.count + training[UnitKind.scholar.rawValue]
        if e == 0 && w >= 2 { return .engineer }
        if w < 4 { return .worker }
        let studying = catalogue.advance(from: view.age) != nil && view.ageProgress < 1
        let wanted: [(UnitKind, Int, Int)] = [
            (.worker, w, tuning.workers(at: view.age)),
            (.scholar, s, w < tuning.workersBeforeScholars ? 0 : studying ? tuning.scholars : researchable.isEmpty ? 0 : 2),
            (.engineer, e, tuning.engineers(at: view.age)),
            (.merchant, merchants.count + training[UnitKind.merchant.rawValue], wantedMerchants(workers: w)),
        ]
        var best: UnitKind?
        var bestGap = 0.0
        for (kind, have, want) in wanted where want > have {
            let gap = Double(want - have) / Double(want)
            if gap > bestGap { best = kind; bestGap = gap }
        }
        return best
    }

    /// One merchant from the Bronze age once twelve workers gather, and three
    /// whilst a resource has piled up to 3000, so that the surplus is traded
    /// for what is short.
    private func wantedMerchants(workers w: Int) -> Int {
        guard catalogue.merchants != nil, view.age >= .bronze, w >= 12 else { return 0 }
        let largest = view.shownResources.map { view.resources[$0] }.max() ?? 0
        return largest >= 3000 ? 3 : 1
    }

    // MARK: Workers

    /// Idle workers go to the nearest suitable sites, in the shares the age and
    /// the player's savings call for; copper and tin are kept in pairs.
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
        guard !idle.isEmpty || abs(on[Task.copper.rawValue] - on[Task.tin.rawValue]) >= 2 else { return }
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
        var pens = (completeBuildings(.farm) + completeBuildings(.stockPen)).map { Pen(building: $0, herders: 0) }
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
        pairMetals(on, &open)
    }

    /// What a worker is doing, as far as its activity and its last assignment show.
    private func task(of worker: EntityView) -> Task? {
        switch worker.activity {
        case .gathering(let kind):
            return Task(site: kind)
        case .working:
            return memory.assignment(of: worker.id)?.task == .crafting ? .crafting : .herding
        case .carrying(let resource, _):
            if let last = memory.assignment(of: worker.id), last.task.resource == resource { return last.task }
            switch resource {
            case .food: return .hunting
            case .wood: return .felling
            case .stone: return .quarrying
            case .gold: return .gold
            case .iron: return .iron
            default: return .copper
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
        if view.age == .stone {
            set(.food, 0.5); set(.wood, 0.35); set(.stone, 0.15)
        } else {
            set(.food, 0.34); set(.wood, 0.24); set(.stone, 0.08); set(.bronze, 0.22); set(.gold, 0.12)
            if view.age >= .iron { set(.iron, 0.1) }
            // Craftsmen turn wood into gunpowder, so the Alchemy age fells more; the castle needs stone.
            if view.age >= .alchemy { set(.wood, 0.32); set(.stone, 0.16) }
        }
        for resource in Resource.allCases where share[resource.rawValue] > 0 {
            let short = max(0, reserve[resource] - view.resources[resource])
            share[resource.rawValue] *= 1 + min(1, Double(short) / 200)
        }
        if !open.has(.prey) && completeBuildings(.stockPen).isEmpty && completeBuildings(.farm).isEmpty { set(.food, 0) }
        if !open.has(.tree) { set(.wood, 0) }
        if !open.has(.stone) { set(.stone, 0) }
        if !(open.has(.copper) && open.has(.tin)) { set(.bronze, 0) }
        if !open.has(.gold) { set(.gold, 0) }
        if !open.has(.iron) { set(.iron, 0) }
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
            let prey = nearestSite(.prey, to: worker.position, open: &open)
            if let prey, prey.tile.centre.distance(to: worker.position) <= 12 { return (.hunting, .site(prey.id)) }
            // A farm without a farmer, then the nearest pen with room.
            let farms = pens.filter { $0.isFarm && $0.herders < $0.room }.map(\.building)
            if let farm = Turn.nearest(farms, to: worker.position) { return (.herding, .pen(farm.id)) }
            let roomy = pens.filter { !$0.isFarm && $0.herders < $0.room }.map(\.building)
            if let pen = Turn.nearest(roomy, to: worker.position) { return (.herding, .pen(pen.id)) }
            if let prey { return (.hunting, .site(prey.id)) }
            return nil
        case .bronze:
            let kind: SiteKind = on[Task.copper.rawValue] <= on[Task.tin.rawValue] ? .copper : .tin
            guard let task = Task(site: kind), let site = nearestSite(kind, to: worker.position, open: &open) else {
                return nil
            }
            return (task, .site(site.id))
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

    /// Copper and tin make bronze only whilst both are mined, so a worker moves
    /// from the one to the other when they differ by two or more.
    private func pairMetals(_ on: [Int], _ open: inout OpenSites) {
        let copper = on[Task.copper.rawValue], tin = on[Task.tin.rawValue]
        guard abs(copper - tin) >= 2 else { return }
        let (from, to): (SiteKind, SiteKind) = copper > tin ? (.copper, .tin) : (.tin, .copper)
        guard let mover = workers.first(where: { isFree($0) && $0.activity == .gathering(from) }),
              let task = Task(site: to), let site = nearestSite(to, to: mover.position, open: &open) else { return }
        give(.gather(units: [mover.id], site: site.id), to: [mover.id])
        memory.assign(Assignment(worker: mover.id, task: task, site: site.id, building: nil, tick: view.tick))
    }

    /// Workers herding at a stock pen or farming, craftsmen not counted.
    var herders: Int {
        workers.filter { $0.activity == .working && memory.assignment(of: $0.id)?.task != .crafting }.count
    }

    /// Craftsmen at the first alchemist's workshop: as many as it holds whilst
    /// gunpowder is under 300 and the stock holds 100 wood or more beyond what
    /// is set aside, taken from the idle workers and then from those felling;
    /// none once gunpowder reaches 500 or wood falls under 40 beyond what is set
    /// aside, when they are stopped and go back to other work. A worker that
    /// came back idle soon after it was sent is not sent again for a while: it
    /// could not reach the workshop.
    func employCraftsmen() {
        guard let workshop = catalogue.workshop,
              let place = Turn.nearest(completeBuildings(.alchemistsWorkshop), to: base) else { return }
        let crafting = workers.filter { worker in
            guard let last = memory.assignment(of: worker.id), last.task == .crafting, last.building == place.id else { return false }
            return worker.activity == .working || worker.activity == .moving
        }
        let powder = view.resources[.gunpowder], wood = view.resources[.wood] - reserve[.wood]
        if powder >= 500 || wood < 40 {
            let stopping = crafting.filter { isFree($0) }.map(\.id)
            guard !stopping.isEmpty else { return }
            give(.stop(units: stopping), to: stopping)
            for id in stopping { memory.assign(Assignment(worker: id, task: .felling, site: nil, building: nil, tick: view.tick)) }
            return
        }
        guard powder < 300, wood >= 100, crafting.count < workshop.workers, workers.count >= 10 else { return }
        let candidates = workers.filter { worker in
            guard isFree(worker), !crafting.contains(worker) else { return false }
            if worker.activity == .idle, let last = memory.assignment(of: worker.id), last.task == .crafting,
               view.tick - last.tick < Tick.seconds(90) { return false }
            return true
        }
        let idle = candidates.filter { $0.activity == .idle }
        let felling = candidates.filter { $0.activity == .gathering(.tree) }
        var chosen: [EntityID] = []
        for pool in [idle, felling] {
            var pool = pool
            while chosen.count + crafting.count < workshop.workers, let next = Turn.nearest(pool, to: place.position) {
                pool.removeAll { $0.id == next.id }
                chosen.append(next.id)
            }
        }
        guard !chosen.isEmpty else { return }
        give(.work(units: chosen, at: place.id), to: chosen)
        for id in chosen {
            memory.assign(Assignment(worker: id, task: .crafting, site: nil, building: place.id, tick: view.tick))
        }
    }

    // MARK: Scholars and engineers

    /// Idle scholars study at the town centre.
    func employScholars() {
        guard let centre = Turn.nearest(completeBuildings(.townCentre), to: base) else { return }
        var researchers = (memory.researchers ?? []).filter { r in scholars.contains { $0.id == r.scholar } }
        var free = scholars.filter { isFree($0) && ($0.activity == .idle || $0.activity == .working) }
        // Scholars whose research is done, or whose building is gone, go back to study at the town centre.
        var back: [EntityID] = []
        researchers.removeAll { r in
            let researching: Bool = {
                guard let b = view.entity(r.building), case .researching = b.activity else { return false }
                return true
            }()
            if researching { return false }
            if free.contains(where: { $0.id == r.scholar }) { back.append(r.scholar) }
            return true
        }
        // Two scholars, counted from those sent whether still walking or at work, where research is under way.
        for building in buildings where building.id != centre.id {
            guard case .researching = building.activity else { continue }
            let there = researchers.filter { $0.building == building.id }.count
            for _ in 0..<max(0, 2 - there) {
                let candidates = free.filter { s in !researchers.contains { $0.scholar == s.id } && !back.contains(s.id) }
                guard let scholar = Turn.nearest(candidates, to: building.position) else { break }
                free.removeAll { $0.id == scholar.id }
                researchers.append(Researcher(scholar: scholar.id, building: building.id))
                give(.work(units: [scholar.id], at: building.id), to: [scholar.id])
            }
        }
        memory.researchers = researchers
        let idle = free.filter { s in s.activity == .idle && !researchers.contains { $0.scholar == s.id } }.map(\.id)
        let toCentre = Array(Set(idle + back)).sorted()
        if !toCentre.isEmpty { give(.work(units: toCentre, at: centre.id), to: toCentre) }
    }

    /// An idle merchant trades the largest surplus for the resource the player
    /// most lacks of those it is saving for (under 150, or short of what is set
    /// aside), or else of bronze, gold and iron.
    func employMerchants() {
        guard catalogue.merchants != nil, !completeBuildings(.townCentre).isEmpty else { return }
        // A trade under way stops once what it gives falls to 300 or what it takes is no longer short.
        if let trade = memory.trade {
            if view.resources[trade.give] < 300 || view.resources[trade.take] >= max(400, reserve[trade.take]) {
                let trading = merchants.filter { isFree($0) && $0.activity == .working }.map(\.id)
                if !trading.isEmpty { give(.stop(units: trading), to: trading) }
                memory.trade = nil
            }
            return
        }
        let idle = merchants.filter { isFree($0) && $0.activity == .idle }.map(\.id)
        guard !idle.isEmpty else { return }

        let shown = view.shownResources.filter { $0 != .food || view.age >= .bronze }
        guard let surplus = shown.max(by: { view.resources[$0] < view.resources[$1] }), view.resources[surplus] >= 600 else { return }
        let wanted = shown.filter { $0 != surplus && (view.resources[$0] < 150 || view.resources[$0] < reserve[$0]) }
        let short = wanted.max { (reserve[$0] - view.resources[$0]) < (reserve[$1] - view.resources[$1]) }
            ?? [Resource.iron, .gold, .bronze].first { shown.contains($0) && $0 != surplus && view.resources[$0] < 300 }
        guard let take = short else { return }
        give(.exchange(merchants: idle, give: surplus, take: take), to: idle)
        memory.trade = Trade(give: surplus, take: take)
    }

    /// The improvements the player's age offers that it lacks, at its complete
    /// buildings, cheapest first.
    var researchable: [(Improvement, EntityView)] {
        var out: [(Improvement, EntityView)] = []
        for building in buildings where Turn.isComplete(building) {
            guard case .building(let kind) = building.kind else { continue }
            for improvement in catalogue.stats(kind).researches where catalogue.stats(improvement).age <= view.age
                && !view.improvements.contains(improvement) && !out.contains(where: { $0.0 == improvement }) {
                out.append((improvement, building))
            }
        }
        func total(_ i: Improvement) -> Int { Resource.allCases.reduce(0) { $0 + catalogue.stats(i).cost[$1] } }
        return out.sorted { total($0.0) < total($1.0) || (total($0.0) == total($1.0) && $0.0.rawValue < $1.0.rawValue) }
    }

    /// Scholars research one improvement at a time, the cheapest first, whilst
    /// no attack is under way at home and it can be paid without holding back
    /// anything more urgent.
    func research() {
        guard !threatened, !scholars.isEmpty else { return }
        for building in buildings { if case .researching = building.activity { return } }
        guard let (improvement, building) = researchable.first, isFree(building),
              canPay(catalogue.stats(improvement).cost) else { return }
        give(.research(at: building.id, improvement: improvement), to: [building.id])
        pay(catalogue.stats(improvement).cost)
    }

    /// Idle engineers finish what is begun, and otherwise repair what is
    /// damaged and out of the opponents' reach.
    func employEngineers() {
        let planned = memory.plans.flatMap(\.builders)
        let unfinished = buildings.filter { !Turn.isComplete($0) }
        let damaged = buildings.filter { building in
            Turn.isComplete(building) && building.health * 10 < building.maxHealth * 7
                && !intruders.contains { $0.position.distance(to: building.position) <= 8 }
        }
        let jobs = unfinished.isEmpty ? damaged : unfinished
        var groups: [(building: EntityID, engineers: [EntityID])] = []
        for engineer in engineers where isFree(engineer) && engineer.activity == .idle && !planned.contains(engineer.id) {
            guard let job = Turn.nearest(jobs, to: engineer.position) else { break }
            if let i = groups.firstIndex(where: { $0.building == job.id }) {
                groups[i].engineers.append(engineer.id)
            } else {
                groups.append((job.id, [engineer.id]))
            }
        }
        for group in groups { give(.work(units: group.engineers, at: group.building), to: group.engineers) }
    }
}
