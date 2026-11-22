// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The Stone age's boats' art (`StoneBoatSprites`): the batch is the dugout in
/// its poses, the fish and the rocks afloat; every key of it has a sprite on
/// its anchor, the boat with a team mask in every view and the sites with
/// none; every other key has none; and a key always gives the same pixels.
@Suite(.serialized) struct StoneBoatsTests {
    private let source = StoneBoatSprites()
    private static let boat = SpriteSubject.unit(.fishingBoat, .stone)

    @Test func theBatchIsTheDugoutTheFishAndTheRocksAfloat() {
        #expect(source.poses == [SpriteKey(Self.boat, .standing), SpriteKey(Self.boat, .walking), SpriteKey(Self.boat, .working)])
        #expect(source.keys.count == (3 + 1) * SpriteKey.framesPerPose + 1 + 1)  // the gold rock and the outcrop afloat
        #expect(StoneBoatSprites.rocks == [.gold])
        #expect(source.drawsViews(of: Self.boat))
        #expect(!source.drawsViews(of: .site(.fish)))
    }

    /// Every frame of every pose in every view: a mask that is not empty and
    /// lies on the picture, the anchor on the waterline in the middle of the
    /// hull (the lowest solid row of the hull a little below it, and solid
    /// pixels on both sides of it), and nothing cut off at the canvas's edge.
    @Test func everyViewOfTheBoatHasAMaskAndStandsOnTheWaterline() throws {
        for key in source.keys where key.subject == Self.boat {
            for view in SpriteView.allCases {
                let key = key.seen(view)
                let sprite = try #require(source.sprite(key), "\(key)")
                #expect(sprite.anchor == StoneDugout.canvas.anchor, "\(key)")
                let base = BoatPixels(sprite.base)
                let mask = BoatPixels(try #require(sprite.teamMask, "\(key) has no team colour"))
                #expect(mask.width == base.width && mask.height == base.height, "\(key)")
                var covered = 0, outside = 0
                for i in stride(from: 3, to: mask.bytes.count, by: 4) where mask.bytes[i] > 25 {
                    covered += 1
                    if base.bytes[i] == 0 { outside += 1 }
                }
                #expect(covered > 40, "\(key): the mask covers \(covered) pixels")
                #expect(outside == 0, "\(key): \(outside) mask pixels lie outside the picture")
                let (x, row) = base.place(sprite.anchor)
                // The hull is solid at the anchor or just above it, and reaches to either side of it.
                let hullRows = (row - 14)...(row + 2)
                #expect(hullRows.contains { base.solid(x, $0) }, "\(key): no hull at the anchor")
                #expect(hullRows.contains { r in (x - 14...x - 6).contains { base.solid($0, r) } }, "\(key): no hull left of the anchor")
                #expect(hullRows.contains { r in (x + 6...x + 14).contains { base.solid($0, r) } }, "\(key): no hull right of the anchor")
                // The lowest solid row (the near side of the hull, at the waterline) lies near the anchor.
                let lowest = try #require(base.lowestSolid, "\(key)")
                #expect(lowest >= row - 4 && lowest <= row + 40, "\(key): the lowest solid row is \(lowest), the anchor's \(row)")
                #expect(base.clearAtEdges, "\(key) touches its edge")
            }
        }
    }

    @Test func theDugoutMoves() throws {
        for pose in [SpritePose.standing, .walking, .working] {
            for view in SpriteView.allCases {
                let first = try #require(source.sprite(SpriteKey(Self.boat, pose, frame: 0, view: view)))
                let next = try #require(source.sprite(SpriteKey(Self.boat, pose, frame: 3, view: view)))
                #expect(BoatPixels(first.base) != BoatPixels(next.base), "\(pose) \(view)")
            }
        }
    }

    /// The fish and the rocks afloat stand on the centre of their tile, as the
    /// terrain's sites do, carry no team colour, and do not reach their edges.
    @Test func theSitesStandOnTheirTileWithoutAMask() throws {
        for key in source.keys {
            guard case .site(let kind) = key.subject else { continue }
            let sprite = try #require(source.sprite(key), "\(key)")
            #expect(sprite.teamMask == nil, "\(key)")
            #expect(sprite.anchor == TerrainSprites.siteCanvas.anchor, "\(key)")
            let pixels = BoatPixels(sprite.base)
            #expect(pixels.width == TerrainSprites.siteCanvas.pixelWidth && pixels.height == TerrainSprites.siteCanvas.pixelHeight)
            #expect(pixels.clearAtEdges, "\(key) touches its edge")
            // Something is drawn on the tile about its centre, within the tile's diamond.
            let (x, row) = pixels.place(sprite.anchor)
            let near = (row - 30...row + 20).contains { r in (x - 40...x + 40).contains { pixels.visible($0, r) } }
            #expect(near, "\(key): nothing on the tile")
            if kind != .fish {
                // A rock afloat is drawn without the land rock's shadow, so it differs from the rock on land.
                let land = try #require(GameSprites().sprite(SpriteKey(.site(kind), .complete)), "\(kind)")
                #expect(BoatPixels(land.base) != pixels, "\(kind)")
            }
        }
    }

    /// A deposit in the water that the player's age does not yet reveal is
    /// plain bedrock at a waterline, without the land outcrop's shadow.
    @Test func theOutcropRisesFromTheWater() throws {
        let sprite = try #require(source.sprite(SpriteKey(.outcrop, .afloat)))
        #expect(sprite.teamMask == nil)
        #expect(sprite.anchor == TerrainSprites.siteCanvas.anchor)
        let pixels = BoatPixels(sprite.base)
        #expect(pixels.clearAtEdges)
        let land = try #require(GameSprites().sprite(SpriteKey(.outcrop, .complete)))
        #expect(BoatPixels(land.base) != pixels)
        #expect(source.sprite(SpriteKey(.outcrop, .afloat, frame: 1)) == nil)
    }

    @Test func theFishLeaps() throws {
        let frames = try (0..<SpriteKey.framesPerPose).map { try #require(source.sprite(SpriteKey(.site(.fish), .complete, frame: $0))) }
        for (a, b) in zip(frames, frames.dropFirst()) { #expect(BoatPixels(a.base) != BoatPixels(b.base)) }
        // The fish in the air reaches higher than the water's rings alone.
        let air = BoatPixels(frames[2].base), water = BoatPixels(frames[9].base)
        #expect(try #require(air.highestVisible) < (try #require(water.highestVisible)) - 10)
    }

    @Test func everyOtherKeyHasNone() {
        let batch = Set(source.keys)
        var others = SpriteKey.required(through: .hospitals).filter { !batch.contains($0) }
        for frame in [-1, 12] {
            others.append(SpriteKey(Self.boat, .walking, frame: frame))
            others.append(SpriteKey(.site(.fish), .complete, frame: frame))
        }
        others.append(SpriteKey(Self.boat, .fighting))
        others += [Look.bronze, .iron, .alchemy, .industrial].map { SpriteKey(.unit(.fishingBoat, $0), .standing) }
        others += [SiteKind.tree, .prey, .fish].map { SpriteKey(.site($0), .afloat) }
        others += StoneBoatSprites.rocks.map { SpriteKey(.site($0), .afloat, frame: 1) }
        others += StoneBoatSprites.rocks.map { SpriteKey(.site($0), .complete) }
        others.append(SpriteKey(.site(.fish), .complete, frame: 0, view: .front))
        others.append(SpriteKey(.building(.boatHouse, .stone), .complete))
        for key in others { #expect(source.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = StoneBoatSprites()
        var keys = source.keys
        keys += [SpriteKey(Self.boat, .walking, frame: 5, view: .frontQuarter), SpriteKey(Self.boat, .working, frame: 7, view: .back)]
        for key in keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(BoatPixels(first.base) == BoatPixels(second.base), "\(key)")
            #expect(first.teamMask.map(BoatPixels.init) == second.teamMask.map(BoatPixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }
}

/// An image's pixels as premultiplied RGBA bytes, rows from the top.
private struct BoatPixels: Equatable {
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

    /// Whether the pixel is plainly drawn, if only faintly: a ring on the water.
    func visible(_ x: Int, _ row: Int) -> Bool {
        guard x >= 0, x < width, row >= 0, row < height else { return false }
        return bytes[(row * width + x) * 4 + 3] > 60
    }

    var highestVisible: Int? { (0..<height).first { row in (0..<width).contains { visible($0, row) } } }

    var lowestSolid: Int? { (0..<height).reversed().first { row in (0..<width).contains { solid($0, row) } } }

    var clearAtEdges: Bool {
        let w = width - 1, h = height - 1
        let edge = (0...w).flatMap { [($0, 0), ($0, h)] } + (0...h).flatMap { [(0, $0), (w, $0)] }
        return edge.allSatisfy { bytes[($0.1 * width + $0.0) * 4 + 3] == 0 }
    }
}
