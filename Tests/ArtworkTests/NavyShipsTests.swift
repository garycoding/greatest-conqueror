// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The navy ship's art (`NavyShipSprites`): the batch is the navy ship in the
/// Iron, Alchemy and Industrial looks, standing, walking and fighting; every
/// key of it has a sprite on its anchor with a team mask in every view; every
/// other key has none; a key always gives the same pixels; the ship is clearly
/// larger than the fishing boat of its look; and it fires ahead.
@Suite(.serialized) struct NavyShipsTests {
    private let source = NavyShipSprites()
    private static let looks: [Look] = [.iron, .alchemy, .industrial]
    private static let poses: [SpritePose] = [.standing, .walking, .fighting]

    @Test func theBatchIsTheNavyShipInItsLooksAndPoses() {
        let expected = Self.looks.flatMap { look in Self.poses.map { SpriteKey(.unit(.navyShip, look), $0) } }
        #expect(source.poses == expected)
        #expect(source.keys.count == 9 * SpriteKey.framesPerPose)
        for look in Self.looks { #expect(source.drawsViews(of: .unit(.navyShip, look))) }
        #expect(!source.drawsViews(of: .unit(.fishingBoat, .iron)))
        // The navy ship is drawn as itself, in its owner's age's look.
        #expect(StandIn.unit(.navyShip) == .navyShip)
        #expect(StandIn.scale(.unit(.navyShip)) == 1)
        #expect(SpriteSubject.of(.unit(.navyShip), ownerAge: .ships) == .unit(.navyShip, .iron))
        #expect(SpriteSubject.of(.unit(.navyShip), ownerAge: .cannons) == .unit(.navyShip, .alchemy))
        #expect(SpriteSubject.of(.unit(.navyShip), ownerAge: .hospitals) == .unit(.navyShip, .industrial))
    }

    /// Every frame of every pose in every view: a mask that is not empty and
    /// lies on the picture, the anchor on the waterline in the middle of the
    /// hull (the hull solid at and on both sides of it, and the lowest solid
    /// row near it), and nothing cut off at the canvas's edge.
    @Test func everyViewOfTheShipHasAMaskAndStandsOnTheWaterline() throws {
        for key in source.keys {
            guard case .unit(_, let look) = key.subject else { continue }
            for view in SpriteView.allCases {
                let key = key.seen(view)
                let sprite = try #require(source.sprite(key), "\(key)")
                #expect(sprite.anchor == NavyShip.canvas(look).anchor, "\(key)")
                let base = NavyPixels(sprite.base)
                let mask = NavyPixels(try #require(sprite.teamMask, "\(key) has no team colour"))
                #expect(mask.width == base.width && mask.height == base.height, "\(key)")
                var covered = 0, outside = 0
                for i in stride(from: 3, to: mask.bytes.count, by: 4) where mask.bytes[i] > 25 {
                    covered += 1
                    if base.bytes[i] == 0 { outside += 1 }
                }
                #expect(covered > 60, "\(key): the mask covers \(covered) pixels")
                #expect(outside == 0, "\(key): \(outside) mask pixels lie outside the picture")
                let (x, row) = base.place(sprite.anchor)
                let hullRows = (row - 16)...(row + 2)
                #expect(hullRows.contains { base.solid(x, $0) }, "\(key): no hull at the anchor")
                #expect(hullRows.contains { r in (x - 16...x - 6).contains { base.solid($0, r) } }, "\(key): no hull left of the anchor")
                #expect(hullRows.contains { r in (x + 6...x + 16).contains { base.solid($0, r) } }, "\(key): no hull right of the anchor")
                let lowest = try #require(base.lowestSolid, "\(key)")
                #expect(lowest >= row - 4 && lowest <= row + 64, "\(key): the lowest solid row is \(lowest), the anchor's \(row)")
                #expect(base.clearAtEdges, "\(key) touches its edge")
            }
        }
    }

    /// Each pose moves in every view, and every frame differs from the one before it.
    @Test func theShipMoves() throws {
        for look in Self.looks {
            for pose in Self.poses {
                for view in SpriteView.allCases {
                    let frames = try (0..<SpriteKey.framesPerPose).map {
                        NavyPixels(try #require(source.sprite(SpriteKey(.unit(.navyShip, look), pose, frame: $0, view: view))).base)
                    }
                    for (i, (a, b)) in zip(frames, frames.dropFirst()).enumerated() { #expect(a != b, "\(look) \(pose) \(view) \(i)") }
                }
            }
        }
    }

    /// From the side, the ship is half as long again as the fishing boat of its
    /// look, and taller; the stand-in it replaces was the fishing boat drawn at
    /// 1.5 times its size.
    @Test func theShipIsClearlyLargerThanTheFishingBoat() throws {
        let boats: [Look: any SpriteSource] = [.iron: IronBoatSprites(), .alchemy: AlchemyBoatSprites(), .industrial: IndustrialBoatSprites()]
        for look in Self.looks {
            let ship = NavyPixels(try #require(source.sprite(SpriteKey(.unit(.navyShip, look), .standing))).base)
            let boat = NavyPixels(try #require(boats[look]?.sprite(SpriteKey(.unit(.fishingBoat, look), .standing))).base)
            let (shipWidth, shipHeight) = try #require(ship.solidExtent), (boatWidth, boatHeight) = try #require(boat.solidExtent)
            #expect(Double(shipWidth) >= 1.4 * Double(boatWidth), "\(look): \(shipWidth) against \(boatWidth)")
            #expect(Double(shipHeight) >= 1.05 * Double(boatHeight), "\(look): \(shipHeight) against \(boatHeight)")
        }
    }

    /// Fighting, the ship fires ahead: from the side, a quarter of the cycle
    /// after the first shot, the smoke reaches well beyond the bow.
    @Test func theGunsFireAhead() throws {
        for look in Self.looks {
            let key = { (frame: Int) in SpriteKey(.unit(.navyShip, look), .fighting, frame: frame) }
            let standing = NavyPixels(try #require(source.sprite(SpriteKey(.unit(.navyShip, look), .standing))).base)
            let shot = NavyPixels(try #require(source.sprite(key(4))).base)
            let bow = try #require(standing.rightmostVisible)
            let reach = try #require(shot.rightmostVisible)
            #expect(reach > bow + 10, "\(look): the smoke reaches \(reach), the bow \(bow)")
        }
    }

    @Test func everyOtherKeyHasNone() {
        let batch = Set(source.keys)
        var others = SpriteKey.required(through: .hospitals).filter { !batch.contains($0) }
        for frame in [-1, 12] { others.append(SpriteKey(.unit(.navyShip, .iron), .walking, frame: frame)) }
        others += Self.looks.map { SpriteKey(.unit(.navyShip, $0), .working) }
        others += [Look.stone, .bronze].map { SpriteKey(.unit(.navyShip, $0), .standing) }
        others += Self.looks.map { SpriteKey(.unit(.fishingBoat, $0), .standing) }
        for key in others { #expect(source.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = NavyShipSprites()
        var keys = source.keys
        keys += [SpriteKey(.unit(.navyShip, .alchemy), .walking, frame: 5, view: .frontQuarter),
                 SpriteKey(.unit(.navyShip, .industrial), .fighting, frame: 2, view: .back)]
        for key in keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(NavyPixels(first.base) == NavyPixels(second.base), "\(key)")
            #expect(first.teamMask.map(NavyPixels.init) == second.teamMask.map(NavyPixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }
}

/// An image's pixels as premultiplied RGBA bytes, rows from the top.
struct NavyPixels: Equatable {
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

    /// Whether the pixel is plainly drawn, if only faintly.
    func visible(_ x: Int, _ row: Int) -> Bool {
        guard x >= 0, x < width, row >= 0, row < height else { return false }
        return bytes[(row * width + x) * 4 + 3] > 60
    }

    /// The anchor as a column and a row from the top.
    func place(_ anchor: SpriteAnchor) -> (x: Int, row: Int) {
        (Int((anchor.x * Double(width)).rounded()), height - Int((anchor.y * Double(height)).rounded()))
    }

    var lowestSolid: Int? { (0..<height).reversed().first { row in (0..<width).contains { solid($0, row) } } }

    var rightmostVisible: Int? { (0..<width).reversed().first { x in (0..<height).contains { visible(x, $0) } } }

    /// The width and height of what is solid.
    var solidExtent: (Int, Int)? {
        let columns = (0..<width).filter { x in (0..<height).contains { solid(x, $0) } }
        let rows = (0..<height).filter { row in (0..<width).contains { solid($0, row) } }
        guard let left = columns.first, let right = columns.last, let top = rows.first, let bottom = rows.last else { return nil }
        return (right - left + 1, bottom - top + 1)
    }

    var clearAtEdges: Bool {
        let w = width - 1, h = height - 1
        let edge = (0...w).flatMap { [($0, 0), ($0, h)] } + (0...h).flatMap { [(0, $0), (w, $0)] }
        return edge.allSatisfy { bytes[($0.1 * width + $0.0) * 4 + 3] == 0 }
    }
}
