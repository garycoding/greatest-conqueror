// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The warfighters of the Iron age (`IronWarriorSprites`): every key of the
/// batch has a sprite that stands on its anchor and carries a mask, every other
/// key has none, a key always gives the same pixels, and the batch is drawn quickly.
@Suite(.serialized) struct IronWarriorsTests {
    private let source = IronWarriorSprites()

    @Test func theBatchIsTheIronWarriorsStandingWalkingAndFighting() {
        let expected = SpriteKey.required(through: .ships).filter { key in
            guard case .unit(let kind, .iron) = key.subject else { return false }
            return [.soldier2, .knight1].contains(kind) && key.pose != .working
        }
        #expect(source.poses == expected)
        #expect(source.poses.count == 6)
        #expect(Set(source.poses.map(\.pose)) == [.standing, .walking, .fighting])
        #expect(source.keys.count == 6 * SpriteKey.framesPerPose)
    }

    @Test func everyKeyHasASpriteWithAMaskStandingOnItsAnchor() throws {
        for key in source.keys {
            let sprite = try #require(source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "\(key) has no team colour")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height, "\(key)")
            #expect(Self.Pixels(mask).hasCoverage, "\(key)")
            guard case .unit(let kind, _) = key.subject else { continue }
            let pixels = Self.Pixels(sprite.base)
            if kind == .soldier2 {
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
        for kind in [UnitKind.soldier2, .knight1] {
            #expect(source.sprite(SpriteKey(.unit(kind, .iron), .working, frame: 0)) == nil, "\(kind) working")
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = IronWarriorSprites()
        for key in source.keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(Self.Pixels(first.base) == Self.Pixels(second.base), "\(key)")
            #expect(first.teamMask.map(Self.Pixels.init) == second.teamMask.map(Self.Pixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }

    @Test func theBatchRendersInUnderFourSeconds() {
        let fresh = IronWarriorSprites()
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

        /// Whether the pixel is the dark line, opaque: the outline, a leg, a hoof or a tyre.
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

        /// A horse's hooves or a carriage's wheels meet the ground on the
        /// anchor's row, on both sides of its column, and the anchor is near the
        /// middle of what touches the ground.
        func centresContact(at anchor: SpriteAnchor) -> Bool {
            let (x, ground) = place(anchor)
            guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
            let columns = contact(ground, rows: 4)
            guard let left = columns.min(), let right = columns.max(), left < x - 6, right > x + 6 else { return false }
            return abs(Double(left + right) / 2 - Double(x)) <= Double(right - left) * 0.2
        }
    }
}
