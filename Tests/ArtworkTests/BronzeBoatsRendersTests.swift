// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the Bronze age's boats' art for a person to judge, into the
/// directory named by the environment variable `BOATS_RENDERS`, each file's
/// name ending with `BOATS_RENDERS_SUFFIX` where it is set; skipped when
/// `BOATS_RENDERS` is not set. The sheets are PNG, the movement animated GIF
/// at 12 frames a second, all on the game's own water and ground tiles, in
/// Sumer's colour. The map is laid as the Stone age's renders lay it
/// (`StoneBoatsRenders`).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BOATS_RENDERS"] != nil))
struct BronzeBoatsRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BOATS_RENDERS"] ?? "/", isDirectory: true)
    private let suffix = ProcessInfo.processInfo.environment["BOATS_RENDERS_SUFFIX"] ?? ""
    private let colour = TeamColour.of(.sumer)

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
    /// ground, and at game size beside the Bronze age's house.
    @Test func boatHouse() throws {
        let width = 1600, height = 900
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = BronzeBuildingSprites()
        for (i, complete) in [true, false].enumerated() {
            let key = SpriteKey(.building(.boatHouse, .bronze), complete ? .complete : .underConstruction)
            let large = BronzeBuildingsArt.canvas(.boatHouse).scaled(to: 4.4)
            let drawn = try #require(Raster.render(on: large) { svg in
                var painter = BronzeBuildingsPainter(layer: svg.layer)
                painter.boatHouse(complete: complete)
                svg = painter.svg
            })
            Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                          at: CGPoint(x: 330 + Double(i) * 640, y: 330), in: context)
            Preview.label(complete ? "complete" : "under construction", in: context, at: CGPoint(x: 230 + Double(i) * 640, y: 40), size: 24)
            let sprite = try #require(source.sprite(key))
            Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor,
                          at: CGPoint(x: 1420, y: 520 - Double(i) * 330), in: context)
        }
        let house = try #require(source.sprite(SpriteKey(.building(.house, .bronze), .complete)))
        Preview.place(Preview.tinted(base: house.base, mask: house.teamMask, colour: colour), anchor: house.anchor,
                      at: CGPoint(x: 1420, y: 760), in: context)
        Preview.label("at game size, the house above for scale", in: context, at: CGPoint(x: 1260, y: 40), size: 16)
        Preview.label("The Bronze age's boat house, in Sumer's colour", in: context, at: CGPoint(x: 28, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house")
    }

    /// The boat house's back view, complete and under construction, enlarged
    /// beside its side view, and beneath each the four ways the game draws it
    /// at game size: the side, the side mirrored, the back, and the back mirrored.
    @Test func boatHouseBack() throws {
        let width = 2240, height = 1020
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = GameSprites()
        let large = BronzeBuildingsArt.canvas(.boatHouse).scaled(to: 3)
        for (row, complete) in [true, false].enumerated() {
            let y = 640 - Double(row) * 460
            for (column, back) in [false, true].enumerated() {
                let drawn = try #require(Raster.render(on: large) { svg in
                    var painter = BronzeBuildingsPainter(layer: svg.layer)
                    if back { painter.boatHouseFromBehind(complete: complete) } else { painter.boatHouse(complete: complete) }
                    svg = painter.svg
                })
                Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                              at: CGPoint(x: 230 + Double(column) * 480, y: y), in: context)
                Preview.label("\(back ? "back" : "side"), \(complete ? "complete" : "under construction")", in: context,
                              at: CGPoint(x: 130 + Double(column) * 480, y: y - 150), size: 20)
            }
            for (i, edge) in [FootprintEdge.plusX, .plusY, .minusY, .minusX].enumerated() {
                let (view, mirrored) = edge.boatHouseView
                let key = SpriteKey(.building(.boatHouse, .bronze), complete ? .complete : .underConstruction, view: view)
                let sprite = try #require(source.sprite(key))
                let at = CGPoint(x: 1110 + Double(i) * 300, y: y + 40)
                Self.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor, at: at,
                           mirrored: mirrored, in: context)
                Preview.label("\(view.rawValue)\(mirrored ? " mirrored" : ""): \(edge)", in: context, at: CGPoint(x: at.x - 80, y: y - 110),
                              size: 16)
            }
        }
        Preview.label("The Bronze age's boat house from behind, beside its side view; at game size, the four ways it is drawn",
                      in: context, at: CGPoint(x: 28, y: Double(height) - 48), size: 24)
        try write(context.makeImage()!, "boat-house-back")
    }

    /// Four boat houses at play size round a lake, one on each edge, each
    /// drawn as the game draws it for the edge of its footprint that touches
    /// the water (`Placement.waterEdge`, `FootprintEdge.boatHouseView`): one
    /// picture complete, one under construction.
    @Test func boatHousesRoundALake() throws {
        let sprites = GameSprites()
        let size = 14
        var terrain = [Terrain](repeating: .grass, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let lake = (4...9).contains(x) && (4...9).contains(y)
                let shore = (3...10).contains(x) && (3...10).contains(y)
                let deep = (5...8).contains(x) && (5...8).contains(y)
                terrain[y * size + x] = deep ? .deepWater : lake ? .shallowWater : shore ? .sand : .grass
            }
        }
        let width = 1500, height = 900
        let origin = CGPoint(x: 750, y: 900)
        let ground = Raster.bitmap(width: width, height: height)!
        try StoneBoatsRenders.lay({ x, y in (0..<size).contains(x) && (0..<size).contains(y) ? terrain[y * size + x] : .grass },
                                  reach: 30, origin: origin, scale: 1, in: ground)
        let background = ground.makeImage()!
        // One boat house beside each edge of the lake, by its footprint's origin.
        let origins = [GridPoint(2, 6), GridPoint(6, 2), GridPoint(6, 10), GridPoint(10, 6)]
        for complete in [true, false] {
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
            for o in origins.sorted(by: { $0.x + $0.y < $1.x + $1.y }) {
                let edge = Placement.waterEdge(.boatHouse, at: o, width: size, height: size, terrain: terrain)
                let (view, mirrored) = edge.boatHouseView
                let key = SpriteKey(.building(.boatHouse, .bronze), complete ? .complete : .underConstruction, view: view)
                let sprite = try #require(sprites.sprite(key))
                let at = StoneBoatsRenders.screen(Double(o.x) + 1, Double(o.y) + 1, origin: origin, scale: 1)
                Self.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor, at: at,
                           mirrored: mirrored, in: context)
                Preview.label("\(edge): \(view.rawValue)\(mirrored ? " mirrored" : "")", in: context,
                              at: CGPoint(x: at.x - 70, y: at.y - 100), size: 16, colour: .white)
            }
            Preview.label("At play size: four Bronze boat houses\(complete ? "" : " under construction"), each facing the lake from its edge",
                          in: context, at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            try write(context.makeImage()!, complete ? "boat-houses-round-a-lake" : "boat-houses-round-a-lake-rising")
        }
    }

    /// Places an image by its anchor, mirrored about the anchor where `mirrored`, as the drawing mirrors it.
    private static func place(_ image: CGImage, anchor: SpriteAnchor, at: CGPoint, mirrored: Bool, in context: CGContext) {
        guard mirrored else { return Preview.place(image, anchor: anchor, at: at, in: context) }
        context.saveGState()
        context.translateBy(x: at.x * 2, y: 0)
        context.scaleBy(x: -1, y: 1)
        Preview.place(image, anchor: anchor, at: at, in: context)
        context.restoreGState()
    }

    // MARK: The reed boat

    /// Each of the reed boat's poses in each view, its 12 frames enlarged in
    /// rows of six, for looking at frame by frame.
    @Test func reedBoatStrips() throws {
        let large = BronzeReedBoat.canvas.scaled(to: 3)
        let cellW = large.pixelWidth, cellH = large.pixelHeight
        for pose in [SpritePose.standing, .walking, .working] {
            let width = cellW * 6, height = cellH * 2 * SpriteView.allCases.count
            let context = try StoneBoatsRenders.water(width: width, height: height, scale: 2.4)
            for (v, view) in SpriteView.allCases.enumerated() {
                for frame in 0..<12 {
                    let drawn = try #require(BronzeReedBoat.render(pose, frame: frame, view: view, canvas: large))
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    let x = Double(frame % 6 * cellW), y = Double(height - (v * 2 + frame / 6 + 1) * cellH)
                    context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(view.rawValue) \(frame)", in: context, at: CGPoint(x: x + 6, y: y + 6), size: 16)
                }
            }
            try write(context.makeImage()!, "strips/reed-boat-\(pose.rawValue)")
        }
    }

    /// One animated GIF for each pose: the five views side by side, drawn
    /// large from the same drawing, and beneath them the sprites at game size,
    /// the views toward the left mirrored as the drawing mirrors them.
    @Test func reedBoatAnimations() throws {
        let scale = 2.0
        let large = BronzeReedBoat.canvas.scaled(to: Canvas.person.pixelsPerUnit * scale)
        let source = BronzeBoatSprites()
        let width = 1750, height = 800
        let background = try StoneBoatsRenders.water(width: width, height: height, scale: 1.6).makeImage()!
        let names: [SpritePose: String] = [.standing: "standing: riding the water", .walking: "walking: poling",
                                           .working: "working: fishing with a hoop net"]
        for pose in [SpritePose.standing, .walking, .working] {
            var frames: [CGImage] = []
            for i in 0..<24 {
                let frame = i % 12
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
                for (v, view) in SpriteView.allCases.enumerated() {
                    let drawn = try #require(BronzeReedBoat.render(pose, frame: frame, view: view, canvas: large))
                    Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                                  at: CGPoint(x: 185 + Double(v) * 345, y: 420), in: context)
                    Preview.label(view.rawValue, in: context, at: CGPoint(x: 125 + Double(v) * 345, y: 300), size: 18)
                    // At game size: the view, and beside it the same view mirrored, as for a facing toward the left.
                    let sprite = try #require(source.sprite(SpriteKey(.unit(.boat, .bronze), pose, frame: frame, view: view)))
                    let tinted = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 120 + Double(v) * 345, y: 120), in: context)
                    context.saveGState()
                    context.translateBy(x: 250 + Double(v) * 345, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 0, y: 120), in: context)
                    context.restoreGState()
                }
                Preview.label("The Bronze age's reed boat, in Sumer's colour: \(names[pose]!), 12 frames a second", in: context,
                              at: CGPoint(x: 28, y: Double(height) - 48), size: 24)
                Preview.label("at game size, each view and its mirror", in: context, at: CGPoint(x: 28, y: 24), size: 16)
                frames.append(context.makeImage()!)
            }
            try writeGIF(frames, "reed-boat-\(pose.rawValue)")
        }
    }

    // MARK: At play size

    /// A stretch of shore at game size: the boat house on land beside the
    /// water, a shoal, rocks afloat, and reed boats poling, standing and
    /// fishing, drawn in increasing depth as the map draws them; as a PNG of
    /// its first frame and as an animated GIF.
    @Test func shore() throws {
        let sprites = GameSprites()
        let width = 1700, height = 980
        let origin = CGPoint(x: 850, y: 900)
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            if x <= 3 && y <= 9 { return x == 3 ? .sand : .grass }
            return x + y > 14 ? .deepWater : .shallowWater
        }
        let ground = Raster.bitmap(width: width, height: height)!
        try StoneBoatsRenders.lay(terrain, reach: 16, origin: origin, scale: 1, in: ground)
        let background = ground.makeImage()!
        struct Thing { var depth: Double; var key: SpriteKey; var at: (Double, Double); var mirrored: Bool; var offset: Bool }
        var things: [Thing] = [Thing(depth: 6, key: SpriteKey(.building(.boatHouse, .bronze), .complete), at: (3, 3), mirrored: false, offset: false),
                               Thing(depth: 12, key: SpriteKey(.building(.boatHouse, .bronze), .underConstruction), at: (3, 9), mirrored: false,
                                     offset: false)]
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
            things.append(Thing(depth: x + y, key: SpriteKey(.unit(.boat, .bronze), pose, view: view), at: (x, y), mirrored: mirrored, offset: false))
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
                let at = StoneBoatsRenders.screen(thing.at.0, thing.at.1, origin: origin, scale: 1)
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
            Preview.label("At play size (zoom 1, two pixels a point): the Bronze boat house, a shoal, rocks afloat, and reed boats", in: context,
                          at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            frames.append(context.makeImage()!)
        }
        try write(frames[0], "shore")
        try writeGIF(frames, "shore")
    }
}
