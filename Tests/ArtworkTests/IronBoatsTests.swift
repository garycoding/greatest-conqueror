// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The Iron age's boats' art (`IronBoatSprites`): the batch is the fishing
/// boat in its poses; every key of it has a sprite on its anchor with a team
/// mask in every view; every other key has none; and a key always gives the
/// same pixels.
@Suite(.serialized) struct IronBoatsTests {
    private let source = IronBoatSprites()
    private static let boat = SpriteSubject.unit(.fishingBoat, .iron)

    @Test func theBatchIsTheFishingBoatInItsPoses() {
        #expect(source.poses == [SpriteKey(Self.boat, .standing), SpriteKey(Self.boat, .walking), SpriteKey(Self.boat, .working)])
        #expect(source.keys.count == 3 * SpriteKey.framesPerPose)
        #expect(source.drawsViews(of: Self.boat))
        #expect(!source.drawsViews(of: .unit(.fishingBoat, .stone)))
        #expect(UnitKind.fishingBoat.stageName(at: .ships) == "Fishing boat")
    }

    /// Every frame of every pose in every view: a mask that is not empty and
    /// lies on the picture, the anchor on the waterline in the middle of the
    /// hull (the hull solid at and on both sides of it, and the lowest solid
    /// row near it), and nothing cut off at the canvas's edge.
    @Test func everyViewOfTheBoatHasAMaskAndStandsOnTheWaterline() throws {
        for key in source.keys {
            for view in SpriteView.allCases {
                let key = key.seen(view)
                let sprite = try #require(source.sprite(key), "\(key)")
                #expect(sprite.anchor == IronFishingBoat.canvas.anchor, "\(key)")
                let base = IronBoatPixels(sprite.base)
                let mask = IronBoatPixels(try #require(sprite.teamMask, "\(key) has no team colour"))
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
                #expect(lowest >= row - 4 && lowest <= row + 48, "\(key): the lowest solid row is \(lowest), the anchor's \(row)")
                #expect(base.clearAtEdges, "\(key) touches its edge")
            }
        }
    }

    /// Each pose moves in every view, and every frame differs from the one before it.
    @Test func theFishingBoatMoves() throws {
        for pose in [SpritePose.standing, .walking, .working] {
            for view in SpriteView.allCases {
                let frames = try (0..<SpriteKey.framesPerPose).map {
                    IronBoatPixels(try #require(source.sprite(SpriteKey(Self.boat, pose, frame: $0, view: view))).base)
                }
                for (i, (a, b)) in zip(frames, frames.dropFirst()).enumerated() { #expect(a != b, "\(pose) \(view) \(i)") }
            }
        }
    }

    /// The oars turn on their pins: the hands and the blades move opposite each
    /// other, and the rowing comes round to where it began.
    @Test func theOarsTurnOnTheirPins() {
        for frame in 0..<SpriteKey.framesPerPose {
            let a = IronFishingBoat.oarAngles(.walking, frame)
            for side in [-1.0, 1.0] {
                let oar = IronOar(side: side, sweep: a.sweep, dip: a.dip, square: a.square)
                let handle = oar.handle - oar.thole, tip = oar.tip - oar.thole
                #expect(abs(handle.x * tip.x + handle.y * tip.y + handle.z * tip.z + handle.length * tip.length) < 1e-6)
            }
        }
        let first = IronFishingBoat.oarAngles(.walking, 0), wrapped = IronFishingBoat.oarAngles(.walking, 12)
        #expect(abs(first.sweep - wrapped.sweep) < 1e-9 && abs(first.dip - wrapped.dip) < 1e-9)
        // The blades are in the water through the drive and out of it through the recovery.
        let tips = (0..<12).map { f -> Double in
            let a = IronFishingBoat.oarAngles(.walking, f)
            return IronOar(side: 1, sweep: a.sweep, dip: a.dip, square: a.square).tip.y
        }
        #expect(tips.max()! > 3 && tips.min()! < -3)
    }

    @Test func everyOtherKeyHasNone() {
        let batch = Set(source.keys)
        var others = SpriteKey.required(through: .hospitals).filter { !batch.contains($0) }
        for frame in [-1, 12] { others.append(SpriteKey(Self.boat, .walking, frame: frame)) }
        others.append(SpriteKey(Self.boat, .fighting))
        others += [Look.stone, .bronze, .alchemy, .industrial].map { SpriteKey(.unit(.fishingBoat, $0), .standing) }
        others += [SpriteKey(.building(.boatHouse, .iron), .complete), SpriteKey(.building(.boatHouse, .iron), .underConstruction)]
        others.append(SpriteKey(.site(.fish), .complete))
        others += StoneBoatSprites.rocks.map { SpriteKey(.site($0), .afloat) }
        for key in others { #expect(source.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = IronBoatSprites()
        var keys = source.keys
        keys += [SpriteKey(Self.boat, .walking, frame: 5, view: .frontQuarter), SpriteKey(Self.boat, .working, frame: 7, view: .back)]
        for key in keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(IronBoatPixels(first.base) == IronBoatPixels(second.base), "\(key)")
            #expect(first.teamMask.map(IronBoatPixels.init) == second.teamMask.map(IronBoatPixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }
}

/// An image's pixels as premultiplied RGBA bytes, rows from the top.
private struct IronBoatPixels: Equatable {
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
