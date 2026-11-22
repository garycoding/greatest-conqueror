// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the Alchemy age's boats' art for a person to judge, into the
/// directory named by the environment variable `BOATS_RENDERS`, as the Stone
/// age's renders are (`StoneBoatsRenders`), each file's name beginning with
/// `alchemy-` so that the two sets lie side by side, and ending with
/// `BOATS_RENDERS_SUFFIX` where it is set; skipped when `BOATS_RENDERS` is not
/// set. The sheets are PNG, the movement animated GIF at 12 frames a second,
/// all on the game's own water and ground tiles, in Sumer's colour.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BOATS_RENDERS"] != nil))
struct AlchemyBoatsRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BOATS_RENDERS"] ?? "/", isDirectory: true)
    private let suffix = ProcessInfo.processInfo.environment["BOATS_RENDERS_SUFFIX"] ?? ""
    private let colour = TeamColour.of(.sumer)

    /// Where a render named `name` (perhaps in a subdirectory) is written, its file's name prefixed.
    private func url(_ name: String, _ ext: String) -> URL {
        let path = URL(fileURLWithPath: name)
        let folder = name.contains("/") ? directory.appendingPathComponent(path.deletingLastPathComponent().relativePath) : directory
        return folder.appendingPathComponent("alchemy-\(path.lastPathComponent)\(suffix).\(ext)")
    }

    private func write(_ image: CGImage, _ name: String) throws {
        let url = url(name, "png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Preview.writePNG(image, to: url)
    }

    private func writeGIF(_ frames: [CGImage], _ name: String) throws {
        let url = url(name, "gif")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Preview.writeGIF(frames, to: url)
    }

    // MARK: The boat house

    /// The boat house, complete and under construction, enlarged on its
    /// cobbled quay, and at game size beside the Alchemy age's house.
    @Test func boatHouse() throws {
        let width = 1600, height = 900
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = AlchemyOldBuildingSprites()
        for (i, complete) in [true, false].enumerated() {
            let key = SpriteKey(.building(.boatHouse, .alchemy), complete ? .complete : .underConstruction)
            let large = AlchemyOldBuildingsArt.canvas(.boatHouse).scaled(to: 4.4)
            let drawn = try #require(Raster.render(on: large) { svg in
                var painter = AlchemyOldBuildingsPainter(layer: svg.layer)
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
        let house = try #require(source.sprite(SpriteKey(.building(.house, .alchemy), .complete)))
        Preview.place(Preview.tinted(base: house.base, mask: house.teamMask, colour: colour), anchor: house.anchor,
                      at: CGPoint(x: 1420, y: 760), in: context)
        Preview.label("at game size, the house above for scale", in: context, at: CGPoint(x: 1260, y: 40), size: 16)
        Preview.label("The Alchemy age's boat house, in Sumer's colour", in: context, at: CGPoint(x: 28, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house")
    }

    /// The back view beside the side view, complete and under construction,
    /// enlarged on the cobbled quay: the same building turned a quarter, its
    /// water toward the upper right instead of the lower right.
    @Test func boatHouseBack() throws {
        let large = AlchemyOldBuildingsArt.canvas(.boatHouse).scaled(to: 4.4)
        let cellW = large.pixelWidth + 40, cellH = large.pixelHeight + 60
        let width = cellW * 2, height = cellH * 2 + 70
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        for (row, complete) in [true, false].enumerated() {
            for (column, back) in [false, true].enumerated() {
                let drawn = try #require(Raster.render(on: large) { svg in
                    var painter = AlchemyOldBuildingsPainter(layer: svg.layer)
                    painter.boatHouse(complete: complete, back: back)
                    svg = painter.svg
                })
                let x = column * cellW + 20, y = height - 70 - (row + 1) * cellH + 50
                context.draw(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour),
                             in: CGRect(x: x, y: y, width: large.pixelWidth, height: large.pixelHeight))
                Preview.label("\(back ? "back: water toward the upper right" : "side: water toward the lower right"), "
                              + (complete ? "complete" : "under construction"),
                              in: context, at: CGPoint(x: Double(x) + 10, y: Double(y) - 36), size: 20)
            }
        }
        Preview.label("The Alchemy age's boat house in its two views, in Sumer's colour", in: context,
                      at: CGPoint(x: 28, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house-back")
    }

    /// A lake at play size with a boat house on each of its four shores, each
    /// on land with water along one edge of its footprint, drawn as the map
    /// draws it: the view and mirror `FootprintEdge.boatHouseView` gives for
    /// the edge `Placement.waterEdge` finds, so that each faces its water.
    @Test func boatHousesFacingALake() throws {
        let sprites = GameSprites()
        let size = 16
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            if x >= 4 && x <= 9 && y >= 4 && y <= 9 { return x >= 6 && x <= 7 && y >= 6 && y <= 7 ? .deepWater : .shallowWater }
            if x >= 3 && x <= 10 && y >= 3 && y <= 10 { return .sand }
            return .grass
        }
        let map = (0..<size * size).map { terrain($0 % size, $0 / size) }
        let width = 1500, height = 1060
        let origin = CGPoint(x: 750, y: 1000)
        let context = Raster.bitmap(width: width, height: height)!
        try StoneBoatsRenders.lay(terrain, reach: 26, origin: origin, scale: 1, in: context)
        struct Thing { var depth: Double; var key: SpriteKey; var at: (Double, Double); var mirrored: Bool }
        var things: [Thing] = []
        // One boat house on each shore, two of them still being built.
        let places: [(GridPoint, Bool)] = [(GridPoint(2, 6), true), (GridPoint(6, 2), false), (GridPoint(10, 6), true), (GridPoint(6, 10), false)]
        for (place, complete) in places {
            let edge = Placement.waterEdge(.boatHouse, at: place, width: size, height: size, terrain: map)
            let (view, mirrored) = edge.boatHouseView
            let key = SpriteKey(.building(.boatHouse, .alchemy), complete ? .complete : .underConstruction, view: view)
            things.append(Thing(depth: Double(place.x + place.y) + 2, key: key, at: (Double(place.x) + 1, Double(place.y) + 1),
                                mirrored: mirrored))
        }
        // Two smacks on the lake, for scale.
        for (x, y, view, mirrored) in [(5.0, 5.4, SpriteView.side, false), (8.6, 8.4, .frontQuarter, true)] {
            things.append(Thing(depth: x + y, key: SpriteKey(.unit(.fishingBoat, .alchemy), .standing, view: view), at: (x, y), mirrored: mirrored))
        }
        func draw(_ things: [Thing], in context: CGContext) throws {
            for thing in things.sorted(by: { $0.depth < $1.depth }) {
                let sprite = try #require(sprites.sprite(thing.key), "\(thing.key)")
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                let at = StoneBoatsRenders.screen(thing.at.0, thing.at.1, origin: origin, scale: 1)
                context.saveGState()
                if thing.mirrored {
                    context.translateBy(x: at.x * 2, y: 0)
                    context.scaleBy(x: -1, y: 1)
                }
                Preview.place(image, anchor: sprite.anchor, at: at, in: context)
                context.restoreGState()
            }
        }
        let ground = context.makeImage()!
        try draw(things, in: context)
        Preview.label("At play size: the Alchemy age's boat house on each shore of a lake, each facing its water",
                      in: context, at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
        try write(context.makeImage()!, "boat-houses-facing-a-lake")
        // The same, every boat house complete.
        let complete = Raster.bitmap(width: width, height: height)!
        complete.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
        try draw(things.map { thing in
            var thing = thing
            if case .building = thing.key.subject { thing.key.pose = .complete }
            return thing
        }, in: complete)
        Preview.label("At play size: the same, every boat house complete",
                      in: complete, at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
        try write(complete.makeImage()!, "boat-houses-facing-a-lake-complete")
    }

    // MARK: The fishing smack

    /// Each of the smack's poses in each view, its 12 frames enlarged in rows
    /// of six, for looking at frame by frame.
    @Test func smackStrips() throws {
        let large = AlchemySmack.canvas.scaled(to: 2.6)
        let cellW = large.pixelWidth, cellH = large.pixelHeight
        for pose in [SpritePose.standing, .walking, .working] {
            let width = cellW * 6, height = cellH * 2 * SpriteView.allCases.count
            let context = try StoneBoatsRenders.water(width: width, height: height, scale: 2.4)
            for (v, view) in SpriteView.allCases.enumerated() {
                for frame in 0..<12 {
                    let drawn = try #require(AlchemySmack.render(pose, frame: frame, view: view, canvas: large))
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    let x = Double(frame % 6 * cellW), y = Double(height - (v * 2 + frame / 6 + 1) * cellH)
                    context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(view.rawValue) \(frame)", in: context, at: CGPoint(x: x + 6, y: y + 6), size: 16)
                }
            }
            try write(context.makeImage()!, "strips/smack-\(pose.rawValue)")
        }
    }

    /// One animated GIF for each pose: the five views side by side, drawn
    /// large from the same drawing, and beneath them the sprites at game size,
    /// the views toward the left mirrored as the drawing mirrors them.
    @Test func smackAnimations() throws {
        let scale = 1.9
        let large = AlchemySmack.canvas.scaled(to: Canvas.person.pixelsPerUnit * scale)
        let source = AlchemyBoatSprites()
        let width = 1800, height = 860
        let background = try StoneBoatsRenders.water(width: width, height: height, scale: 1.6).makeImage()!
        let names: [SpritePose: String] = [.standing: "standing: hove to", .walking: "walking: under sail",
                                           .working: "working: hauling a net"]
        for pose in [SpritePose.standing, .walking, .working] {
            var frames: [CGImage] = []
            for i in 0..<24 {
                let frame = i % 12
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
                for (v, view) in SpriteView.allCases.enumerated() {
                    let drawn = try #require(AlchemySmack.render(pose, frame: frame, view: view, canvas: large))
                    Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                                  at: CGPoint(x: 190 + Double(v) * 355, y: 380), in: context)
                    Preview.label(view.rawValue, in: context, at: CGPoint(x: 130 + Double(v) * 355, y: 250), size: 18)
                    // At game size: the view, and beside it the same view mirrored, as for a facing toward the left.
                    let sprite = try #require(source.sprite(SpriteKey(.unit(.fishingBoat, .alchemy), pose, frame: frame, view: view)))
                    let tinted = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 120 + Double(v) * 355, y: 110), in: context)
                    context.saveGState()
                    context.translateBy(x: 260 + Double(v) * 355, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 0, y: 110), in: context)
                    context.restoreGState()
                }
                Preview.label("The Alchemy age's fishing smack, in Sumer's colour: \(names[pose]!), 12 frames a second", in: context,
                              at: CGPoint(x: 28, y: Double(height) - 48), size: 24)
                Preview.label("at game size, each view and its mirror", in: context, at: CGPoint(x: 28, y: 20), size: 16)
                frames.append(context.makeImage()!)
            }
            try writeGIF(frames, "smack-\(pose.rawValue)")
            try write(frames[0], "smack-\(pose.rawValue)")
        }
    }

    // MARK: At play size

    /// A stretch of shore at game size: the boat house complete and under
    /// construction on land beside the water, a shoal, rocks afloat, and smacks
    /// sailing, lying hove to and hauling nets, drawn in increasing depth as the
    /// map draws them; as a PNG of its first frame and as an animated GIF.
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
            Thing(depth: 6, key: SpriteKey(.building(.boatHouse, .alchemy), .complete), at: (3, 3), mirrored: false, offset: false),
            Thing(depth: 12, key: SpriteKey(.building(.boatHouse, .alchemy), .underConstruction), at: (3, 9), mirrored: false, offset: false),
            Thing(depth: 2, key: SpriteKey(.building(.house, .alchemy), .complete), at: (1, 6), mirrored: false, offset: false),
        ]
        for (x, y) in [(6, 1), (7, 1), (6, 2), (7, 2)] {
            things.append(Thing(depth: Double(x + y) + 1, key: SpriteKey(.site(.fish), .complete), at: (Double(x) + 0.5, Double(y) + 0.5),
                                mirrored: false, offset: true))
        }
        for (i, (x, y)) in [(5, 5), (9, 6), (8, 9)].enumerated() {
            things.append(Thing(depth: Double(x + y) + 1, key: SpriteKey(.site(StoneBoatSprites.rocks[i * 2]), .afloat),
                                at: (Double(x) + 0.5, Double(y) + 0.5), mirrored: false, offset: false))
        }
        let boats: [(SpritePose, SpriteView, Bool, Double, Double)] = [
            (.walking, .side, false, 4.8, 3.4), (.working, .frontQuarter, false, 8.4, 2.4), (.standing, .backQuarter, true, 5.4, 7.2),
            (.walking, .front, false, 9.6, 4.0), (.walking, .back, false, 4.8, 11.0), (.working, .side, true, 7.6, 7.6),
        ]
        for (pose, view, mirrored, x, y) in boats {
            things.append(Thing(depth: x + y, key: SpriteKey(.unit(.fishingBoat, .alchemy), pose, view: view), at: (x, y), mirrored: mirrored, offset: false))
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
            Preview.label("At play size (zoom 1, two pixels a point): the Alchemy age's boat house, a shoal, rocks afloat, and smacks",
                          in: context, at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            frames.append(context.makeImage()!)
        }
        try write(frames[0], "shore")
        try writeGIF(frames, "shore")
    }
}
