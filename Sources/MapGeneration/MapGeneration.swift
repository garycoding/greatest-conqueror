// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Makes the map of a match (docs/architecture.md, `MapGenerating`).
///
/// The same request gives the same map, in any process: every choice comes from
/// one `SeededGenerator`, and nothing here depends on the order of a `Dictionary`
/// or a `Set`, on `Foundation`, or on the platform's trigonometry.
///
/// The map is made in this order: the starts are spread on a ring; the ground
/// (grass, dirt, sand, forest) is shaped by smooth noise; lakes, rivers and coast
/// are laid over it, never near a start; each start is cleared and given the same
/// kit of sites (trees, prey and gold within reach); the rest of the map is
/// scattered with further gold mines, herds
/// and trees; any start that cannot walk to the others is joined to them by a
/// path cut through water or trees; and last, the water is given its own
/// resources, for boats (ruled 2026-11-21): shoals of fish, two tiles by two,
/// and rocks of gold rising from it, one near each start that has water within
/// reach and the rest scattered.
public struct MapGenerator: MapGenerating {
    public init() {}

    /// A map for 2 to 6 players on a field of at least 64 × 64 tiles. The
    /// default field is 96 × 96.
    public func generate(_ request: MapRequest) -> GameMap {
        precondition((2...6).contains(request.playerCount), "a map holds 2 to 6 players")
        precondition(request.width >= 64 && request.height >= 64, "a map is at least 64 × 64 tiles")
        var builder = MapBuilder(request)
        return builder.build()
    }
}

// MARK: - Random helpers

extension SeededGenerator {
    /// An integer in `0..<n`. Not `Int.random(in:using:)`, whose algorithm the
    /// standard library may change between releases and so change every map.
    mutating func below(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt64(n)) }

    mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + below(range.count) }

    /// A value in `0 ..< 1`.
    mutating func unit() -> Double { Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0) }

    mutating func double(_ low: Double, _ high: Double) -> Double { low + unit() * (high - low) }

    mutating func chance(_ p: Double) -> Bool { unit() < p }

    mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, to: 0, by: -1) { items.swapAt(i, below(i + 1)) }
    }
}

/// Sine and cosine by Taylor series, which use only the four basic operations
/// and so give the same result on every platform.
func sinCos(_ angle: Double) -> (sin: Double, cos: Double) {
    let twoPi = 2 * Double.pi
    var x = angle
    while x > Double.pi { x -= twoPi }
    while x < -Double.pi { x += twoPi }
    let x2 = x * x
    var sin = x, term = x
    for k in 1...13 { term *= -x2 / Double((2 * k) * (2 * k + 1)); sin += term }
    var cos = 1.0
    term = 1
    for k in 1...13 { term *= -x2 / Double((2 * k - 1) * (2 * k)); cos += term }
    return (sin, cos)
}

/// Smooth noise in `0 ... 1`: random values on a coarse lattice, blended with a
/// smoothstep. A larger cell makes larger features.
struct ValueNoise {
    private let cell: Double
    private let columns: Int
    private var values: [Double]

    init(width: Int, height: Int, cell: Int, rng: inout SeededGenerator) {
        self.cell = Double(cell)
        columns = width / cell + 2
        let rows = height / cell + 2
        values = (0..<(columns * rows)).map { _ in rng.unit() }
    }

