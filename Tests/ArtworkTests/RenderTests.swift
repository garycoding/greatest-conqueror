// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the batch for a person to judge, into the directory named by the
/// environment variable `ARTWORK_RENDERS`; skipped when it is not set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] != nil))
struct RenderTests {
    let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] ?? "/", isDirectory: true)

    static let kinds: [UnitKind] = [.worker, .scholar, .engineer, .clubman, .slinger, .founder]

    /// A kind's Stone-age name, with the sector's name where the two differ.
    static func name(_ kind: UnitKind) -> String {
        let stage = kind.stageName(at: .stone)
        return stage.lowercased() == "\(kind)" ? stage : "\(stage) (\(kind))"
    }

    /// For each kind and pose, its 12 frames enlarged (three times the game's
    /// pixels, drawn from the same SVG) in two rows, and beneath them the
    /// sprites themselves at their own size.
    @Test func posesAsStrips() throws {
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("strips"), withIntermediateDirectories: true)
        let sprites = CartoonSprites()
        let large = Canvas.person.scaled(to: 4)
        let colour = TeamColour.of(.sumer)
        for pose in sprites.poses {
            guard case .unit(let kind, _) = pose.subject, let look = StonePeople.person(kind) else { continue }
            let cellW = large.pixelWidth, cellH = large.pixelHeight
            let small = Canvas.person
            let width = cellW * 6, height = cellH * 2 + small.pixelHeight + 20
            let ground = Preview.ground(width: width, height: height, tile: 256)
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
            for frame in 0..<12 {
                let drawn = try #require(look.render(pose.pose, frame: frame, canvas: large))
                let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                let col = frame % 6, row = frame / 6
                let x = Double(col * cellW), y = Double(height - (row + 1) * cellH)
                context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                Preview.label("\(frame)", in: context, at: CGPoint(x: x + 8, y: y + 8), size: 18)
                let sprite = try #require(sprites.sprite(SpriteKey(pose.subject, pose.pose, frame: frame)))
                let smallImage = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                context.draw(smallImage, in: CGRect(x: Double(frame * (small.pixelWidth + 8) + 8), y: 10,
                                                    width: Double(small.pixelWidth), height: Double(small.pixelHeight)))
            }
            let name = "\(kind)-\(pose.pose.rawValue).png"
            try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("strips").appendingPathComponent(name))
            // The sprite's own pictures, untinted, for checking pixel by pixel.
            let sprite = try #require(sprites.sprite(SpriteKey(pose.subject, pose.pose, frame: 0)))
            try FileManager.default.createDirectory(at: directory.appendingPathComponent("sprites"), withIntermediateDirectories: true)
            try Preview.writePNG(sprite.base, to: directory.appendingPathComponent("sprites/\(kind)-\(pose.pose.rawValue)-base.png"))
            if let mask = sprite.teamMask {
                try Preview.writePNG(mask, to: directory.appendingPathComponent("sprites/\(kind)-\(pose.pose.rawValue)-mask.png"))
            }
        }
    }

    /// What each kind does in each pose, for the animations' captions.
    static func caption(_ kind: UnitKind, _ pose: SpritePose) -> String {
        switch (kind, pose) {
        case (_, .standing): "standing: a breath, and a blink"
        case (.scholar, .walking): "walking: a slower, shorter stride, leaning on his stick"
        case (_, .walking): "walking: a 12-frame stride"
        case (.worker, .working): "working: the two-handed chop"
        case (.scholar, .working): "working: reading a tablet, until a thought arrives"
        case (.engineer, .working): "working: driving a post"
        case (_, .working): "working: the standing pose serves"
        case (.worker, .fighting): "fighting: a one-handed hack with the axe"
        case (.engineer, .fighting): "fighting: a swing of the mallet"
        case (.clubman, .fighting): "fighting: a two-handed blow of the club"
        case (.slinger, .fighting): "fighting: the sling whirled, and the stone let fly"
        default: pose.rawValue
        }
    }

    /// One animated GIF per kind at 12 frames a second: each of its poses in
    /// turn, on a patch of Stone-age ground, in Sumer's colour. The figure is
    /// drawn large from the same SVG; beside it, the sprite itself at game size.
    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = CartoonSprites()
        let colour = TeamColour.of(.sumer)
        let large = Canvas.person.scaled(to: 4)
        // The enlarged canvas reaches 408 px above the ground line, so the title
        // is set above it.
        let width = 1080, height = 580, groundLine = 104.0
        let ground = Preview.ground(width: width, height: height, tile: 256, grained: false)
        for kind in Self.kinds {
            let look = try #require(StonePeople.person(kind))
            var frames: [CGImage] = []
            for pose in sprites.poses where pose.subject == .unit(kind, .stone) {
                let walking = pose.pose == .walking
                let servesAsStanding = pose.pose == .working && [.clubman, .slinger, .founder].contains(kind)
                let count = pose.pose == .standing ? 24 : (servesAsStanding ? 12 : 36)
                for i in 0..<count {
                    let frame = i % 12
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                    let drawn = try #require(look.render(pose.pose, frame: frame, canvas: large))
                    let big = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    // Walking, the figure covers 4 units of ground a frame, as the approved worker does.
                    let x = walking ? 150 + Double(i) * 16 : 330
                    Preview.place(big, anchor: large.anchor, at: CGPoint(x: x, y: groundLine), in: context)
                    let sprite = try #require(sprites.sprite(SpriteKey(pose.subject, pose.pose, frame: frame)))
                    let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    let sx = walking ? 840 + Double(i) * 5 : 930
                    Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: sx, y: groundLine), in: context)
                    Preview.label("\(Self.name(kind)), Stone age, in Sumer's colour", in: context,
                                  at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                    Preview.label(Self.caption(kind, pose.pose) + ", 12 frames a second", in: context,
                                  at: CGPoint(x: 28, y: 28), size: 22)
                    Preview.label("at game size", in: context, at: CGPoint(x: 870, y: 64), size: 18)
                    frames.append(context.makeImage()!)
                }
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(kind).gif"))
        }
    }

    /// Every kind side by side, standing, in two civilizations' colours: drawn
    /// large from the same SVG, and as the sprites themselves at game size,
    /// standing and in their working or fighting pose.
    @Test func contactSheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = CartoonSprites()
        let civilizations: [Civilization] = [.sumer, .egypt]
        let large = Canvas.person.scaled(to: 3)
        let column = 300, width = column * Self.kinds.count
        let largeRow = large.pixelHeight, smallRow = Canvas.person.pixelHeight + 20
        let height = 90 + largeRow * 2 + smallRow * 2 + 60
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false),
                     in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The people of the Stone age, in the colours of Sumer and Egypt", in: context,
                      at: CGPoint(x: 24, y: Double(height) - 48), size: 26)
        for (i, kind) in Self.kinds.enumerated() {
            let look = try #require(StonePeople.person(kind))
            let centre = Double(i * column + column / 2)
            Preview.label(Self.name(kind), in: context,
                          at: CGPoint(x: Double(i * column) + 20, y: Double(height) - 92), size: 20)
            for (row, civilization) in civilizations.enumerated() {
                let drawn = try #require(look.render(.standing, frame: 0, canvas: large))
                let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: TeamColour.of(civilization))
                let baseline = Double(height - 100 - largeRow * (row + 1)) + 24
                Preview.place(image, anchor: large.anchor, at: CGPoint(x: centre, y: baseline), in: context)
            }
            // At game size: standing, then working (or fighting, for the warfighters), in both colours.
            let action: SpritePose = kind.isWarfighter ? .fighting : .working
            for (row, pose) in [SpritePose.standing, action].enumerated() {
                for (n, civilization) in civilizations.enumerated() {
                    let frame = pose == .standing ? 0 : 7
                    let sprite = try #require(sprites.sprite(SpriteKey(.unit(kind, .stone), pose, frame: frame)))
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(civilization))
                    let baseline = Double(smallRow * (1 - row)) + 40
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: centre - 50 + Double(n) * 100, y: baseline), in: context)
                }
            }
        }
        Preview.label("at game size: standing, and at work or fighting", in: context, at: CGPoint(x: 24, y: 10), size: 16)
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("contact-sheet.png"))
    }
}
