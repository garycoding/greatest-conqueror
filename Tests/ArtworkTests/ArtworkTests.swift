// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import Testing
import GameCore
@testable import Artwork

@Test func emptySourceHasNoSprites() {
    let source = EmptySpriteSource()
    for key in SpriteKey.required(through: .farms) { #expect(source.sprite(key) == nil) }
}

/// The pixels of an image, as premultiplied RGBA bytes in sRGB.
struct Pixels: Equatable {
    let width: Int, height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width; height = image.height
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = Array(UnsafeBufferPointer(start: context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4),
                                          count: width * height * 4))
    }

    /// The alpha at a pixel, with (0, 0) at the top left.
    func alpha(_ x: Int, _ y: Int) -> UInt8 { bytes[(y * width + x) * 4 + 3] }
}

/// The first batch of artwork (docs/art-style.md): the people of the Stone age.
@Suite(.serialized)
struct StonePeopleTests {
    /// The batch: every person of the checklist in its Stone-age look, each pose at every frame.
    static let batch: [SpriteKey] = SpriteKey.required(through: .towns).filter {
        // The car, of no age, is its own batch, and the boat belongs to the boats' batch (`StoneBoatSprites`).
        if case .unit(let kind, .stone) = $0.subject { return kind != .car && kind != .fishingBoat }
        return false
    }.flatMap { key in (0..<12).map { SpriteKey(key.subject, key.pose, frame: $0) } }

    @Test func theBatchIsTheStonePeopleInTheirPoses() {
        let kinds = Set(Self.batch.compactMap { key -> UnitKind? in
            if case .unit(let kind, _) = key.subject { return kind }
            return nil
        })
        #expect(kinds == [.worker])
        // Standing, walking, working and fighting for the worker, 12 frames each.
        #expect(Self.batch.count == 4 * 12)
        #expect(Set(CartoonSprites().keys) == Set(Self.batch))
    }

