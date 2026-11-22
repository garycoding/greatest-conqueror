// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The Industrial age's boat (`IndustrialBoatSprites`): the batch is the steam
/// trawler in its poses; every key of it has a sprite on its anchor with a team
/// mask in every view; every other key has none; and a key always gives the
/// same pixels.
@Suite(.serialized) struct IndustrialBoatsTests {
    private let source = IndustrialBoatSprites()
    private static let boat = SpriteSubject.unit(.boat, .industrial)

    @Test func theBatchIsTheTrawlerInItsPoses() {
        #expect(source.poses == [SpriteKey(Self.boat, .standing), SpriteKey(Self.boat, .walking), SpriteKey(Self.boat, .working)])
        #expect(source.keys.count == 3 * SpriteKey.framesPerPose)
        #expect(source.drawsViews(of: Self.boat))
        #expect(!source.drawsViews(of: .unit(.boat, .stone)))
    }

    /// Every frame of every pose in every view: a mask that is not empty and
    /// lies on the picture, the anchor on the waterline in the middle of the
    /// hull (solid pixels of the hull at it and on both sides of it, and the
    /// lowest solid row a little below it), and nothing cut off at the canvas's edge.
    @Test func everyViewOfTheBoatHasAMaskAndStandsOnTheWaterline() throws {
        for key in source.keys {
            for view in SpriteView.allCases {
                let key = key.seen(view)
                let sprite = try #require(source.sprite(key), "\(key)")
                #expect(sprite.anchor == IndustrialTrawler.canvas.anchor, "\(key)")
                let base = TrawlerPixels(sprite.base)
                let mask = TrawlerPixels(try #require(sprite.teamMask, "\(key) has no team colour"))
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

    /// Every pose moves in every view, and under steam the smoke rises above the funnel.
    @Test func theTrawlerMoves() throws {
        for pose in [SpritePose.standing, .walking, .working] {
            for view in SpriteView.allCases {
                let first = try #require(source.sprite(SpriteKey(Self.boat, pose, frame: 0, view: view)))
                let next = try #require(source.sprite(SpriteKey(Self.boat, pose, frame: 3, view: view)))
                #expect(TrawlerPixels(first.base) != TrawlerPixels(next.base), "\(pose) \(view)")
            }
        }
        // The plume under steam reaches higher over the water than the boat lying still with its thin wisp, seen from the side.
        let steaming = TrawlerPixels(try #require(source.sprite(SpriteKey(Self.boat, .walking, frame: 0))).base)
        let still = TrawlerPixels(try #require(source.sprite(SpriteKey(Self.boat, .standing, frame: 0))).base)
        #expect(try #require(steaming.highestVisible) <= (try #require(still.highestVisible)))
    }

    /// The batch draws only the Industrial boat: the fish and the rocks afloat
    /// are the Stone batch's, and the boat house the Industrial old buildings'.
    @Test func everyOtherKeyHasNone() {
        let batch = Set(source.keys)
        var others = SpriteKey.required(through: .hospitals).filter { !batch.contains($0) }
        for frame in [-1, 12] { others.append(SpriteKey(Self.boat, .walking, frame: frame)) }
        others.append(SpriteKey(Self.boat, .fighting))
        others += [Look.stone, .bronze, .iron, .alchemy].map { SpriteKey(.unit(.boat, $0), .standing) }
        others.append(SpriteKey(.site(.fish), .complete))
        others += StoneBoatSprites.rocks.map { SpriteKey(.site($0), .afloat) }
        others.append(SpriteKey(.building(.boatHouse, .industrial), .complete))
        for key in others { #expect(source.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = IndustrialBoatSprites()
        var keys = source.keys
        keys += [SpriteKey(Self.boat, .walking, frame: 5, view: .frontQuarter), SpriteKey(Self.boat, .working, frame: 7, view: .back)]
        for key in keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(TrawlerPixels(first.base) == TrawlerPixels(second.base), "\(key)")
            #expect(first.teamMask.map(TrawlerPixels.init) == second.teamMask.map(TrawlerPixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }

    /// The combined source draws the Industrial boat and boat house from their batches.
    @Test func theGameDrawsTheIndustrialBoatAndBoatHouse() throws {
        let all = GameSprites()
        for key in [SpriteKey(Self.boat, .walking, frame: 4, view: .backQuarter), SpriteKey(.building(.boatHouse, .industrial), .complete)] {
            let drawn = try #require(all.sprite(key), "\(key)")
            let own = try #require(source.sprite(key) ?? IndustrialOldBuildingSprites().sprite(key), "\(key)")
            #expect(TrawlerPixels(drawn.base) == TrawlerPixels(own.base), "\(key)")
        }
    }
}

/// An image's pixels as premultiplied RGBA bytes, rows from the top.
private struct TrawlerPixels: Equatable {
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

    /// Whether the pixel is plainly drawn, if only faintly.
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
