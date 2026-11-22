// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the Stone age's boats' art for a person to judge, into the
/// directory named by the environment variable `BOATS_RENDERS`, each file's
/// name ending with `BOATS_RENDERS_SUFFIX` where it is set, so that a round of
/// corrections keeps the earlier renders; skipped when `BOATS_RENDERS` is not
/// set. The sheets are PNG, the movement animated GIF at 12 frames a second,
/// all on the game's own water and ground tiles, in Sumer's colour.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BOATS_RENDERS"] != nil))
struct StoneBoatsRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BOATS_RENDERS"] ?? "/", isDirectory: true)
    private let suffix = ProcessInfo.processInfo.environment["BOATS_RENDERS_SUFFIX"] ?? ""
    private let colour = TeamColour.of(.sumer)
    private static let tiles = TerrainSprites()

    // MARK: Laying the map

    /// Where a map position falls in the picture, at `scale` times the
    /// sprites' own pixels, with the map's origin at `origin` (pixels, the
    /// picture's origin at its bottom left).
    static func screen(_ x: Double, _ y: Double, origin: CGPoint, scale: Double) -> CGPoint {
        CGPoint(x: origin.x + (x - y) * 64 * scale, y: origin.y - (x + y) * 32 * scale)
    }

    /// The tiles of the map from `-reach` to `reach` on each axis, laid as the
    /// projection lays them, each of the terrain `terrain` gives it.
    static func lay(_ terrain: (Int, Int) -> Terrain, reach: Int, origin: CGPoint, scale: Double, in context: CGContext) throws {
        for y in -reach...reach {
            for x in -reach...reach {
                let key = SpriteKey(.terrain(terrain(x, y), variant: ((x * 3 + y * 5) % 4 + 4) % 4), .complete)
                let sprite = try #require(tiles.sprite(key))
                Preview.place(sprite.base, anchor: sprite.anchor, at: screen(Double(x) + 0.5, Double(y) + 0.5, origin: origin, scale: scale),
                              in: context, scale: scale)
            }
        }
    }

    /// A picture covered with one terrain's tiles.
    static func water(_ terrain: Terrain = .shallowWater, width: Int, height: Int, scale: Double) throws -> CGContext {
        let context = Raster.bitmap(width: width, height: height)!
        let reach = Int(Double(width + height) / (32 * scale)) + 2
        try lay({ _, _ in terrain }, reach: reach, origin: CGPoint(x: Double(width) / 2, y: Double(height) / 2), scale: scale, in: context)
        return context
    }

    private func write(_ image: CGImage, _ name: String) throws {
        let url = directory.appendingPathComponent("\(name)\(suffix).png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Preview.writePNG(image, to: url)
    }

    private func writeGIF(_ frames: [CGImage], _ name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(name)\(suffix).gif"))
    }

    // MARK: The boat house

    /// The boat house, complete and under construction, enlarged on its
    /// trodden ground, and at game size beside the Stone age's house.
    @Test func boatHouse() throws {
        let width = 1600, height = 900
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = StoneBuildingSprites()
        for (i, complete) in [true, false].enumerated() {
            let key = SpriteKey(.building(.boatHouse, .stone), complete ? .complete : .underConstruction)
            let piece = try #require(StoneBuildingsPiece(key))
            let large = piece.canvas.scaled(to: 4.4)
            let drawn = try #require(Raster.render(on: large) { svg in
                var sketch = StoneBuildingsSketch(layer: svg.layer)
                sketch.boatHouse(complete: complete)
                svg = sketch.svg
            })
            Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                          at: CGPoint(x: 330 + Double(i) * 640, y: 330), in: context)
            Preview.label(complete ? "complete" : "under construction", in: context, at: CGPoint(x: 230 + Double(i) * 640, y: 40), size: 24)
            let sprite = try #require(source.sprite(key))
            Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor,
                          at: CGPoint(x: 1420, y: 520 - Double(i) * 330), in: context)
        }
        let house = try #require(source.sprite(SpriteKey(.building(.house, .stone), .complete)))
        Preview.place(Preview.tinted(base: house.base, mask: house.teamMask, colour: colour), anchor: house.anchor,
                      at: CGPoint(x: 1420, y: 760), in: context)
        Preview.label("at game size, the house above for scale", in: context, at: CGPoint(x: 1260, y: 40), size: 16)
        Preview.label("The Stone age's boat house, in Sumer's colour", in: context, at: CGPoint(x: 28, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house")
    }

    /// The boat house seen from the side and from behind, complete and under
    /// construction, enlarged on its trodden ground, and each at game size.
    @Test func boatHouseBack() throws {
        let width = 1500, height = 1160
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = StoneBuildingSprites()
        for (row, complete) in [true, false].enumerated() {
            for (column, back) in [false, true].enumerated() {
                let view: SpriteView = back ? .back : .side
                let key = SpriteKey(.building(.boatHouse, .stone), complete ? .complete : .underConstruction, view: view)
                let piece = try #require(StoneBuildingsPiece(key))
                let large = piece.canvas.scaled(to: 3.4)
                let drawn = try #require(Raster.render(on: large) { svg in
                    var sketch = StoneBuildingsSketch(layer: svg.layer)
                    if back { sketch.boatHouseBack(complete: complete) } else { sketch.boatHouse(complete: complete) }
                    svg = sketch.svg
                })
                let y = Double(height) - 140 - Double(row) * 520
                Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                              at: CGPoint(x: 260 + Double(column) * 500, y: y - 330), in: context)
                Preview.label("\(view.rawValue), \(complete ? "complete" : "under construction")", in: context,
                              at: CGPoint(x: 120 + Double(column) * 500, y: y - 440), size: 20)
                let sprite = try #require(source.sprite(key))
                Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor,
                              at: CGPoint(x: 1160 + Double(column) * 190, y: y - 260), in: context)
            }
        }
        Preview.label("at game size", in: context, at: CGPoint(x: 1180, y: 60), size: 16)
        Preview.label("The Stone age's boat house from the side (water to the lower right) and from behind (water to the upper right)",
                      in: context, at: CGPoint(x: 28, y: Double(height) - 44), size: 20)
        try write(context.makeImage()!, "boat-house-back")
    }

    /// A lake at play size with a boat house on each of its four sides, each
    /// facing the water as the game draws it: the edge from
    /// `Placement.waterEdge`, the view and the mirror from
    /// `FootprintEdge.boatHouseView`, the sprite from `GameSprites`; complete,
    /// and under construction.
    @Test func boatHouseFacings() throws {
        let sprites = GameSprites()
        let (mapWidth, mapHeight) = (18, 18)
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            guard (6...11).contains(x), (6...11).contains(y) else { return .grass }
            return (8...9).contains(x) && (8...9).contains(y) ? .deepWater : .shallowWater
        }
        let grid = (0..<mapHeight).flatMap { y in (0..<mapWidth).map { x in terrain(x, y) } }
        // One footprint at the middle of each side of the lake, each touching the water along one edge.
        let origins = [GridPoint(4, 8), GridPoint(8, 4), GridPoint(8, 12), GridPoint(12, 8)]
        let edges = origins.map { Placement.waterEdge(.boatHouse, at: $0, width: mapWidth, height: mapHeight, terrain: grid) }
        try #require(Set(edges) == Set(FootprintEdge.allCases), "\(edges)")
        let width = 1500, height = 1000
        let origin = CGPoint(x: Double(width) / 2, y: Double(height) / 2 + 18 * 32)
        let background = Raster.bitmap(width: width, height: height)!
        try Self.lay(terrain, reach: 26, origin: origin, scale: 1, in: background)
        let ground = background.makeImage()!
        for complete in [true, false] {
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
            let placed = zip(origins, edges).map { (origin: $0, edge: $1) }
                .sorted { $0.origin.x + $0.origin.y < $1.origin.x + $1.origin.y }
            for (tile, edge) in placed {
                let (view, mirrored) = edge.boatHouseView
                let key = SpriteKey(.building(.boatHouse, .stone), complete ? .complete : .underConstruction, view: view)
                let sprite = try #require(sprites.sprite(key), "\(key)")
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                let centre = Placement.centre(.boatHouse, origin: tile)
                let at = Self.screen(centre.x, centre.y, origin: origin, scale: 1)
                context.saveGState()
                if mirrored {
                    context.translateBy(x: at.x * 2, y: 0)
                    context.scaleBy(x: -1, y: 1)
                }
                Preview.place(image, anchor: sprite.anchor, at: at, in: context)
                context.restoreGState()
                let name = "\(edge): \(view.rawValue)\(mirrored ? ", mirrored" : "")"
                Preview.label(name, in: context, at: CGPoint(x: at.x - 70, y: at.y - 60), size: 15, colour: .white)
            }
            Preview.label("At play size: a boat house on each side of a lake, \(complete ? "complete" : "under construction"), each facing the water",
                          in: context, at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            try write(context.makeImage()!, complete ? "boat-house-facings" : "boat-house-facings-under-construction")
        }
    }

    // MARK: The dugout

    /// Each of the dugout's poses in each view, its 12 frames enlarged in
    /// rows of six, for looking at frame by frame.
    @Test func dugoutStrips() throws {
        let large = StoneDugout.canvas.scaled(to: 3)
        let cellW = large.pixelWidth, cellH = large.pixelHeight
        for pose in [SpritePose.standing, .walking, .working] {
            let width = cellW * 6, height = cellH * 2 * SpriteView.allCases.count
            let context = try Self.water(width: width, height: height, scale: 2.4)
            for (v, view) in SpriteView.allCases.enumerated() {
                for frame in 0..<12 {
                    let drawn = try #require(StoneDugout.render(pose, frame: frame, view: view, canvas: large))
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    let x = Double(frame % 6 * cellW), y = Double(height - (v * 2 + frame / 6 + 1) * cellH)
                    context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(view.rawValue) \(frame)", in: context, at: CGPoint(x: x + 6, y: y + 6), size: 16)
                }
            }
            try write(context.makeImage()!, "strips/dugout-\(pose.rawValue)")
        }
    }

    /// One animated GIF for each pose: the five views side by side, drawn
    /// large from the same drawing, and beneath them the sprites at game size,
    /// the views toward the left mirrored as the drawing mirrors them.
    @Test func dugoutAnimations() throws {
        let scale = 2.2
        let large = StoneDugout.canvas.scaled(to: Canvas.person.pixelsPerUnit * scale)
        let source = StoneBoatSprites()
        let width = 1700, height = 760
        let background = try Self.water(width: width, height: height, scale: 1.6).makeImage()!
        let names: [SpritePose: String] = [.standing: "standing: riding the water", .walking: "walking: paddling",
                                           .working: "working: spearing fish, or prodding at a rock"]
        for pose in [SpritePose.standing, .walking, .working] {
            var frames: [CGImage] = []
            for i in 0..<24 {
                let frame = i % 12
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
                for (v, view) in SpriteView.allCases.enumerated() {
                    let drawn = try #require(StoneDugout.render(pose, frame: frame, view: view, canvas: large))
                    Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                                  at: CGPoint(x: 180 + Double(v) * 335, y: 400), in: context)
                    Preview.label(view.rawValue, in: context, at: CGPoint(x: 120 + Double(v) * 335, y: 300), size: 18)
                    // At game size: the view, and beside it the same view mirrored, as for a facing toward the left.
                    let sprite = try #require(source.sprite(SpriteKey(.unit(.boat, .stone), pose, frame: frame, view: view)))
                    let tinted = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 120 + Double(v) * 335, y: 120), in: context)
                    context.saveGState()
                    context.translateBy(x: 240 + Double(v) * 335, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 0, y: 120), in: context)
                    context.restoreGState()
                }
                Preview.label("The Stone age's dugout, in Sumer's colour: \(names[pose]!), 12 frames a second", in: context,
                              at: CGPoint(x: 28, y: Double(height) - 48), size: 24)
                Preview.label("at game size, each view and its mirror", in: context, at: CGPoint(x: 28, y: 24), size: 16)
                frames.append(context.makeImage()!)
            }
            try writeGIF(frames, "dugout-\(pose.rawValue)")
        }
    }

    // MARK: The water

    /// The fish's 12 frames and the five rocks afloat, enlarged twice, on
    /// shallow and on deep water.
    @Test func waterSheets() throws {
        let source = StoneBoatSprites()
        let canvas = TerrainSprites.siteCanvas
        let scale = 2.0
        let cellW = Int(Double(canvas.pixelWidth) * scale), cellH = Int(Double(canvas.pixelHeight) * scale)
        let columns = 6
        for water in [Terrain.shallowWater, .deepWater] {
            let width = cellW * columns, height = cellH * 3
            let context = try Self.water(water, width: width, height: height, scale: scale)
            var subjects: [(SpriteKey, String)] = (0..<12).map { (SpriteKey(.site(.fish), .complete, frame: $0), "fish \($0)") }
            subjects += StoneBoatSprites.rocks.map { (SpriteKey(.site($0), .afloat), "\($0) afloat") }
            for (i, (key, label)) in subjects.enumerated() {
                let sprite = try #require(source.sprite(key), "\(key)")
                let x = Double(i % columns * cellW), y = Double(height - (i / columns + 1) * cellH)
                Preview.place(sprite.base, anchor: sprite.anchor, at: CGPoint(x: x + Double(cellW) / 2, y: y + Double(cellH) * 0.3),
                              in: context, scale: scale)
                Preview.label(label, in: context, at: CGPoint(x: x + 6, y: y + 6), size: 14)
            }
            try write(context.makeImage()!, "water-\(water)")
        }
    }

    /// The five rocks afloat beside the same rocks on land, at game size and enlarged.
    @Test func rocksAfloat() throws {
        let width = 1700, height = 560
        let context = Raster.bitmap(width: width, height: height)!
        let sprites = GameSprites()
        try Self.lay({ x, y in x + y < 0 ? .grass : .shallowWater }, reach: 14, origin: CGPoint(x: Double(width) / 2, y: Double(height) / 2 + 40),
                     scale: 1, in: context)
        for (i, kind) in StoneBoatSprites.rocks.enumerated() {
            let afloat = try #require(sprites.sprite(SpriteKey(.site(kind), .afloat)))
            let land = try #require(sprites.sprite(SpriteKey(.site(kind), .complete)))
            Preview.place(afloat.base, anchor: afloat.anchor, at: CGPoint(x: 160 + Double(i) * 290, y: 120), in: context, scale: 1.6)
            Preview.place(afloat.base, anchor: afloat.anchor, at: CGPoint(x: 230 + Double(i) * 290, y: 300), in: context)
            Preview.place(land.base, anchor: land.anchor, at: CGPoint(x: 100 + Double(i) * 290, y: 430), in: context)
            Preview.label("\(kind)", in: context, at: CGPoint(x: 120 + Double(i) * 290, y: 20), size: 18)
        }
        // The outcrop, a deposit not yet revealed, rising from the water between the rows.
        let outcrop = try #require(sprites.sprite(SpriteKey(.outcrop, .afloat)))
        Preview.place(outcrop.base, anchor: outcrop.anchor, at: CGPoint(x: 1600, y: 300), in: context)
        Preview.label("outcrop", in: context, at: CGPoint(x: 1560, y: 20), size: 18)
        Preview.label("Rocks rising from the water (afloat), and on land above them", in: context,
                      at: CGPoint(x: 24, y: Double(height) - 40), size: 22)
        try write(context.makeImage()!, "rocks-afloat")
    }

    /// The fish leaping, as an animated GIF: a shoal of two tiles by two,
    /// each tile's frame run ahead as the drawing runs it (`5x + 3y`), large and at game size.
    @Test func fishAnimation() throws {
        let source = StoneBoatSprites()
        let width = 1300, height = 620
        var frames: [CGImage] = []
        let shoal = [(10, 6), (11, 6), (10, 7), (11, 7)]
        for i in 0..<24 {
            let frame = i % 12
            let context = try Self.water(width: width, height: height, scale: 1.8)
            for (scale, centre) in [(1.8, CGPoint(x: 420, y: 330)), (0.5, CGPoint(x: 1080, y: 330))] {
                for (x, y) in shoal {
                    let shown = (frame + ((5 * x + 3 * y) % 12)) % 12
                    let sprite = try #require(source.sprite(SpriteKey(.site(.fish), .complete, frame: shown)))
                    let at = Self.screen(Double(x - 10) + 0.5, Double(y - 6) + 0.5, origin: CGPoint(x: centre.x, y: centre.y + 64 * scale),
                                         scale: scale)
                    Preview.place(sprite.base, anchor: sprite.anchor, at: at, in: context, scale: scale)
                }
            }
            Preview.label("A shoal of fish, two tiles by two, each tile's leap offset from its neighbours'", in: context,
                          at: CGPoint(x: 24, y: Double(height) - 44), size: 22)
            Preview.label("at game size", in: context, at: CGPoint(x: 1020, y: 40), size: 16)
            frames.append(context.makeImage()!)
        }
        try writeGIF(frames, "fish")
    }

    // MARK: At play size

    /// A stretch of shore at game size: the boat house on land beside the
    /// water, a shoal, the five rocks afloat, and dugouts paddling, standing
    /// and spearing fish, drawn in increasing depth as the map draws them;
    /// as a PNG of its first frame and as an animated GIF.
    @Test func shore() throws {
        let sprites = GameSprites()
        let width = 1700, height = 980
        let origin = CGPoint(x: 850, y: 900)
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            if x <= 3 && y <= 9 { return x == 3 ? .sand : .grass }
            return x + y > 14 ? .deepWater : .shallowWater
        }
        let ground = Raster.bitmap(width: width, height: height)!
        try Self.lay(terrain, reach: 16, origin: origin, scale: 1, in: ground)
        let background = ground.makeImage()!
        struct Thing { var depth: Double; var key: SpriteKey; var at: (Double, Double); var mirrored: Bool; var offset: Bool }
        var things: [Thing] = [Thing(depth: 6, key: SpriteKey(.building(.boatHouse, .stone), .complete), at: (3, 3), mirrored: false, offset: false),
                               Thing(depth: 12, key: SpriteKey(.building(.boatHouse, .stone), .underConstruction), at: (3, 9), mirrored: false, offset: false)]
        for (x, y) in [(6, 1), (7, 1), (6, 2), (7, 2)] {
            things.append(Thing(depth: Double(x + y) + 1, key: SpriteKey(.site(.fish), .complete), at: (Double(x) + 0.5, Double(y) + 0.5),
                                mirrored: false, offset: true))
        }
        for (i, (x, y)) in [(5, 5), (7, 4), (9, 6), (6, 8), (8, 9)].enumerated() {
            things.append(Thing(depth: Double(x + y) + 1, key: SpriteKey(.site(StoneBoatSprites.rocks[i]), .afloat),
                                at: (Double(x) + 0.5, Double(y) + 0.5), mirrored: false, offset: false))
        }
        let boats: [(SpritePose, SpriteView, Bool, Double, Double)] = [
            (.walking, .side, false, 4.6, 3.6), (.working, .frontQuarter, false, 8.4, 2.0), (.standing, .backQuarter, true, 5.4, 7.0),
            (.walking, .front, false, 9.2, 4.0), (.walking, .back, false, 4.8, 10.6), (.working, .side, true, 7.6, 7.6),
        ]
        for (pose, view, mirrored, x, y) in boats {
            things.append(Thing(depth: x + y, key: SpriteKey(.unit(.boat, .stone), pose, view: view), at: (x, y), mirrored: mirrored, offset: false))
        }
        things.sort { $0.depth < $1.depth }
        var frames: [CGImage] = []
        for i in 0..<24 {
            let frame = i % 12
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
            for thing in things {
                var key = thing.key
                if thing.offset {
                    let (tx, ty) = (Int(thing.at.0), Int(thing.at.1))
                    key.frame = (frame + ((5 * tx + 3 * ty) % 12)) % 12
                } else if case .unit = key.subject {
                    key.frame = frame
                }
                let sprite = try #require(sprites.sprite(key), "\(key)")
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                let at = Self.screen(thing.at.0, thing.at.1, origin: origin, scale: 1)
                if thing.mirrored {
                    context.saveGState()
                    context.translateBy(x: at.x * 2, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(image, anchor: sprite.anchor, at: at, in: context)
                    context.restoreGState()
                } else {
                    Preview.place(image, anchor: sprite.anchor, at: at, in: context)
                }
            }
            Preview.label("At play size (zoom 1, two pixels a point): the boat house, a shoal, rocks afloat, and dugouts", in: context,
                          at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            frames.append(context.makeImage()!)
        }
        try write(frames[0], "shore")
        try writeGIF(frames, "shore")
    }
}
