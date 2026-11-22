// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The buildings of the last two ages that Cities of Progress lacks
/// (`LateBuildingSprites`): the cannon factory in the Alchemy and Industrial
/// looks and the hospital in the Industrial look. Every key of the batch has a
/// sprite that covers its footprint from its anchor and carries a mask, every
/// other key has none, a key always gives the same pixels, the owner's age
/// chooses the look, and each building has the size of the buildings beside it.
@Suite struct LateBuildingsTests {
    private static let source = LateBuildingSprites()

    /// Every key of the batch: each building in each of its looks, complete and under construction.
    private static let batch: [SpriteKey] = LateBuildingsArt.drawn.flatMap { drawn in
        [SpriteKey(.building(drawn.kind, drawn.look), .complete), SpriteKey(.building(drawn.kind, drawn.look), .underConstruction)]
    }

    @Test func theBatchIsTheCannonFactoryInTwoLooksAndTheHospital() {
        let expected = SpriteKey.required(through: .hospitals).filter { key in
            guard case .building(let kind, _) = key.subject else { return false }
            return kind == .cannonFactory || kind == .hospital
        }
        #expect(Set(expected) == Set(Self.batch))
        #expect(Self.batch.count == 6)
    }

    @Test func everyKeyOfTheBatchHasASpriteAndNoOtherKeyDoes() {
        var keys = SpriteKey.required(through: .hospitals)
        for kind in BuildingKind.allCases {
            for look in Look.allCases {
                keys.append(SpriteKey(.building(kind, look), .complete))
                keys.append(SpriteKey(.building(kind, look), .underConstruction))
            }
        }
        for key in Self.batch {
            keys.append(SpriteKey(key.subject, key.pose, frame: 1))
            keys.append(SpriteKey(key.subject, key.pose, frame: 11))
            keys.append(SpriteKey(key.subject, .standing))
            keys.append(SpriteKey(key.subject, .working))
            for view in SpriteView.allCases { keys.append(key.seen(view)) }
        }
        let supplied = Set(keys.filter { Self.source.sprite($0) != nil })
        #expect(supplied == Set(Self.batch))
    }

    /// A building takes the look of its owner's age: the cannon factory is
    /// drawn in the Alchemy look in the age of cannons and in the Industrial
    /// look in the age of hospitals, and the hospital in the Industrial look;
    /// the game's sprite for each is this batch's, no longer a stand-in.
    @Test func theOwnersAgeChoosesTheLook() throws {
        let game = GameSprites()
        let cases: [(BuildingKind, Age, Look)] = [(.cannonFactory, .cannons, .alchemy), (.cannonFactory, .hospitals, .industrial),
                                                  (.hospital, .hospitals, .industrial)]
        for (kind, age, look) in cases {
            let subject = SpriteSubject.of(.building(kind), ownerAge: age)
            #expect(subject == .building(kind, look), "\(kind) in \(age)")
            for pose in [SpritePose.complete, .underConstruction] {
                let own = try #require(Self.source.sprite(SpriteKey(subject, pose)), "\(kind) \(pose)")
                let theGames = try #require(game.sprite(SpriteKey(subject, pose)), "\(kind) \(pose)")
                #expect(LateBuildingsPixels(own.base).bytes == LateBuildingsPixels(theGames.base).bytes, "\(kind) \(pose)")
            }
        }
    }

