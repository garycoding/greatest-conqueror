// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The fruit bush in each of the five looks (`FruitBushSprites`).
@Suite(.serialized) struct FruitBushesTests {
    @Test func theBatchIsTheBushInEachLookAndComplete() {
        #expect(FruitBushSprites.keys.count == Look.allCases.count + 1)
        // The checklist asks for the bush in each look reached, and not in the pose `complete`.
        let required = SpriteKey.required(through: .hospitals).filter { $0.subject == .site(.fruit) }
        #expect(Set(required) == Set(Look.allCases.map { SpriteKey(.site(.fruit), .complete(in: $0)) }))
        let towns = SpriteKey.required(through: .towns).filter { $0.subject == .site(.fruit) }
        #expect(towns == [SpriteKey(.site(.fruit), .complete(in: .stone))])
    }

    @Test func everyKeyHasASpriteWithoutAMaskStandingOnItsAnchor() throws {
        let sprites = FruitBushSprites()
        let canvas = FruitBushPainter.canvas
        for key in FruitBushSprites.keys {
            let sprite = try #require(sprites.sprite(key), "\(key)")
            // A bush carries no team's colour.
            #expect(sprite.teamMask == nil, "\(key)")
            #expect(sprite.base.width == canvas.pixelWidth && sprite.base.height == canvas.pixelHeight, "\(key)")
            #expect(sprite.anchor == canvas.anchor && sprite.anchor.x == 0.5, "\(key)")
            // Standing on the centre of its tile, as the other sites do: its mass over
            // the anchor, nothing solid farther forward than the tile's front corner.
            let pixels = BushPixels(sprite.base)
            let solid = try #require(pixels.solid(), "\(key)")
            let anchorX = sprite.anchor.x * Double(pixels.width), anchorRow = (1 - sprite.anchor.y) * Double(pixels.height)
            #expect(abs(solid.centreX - anchorX) <= 8 * 2, "\(key)")
            #expect(Double(solid.bottom) <= anchorRow + 16 * 2, "\(key)")
            #expect(pixels.alpha(Int(anchorX), Int(anchorRow) - 2) > 0, "\(key)")
        }
    }

    @Test func everyOtherKeyIsNil() {
        let sprites = FruitBushSprites()
        let ours = Set(FruitBushSprites.keys)
        var others = SpriteKey.required(through: .hospitals).filter { !ours.contains($0) }
        for key in FruitBushSprites.keys {
            others.append(SpriteKey(key.subject, key.pose, frame: 1))
            others.append(SpriteKey(key.subject, key.pose, view: .front))
        }
        for pose in [SpritePose.afloat, .standing, .underConstruction, "complete-silicon"] {
            others.append(SpriteKey(.site(.fruit), pose))
        }
        for kind in SiteKind.allCases where kind != .fruit {
            others.append(SpriteKey(.site(kind), .complete))
            others.append(SpriteKey(.site(kind), .complete(in: .iron)))
        }
        for key in others { #expect(sprites.sprite(key) == nil, "\(key)") }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        for look in Look.allCases {
            let first = try #require(FruitBushSprites.draw(look))
            let second = try #require(FruitBushSprites.draw(look))
            #expect(BushPixels(first.base).bytes == BushPixels(second.base).bytes, "\(look)")
        }
        // The source keeps what it drew; `complete` is the Stone look.
        let sprites = FruitBushSprites()
        let stone = sprites.sprite(SpriteKey(.site(.fruit), .complete(in: .stone)))
        #expect(stone?.base === sprites.sprite(SpriteKey(.site(.fruit), .complete(in: .stone)))?.base)
        #expect(stone?.base === sprites.sprite(SpriteKey(.site(.fruit), .complete))?.base)
    }

    @Test func eachLookIsAPictureOfItsOwn() throws {
        let sprites = FruitBushSprites()
        let images = try Look.allCases.map { look in
            try #require(sprites.sprite(SpriteKey(.site(.fruit), .complete(in: look)))).base
        }
        for i in images.indices {
            for j in images.indices where j > i {
                #expect(BushPixels(images[i]).bytes != BushPixels(images[j]).bytes, "\(Look.allCases[i]) and \(Look.allCases[j])")
            }
        }
    }

