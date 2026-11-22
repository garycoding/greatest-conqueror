// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The Alchemy age's boat's art (`AlchemyBoatSprites`): the batch is the
/// fishing smack in its poses; every key of it has a sprite on its anchor with
/// a team mask in every view; every other key has none; the smack moves; and a
/// key always gives the same pixels. The boat house is checked with the
/// Alchemy age's older buildings (`AlchemyOldBuildingsTests`).
@Suite(.serialized) struct AlchemyBoatsTests {
    private let source = AlchemyBoatSprites()
    private static let boat = SpriteSubject.unit(.fishingBoat, .alchemy)

    @Test func theBatchIsTheFishingSmack() {
        #expect(source.poses == [SpriteKey(Self.boat, .standing), SpriteKey(Self.boat, .walking), SpriteKey(Self.boat, .working)])
        #expect(source.keys.count == 3 * SpriteKey.framesPerPose)
        #expect(source.drawsViews(of: Self.boat))
        #expect(!source.drawsViews(of: .unit(.fishingBoat, .stone)))
        #expect(UnitKind.fishingBoat.stageName(at: .cannons) == "Fishing smack")
    }

    /// Every frame of every pose in every view: a mask that is not empty and
    /// lies on the picture, the anchor on the waterline in the middle of the
    /// hull (the hull solid a little above it and on both sides of it, and the
    /// lowest solid row near it), and nothing cut off at the canvas's edge.
    @Test func everyViewOfTheSmackHasAMaskAndStandsOnTheWaterline() throws {
        for key in source.keys {
            for view in SpriteView.allCases {
                let key = key.seen(view)
                let sprite = try #require(source.sprite(key), "\(key)")
                #expect(sprite.anchor == AlchemySmack.canvas.anchor, "\(key)")
                let base = SmackPixels(sprite.base)
                let mask = SmackPixels(try #require(sprite.teamMask, "\(key) has no team colour"))
                #expect(mask.width == base.width && mask.height == base.height, "\(key)")
                var covered = 0, outside = 0
                for i in stride(from: 3, to: mask.bytes.count, by: 4) where mask.bytes[i] > 25 {
                    covered += 1
                    if base.bytes[i] == 0 { outside += 1 }
                }
                #expect(covered > 40, "\(key): the mask covers \(covered) pixels")
                #expect(outside == 0, "\(key): \(outside) mask pixels lie outside the picture")
                let (x, row) = base.place(sprite.anchor)
                let hullRows = (row - 14)...(row + 2)
                #expect(hullRows.contains { base.solid(x, $0) }, "\(key): no hull at the anchor")
                #expect(hullRows.contains { r in (x - 14...x - 6).contains { base.solid($0, r) } }, "\(key): no hull left of the anchor")
                #expect(hullRows.contains { r in (x + 6...x + 14).contains { base.solid($0, r) } }, "\(key): no hull right of the anchor")
                let lowest = try #require(base.lowestSolid, "\(key)")
                #expect(lowest >= row - 4 && lowest <= row + 40, "\(key): the lowest solid row is \(lowest), the anchor's \(row)")
                #expect(base.clearAtEdges, "\(key) touches its edge")
            }
        }
    }

    /// Each pose moves in every view, and its cycle closes: the last frame
    /// differs from the first by no more than one frame differs from the next.
    @Test func theSmackMovesInACycle() throws {
        for pose in [SpritePose.standing, .walking, .working] {
            for view in SpriteView.allCases {
                let frames = try (0..<SpriteKey.framesPerPose).map { frame in
                    SmackPixels(try #require(source.sprite(SpriteKey(Self.boat, pose, frame: frame, view: view))).base)
                }
                #expect(frames[0] != frames[3], "\(pose) \(view)")
                let steps = zip(frames, frames.dropFirst()).map { $0.difference($1) }
                let closing = frames[11].difference(frames[0])
                #expect(closing <= (steps.max() ?? 0) * 3 / 2 + 1, "\(pose) \(view): the cycle jumps \(closing), steps up to \(steps.max() ?? 0)")
            }
        }
    }

    @Test func everyOtherKeyHasNone() {
        let batch = Set(source.keys)
        var others = SpriteKey.required(through: .hospitals).filter { !batch.contains($0) }
        for frame in [-1, 12] { others.append(SpriteKey(Self.boat, .walking, frame: frame)) }
        others.append(SpriteKey(Self.boat, .fighting))
        others += [Look.stone, .bronze, .iron, .industrial].map { SpriteKey(.unit(.fishingBoat, $0), .standing) }
        others.append(SpriteKey(.building(.boatHouse, .alchemy), .complete))
        others.append(SpriteKey(.site(.fish), .complete))
        others.append(SpriteKey(.site(.gold), .afloat))
        for key in others { #expect(source.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = AlchemyBoatSprites()
        var keys = source.keys
        keys += [SpriteKey(Self.boat, .walking, frame: 5, view: .frontQuarter), SpriteKey(Self.boat, .working, frame: 7, view: .back)]
        for key in keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(SmackPixels(first.base) == SmackPixels(second.base), "\(key)")
            #expect(first.teamMask.map(SmackPixels.init) == second.teamMask.map(SmackPixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }
}

/// An image's pixels as premultiplied RGBA bytes, rows from the top.
private struct SmackPixels: Equatable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width; height = image.height
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let data = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
        bytes = Array(UnsafeBufferPointer(start: data, count: context.bytesPerRow * height))
    }

    /// Whether the pixel is nearly opaque.
    func solid(_ x: Int, _ row: Int) -> Bool {
        guard x >= 0, x < width, row >= 0, row < height else { return false }
        return bytes[(row * width + x) * 4 + 3] > 200
    }

    /// The anchor as a column and a row from the top.
    func place(_ anchor: SpriteAnchor) -> (x: Int, row: Int) {
        (Int((anchor.x * Double(width)).rounded()), height - Int((anchor.y * Double(height)).rounded()))
    }

    var lowestSolid: Int? { (0..<height).reversed().first { row in (0..<width).contains { solid($0, row) } } }

    var clearAtEdges: Bool {
        let w = width - 1, h = height - 1
        let edge = (0...w).flatMap { [($0, 0), ($0, h)] } + (0...h).flatMap { [(0, $0), (w, $0)] }
        return edge.allSatisfy { bytes[($0.1 * width + $0.0) * 4 + 3] == 0 }
    }

    /// How many pixels differ plainly between two pictures of the same size.
    func difference(_ other: SmackPixels) -> Int {
        var count = 0
        for i in stride(from: 0, to: min(bytes.count, other.bytes.count), by: 4) {
            let d = (0..<4).map { abs(Int(bytes[i + $0]) - Int(other.bytes[i + $0])) }.max() ?? 0
            if d > 40 { count += 1 }
        }
        return count
    }
}
