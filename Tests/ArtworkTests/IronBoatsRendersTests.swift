// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the Iron age's boats' art for a person to judge, as the Stone
/// age's renders do (`StoneBoatsRenders`): into the directory named by
/// `BOATS_RENDERS`, each file's name ending with `BOATS_RENDERS_SUFFIX` where
/// it is set; skipped when `BOATS_RENDERS` is not set. The sheets are PNG,
/// the movement animated GIF at 12 frames a second, on the game's own water
/// and ground tiles, in Sumer's colour.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BOATS_RENDERS"] != nil))
struct IronBoatsRenders {
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

    /// The boat house, complete and under construction, enlarged on its quay,
    /// and at game size beside the Iron age's house and the Stone age's boat house.
    @Test func boatHouse() throws {
        let width = 1600, height = 900
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        let source = IronOldBuildingSprites()
        for (i, complete) in [true, false].enumerated() {
            let key = SpriteKey(.building(.boatHouse, .iron), complete ? .complete : .underConstruction)
            let large = IronOldBuildingsArt.canvas(.boatHouse).scaled(to: 4.4)
            let drawn = try #require(Raster.render(on: large) { svg in
                var painter = IronOldBuildingsPainter(layer: svg.layer)
                painter.boatHouse(complete: complete)
                svg = painter.svg
            })
            Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                          at: CGPoint(x: 330 + Double(i) * 640, y: 300), in: context)
            Preview.label(complete ? "complete" : "under construction", in: context, at: CGPoint(x: 230 + Double(i) * 640, y: 40), size: 24)
            let sprite = try #require(source.sprite(key))
            Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor,
                          at: CGPoint(x: 1440, y: 460 - Double(i) * 260), in: context)
        }
        let house = try #require(source.sprite(SpriteKey(.building(.house, .iron), .complete)))
        Preview.place(Preview.tinted(base: house.base, mask: house.teamMask, colour: colour), anchor: house.anchor,
                      at: CGPoint(x: 1250, y: 700), in: context)
        let stone = try #require(StoneBuildingSprites().sprite(SpriteKey(.building(.boatHouse, .stone), .complete)))
        Preview.place(Preview.tinted(base: stone.base, mask: stone.teamMask, colour: colour), anchor: stone.anchor,
                      at: CGPoint(x: 1500, y: 750), in: context)
        Preview.label("at game size; above, the Iron house and the Stone boat house", in: context, at: CGPoint(x: 1150, y: 40), size: 15)
        Preview.label("The Iron age's boat house, in Sumer's colour", in: context, at: CGPoint(x: 28, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house")
    }

    /// The boat house's two views enlarged, complete and under construction:
    /// the side, its slip toward +x (the lower right), and beside it the back,
    /// the same building turned so that its slip runs toward −y (the upper
    /// right) and its landward gable faces the viewer.
    @Test func boatHouseViews() throws {
        let large = IronOldBuildingsArt.canvas(.boatHouse).scaled(to: 4.4)
        let cellW = large.pixelWidth, cellH = large.pixelHeight, label = 40, top = 70
        let width = cellW * 2, height = (cellH + label) * 2 + top
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        for (row, complete) in [true, false].enumerated() {
            for (column, view) in [SpriteView.side, .back].enumerated() {
                let drawn = try #require(Raster.render(on: large) { svg in
                    var painter = IronOldBuildingsPainter(layer: svg.layer)
                    painter.boatHouse(complete: complete, view: view)
                    svg = painter.svg
                })
                let x = Double(column * cellW), y = Double(height - top - (row + 1) * (cellH + label))
                context.draw(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour),
                             in: CGRect(x: x, y: y + Double(label), width: Double(cellW), height: Double(cellH)))
                let name = view == .side ? "side: the water toward +x, the lower right" : "back: the water toward −y, the upper right"
                Preview.label("\(name), \(complete ? "complete" : "under construction")", in: context, at: CGPoint(x: x + 16, y: y + 8), size: 20)
            }
        }
        Preview.label("The Iron age's boat house in its two views, in Sumer's colour", in: context,
                      at: CGPoint(x: 24, y: Double(height) - 48), size: 26)
        try write(context.makeImage()!, "boat-house-views")
    }

    /// A lake at play size with a boat house on each of its four edges, each
    /// drawn as the game draws it (`FootprintEdge.boatHouseView`): the side,
    /// the side mirrored, the back and the back mirrored, so that each faces
    /// the water. Once complete and once under construction.
    @Test func boatHousesRoundALake() throws {
        let sprites = GameSprites()
        let size = 14, width = 1300, height = 860
        let origin = CGPoint(x: 650, y: 420 + 7 * 64)
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            if (5...8).contains(x) && (5...8).contains(y) { return .deepWater }
            if (4...9).contains(x) && (4...9).contains(y) { return .shallowWater }
            if (3...10).contains(x) && (3...10).contains(y) { return .sand }
            return .grass
        }
        var cells: [Terrain] = []
        for y in 0..<size { for x in 0..<size { cells.append(terrain(x, y)) } }
        let ground = Raster.bitmap(width: width, height: height)!
        try StoneBoatsRenders.lay(terrain, reach: 24, origin: origin, scale: 1, in: ground)
        let background = ground.makeImage()!
        // Each boat house has the lake along one edge of its footprint and dry land along the others.
        let houses: [(GridPoint, FootprintEdge)] = [(GridPoint(2, 6), .plusX), (GridPoint(6, 2), .plusY),
                                                    (GridPoint(6, 10), .minusY), (GridPoint(10, 6), .minusX)]
        for complete in [true, false] {
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
            for (tile, edge) in houses.sorted(by: { $0.0.x + $0.0.y < $1.0.x + $1.0.y }) {
                #expect(Placement.waterEdge(.boatHouse, at: tile, width: size, height: size, terrain: cells) == edge, "\(tile)")
                let (view, mirrored) = edge.boatHouseView
                let key = SpriteKey(.building(.boatHouse, .iron), complete ? .complete : .underConstruction, view: view)
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
            }
            Preview.label("At play size: Iron boat houses \(complete ? "" : "under construction ")on the four edges of a lake, each facing the water",
                          in: context, at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            try write(context.makeImage()!, complete ? "boat-houses-round-a-lake" : "boat-houses-round-a-lake-under-construction")
        }
    }

    // MARK: The fishing boat

    /// Each of the boat's poses in each view, its 12 frames enlarged in rows of six, for looking at frame by frame.
    @Test func boatStrips() throws {
        let large = IronFishingBoat.canvas.scaled(to: 2.6)
        let cellW = large.pixelWidth, cellH = large.pixelHeight
        for pose in [SpritePose.standing, .walking, .working] {
            let width = cellW * 6, height = cellH * 2 * SpriteView.allCases.count
            let context = try StoneBoatsRenders.water(width: width, height: height, scale: 2.2)
            for (v, view) in SpriteView.allCases.enumerated() {
                for frame in 0..<12 {
                    let drawn = try #require(IronFishingBoat.render(pose, frame: frame, view: view, canvas: large))
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    let x = Double(frame % 6 * cellW), y = Double(height - (v * 2 + frame / 6 + 1) * cellH)
                    context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(view.rawValue) \(frame)", in: context, at: CGPoint(x: x + 6, y: y + 6), size: 16)
                }
            }
            try write(context.makeImage()!, "strips/fishing-boat-\(pose.rawValue)")
        }
    }

    /// One animated GIF for each pose: the five views side by side, drawn
    /// large from the same drawing, and beneath them the sprites at game size,
    /// the views toward the left mirrored as the drawing mirrors them.
    @Test func boatAnimations() throws {
        let scale = 2.0
        let large = IronFishingBoat.canvas.scaled(to: Canvas.person.pixelsPerUnit * scale)
        let source = IronBoatSprites()
        let width = 1700, height = 760
        let background = try StoneBoatsRenders.water(width: width, height: height, scale: 1.6).makeImage()!
        let names: [SpritePose: String] = [.standing: "standing: riding the water", .walking: "walking: rowing",
                                           .working: "working: casting a net"]
        for pose in [SpritePose.standing, .walking, .working] {
            var frames: [CGImage] = []
            for i in 0..<24 {
                let frame = i % 12
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
                for (v, view) in SpriteView.allCases.enumerated() {
                    let drawn = try #require(IronFishingBoat.render(pose, frame: frame, view: view, canvas: large))
                    Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                                  at: CGPoint(x: 180 + Double(v) * 335, y: 420), in: context)
                    Preview.label(view.rawValue, in: context, at: CGPoint(x: 120 + Double(v) * 335, y: 290), size: 18)
                    // At game size: the view, and beside it the same view mirrored, as for a facing toward the left.
                    let sprite = try #require(source.sprite(SpriteKey(.unit(.boat, .iron), pose, frame: frame, view: view)))
                    let tinted = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 110 + Double(v) * 335, y: 120), in: context)
                    context.saveGState()
                    context.translateBy(x: 250 + Double(v) * 335, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 0, y: 120), in: context)
                    context.restoreGState()
                }
                Preview.label("The Iron age's fishing boat, in Sumer's colour: \(names[pose]!), 12 frames a second", in: context,
                              at: CGPoint(x: 28, y: Double(height) - 48), size: 24)
                Preview.label("at game size, each view and its mirror", in: context, at: CGPoint(x: 28, y: 24), size: 16)
                frames.append(context.makeImage()!)
            }
            try writeGIF(frames, "fishing-boat-\(pose.rawValue)")
        }
    }

    // MARK: At play size

    /// A stretch of shore at game size: the boat house on land beside the
    /// water, a shoal, rocks afloat, and fishing boats rowing, standing and
    /// casting nets, drawn in increasing depth as the map draws them; as a PNG
    /// of its first frame and as an animated GIF.
    @Test func shore() throws {
        let sprites = GameSprites()
        let width = 1700, height = 980
        let origin = CGPoint(x: 850, y: 900)
        func terrain(_ x: Int, _ y: Int) -> Terrain {
            if x <= 3 && y <= 8 { return x == 3 ? .sand : .grass }
            return x + y > 14 ? .deepWater : .shallowWater
        }
        let ground = Raster.bitmap(width: width, height: height)!
        try StoneBoatsRenders.lay(terrain, reach: 16, origin: origin, scale: 1, in: ground)
        let background = ground.makeImage()!
        struct Thing { var depth: Double; var key: SpriteKey; var at: (Double, Double); var mirrored: Bool; var offset: Bool }
        // The complete boat house has the water along its +y edge, so it is drawn as the game draws it there: the side view mirrored.
        var things: [Thing] = [Thing(depth: 6, key: SpriteKey(.building(.boatHouse, .iron), .underConstruction), at: (2, 3), mirrored: false, offset: false),
                               Thing(depth: 11, key: SpriteKey(.building(.boatHouse, .iron), .complete), at: (2, 8), mirrored: true, offset: false)]
        for (x, y) in [(6, 1), (7, 1), (6, 2), (7, 2)] {
            things.append(Thing(depth: Double(x + y) + 1, key: SpriteKey(.site(.fish), .complete), at: (Double(x) + 0.5, Double(y) + 0.5),
                                mirrored: false, offset: true))
        }
        for (i, (x, y)) in [(5, 5), (7, 4), (9, 6), (6, 8), (8, 9)].enumerated() {
            things.append(Thing(depth: Double(x + y) + 1, key: SpriteKey(.site(StoneBoatSprites.rocks[i]), .afloat),
                                at: (Double(x) + 0.5, Double(y) + 0.5), mirrored: false, offset: false))
        }
        let boats: [(SpritePose, SpriteView, Bool, Double, Double)] = [
            (.walking, .side, false, 4.6, 3.6), (.working, .frontQuarter, false, 8.2, 2.0), (.standing, .backQuarter, true, 5.4, 7.0),
            (.walking, .front, false, 9.4, 4.0), (.walking, .back, false, 4.8, 10.6), (.working, .side, true, 7.6, 7.6),
        ]
        for (pose, view, mirrored, x, y) in boats {
            things.append(Thing(depth: x + y, key: SpriteKey(.unit(.boat, .iron), pose, view: view), at: (x, y), mirrored: mirrored, offset: false))
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
            Preview.label("At play size (zoom 1, two pixels a point): the Iron boat house, a shoal, rocks afloat, and fishing boats",
                          in: context, at: CGPoint(x: 24, y: Double(height) - 40), size: 22, colour: .white)
            frames.append(context.makeImage()!)
        }
        try write(frames[0], "shore")
        try writeGIF(frames, "shore")
    }
}
