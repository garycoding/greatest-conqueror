// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import GameCore
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Artwork

/// The ground, the resource sites and the outcrop (`TerrainSprites`).
struct TerrainTests {
    @Test func everyKeyOfTheBatchHasItsSprite() throws {
        let sprites = TerrainSprites()
        #expect(TerrainSprites.keys.count == Terrain.allCases.count * 4 + 6 + 1)
        for key in TerrainSprites.keys {
            let sprite = try #require(sprites.sprite(key), "\(key)")
            #expect(sprite.teamMask == nil, "\(key)")
            if case .terrain = key.subject {
                // The tile's diamond of 64 by 32 points with its ground spread 17/16
                // about its centre: 68 by 34 points, at two pixels a point, its
                // centre the image's.
                #expect(sprite.base.width == 136 && sprite.base.height == 68, "\(key)")
                #expect(sprite.anchor == SpriteAnchor(x: 0.5, y: 0.5), "\(key)")
                continue
            }
            let canvas = try #require(TerrainSprites.canvas(for: key.subject))
            #expect(sprite.base.width == canvas.pixelWidth && sprite.base.height == canvas.pixelHeight, "\(key)")
            #expect(sprite.anchor == canvas.anchor, "\(key)")
            // Standing on the centre of its tile: the anchor is centred across the
            // picture, the drawing's mass stands over it, and nothing solid reaches
            // farther forward than the front corner of the tile's diamond.
            #expect(sprite.anchor.x == 0.5, "\(key)")
            let pixels = TerrainPixels(sprite.base)
            let solid = try #require(pixels.solidBounds(), "\(key)")
            let anchorX = sprite.anchor.x * Double(pixels.width), anchorRow = (1 - sprite.anchor.y) * Double(pixels.height)
            #expect(abs(solid.centreX - anchorX) <= 8 * 2, "\(key)")
            #expect(Double(solid.bottom) <= anchorRow + 16 * 2, "\(key)")
            #expect(Double(solid.top) < anchorRow - 8 * 2, "\(key)")
            #expect(pixels.alpha(Int(anchorX), Int(anchorRow)) > 0, "\(key)")
        }
    }

    @Test func everyOtherKeyIsNil() {
        let sprites = TerrainSprites()
        let ours = Set(TerrainSprites.keys)
        var others = SpriteKey.required(through: .ai).filter { !ours.contains($0) }
        others += [SpriteSubject.terrain(.grass, variant: 4), .terrain(.deepWater, variant: -1), .site(.iron), .site(.oilField)]
            .map { SpriteKey($0, .complete) }
        for key in TerrainSprites.keys {
            others.append(SpriteKey(key.subject, .complete, frame: 1))
            for pose in [SpritePose.standing, .walking, .working, .fighting, .underConstruction] {
                others.append(SpriteKey(key.subject, pose))
            }
        }
        #expect(others.contains { if case .unit = $0.subject { true } else { false } })
        #expect(others.contains { if case .building = $0.subject { true } else { false } })
        for key in others { #expect(sprites.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        for key in TerrainSprites.keys {
            let first = try #require(TerrainSprites.draw(key.subject))
            let second = try #require(TerrainSprites.draw(key.subject))
            #expect(TerrainPixels(first.base).bytes == TerrainPixels(second.base).bytes, "\(key)")
        }
        // The source keeps what it drew, and gives the same picture again.
        let sprites = TerrainSprites()
        let key = SpriteKey(.site(.gold), .complete)
        #expect(sprites.sprite(key)?.base === sprites.sprite(key)?.base)
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            let sprites = TerrainSprites()
            for key in TerrainSprites.keys { _ = sprites.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "\(elapsed)")
    }