    /// The fruit shows: in each look a good share of what is drawn is the
    /// colour of its ripe fruit, though the line and the grain lie over it.
    @Test func theFruitIsClearlyVisibleInEachLook() throws {
        for look in Look.allCases {
            let sprite = try #require(FruitBushSprites.draw(look))
            let pixels = BushPixels(sprite.base)
            let share = pixels.share(near: FruitBushPainter.fruit(look), within: 34)
            #expect(share >= 0.03, "\(look): \(share)")
        }
    }

    /// About a worker's height or a little more, wider than a worker, and much
    /// lower than a tree.
    @Test func theBushIsTheSizeOfAWorker() throws {
        let worker = try #require(CartoonSprites().sprite(SpriteKey(.unit(.worker, .stone), .standing)))
        let tree = try #require(TerrainSprites().sprite(SpriteKey(.site(.tree), .complete)))
        func measure(_ sprite: SpriteImage) throws -> (height: Double, width: Double) {
            let pixels = BushPixels(sprite.base)
            let solid = try #require(pixels.solid())
            let anchorRow = (1 - sprite.anchor.y) * Double(pixels.height)
            // In points: the sprites are drawn at two pixels a point.
            return ((anchorRow - Double(solid.top)) / 2, Double(solid.right - solid.left) / 2)
        }
        let person = try measure(worker), fir = try measure(tree)
        for look in Look.allCases {
            let bush = try measure(try #require(FruitBushSprites.draw(look)))
            #expect(bush.height >= person.height * 0.85 && bush.height <= person.height * 1.2,
                    "\(look): \(bush.height) against a worker's \(person.height)")
            #expect(bush.width > person.width && bush.width <= 64, "\(look): \(bush.width) wide")
            #expect(bush.height < fir.height * 0.6, "\(look)")
        }
    }

    @Test func theBatchRendersInUnderTwoSeconds() {
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            let sprites = FruitBushSprites()
            for key in FruitBushSprites.keys { _ = sprites.sprite(key) }
        }
        #expect(elapsed < .seconds(2), "\(elapsed)")
    }

    /// The combined source answers the bush from this batch, never from the tree.
    @Test func theGameAsksThisBatchForTheBush() throws {
        let all = GameSprites(), own = FruitBushSprites()
        for look in Look.allCases {
            let key = SpriteKey(.site(.fruit), .complete(in: look))
            let found = try #require(all.sprite(key))
            let drawn = try #require(own.sprite(key))
            #expect(BushPixels(found.base).bytes == BushPixels(drawn.base).bytes, "\(look)")
        }
    }
}

/// The pixels of a picture, to measure what is drawn.
struct BushPixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let data = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        bytes = Array(UnsafeBufferPointer(start: data, count: width * height * 4))
    }

    func alpha(_ column: Int, _ row: Int) -> UInt8 { bytes[(row * width + column) * 4 + 3] }

    /// The bounds of what is drawn solid (not the soft shadow), in pixels, and its centre across.
    func solid() -> (top: Int, bottom: Int, left: Int, right: Int, centreX: Double)? {
        var top = Int.max, bottom = -1, left = Int.max, right = -1, sum = 0.0, count = 0.0
        for row in 0..<height {
            for column in 0..<width where alpha(column, row) >= 200 {
                top = min(top, row); bottom = max(bottom, row)
                left = min(left, column); right = max(right, column)
                sum += Double(column); count += 1
            }
        }
        return count > 0 ? (top, bottom, left, right, sum / count) : nil
    }

    /// The share of the solid pixels within `within` (of 255 a channel, as a
    /// distance) of a colour written `#rrggbb`. The bitmap's colours are
    /// premultiplied, so only opaque pixels are counted.
    func share(near hex: String, within distance: Double) -> Double {
        let value = Int(hex.dropFirst(), radix: 16)!
        let target = [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)]
        var near = 0.0, solid = 0.0
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] == 255 {
            solid += 1
            let d = (0..<3).map { Double(bytes[i + $0]) - target[$0] }
            if (d[0] * d[0] + d[1] * d[1] + d[2] * d[2]).squareRoot() <= distance { near += 1 }
        }
        return near / max(solid, 1)
    }
}
