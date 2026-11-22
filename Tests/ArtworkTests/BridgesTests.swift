// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The bridge (`BridgeSprites`): every key of the batch has a sprite anchored
/// at the centre of its tile with a mask, every other key has none, the
/// pieces of a row make one deck rising to its middle, a key always gives the
/// same pixels, and the batch is drawn quickly.
@Suite(.serialized) struct BridgesTests {
    private static let source = BridgeSprites()

    /// The batch's keys, as the milestone's checklist names them.
    private static let batch: [SpriteKey] = SpriteKey.required(through: .industrial).filter {
        if case .building(.bridge, _) = $0.subject { return true }
        return false
    }

    @Test func theBatchIsEveryAgesBridgeInEveryPlace() {
        #expect(Self.batch.count == 5 * BridgePlace.drawings.count * 2)
        #expect(Set(Self.batch) == Set(BridgesPiece.keys))
    }

    @Test func everyKeyHasASpriteWithAMask() throws {
        for key in Self.batch {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "\(key) has no team colour")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height, "\(key)")
            #expect(BridgesPixels(mask).bounds(alphaAbove: 128) != nil, "\(key): the mask is empty")
            let drawn = try #require(BridgesPixels(sprite.base).bounds(alphaAbove: 128), "\(key) is empty")
            let pixels = BridgesPixels(sprite.base)
            #expect(drawn.minX > 0 && drawn.minY > 0 && drawn.maxX < pixels.width - 1 && drawn.maxY < pixels.height - 1,
                    "\(key) reaches the edge of its picture")
        }
    }

    /// The anchor is the centre of the tile's diamond: along the middle of the
    /// piece's own row, the deck reaches the tile's two edges at its height
    /// there, half a tile on either side of the anchor, and not past the far one.
    @Test func theAnchorIsTheCentreOfTheTile() throws {
        for key in Self.batch where Self.isComplete(key) {
            let piece = try #require(BridgesPiece(key))
            let sprite = try #require(Self.source.sprite(key))
            let pixels = BridgesPixels(sprite.base)
            let (x, y) = pixels.place(sprite.anchor)
            // Two pixels a point: half a tile along x is 32 by 16 pixels on the screen.
            let dx = piece.place.run == .alongX ? 32.0 : -32.0
            let (back, front) = piece.place.heights
            func deck(_ t: Double) -> Double {
                2 * (BridgesLook.deckHeight + Double(back) + Double(front - back) * (t + 1) / 2)
            }
            func opaque(_ t: Double, _ d: Double) -> Bool {
                pixels.alpha(Int((x + dx * t).rounded()), Int((y - d + 16 * t).rounded())) > 200
            }
            for t in stride(from: -0.95, through: 0.95, by: 0.05) { #expect(opaque(t, deck(t)), "\(key): no deck at \(t)") }
            // (The Alchemy age's gatehouse, on the near lane's middle piece, stands over the point beyond.)
            let gatehouse = piece.age == .alchemy && piece.place.lane == 1 && piece.place.middle
            if !gatehouse { #expect(!opaque(-1.3, deck(-1)), "\(key): the deck runs past the tile") }
        }
    }

    /// A row of six pieces, as a bridge lays them, shows one deck along the
    /// middle of the row, rising from the bank to its middle and back: no
    /// pixel along it is less than opaque, across any joint.
    @Test func theRowsOfABridgeMakeOneRisingDeck() throws {
        for age in BridgesPiece.ages {
            for run in BridgeRun.allCases {
                for lane in 0...1 {
                    let places = (0..<6).map { BridgePlace(run: run, lane: lane, index: $0, count: 6) }
                    let sprites = try places.map { try #require(Self.source.sprite(SpriteKey(.building(.bridge, age), $0.pose(complete: true)))) }
                    let w = sprites[0].base.width, h = sprites[0].base.height
                    let width = w + 6 * 64 + 80, height = h + 6 * 32 + 80
                    let context = try #require(Raster.bitmap(width: width, height: height))
                    let step = run == .alongX ? 64.0 : -64.0
                    let start = CGPoint(x: Double(width) / 2 - 2.5 * step, y: Double(height) / 2 + 2.5 * 32)
                    for (k, sprite) in sprites.enumerated() {
                        let ax = start.x + Double(k) * step - sprite.anchor.x * Double(w)
                        let ay = start.y - Double(k) * 32 - sprite.anchor.y * Double(h)
                        context.draw(sprite.base, in: CGRect(x: ax, y: ay, width: Double(w), height: Double(h)))
                    }
                    let pixels = BridgesPixels(try #require(context.makeImage()))
                    for s in stride(from: 0.05, through: 5.95, by: 0.02) {
                        let i = min(Int(s), 5), f = s - Double(i)
                        let (back, front) = places[i].heights
                        let lift = 2 * (BridgesLook.deckHeight + Double(back) + Double(front - back) * f)
                        let px = Int((start.x + step * (s - 0.5)).rounded())
                        let py = Int((Double(height) - start.y + 32 * (s - 0.5) - lift).rounded())
                        #expect(pixels.alpha(px, py) == 255, "\(age) \(run) lane \(lane): a gap in the deck at \(s)")
                    }
                }
            }
        }
    }

    @Test func everyOtherKeyHasNone() {
        let batch = Set(Self.batch)
        var others: [SpriteKey] = []
        let poses: [SpritePose] = [.complete, .underConstruction, .standing, "bridge-along-z", "bridge-along-x",
                                   "bridge-along-x-lane-2-from-0-to-4", "bridge-along-y-lane-0-from-0-to-20"]
        for kind in BuildingKind.allCases {
            for age in Age.allCases {
                for pose in poses {
                    for frame in [-1, 0, 1, 11] { others.append(SpriteKey(.building(kind, age), pose, frame: frame)) }
                }
            }
        }
        for kind in UnitKind.allCases {
            for age in Age.allCases { others.append(SpriteKey(.unit(kind, age), .standing)) }
        }
        for kind in SiteKind.allCases { others.append(SpriteKey(.site(kind), .complete)) }
        others.append(SpriteKey(.outcrop, .complete))
        for terrain in Terrain.allCases { others.append(SpriteKey(.terrain(terrain, variant: 0), .complete)) }
        let outside = others.filter { !batch.contains($0) }
        #expect(outside.count > 1000)
        for key in outside { #expect(Self.source.sprite(key) == nil, "\(key)") }
        let somewhere = BridgePlace(run: .alongX, lane: 0, index: 0, count: 3).pose(complete: true)
        for age in [Age.silicon, .ai] {
            #expect(Self.source.sprite(SpriteKey(.building(.bridge, age), somewhere)) == nil)
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = BridgeSprites(), second = BridgeSprites()
        for key in Self.batch.enumerated().filter({ $0.offset % 7 == 0 }).map(\.element) {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(BridgesPixels(a.base).bytes == BridgesPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(BridgesPixels(maskA).bytes == BridgesPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor, "\(key)")
        }
    }

    /// The pieces of a long bridge in one age are drawn in well under a second.
    @Test func aBridgeRendersQuickly() {
        let fresh = BridgeSprites()
        let places = (0..<16).flatMap { i in (0...1).map { BridgePlace(run: .alongX, lane: $0, index: i, count: 16) } }
        let elapsed = ContinuousClock().measure {
            for place in places { _ = fresh.sprite(SpriteKey(.building(.bridge, .alchemy), place.pose(complete: true))) }
        }
        #expect(elapsed < .seconds(1), "the bridge took \(elapsed)")
    }

    private static func isComplete(_ key: SpriteKey) -> Bool { !key.pose.rawValue.hasSuffix("under-construction") }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct BridgesPixels {
    let width: Int, height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let data = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
        bytes = Array(UnsafeBufferPointer(start: data, count: context.bytesPerRow * height))
    }

    func alpha(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return bytes[(y * width + x) * 4 + 3]
    }

    /// The anchor as a column and a row from the top.
    func place(_ anchor: SpriteAnchor) -> (x: Double, y: Double) {
        (anchor.x * Double(width), (1 - anchor.y) * Double(height))
    }

    /// The smallest box holding every pixel more opaque than `alphaAbove`.
    func bounds(alphaAbove threshold: UInt8) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha(x, y) > threshold {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return maxX < 0 ? nil : (minX, minY, maxX, maxY)
    }
}

/// The pictures for the person's ruling, written to the directory named by the
/// environment variable `BRIDGES_RENDERS`, each file's name ending with
/// `BRIDGES_RENDERS_SUFFIX` where it is set; skipped when `BRIDGES_RENDERS` is
/// not set: a sheet of every age's bridge enlarged, and a scene at game size
/// for each age of a river crossed by two bridges with people and cars on them.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BRIDGES_RENDERS"] != nil))
struct BridgesRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BRIDGES_RENDERS"] ?? "/",
                                isDirectory: true)
    private let suffix = ProcessInfo.processInfo.environment["BRIDGES_RENDERS_SUFFIX"] ?? ""

    /// Lays a bridge of `count` pieces a row from `start` along `run`, both
    /// rows, complete or not (from `built` pieces on, under construction), at
    /// `scale` pixels a point, with its tiles' water under it.
    private func lay(_ context: CGContext, age: Age, run: BridgeRun, count: Int, built: Int, colour: TeamColour,
                     scale: Double, screen: (Double, Double) -> CGPoint, start: GridPoint) throws {
        var pieces: [(GridPoint, BridgePlace)] = []
        for lane in 0...1 {
            for i in 0..<count {
                let tile = run == .alongX ? GridPoint(start.x + i, start.y + lane) : GridPoint(start.x + lane, start.y + i)
                pieces.append((tile, BridgePlace(run: run, lane: lane, index: i, count: count)))
            }
        }
        pieces.sort { ($0.0.x + $0.0.y, $0.1.lane) < ($1.0.x + $1.0.y, $1.1.lane) }
        let canvas = BridgesPiece.canvas.scaled(to: scale)
        for (tile, place) in pieces {
            let piece = BridgesPiece(age: age, place: place, complete: place.index < built)
            let drawn = try #require(piece.render(on: canvas))
            Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: canvas.anchor,
                          at: screen(Double(tile.x) + 0.5, Double(tile.y) + 0.5), in: context)
        }
    }

    /// Each age's bridge at twice game size: five pieces a row along x,
    /// complete, then the same along y with its last two pieces under
    /// construction, on a strip of water.
    @Test func sheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scale = 4.0, k = 2.0
        let width = 3000, rowHeight = 620.0, top = 120.0
        let height = Int(top + rowHeight * Double(BridgesPiece.ages.count))
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128 * k), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The bridge at twice game size: five pieces a row along x, complete; along y, the last two pieces under construction",
                      in: context, at: CGPoint(x: 40, y: Double(height) - 70), size: 30)
        let terrain = TerrainSprites()
        for (r, age) in BridgesPiece.ages.enumerated() {
            let base = Double(height) - top - Double(r) * rowHeight - rowHeight * 0.5
            Preview.label("\(age)", in: context, at: CGPoint(x: 40, y: base + rowHeight * 0.32), size: 28)
            for (j, run) in BridgeRun.allCases.enumerated() {
                let origin = CGPoint(x: 900 + Double(j) * 1350, y: base + 120)
                func screen(_ x: Double, _ y: Double) -> CGPoint {
                    CGPoint(x: origin.x + (x - y) * 64 * k, y: origin.y - (x + y) * 32 * k)
                }
                // The water: the river runs across the bridge, a tile of bank at each end.
                for a in -1...5 {
                    for b in -2...3 {
                        let (x, y) = run == .alongX ? (a, b) : (b, a)
                        let water = (0...4).contains(a)
                        let kind: Terrain = water ? (a == 0 || a == 4 ? .shallowWater : .deepWater) : .grass
                        guard let tile = terrain.sprite(SpriteKey(.terrain(kind, variant: (a * 5 + b * 3 + 40) % TerrainSprites.variantCount), .complete)) else { continue }
                        let at = screen(Double(x) + 0.5, Double(y) + 0.5)
                        context.saveGState()
                        context.scaleBy(x: k, y: k)
                        Preview.place(tile.base, anchor: tile.anchor, at: CGPoint(x: at.x / k, y: at.y / k), in: context)
                        context.restoreGState()
                    }
                }
                try lay(context, age: age, run: run, count: 5, built: run == .alongX ? 5 : 3,
                        colour: .of(j == 0 ? .sumer : .egypt), scale: scale, screen: screen, start: GridPoint(0, 0))
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("bridges-sheet\(suffix).png"))
    }

    /// A river at game size for each age: grass banks, shallow water at its
    /// edges and deep water in its middle, bending from a reach that runs along
    /// y to one that runs along x, crossed by a bridge of six pieces a row
    /// along x and one of five along y, both finished, with people and cars of
    /// the age on each, raised with the deck.
    @Test func riverScenes() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let others = GameSprites()
        let mapWidth = 19, mapHeight = 17
        func isWater(_ x: Int, _ y: Int) -> Bool { x >= 4 && ((x <= 9 && y <= 14) || (y >= 10 && y <= 14)) }
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            guard isWater(x, y) else { return .grass }
            let bank = !isWater(x - 1, y) || !isWater(x + 1, y) || !isWater(x, y - 1) || !isWater(x, y + 1)
            return bank ? .shallowWater : .deepWater
        }
        let terrains = (0..<mapHeight).flatMap { y in (0..<mapWidth).map { x in terrain(x, y) } }
        let alongX = try #require(Placement.bridgeRows(from: GridPoint(3, 4), to: GridPoint(10, 4), width: mapWidth,
                                                        height: mapHeight, terrain: terrains))
        let alongY = try #require(Placement.bridgeRows(from: GridPoint(14, 9), to: GridPoint(14, 15), width: mapWidth,
                                                        height: mapHeight, terrain: terrains))
        #expect(alongX[0].count == 6 && alongY[0].count == 5)
        /// The deck's rise under a point on a bridge, as the drawing raises people (`DrawContext.deckHeight`).
        func lift(_ x: Double, _ y: Double) -> Double {
            if (4.0..<10.0).contains(x), (4.0..<6.0).contains(y) {
                let place = BridgePlace(run: .alongX, lane: 0, index: Int(x) - 4, count: 6)
                let f = x - x.rounded(.down)
                return Double(place.heights.back) + Double(place.heights.front - place.heights.back) * f
            }
            if (10.0..<15.0).contains(y), (14.0..<16.0).contains(x) {
                let place = BridgePlace(run: .alongY, lane: 0, index: Int(y) - 10, count: 5)
                let f = y - y.rounded(.down)
                return Double(place.heights.back) + Double(place.heights.front - place.heights.back) * f
            }
            return 0
        }
        for age in BridgesPiece.ages {
            let width = 2100, height = 1150
            let context = Raster.bitmap(width: width, height: height)!
            let origin = CGPoint(x: 1000, y: -60)
            func screen(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: origin.x + (x - y) * 64, y: Double(height) - (origin.y + (x + y) * 32))
            }
            for y in -12..<(mapHeight + 12) {
                for x in -12..<(mapWidth + 12) {
                    let t = (0..<mapWidth).contains(x) && (0..<mapHeight).contains(y) ? terrain(x, y) : .grass
                    let variant = (x * 7 + y * 3 + 40) % TerrainSprites.variantCount
                    guard let tile = others.sprite(SpriteKey(.terrain(t, variant: variant), .complete)) else { continue }
                    Preview.place(tile.base, anchor: tile.anchor, at: screen(Double(x) + 0.5, Double(y) + 0.5), in: context)
                }
            }
            try lay(context, age: age, run: .alongX, count: 6, built: 6, colour: .of(.sumer), scale: 2, screen: screen,
                    start: GridPoint(4, 4))
            try lay(context, age: age, run: .alongY, count: 5, built: 5, colour: .of(.egypt), scale: 2, screen: screen,
                    start: GridPoint(14, 10))
            // People and cars crossing, a lane each way, and a few on the banks; trees by the water.
            let trader: UnitKind = age == .stone ? .worker : .merchant
            var things: [(SpriteKey, Double, Double, Civilization?, Bool)] = [
                (SpriteKey(.unit(.car, .stone), .walking, frame: 0), 5.4, 5.5, .sumer, false),
                (SpriteKey(.unit(.worker, age), .walking, frame: 2), 7.2, 5.45, .sumer, false),
                (SpriteKey(.unit(trader, age), .walking, frame: 7), 6.6, 4.5, .sumer, true),
                (SpriteKey(.unit(.car, .stone), .walking, frame: 4), 8.6, 4.5, .sumer, true),
                (SpriteKey(.unit(.engineer, age), .walking, frame: 4), 14.5, 10.9, .egypt, true),
                (SpriteKey(.unit(.car, .stone), .walking, frame: 6), 15.5, 12.0, .egypt, false),
                (SpriteKey(.unit(.scholar, age), .standing), 14.45, 13.5, .egypt, false),
                (SpriteKey(.unit(.worker, age), .standing), 2.5, 4.8, .sumer, false),
                (SpriteKey(.site(.tree), .complete), 2.5, 2.5, nil, false),
                (SpriteKey(.site(.tree), .complete), 12.5, 2.5, nil, false),
                (SpriteKey(.site(.tree), .complete), 17.5, 8.5, nil, false),
                (SpriteKey(.site(.tree), .complete), 12.5, 16.5, nil, false),
            ]
            things.sort { ($0.1 + $0.2) < ($1.1 + $1.2) }
            for (key, x, y, civilization, mirrored) in things {
                guard let sprite = others.sprite(key) else { continue }
                let image = civilization.map { Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of($0)) } ?? sprite.base
                var p = screen(x, y)
                p.y += lift(x, y)
                if mirrored {
                    context.saveGState()
                    context.translateBy(x: p.x, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: 0, y: p.y), in: context)
                    context.restoreGState()
                } else {
                    Preview.place(image, anchor: sprite.anchor, at: p, in: context)
                }
            }
            Preview.label("The \(age) age's bridge at game size: six pieces a row along x (Sumer) and five along y (Egypt)",
                          in: context, at: CGPoint(x: 30, y: Double(height) - 50), size: 24)
            try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("bridges-river-\(age)\(suffix).png"))
        }
    }
}
