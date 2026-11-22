// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The warfighters of the Alchemy age (`AlchemyWarriorSprites`): the knight,
/// the musketeer and the cannon. Every key of the batch has a sprite that stands on its anchor and carries a mask, every
/// other key has none, a key always gives the same pixels, and the batch is
/// drawn quickly.
@Suite(.serialized) struct AlchemyWarriorsTests {
    private let source = AlchemyWarriorSprites()

    @Test func theBatchIsTheKnightTheMusketeerAndTheCannonStandingWalkingAndFighting() {
        let expected = SpriteKey.required(through: .cannons).filter { key in
            guard case .unit(let kind, .alchemy) = key.subject else { return false }
            return [.knight2, .soldier3, .cannon1].contains(kind) && key.pose != .working
        }
        #expect(source.poses == expected)
        #expect(source.poses.count == 9)
        #expect(Set(source.poses.map(\.pose)) == [.standing, .walking, .fighting])
        #expect(source.keys.count == 9 * SpriteKey.framesPerPose)
    }

    @Test func everyKeyHasASpriteWithAMaskStandingOnItsAnchor() throws {
        for key in source.keys {
            let sprite = try #require(source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "\(key) has no team colour")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height, "\(key)")
            #expect(Self.Pixels(mask).hasCoverage, "\(key)")
            guard case .unit(let kind, _) = key.subject else { continue }
            let pixels = Self.Pixels(sprite.base)
            if kind == .soldier3 {
                #expect(pixels.standsOn(sprite.anchor, bothSides: key.pose == .standing),
                        "\(key): the anchor is not on the ground between the feet")
            } else {
                #expect(pixels.centresContact(at: sprite.anchor),
                        "\(key): the anchor is not at the centre of the ground contact")
            }
        }
    }

    @Test func theWorkingPoseAndEveryOtherKeyHaveNone() {
        let batch = Set(source.keys)
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting, .complete, .underConstruction, "carrying"]
        var others: [SpriteKey] = []
        for kind in UnitKind.allCases {
            for age in Look.allCases {
                for pose in poses {
                    for frame in [-1, 0, 6, 11, 12] { others.append(SpriteKey(.unit(kind, age), pose, frame: frame)) }
                }
            }
        }
        for kind in BuildingKind.allCases {
            for age in Look.allCases { others.append(SpriteKey(.building(kind, age), .complete)) }
        }
        for kind in SiteKind.allCases { others.append(SpriteKey(.site(kind), .complete)) }
        others.append(SpriteKey(.outcrop, .complete))
        for terrain in Terrain.allCases { others.append(SpriteKey(.terrain(terrain, variant: 0), .complete)) }
        let outside = others.filter { !batch.contains($0) }
        #expect(outside.count > 1000)
        for key in outside { #expect(source.sprite(key) == nil, "\(key)") }
        for kind in [UnitKind.knight2, .soldier3, .cannon1] {
            #expect(source.sprite(SpriteKey(.unit(kind, .alchemy), .working, frame: 0)) == nil, "\(kind) working")
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = AlchemyWarriorSprites()
        for key in source.keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(Self.Pixels(first.base) == Self.Pixels(second.base), "\(key)")
            #expect(first.teamMask.map(Self.Pixels.init) == second.teamMask.map(Self.Pixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }

    @Test func theBatchRendersInUnderFourSeconds() {
        let fresh = AlchemyWarriorSprites()
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for key in fresh.keys { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(4), "the batch took \(elapsed)")
    }

    // MARK: Pixels

    /// An image's pixels as premultiplied RGBA bytes, rows from the top.
    private struct Pixels: Equatable {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init(_ image: CGImage) {
            width = image.width; height = image.height
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            // `Raster.bitmap` packs its rows, four bytes to a pixel.
            let data = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
            bytes = Array(UnsafeBufferPointer(start: data, count: context.bytesPerRow * height))
        }

        var hasCoverage: Bool { stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] > 128 } }

        /// Whether the pixel is the dark line, opaque: the outline, a leg, a hoof.
        func ink(_ x: Int, _ row: Int) -> Bool {
            guard x >= 0, x < width, row >= 0, row < height else { return false }
            let i = (row * width + x) * 4
            return bytes[i + 3] > 200 && bytes[i] < 90 && bytes[i + 1] < 90 && bytes[i + 2] < 90
        }

        /// The anchor as a column and a row from the top.
        func place(_ anchor: SpriteAnchor) -> (x: Int, row: Int) {
            (Int((anchor.x * Double(width)).rounded()), height - Int((anchor.y * Double(height)).rounded()))
        }

        /// The lowest row with ink in it.
        var lowestInk: Int? {
            (0..<height).reversed().first { row in (0..<width).contains { ink($0, row) } }
        }

        /// The columns with ink in the rows just above the ground row.
        func contact(_ ground: Int, rows: Int) -> [Int] {
            (max(0, ground - rows)...min(height - 1, ground + 2)).flatMap { row in (0..<width).filter { ink($0, row) } }
        }

        /// A person stands on the anchor: the lowest ink is on its row, and the
        /// ink near the ground spans its column, with ink on both sides of it when `bothSides`.
        func standsOn(_ anchor: SpriteAnchor, bothSides: Bool) -> Bool {
            let (x, ground) = place(anchor)
            guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
            let columns = contact(ground, rows: 14)
            guard let left = columns.min(), let right = columns.max() else { return false }
            return bothSides ? left < x - 2 && right > x + 2 : left <= x + 3 && right >= x - 3
        }

        /// A horse's hooves, or a gun's wheel, trail and crew, meet the ground on the anchor's row, on both sides
        /// of its column, and the anchor is near the middle of what touches the ground.
        func centresContact(at anchor: SpriteAnchor) -> Bool {
            let (x, ground) = place(anchor)
            guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
            let columns = contact(ground, rows: 4)
            guard let left = columns.min(), let right = columns.max(), left < x - 6, right > x + 6 else { return false }
            return abs(Double(left + right) / 2 - Double(x)) <= Double(right - left) * 0.2
        }
    }
}