    /// Tiles laid as the map lays them leave no pixel uncovered between them:
    /// every pixel inside the patch is opaque.
    @Test func tilesMeetWithoutSeams() throws {
        let sprites = TerrainSprites()
        let scene = TerrainPreview.Scene.standard
        let laid = try #require(TerrainPreview.layTiles(scene, sprites: sprites, margin: 8))
        let pixels = TerrainPixels(laid.image)
        var gaps = 0
        for row in 0..<pixels.height {
            for column in 0..<pixels.width {
                // The map position under the pixel's centre.
                let screen = ScreenPoint(x: (Double(column) + 0.5 - laid.origin.x) / 2,
                                         y: (Double(pixels.height - row) - 0.5 - laid.origin.y) / 2)
                let p = Projection.map(screen)
                let inset = 0.08
                guard p.x > inset, p.y > inset, p.x < Double(scene.width) - inset, p.y < Double(scene.height) - inset else { continue }
                if pixels.alpha(column, row) < 255 { gaps += 1 }
            }
        }
        #expect(gaps == 0)
    }

    /// The four variants of a terrain share its ground right up to their edges,
    /// so that where they meet nothing changes: along the edge, the commonest
    /// colour of every variant is the terrain's own.
    @Test func variantsOfATerrainMeetInOneColour() throws {
        let sprites = TerrainSprites()
        for terrain in Terrain.allCases {
            var colours: [[UInt8]] = []
            for variant in 0..<TerrainSprites.variantCount {
                let sprite = try #require(sprites.sprite(SpriteKey(.terrain(terrain, variant: variant), .complete)))
                let pixels = TerrainPixels(sprite.base)
                var counts: [[UInt8]: Int] = [:]
                for row in 0..<pixels.height {
                    for column in 0..<pixels.width {
                        // Within half a point to a point and a half inside the diamond's edge.
                        let x = (Double(column) + 0.5) / 2 - 34, y = (Double(row) + 0.5) / 2 - 17
                        let inside = (1 - (abs(x) / 32 + abs(y) / 16)) * 14.31
                        guard inside > 0.5, inside < 1.5 else { continue }
                        counts[pixels.colour(column, row), default: 0] += 1
                    }
                }
                let commonest = try #require(counts.max { $0.value < $1.value }?.key)
                colours.append(commonest)
            }
            #expect(Set(colours).count == 1, "\(terrain): \(colours)")
        }
    }

    /// An outcrop is not to be taken for stone to quarry: it is lower, and darker.
    @Test func theOutcropIsLowerAndDarkerThanStone() throws {
        let sprites = TerrainSprites()
        let stone = TerrainPixels(try #require(sprites.sprite(SpriteKey(.site(.stone), .complete))).base)
        let outcrop = TerrainPixels(try #require(sprites.sprite(SpriteKey(.outcrop, .complete))).base)
        let stoneBounds = try #require(stone.solidBounds()), outcropBounds = try #require(outcrop.solidBounds())
        // Both stand on the same canvas, so their rows compare directly: the
        // outcrop rises less than half as high above the ground as the stone.
        let ground = (1 - TerrainSprites.siteCanvas.anchor.y) * Double(stone.height)
        #expect((ground - Double(outcropBounds.top)) * 2 < ground - Double(stoneBounds.top))
        #expect(outcrop.meanLightness() < stone.meanLightness() - 0.25)
    }

    /// Copper, tin and gold stay apart from one another, from stone and from
    /// the outcrop: their solid pixels' average colours lie at least 0.12 apart
    /// (the nearest pair, copper and tin, measured 0.153). A guard against two
    /// drifting together; whether they read apart at a glance is judged by eye.
    @Test func depositsAreToldApart() throws {
        let sprites = TerrainSprites()
        var means: [(String, [Double])] = []
        for (name, subject) in [("stone", SpriteSubject.site(.stone)), ("copper", .site(.copper)), ("tin", .site(.tin)),
                                ("gold", .site(.gold)), ("outcrop", .outcrop)] {
            means.append((name, TerrainPixels(try #require(sprites.sprite(SpriteKey(subject, .complete))).base).meanColour()))
        }
        for i in means.indices {
            for j in means.indices where j > i {
                let a = means[i].1, b = means[j].1
                let distance = (0..<3).map { (a[$0] - b[$0]) * (a[$0] - b[$0]) }.reduce(0, +).squareRoot()
                #expect(distance > 0.12, "\(means[i].0) and \(means[j].0): \(distance)")
            }
        }
    }

    // MARK: Rendering for inspection

    /// Writes the patch of map and the contact sheet for a person to judge, into
    /// the directory named by `ARTWORK_RENDERS`; skipped when it is not set.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] != nil))
    func rendersTheSceneAndTheSheet() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] ?? "/", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = TerrainSprites()
        let scene = try #require(TerrainPreview.scene(.standard, sprites: sprites))
        try TerrainPreview.writePNG(scene, to: directory.appendingPathComponent("terrain-scene.png"))
        let sheet = try #require(TerrainPreview.contactSheet(sprites: sprites))
        try TerrainPreview.writePNG(sheet, to: directory.appendingPathComponent("terrain-contact-sheet.png"))
        let enlarged = try #require(TerrainPreview.enlargedSites())
        try TerrainPreview.writePNG(enlarged, to: directory.appendingPathComponent("terrain-sites-enlarged.png"))
    }
}

/// A picture's pixels, premultiplied RGBA in sRGB, row 0 at the top.
private struct TerrainPixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let data = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        bytes = Array(UnsafeBufferPointer(start: data, count: width * height * 4))
    }

    func alpha(_ column: Int, _ row: Int) -> UInt8 { bytes[(row * width + column) * 4 + 3] }

    func colour(_ column: Int, _ row: Int) -> [UInt8] {
        let i = (row * width + column) * 4
        return [bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]]
    }

