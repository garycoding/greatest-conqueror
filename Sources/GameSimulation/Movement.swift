// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Where a person is going: within `reach` of a rectangle of the map, which is
/// a point when it has no extent.
struct Goal {
    var minX: Double, minY: Double, maxX: Double, maxY: Double
    var reach: Double
    /// A tile the search accepts whatever the reach: the tile of a point.
    var exactTile: GridPoint
    /// A target that may move: a person.
    var moving: Bool
    /// Tiles the straight way to the goal may cross: the target's own footprint or site.
    var ownTiles: (origin: GridPoint, size: GridPoint)?
    /// The tile whose change means the target has moved.
    var anchor: GridPoint

    static func point(_ p: MapPosition, reach: Double, moving: Bool = false) -> Goal {
        Goal(minX: p.x, minY: p.y, maxX: p.x, maxY: p.y, reach: reach, exactTile: p.tile, moving: moving,
             ownTiles: nil, anchor: p.tile)
    }

    static func tiles(_ origin: GridPoint, _ size: GridPoint, reach: Double) -> Goal {
        Goal(minX: Double(origin.x), minY: Double(origin.y), maxX: Double(origin.x + size.x),
             maxY: Double(origin.y + size.y), reach: reach, exactTile: GridPoint(-1, -1), moving: false,
             ownTiles: (origin, size), anchor: origin)
    }

