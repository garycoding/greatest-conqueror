// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The peaceful people of the Iron age (`IronPeopleSprites`): every key of the
/// batch has a sprite that stands on its anchor and carries a mask, every other
/// key has none, a key always gives the same pixels, and the batch is drawn quickly.
@Suite(.serialized) struct IronPeopleTests {
    private let source = IronPeopleSprites()

    @Test func theBatchIsTheChecklistsIronPeacefulSectors() {
        let expected = SpriteKey.required(through: .ships).filter { key in
            if case .unit(let kind, .iron) = key.subject { return [.worker].contains(kind) }
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
            #expect(Self.Pixels(mask).hasCoverage, "\(key)")
            #expect(Self.Pixels(sprite.base).standsOn(sprite.anchor, bothSides: key.pose == .standing),
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
        let again = IronPeopleSprites()
        for key in source.keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(Self.Pixels(first.base) == Self.Pixels(second.base), "\(key)")
            #expect(first.teamMask.map(Self.Pixels.init) == second.teamMask.map(Self.Pixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }

    @Test func everyFrameOfAMovingPoseDiffers() throws {
        for pose in source.poses where pose.pose != .standing {
            var seen: [Self.Pixels] = []
            for frame in 0..<SpriteKey.framesPerPose {
                let sprite = try #require(source.sprite(SpriteKey(pose.subject, pose.pose, frame: frame)))
                let pixels = Self.Pixels(sprite.base)
                #expect(!seen.contains(pixels), "\(pose) frame \(frame) repeats an earlier frame")
                seen.append(pixels)
            }
        }
    }

    @Test func theBatchRendersInUnderFourSeconds() {
        let fresh = IronPeopleSprites()
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

        /// A person stands on the anchor: the lowest ink is on its row, and the
        /// ink near the ground (the feet and what touches the ground) spans its
        /// column, with ink on both sides of it when `bothSides`. Only the
        /// columns within a person's reach of the anchor count, so that the
        /// trader's donkey behind him does not stand in for his feet.
        func standsOn(_ anchor: SpriteAnchor, bothSides: Bool) -> Bool {
            let (x, ground) = place(anchor)
            guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
            let near = max(0, x - 30)...min(width - 1, x + 30)
            let columns = (max(0, ground - 14)...min(height - 1, ground + 2)).flatMap { row in near.filter { ink($0, row) } }
            guard let left = columns.min(), let right = columns.max() else { return false }
            return bothSides ? left < x - 2 && right > x + 2 : left <= x + 3 && right >= x - 3
        }
    }
}
