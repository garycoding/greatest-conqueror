// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

@Suite struct BronzeBuildingsTests {
    /// One source shared by the tests that only look at the sprites.
    private static let source = BronzeBuildingSprites()

    /// Every key of the batch: each building of the standard catalogue in the
    /// Bronze age's look, complete and under construction, at frame 0.
    private static let batch: [SpriteKey] = Catalogue.standard.buildings.filter({ $0.age <= .bronze && $0.kind != .bridge }).flatMap { stats in
        [SpriteKey(.building(stats.kind, .bronze), .complete), SpriteKey(.building(stats.kind, .bronze), .underConstruction)]
    }

    /// The keys of the back view: the boat house's alone, complete and under
    /// construction (ruled 2026-11-22), for the edges toward -y and -x.
    private static let back: [SpriteKey] = [SpritePose.complete, .underConstruction].map {
        SpriteKey(.building(.boatHouse, .bronze), $0, view: .back)
    }

    @Test func everyKeyOfTheBatchHasASpriteAndNoOtherKeyDoes() {
        #expect(Self.batch.count == 16)
        var keys = SpriteKey.required(through: .ai)
        for key in Self.batch {
            keys.append(SpriteKey(key.subject, key.pose, frame: 1))
            keys.append(SpriteKey(key.subject, key.pose, frame: 11))
            keys.append(SpriteKey(key.subject, .standing))
            keys.append(SpriteKey(key.subject, .working))
        }
        let supplied = Set(keys.filter { Self.source.sprite($0) != nil })
        #expect(supplied == Set(Self.batch))
    }

    /// A building takes the look of its owner's age: once its owner is in the
    /// Bronze age, every building, the Stone age's included, is drawn from here.
    @Test func everyBuildingOfABronzeAgeOwnerIsSupplied() {
        for stats in Catalogue.standard.buildings.filter({ $0.age <= .bronze && $0.kind != .bridge }) {
            let entity = EntityView(id: EntityID(1), owner: PlayerID(0), kind: .building(stats.kind), position: MapPosition(x: 5, y: 5),
                                    tile: GridPoint(4, 4), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle)
            let subject = SpriteSubject.of(entity, ownerAge: .bronze)
            #expect(Self.source.sprite(SpriteKey(subject, .complete)) != nil, "\(stats.kind)")
            #expect(Self.source.sprite(SpriteKey(subject, .underConstruction)) != nil, "\(stats.kind)")
            // In the Stone age only the buildings that the Bronze age brings take this look.
            let early = Self.source.sprite(SpriteKey(SpriteSubject.of(entity, ownerAge: .stone), .complete))
            #expect((early != nil) == (stats.age == .bronze), "\(stats.kind)")
        }
    }