    @inline(__always) func distance(to p: MapPosition) -> Double {
        let dx = max(minX - p.x, 0, p.x - maxX), dy = max(minY - p.y, 0, p.y - maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    @inline(__always) func nearestPoint(to p: MapPosition) -> MapPosition {
        MapPosition(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
    }

    /// Whether a search may end on this open tile.
    @inline(__always) func accepts(_ x: Int, _ y: Int) -> Bool {
        if x == exactTile.x && y == exactTile.y { return true }
        return reach >= 0.5 && distance(to: MapPosition(x: Double(x) + 0.5, y: Double(y) + 0.5)) <= reach
    }

    /// A lower bound on the cost of the way from a tile (10 a tile straight, 14 diagonally).
    @inline(__always) func heuristic(_ x: Int, _ y: Int) -> Int {
        let cx = Double(x) + 0.5, cy = Double(y) + 0.5
        let gx = max(0, max(minX - cx, 0, cx - maxX) - reach), gy = max(0, max(minY - cy, 0, cy - maxY) - reach)
        return Int(10 * max(gx, gy) + 4 * min(gx, gy))
    }

    func covers(_ x: Int, _ y: Int) -> Bool {
        guard let own = ownTiles else { return false }
        return x >= own.origin.x && y >= own.origin.y && x < own.origin.x + own.size.x && y < own.origin.y + own.size.y
    }
}

enum Approach { case arrived, moving, unreachable }

/// Buffers for path searches, reused from one search to the next: a value is
/// current only where its generation is the search's.
struct PathSearch: Sendable {
    var cost: [Int32]
    var parent: [Int32]
    var opened: [UInt32]
    var closed: [UInt32]
    var generation: UInt32 = 0
    var heap: [UInt64] = []

    init(count: Int = 0) {
        cost = Array(repeating: 0, count: count)
        parent = Array(repeating: -1, count: count)
        opened = Array(repeating: 0, count: count)
        closed = Array(repeating: 0, count: count)
    }

    mutating func begin() {
        generation &+= 1
        if generation == 0 {
            for k in opened.indices { opened[k] = 0; closed[k] = 0 }
            generation = 1
        }
        heap.removeAll(keepingCapacity: true)
    }

    /// Keys order by estimated total, then by the estimate alone, then by tile.
    @inline(__always) static func key(total: Int, estimate: Int, node: Int) -> UInt64 {
        (UInt64(min(total, 0x3F_FFFF)) << 42) | (UInt64(min(estimate, 0x1F_FFFF)) << 21) | UInt64(node)
    }

    mutating func push(_ key: UInt64) {
        heap.append(key)
        var i = heap.count - 1
        while i > 0 {
            let up = (i - 1) / 2
            if heap[up] <= key { break }
            heap[i] = heap[up]
            i = up
        }
        heap[i] = key
    }

    mutating func pop() -> UInt64? {
        guard let top = heap.first else { return nil }
        let last = heap.removeLast()
        if heap.isEmpty { return top }
        var i = 0
        let n = heap.count
        while true {
            let l = 2 * i + 1
            if l >= n { break }
            let r = l + 1
            let c = r < n && heap[r] < heap[l] ? r : l
            if heap[c] >= last { break }
            heap[i] = heap[c]
            i = c
        }
        heap[i] = last
        return top
    }
}

/// The living people by cell of the map, rebuilt each tick, for finding the
/// opponents near a point without looking at everyone.
struct Buckets: Sendable {
    var columns = 0
    var rows = 0
    /// `start[c] ..< start[c + 1]` are cell c's entries in `items`.
    var start: [Int32] = []
    /// Indices into `entities`, in index order within a cell.
    var items: [Int32] = []
    private var cellOf: [Int32] = []

    mutating func rebuild(entities: [Entity], width: Int, height: Int) {
        let size = Rule.bucketSize
        columns = (width + size - 1) / size
        rows = (height + size - 1) / size
        let cells = columns * rows
        if start.count != cells + 1 { start = Array(repeating: 0, count: cells + 1) } else { for k in start.indices { start[k] = 0 } }
        if cellOf.count < entities.count { cellOf = Array(repeating: -1, count: entities.count) }
        var people = 0
        for i in entities.indices {
            let e = entities[i]
            guard e.alive, e.isPerson else { cellOf[i] = -1; continue }
            let cx = min(max(Int(e.position.x) / size, 0), columns - 1), cy = min(max(Int(e.position.y) / size, 0), rows - 1)
            let c = cy * columns + cx
            cellOf[i] = Int32(c)
            start[c + 1] += 1
            people += 1
        }
        for c in 0..<cells { start[c + 1] += start[c] }
        if items.count != people { items = Array(repeating: 0, count: people) }
        var fill = Array(start.dropLast())
        for i in entities.indices where cellOf[i] >= 0 {
            let c = Int(cellOf[i])
            items[Int(fill[c])] = Int32(i)
            fill[c] += 1
        }
    }

    /// The cells overlapping a rectangle of the map.
    func cells(minX: Double, minY: Double, maxX: Double, maxY: Double) -> (x0: Int, y0: Int, x1: Int, y1: Int) {
        let size = Double(Rule.bucketSize)
        let x0 = max(0, Int((minX / size).rounded(.down))), y0 = max(0, Int((minY / size).rounded(.down)))
        let x1 = min(columns - 1, Int((maxX / size).rounded(.down))), y1 = min(rows - 1, Int((maxY / size).rounded(.down)))
        return (x0, y0, x1, y1)
    }
}

private struct Step { var dx: Int, dy: Int, cost: Int32 }
private let steps: [Step] = [
    Step(dx: 1, dy: 0, cost: 10), Step(dx: -1, dy: 0, cost: 10), Step(dx: 0, dy: 1, cost: 10), Step(dx: 0, dy: -1, cost: 10),
    Step(dx: 1, dy: 1, cost: 14), Step(dx: 1, dy: -1, cost: 14), Step(dx: -1, dy: 1, cost: 14), Step(dx: -1, dy: -1, cost: 14),
]

extension Simulation {
    /// Move a person one tick toward a goal. People do not block one another;
    /// only `Placement`'s blocked tiles do.
    mutating func approach(_ i: Int, _ goal: Goal) -> Approach { walk(i, goal) }

    /// The way on foot toward a goal.
    mutating func walk(_ i: Int, _ goal: Goal) -> Approach {
        let position = entities[i].position
        if goal.distance(to: position) <= goal.reach {
            if entities[i].route.planned { entities[i].route = Route() }
            return .arrived
        }
        if entities[i].route.planned && goal.anchor != entities[i].route.plannedFor {
            // A fixed goal that changed is planned afresh. A moving one is followed
            // straight, or re-planned now and then as it changes tile; a re-plan
            // takes only the first half of the tick's searches, so that people who
            // have no route at all are served first, and without one the old
            // route is kept.
            if !goal.moving {
                entities[i].route.planned = false
            } else if !entities[i].route.direct && tick - entities[i].route.plannedAt >= Rule.replanInterval {
                _ = plan(i, goal, keepingRoute: true)
            }
        }
        if !entities[i].route.planned {
            guard plan(i, goal, keepingRoute: false) else { return .moving }
        }
        let target: MapPosition
        if let next = entities[i].route.waypoints.last {
            target = next.centre
        } else if entities[i].route.direct {
            target = goal.nearestPoint(to: position)
        } else if entities[i].route.partial {
            return .unreachable
        } else {
            entities[i].route.direct = true
            target = goal.nearestPoint(to: position)
        }
        return advance(i, toward: target)
    }

    /// Plan a route: straight if the way is clear, else by search. When the
    /// searches this tick allows are used up, a person with a route keeps it and
    /// one without waits; returns whether the person has a route.
    mutating func plan(_ i: Int, _ goal: Goal, keepingRoute: Bool) -> Bool {
        let from = entities[i].position
        var route = Route()
        route.planned = true
        route.plannedFor = goal.anchor
        route.plannedAt = tick
        route.stuck = entities[i].route.stuck
        let afloat = entities[i].isBoat
        if !entities[i].route.forceSearch && clearWay(from, goal.nearestPoint(to: from), goal: goal, afloat: afloat) {
            route.direct = true
            entities[i].route = route
            return true
        }
        guard searchesLeft > (keepingRoute ? searchBudget / 2 : 0) else { return keepingRoute }
        searchesLeft -= 1
        let (tiles, complete) = findPath(from: from.tile, to: goal, afloat: afloat)
        route.waypoints = smoothed(from: from, tiles, afloat: afloat).reversed()
        route.partial = !complete
        entities[i].route = route
        return true
    }

    /// One tick's walk toward a point, refused where it would cross a blocked tile.
    mutating func advance(_ i: Int, toward target: MapPosition) -> Approach {
        let from = entities[i].position
        let speed = tables.speedPerTick[entities[i].unitKind?.rawValue ?? 0]
        let dx = target.x - from.x, dy = target.y - from.y
        let d = (dx * dx + dy * dy).squareRoot()
        let reached = d <= speed
        let to = reached ? target : MapPosition(x: from.x + dx * speed / d, y: from.y + dy * speed / d)
        guard clearWay(from, to, goal: nil, afloat: entities[i].isBoat) else {
            entities[i].route.planned = false
            entities[i].route.forceSearch = true
            entities[i].route.stuck += 1
            return entities[i].route.stuck > Rule.stuckLimit ? .unreachable : .moving
        }
        entities[i].route.stuck = 0
        entities[i].position = to
        if reached && !entities[i].route.waypoints.isEmpty { entities[i].route.waypoints.removeLast() }
        face(i, dx: dx, dy: dy)
        if to.tile != entities[i].stamp { restamp(i) }
        return .moving
    }

    /// Face the way a movement or a blow goes on the screen, in eight directions (`Facing.of`).
    mutating func face(_ i: Int, dx: Double, dy: Double) {
        if let facing = Facing.of(dx: dx, dy: dy) { entities[i].facing = facing }
    }

    /// Whether a straight way between two points crosses only open tiles (and the
    /// goal's own tiles). Where it passes exactly through a corner, both tiles
    /// beside the corner must be open, so that nothing slips between two blocked
    /// tiles that touch at a corner. The starting tile is not checked.
    func clearWay(_ a: MapPosition, _ b: MapPosition, goal: Goal?, afloat: Bool = false) -> Bool {
        var x = Int(a.x.rounded(.down)), y = Int(a.y.rounded(.down))
        let dx = b.x - a.x, dy = b.y - a.y
        let stepX = dx > 0 ? 1 : (dx < 0 ? -1 : 0), stepY = dy > 0 ? 1 : (dy < 0 ? -1 : 0)
        let deltaX = stepX != 0 ? abs(1 / dx) : Double.infinity
        let deltaY = stepY != 0 ? abs(1 / dy) : Double.infinity
        var nextX = stepX > 0 ? (Double(x + 1) - a.x) / dx : (stepX < 0 ? (Double(x) - a.x) / dx : Double.infinity)
        var nextY = stepY > 0 ? (Double(y + 1) - a.y) / dy : (stepY < 0 ? (Double(y) - a.y) / dy : Double.infinity)
        func passable(_ x: Int, _ y: Int) -> Bool { open(x, y, afloat: afloat) || (goal?.covers(x, y) ?? false) }
        while true {
            let t = min(nextX, nextY)
            if t > 1 { return true }
            if abs(nextX - nextY) < 1e-12 {
                if !passable(x + stepX, y) || !passable(x, y + stepY) { return false }
                x += stepX; y += stepY
                nextX += deltaX; nextY += deltaY
            } else if nextX < nextY {
                x += stepX
                nextX += deltaX
            } else {
                y += stepY
                nextY += deltaY
            }
            if !passable(x, y) { return false }
        }
    }

    /// A* over tiles, eight ways, never cutting a blocked corner. Returns the tiles
    /// after the start to the first tile the goal accepts, or, when the goal
    /// cannot be reached, to the tile nearest it.
    mutating func findPath(from start: GridPoint, to goal: Goal, afloat: Bool = false) -> (tiles: [GridPoint], complete: Bool) {
        guard inMap(start) else { return ([], false) }
        search.begin()
        let generation = search.generation
        let w = width
        let s = start.y * w + start.x
        search.cost[s] = 0
        search.parent[s] = -1
        search.opened[s] = generation
        let h0 = goal.heuristic(start.x, start.y)
        search.push(PathSearch.key(total: h0, estimate: h0, node: s))
        var best = s, bestEstimate = h0
        var found = -1
        var expanded = 0
        let limit = min(width * height, Rule.searchLimit)
        while let top = search.pop() {
            let n = Int(top & 0x1F_FFFF)
            if search.closed[n] == generation { continue }
            search.closed[n] = generation
            let x = n % w, y = n / w
            if goal.accepts(x, y) && (n == s || open(x, y, afloat: afloat)) { found = n; break }
            let estimate = goal.heuristic(x, y)
            if estimate < bestEstimate || (estimate == bestEstimate && search.cost[n] < search.cost[best]) {
                best = n
                bestEstimate = estimate
            }
            expanded += 1
            if expanded > limit { break }
            let g = search.cost[n]
            for step in steps {
                let nx = x + step.dx, ny = y + step.dy
                guard nx >= 0, ny >= 0, nx < w, ny < height else { continue }
                let m = ny * w + nx
                if !open(nx, ny, afloat: afloat) || search.closed[m] == generation { continue }
                if step.dx != 0 && step.dy != 0 && (!open(nx, y, afloat: afloat) || !open(x, ny, afloat: afloat)) { continue }
                let ng = g + step.cost
                if search.opened[m] != generation || ng < search.cost[m] {
                    search.opened[m] = generation
                    search.cost[m] = ng
                    search.parent[m] = Int32(n)
                    let hm = goal.heuristic(nx, ny)
                    search.push(PathSearch.key(total: Int(ng) + hm, estimate: hm, node: m))
                }
            }
        }
        let end = found >= 0 ? found : best
        var tiles: [GridPoint] = []
        var n = end
        while n != s && n >= 0 {
            tiles.append(GridPoint(n % w, n / w))
            n = Int(search.parent[n])
        }
        tiles.reverse()
        return (tiles, found >= 0)
    }

    /// Drop the waypoints that a straight way can skip.
    func smoothed(from start: MapPosition, _ tiles: [GridPoint], afloat: Bool = false) -> [GridPoint] {
        guard tiles.count > 1 else { return tiles }
        var out: [GridPoint] = []
        var anchor = start
        var k = 0
        while k < tiles.count {
            var j = k
            while j + 1 < tiles.count && clearWay(anchor, tiles[j + 1].centre, goal: nil, afloat: afloat) { j += 1 }
            out.append(tiles[j])
            anchor = tiles[j].centre
            k = j + 1
        }
        return out
    }

    /// Re-stamp a person's sight after it has moved to another tile.
    mutating func restamp(_ i: Int) {
        let tile = entities[i].position.tile
        guard tile != entities[i].stamp else { return }
        stampSight(of: i, by: -1)
        entities[i].stamp = tile
        stampSight(of: i, by: 1)
    }

    /// The living opponent person nearest a rectangle of the map, within a
    /// distance of it: never a car, which cannot be harmed, and, if asked,
    /// only one the team can see. Ties go to the lower id.
    func nearestOpponent(of team: Int, minX: Double, minY: Double, maxX: Double, maxY: Double, within radius: Double,
                         visibleOnly: Bool) -> Int? {
        let cells = buckets.cells(minX: minX - radius, minY: minY - radius, maxX: maxX + radius, maxY: maxY + radius)
        guard cells.x0 <= cells.x1, cells.y0 <= cells.y1 else { return nil }
        let tiles = width * height
        var best = -1
        var bestDistance = Double.infinity
        for cy in cells.y0...cells.y1 {
            for cx in cells.x0...cells.x1 {
                let c = cy * buckets.columns + cx
                for k in Int(buckets.start[c])..<Int(buckets.start[c + 1]) {
                    let j = Int(buckets.items[k])
                    guard entities[j].alive, teamOf(entities[j].owner) != team, !entities[j].isUnharmable else { continue }
                    let p = entities[j].position
                    let dx = max(minX - p.x, 0, p.x - maxX), dy = max(minY - p.y, 0, p.y - maxY)
                    let d = (dx * dx + dy * dy).squareRoot()
                    guard d <= radius else { continue }
                    if visibleOnly && seen[team * tiles + tileIndex(p.tile)] <= 0 { continue }
                    if d < bestDistance || (d == bestDistance && entities[j].id < entities[best].id) {
                        best = j
                        bestDistance = d
                    }
                }
            }
        }
        return best >= 0 ? best : nil
    }
}
