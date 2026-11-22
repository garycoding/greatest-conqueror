// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

@Suite struct IronNewBuildingsTests {
    /// One source shared by the tests that only look at the sprites.
    private static let source = IronNewBuildingSprites()

    /// The buildings of the batch: each new building of the Iron age, complete
    /// and under construction, at frame 0.
    private static let buildings: [SpriteKey] = IronNewBuildingsArt.kinds.flatMap { kind in
        [SpriteKey(.building(kind, .iron), .complete), SpriteKey(.building(kind, .iron), .underConstruction)]
    }

    /// Every key of the batch: the buildings, and the farm in the Bronze look.
    private static let batch: [SpriteKey] = buildings
        + [SpriteKey(.building(.farm, .bronze), .complete), SpriteKey(.building(.farm, .bronze), .underConstruction)]

    @Test func theBatchIsTheIronAgesNewBuildings() {
        // The stable, of the age of ships, and the farm, which Cities of Progress drew from its Iron age.
        // The castle, of the age of ships now, is drawn in the Iron look by its Alchemy stand-in (`StandIn`).
        let iron = Catalogue.standard.buildings.filter { $0.age == .ships && $0.kind != .castle }.map(\.kind) + [.farm]
        #expect(Set(iron) == Set(IronNewBuildingsArt.kinds))
        #expect(Self.batch.count == 6)
    }

    @Test func everyKeyOfTheBatchHasASpriteAndNoOtherKeyDoes() {
        var keys = SpriteKey.required(through: .hospitals)
        for kind in BuildingKind.allCases {
            for age in Look.allCases {
                keys.append(SpriteKey(.building(kind, age), .complete))
                keys.append(SpriteKey(.building(kind, age), .underConstruction))
            }
        }
        for kind in SiteKind.allCases { keys.append(SpriteKey(.site(kind), .complete)) }
        for key in Self.batch {
            keys.append(SpriteKey(key.subject, key.pose, frame: 1))
            keys.append(SpriteKey(key.subject, key.pose, frame: 11))
            keys.append(SpriteKey(key.subject, .standing))
            keys.append(SpriteKey(key.subject, .working))
        }
        let supplied = Set(keys.filter { Self.source.sprite($0) != nil })
        #expect(supplied == Set(Self.batch))
    }

    /// A new building of the Iron age is drawn from here for its owner in the
    /// Iron look (`SpriteSubject.of`).
    @Test func anIronAgeOwnersNewBuildingsAreSupplied() {
        for kind in IronNewBuildingsArt.kinds {
            let stats = Catalogue.standard.stats(kind)
            let entity = EntityView(id: EntityID(1), owner: PlayerID(0), kind: .building(kind), position: MapPosition(x: 5, y: 5),
                                    tile: GridPoint(4, 4), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle)
            let subject = SpriteSubject.of(entity, ownerAge: .ships)
            #expect(Self.source.sprite(SpriteKey(subject, .complete)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(subject, .underConstruction)) != nil, "\(kind)")
        }
    }

