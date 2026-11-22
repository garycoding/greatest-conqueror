// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The peaceful people of the Alchemy age (`AlchemyPeopleSprites`): every key
/// of the batch has a sprite that stands on its anchor and carries a mask,
/// every other key has none, a key always gives the same pixels, and the batch
/// is drawn quickly.
@Suite(.serialized) struct AlchemyPeopleTests {
    private let source = AlchemyPeopleSprites()

    @Test func theBatchIsTheChecklistsAlchemyPeacefulSectors() {
        let expected = SpriteKey.required(through: .cannons).filter { key in
            if case .unit(let kind, .alchemy) = key.subject { return [.worker].contains(kind) }
            return false
        }
        #expect(source.poses == expected)
        #expect(source.keys.count == expected.count * SpriteKey.framesPerPose)
        // Standing, walking, working and fighting for the worker.
        #expect(expected.count == 4)
        let fighting = Set(source.poses.filter { $0.pose == .fighting }.compactMap { key -> UnitKind? in
            if case .unit(let kind, _) = key.subject { return kind }
            return nil
        })
        #expect(fighting == [.worker])
    }

    @Test func everyKeyHasASpriteWithAMaskStandingOnItsAnchor() throws {
        for key in source.keys {
            let sprite = try #require(source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "\(key) has no team colour")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height, "\(key)")
            #expect(sprite.base.width == Canvas.person.pixelWidth && sprite.base.height == Canvas.person.pixelHeight, "\(key)")
            #expect(sprite.anchor == Canvas.person.anchor, "\(key)")
            #expect(AlchemyPeoplePixels(mask).hasCoverage, "\(key)")
            #expect(AlchemyPeoplePixels(sprite.base).standsOn(sprite.anchor, bothSides: key.pose == .standing),
                    "\(key): the anchor is not on the ground between the feet")
        }
    }

    @Test func everyOtherKeyHasNone() {
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
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = AlchemyPeopleSprites()
        for key in source.keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(AlchemyPeoplePixels(first.base) == AlchemyPeoplePixels(second.base), "\(key)")
            #expect(first.teamMask.map(AlchemyPeoplePixels.init) == second.teamMask.map(AlchemyPeoplePixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }

    @Test func everyFrameOfAMovingPoseDiffers() throws {
        for pose in source.poses where pose.pose != .standing {
            var seen: [AlchemyPeoplePixels] = []
            for frame in 0..<SpriteKey.framesPerPose {
                let sprite = try #require(source.sprite(SpriteKey(pose.subject, pose.pose, frame: frame)))
                let pixels = AlchemyPeoplePixels(sprite.base)
                #expect(!seen.contains(pixels), "\(pose) frame \(frame) repeats an earlier frame")
                seen.append(pixels)
            }
        }
    }

    @Test func theKindsAreToldApartByTheirLooks() throws {
        // At game size, no two kinds' standing pictures are alike.
        let kinds: [UnitKind] = [.worker]
        let pictures = try kinds.map { kind in
            AlchemyPeoplePixels(try #require(source.sprite(SpriteKey(.unit(kind, .alchemy), .standing))).base)
        }
        for i in pictures.indices {
            for j in pictures.indices where j > i {
                #expect(pictures[i].difference(pictures[j]) > 0.04, "\(kinds[i]) and \(kinds[j]) look alike")
            }
        }
    }

    @Test func theBatchRendersInUnderFourSeconds() {
        let fresh = AlchemyPeopleSprites()
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for key in fresh.keys { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(4), "the batch took \(elapsed)")
    }
}

// MARK: Renders

/// Renders the batch for a person to judge, into the directory named by the
/// environment variable `ALCHEMY_PEOPLE_RENDERS`; skipped when it is not set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ALCHEMY_PEOPLE_RENDERS"] != nil))
struct AlchemyPeopleRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ALCHEMY_PEOPLE_RENDERS"] ?? "/", isDirectory: true)
    private let sprites = AlchemyPeopleSprites()
    private static let kinds: [UnitKind] = [.worker]

    /// A kind's Alchemy-age name, with the sector's name.
    private static func name(_ kind: UnitKind, _ age: Look = .alchemy) -> String { "\(kind.stageName(at: Age(rawValue: age.rawValue)!)) (\(kind))" }

    /// What each kind does in each pose, for the animations' captions.
    private static func caption(_ kind: UnitKind, _ pose: SpritePose) -> String {
        switch (kind, pose) {
        case (_, .standing): "standing: a breath, and a blink"
        case (_, .walking): "walking: a 12-frame stride"
        case (.worker, .working): "working: carving oak with mallet and chisel"
        case (.worker, .fighting): "fighting: a blow of the mallet"
        default: pose.rawValue
        }
    }

    private func poses(_ kind: UnitKind) -> [SpriteKey] { sprites.poses.filter { $0.subject == .unit(kind, .alchemy) } }

    /// For each kind and pose, its 12 frames enlarged (four times the game's
    /// pixels, drawn from the same SVG) in two rows, and beneath them the
    /// sprites themselves at their own size.
    @Test func posesAsStrips() throws {
        let folder = directory.appendingPathComponent("strips")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let large = Canvas.person.scaled(to: 4), small = Canvas.person
        let colour = TeamColour.of(.sumer)
        for kind in Self.kinds {
            let look = try #require(AlchemyPeopleLooks.look(kind))
            for pose in poses(kind) {
                let cellW = large.pixelWidth, cellH = large.pixelHeight
                let width = cellW * 6, height = cellH * 2 + small.pixelHeight + 20
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
                for frame in 0..<12 {
                    let drawn = try #require(look.render(pose.pose, frame: frame, canvas: large))
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    let x = Double(frame % 6 * cellW), y = Double(height - (frame / 6 + 1) * cellH)
                    context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                    Preview.label("\(frame)", in: context, at: CGPoint(x: x + 8, y: y + 8), size: 18)
                    let sprite = try #require(sprites.sprite(SpriteKey(pose.subject, pose.pose, frame: frame)))
                    let smallImage = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    context.draw(smallImage, in: CGRect(x: Double(frame * (small.pixelWidth + 8) + 8), y: 10,
                                                        width: Double(small.pixelWidth), height: Double(small.pixelHeight)))
                }
                try Preview.writePNG(context.makeImage()!, to: folder.appendingPathComponent("\(kind)-\(pose.pose.rawValue).png"))
            }
        }
    }

    /// One animated GIF per kind at 12 frames a second: each of its poses in
    /// turn, on a patch of ground, in Sumer's colour. The figure is drawn large
    /// from the same SVG; beside it, the sprite itself at game size.
    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let colour = TeamColour.of(.sumer)
        let large = Canvas.person.scaled(to: 4)
        let width = 1080, height = 580, groundLine = 104.0
        let ground = Preview.ground(width: width, height: height, tile: 256, grained: false)
        for kind in Self.kinds {
            let look = try #require(AlchemyPeopleLooks.look(kind))
            var frames: [CGImage] = []
            for pose in poses(kind) {
                let walking = pose.pose == .walking
                let count = pose.pose == .standing ? 24 : 36
                for i in 0..<count {
                    let frame = i % 12
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                    let drawn = try #require(look.render(pose.pose, frame: frame, canvas: large))
                    let big = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    // Walking, the figure covers 4 units of ground a frame, as the approved worker does.
                    let x = walking ? 150 + Double(i) * 16 : 300
                    Preview.place(big, anchor: large.anchor, at: CGPoint(x: x, y: groundLine), in: context)
                    let sprite = try #require(sprites.sprite(SpriteKey(pose.subject, pose.pose, frame: frame)))
                    let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    let sx = walking ? 840 + Double(i) * 5 : 930
                    Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: sx, y: groundLine), in: context)
                    Preview.label("\(Self.name(kind)), Alchemy age, in Sumer's colour", in: context,
                                  at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                    Preview.label(Self.caption(kind, pose.pose) + ", 12 frames a second", in: context, at: CGPoint(x: 28, y: 28), size: 22)
                    Preview.label("at game size", in: context, at: CGPoint(x: 870, y: 64), size: 18)
                    frames.append(context.makeImage()!)
                }
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(kind.stageName(at: .cannons).lowercased()).gif"))
        }
    }

    /// Every kind side by side, standing, in two civilizations' colours, the
    /// Iron stage of the same kind beside it: drawn large from the same SVG,
    /// and beneath, as the sprites themselves at game size, standing and at work.
    @Test func contactSheets() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (pair, file) in [([Civilization.rome, .angkor], "contact-sheet-rome-angkor.png"), ([.sumer, .egypt], "contact-sheet-sumer-egypt.png")] {
            try contactSheet(pair, to: directory.appendingPathComponent(file))
        }
    }

    private func contactSheet(_ civilizations: [Civilization], to url: URL) throws {
        let iron = IronPeopleSprites()
        let scale = 3.0
        // Each kind's column: its Iron stage on the left (the trader's donkey reaches far behind him), the Alchemy stage on the right.
        let ironAt: [Double] = Self.kinds.map { _ in 140 }
        let columns: [Double] = Self.kinds.map { _ in 470 }
        let width = Int(columns.reduce(0, +)), largeRow = Int(Canvas.person.height * scale)
        let smallRow = Canvas.person.pixelHeight + 24
        let height = 110 + largeRow * civilizations.count + smallRow * civilizations.count + 50
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
        let names = civilizations.map { "\($0)".capitalized }.joined(separator: " and ")
        Preview.label("The peaceful people of the Alchemy age beside their Iron stages, in the colours of \(names)", in: context,
                      at: CGPoint(x: 24, y: Double(height) - 46), size: 24)
        var left = 0.0
        for (k, kind) in Self.kinds.enumerated() {
            let ironLook = try #require(IronPeopleLooks.look(kind)), look = try #require(AlchemyPeopleLooks.look(kind))
            let ironCanvas = IronPeopleLooks.canvas(kind).scaled(to: scale), canvas = Canvas.person.scaled(to: scale)
            let ironX = left + ironAt[k], alchemyX = ironX + 190
            Preview.label(Self.name(kind), in: context, at: CGPoint(x: alchemyX - 90, y: Double(height) - 88), size: 19)
            Preview.label(kind.stageName(at: .ships), in: context, at: CGPoint(x: ironX - 60, y: Double(height) - 88), size: 15)
            for (row, civilization) in civilizations.enumerated() {
                let colour = TeamColour.of(civilization)
                let baseline = Double(height - 104 - largeRow * (row + 1)) + 22
                let old = try #require(ironLook.render(.standing, frame: 0, canvas: ironCanvas))
                Preview.place(Preview.tinted(base: old.base, mask: old.mask, colour: colour), anchor: ironCanvas.anchor,
                              at: CGPoint(x: ironX, y: baseline), in: context)
                let drawn = try #require(look.render(.standing, frame: 0, canvas: canvas))
                Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour), anchor: canvas.anchor,
                              at: CGPoint(x: alchemyX, y: baseline), in: context)
                // At game size: the Iron stage standing, then the Alchemy stage standing, at work, and fighting where he fights.
                let small = Double(smallRow * (civilizations.count - 1 - row)) + 44
                var x = ironX - 60
                if let sprite = iron.sprite(SpriteKey(.unit(kind, .iron), .standing)) {
                    Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor,
                                  at: CGPoint(x: x, y: small), in: context)
                }
                x += 110
                for (pose, frame) in [(SpritePose.standing, 0), (.working, 5), (.fighting, 7)] {
                    guard let sprite = sprites.sprite(SpriteKey(.unit(kind, .alchemy), pose, frame: frame)) else { continue }
                    Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour), anchor: sprite.anchor,
                                  at: CGPoint(x: x, y: small), in: context)
                    x += 100
                }
            }
            left += columns[k]
        }
        Preview.label("at game size: the Iron stage standing; the Alchemy stage standing, at work, and fighting", in: context,
                      at: CGPoint(x: 24, y: 10), size: 15)
        try Preview.writePNG(context.makeImage()!, to: url)
    }
}