    @Test func everySpriteCarriesTeamColour() throws {
        for key in Self.batch + Self.back {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = BronzeBuildingsPixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 60, "only \(coloured) pixels of team colour in \(key)")
        }
    }

    /// The anchor is the centre of the footprint's diamond: the diamond placed by
    /// the anchor is what the drawing covers, reaching its left, bottom and right
    /// corners and overhanging none of them; the boat house's jetty alone runs
    /// on beyond it over the water, to the right.
    @Test func theAnchorIsTheCentreOfTheFootprintsDiamond() throws {
        for key in Self.batch + Self.back {
            guard case .building(let kind, _) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key))
            let footprint = Catalogue.standard.stats(kind).footprint
            let pixels = BronzeBuildingsPixels(sprite.base)
            let centreX = sprite.anchor.x * Double(pixels.width)
            let centreY = (1 - sprite.anchor.y) * Double(pixels.height)
            // Two pixels a point: a tile's diamond is 128 by 64 pixels.
            let halfWidth = Double(footprint.x + footprint.y) * 32, halfHeight = Double(footprint.x + footprint.y) * 16
            let drawn = try #require(pixels.bounds(alphaAbove: 128), "\(key) is empty")
            // Nothing is cut off by the edges of the picture.
            #expect(drawn.minY > 0 && drawn.minX > 0 && drawn.maxX < pixels.width - 1 && drawn.maxY < pixels.height - 1,
                    "\(key) reaches the edge of its picture")
            let tolerance = 5.0
            #expect(abs(Double(drawn.minX) - (centreX - halfWidth)) <= tolerance, "\(key): left \(drawn.minX), corner \(centreX - halfWidth)")
            if kind == .boatHouse {
                // The boat house's jetty reaches out beyond the diamond toward the water, to the right.
                #expect(Double(drawn.maxX + 1) >= centreX + halfWidth - tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
                #expect(Double(drawn.maxY + 1) >= centreY + halfHeight - tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
            } else {
                #expect(abs(Double(drawn.maxX + 1) - (centreX + halfWidth)) <= tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
                #expect(abs(Double(drawn.maxY + 1) - (centreY + halfHeight)) <= tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
            }
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = BronzeBuildingSprites(), second = BronzeBuildingSprites()
        for key in Self.batch + Self.back {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(BronzeBuildingsPixels(a.base).bytes == BronzeBuildingsPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(BronzeBuildingsPixels(maskA).bytes == BronzeBuildingsPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor)
        }
    }

    /// The boat house's back view is the same building on the same canvas: the
    /// side's size and anchor, a team-colour mask where the side has one, and
    /// a picture of its own.
    @Test func theBoatHousesBackViewMatchesItsSideInSizeAndAnchor() throws {
        for key in Self.back {
            let back = try #require(Self.source.sprite(key), "\(key)")
            let side = try #require(Self.source.sprite(key.seen(.side)), "\(key)")
            #expect(back.base.width == side.base.width && back.base.height == side.base.height, "\(key)")
            #expect(back.anchor == side.anchor, "\(key)")
            #expect((back.teamMask != nil) == (side.teamMask != nil), "\(key)")
            #expect(BronzeBuildingsPixels(back.base).bytes != BronzeBuildingsPixels(side.base).bytes, "\(key)")
            if let backMask = back.teamMask, let sideMask = side.teamMask {
                #expect(BronzeBuildingsPixels(backMask).bytes != BronzeBuildingsPixels(sideMask).bytes, "\(key)")
            }
        }
    }

    /// Only the boat house gains a view, and only the back: every other
    /// building, and the boat house in every other view, gives nothing.
    @Test func nothingElseGainsAView() {
        for key in Self.batch {
            for view in SpriteView.allCases where view != .side {
                let seen = key.seen(view)
                #expect((Self.source.sprite(seen) != nil) == Self.back.contains(seen), "\(seen)")
            }
            #expect(Self.source.drawsViews(of: key.subject) == (key.subject == .building(.boatHouse, .bronze)), "\(key)")
        }
    }

    /// The combined source asks this batch for the boat house's back view, and
    /// gives its picture, not the side's.
    @Test func theGameDrawsTheBoatHousesBackFromHere() throws {
        let all = GameSprites()
        for key in Self.back {
            let own = try #require(Self.source.sprite(key)), drawn = try #require(all.sprite(key))
            #expect(BronzeBuildingsPixels(own.base).bytes == BronzeBuildingsPixels(drawn.base).bytes, "\(key)")
        }
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let fresh = BronzeBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "the batch took \(elapsed)")
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct BronzeBuildingsPixels {
    let width: Int, height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                    bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        bytes = data
    }

    func alpha(_ x: Int, _ y: Int) -> UInt8 { bytes[(y * width + x) * 4 + 3] }

    /// The smallest box holding every pixel more opaque than `alphaAbove`.
    func bounds(alphaAbove threshold: UInt8) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha(x, y) > threshold {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return maxX < 0 ? nil : (minX, minY, maxX, maxY)
    }
}
