// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The people new in the age of hospitals (`IndustrialNewPeopleSprites`): the
/// doctor and knight 3. Every key of the batch has a sprite that stands on its
/// anchor and carries a mask, in every view; every other key has none; a key
/// always gives the same pixels; each frame of a moving pose differs; the two
/// stand as tall as the kinds they stand beside; and the batch is drawn quickly.
@Suite(.serialized) struct IndustrialNewPeopleTests {
    private let source = IndustrialNewPeopleSprites()

    @Test func theBatchIsTheDoctorHealingAndKnightThreeFighting() {
        let expected = SpriteKey.required(through: .hospitals).filter { key in
            guard case .unit(let kind, .industrial) = key.subject else { return false }
            return kind == .doctor || (kind == .knight3 && key.pose != .working)
        }
        #expect(source.poses == expected)
        #expect(Set(source.poses.filter { $0.subject == .unit(.doctor, .industrial) }.map(\.pose)) == [.standing, .walking, .working])
        #expect(Set(source.poses.filter { $0.subject == .unit(.knight3, .industrial) }.map(\.pose)) == [.standing, .walking, .fighting])
        #expect(source.keys.count == 6 * SpriteKey.framesPerPose)
    }

    @Test func theKindsAreNoLongerDrawnAsStandIns() {
        #expect(StandIn.unit(.doctor) == .doctor)
        #expect(StandIn.unit(.knight3) == .knight3)
        #expect(SpriteSubject.of(.unit(.doctor), ownerAge: .hospitals) == .unit(.doctor, .industrial))
        #expect(SpriteSubject.of(.unit(.knight3), ownerAge: .hospitals) == .unit(.knight3, .industrial))
        #expect(StandIn.scale(.unit(.knight3)) == 1 && StandIn.scale(.unit(.doctor)) == 1)
    }

