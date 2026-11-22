// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the Industrial age's boats' art for a person to judge, into the
/// directory named by the environment variable `BOATS_RENDERS`, each file's
/// name beginning `industrial-` and ending with `BOATS_RENDERS_SUFFIX` where it
/// is set; skipped when `BOATS_RENDERS` is not set. The sheets are PNG, the
/// movement animated GIF at 12 frames a second, all on the game's own water
/// and ground tiles, in Sumer's colour. The map is laid as the Stone age's
/// renders lay it (`StoneBoatsRenders`).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BOATS_RENDERS"] != nil))
struct IndustrialBoatsRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BOATS_RENDERS"] ?? "/", isDirectory: true)
    private let suffix = ProcessInfo.processInfo.environment["BOATS_RENDERS_SUFFIX"] ?? ""
    private let colour = TeamColour.of(.sumer)

    private func write(_ image: CGImage, _ name: String) throws {
        let path = name.split(separator: "/").map(String.init)
        let file = (path.dropLast() + ["industrial-\(path.last!)\(suffix).png"]).joined(separator: "/")
        let url = directory.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Preview.writePNG(image, to: url)
    }

    private func writeGIF(_ frames: [CGImage], _ name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Preview.writeGIF(frames, to: directory.appendingPathComponent("industrial-\(name)\(suffix).gif"))
    }

    // MARK: The boat house

    /// The boat house, complete and under construction, enlarged on its
    /// ground, and at game size beside the Industrial age's house.
    @Test func boatHouse() throws {
        let width = 1600, height = 900
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = IndustrialOldBuildingSprites()
        let canvas = IndustrialOldBuildingsArt.canvas(.boatHouse)
        for (i, complete) in [true, false].enumerated() {
            let key = SpriteKey(.building(.boatHouse, .industrial), complete ? .complete : .underConstruction)
            let drawn = try #require(IndustrialOldBuildingsArt.draw(.boatHouse, complete: complete, pixelsPerUnit: 4.4))
            Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: canvas.anchor,
                          at: CGPoint(x: 330 + Double(i) * 640, y: 330), in: context)
            Preview.label(complete ? "complete" : "under construction", in: context, at: CGPoint(x: 230 + Double(i) * 640, y: 40), size: 24)
            let sprite = try #require(source.sprite(key))
            Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor,
                          at: CGPoint(x: 1420, y: 520 - Double(i) * 330), in: context)
        }
        let house = try #require(source.sprite(SpriteKey(.building(.house, .industrial), .complete)))
        Preview.place(Preview.tinted(base: house.base, mask: house.teamMask, colour: colour), anchor: house.anchor,
                      at: CGPoint(x: 1420, y: 760), in: context)
        Preview.label("at game size, the house above for scale", in: context, at: CGPoint(x: 1260, y: 40), size: 16)
        Preview.label("The Industrial age's boat house, in Sumer's colour", in: context, at: CGPoint(x: 28, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house")
    }

    /// The boat house's back view (ruled 2026-11-22), complete and under
    /// construction, enlarged beside its side view, and each view at game size
    /// beside its mirror.
    @Test func boatHouseBack() throws {
        let scale = 3.6
        let canvas = IndustrialOldBuildingsArt.canvas(.boatHouse)
        let large = canvas.scaled(to: scale)
        let cellW = large.pixelWidth + 20, cellH = large.pixelHeight + 50
        let width = cellW * 2 + 1200, height = cellH * 2 + 80
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = IndustrialOldBuildingSprites()
        for (row, complete) in [true, false].enumerated() {
            let y = Double(height - 80 - (row + 1) * cellH)
            for (column, view) in [SpriteView.side, .back].enumerated() {
                let drawn = try #require(IndustrialOldBuildingsArt.draw(.boatHouse, complete: complete, view: view, pixelsPerUnit: scale))
                let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                let x = Double(column * cellW + 10)
                context.draw(image, in: CGRect(x: x, y: y, width: Double(image.width), height: Double(image.height)))
                Preview.label("\(view.rawValue), \(complete ? "complete" : "under construction")", in: context,
                              at: CGPoint(x: x + 10, y: y + Double(cellH) - 40), size: 22)
                // At game size: the view, and its mirror.
                let key = SpriteKey(.building(.boatHouse, .industrial), complete ? .complete : .underConstruction, view: view)
                let sprite = try #require(source.sprite(key))
                let tinted = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                for mirrored in [false, true] {
                    let at = CGPoint(x: Double(cellW * 2) + 160 + Double(column * 2 + (mirrored ? 1 : 0)) * 290, y: y + 120)
                    context.saveGState()
                    if mirrored {
                        context.translateBy(x: at.x * 2, y: 0)
                        context.scaleBy(x: -1, y: 1)
                    }
                    Preview.place(tinted, anchor: sprite.anchor, at: at, in: context)
                    context.restoreGState()
                    Preview.label("\(view.rawValue)\(mirrored ? ", mirrored" : "")", in: context, at: CGPoint(x: at.x - 60, y: y + 20), size: 16)
                }
            }
        }
        Preview.label("at game size: each view and its mirror", in: context,
                      at: CGPoint(x: Double(cellW * 2) + 20, y: Double(height) - 90), size: 18)
        Preview.label("The Industrial age's boat house, side and back views, in Sumer's colour", in: context,
                      at: CGPoint(x: 28, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house-back")
    }

    /// A lake at game size with a boat house of the Industrial age on each of
    /// its four shores, each drawn as the map draws it: the edge of its
    /// footprint that touches water (`Placement.waterEdge`) chooses the view
    /// and whether it is mirrored (`FootprintEdge.boatHouseView`). Once complete
    /// and once under construction.
    @Test func boatHousesFacingTheWater() throws {
        let sprites = GameSprites()
        let size = 12
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            guard (4...7).contains(x) && (4...7).contains(y) else { return .grass }
            return (5...6).contains(x) && (5...6).contains(y) ? .deepWater : .shallowWater
        }
        var map: [Terrain] = []
        for y in 0..<size { for x in 0..<size { map.append(terrain(x, y)) } }
        let origins = [GridPoint(2, 5), GridPoint(5, 2), GridPoint(5, 8), GridPoint(8, 5)]
        let width = 1100, height = 760
        let origin = CGPoint(x: 550, y: 700)
        for complete in [true, false] {
            let context = Raster.bitmap(width: width, height: height)!
            try StoneBoatsRenders.lay(terrain, reach: 24, origin: origin, scale: 1, in: context)
            var labels: [(String, CGPoint)] = []
            for tile in origins.sorted(by: { $0.x + $0.y < $1.x + $1.y }) {
                let edge = Placement.waterEdge(.boatHouse, at: tile, width: size, height: size, terrain: map)
                let (view, mirrored) = edge.boatHouseView
                let key = SpriteKey(.building(.boatHouse, .industrial), complete ? .complete : .underConstruction, view: view)
                let sprite = try #require(sprites.sprite(key), "\(key)")
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                let centre = Placement.centre(.boatHouse, origin: tile)
                let at = StoneBoatsRenders.screen(centre.x, centre.y, origin: origin, scale: 1)
                context.saveGState()
                if mirrored {
                    context.translateBy(x: at.x * 2, y: 0)
                    context.scaleBy(x: -1, y: 1)
                }
                Preview.place(image, anchor: sprite.anchor, at: at, in: context)
                context.restoreGState()
                labels.append(("\(edge): \(view.rawValue)\(mirrored ? ", mirrored" : "")", CGPoint(x: at.x - 70, y: at.y - 90)))
            }
            for (text, at) in labels { Preview.label(text, in: context, at: at, size: 16, colour: .white) }
            Preview.label("At play size: a boat house on each shore of a lake, each facing its water"
                          + (complete ? "" : ", under construction"), in: context,
                          at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            try write(context.makeImage()!, complete ? "boat-houses-facing" : "boat-houses-facing-rising")
        }
    }

    // MARK: The steam trawler

    /// Each of the trawler's poses in each view, its 12 frames enlarged in
    /// rows of six, for looking at frame by frame.
    @Test func trawlerStrips() throws {
        let large = IndustrialTrawler.canvas.scaled(to: 2.4)
        let cellW = large.pixelWidth, cellH = large.pixelHeight
        for pose in [SpritePose.standing, .walking, .working] {
            let width = cellW * 6, height = cellH * 2 * SpriteView.allCases.count
            let context = try StoneBoatsRenders.water(width: width, height: height, scale: 2)
            for (v, view) in SpriteView.allCases.enumerated() {
                for frame in 0..<12 {
                    let drawn = try #require(IndustrialTrawler.render(pose, frame: frame, view: view, canvas: large))
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    let x = Double(frame % 6 * cellW), y = Double(height - (v * 2 + frame / 6 + 1) * cellH)
                    context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(view.rawValue) \(frame)", in: context, at: CGPoint(x: x + 6, y: y + 6), size: 16)
                }
            }
            try write(context.makeImage()!, "strips/trawler-\(pose.rawValue)")
        }
    }

    /// One animated GIF for each pose: the five views side by side, drawn
    /// large from the same drawing, and beneath them the sprites at game size,
    /// each view beside its mirror.
    @Test func trawlerAnimations() throws {
        let scale = 1.9
        let large = IndustrialTrawler.canvas.scaled(to: Canvas.person.pixelsPerUnit * scale)
        let source = IndustrialBoatSprites()
        let width = 1800, height = 820
        let background = try StoneBoatsRenders.water(width: width, height: height, scale: 1.6).makeImage()!
        let names: [SpritePose: String] = [.standing: "standing: riding the water", .walking: "walking: under steam",
                                           .working: "working: hauling the warp with the winch, or working a rock"]
        for pose in [SpritePose.standing, .walking, .working] {
            var frames: [CGImage] = []
            for i in 0..<24 {
                let frame = i % 12
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
                for (v, view) in SpriteView.allCases.enumerated() {
                    let drawn = try #require(IndustrialTrawler.render(pose, frame: frame, view: view, canvas: large))
                    Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                                  at: CGPoint(x: 185 + Double(v) * 355, y: 400), in: context)
                    Preview.label(view.rawValue, in: context, at: CGPoint(x: 125 + Double(v) * 355, y: 290), size: 18)
                    let sprite = try #require(source.sprite(SpriteKey(.unit(.boat, .industrial), pose, frame: frame, view: view)))
                    let tinted = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 115 + Double(v) * 355, y: 110), in: context)
                    context.saveGState()
                    context.translateBy(x: 255 + Double(v) * 355, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 0, y: 110), in: context)
                    context.restoreGState()
                }
                Preview.label("The Industrial age's steam trawler, in Sumer's colour: \(names[pose]!), 12 frames a second", in: context,
                              at: CGPoint(x: 28, y: Double(height) - 48), size: 24)
                Preview.label("at game size, each view and its mirror", in: context, at: CGPoint(x: 28, y: 24), size: 16)
                frames.append(context.makeImage()!)
            }
            try writeGIF(frames, "trawler-\(pose.rawValue)")
            try write(frames[0], "trawler-\(pose.rawValue)")
        }
    }

    // MARK: At play size

    /// A stretch of shore at game size, as the Stone age's `shore` lays it:
    /// the boat house on land beside the water, a shoal, the five rocks
    /// afloat, and trawlers under steam, lying still and hauling, drawn in
    /// increasing depth as the map draws them; as a PNG of its first frame and
    /// as an animated GIF.
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
        var things: [Thing] = [
            Thing(depth: 6, key: SpriteKey(.building(.boatHouse, .industrial), .complete), at: (3, 3), mirrored: false, offset: false),
            Thing(depth: 12, key: SpriteKey(.building(.boatHouse, .industrial), .underConstruction), at: (3, 9), mirrored: false, offset: false),
        ]
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
            things.append(Thing(depth: x + y, key: SpriteKey(.unit(.boat, .industrial), pose, view: view), at: (x, y), mirrored: mirrored,
                                offset: false))
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
            Preview.label("At play size (zoom 1, two pixels a point): the boat house, a shoal, rocks afloat, and steam trawlers", in: context,
                          at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            frames.append(context.makeImage()!)
        }
        try write(frames[0], "shore")
        try writeGIF(frames, "shore")
    }
}
