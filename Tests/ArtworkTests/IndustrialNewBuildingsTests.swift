// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

@Suite struct IndustrialNewBuildingsTests {
    /// One source shared by the tests that only look at the sprites.
    private static let source = IndustrialNewBuildingSprites()

    /// Every key of the batch: each new building of the Industrial age,
    /// complete and under construction, at frame 0.
    private static let batch: [SpriteKey] = IndustrialNewBuildingsArt.kinds.flatMap { kind in
        [SpriteKey(.building(kind, .industrial), .complete), SpriteKey(.building(kind, .industrial), .underConstruction)]
    }

    /// The oil field the well stands on, keyed as the terrain's sites are.
    private static let oilField = SpriteKey(.site(.oilField), .complete)

    @Test func theBatchIsTheIndustrialAgesNewBuildings() {
        let industrial = Catalogue.standard.buildings.filter { $0.age == .industrial }.map(\.kind)
        #expect(Set(industrial) == Set(IndustrialNewBuildingsArt.kinds))
        #expect(Self.batch.count == 6)
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
        keys.append(SpriteKey(.site(.oilField), .complete, frame: 1))
        keys.append(SpriteKey(.site(.oilField), .standing))
        let supplied = Set(keys.filter { Self.source.sprite($0) != nil })
        #expect(supplied == Set(Self.batch + [Self.oilField]))
    }

    /// A factory, depot or well is drawn from here for its owner in the
    /// Industrial age (`SpriteSubject.of`), and for an owner in a later age the
    /// key names that age, which another batch answers.
    @Test func anIndustrialAgeOwnersNewBuildingsAreSupplied() {
        for kind in IndustrialNewBuildingsArt.kinds {
            let stats = Catalogue.standard.stats(kind)
            let entity = EntityView(id: EntityID(1), owner: PlayerID(0), kind: .building(kind), position: MapPosition(x: 5, y: 5),
                                    tile: GridPoint(3, 3), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle)
            let subject = SpriteSubject.of(entity, ownerAge: .industrial)
            #expect(Self.source.sprite(SpriteKey(subject, .complete)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(subject, .underConstruction)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(SpriteSubject.of(entity, ownerAge: .silicon), .complete)) == nil, "\(kind)")
        }
    }