    @Test(arguments: SpriteView.allCases)
    func everyKeyHasASpriteWithAMaskStandingOnItsAnchor(_ view: SpriteView) throws {
        for key in source.keys.map({ $0.seen(view) }) {
            let sprite = try #require(source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "\(key) has no team colour")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height, "\(key)")
            #expect(Pixels(mask).hasCoverage, "\(key)")
            guard case .unit(let kind, _) = key.subject else { continue }
            let pixels = Pixels(sprite.base)
            if kind == .doctor {
                #expect(sprite.base.width == Canvas.person.pixelWidth && sprite.base.height == Canvas.person.pixelHeight, "\(key)")
                #expect(pixels.standsOn(sprite.anchor, bothSides: key.pose == .standing && view == .side),
                        "\(key): the anchor is not on the ground between the feet")
            } else {
                #expect(pixels.centresContact(at: sprite.anchor, view: view), "\(key): the anchor is not at the centre of the ground contact")
            }
        }
    }

    @Test func theMissingPosesAndEveryOtherKeyHaveNone() {
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
        // The doctor does not attack, and the knight never works.
        #expect(source.sprite(SpriteKey(.unit(.doctor, .industrial), .fighting)) == nil)
        #expect(source.sprite(SpriteKey(.unit(.knight3, .industrial), .working)) == nil)
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = IndustrialNewPeopleSprites()
        for key in source.keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(Pixels(first.base) == Pixels(second.base), "\(key)")
            #expect(first.teamMask.map(Pixels.init) == second.teamMask.map(Pixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }

    @Test func everyFrameOfAMovingPoseDiffers() throws {
        for pose in source.poses where pose.pose != .standing {
            var seen: [Pixels] = []
            for frame in 0..<SpriteKey.framesPerPose {
                let pixels = Pixels(try #require(source.sprite(SpriteKey(pose.subject, pose.pose, frame: frame))).base)
                #expect(!seen.contains(pixels), "\(pose) frame \(frame) repeats an earlier frame")
                seen.append(pixels)
            }
        }
    }

    @Test func eachStandsAsTallAsTheKindItStandsBeside() throws {
        // The doctor beside the factory hand, a top hat taller; knight 3 beside knight 2, whose stand-in he replaces.
        func height(_ source: any SpriteSource, _ subject: SpriteSubject) throws -> Double {
            let sprite = try #require(source.sprite(SpriteKey(subject, .standing)))
            return Double(try #require(Pixels(sprite.base).drawnHeight))
        }
        let doctor = try height(source, .unit(.doctor, .industrial))
        let hand = try height(IndustrialPeopleSprites(), .unit(.worker, .industrial))
        #expect(doctor / hand > 0.95 && doctor / hand < 1.2, "the doctor is \(doctor) high, the factory hand \(hand)")
        let knight3 = try height(source, .unit(.knight3, .industrial))
        let knight2 = try height(AlchemyWarriorSprites(), .unit(.knight2, .alchemy))
        #expect(knight3 / knight2 > 0.9 && knight3 / knight2 < 1.1, "knight 3 is \(knight3) high, knight 2 \(knight2)")
        let canvas3 = try #require(source.sprite(SpriteKey(.unit(.knight3, .industrial), .standing)))
        let canvas2 = try #require(AlchemyWarriorSprites().sprite(SpriteKey(.unit(.knight2, .alchemy), .standing)))
        #expect(canvas3.base.width == canvas2.base.width && canvas3.base.height == canvas2.base.height && canvas3.anchor == canvas2.anchor)
    }

    @Test func theKindsAreToldApartFromTheirNeighbours() throws {
        // At game size, the doctor is not the factory hand, and knight 3 is not knight 2.
        let doctor = Pixels(try #require(source.sprite(SpriteKey(.unit(.doctor, .industrial), .standing))).base)
        let hand = Pixels(try #require(IndustrialPeopleSprites().sprite(SpriteKey(.unit(.worker, .industrial), .standing))).base)
        #expect(doctor.difference(hand) > 0.04)
        let knight3 = Pixels(try #require(source.sprite(SpriteKey(.unit(.knight3, .industrial), .standing))).base)
        let knight2 = Pixels(try #require(AlchemyWarriorSprites().sprite(SpriteKey(.unit(.knight2, .alchemy), .standing))).base)
        #expect(knight3.difference(knight2) > 0.04)
    }

    @Test func theBatchRendersInUnderFourSeconds() {
        let fresh = IndustrialNewPeopleSprites()
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for key in fresh.keys { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(4), "the batch took \(elapsed)")
    }

    // MARK: Pixels

    /// An image's pixels as premultiplied RGBA bytes, rows from the top.
    struct Pixels: Equatable {
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

        /// The rows from the highest to the lowest opaque pixel, the shadow aside.
        var drawnHeight: Int? {
            let opaque = (0..<height).filter { row in (0..<width).contains { bytes[(row * width + $0) * 4 + 3] > 200 } }
            guard let top = opaque.first, let bottom = opaque.last else { return nil }
            return bottom - top + 1
        }

        /// The share of pixels that differ markedly between two pictures of the same size.
        func difference(_ other: Pixels) -> Double {
            guard width == other.width, height == other.height else { return 1 }
            var differing = 0
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let d = (0..<4).map { abs(Int(bytes[i + $0]) - Int(other.bytes[i + $0])) }.max() ?? 0
                if d > 60 { differing += 1 }
            }
            return Double(differing) / Double(width * height)
        }

        /// Whether the pixel is the dark line, opaque: an outline, a leg, a hoof.
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

        /// The columns with ink in the rows just above the ground row, within `near` of `x` when it is given.
        func contact(_ ground: Int, rows: Int, near: ClosedRange<Int>? = nil) -> [Int] {
            let columns = near ?? 0...(width - 1)
            return (max(0, ground - rows)...min(height - 1, ground + 2)).flatMap { row in columns.filter { ink($0, row) } }
        }

        /// A person stands on the anchor: the lowest ink is on its row, and the
        /// ink near the ground spans its column, with ink on both sides of it
        /// when `bothSides`. Only the columns within a stance of the anchor
        /// count, so that the bag on the ground before him does not stand in for his feet.
        func standsOn(_ anchor: SpriteAnchor, bothSides: Bool) -> Bool {
            let (x, ground) = place(anchor)
            guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
            let columns = contact(ground, rows: 10, near: max(0, x - 18)...min(width - 1, x + 18))
            guard let left = columns.min(), let right = columns.max() else { return false }
            return bothSides ? left < x - 2 && right > x + 2 : left <= x + 3 && right >= x - 3
        }

        /// A horse's hooves meet the ground on the anchor's row. From the
        /// side, they do so on both sides of its column, and the anchor is near
        /// the middle of what touches the ground. From the other views the far
        /// legs stand aside from the near ones, as the knight's do, and a trot
        /// may set both hooves on the ground to one side; there the hooves on
        /// the ground need only be within half the horse's length of the anchor.
        func centresContact(at anchor: SpriteAnchor, view: SpriteView) -> Bool {
            let (x, ground) = place(anchor)
            guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
            let columns = contact(ground, rows: 4)
            guard let left = columns.min(), let right = columns.max() else { return false }
            // Half the horse's length from hoof to hoof at game size, and a little over.
            let reach = Int(26 * Canvas.person.pixelsPerUnit * AlchemyWarriorsKnight.horseScale * 1.3)
            guard view == .side else { return left > x - reach && right < x + reach }
            guard left < x - 6, right > x + 6 else { return false }
            return abs(Double(left + right) / 2 - Double(x)) <= Double(right - left) * 0.2
        }
    }
}

/// Renders the batch for a person to judge, into the directory named by the
/// environment variable `INDUSTRIAL_NEW_PEOPLE_RENDERS`; skipped when it is not set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["INDUSTRIAL_NEW_PEOPLE_RENDERS"] != nil))
struct IndustrialNewPeopleRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["INDUSTRIAL_NEW_PEOPLE_RENDERS"] ?? "/", isDirectory: true)
    private let sprites = IndustrialNewPeopleSprites()
    private static let kinds: [UnitKind] = [.doctor, .knight3]

    private static func caption(_ kind: UnitKind, _ pose: SpritePose) -> String {
        switch (kind, pose) {
        case (.doctor, .standing): "standing: a breath, and a blink, the bag in hand"
        case (.doctor, .walking): "walking: the bag swinging with the stride"
        case (.doctor, .working): "working: healing, the bandage unrolled toward the patient"
        case (.knight3, .standing): "standing: the horse breathes, the sabre at the carry"
        case (.knight3, .walking): "walking: the charge at the trot, the point lowered"
        case (.knight3, .fighting): "fighting: the sabre whirled back and cut down"
        default: pose.rawValue
        }
    }

    private static func name(_ kind: UnitKind) -> String { kind == .doctor ? "doctor" : "knight3" }

    private func poses(_ kind: UnitKind) -> [SpritePose] {
        sprites.poses.filter { $0.subject == .unit(kind, .industrial) }.map(\.pose)
    }

    /// For each kind and pose, its 12 frames enlarged in two rows of six, for looking at frame by frame.
    @Test func posesAsStrips() throws {
        let strips = directory.appendingPathComponent("strips")
        try FileManager.default.createDirectory(at: strips, withIntermediateDirectories: true)
        let colour = TeamColour.of(.sumer)
        for kind in Self.kinds {
            let look = try #require(IndustrialNewPeopleLooks.look(kind))
            let large = IndustrialNewPeopleLooks.canvas(kind).scaled(to: kind == .knight3 ? 3 : 4)
            for view in [SpriteView.side, .frontQuarter, .front, .back, .backQuarter] {
                for pose in poses(kind) {
                    let cellW = large.pixelWidth, cellH = large.pixelHeight
                    let width = cellW * 6, height = cellH * 2
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
                    for frame in 0..<12 {
                        let drawn = try #require(look.render(pose, frame: frame, canvas: large, view: view))
                        let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                        let x = Double(frame % 6 * cellW), y = Double(height - (frame / 6 + 1) * cellH)
                        context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                        Preview.label("\(frame)", in: context, at: CGPoint(x: x + 8, y: y + 8), size: 18)
                    }
                    try Preview.writePNG(context.makeImage()!, to: strips.appendingPathComponent("\(Self.name(kind))-\(pose.rawValue)-\(view.rawValue).png"))
                }
            }
        }
    }

    /// One animated GIF per kind at 12 frames a second: each pose in turn on a
    /// patch of ground, in Sumer's colour, drawn large from the same SVG, and
    /// beside it the sprite itself at game size.
    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let colour = TeamColour.of(.sumer)
        let width = 1440, height = 640, groundLine = 96.0
        let ground = Preview.ground(width: width, height: height, tile: 256, grained: false)
        for kind in Self.kinds {
            let look = try #require(IndustrialNewPeopleLooks.look(kind))
            let scale = kind == .knight3 ? 3.0 : 4.0
            let large = IndustrialNewPeopleLooks.canvas(kind).scaled(to: scale)
            var frames: [CGImage] = []
            for pose in poses(kind) {
                let walking = pose == .walking
                let count = pose == .standing ? 24 : 36
                for i in 0..<count {
                    let frame = i % 12
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                    let drawn = try #require(look.render(pose, frame: frame, canvas: large))
                    let big = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                    // Walking, a figure covers 4 units of ground a frame, as the approved worker does.
                    let x = walking ? 290 + Double(i) * 4 * scale : 230 + (kind == .knight3 ? 100 : 140)
                    Preview.place(big, anchor: large.anchor, at: CGPoint(x: x, y: groundLine), in: context)
                    let sprite = try #require(sprites.sprite(SpriteKey(.unit(kind, .industrial), pose, frame: frame)))
                    let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                    let sx = walking ? 1200 + Double(i) * 1.6 : 1250
                    Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: sx, y: groundLine), in: context)
                    Preview.label("\(kind.stageName(at: .hospitals)), Industrial age, in Sumer's colour", in: context,
                                  at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                    Preview.label(Self.caption(kind, pose) + ", 12 frames a second", in: context, at: CGPoint(x: 28, y: 28), size: 22)
                    Preview.label("at game size", in: context, at: CGPoint(x: 1210, y: 60), size: 18)
                    frames.append(context.makeImage()!)
                }
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(Self.name(kind)).gif"))
        }
    }

    /// One still sheet per kind: every pose (rows, at frames 0 and 6) in every
    /// view and facing (columns: the five views drawn and the three mirrored),
    /// at game size enlarged twice, in Sumer's colour.
    @Test func sheets() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let facings: [Facing] = [.right, .downRight, .down, .downLeft, .left, .upLeft, .up, .upRight]
        for kind in Self.kinds {
            let subject = SpriteSubject.unit(kind, .industrial)
            let k = 2.0
            let column = kind == .knight3 ? 360.0 : 240.0, row = kind == .knight3 ? 380.0 : 290.0
            let rows = poses(kind).flatMap { pose in [(pose, 0), (pose, 6)] }
            let left = 170.0, top = 110.0
            let width = Int(left + column * Double(facings.count) + 20), height = Int(top + row * Double(rows.count) + 30)
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(Preview.ground(width: width, height: height, tile: 128), in: CGRect(x: 0, y: 0, width: width, height: height))
            Preview.label("\(kind.stageName(at: .hospitals)), Industrial age: every pose (frames 0 and 6) in every facing, five views drawn and three mirrored, game size enlarged twice",
                          in: context, at: CGPoint(x: 20, y: Double(height) - 40), size: 17)
            for (i, facing) in facings.enumerated() {
                Preview.label("\(facing) (\(facing.view.rawValue)\(facing.mirrored ? ", mirrored" : ""))", in: context,
                              at: CGPoint(x: left + Double(i) * column + 10, y: Double(height) - 80), size: 14)
            }
            for (r, (pose, frame)) in rows.enumerated() {
                let ground = Double(height) - top - Double(r + 1) * row + 30
                Preview.label("\(pose.rawValue) \(frame)", in: context, at: CGPoint(x: 16, y: ground + 60), size: 16)
                for (i, facing) in facings.enumerated() {
                    let sprite = try #require(sprites.sprite(SpriteKey(subject, pose, frame: frame, view: facing.view)))
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
                    let at = CGPoint(x: left + Double(i) * column + column / 2, y: ground)
                    context.saveGState()
                    context.translateBy(x: at.x, y: at.y)
                    context.scaleBy(x: facing.mirrored ? -k : k, y: k)
                    Preview.place(image, anchor: sprite.anchor, at: .zero, in: context)
                    context.restoreGState()
                }
            }
            try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("\(Self.name(kind))-sheet.png"))
        }
    }

    /// The line of the tiers and the neighbours: the three knights side by
    /// side, and the doctor beside the factory hand and the rifleman, drawn
    /// large and at game size, in the colours of Rome and Angkor.
    @Test func contactSheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let columns: [(String, any PersonLook, Canvas, any SpriteSource, SpriteSubject)] = [
            ("Knight 1, Iron", IronWarriorsHorseman(), IronWarriorsLooks.canvas(.knight1), IronWarriorSprites(), .unit(.knight1, .iron)),
            ("Knight 2, Alchemy", AlchemyWarriorsKnight(), AlchemyWarriorsKnight.canvas, AlchemyWarriorSprites(), .unit(.knight2, .alchemy)),
            ("Knight 3, Industrial", IndustrialNewPeopleCavalryman(), IndustrialNewPeopleCavalryman.canvas, sprites, .unit(.knight3, .industrial)),
            ("Factory hand", IndustrialPeopleFactoryHand(), .person, IndustrialPeopleSprites(), .unit(.worker, .industrial)),
            ("Rifleman", IndustrialWarriorsRifleman(), IndustrialWarriorsRifleman.canvas, IndustrialWarriorSprites(), .unit(.soldier4, .industrial)),
            ("Doctor", IndustrialNewPeopleDoctor(), .person, sprites, .unit(.doctor, .industrial)),
        ]
        let civilizations: [Civilization] = [.rome, .angkor]
        let column = 520, width = column * columns.count
        let largeRow = 470, smallRow = 200
        let height = 100 + (largeRow + smallRow) * civilizations.count
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The three knights in the line of their tiers, and the doctor beside the Industrial factory hand and rifleman, in the colours of Rome and Angkor",
                      in: context, at: CGPoint(x: 24, y: Double(height) - 48), size: 26)
        for (i, (title, look, canvas, source, subject)) in columns.enumerated() {
            let left = Double(i * column)
            Preview.label(title, in: context, at: CGPoint(x: left + 20, y: Double(height) - 92), size: 22)
            let scale = canvas.width > 140 ? 2.6 : 3.6
            let large = canvas.scaled(to: scale)
            for (r, civilization) in civilizations.enumerated() {
                let tint = TeamColour.of(civilization)
                let top = Double(height - 110 - r * (largeRow + smallRow))
                let drawn = try #require(look.render(.standing, frame: 0, canvas: large))
                let groundY = top - Double(largeRow) + 30
                Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: tint), anchor: large.anchor,
                              at: CGPoint(x: left + Double(column) * 0.45, y: groundY), in: context)
                Preview.label("\(civilization)", in: context, at: CGPoint(x: left + 20, y: top - 30), size: 18)
                for (n, pose) in [SpritePose.standing, .walking].enumerated() {
                    let sprite = try #require(source.sprite(SpriteKey(subject, pose, frame: 3)))
                    Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: tint), anchor: sprite.anchor,
                                  at: CGPoint(x: left + 130 + Double(n) * 230, y: groundY - Double(smallRow) + 40), in: context)
                }
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("contact-sheet.png"))
    }
}