    /// The bounds of what is drawn solid (not the soft shadow), in pixels, and its centre across.
    func solidBounds() -> (top: Int, bottom: Int, centreX: Double)? {
        var top = Int.max, bottom = -1, sum = 0.0, count = 0.0
        for row in 0..<height {
            for column in 0..<width where alpha(column, row) >= 200 {
                top = min(top, row); bottom = max(bottom, row)
                sum += Double(column); count += 1
            }
        }
        return count > 0 ? (top, bottom, sum / count) : nil
    }

    /// The average colour, 0 to 1, of what is drawn solid.
    func meanColour() -> [Double] {
        var sum = [0.0, 0.0, 0.0], count = 0.0
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] == 255 {
            for c in 0..<3 { sum[c] += Double(bytes[i + c]) / 255 }
            count += 1
        }
        return sum.map { $0 / max(count, 1) }
    }

    func meanLightness() -> Double {
        let c = meanColour()
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }
}

/// Pictures of the batch for a person to judge.
private enum TerrainPreview {
    /// A patch of map: its terrain, row by row, and what stands on it.
    struct Scene {
        enum Thing { case site(SiteKind), outcrop }
        var rows: [String]
        var things: [(Thing, Int, Int)]
        var width: Int { rows[0].count }
        var height: Int { rows.count }

        func terrain(_ x: Int, _ y: Int) -> Terrain {
            switch Array(rows[y])[x] {
            case "f": .forest
            case "d": .dirt
            case "s": .sand
            case "w": .shallowWater
            case "W": .deepWater
            default: .grass
            }
        }

        /// Twelve tiles square: a river with two fords, a wood, open grass with
        /// deer, a path, and every deposit, with an outcrop beside the stone.
        static let standard: Scene = {
            let rows = [
                "ffffggsWWggg",
                "fffgggsWWsgg",
                "fffgggsWWsgg",
                "ffggdddwwddd",
                "ffggggsWWsgg",
                "fggggsWWwsgg",
                "gggggsWWssgg",
                "ggggsWWwsggg",
                "ggggsWWsgggg",
                "ggdddwwddggg",
                "ggggsWWsgggg",
                "gggssWWssggg",
            ]
            var things: [(Thing, Int, Int)] = []
            let felled: Set<[Int]> = [[2, 1], [1, 3]]
            for (y, row) in rows.enumerated() {
                for (x, c) in row.enumerated() where c == "f" && !felled.contains([x, y]) { things.append((.site(.tree), x, y)) }
            }
            things += [(.site(.prey), 4, 1), (.site(.prey), 5, 2), (.site(.prey), 3, 6),
                       (.site(.stone), 10, 0), (.site(.stone), 11, 1), (.outcrop, 10, 4), (.outcrop, 11, 4),
                       (.site(.copper), 1, 7), (.site(.copper), 1, 8), (.site(.tin), 2, 10), (.site(.gold), 10, 9)]
            return Scene(rows: rows, things: things)
        }()
    }