    func at(_ x: Int, _ y: Int) -> Double {
        let fx = Double(x) / cell, fy = Double(y) / cell
        let ix = Int(fx), iy = Int(fy)
        let tx = smooth(fx - Double(ix)), ty = smooth(fy - Double(iy))
        let i = iy * columns + ix
        let top = values[i] + (values[i + 1] - values[i]) * tx
        let bottom = values[i + columns] + (values[i + columns + 1] - values[i + columns]) * tx
        return top + (bottom - top) * ty
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

// MARK: - The builder

/// Where a site may be put: near a start (the kit, which clears forest for what
/// is not a tree), or away from every start (which leaves forest to the trees).
private enum Zone {
    case near(x: Double, y: Double, maxSquared: Double)
    case away
}

private struct KitItem {
    var kind: SiteKind
    var count: Int
    var minDistance: Double
    var maxDistance: Double
    var radius: Int
}

struct MapBuilder {
    private let request: MapRequest
    private let w: Int, h: Int
    private var rng: SeededGenerator
    private var terrain: [Terrain]
    /// Sites in the order made; a removed site leaves `nil`.
    private var sites: [ResourceSite?] = []
    /// The index in `sites` of the site on each tile, or -1.
    private var siteAt: [Int]
    private var starts: [GridPoint] = []
    /// The centre of each start's town centre footprint, in tile units.
    private var centres: [(x: Double, y: Double)] = []
    /// The tiles around each start that stay open ground with no site.
    private var clear: [Bool]
    /// Tiles within 12 of a start's centre, where no water is laid.
    private var dry: [Bool]
    /// Tiles within 11 of a start's centre, where no scattered site is put.
    private var nearStart: [Bool]

    init(_ request: MapRequest) {
        self.request = request
        w = request.width
        h = request.height
        rng = SeededGenerator(seed: request.seed)
        terrain = Array(repeating: .grass, count: w * h)
        siteAt = Array(repeating: -1, count: w * h)
        clear = Array(repeating: false, count: w * h)
        dry = Array(repeating: false, count: w * h)
        nearStart = Array(repeating: false, count: w * h)
    }

    mutating func build() -> GameMap {
        layOutStarts()
        shapeGround()
        layWater()
        addBeaches()
        for s in starts.indices { giveKit(to: s) }
        scatter()
        growTrees()
        joinStarts()
        seedWater()
        let ordered = sites.compactMap { $0 }.sorted { $0.tile < $1.tile }
        let numbered = ordered.enumerated().map {
            ResourceSite(id: SiteID($0.offset), kind: $0.element.kind, tile: $0.element.tile, remaining: $0.element.remaining)
        }
        return GameMap(width: w, height: h, terrain: terrain, sites: numbered, starts: starts)
    }

    // MARK: Starts

    /// Puts the starts on a ring around the middle, a random turn of it apart
    /// and a little out of true, and tries again until every pair is far enough
    /// apart. The last tries are exactly regular, which always succeeds.
    private mutating func layOutStarts() {
        let n = request.playerCount
        let side = Double(min(w, h))
        let radius = side * 0.37
        let required = side * 0.3125
        let cx = Double(w) / 2, cy = Double(h) / 2
        let step = 2 * Double.pi / Double(n)
        var chosen: [GridPoint] = []
        for attempt in 0..<64 {
            let wobble = attempt < 56 ? 1.0 : 0.0
            let base = rng.unit() * 2 * Double.pi
            var tries: [GridPoint] = []
            for i in 0..<n {
                let angle = base + Double(i) * step + (rng.unit() - 0.5) * 0.12 * wobble
                let r = radius * (1 + (rng.unit() - 0.5) * 0.08 * wobble)
                let (s, c) = sinCos(angle)
                let x = Int((cx + r * c - 1.5).rounded()), y = Int((cy + r * s - 1.5).rounded())
                tries.append(GridPoint(min(max(x, 6), w - 9), min(max(y, 6), h - 9)))
            }
            chosen = tries
            var ok = true
            for i in 0..<n { for j in (i + 1)..<max(n, i + 1) {
                let dx = Double(tries[i].x - tries[j].x), dy = Double(tries[i].y - tries[j].y)
                if (dx * dx + dy * dy).squareRoot() < required { ok = false }
            } }
            if ok { break }
        }
        starts = chosen
        centres = starts.map { (Double($0.x) + 1.5, Double($0.y) + 1.5) }
        for (x, y) in centres {
            let x0 = max(0, Int(x) - 13), x1 = min(w - 1, Int(x) + 13)
            let y0 = max(0, Int(y) - 13), y1 = min(h - 1, Int(y) + 13)
            for ty in y0...y1 { for tx in x0...x1 {
                let dx = Double(tx) + 0.5 - x, dy = Double(ty) + 0.5 - y
                let d2 = dx * dx + dy * dy
                if d2 <= 144 { dry[ty * w + tx] = true }
                if d2 <= 121 { nearStart[ty * w + tx] = true }
            } }
        }
        for start in starts {
            for ty in (start.y - 2)...(start.y + 4) { for tx in (start.x - 2)...(start.x + 4) where inBounds(tx, ty) {
                clear[ty * w + tx] = true
            } }
        }
    }

    // MARK: Ground and water

    private func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h }

    private mutating func shapeGround() {
        let dirtNoise = ValueNoise(width: w, height: h, cell: 12, rng: &rng)
        let sandNoise = ValueNoise(width: w, height: h, cell: 16, rng: &rng)
        let forestNoise = ValueNoise(width: w, height: h, cell: 9, rng: &rng)
        for y in 0..<h { for x in 0..<w {
            let i = y * w + x
            if forestNoise.at(x, y) > 0.6 { terrain[i] = .forest }
            else if sandNoise.at(x, y) > 0.72 { terrain[i] = .sand }
            else if dirtNoise.at(x, y) > 0.62 { terrain[i] = .dirt }
        } }
    }

    /// Lays water only where it is not too near a start.
    private mutating func setWater(_ x: Int, _ y: Int, deep: Bool) {
        guard inBounds(x, y) else { return }
        let i = y * w + x
        guard !dry[i] else { return }
        if deep { terrain[i] = .deepWater } else if terrain[i] != .deepWater { terrain[i] = .shallowWater }
    }

    private mutating func layWater() {
        let area = Double(w * h) / 9216
        let lakes = max(1, Int((rng.double(3, 5.99) * area).rounded()))
        for _ in 0..<lakes { layLake() }
        let rivers = rng.int(1...2)
        for _ in 0..<rivers { layRiver() }
        let coasts = rng.int(0...2)
        var sides = [0, 1, 2, 3]
        rng.shuffle(&sides)
        for k in 0..<coasts { layCoast(side: sides[k]) }
    }

    private mutating func layLake() {
        let side = Double(min(w, h))
        let cx = rng.double(0.1, 0.9) * Double(w), cy = rng.double(0.1, 0.9) * Double(h)
        let rx = rng.double(0.04, 0.09) * side, ry = rng.double(0.04, 0.09) * side
        let wobble = ValueNoise(width: w, height: h, cell: 5, rng: &rng)
        let x0 = max(0, Int(cx - rx * 1.5)), x1 = min(w - 1, Int(cx + rx * 1.5))
        let y0 = max(0, Int(cy - ry * 1.5)), y1 = min(h - 1, Int(cy + ry * 1.5))
        for y in y0...y1 { for x in x0...x1 {
            let dx = (Double(x) - cx) / rx, dy = (Double(y) - cy) / ry
            let d = (dx * dx + dy * dy).squareRoot() * (1.25 - 0.5 * wobble.at(x, y))
            if d < 1 { setWater(x, y, deep: d < 0.55) }
        } }
    }

    private mutating func layRiver() {
        let horizontal = rng.chance(0.5)
        let length = horizontal ? w : h, breadth = horizontal ? h : w
        var lateral = rng.double(0.2, 0.8) * Double(breadth)
        var drift = 0.0
        let radius = rng.double(1.3, 2.0)
        for along in 0..<length {
            drift = drift * 0.85 + (rng.unit() - 0.5) * 0.9
            lateral = min(max(lateral + drift, 4), Double(breadth - 5))
            let reach = Int(radius.rounded(.up))
            let centre = Int(lateral.rounded())
            for across in (centre - reach)...(centre + reach) {
                let d = Double(across) - lateral
                let dist = d < 0 ? -d : d
                guard dist <= radius else { continue }
                if horizontal { setWater(along, across, deep: dist < radius - 1) } else { setWater(across, along, deep: dist < radius - 1) }
            }
        }
    }

    /// Water along one edge of the map, to a depth that varies along the edge.
    /// Side 0 is the top (y = 0), 1 the right, 2 the bottom, 3 the left.
    private mutating func layCoast(side: Int) {
        let length = side % 2 == 0 ? w : h, breadth = side % 2 == 0 ? h : w
        let noise = ValueNoise(width: length, height: 1, cell: 12, rng: &rng)
        let base = rng.double(0.03, 0.06) * Double(breadth)
        for along in 0..<length {
            let depth = base + noise.at(along, 0) * 0.08 * Double(breadth)
            for d in 0..<Int(depth.rounded(.up)) {
                let deep = Double(d) < depth * 0.5
                switch side {
                case 0: setWater(along, d, deep: deep)
                case 1: setWater(w - 1 - d, along, deep: deep)
                case 2: setWater(along, h - 1 - d, deep: deep)
                default: setWater(d, along, deep: deep)
                }
            }
        }
    }

    /// Grass and dirt beside water become sand.
    private mutating func addBeaches() {
        for y in 0..<h { for x in 0..<w {
            let i = y * w + x
            guard terrain[i] == .grass || terrain[i] == .dirt else { continue }
            if (x > 0 && !terrain[i - 1].isPassable) || (x < w - 1 && !terrain[i + 1].isPassable)
                || (y > 0 && !terrain[i - w].isPassable) || (y < h - 1 && !terrain[i + w].isPassable) {
                terrain[i] = .sand
            }
        } }
        for i in clear.indices where clear[i] { terrain[i] = .grass }
    }

    // MARK: Sites

    private mutating func put(_ kind: SiteKind, _ x: Int, _ y: Int) {
        let i = y * w + x
        siteAt[i] = sites.count
        sites.append(ResourceSite(id: SiteID(0), kind: kind, tile: GridPoint(x, y),
                                  remaining: request.catalogue.gathering.amount(kind)))
        if kind == .tree { terrain[i] = .forest } else if terrain[i] == .forest { terrain[i] = .grass }
    }

    private func allowed(_ x: Int, _ y: Int, _ kind: SiteKind, _ zone: Zone) -> Bool {
        guard inBounds(x, y) else { return false }
        let i = y * w + x
        guard !clear[i], siteAt[i] < 0, terrain[i].isPassable else { return false }
        switch zone {
        case .near(let cx, let cy, let maxSquared):
            let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
            return dx * dx + dy * dy <= maxSquared
        case .away:
            return !nearStart[i] && (kind == .tree || terrain[i] != .forest)
        }
    }

    /// The tiles a cluster of `kind` would take around `(x, y)`: the nearest
    /// allowed tiles, with a little disorder so that clusters are not discs.
    private mutating func clusterTiles(_ kind: SiteKind, count: Int, x: Int, y: Int, radius: Int, zone: Zone) -> [GridPoint] {
        var candidates: [(key: Double, tile: GridPoint)] = []
        for dy in -radius...radius { for dx in -radius...radius {
            let d2 = Double(dx * dx + dy * dy)
            guard d2 <= Double(radius * radius), allowed(x + dx, y + dy, kind, zone) else { continue }
            candidates.append((d2 + rng.unit() * 2.5, GridPoint(x + dx, y + dy)))
        } }
        candidates.sort { $0.key < $1.key || ($0.key == $1.key && $0.tile < $1.tile) }
        return candidates.prefix(count).map(\.tile)
    }

    private mutating func giveKit(to s: Int) {
        let (cx, cy) = centres[s]
        let near = Zone.near(x: cx, y: cy, maxSquared: 11 * 11)
        let items = [
            KitItem(kind: .tree, count: 14, minDistance: 6, maxDistance: 8.5, radius: 3),
            KitItem(kind: .prey, count: 4, minDistance: 6.5, maxDistance: 9, radius: 2),
            KitItem(kind: .gold, count: 3, minDistance: 6.5, maxDistance: 9, radius: 2),
        ]
        var slots = Array(0..<items.count)
        rng.shuffle(&slots)
        let turn = rng.unit() * 2 * Double.pi
        for (k, item) in items.enumerated() {
            let slotAngle = turn + Double(slots[k]) * 2 * Double.pi / Double(items.count)
            place(item, aroundX: cx, y: cy, slotAngle: slotAngle, zone: near)
        }
    }

    /// Puts a cluster of `item` at the distance and angle asked for; if the
    /// ground there will not hold it, at other angles, keeping the best found.
    private mutating func place(_ item: KitItem, aroundX cx: Double, y cy: Double, slotAngle: Double, zone: Zone) {
        var best: [GridPoint] = []
        for attempt in 0..<48 {
            let angle = attempt < 24 ? slotAngle + (rng.unit() - 0.5) * 0.5 : rng.unit() * 2 * Double.pi
            let distance = rng.double(item.minDistance, item.maxDistance)
            let (s, c) = sinCos(angle)
            let x = Int((cx + distance * c).rounded(.down)), y = Int((cy + distance * s).rounded(.down))
            let tiles = clusterTiles(item.kind, count: item.count, x: x, y: y, radius: item.radius, zone: zone)
            if tiles.count > best.count { best = tiles }
            if best.count >= item.count { break }
        }
        for t in best { put(item.kind, t.x, t.y) }
    }

    /// Clusters of prey and gold over the whole field, away from the starts.
    private mutating func scatter() {
        let area = Double(w * h) / 9216
        func clusters(_ n: Double) -> Int { max(2, Int((n * area).rounded())) }
        let plan: [(SiteKind, Int, ClosedRange<Int>)] = [
            (.prey, clusters(14), 3...5),
            (.gold, clusters(5), 3...4),
        ]
        for (kind, count, size) in plan {
            for _ in 0..<count { _ = scatterCluster(kind, size: rng.int(size)) }
        }
    }

    /// Puts one cluster of up to `size` sites of `kind` somewhere away from the
    /// starts, and returns how many it put.
    private mutating func scatterCluster(_ kind: SiteKind, size n: Int, attempts: Int = 30) -> Int {
        for _ in 0..<attempts {
            let x = rng.below(w), y = rng.below(h)
            let tiles = clusterTiles(kind, count: n, x: x, y: y, radius: 2, zone: .away)
            if tiles.count >= min(n, 2) {
                for t in tiles { put(kind, t.x, t.y) }
                return tiles.count
            }
        }
        return 0
    }

    /// A tree on most forest tiles that are not part of a start's open ground.
    private mutating func growTrees() {
        for y in 0..<h { for x in 0..<w {
            let i = y * w + x
            if terrain[i] == .forest && !clear[i] && siteAt[i] < 0 && rng.chance(0.6) { put(.tree, x, y) }
        } }
    }

    // MARK: The water's resources

    /// The farthest a start's own shoal and rocks may lie from its centre.
    static let waterReach = 30.0

    /// Whether a shoal may cover the two tiles by two from `(x, y)`: all water, with no site.
    private func shoalFits(_ x: Int, _ y: Int) -> Bool {
        guard inBounds(x, y), inBounds(x + 1, y + 1) else { return false }
        for (tx, ty) in [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)] {
            let i = ty * w + tx
            if terrain[i].isPassable || siteAt[i] >= 0 { return false }
        }
        return true
    }