    @Test func everyKeyOfTheBatchHasASpriteStandingBetweenItsFeetWithATeamMask() throws {
        let sprites = CartoonSprites()
        for key in Self.batch {
            let sprite = try #require(sprites.sprite(key), "\(key)")
            // Drawn at twice its size in points, anchored at the figure's origin.
            #expect(sprite.anchor == Canvas.person.anchor, "\(key)")
            #expect(sprite.base.width == Canvas.person.pixelWidth && sprite.base.height == Canvas.person.pixelHeight, "\(key)")
            let base = Pixels(sprite.base)
            // The lowest solid pixels (the feet, or what stands on the ground beside
            // them) lie on the anchor's row.
            let anchorY = base.height - Int((sprite.anchor.y * Double(base.height)).rounded())
            let solidRows = (0..<base.height).filter { y in (0..<base.width).contains { base.alpha($0, y) > 200 } }
            let lowest = try #require(solidRows.last)
            #expect(abs(lowest - anchorY) <= 3, "\(key): the lowest solid row is \(lowest), the anchor's \(anchorY)")
            // The team's colour: a mask of the same size, not empty, and only where the figure is.
            let mask = Pixels(try #require(sprite.teamMask, "\(key) has no mask"))
            #expect(mask.width == base.width && mask.height == base.height)
            var covered = 0, outside = 0
            for i in stride(from: 3, to: mask.bytes.count, by: 4) where mask.bytes[i] > 25 {
                covered += 1
                if base.bytes[i] == 0 { outside += 1 }
            }
            #expect(covered > 40, "\(key): the mask covers \(covered) pixels")
            #expect(outside == 0, "\(key): \(outside) mask pixels lie outside the figure")
        }
    }

    @Test func theAnchorIsBetweenTheFeetAndTheLowerFootIsOnTheGround() throws {
        for key in Self.batch {
            guard case .unit(let kind, _) = key.subject else { continue }
            let rig = try #require(StonePeople.person(kind)?.rig(key.pose, key.frame), "\(key)")
            let d = Drawing(layer: .base, rig: rig, phase: 0)
            let back = d.worldFoot(front: false), front = d.worldFoot(front: true)
            #expect(abs(max(back.y, front.y)) < 1e-9, "\(key)")
            // The anchor (the figure's origin) lies between the feet: between the
            // rearmost heel and the foremost toe (4.5 units ahead of its heel).
            #expect(min(back.x, front.x) <= 0 && max(back.x, front.x) + 4.5 >= 0, "\(key): heels at \(back.x) and \(front.x)")
        }
    }

    @Test func aPersonIsAbout48PointsTall() throws {
        let sprites = CartoonSprites()
        // Standing, from the top of the hair to the feet.
        for key in Self.batch where key.pose == .standing && key.frame == 0 {
            let base = Pixels(try #require(sprites.sprite(key)).base)
            let rows = (0..<base.height).filter { y in (0..<base.width).contains { base.alpha($0, y) > 200 } }
            let height = Double(try #require(rows.last) - (try #require(rows.first))) / 2
            #expect(height > 44 && height < 54, "\(key): \(height) points")
        }
    }

    @Test func nothingIsCutOffAtTheEdges() throws {
        let sprites = CartoonSprites()
        for key in Self.batch {
            let sprite = try #require(sprites.sprite(key))
            for image in [sprite.base, try #require(sprite.teamMask)] {
                let p = Pixels(image)
                let border = (0..<p.width).flatMap { [($0, 0), ($0, p.height - 1)] } + (0..<p.height).flatMap { [(0, $0), (p.width - 1, $0)] }
                #expect(border.allSatisfy { p.alpha($0.0, $0.1) == 0 }, "\(key) reaches the edge of its picture")
            }
        }
    }

    @Test func everyPoseMovesThroughItsTwelveFrames() throws {
        let sprites = CartoonSprites()
        for pose in sprites.poses {
            let frames = try (0..<12).map { try #require(sprites.sprite(SpriteKey(pose.subject, pose.pose, frame: $0))) }
            let distinct = Set(frames.map { Pixels($0.base).bytes })
            #expect(distinct.count >= 8, "\(pose): only \(distinct.count) different frames")
        }
    }

    @Test func everyOtherKeyHasNoSprite() {
        let sprites = CartoonSprites()
        var others: [SpriteKey] = []
        // Frames outside the cycle, and poses that are not drawn.
        for key in Self.batch where key.frame == 0 {
            for frame in [-1, 12, 13, 100] { others.append(SpriteKey(key.subject, key.pose, frame: frame)) }
            others.append(SpriteKey(key.subject, "dancing"))
        }
        // Every person in the look of a later age, and the kinds of later ages.
        for kind in UnitKind.allCases {
            for age in Look.allCases where age != .stone || kind != .worker {
                for pose in [SpritePose.standing, .walking, .working, .fighting] { others.append(SpriteKey(.unit(kind, age), pose)) }
            }
        }
        // Buildings, sites and terrain.
        others += SpriteKey.required(through: .farms).filter { if case .unit = $0.subject { return false }; return true }
        for key in others { #expect(sprites.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesIdenticalPixelsEveryTime() throws {
        let first = CartoonSprites(), second = CartoonSprites()
        for key in Self.batch {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(Pixels(a.base) == Pixels(b.base), "\(key)")
            #expect(Pixels(try #require(a.teamMask)) == Pixels(try #require(b.teamMask)), "\(key)")
            // A sprite asked for again is the one already drawn.
            #expect(first.sprite(key)?.base === a.base)
        }
    }

    @Test func theWholeBatchIsDrawnInUnderThreeSeconds() {
        let sprites = CartoonSprites()
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for key in Self.batch { _ = sprites.sprite(key) }
        }
        print("The Stone age's people, \(Self.batch.count) sprites, drawn in \(elapsed)")
        #expect(elapsed < .seconds(3))
    }

    @Test func eachKindHasItsOwnNose() {
        let noses: [UnitKind: Nose] = [.worker: .curve]
        for (kind, nose) in noses {
            #expect(StonePeople.nose(kind) == nose, "\(kind)")
        }
    }
}