    @Test func everySpriteCarriesTeamColour() throws {
        for key in Self.batch {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = LateBuildingsPixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 60, "only \(coloured) pixels of team colour in \(key)")
        }
    }

    /// The anchor is the centre of the footprint's diamond: the diamond placed
    /// by the anchor is what the drawing covers, reaching its left, bottom and
    /// right corners and overhanging none of them, and no drawing reaches the
    /// edge of its picture.
    @Test func theAnchorIsTheCentreOfTheFootprintsDiamond() throws {
        for key in Self.batch {
            guard case .building(let kind, _) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key))
            let footprint = Catalogue.standard.stats(kind).footprint
            let pixels = LateBuildingsPixels(sprite.base)
            let centreX = sprite.anchor.x * Double(pixels.width)
            let centreY = (1 - sprite.anchor.y) * Double(pixels.height)
            // Two pixels a point: a tile's diamond is 128 by 64 pixels.
            let halfWidth = Double(footprint.x + footprint.y) * 32, halfHeight = Double(footprint.x + footprint.y) * 16
            let drawn = try #require(pixels.bounds(alphaAbove: 128), "\(key) is empty")
            #expect(drawn.minY > 0 && drawn.minX > 0 && drawn.maxX < pixels.width - 1 && drawn.maxY < pixels.height - 1,
                    "\(key) reaches the edge of its picture \(drawn) \(pixels.width)x\(pixels.height)")
            let tolerance = 5.0
            #expect(abs(Double(drawn.minX) - (centreX - halfWidth)) <= tolerance, "\(key): left \(drawn.minX), corner \(centreX - halfWidth)")
            let right = Double(drawn.maxX + 1) - (centreX + halfWidth), bottom = Double(drawn.maxY + 1) - (centreY + halfHeight)
            #expect(abs(right) <= tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
            #expect(abs(bottom) <= tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
        }
    }

    /// The barracks of the same look, for size: three tiles square, as both of these buildings are.
    private static func barracks(_ look: Look, _ pose: SpritePose) -> SpriteImage? {
        let key = SpriteKey(.building(.barracks, look), pose)
        return look == .alchemy ? AlchemyOldBuildingSprites().sprite(key) : IndustrialOldBuildingSprites().sprite(key)
    }

    /// A building is as wide as the barracks of its look and stands on its
    /// footprint as the barracks does; the cannon factory keeps its canvas from
    /// the Alchemy look to the Industrial.
    @Test func eachBuildingHasTheBarracksWidthAndKeepsItsCanvasAcrossLooks() throws {
        for key in Self.batch {
            guard case .building(_, let look) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key)), barracks = try #require(Self.barracks(look, key.pose))
            #expect(sprite.base.width == barracks.base.width, "\(key)")
            let ground = (1 - sprite.anchor.y) * Double(sprite.base.height), barracksGround = (1 - barracks.anchor.y) * Double(barracks.base.height)
            #expect(abs((Double(sprite.base.height) - ground) - (Double(barracks.base.height) - barracksGround)) < 0.01, "\(key)")
            #expect(sprite.anchor.x == barracks.anchor.x, "\(key)")
        }
        for pose in [SpritePose.complete, .underConstruction] {
            let alchemy = try #require(Self.source.sprite(SpriteKey(.building(.cannonFactory, .alchemy), pose)))
            let industrial = try #require(Self.source.sprite(SpriteKey(.building(.cannonFactory, .industrial), pose)))
            #expect(alchemy.base.width == industrial.base.width && alchemy.base.height == industrial.base.height)
            #expect(alchemy.anchor == industrial.anchor)
        }
    }

    /// Complete, each building stands taller than the house of its look and
    /// lower than its town hall, which stays the tallest building of the town.
    @Test func eachBuildingStandsAboveTheHouseAndBelowTheTownHall() throws {
        func height(_ sprite: SpriteImage) throws -> Int {
            let pixels = LateBuildingsPixels(sprite.base)
            let drawn = try #require(pixels.bounds(alphaAbove: 128))
            return Int((1 - sprite.anchor.y) * Double(pixels.height)) - drawn.minY
        }
        for drawn in LateBuildingsArt.drawn {
            let older: any SpriteSource = drawn.look == .alchemy ? AlchemyOldBuildingSprites() : IndustrialOldBuildingSprites()
            let own = try height(try #require(Self.source.sprite(SpriteKey(.building(drawn.kind, drawn.look), .complete))))
            let house = try height(try #require(older.sprite(SpriteKey(.building(.house, drawn.look), .complete))))
            let hall = try height(try #require(older.sprite(SpriteKey(.building(.townCentre, drawn.look), .complete))))
            #expect(own > house && own < hall, "\(drawn.kind) in \(drawn.look): \(own), house \(house), town hall \(hall)")
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = LateBuildingSprites(), second = LateBuildingSprites()
        for key in Self.batch {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(LateBuildingsPixels(a.base).bytes == LateBuildingsPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(LateBuildingsPixels(maskA).bytes == LateBuildingsPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor)
        }
    }

    @Test func theBatchRendersInUnderTwoSeconds() {
        let fresh = LateBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(2), "the batch took \(elapsed)")
    }
}

/// Pictures of the batch for a person to judge, written into the directory
/// named by `LATE_BUILDINGS_RENDERS`; skipped when it is not set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LATE_BUILDINGS_RENDERS"] != nil))
struct LateBuildingsRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LATE_BUILDINGS_RENDERS"] ?? "/", isDirectory: true)

    private static func name(_ kind: BuildingKind, _ look: Look) -> String {
        "\(kind == .cannonFactory ? "cannon-factory" : "hospital")-\(look)"
    }

    private static func lookName(_ look: Look) -> String { look == .alchemy ? "Alchemy" : "Industrial" }

    /// One animated GIF per building and look at 12 frames a second: each pose
    /// in turn, two seconds each, drawn large from the same SVG on a patch of
    /// ground in Sumer's colour, and beside it the sprite itself at game size.
    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = LateBuildingSprites()
        let colour = TeamColour.of(.sumer)
        let width = 1560, height = 1000, groundLine = 300.0, scale = 5.0
        let ground = Preview.ground(width: width, height: height, tile: 64 * scale, grained: false)
        for drawn in LateBuildingsArt.drawn {
            var frames: [CGImage] = []
            for pose in [SpritePose.complete, .underConstruction] {
                let subject = LateBuildingsSubject(kind: drawn.kind, look: drawn.look, complete: pose == .complete)
                let large = try #require(LateBuildingsArt.draw(subject, pixelsPerUnit: scale))
                let big = Preview.tinted(base: large.base, mask: large.mask, colour: colour)
                let sprite = try #require(sprites.sprite(SpriteKey(.building(drawn.kind, drawn.look), pose)))
                let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                let anchor = LateBuildingsArt.canvas(drawn.kind).anchor
                for _ in 0..<24 {
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                    Preview.place(big, anchor: anchor, at: CGPoint(x: 560, y: groundLine), in: context)
                    Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: 1360, y: groundLine), in: context)
                    Preview.label("\(drawn.kind.name), \(Self.lookName(drawn.look)) look, in Sumer's colour", in: context,
                                  at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                    Preview.label((pose == .complete ? "complete" : "under construction") + ", 12 frames a second", in: context,
                                  at: CGPoint(x: 28, y: 28), size: 22)
                    Preview.label("at game size", in: context, at: CGPoint(x: 1310, y: 120), size: 18)
                    frames.append(context.makeImage()!)
                }
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(Self.name(drawn.kind, drawn.look)).gif"))
        }
    }

    /// One sheet of every building, look and pose: each drawn large in
    /// Sumer's colour, complete and under construction, and at game size beside
    /// the house, the barracks and the town hall of its look, complete in the
    /// colours of Sumer, Angkor and Shang, and under construction.
    @Test func sheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = LateBuildingSprites()
        let largeScale = 3.0, rowHeight = 620, header = 70
        let width = 4300, height = header + rowHeight * LateBuildingsArt.drawn.count
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The cannon factory in the Alchemy and Industrial looks and the hospital in the Industrial look, large and at game size beside their neighbours",
                      in: context, at: CGPoint(x: 24, y: Double(height) - 48), size: 26)
        for (row, drawn) in LateBuildingsArt.drawn.enumerated() {
            let top = Double(height - header - row * rowHeight)
            let groundY = top - Double(rowHeight) + 190
            let anchor = LateBuildingsArt.canvas(drawn.kind).anchor
            Preview.label("\(drawn.kind.name), \(Self.lookName(drawn.look)) look", in: context, at: CGPoint(x: 24, y: top - 34), size: 22)
            for (n, complete) in [true, false].enumerated() {
                let large = try #require(LateBuildingsArt.draw(LateBuildingsSubject(kind: drawn.kind, look: drawn.look, complete: complete),
                                                               pixelsPerUnit: largeScale))
                let image = Preview.tinted(base: large.base, mask: large.mask, colour: TeamColour.of(.sumer))
                Preview.place(image, anchor: anchor, at: CGPoint(x: 340 + Double(n) * 640, y: groundY), in: context)
                Preview.label(complete ? "complete" : "under construction", in: context,
                              at: CGPoint(x: 240 + Double(n) * 640, y: groundY - 180), size: 18)
            }
            // At game size: the neighbours, then this building in three colours and under construction.
            let older: any SpriteSource = drawn.look == .alchemy ? AlchemyOldBuildingSprites() : IndustrialOldBuildingSprites()
            var x = 1500.0
            for kind in [BuildingKind.house, .barracks, .townCentre] {
                guard let sprite = older.sprite(SpriteKey(.building(kind, drawn.look), .complete)) else { continue }
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(.sumer))
                Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: x, y: groundY), in: context)
                Preview.label(kind.name, in: context, at: CGPoint(x: x - 40, y: groundY - 150), size: 16)
                x += kind == .house ? 330 : 420
            }
            let shown: [(SpritePose, Civilization)] = [(.complete, .sumer), (.complete, .angkor), (.complete, .shang),
                                                       (.underConstruction, .sumer)]
            for (pose, civilization) in shown {
                let sprite = try #require(sprites.sprite(SpriteKey(.building(drawn.kind, drawn.look), pose)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(civilization))
                Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: x, y: groundY), in: context)
                Preview.label("\(String(describing: civilization).capitalized)\(pose == .complete ? "" : ", building")", in: context,
                              at: CGPoint(x: x - 40, y: groundY - 150), size: 16)
                x += 420
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("late-buildings-sheet.png"))
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct LateBuildingsPixels {
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