    /// The variant the map shows on a tile (MapDrawing's `TerrainLayer`).
    static func variant(_ x: Int, _ y: Int, count: Int) -> Int {
        (((x &* 73_856_093) ^ (y &* 19_349_663)) & 0x7fff_ffff) % count
    }

    /// The patch's tiles laid in isometric order on a transparent bitmap at two
    /// pixels a point, `margin` points around it; and the pixel, from the
    /// bottom left, of the map's origin.
    static func layTiles(_ scene: Scene, sprites: TerrainSprites, margin: Double, above: Double = 0,
                         background: CGColor? = nil) -> (image: CGImage, origin: CGPoint, context: CGContext)? {
        let span = Double(scene.width + scene.height)
        let width = Int((span * 32 + 2 * margin) * 2), height = Int((span * 16 + 2 * margin + above) * 2)
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        if let background { context.setFillColor(background); context.fill(CGRect(x: 0, y: 0, width: width, height: height)) }
        let origin = CGPoint(x: (margin + Double(scene.height) * 32) * 2, y: Double(height) - (margin + above) * 2)
        var tiles: [(Int, Int)] = []
        for y in 0..<scene.height { for x in 0..<scene.width { tiles.append((x, y)) } }
        tiles.sort { ($0.0 + $0.1, $0.0) < ($1.0 + $1.1, $1.0) }
        for (x, y) in tiles {
            let key = SpriteKey(.terrain(scene.terrain(x, y), variant: variant(x, y, count: TerrainSprites.variantCount)), .complete)
            guard let sprite = sprites.sprite(key) else { return nil }
            place(sprite, at: GridPoint(x, y).centre, origin: origin, in: context)
        }
        guard let image = context.makeImage() else { return nil }
        return (image, origin, context)
    }

    /// Draws a sprite with its anchor on a map position.
    static func place(_ sprite: SpriteImage, at position: MapPosition, origin: CGPoint, in context: CGContext) {
        let s = Projection.screen(position)
        let w = Double(sprite.base.width), h = Double(sprite.base.height)
        let x = origin.x + s.x * 2 - sprite.anchor.x * w, y = origin.y + s.y * 2 - sprite.anchor.y * h
        context.draw(sprite.base, in: CGRect(x: x, y: y, width: w, height: h))
    }

    /// The patch at game size, as the map draws it: the ground, then the sites
    /// in order of depth, on the dark of ground not yet explored.
    static func scene(_ scene: Scene, sprites: TerrainSprites) -> CGImage? {
        let dark = CGColor(srgbRed: 0x2a / 255.0, green: 0x24 / 255.0, blue: 0x20 / 255.0, alpha: 1)
        guard let laid = layTiles(scene, sprites: sprites, margin: 24, above: 90, background: dark) else { return nil }
        let things = scene.things.sorted { ($0.1 + $0.2, $0.1) < ($1.1 + $1.2, $1.1) }
        for (thing, x, y) in things {
            let subject: SpriteSubject = switch thing {
            case .site(let kind): .site(kind)
            case .outcrop: .outcrop
            }
            guard let sprite = sprites.sprite(SpriteKey(subject, .complete)) else { return nil }
            place(sprite, at: GridPoint(x, y).centre, origin: laid.origin, in: laid.context)
        }
        return laid.context.makeImage()
    }