/// Renders the batch for a person to judge, into the directory named by the
/// environment variable `ALCHEMY_WARRIORS_RENDERS`; skipped when it is not set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ALCHEMY_WARRIORS_RENDERS"] != nil))
struct AlchemyWarriorsRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ALCHEMY_WARRIORS_RENDERS"] ?? "/", isDirectory: true)

    private static let kinds: [UnitKind] = [.knight2, .soldier3, .cannon1]

    private static func caption(_ kind: UnitKind, _ pose: SpritePose) -> String {
        switch (kind, pose) {
        case (.knight2, .standing): "standing: the horse breathes, the lance at rest"
        case (.knight2, .walking): "walking: the charge at the trot, the lance couched"
        case (.knight2, .fighting): "fighting: the sword at close quarters"
        case (.soldier3, .standing): "standing: a breath, and a blink"
        case (.soldier3, .walking): "walking: the musket at the trail, the rest in hand"
        case (.soldier3, .fighting): "fighting: aim, fire, and the slow reload"
        case (.cannon1, .standing): "standing: the crew wait by the gun"
        case (.cannon1, .walking): "walking: pushed and hauled, the wheels turning with the stride"
        case (.cannon1, .fighting): "fighting: fire, recoil, sponge, ram, and run it up"
        default: pose.rawValue
        }
    }

    /// For each kind and pose, its 12 frames enlarged in two rows of six, for
    /// looking at frame by frame.
    @Test func posesAsStrips() throws {
        let strips = directory.appendingPathComponent("strips")
        try FileManager.default.createDirectory(at: strips, withIntermediateDirectories: true)
        let colour = TeamColour.of(.sumer)
        for kind in Self.kinds {
            let look = try #require(AlchemyWarriorsLooks.look(kind))
            let large = AlchemyWarriorsLooks.canvas(kind).scaled(to: 3)
            for pose in [SpritePose.standing, .walking, .fighting] {
                let cellW = large.pixelWidth, cellH = large.pixelHeight
                let width = cellW * 6, height = cellH * 2
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
                for frame in 0..<12 {
                    let drawn = try #require(look.render(pose, frame: frame, canvas: large))
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    let x = Double(frame % 6 * cellW), y = Double(height - (frame / 6 + 1) * cellH)
                    context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(frame)", in: context, at: CGPoint(x: x + 8, y: y + 8), size: 18)
                }
                try Preview.writePNG(context.makeImage()!, to: strips.appendingPathComponent("\(kind)-\(pose.rawValue).png"))
            }
        }
    }

    /// One animated GIF per kind at 12 frames a second: each pose in turn on a
    /// patch of ground, in Sumer's colour, drawn large from the same SVG, and
    /// beside it the sprite itself at game size.
    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = AlchemyWarriorSprites()
        let colour = TeamColour.of(.sumer)
        let width = 1440, height = 640, groundLine = 96.0
        let ground = Preview.ground(width: width, height: height, tile: 256, grained: false)
        for kind in Self.kinds {
            let look = try #require(AlchemyWarriorsLooks.look(kind))
            let canvas = AlchemyWarriorsLooks.canvas(kind)
            let scale = kind == .knight2 ? 3.0 : kind == .cannon1 ? 3.1 : 4.0
            let large = canvas.scaled(to: scale)
            var frames: [CGImage] = []
            for pose in [SpritePose.standing, .walking, .fighting] {
                let walking = pose == .walking
                let count = pose == .standing ? 24 : 36
                for i in 0..<count {
                    let frame = i % 12
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                    let drawn = try #require(look.render(pose, frame: frame, canvas: large))
                    let big = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    // Walking, a figure covers 4 units of ground a frame, as the approved worker
                    // does; the gun covers what its wheels roll.
                    let step = kind == .cannon1 ? AlchemyWarriorsCannon.groundPerFrame : 4
                    let x = walking ? 290 + Double(i) * step * scale : 230 + (kind == .knight2 ? 100 : kind == .cannon1 ? 220 : 140)
                    Preview.place(big, anchor: large.anchor, at: CGPoint(x: x, y: groundLine), in: context)
                    let sprite = try #require(sprites.sprite(SpriteKey(.unit(kind, .alchemy), pose, frame: frame)))
                    let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    let sx = walking ? 1200 + Double(i) * 1.6 : 1250
                    Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: sx, y: groundLine), in: context)
                    Preview.label("\(kind.stageName(at: .cannons)), Alchemy age, in Sumer's colour", in: context,
                                  at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                    Preview.label(Self.caption(kind, pose) + ", 12 frames a second", in: context, at: CGPoint(x: 28, y: 28), size: 22)
                    Preview.label("at game size", in: context, at: CGPoint(x: 1210, y: 60), size: 18)
                    frames.append(context.makeImage()!)
                }
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(kind).gif"))
        }
    }

    /// Every kind side by side in two civilizations' colours (Rome's red and
    /// Angkor's orange, which must stay distinct), each beside the Iron-age
    /// warfighter it follows on from: drawn large, and as the sprites at game
    /// size standing and fighting.
    @Test func contactSheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let alchemy = AlchemyWarriorSprites(), iron = IronWarriorSprites()
        let civilizations: [Civilization] = [.rome, .angkor]
        let column = 560, width = column * 6
        let largeRow = 470, smallRow = 230
        let height = 100 + (largeRow + smallRow) * civilizations.count
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The Alchemy age's knight, musketeer and cannon beside the Iron age's horseman, swordsman and catapult, in the colours of Rome and Angkor",
                      in: context, at: CGPoint(x: 24, y: Double(height) - 48), size: 26)
        let columns: [(UnitKind, Look)] = [(.knight1, .iron), (.knight2, .alchemy), (.soldier2, .iron), (.soldier3, .alchemy), 
                                          (.cannon1, .alchemy)]
        for (i, (kind, age)) in columns.enumerated() {
            let left = Double(i * column)
            Preview.label("\(kind.stageName(at: .towns)), \(age == .iron ? "Iron" : "Alchemy") age", in: context,
                          at: CGPoint(x: left + 20, y: Double(height) - 92), size: 22)
            let look: any PersonLook = try #require(age == .iron ? IronWarriorsLooks.look(kind) : AlchemyWarriorsLooks.look(kind))
            let canvas = age == .iron ? IronWarriorsLooks.canvas(kind) : AlchemyWarriorsLooks.canvas(kind)
            let scale = canvas.width > 180 ? 2.4 : canvas.width > 140 ? 2.6 : 3.4
            let large = canvas.scaled(to: scale)
            let source: any SpriteSource = age == .iron ? iron : alchemy
            for (row, civilization) in civilizations.enumerated() {
                let tint = TeamColour.of(civilization)
                let top = Double(height - 110 - row * (largeRow + smallRow))
                let drawn = try #require(look.render(.standing, frame: 0, canvas: large))
                let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: tint)
                let groundY = top - Double(largeRow) + 30
                Preview.place(image, anchor: large.anchor, at: CGPoint(x: left + Double(column) * 0.45, y: groundY), in: context)
                Preview.label("\(civilization)", in: context, at: CGPoint(x: left + 20, y: top - 30), size: 18)
                for (n, pose) in [SpritePose.standing, .fighting].enumerated() {
                    let sprite = try #require(source.sprite(SpriteKey(.unit(kind, age), pose, frame: pose == .fighting ? 8 : 0)))
                    let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: tint)
                    Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: left + 140 + Double(n) * 260, y: groundY - Double(smallRow) + 40), in: context)
                }
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("contact-sheet.png"))
    }
}
