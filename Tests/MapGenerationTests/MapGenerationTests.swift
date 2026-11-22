// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MapGeneration

// MARK: - Helpers

private let seeds: [UInt64] = Array(1...20)

/// One map for each player count and seed, made once and shared by the tests.
private enum Maps {
    static let byPlayers: [Int: [GameMap]] = {
        var out: [Int: [GameMap]] = [:]
        for n in 2...6 { out[n] = seeds.map { MapGenerator().generate(MapRequest(playerCount: n, seed: $0)) } }
        return out
    }()
}

private func centre(of start: GridPoint) -> MapPosition { Placement.centre(.townCentre, origin: start) }

private func distance(_ site: ResourceSite, from c: MapPosition) -> Double { site.tile.centre.distance(to: c) }

private func count(_ kind: SiteKind, in map: GameMap, within radius: Double, of start: GridPoint) -> Int {
    let c = centre(of: start)
    // On land: the water's own sites, for boats, are counted apart.
    return map.sites.filter { $0.kind == kind && map[$0.tile].isPassable && distance($0, from: c) <= radius }.count
}

/// The checksum the brief asks for: terrain raw values, then each site's fields in order.
private func checksum(_ map: GameMap) -> UInt64 {
    var sum = StableChecksum()
    func add(_ v: Int) { withUnsafeBytes(of: Int64(v).littleEndian) { sum.add(bytes: $0) } }
    add(map.width); add(map.height)
    for t in map.terrain { add(t.rawValue) }
    for s in map.sites { add(s.id.rawValue); add(s.kind.rawValue); add(s.tile.x); add(s.tile.y); add(s.remaining) }
    for s in map.starts { add(s.x); add(s.y) }
    return sum.value
}

/// Tiles that can be walked: passable terrain with no standing site that blocks.
private func reachableTiles(in map: GameMap, from start: GridPoint, ignoringSites: Bool) -> Set<GridPoint> {
    let blocked = ignoringSites ? [] : Placement.occupied(buildings: [], sites: map.sites)
    func free(_ p: GridPoint) -> Bool { map.contains(p) && map[p].isPassable && !blocked.contains(p) }
    var seen: Set<GridPoint> = [start]
    var stack = [start]
    while let p = stack.popLast() {
        for q in [GridPoint(p.x + 1, p.y), GridPoint(p.x - 1, p.y), GridPoint(p.x, p.y + 1), GridPoint(p.x, p.y - 1)]
        where free(q) && !seen.contains(q) { seen.insert(q); stack.append(q) }
    }
    return seen
}

// MARK: - Determinism

@Test func theSameRequestGivesTheSameMap() {
    let request = MapRequest(playerCount: 4, seed: 99)
    #expect(MapGenerator().generate(request) == MapGenerator().generate(request))
    #expect(MapGenerator().generate(request) != MapGenerator().generate(MapRequest(playerCount: 4, seed: 100)))
}

/// Stored values, which a second process reproduces. If a deliberate change to
/// the generator alters the map, regenerate them and say so in the commit.
@Test func storedChecksumsMatch() {
    #expect(checksum(MapGenerator().generate(MapRequest(playerCount: 2, seed: 1))) == 367_805_829_030_684_542)
    #expect(checksum(MapGenerator().generate(MapRequest(playerCount: 6, seed: 2))) == 18_390_609_078_460_926_163)
}

// MARK: - Shape

@Test(arguments: 2...6) func theMapHasItsSizeStartsAndOrderedSites(players: Int) {
    for map in Maps.byPlayers[players]! {
        #expect(map.width == 96 && map.height == 96 && map.terrain.count == 96 * 96)
        #expect(map.starts.count == players)
        for (i, site) in map.sites.enumerated() {
            #expect(site.id == SiteID(i))
            #expect(site.remaining == Catalogue.standard.gathering.amount(site.kind))
            #expect(map.contains(site.tile))
        }
        #expect(Set(map.sites.map(\.tile)).count == map.sites.count, "one site to a tile")
    }
}