    /// Whether a rock may rise from `(x, y)`: water all round it, and no site
    /// on it or beside it, so that a rock never closes a channel.
    private func rockFits(_ x: Int, _ y: Int) -> Bool {
        guard x > 0, y > 0, x < w - 1, y < h - 1 else { return false }
        for ty in (y - 1)...(y + 1) { for tx in (x - 1)...(x + 1) {
            let i = ty * w + tx
            if terrain[i].isPassable || siteAt[i] >= 0 { return false }
        } }
        return true
    }

    private mutating func putShoal(_ x: Int, _ y: Int) {
        for (tx, ty) in [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)] { put(.fish, tx, ty) }
    }

    /// The water tiles within `waterReach` of a centre, nearest first.
    private func waterNear(_ cx: Double, _ cy: Double) -> [GridPoint] {
        let reach = Int(Self.waterReach)
        var found: [(d2: Double, tile: GridPoint)] = []
        for ty in max(0, Int(cy) - reach)...min(h - 1, Int(cy) + reach) {
            for tx in max(0, Int(cx) - reach)...min(w - 1, Int(cx) + reach) where !terrain[ty * w + tx].isPassable {
                let dx = Double(tx) + 0.5 - cx, dy = Double(ty) + 0.5 - cy
                let d2 = dx * dx + dy * dy
                if d2 <= Self.waterReach * Self.waterReach { found.append((d2, GridPoint(tx, ty))) }
            }
        }
        found.sort { $0.d2 < $1.d2 || ($0.d2 == $1.d2 && $0.tile < $1.tile) }
        return found.map(\.tile)
    }

    private mutating func seedWater() {
        // Each start with water in reach: a shoal and a gold rock in the nearest water that holds them.
        for (cx, cy) in centres {
            let near = waterNear(cx, cy)
            if let t = near.first(where: { shoalFits($0.x, $0.y) }) { putShoal(t.x, t.y) }
            if let t = near.first(where: { rockFits($0.x, $0.y) }) { put(.gold, t.x, t.y) }
        }
        // The rest of the water, in proportion to the field.
        let area = Double(w * h) / 9216
        let shoals = Int((4 * area).rounded()), rounds = Int((2 * area).rounded())
        func randomWater(_ fits: (Int, Int) -> Bool) -> GridPoint? {
            for _ in 0..<200 {
                let x = rng.below(w), y = rng.below(h)
                if fits(x, y) { return GridPoint(x, y) }
            }
            return nil
        }
        for _ in 0..<shoals {
            if let t = randomWater({ shoalFits($0, $1) }) { putShoal(t.x, t.y) }
        }
        // Rounds of gold rocks.
        for _ in 0..<rounds {
            if let t = randomWater({ rockFits($0, $1) }) { put(.gold, t.x, t.y) }
        }
    }

    // MARK: Reaching every start

    private func isFree(_ i: Int) -> Bool {
        guard terrain[i].isPassable else { return false }
        let s = siteAt[i]
        return s < 0 || !(sites[s]?.kind.blocksTile ?? false)
    }

    /// The tiles reachable from `source` on four-connected free tiles.
    private func reachable(from source: Int) -> [Bool] {
        var seen = Array(repeating: false, count: w * h)
        guard isFree(source) else { return seen }
        var stack = [source]
        seen[source] = true
        while let u = stack.popLast() {
            for v in neighbours(u) where !seen[v] && isFree(v) { seen[v] = true; stack.append(v) }
        }
        return seen
    }

    private func neighbours(_ i: Int) -> [Int] {
        let x = i % w, y = i / w
        var out: [Int] = []
        if y > 0 { out.append(i - w) }
        if x > 0 { out.append(i - 1) }
        if x < w - 1 { out.append(i + 1) }
        if y < h - 1 { out.append(i + w) }
        return out
    }

    /// Cuts the cheapest path from each start that cannot reach the first start
    /// to the ground the first start can reach: a tile of water becomes sand
    /// and a tree is felled; gold mines are never cut. A shortest
    /// path in which free tiles cost nothing and the others cost one.
    private mutating func joinStarts() {
        let anchor = starts[0].y * w + starts[0].x
        for s in 1..<starts.count {
            let origin = starts[s].y * w + starts[s].x
            let reached = reachable(from: anchor)
            if reached[origin] { continue }
            var cost = Array(repeating: Int.max, count: w * h)
            var parent = Array(repeating: -1, count: w * h)
            var done = Array(repeating: false, count: w * h)
            var current = [origin], later: [Int] = []
            cost[origin] = 0
            var level = 0
            var target = -1
            search: while !current.isEmpty {
                while let u = current.popLast() {
                    if done[u] { continue }
                    done[u] = true
                    if reached[u] { target = u; break search }
                    for v in neighbours(u) where !done[v] {
                        let step: Int
                        if isFree(v) { step = 0 }
                        else if !terrain[v].isPassable { step = 1 }
                        else if sites[siteAt[v]]?.kind == .tree { step = 1 }
                        else { continue }
                        if level + step < cost[v] {
                            cost[v] = level + step
                            parent[v] = u
                            if step == 0 { current.append(v) } else { later.append(v) }
                        }
                    }
                }
                current = later
                later = []
                level += 1
            }
            var t = target
            while t >= 0 {
                if !terrain[t].isPassable { terrain[t] = .sand }
                if siteAt[t] >= 0, sites[siteAt[t]]?.kind == .tree { sites[siteAt[t]] = nil; siteAt[t] = -1 }
                t = parent[t]
            }
        }
    }
}