// MARK: Pixels

/// An image's pixels as premultiplied RGBA bytes, rows from the top.
private struct AlchemyPeoplePixels: Equatable {
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

    /// The share of pixels that differ markedly between two pictures of the same size.
    func difference(_ other: AlchemyPeoplePixels) -> Double {
        guard width == other.width, height == other.height else { return 1 }
        var differing = 0
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let d = (0..<4).map { abs(Int(bytes[i + $0]) - Int(other.bytes[i + $0])) }.max() ?? 0
            if d > 60 { differing += 1 }
        }
        return Double(differing) / Double(width * height)
    }

    /// Whether the pixel is the dark line, opaque: an outline, a leg, a foot.
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

    /// A person stands on the anchor: the lowest ink is on its row, and the ink
    /// of the feet near the ground spans its column, with ink on both sides of
    /// it when `bothSides`. Only the columns within a person's stance of the
    /// anchor count, so that a bench or a strongbox on the ground before him
    /// does not stand in for his feet.
    func standsOn(_ anchor: SpriteAnchor, bothSides: Bool) -> Bool {
        let (x, ground) = place(anchor)
        guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
        let near = max(0, x - 18)...min(width - 1, x + 18)
        let columns = (max(0, ground - 10)...min(height - 1, ground + 2)).flatMap { row in near.filter { ink($0, row) } }
        guard let left = columns.min(), let right = columns.max() else { return false }
        return bothSides ? left < x - 2 && right > x + 2 : left <= x + 3 && right >= x - 3
    }
}