    @Test func everyBuildingCarriesTeamColour() throws {
        for key in Self.buildings {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = IronNewBuildingsPixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 60, "only \(coloured) pixels of team colour in \(key)")
        }
    }

    /// The anchor is the centre of the footprint's diamond: the diamond placed by
    /// the anchor is what the drawing covers, reaching its left, bottom and right
    /// corners and overhanging none of them.
    @Test func aBuildingsAnchorIsTheCentreOfItsFootprintsDiamond() throws {
        for key in Self.buildings {
            guard case .building(let kind, _) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key))
            let footprint = Catalogue.standard.stats(kind).footprint
            let pixels = IronNewBuildingsPixels(sprite.base)
            let centreX = sprite.anchor.x * Double(pixels.width)
            let centreY = (1 - sprite.anchor.y) * Double(pixels.height)
            // Two pixels a point: a tile's diamond is 128 by 64 pixels.
            let halfWidth = Double(footprint.x + footprint.y) * 32, halfHeight = Double(footprint.x + footprint.y) * 16
            let drawn = try #require(pixels.bounds(alphaAbove: 128), "\(key) is empty")
            #expect(drawn.minY > 0 && drawn.minX > 0 && drawn.maxX < pixels.width - 1 && drawn.maxY < pixels.height - 1,
                    "\(key) reaches the edge of its picture")
            let tolerance = 5.0
            #expect(abs(Double(drawn.minX) - (centreX - halfWidth)) <= tolerance, "\(key): left \(drawn.minX), corner \(centreX - halfWidth)")
            #expect(abs(Double(drawn.maxX + 1) - (centreX + halfWidth)) <= tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
            #expect(abs(Double(drawn.maxY + 1) - (centreY + halfHeight)) <= tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = IronNewBuildingSprites(), second = IronNewBuildingSprites()
        for key in Self.batch {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(IronNewBuildingsPixels(a.base).bytes == IronNewBuildingsPixels(b.base).bytes, "\(key)")
            if let maskA = a.teamMask {
                let maskB = try #require(b.teamMask)
                #expect(IronNewBuildingsPixels(maskA).bytes == IronNewBuildingsPixels(maskB).bytes, "\(key)")
            }
            #expect(a.anchor == b.anchor)
        }
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let fresh = IronNewBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "the batch took \(elapsed)")
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct IronNewBuildingsPixels {
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

/// The pictures for the person's ruling, written to the directory named by
/// the environment variable `IRON_NEW_BUILDINGS_RENDERS`; skipped when it is not
/// set: a contact sheet of every drawing, complete and under construction, in
/// two civilizations' colours, beside the nearest Bronze-age look, and a scene
/// of an Iron-age town at game size.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["IRON_NEW_BUILDINGS_RENDERS"] != nil))
struct IronNewBuildingsRenders {
    let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["IRON_NEW_BUILDINGS_RENDERS"] ?? "/", isDirectory: true)
    let source = IronNewBuildingSprites()
    let others = GameSprites()
    let colours = [TeamColour.of(.sumer), TeamColour.of(.egypt)]

    @Test func contactSheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let column = 440.0, row = 380.0, left = 40.0, top = 90.0
        let rows: [(String, [SpriteKey?], [(String, SpriteKey)])] = [
            ("Farm", keys(.farm), []),
            ("Stable", keys(.stable), [("Bronze barracks", SpriteKey(.building(.barracks, .bronze), .complete))]),
        ]
        let width = Int(left * 2 + column * 5), height = Int(top + row * Double(rows.count) + 120)
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The Iron age's new buildings, at game size, in Sumer's and Egypt's colours", in: context,
                      at: CGPoint(x: left, y: Double(height) - 50), size: 26)
        let headings = ["complete, Sumer", "complete, Egypt", "under construction, Sumer", "under construction, Egypt", "beside: the Bronze age"]
        for (i, heading) in headings.enumerated() {
            Preview.label(heading, in: context, at: CGPoint(x: left + Double(i) * column + 10, y: Double(height) - 84), size: 18)
        }
        for (r, (name, ownKeys, beside)) in rows.enumerated() {
            let groundLine = Double(height) - top - Double(r) * row - row + 70
            Preview.label(name, in: context, at: CGPoint(x: left, y: groundLine + 230), size: 20)
            for (i, key) in ownKeys.enumerated() {
                guard let key, let sprite = source.sprite(key) else { continue }
                let colour = colours[i % 2]
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: left + Double(i) * column + column / 2, y: groundLine),
                              in: context)
            }
            for (label, key) in beside {
                let x = left + 4 * column + column / 2
                if let sprite = others.sprite(key) {
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colours[0])
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: x, y: groundLine), in: context)
                }
                Preview.label(label, in: context, at: CGPoint(x: x - column / 2 + 10, y: groundLine - 120), size: 16)
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("iron-new-buildings-sheet.png"))
    }

    /// An Iron-age town at game size: the new buildings among the town's others
    /// (in the Bronze age's look, until the Iron age's own are drawn), with a
    /// row of stone wall, the iron deposit and other sites, on the ground's tiles.
    @Test func townScene() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let width = 1800, height = 1100
        let context = Raster.bitmap(width: width, height: height)!
        let origin = CGPoint(x: 900, y: -200)
        /// The screen point of a place on the map, in pixels with the origin at the bottom left.
        func screen(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: origin.x + (x - y) * 64, y: Double(height) - (origin.y + (x + y) * 32))
        }
        for i in -8..<36 {
            for j in -8..<36 {
                let terrain: Terrain = (i + 2 * j + 40) % 11 == 0 ? .dirt : .grass
                guard let tile = others.sprite(SpriteKey(.terrain(terrain, variant: (i * 7 + j * 3 + 400) % 4), .complete)) else { continue }
                let p = screen(Double(i) + 0.5, Double(j) + 0.5)
                if p.x < -100 || p.x > Double(width) + 100 || p.y < -100 || p.y > Double(height) + 100 { continue }
                Preview.place(tile.base, anchor: tile.anchor, at: p, in: context)
            }
        }
        // What stands on the map: the key, its centre on the map, and its civilization.
        var things: [(SpriteKey, Double, Double, Civilization?)] = [
            (SpriteKey(.building(.townCentre, .bronze), .complete), 9.5, 9.5, .sumer),
            (SpriteKey(.building(.house, .bronze), .complete), 12, 7, .sumer),
            (SpriteKey(.building(.house, .bronze), .complete), 7, 12, .sumer),
            (SpriteKey(.building(.farm, .iron), .underConstruction), 4.5, 5.5, .sumer),
            (SpriteKey(.building(.farm, .iron), .complete), 4.5, 8.5, .sumer),
            (SpriteKey(.building(.farm, .iron), .complete), 4.5, 11.5, .sumer),
            (SpriteKey(.building(.stable, .iron), .complete), 13.5, 10.5, .sumer),
            (SpriteKey(.building(.stable, .iron), .complete), 21.5, 12.5, .egypt),
            (SpriteKey(.site(.gold), .complete), 19.5, 3.5, nil),
            (SpriteKey(.site(.tree), .complete), 1.5, 3.5, nil),
            (SpriteKey(.site(.tree), .complete), 2.5, 1.5, nil),
            (SpriteKey(.site(.tree), .complete), 1.5, 15.5, nil),
            (SpriteKey(.site(.tree), .complete), 7.5, 2.5, nil),
            (SpriteKey(.unit(.worker, .bronze), .working), 6.9, 9.4, .sumer),
            (SpriteKey(.unit(.soldier1, .bronze), .standing), 15.6, 9.6, .sumer),
            (SpriteKey(.unit(.worker, .bronze), .walking), 11.4, 11.6, .sumer),
        ]
        for (key, x, y, civilization) in things.sorted(by: { ($0.1 + $0.2, $0.1) < ($1.1 + $1.2, $1.1) }) {
            guard let sprite = source.sprite(key) ?? others.sprite(key) else { continue }
            let image = civilization.map { Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of($0)) } ?? sprite.base
            Preview.place(image, anchor: sprite.anchor, at: screen(x, y), in: context)
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("iron-new-buildings-town.png"))
    }

    private func keys(_ kind: BuildingKind) -> [SpriteKey?] {
        [SpriteKey(.building(kind, .iron), .complete), SpriteKey(.building(kind, .iron), .complete),
         SpriteKey(.building(kind, .iron), .underConstruction), SpriteKey(.building(kind, .iron), .underConstruction)]
    }
}
