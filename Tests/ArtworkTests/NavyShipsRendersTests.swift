// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the navy ship's art for a person to judge, as the boats' renders do
/// (`IronBoatsRenders`): into the directory named by `NAVY_SHIP_RENDERS`;
/// skipped when it is not set. For each look, one animated GIF at 12 frames a
/// second of each pose in turn, the five views drawn large and the sprites at
/// game size beneath them; one PNG sheet of every view and pose; and strips of
/// each pose's 12 frames, all on the game's own water tiles, in Sumer's colour.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["NAVY_SHIP_RENDERS"] != nil))
struct NavyShipsRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NAVY_SHIP_RENDERS"] ?? "/", isDirectory: true)
    private let colour = TeamColour.of(.sumer)
    private static let looks: [Look] = [.iron, .alchemy, .industrial]
    private static let poses: [SpritePose] = [.standing, .walking, .fighting]

    private static func name(_ look: Look) -> String {
        switch look {
        case .alchemy: "galleon (Alchemy look)"
        case .industrial: "ironclad (Industrial look)"
        default: "war galley (Iron look)"
        }
    }

    private static func caption(_ look: Look, _ pose: SpritePose) -> String {
        switch (look, pose) {
        case (.iron, .standing): "standing: at anchor, the sail furled, the oars resting on the water"
        case (.iron, .walking): "walking: rowed, the sail set"
        case (.iron, .fighting): "fighting: the bow gun fires ahead"
        case (.alchemy, .standing): "standing: hove to under topsails"
        case (.alchemy, .walking): "walking: under full sail"
        case (.alchemy, .fighting): "fighting: under topsails, the bow chasers fire ahead"
        case (.industrial, .standing): "standing: at rest, a wisp from the funnels"
        case (.industrial, .walking): "walking: under steam"
        case (.industrial, .fighting): "fighting: the forward turret fires ahead"
        default: pose.rawValue
        }
    }

    private static func fishingBoat(_ look: Look) -> any SpriteSource {
        switch look {
        case .alchemy: AlchemyBoatSprites()
        case .industrial: IndustrialBoatSprites()
        default: IronBoatSprites()
        }
    }

    private func write(_ image: CGImage, _ name: String) throws {
        let url = directory.appendingPathComponent("\(name).png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Preview.writePNG(image, to: url)
    }

    /// One animated GIF for each look: each pose in turn, the five views side by
    /// side drawn large from the same drawing, and beneath them the sprites at
    /// game size, each view beside its mirror, as the drawing shows the facings toward the left.
    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = NavyShipSprites()
        let scale = 1.5
        let width = 2000, height = 820, cell = 395.0
        let background = try StoneBoatsRenders.water(width: width, height: height, scale: 1.6).makeImage()!
        for look in Self.looks {
            let large = NavyShip.canvas(look).scaled(to: Canvas.person.pixelsPerUnit * scale)
            var frames: [CGImage] = []
            for pose in Self.poses {
                for i in 0..<(pose == .standing ? 24 : 36) {
                    let frame = i % 12
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(background, in: CGRect(x: 0, y: 0, width: width, height: height))
                    for (v, view) in SpriteView.allCases.enumerated() {
                        let drawn = try #require(NavyShip.render(look, pose, frame: frame, view: view, canvas: large))
                        Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: large.anchor,
                                      at: CGPoint(x: 200 + Double(v) * cell, y: 400), in: context)
                        Preview.label(view.rawValue, in: context, at: CGPoint(x: 150 + Double(v) * cell, y: 250), size: 18)
                        let sprite = try #require(source.sprite(SpriteKey(.unit(.navyShip, look), pose, frame: frame, view: view)))
                        let tinted = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                        Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 110 + Double(v) * cell, y: 110), in: context)
                        context.saveGState()
                        context.translateBy(x: 290 + Double(v) * cell, y: 0)
                        context.scaleBy(x: -1, y: 1)
                        Preview.place(tinted, anchor: sprite.anchor, at: CGPoint(x: 0, y: 110), in: context)
                        context.restoreGState()
                    }
                    Preview.label("The navy ship, \(Self.name(look)), in Sumer's colour: \(Self.caption(look, pose)), 12 frames a second",
                                  in: context, at: CGPoint(x: 28, y: Double(height) - 48), size: 24)
                    Preview.label("at game size, each view and its mirror", in: context, at: CGPoint(x: 28, y: 20), size: 16)
                    frames.append(context.makeImage()!)
                }
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("navy-ship-\(look.name.lowercased()).gif"))
        }
    }

    /// One still sheet for each look: every view (columns) in every pose
    /// (rows) drawn large, the fighting pose in the frame after the shot; and
    /// beneath, at game size, the ship standing beside the fishing boat of its look.
    @Test func sheets() throws {
        let source = NavyShipSprites()
        for look in Self.looks {
            let large = NavyShip.canvas(look).scaled(to: Canvas.person.pixelsPerUnit * 1.6)
            let cellW = large.pixelWidth, cellH = large.pixelHeight, top = 70, foot = 300
            let width = cellW * 5, height = cellH * 3 + top + foot
            let context = try StoneBoatsRenders.water(width: width, height: height, scale: 1.6)
            for (row, pose) in Self.poses.enumerated() {
                for (column, view) in SpriteView.allCases.enumerated() {
                    let frame = pose == .fighting ? 2 : 0
                    let drawn = try #require(NavyShip.render(look, pose, frame: frame, view: view, canvas: large))
                    let x = Double(column * cellW), y = Double(height - top - (row + 1) * cellH)
                    context.draw(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour),
                                 in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(pose.rawValue), \(view.rawValue)", in: context, at: CGPoint(x: x + 10, y: y + 10), size: 18)
                }
            }
            let ship = try #require(source.sprite(SpriteKey(.unit(.navyShip, look), .standing)))
            let boat = try #require(Self.fishingBoat(look).sprite(SpriteKey(.unit(.fishingBoat, look), .standing)))
            Preview.place(Preview.tinted(base: ship.base, mask: ship.teamMask, colour: colour), anchor: ship.anchor,
                          at: CGPoint(x: 260, y: 110), in: context)
            Preview.place(Preview.tinted(base: boat.base, mask: boat.teamMask, colour: colour), anchor: boat.anchor,
                          at: CGPoint(x: 520, y: 110), in: context)
            Preview.label("at game size: the navy ship beside the fishing boat of its look", in: context, at: CGPoint(x: 40, y: 230), size: 18)
            Preview.label("The navy ship, \(Self.name(look)), every view and pose, in Sumer's colour", in: context,
                          at: CGPoint(x: 24, y: Double(height) - 46), size: 26)
            try write(context.makeImage()!, "navy-ship-\(look.name.lowercased())-sheet")
        }
    }

    /// Each pose's 12 frames in the side and front-quarter views, enlarged in rows of six, for looking at frame by frame.
    @Test func strips() throws {
        for look in Self.looks {
            let large = NavyShip.canvas(look).scaled(to: 2.2)
            let cellW = large.pixelWidth, cellH = large.pixelHeight
            for pose in Self.poses {
                let views: [SpriteView] = [.side, .frontQuarter]
                let width = cellW * 6, height = cellH * 2 * views.count
                let context = try StoneBoatsRenders.water(width: width, height: height, scale: 2.2)
                for (v, view) in views.enumerated() {
                    for frame in 0..<12 {
                        let drawn = try #require(NavyShip.render(look, pose, frame: frame, view: view, canvas: large))
                        let x = Double(frame % 6 * cellW), y = Double(height - (v * 2 + frame / 6 + 1) * cellH)
                        context.draw(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour),
                                     in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                        Preview.label("\(view.rawValue) \(frame)", in: context, at: CGPoint(x: x + 6, y: y + 6), size: 16)
                    }
                }
                try write(context.makeImage()!, "strips/navy-ship-\(look.name.lowercased())-\(pose.rawValue)")
            }
        }
    }
}