@Test func sitesAreOnTheGroundTheyBelongOn() {
    for map in Maps.byPlayers[4]! {
        for site in map.sites {
            // Fish live only in the water; rocks may rise from it (ruled 2026-11-21); the rest stand on land.
            if site.kind == .fish { #expect(!map[site.tile].isPassable); continue }
            if !map[site.tile].isPassable { #expect([.stone, .copper, .tin, .gold, .iron].contains(site.kind)); continue }
            if site.kind == .tree { #expect(map[site.tile] == .forest) }
            else { #expect(map[site.tile] != .forest) }
        }
    }
}

@Test func everyTerrainAndEverySiteKindAppearsAcrossTheSeeds() {
    let maps = Maps.byPlayers.values.flatMap { $0 }
    for terrain in Terrain.allCases { #expect(maps.contains { $0.terrain.contains(terrain) }, "no \(terrain)") }
    for kind in SiteKind.allCases { #expect(maps.allSatisfy { $0.sites.contains { $0.kind == kind } }, "a map has no \(kind)") }
}

@Test func copperAndTinAreEqualInNumber() {
    for maps in Maps.byPlayers.values { for map in maps {
        let copper = map.sites.filter { $0.kind == .copper }.count
        #expect(copper == map.sites.filter { $0.kind == .tin }.count)
        #expect(copper > 5 * map.starts.count, "no scattered copper and tin")
    } }
}

@Test(arguments: 2...6) func everyStartHasFiveCopperTinAndIron(players: Int) {
    for map in Maps.byPlayers[players]! { for start in map.starts {
        #expect(count(.copper, in: map, within: 14, of: start) >= 5, "copper near \(start)")
        #expect(count(.tin, in: map, within: 14, of: start) >= 5, "tin near \(start)")
        #expect(count(.iron, in: map, within: 30, of: start) >= 5, "iron near \(start)")
    } }
}

// MARK: - The water's resources (ruled 2026-11-21)

@Test func fishComeInShoalsOfTwoByTwo() {
    for maps in Maps.byPlayers.values { for map in maps {
        let fish = Set(map.sites.filter { $0.kind == .fish }.map(\.tile))
        #expect(!fish.isEmpty)
        #expect(fish.count % 4 == 0)
        // Every fish tile is in a whole square of four fish tiles.
        for t in fish {
            let squares = [(0, 0), (-1, 0), (0, -1), (-1, -1)].map { d in
                [(0, 0), (1, 0), (0, 1), (1, 1)].allSatisfy { fish.contains(GridPoint(t.x + d.0 + $0.0, t.y + d.1 + $0.1)) }
            }
            #expect(squares.contains(true), "\(t)")
        }
    } }
}

@Test func rocksInTheWaterHaveWaterAllRound() {
    var kinds: Set<SiteKind> = []
    for maps in Maps.byPlayers.values { for map in maps {
        for site in map.sites where site.kind != .fish && !map[site.tile].isPassable {
            kinds.insert(site.kind)
            for dy in -1...1 { for dx in -1...1 {
                #expect(!map[GridPoint(site.tile.x + dx, site.tile.y + dy)].isPassable, "\(site.kind) at \(site.tile)")
            } }
        }
    } }
    #expect(kinds == [.stone, .copper, .tin, .gold, .iron])
}

@Test func aStartWithWaterInReachHasAShoalAndARockThere() {
    for maps in Maps.byPlayers.values { for map in maps { for start in map.starts {
        let c = centre(of: start)
        // Water in reach wide enough for a shoal: a square of two by two.
        let water = (0..<(map.width * map.height)).contains { i in
            let t = GridPoint(i % map.width, i / map.width)
            guard t.x < map.width - 1, t.y < map.height - 1 else { return false }
            let dx = Double(t.x) + 0.5 - c.x, dy = Double(t.y) + 0.5 - c.y
            return dx * dx + dy * dy <= 30 * 30
                && [(0, 0), (1, 0), (0, 1), (1, 1)].allSatisfy { !map[GridPoint(t.x + $0.0, t.y + $0.1)].isPassable }
        }
        guard water else { continue }
        let afloat = map.sites.filter { !map[$0.tile].isPassable && distance($0, from: c) <= 31 }
        #expect(afloat.contains { $0.kind == .fish } || afloat.contains { $0.kind == .stone }, "nothing afloat near \(start)")
    } } }
}

// MARK: - Fairness

@Test(arguments: 2...6) func everyStartIsBuildableWithNothingBlocking(players: Int) {
    for map in Maps.byPlayers[players]! {
        let occupied = Placement.occupied(buildings: [], sites: map.sites)
        for start in map.starts {
            #expect(Placement.canPlace(.townCentre, at: start, width: map.width, height: map.height, terrain: map.terrain,
                                       occupied: occupied, explored: { _ in true }))
        }
    }
}

@Test(arguments: 2...6) func everyStartHasItsNearbyResources(players: Int) {
    let near: [(SiteKind, Int)] = [(.tree, 6), (.prey, 3), (.stone, 2), (.copper, 2), (.tin, 1), (.gold, 2)]
    for map in Maps.byPlayers[players]! { for start in map.starts {
        for (kind, least) in near { #expect(count(kind, in: map, within: 14, of: start) >= least, "\(kind) near \(start)") }
    } }
}

@Test(arguments: 2...6) func everyStartHasIronAndOilWithinThirtyTiles(players: Int) {
    for map in Maps.byPlayers[players]! { for start in map.starts {
        #expect(count(.iron, in: map, within: 30, of: start) >= 1)
        #expect(count(.oilField, in: map, within: 30, of: start) >= 1)
    } }
}

@Test(arguments: 2...6) func startsAreFarApart(players: Int) {
    for map in Maps.byPlayers[players]! {
        for i in map.starts.indices { for j in map.starts.indices where i < j {
            #expect(centre(of: map.starts[i]).distance(to: centre(of: map.starts[j])) >= 30)
        } }
    }
}

@Test(arguments: 2...6) func startsAreSpreadAroundTheMap(players: Int) {
    for map in Maps.byPlayers[players]! {
        let middle = MapPosition(x: Double(map.width) / 2, y: Double(map.height) / 2)
        for start in map.starts { #expect(centre(of: start).distance(to: middle) >= 20) }
        // The bearings from the middle leave no gap larger than one and a half times an even spacing.
        var bearings = map.starts.map { atan2(centre(of: $0).y - middle.y, centre(of: $0).x - middle.x) }.sorted()
        bearings.append(bearings[0] + 2 * Double.pi)
        for k in 0..<(bearings.count - 1) { #expect(bearings[k + 1] - bearings[k] <= 2 * Double.pi / Double(players) * 1.5) }
    }
}

@Test(arguments: 2...6) func everyStartReachesEveryOther(players: Int) {
    for map in Maps.byPlayers[players]! {
        let reached = reachableTiles(in: map, from: map.starts[0], ignoringSites: false)
        for start in map.starts { #expect(reached.contains(start)) }
        // And every tile of every town centre footprint, which is where people begin.
        for start in map.starts { for t in Placement.footprint(.townCentre, at: start) { #expect(reached.contains(t)) } }
    }
}

@Test func smallerFieldsAreFairToo() {
    for players in 2...6 { for seed in seeds.prefix(8) {
        let map = MapGenerator().generate(MapRequest(width: 64, height: 72, playerCount: players, seed: seed))
        #expect(map.width == 64 && map.height == 72)
        for start in map.starts {
            #expect(count(.tree, in: map, within: 14, of: start) >= 6)
            #expect(count(.tin, in: map, within: 14, of: start) >= 1)
            #expect(count(.iron, in: map, within: 30, of: start) >= 1)
            #expect(count(.oilField, in: map, within: 30, of: start) >= 1)
        }
        let reached = reachableTiles(in: map, from: map.starts[0], ignoringSites: false)
        for start in map.starts { #expect(reached.contains(start)) }
    } }
}

/// The large map (ruled 2026-11-21): twice as wide and twice as tall, and still
/// fair to every start. The scattered deposits, herds and woods grow with the
/// area, four times; each start's own resources are those of the standard map,
/// so the whole grows less than four times, the less the more players there are.
@Test(arguments: [2, 6]) func aLargeMapHasFourTimesTheRoomAndTheResources(players: Int) {
    let standard = MapGenerator().generate(MapRequest(size: .standard, playerCount: players, seed: 3))
    let large = MapGenerator().generate(MapRequest(size: .large, playerCount: players, seed: 3))
    #expect(large.width == 192 && large.height == 192 && large.starts.count == players)
    let ratio = Double(large.sites.count) / Double(standard.sites.count)
    #expect(ratio > (players == 2 ? 3.3 : 2.5) && ratio < 4.5, "ratio \(ratio)")
    for start in large.starts {
        #expect(count(.tree, in: large, within: 14, of: start) >= 6)
        #expect(count(.iron, in: large, within: 30, of: start) >= 1)
    }
    let reached = reachableTiles(in: large, from: large.starts[0], ignoringSites: false)
    for start in large.starts { #expect(reached.contains(start)) }
}

// MARK: - Speed

@Test func aDefaultMapTakesUnderTwoHundredMilliseconds() {
    // The best of several runs, so that a busy machine does not fail the test.
    var best = Duration.seconds(10)
    for seed in 1...5 as ClosedRange<UInt64> {
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = MapGenerator().generate(MapRequest(playerCount: 6, seed: seed)) }
        best = min(best, elapsed)
    }
    #expect(best < .milliseconds(200), "took \(best)")
}

// MARK: - Overview images

private func colour(_ t: Terrain) -> (UInt8, UInt8, UInt8) {
    switch t {
    case .grass: (120, 170, 80)
    case .dirt: (150, 115, 75)
    case .sand: (225, 205, 140)
    case .forest: (50, 110, 55)
    case .shallowWater: (110, 175, 215)
    case .deepWater: (40, 90, 160)
    }
}

private func colour(_ k: SiteKind) -> (UInt8, UInt8, UInt8) {
    switch k {
    case .tree: (20, 70, 30)
    case .prey: (240, 240, 240)
    case .stone: (130, 130, 130)
    case .copper: (210, 110, 40)
    case .tin: (180, 200, 215)
    case .gold: (250, 215, 30)
    case .iron: (90, 50, 50)
    case .oilField: (20, 20, 20)
    case .fish: (230, 250, 255)
    }
}

/// One block of `scale` pixels to a tile; a colour per terrain and per site
/// kind; each start a magenta 3 × 3 block with a white border.
private func overview(_ map: GameMap, scale: Int = 6) -> CGImage? {
    let width = map.width * scale, height = map.height * scale
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    func paint(_ tx: Int, _ ty: Int, _ c: (UInt8, UInt8, UInt8), inset: Int = 0) {
        guard tx >= 0, ty >= 0, tx < map.width, ty < map.height else { return }
        for py in inset..<(scale - inset) { for px in inset..<(scale - inset) {
            let o = ((ty * scale + py) * width + tx * scale + px) * 4
            pixels[o] = c.0; pixels[o + 1] = c.1; pixels[o + 2] = c.2
        } }
    }
    for y in 0..<map.height { for x in 0..<map.width { paint(x, y, colour(map[GridPoint(x, y)])) } }
    for s in map.sites { paint(s.tile.x, s.tile.y, colour(s.kind), inset: s.kind == .tree ? 1 : 0) }
    for start in map.starts {
        for t in Placement.footprint(.townCentre, at: start) { paint(t.x, t.y, (255, 255, 255)) }
        for t in Placement.footprint(.townCentre, at: start) { paint(t.x, t.y, (230, 0, 200), inset: 1) }
    }
    guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                   space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

private func write(_ image: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

/// Writes overviews to `MAP_RENDERS` when it is set, else to a temporary folder.
@Test(arguments: [(2, UInt64(1)), (6, UInt64(2)), (3, UInt64(7)), (4, UInt64(11))])
func overviewImagesAreWritten(players: Int, seed: UInt64) throws {
    let folder = ProcessInfo.processInfo.environment["MAP_RENDERS"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("greatest-conqueror-map-renders", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let map = MapGenerator().generate(MapRequest(playerCount: players, seed: seed))
    let image = try #require(overview(map))
    let url = folder.appendingPathComponent("map-\(players)-players-seed-\(seed).png")
    #expect(write(image, to: url))
    #expect(FileManager.default.fileExists(atPath: url.path))
}
