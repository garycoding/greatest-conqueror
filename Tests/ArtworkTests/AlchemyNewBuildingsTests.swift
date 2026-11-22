// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

@Suite struct AlchemyNewBuildingsTests {
    /// One source shared by the tests that only look at the sprites.
    private static let source = AlchemyNewBuildingSprites()

    /// Every key of the batch: each new building of the Alchemy age, complete
    /// and under construction, at frame 0.
    private static let batch: [SpriteKey] = AlchemyNewBuildingsArt.kinds.flatMap { kind in
        [SpriteKey(.building(kind, .alchemy), .complete), SpriteKey(.building(kind, .alchemy), .underConstruction)]
    }

    @Test func theBatchIsTheAlchemyAgesNewBuildings() {
        let alchemy = Catalogue.standard.buildings.filter { $0.age == .alchemy }.map(\.kind)
        #expect(Set(alchemy) == Set(AlchemyNewBuildingsArt.kinds))
        #expect(Self.batch.count == 4)
    }

    @Test func everyKeyOfTheBatchHasASpriteAndNoOtherKeyDoes() {
        var keys = SpriteKey.required(through: .ai)
        for kind in BuildingKind.allCases {
            for age in Age.allCases {
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

    /// A castle or a workshop is drawn from here for its owner in the Alchemy
    /// age (`SpriteSubject.of`), and for an owner in a later age the key names
    /// that age, which another batch answers.
    @Test func anAlchemyAgeOwnersNewBuildingsAreSupplied() {
        for kind in AlchemyNewBuildingsArt.kinds {
            let stats = Catalogue.standard.stats(kind)
            let entity = EntityView(id: EntityID(1), owner: PlayerID(0), kind: .building(kind), position: MapPosition(x: 5, y: 5),
                                    tile: GridPoint(3, 3), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle)
            let subject = SpriteSubject.of(entity, ownerAge: .alchemy)
            #expect(Self.source.sprite(SpriteKey(subject, .complete)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(subject, .underConstruction)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(SpriteSubject.of(entity, ownerAge: .industrial), .complete)) == nil, "\(kind)")
        }
    }

    @Test func everyBuildingCarriesTeamColourInAMask() throws {
        for key in Self.batch {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = AlchemyNewBuildingsPixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 150, "only \(coloured) pixels of team colour in \(key)")
        }
    }

    /// The anchor is the centre of the footprint's diamond: the diamond placed by
    /// the anchor is what the drawing covers, reaching its left, bottom and right
    /// corners and overhanging none of them.
    @Test func aBuildingsAnchorIsTheCentreOfItsFootprintsDiamond() throws {
        for key in Self.batch {
            guard case .building(let kind, _) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key))
            let footprint = Catalogue.standard.stats(kind).footprint
            let pixels = AlchemyNewBuildingsPixels(sprite.base)
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

    /// The castle is the strongest building in the game, and is drawn the tallest of the batch.
    @Test func theCastleStandsTallerThanTheWorkshop() throws {
        func height(_ kind: BuildingKind) throws -> Double {
            let sprite = try #require(Self.source.sprite(SpriteKey(.building(kind, .alchemy), .complete)))
            let pixels = AlchemyNewBuildingsPixels(sprite.base)
            let drawn = try #require(pixels.bounds(alphaAbove: 128))
            return (1 - sprite.anchor.y) * Double(pixels.height) - Double(drawn.minY)
        }
        #expect(try height(.castle) > height(.alchemistsWorkshop))
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = AlchemyNewBuildingSprites(), second = AlchemyNewBuildingSprites()
        for key in Self.batch {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(AlchemyNewBuildingsPixels(a.base).bytes == AlchemyNewBuildingsPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(AlchemyNewBuildingsPixels(maskA).bytes == AlchemyNewBuildingsPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor)
        }
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let fresh = AlchemyNewBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "the batch took \(elapsed)")
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct AlchemyNewBuildingsPixels {
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
/// the environment variable `ALCHEMY_NEW_BUILDINGS_RENDERS`; skipped when it
/// is not set: a contact sheet of every drawing, complete and under
/// construction, in Rome's and Angkor's colours (the two nearest), beside the
/// nearest Iron-age buildings; a scene of an Alchemy-age town at game size;
/// and each drawing enlarged three times.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ALCHEMY_NEW_BUILDINGS_RENDERS"] != nil))
struct AlchemyNewBuildingsRenders {
    let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ALCHEMY_NEW_BUILDINGS_RENDERS"] ?? "/",
                        isDirectory: true)
    let source = AlchemyNewBuildingSprites()
    let others = GameSprites()
    let civilizations: [Civilization] = [.rome, .angkor]

    /// A flat field of `colour` with the faint diamonds of the map's tiles and the grain over it.
    private func field(_ context: CGContext, _ rect: CGRect, colour: String, joints: String) {
        func rgb(_ hex: String) -> CGColor {
            let v = Int(hex.dropFirst(), radix: 16) ?? 0
            return CGColor(srgbRed: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255,
                           blue: Double(v & 255) / 255, alpha: 1)
        }
        context.setFillColor(rgb(colour))
        context.fill(rect)
        context.saveGState()
        context.clip(to: rect)
        context.setStrokeColor(rgb(joints))
        context.setLineWidth(1)
        var x = rect.minX - rect.height * 2
        while x < rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY)); context.addLine(to: CGPoint(x: x + rect.height * 2, y: rect.maxY))
            context.move(to: CGPoint(x: x + rect.height * 2, y: rect.minY)); context.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += 128
        }
        context.strokePath()
        if let grain = Grain.image(width: Int(rect.width), height: Int(rect.height)) { context.draw(grain, in: rect) }
        context.restoreGState()
    }

    @Test func contactSheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cellW = 580, cellH = 540, label = 34, columns = 5
        let rows: [(BuildingKind, [(String, SpriteKey)])] = [
            (.castle, [("Iron watch tower", SpriteKey(.building(.watchTower, .iron), .complete)),
                       ("Iron stone wall", SpriteKey(.building(.stoneWall, .iron), .complete))]),
            (.alchemistsWorkshop, [("Iron siege workshop", SpriteKey(.building(.siegeWorkshop, .iron), .complete))]),
        ]
        let width = cellW * columns, height = (cellH + label) * rows.count + 70
        let context = try #require(Raster.bitmap(width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0xef / 255.0, green: 0xe0 / 255.0, blue: 0xc2 / 255.0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The Alchemy age's new buildings at game size, in Rome's and Angkor's colours, beside the nearest Iron-age buildings",
                      in: context, at: CGPoint(x: 16, y: height - 48), size: 26)
        for (row, (kind, beside)) in rows.enumerated() {
            let top = height - 70 - row * (cellH + label)
            let f = Catalogue.standard.stats(kind).footprint
            for column in 0..<columns {
                let rect = CGRect(x: column * cellW + 6, y: top - label - cellH + 6, width: cellW - 12, height: cellH - 12)
                let isIron = column == 4
                field(context, rect, colour: isIron ? "#6fa39a" : "#d6b25e", joints: isIron ? "#64978e" : "#c9a552")
                let groundY = rect.minY + 16 + Double(f.x + f.y) * 16
                if isIron {
                    // No Iron-age castle or workshop exists; the nearest Iron buildings stand beside.
                    for (k, (_, key)) in beside.enumerated() {
                        guard let sprite = others.sprite(key) else { continue }
                        let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(civilizations[0]))
                        let x = beside.count == 1 ? rect.midX : rect.minX + 150 + Double(k) * 260
                        Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: x, y: groundY + 40), in: context)
                    }
                    let text = "Beside: " + beside.map(\.0).joined(separator: ", ") + ", Rome"
                    Preview.label(text, in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 17)
                    continue
                }
                let complete = column < 2, civilization = civilizations[column % 2]
                let key = SpriteKey(.building(kind, .alchemy), complete ? .complete : .underConstruction)
                if let sprite = source.sprite(key) {
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(civilization))
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: rect.midX, y: groundY), in: context)
                }
                let text = "\(kind.name), \(String(describing: civilization).capitalized), \(complete ? "complete" : "under construction")"
                Preview.label(text, in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 17)
            }
        }
        try Preview.writePNG(try #require(context.makeImage()), to: directory.appendingPathComponent("alchemy-new-buildings-sheet.png"))
    }

    /// An Alchemy-age town at game size on the ground's tiles: a castle and two
    /// workshops (one being built, one a rival's), with the town's other
    /// buildings and people in the Iron age's look until the Alchemy age's own
    /// are drawn, a row of stone wall, and trees.
    @Test func townScene() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let width = 2000, height = 1200
        let context = try #require(Raster.bitmap(width: width, height: height))
        let origin = CGPoint(x: 1000, y: -180)
        /// The screen point of a place on the map, in pixels with the origin at the bottom left.
        func screen(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: origin.x + (x - y) * 64, y: Double(height) - (origin.y + (x + y) * 32))
        }
        for i in -8..<40 {
            for j in -8..<40 {
                let path = (j == 14 && i < 16) || (i == 15 && j > 14 && j < 16)
                let terrain: Terrain = path ? .dirt : .grass
                guard let tile = others.sprite(SpriteKey(.terrain(terrain, variant: (i * 7 + j * 3 + 400) % 4), .complete)) else { continue }
                let p = screen(Double(i) + 0.5, Double(j) + 0.5)
                if p.x < -100 || p.x > Double(width) + 100 || p.y < -100 || p.y > Double(height) + 100 { continue }
                Preview.place(tile.base, anchor: tile.anchor, at: p, in: context)
            }
        }
        // What stands on the map: the key, its centre on the map, and its civilization.
        var things: [(SpriteKey, Double, Double, Civilization?)] = [
            (SpriteKey(.building(.castle, .alchemy), .complete), 12, 10, .rome),
            (SpriteKey(.building(.alchemistsWorkshop, .alchemy), .complete), 17.5, 13.5, .rome),
            (SpriteKey(.building(.alchemistsWorkshop, .alchemy), .underConstruction), 9.5, 16.5, .rome),
            (SpriteKey(.building(.townCentre, .iron), .complete), 14.5, 17.5, .rome),
            (SpriteKey(.building(.house, .iron), .complete), 18, 17, .rome),
            (SpriteKey(.building(.house, .iron), .complete), 11, 20, .rome),
            (SpriteKey(.building(.castle, .alchemy), .underConstruction), 16, 5, .angkor),
            (SpriteKey(.building(.alchemistsWorkshop, .alchemy), .complete), 21.5, 11.5, .angkor),
            (SpriteKey(.site(.tree), .complete), 3.5, 4.5, nil),
            (SpriteKey(.site(.tree), .complete), 4.5, 2.5, nil),
            (SpriteKey(.site(.tree), .complete), 2.5, 16.5, nil),
            (SpriteKey(.site(.tree), .complete), 9.5, 3.5, nil),
            (SpriteKey(.site(.gold), .complete), 5.5, 19.5, nil),
            (SpriteKey(.unit(.worker, .iron), .walking), 13.2, 14.5, .rome),
            (SpriteKey(.unit(.engineer, .iron), .working), 10.7, 14.6, .rome),
            (SpriteKey(.unit(.swordsman, .iron), .standing), 12.6, 12.9, .rome),
            (SpriteKey(.unit(.horseman, .iron), .standing), 15.8, 15.6, .rome),
        ]
        // A stretch of stone wall to the west of the castle.
        for y in 6..<13 { things.append((SpriteKey(.building(.stoneWall, .iron), .complete), 7.5, Double(y) + 0.5, .rome)) }
        for (key, x, y, civilization) in things.sorted(by: { ($0.1 + $0.2, $0.1) < ($1.1 + $1.2, $1.1) }) {
            guard let sprite = source.sprite(key) ?? others.sprite(key) else { continue }
            let image = civilization.map { Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of($0)) } ?? sprite.base
            Preview.place(image, anchor: sprite.anchor, at: screen(x, y), in: context)
        }
        try Preview.writePNG(try #require(context.makeImage()), to: directory.appendingPathComponent("alchemy-new-buildings-town.png"))
    }

    /// Each drawing three times larger than in the game, in Rome's colour, for close inspection.
    @Test func enlarged() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for kind in AlchemyNewBuildingsArt.kinds {
            for complete in [true, false] {
                let canvas = AlchemyNewBuildingsArt.canvas(kind).scaled(to: 6)
                let drawn = try #require(Raster.render(on: canvas) { svg in
                    var painter = AlchemyNewBuildingsPainter(layer: svg.layer)
                    painter.building(kind, complete: complete)
                    svg = painter.svg
                })
                let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: TeamColour.of(.rome))
                let context = try #require(Raster.bitmap(width: image.width, height: image.height))
                let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                field(context, rect, colour: "#d6b25e", joints: "#c9a552")
                context.draw(image, in: rect)
                try Preview.writePNG(try #require(context.makeImage()), to: directory.appendingPathComponent(
                    "alchemy-\(kind)-\(complete ? "complete" : "under-construction")-enlarged.png"))
            }
        }
    }
}