    @Test func everyBuildingCarriesTeamColourInAMask() throws {
        for key in Self.batch {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = IndustrialNewBuildingsPixels(mask)
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
            let pixels = IndustrialNewBuildingsPixels(sprite.base)
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

    /// The factory's stack is the tallest thing of the batch, and a complete
    /// building stands taller than the same building being built.
    @Test func theFactoryStandsTallestAndEachRisesAsItIsBuilt() throws {
        func height(_ kind: BuildingKind, _ pose: SpritePose) throws -> Double {
            let sprite = try #require(Self.source.sprite(SpriteKey(.building(kind, .industrial), pose)))
            let pixels = IndustrialNewBuildingsPixels(sprite.base)
            let drawn = try #require(pixels.bounds(alphaAbove: 128))
            return (1 - sprite.anchor.y) * Double(pixels.height) - Double(drawn.minY)
        }
        #expect(try height(.factory, .complete) > height(.oilWell, .complete))
        #expect(try height(.factory, .complete) > height(.railwayDepot, .complete))
        for kind in IndustrialNewBuildingsArt.kinds {
            #expect(try height(kind, .complete) > height(kind, .underConstruction), "\(kind)")
        }
    }

    /// The oil field is drawn as the terrain's sites are: on their canvas,
    /// anchored at the tile's centre, with no team's colour; it lies within
    /// its tile's diamond, rising above it only by its reeds, so that a well
    /// standing over it covers it.
    @Test func theOilFieldIsASiteWithinItsTile() throws {
        let sprite = try #require(Self.source.sprite(Self.oilField))
        #expect(sprite.teamMask == nil)
        let canvas = TerrainSprites.siteCanvas
        #expect(sprite.anchor == canvas.anchor)
        #expect(sprite.base.width == canvas.pixelWidth && sprite.base.height == canvas.pixelHeight)
        let pixels = IndustrialNewBuildingsPixels(sprite.base)
        let centreX = sprite.anchor.x * Double(pixels.width), centreY = (1 - sprite.anchor.y) * Double(pixels.height)
        let drawn = try #require(pixels.bounds(alphaAbove: 128), "the oil field is empty")
        // Two pixels a point: the tile's diamond is 128 by 64 pixels.
        #expect(Double(drawn.minX) >= centreX - 64 && Double(drawn.maxX + 1) <= centreX + 64, "\(drawn)")
        #expect(Double(drawn.maxY + 1) <= centreY + 32, "\(drawn)")
        #expect(Double(drawn.minY) >= centreY - 48, "the reeds stand \(centreY - Double(drawn.minY)) pixels tall")
        // The pool is dark: crude oil shows against the grass.
        var dark = 0
        for y in 0..<pixels.height {
            for x in 0..<pixels.width where pixels.alpha(x, y) > 250 {
                let i = (y * pixels.width + x) * 4
                if Int(pixels.bytes[i]) + Int(pixels.bytes[i + 1]) + Int(pixels.bytes[i + 2]) < 3 * 70 { dark += 1 }
            }
        }
        #expect(dark >= 400, "only \(dark) dark pixels")
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = IndustrialNewBuildingSprites(), second = IndustrialNewBuildingSprites()
        for key in Self.batch {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(IndustrialNewBuildingsPixels(a.base).bytes == IndustrialNewBuildingsPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(IndustrialNewBuildingsPixels(maskA).bytes == IndustrialNewBuildingsPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor)
        }
        let a = try #require(first.sprite(Self.oilField)), b = try #require(second.sprite(Self.oilField))
        #expect(IndustrialNewBuildingsPixels(a.base).bytes == IndustrialNewBuildingsPixels(b.base).bytes)
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let fresh = IndustrialNewBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch + [Self.oilField] { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "the batch took \(elapsed)")
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct IndustrialNewBuildingsPixels {
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
/// the environment variable `INDUSTRIAL_NEW_BUILDINGS_RENDERS`; skipped when it
/// is not set: a contact sheet of every drawing, complete and under
/// construction, in Rome's and Angkor's colours (the two nearest the brick),
/// beside the nearest Alchemy-age buildings; a scene of an Industrial-age town
/// at game size; and each drawing enlarged three times.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["INDUSTRIAL_NEW_BUILDINGS_RENDERS"] != nil))
struct IndustrialNewBuildingsRenders {
    let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["INDUSTRIAL_NEW_BUILDINGS_RENDERS"] ?? "/",
                        isDirectory: true)
    let source = IndustrialNewBuildingSprites()
    let others = GameSprites()
    let civilizations: [Civilization] = [.rome, .angkor]

    /// Grass tiles of the map laid over `rect`, as the game lays them.
    private func ground(_ context: CGContext, _ rect: CGRect) {
        context.saveGState()
        context.clip(to: rect)
        for i in -12..<12 {
            for j in -12..<12 {
                guard let tile = others.sprite(SpriteKey(.terrain(.grass, variant: (i * 7 + j * 3 + 400) % 4), .complete)) else { continue }
                let p = CGPoint(x: rect.midX + Double(i - j) * 64, y: rect.midY - Double(i + j) * 32)
                if p.x < rect.minX - 100 || p.x > rect.maxX + 100 || p.y < rect.minY - 100 || p.y > rect.maxY + 100 { continue }
                Preview.place(tile.base, anchor: tile.anchor, at: p, in: context)
            }
        }
        context.restoreGState()
    }

    @Test func contactSheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cellW = 440, cellH = 520, label = 34, columns = 5
        let rows: [(BuildingKind, [(String, SpriteKey)])] = [
            (.factory, [("Alchemist's workshop", SpriteKey(.building(.alchemistsWorkshop, .alchemy), .complete))]),
            (.railwayDepot, [("Stable", SpriteKey(.building(.stable, .alchemy), .complete))]),
            (.oilWell, [("Watch tower", SpriteKey(.building(.watchTower, .alchemy), .complete))]),
        ]
        let width = cellW * columns, height = (cellH + label) * (rows.count + 1) + 70
        let context = try #require(Raster.bitmap(width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0xef / 255.0, green: 0xe0 / 255.0, blue: 0xc2 / 255.0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The Industrial age's new buildings at game size, in Rome's and Angkor's colours, beside the nearest Alchemy-age buildings",
                      in: context, at: CGPoint(x: 16, y: height - 48), size: 24)
        for (row, (kind, beside)) in rows.enumerated() {
            let top = height - 70 - row * (cellH + label)
            let f = Catalogue.standard.stats(kind).footprint
            for column in 0..<columns {
                let rect = CGRect(x: column * cellW + 6, y: top - label - cellH + 6, width: cellW - 12, height: cellH - 12)
                ground(context, rect)
                let groundY = rect.minY + 24 + Double(f.x + f.y) * 16
                if column == 4 {
                    for (_, key) in beside {
                        guard let sprite = others.sprite(key) else { continue }
                        let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(civilizations[0]))
                        Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: rect.midX, y: groundY), in: context)
                    }
                    let text = "Beside: Alchemy " + beside.map(\.0).joined(separator: ", ").lowercased() + ", Rome"
                    Preview.label(text, in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 16)
                    continue
                }
                let complete = column < 2, civilization = civilizations[column % 2]
                let key = SpriteKey(.building(kind, .industrial), complete ? .complete : .underConstruction)
                if let sprite = source.sprite(key) {
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(civilization))
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: rect.midX, y: groundY), in: context)
                }
                let text = "\(kind.name), \(String(describing: civilization).capitalized), \(complete ? "complete" : "being built")"
                Preview.label(text, in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 16)
            }
        }
        // The last row: the oil field alone, under a well (complete, and being
        // built), beside the terrain's stone and gold sites, and enlarged.
        let top = height - 70 - rows.count * (cellH + label)
        let field = try #require(source.sprite(SpriteKey(.site(.oilField), .complete)))
        let captions = ["Oil field, alone", "Oil field under Rome's well", "Under Angkor's well, being built",
                        "Beside: stone and gold sites", "Oil field, enlarged three times"]
        for column in 0..<columns {
            let rect = CGRect(x: column * cellW + 6, y: top - label - cellH + 6, width: cellW - 12, height: cellH - 12)
            ground(context, rect)
            let centre = CGPoint(x: rect.midX, y: rect.minY + 150)
            switch column {
            case 0:
                Preview.place(field.base, anchor: field.anchor, at: centre, in: context)
            case 1, 2:
                // The field on the back tile of the well's footprint, under the well.
                Preview.place(field.base, anchor: field.anchor, at: CGPoint(x: centre.x, y: centre.y + 32), in: context)
                let pose: SpritePose = column == 1 ? .complete : .underConstruction
                let civilization = civilizations[column - 1]
                let well = try #require(source.sprite(SpriteKey(.building(.oilWell, .industrial), pose)))
                Preview.place(Preview.tinted(base: well.base, mask: well.teamMask, colour: TeamColour.of(civilization)), anchor: well.anchor,
                              at: centre, in: context)
            case 3:
                for (k, key) in [SpriteKey(.site(.stone), .complete), SpriteKey(.site(.oilField), .complete),
                                 SpriteKey(.site(.gold), .complete)].enumerated() {
                    guard let sprite = source.sprite(key) ?? others.sprite(key) else { continue }
                    Preview.place(sprite.base, anchor: sprite.anchor, at: CGPoint(x: centre.x + Double(k - 1) * 130, y: centre.y + 60),
                                  in: context)
                }
            default:
                let large = try #require(IndustrialNewBuildingsArt.renderOilField(pixelsPerPoint: 6))
                Preview.place(large.base, anchor: large.anchor, at: CGPoint(x: centre.x, y: centre.y), in: context)
            }
            Preview.label(captions[column], in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 16)
        }
        try Preview.writePNG(try #require(context.makeImage()), to: directory.appendingPathComponent("industrial-new-buildings-sheet-v2.png"))
    }

    /// An Industrial-age town at game size on the ground's tiles: Rome's
    /// factory, depot and two oil wells (one being built), Angkor's factory
    /// being built and its depot, with the town's other buildings and people
    /// in the Alchemy age's look until the Industrial age's own are drawn, oil
    /// fields under the wells and beside them, and trees.
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
                let path = (j == 14 && i < 22) || (i == 13 && j > 14 && j < 24)
                let terrain: Terrain = path ? .dirt : .grass
                guard let tile = others.sprite(SpriteKey(.terrain(terrain, variant: (i * 7 + j * 3 + 400) % 4), .complete)) else { continue }
                let p = screen(Double(i) + 0.5, Double(j) + 0.5)
                if p.x < -100 || p.x > Double(width) + 100 || p.y < -100 || p.y > Double(height) + 100 { continue }
                Preview.place(tile.base, anchor: tile.anchor, at: p, in: context)
            }
        }
        // What stands on the map: the key, its centre on the map, and its civilization.
        let things: [(SpriteKey, Double, Double, Civilization?)] = [
            (SpriteKey(.building(.factory, .industrial), .complete), 11.5, 10.5, .rome),
            (SpriteKey(.building(.railwayDepot, .industrial), .complete), 16.5, 11.5, .rome),
            (SpriteKey(.building(.oilWell, .industrial), .complete), 7, 17, .rome),
            (SpriteKey(.building(.oilWell, .industrial), .underConstruction), 7, 20, .rome),
            (SpriteKey(.building(.townCentre, .alchemy), .complete), 15.5, 17.5, .rome),
            (SpriteKey(.building(.house, .alchemy), .complete), 19, 16, .rome),
            (SpriteKey(.building(.house, .alchemy), .complete), 11, 19, .rome),
            (SpriteKey(.building(.factory, .industrial), .underConstruction), 17.5, 4.5, .angkor),
            (SpriteKey(.building(.railwayDepot, .industrial), .complete), 21, 10.5, .angkor),
            (SpriteKey(.building(.oilWell, .industrial), .complete), 22, 16, .angkor),
            // Oil fields: one on the back tile of each well's footprint, and two not yet pumped.
            (SpriteKey(.site(.oilField), .complete), 6.5, 16.5, nil),
            (SpriteKey(.site(.oilField), .complete), 6.5, 19.5, nil),
            (SpriteKey(.site(.oilField), .complete), 21.5, 15.5, nil),
            (SpriteKey(.site(.oilField), .complete), 9.5, 22.5, nil),
            (SpriteKey(.site(.oilField), .complete), 25.5, 15.5, nil),
            (SpriteKey(.site(.tree), .complete), 3.5, 4.5, nil),
            (SpriteKey(.site(.tree), .complete), 4.5, 2.5, nil),
            (SpriteKey(.site(.tree), .complete), 2.5, 13.5, nil),
            (SpriteKey(.site(.tree), .complete), 9.5, 3.5, nil),
            (SpriteKey(.unit(.worker, .alchemy), .walking), 13.2, 14.5, .rome),
            (SpriteKey(.unit(.engineer, .alchemy), .working), 8.4, 19.0, .rome),
            (SpriteKey(.unit(.musketeer, .alchemy), .standing), 14.6, 13.2, .rome),
            (SpriteKey(.unit(.merchant, .alchemy), .walking), 13.4, 18.2, .rome),
        ]
        for (key, x, y, civilization) in things.sorted(by: { ($0.1 + $0.2, $0.1) < ($1.1 + $1.2, $1.1) }) {
            guard let sprite = source.sprite(key) ?? others.sprite(key) else { continue }
            let image = civilization.map { Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of($0)) } ?? sprite.base
            Preview.place(image, anchor: sprite.anchor, at: screen(x, y), in: context)
        }
        try Preview.writePNG(try #require(context.makeImage()), to: directory.appendingPathComponent("industrial-new-buildings-town-v2.png"))
    }

    /// Each drawing three times larger than in the game, in Rome's and
    /// Angkor's colours, for close inspection.
    @Test func enlarged() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for kind in IndustrialNewBuildingsArt.kinds {
            for complete in [true, false] {
                let canvas = IndustrialNewBuildingsArt.canvas(kind).scaled(to: 6)
                let drawn = try #require(Raster.render(on: canvas) { svg in
                    var painter = IndustrialNewBuildingsPainter(layer: svg.layer)
                    painter.building(kind, complete: complete)
                    svg = painter.svg
                })
                for civilization in civilizations {
                    let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: TeamColour.of(civilization))
                    let context = try #require(Raster.bitmap(width: image.width, height: image.height))
                    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                    context.setFillColor(CGColor(srgbRed: 0x9a / 255.0, green: 0xa4 / 255.0, blue: 0x86 / 255.0, alpha: 1))
                    context.fill(rect)
                    context.draw(image, in: rect)
                    try Preview.writePNG(try #require(context.makeImage()), to: directory.appendingPathComponent(
                        "industrial-\(kind)-\(complete ? "complete" : "under-construction")-\(civilization)-enlarged-v2.png"))
                }
            }
        }
    }
}