    /// Every sprite alone, at game size, named.
    static func contactSheet(sprites: TerrainSprites) -> CGImage? {
        let width = 1240, height = 1060
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0xef / 255.0, green: 0xe0 / 255.0, blue: 0xc2 / 255.0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let names: [Terrain: String] = [.grass: "grass", .dirt: "dirt", .sand: "sand", .forest: "forest",
                                        .shallowWater: "shallow water", .deepWater: "deep water"]
        label("Terrain: four variants each, at game size", in: context, at: CGPoint(x: 30, y: height - 46), size: 22)
        for (row, terrain) in Terrain.allCases.enumerated() {
            let y = Double(height - 130 - row * 96)
            label(names[terrain] ?? "", in: context, at: CGPoint(x: 30, y: y + 22), size: 18)
            for variant in 0..<TerrainSprites.variantCount {
                guard let sprite = sprites.sprite(SpriteKey(.terrain(terrain, variant: variant), .complete)) else { return nil }
                context.draw(sprite.base, in: CGRect(x: 200 + variant * 168, y: Int(y), width: 128, height: 64))
            }
        }
        label("Sites and the outcrop, at game size", in: context, at: CGPoint(x: 30, y: 352), size: 22)
        let subjects: [(String, SpriteSubject)] = [("tree", .site(.tree)), ("prey", .site(.prey)), ("stone", .site(.stone)),
                                                   ("copper", .site(.copper)), ("tin", .site(.tin)), ("gold", .site(.gold)),
                                                   ("outcrop", .outcrop)]
        for (i, (name, subject)) in subjects.enumerated() {
            guard let sprite = sprites.sprite(SpriteKey(subject, .complete)) else { return nil }
            let cx = 100.0 + Double(i) * 170, ground = 90.0
            let w = Double(sprite.base.width), h = Double(sprite.base.height)
            context.draw(sprite.base, in: CGRect(x: cx - sprite.anchor.x * w, y: ground - sprite.anchor.y * h, width: w, height: h))
            label(name, in: context, at: CGPoint(x: cx - 30, y: 24), size: 18)
        }
        return context.makeImage()
    }

    /// The sites and the outcrop drawn three times larger than the game draws
    /// them, from the same SVG, side by side on grass.
    static func enlargedSites() -> CGImage? {
        let subjects: [SpriteSubject] = [.site(.tree), .site(.prey), .site(.stone), .site(.copper), .site(.tin), .site(.gold), .outcrop]
        let scale = 6.0, cell = 72 * scale
        let width = Int(cell) * 4, height = Int(124 * scale + 80 * scale)
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0xef / 255.0, green: 0xe0 / 255.0, blue: 0xc2 / 255.0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (i, subject) in subjects.enumerated() {
            guard let tile = TerrainSprites.draw(.terrain(.grass, variant: 0), pixelsPerPoint: scale),
                  let sprite = TerrainSprites.draw(subject, pixelsPerPoint: scale) else { return nil }
            let row = i < 4 ? 0 : 1, column = i < 4 ? i : i - 4
            let cx = (Double(column) + 0.5) * cell + (row == 1 ? cell / 2 : 0)
            let ground = row == 0 ? Double(height) - 108 * scale : 24 * scale
            for (image, anchor) in [(tile.base, tile.anchor), (sprite.base, sprite.anchor)] {
                let w = Double(image.width), h = Double(image.height)
                context.draw(image, in: CGRect(x: cx - anchor.x * w, y: ground - anchor.y * h, width: w, height: h))
            }
        }
        return context.makeImage()
    }

    /// Text in Futura, as the reference sheets have it.
    static func label(_ text: String, in context: CGContext, at point: CGPoint, size: Double) {
        let font = NSFont(name: "Futura-Medium", size: size) ?? NSFont.systemFont(ofSize: size)
        let ink = NSColor(srgbRed: 0x2a / 255.0, green: 0x24 / 255.0, blue: 0x20 / 255.0, alpha: 1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink]).draw(at: point)
        NSGraphicsContext.restoreGraphicsState()
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
