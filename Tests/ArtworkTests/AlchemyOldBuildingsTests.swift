// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

@Suite struct AlchemyOldBuildingsTests {
    /// One source shared by the tests that only look at the sprites.
    private static let source = AlchemyOldBuildingSprites()

    /// The buildings of the Stone, Bronze and Iron ages, the boat house among them: the batch's kinds.
    /// The castle, of the age of ships now, is drawn by the Alchemy age's new buildings; the kinds
    /// drawn as stand-ins (`StandIn`) are drawn by none.
    private static let kinds = Catalogue.standard.buildings
        .filter { $0.age <= .ships && $0.kind != .castle && StandIn.building($0.kind) == $0.kind }.map(\.kind)

    /// Every key of the batch: each of those buildings in the Alchemy age's
    /// look, complete and under construction, at frame 0.
    private static let batch: [SpriteKey] = kinds.flatMap { kind in
        [SpriteKey(.building(kind, .alchemy), .complete), SpriteKey(.building(kind, .alchemy), .underConstruction)]
    }

    /// The boat house from behind, complete and under construction (ruled 2026-11-22).
    private static let back: [SpriteKey] = [SpritePose.complete, .underConstruction].map {
        SpriteKey(.building(.boatHouse, .alchemy), $0, view: .back)
    }

    /// Every sprite the batch draws: the side view of each key, and the boat house's back view.
    private static let drawn = batch + back

    @Test func theBatchIsTheBuildingsOfTheEarlierAges() {
        #expect(Set(Self.kinds) == Set(AlchemyOldBuildingsArt.kinds))
        #expect(Self.batch.count == 14)
    }

    @Test func everyKeyOfTheBatchHasASpriteAndNoOtherKeyDoes() {
        var keys = SpriteKey.required(through: .hospitals)
        for kind in BuildingKind.allCases {
            for age in Look.allCases {
                keys.append(SpriteKey(.building(kind, age), .complete))
                keys.append(SpriteKey(.building(kind, age), .underConstruction))
            }
        }
        for key in Self.batch {
            keys.append(SpriteKey(key.subject, key.pose, frame: 1))
            keys.append(SpriteKey(key.subject, key.pose, frame: 11))
            keys.append(SpriteKey(key.subject, .standing))
            keys.append(SpriteKey(key.subject, .working))
            for view in SpriteView.allCases {
                keys.append(key.seen(view))
                keys.append(SpriteKey(key.subject, key.pose, frame: 1, view: view))
            }
        }
        let supplied = Set(keys.filter { Self.source.sprite($0) != nil })
        #expect(supplied == Set(Self.drawn))
    }

    /// The boat house is drawn from behind as well, so that it faces water on
    /// any edge; nothing else of the batch gains a view, and `GameSprites`
    /// asks the batch for the boat house's back view alone.
    @Test func theBoatHouseAloneIsDrawnFromBehind() throws {
        for kind in BuildingKind.allCases {
            for age in Look.allCases {
                #expect(Self.source.drawsViews(of: .building(kind, age)) == (kind == .boatHouse && age == .alchemy), "\(kind) \(age)")
            }
        }
        #expect(!Self.source.drawsViews(of: .unit(.fishingBoat, .alchemy)))
        for key in Self.back {
            let back = try #require(Self.source.sprite(key), "\(key)")
            let side = try #require(Self.source.sprite(key.seen(.side)))
            #expect(back.base.width == side.base.width && back.base.height == side.base.height, "\(key)")
            #expect(back.anchor == side.anchor, "\(key)")
            #expect((back.teamMask == nil) == (side.teamMask == nil), "\(key)")
            #expect(AlchemyOldBuildingsPixels(back.base).bytes != AlchemyOldBuildingsPixels(side.base).bytes, "\(key)")
            // The game's sources ask this batch for the back view: without it they would answer nothing.
            let game = try #require(GameSprites().sprite(key), "\(key)")
            #expect(game.base.width == back.base.width && game.base.height == back.base.height && game.anchor == back.anchor, "\(key)")
        }
    }

    /// A building takes the look of its owner's age: once its owner is in the
    /// Alchemy age, every building of the earlier ages is drawn from here.
    @Test func everyOlderBuildingOfAnAlchemyAgeOwnerIsSupplied() {
        for kind in Self.kinds {
            let stats = Catalogue.standard.stats(kind)
            let entity = EntityView(id: EntityID(1), owner: PlayerID(0), kind: .building(kind), position: MapPosition(x: 5, y: 5),
                                    tile: GridPoint(4, 4), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle)
            let subject = SpriteSubject.of(entity, ownerAge: .cannons)
            #expect(Self.source.sprite(SpriteKey(subject, .complete)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(subject, .underConstruction)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(SpriteSubject.of(entity, ownerAge: .ships), .complete)) == nil, "\(kind)")
        }
    }

    @Test func everySpriteCarriesTeamColour() throws {
        for key in Self.drawn {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = AlchemyOldBuildingsPixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 60, "only \(coloured) pixels of team colour in \(key)")
        }
    }

    /// The anchor is the centre of the footprint's diamond: the diamond placed by
    /// the anchor is what the drawing covers, reaching its left, bottom and right
    /// corners and overhanging none of them.
    @Test func theAnchorIsTheCentreOfTheFootprintsDiamond() throws {
        for key in Self.drawn {
            guard case .building(let kind, _) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key))
            let footprint = Catalogue.standard.stats(kind).footprint
            let pixels = AlchemyOldBuildingsPixels(sprite.base)
            let centreX = sprite.anchor.x * Double(pixels.width)
            let centreY = (1 - sprite.anchor.y) * Double(pixels.height)
            // Two pixels a point: a tile's diamond is 128 by 64 pixels.
            let halfWidth = Double(footprint.x + footprint.y) * 32, halfHeight = Double(footprint.x + footprint.y) * 16
            let drawn = try #require(pixels.bounds(alphaAbove: 128), "\(key) is empty")
            // The boat house's dock runs out over the water beyond the footprint, toward the right in both its views
            // (ruled 2026-11-22): its right corner is not the diamond's, and in the side view its far end lies a little
            // below the diamond's bottom corner. It may meet its canvas's right and bottom edges, as it does on the
            // canvas from before the dock, which crops it.
            let dock = kind == .boatHouse
            #expect(drawn.minY > 0 && drawn.minX > 0 && (dock || (drawn.maxX < pixels.width - 1 && drawn.maxY < pixels.height - 1)),
                    "\(key) reaches the edge of its picture \(drawn) \(pixels.width)x\(pixels.height)")
            let tolerance = 5.0
            #expect(abs(Double(drawn.minX) - (centreX - halfWidth)) <= tolerance, "\(key): left \(drawn.minX), corner \(centreX - halfWidth)")
            if dock {
                #expect(Double(drawn.maxX + 1) >= centreX + halfWidth, "\(key): the dock ends at \(drawn.maxX + 1), short of the footprint")
            } else {
                #expect(abs(Double(drawn.maxX + 1) - (centreX + halfWidth)) <= tolerance,
                        "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
            }
            let bottom = Double(drawn.maxY + 1) - (centreY + halfHeight)
            #expect(dock ? bottom >= -tolerance && bottom <= 8 * 2 : abs(bottom) <= tolerance,
                    "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
        }
    }

    /// Each building keeps the canvas, and so the size and the anchor, of its Iron look.
    @Test func eachBuildingKeepsItsIronCanvas() throws {
        let ironOld = IronOldBuildingSprites(), ironNew = IronNewBuildingSprites()
        for key in Self.batch {
            guard case .building(let kind, _) = key.subject else { continue }
            let alchemy = try #require(Self.source.sprite(key))
            let ironKey = SpriteKey(.building(kind, .iron), key.pose)
            let iron = try #require(ironOld.sprite(ironKey) ?? ironNew.sprite(ironKey), "\(kind) has no Iron look")
            #expect(alchemy.base.width == iron.base.width && alchemy.base.height == iron.base.height, "\(key)")
            #expect(alchemy.anchor == iron.anchor, "\(key)")
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = AlchemyOldBuildingSprites(), second = AlchemyOldBuildingSprites()
        for key in Self.drawn {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(AlchemyOldBuildingsPixels(a.base).bytes == AlchemyOldBuildingsPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(AlchemyOldBuildingsPixels(maskA).bytes == AlchemyOldBuildingsPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor)
        }
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let fresh = AlchemyOldBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "the batch took \(elapsed)")
    }

    // MARK: Rendering for inspection

    /// Writes the contact sheet, the scene and enlarged drawings for a person
    /// to judge, into the directory named by `ARTWORK_RENDERS`; skipped when it
    /// is not set. `ARTWORK_ONLY` limits the enlarged drawings to the kinds it names.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] != nil))
    func rendersTheSheetAndTheScene() throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = URL(fileURLWithPath: environment["ARTWORK_RENDERS"] ?? "/", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let only = environment["ARTWORK_ONLY"].map { $0.split(separator: ",").map(String.init) }
        if only == nil {
            try Preview.writePNG(try #require(AlchemyOldBuildingsPreview.contactSheet(Self.kinds)),
                                 to: directory.appendingPathComponent("alchemy-old-buildings-contact-sheet.png"))
            try Preview.writePNG(try #require(AlchemyOldBuildingsPreview.scene()),
                                 to: directory.appendingPathComponent("alchemy-old-buildings-scene.png"))
        }
        for kind in Self.kinds where only?.contains("\(kind)") ?? true {
            for complete in [true, false] {
                let image = try #require(AlchemyOldBuildingsPreview.enlarged(kind, complete: complete))
                try Preview.writePNG(image, to: directory.appendingPathComponent(
                    "alchemy-old-\(kind)-\(complete ? "complete" : "under-construction")-enlarged.png"))
            }
        }
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct AlchemyOldBuildingsPixels {
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

/// Pictures of the batch for a person to judge.
private enum AlchemyOldBuildingsPreview {
    static let alchemy = AlchemyOldBuildingSprites()
    static let ironOld = IronOldBuildingSprites()
    static let ironNew = IronNewBuildingSprites()
    /// Rome's red and Angkor's orange, the two team colours nearest the palette's wine and gilt.
    static let civilizations: [Civilization] = [.rome, .angkor]

    static func rgb(_ hex: String) -> CGColor {
        let v = Int(hex.dropFirst(), radix: 16) ?? 0
        return CGColor(srgbRed: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255,
                       blue: Double(v & 255) / 255, alpha: 1)
    }

    /// A flat field of `colour` with the faint diamonds of the map's tiles and the grain over it.
    static func field(_ context: CGContext, _ rect: CGRect, colour: String, joints: String) {
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

    /// For each kind, a row: its Iron look, complete and under construction,
    /// then its Alchemy look complete and under construction, each in Rome's
    /// and Angkor's colours.
    static func contactSheet(_ kinds: [BuildingKind]) -> CGImage? {
        let cellW = 420, cellH = 380, label = 34
        let columns: [(age: Look, complete: Bool, civilization: Civilization)] = [
            (.iron, true, .rome), (.iron, false, .rome),
            (.alchemy, true, .rome), (.alchemy, true, .angkor), (.alchemy, false, .rome), (.alchemy, false, .angkor),
        ]
        let width = cellW * columns.count, height = (cellH + label) * kinds.count + 60
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(rgb("#efe0c2"))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The buildings of the earlier ages in the Alchemy age's look, beside their Iron look",
                      in: context, at: CGPoint(x: 16, y: height - 44), size: 26)
        for (row, kind) in kinds.enumerated() {
            let top = height - 60 - row * (cellH + label)
            for (column, cell) in columns.enumerated() {
                let key = SpriteKey(.building(kind, cell.age), cell.complete ? .complete : .underConstruction)
                let rect = CGRect(x: column * cellW + 6, y: top - label - cellH + 6, width: cellW - 12, height: cellH - 12)
                let isIron = cell.age == .iron
                field(context, rect, colour: isIron ? "#6fa39a" : "#d6b25e", joints: isIron ? "#64978e" : "#c8a453")
                let found = isIron ? (ironOld.sprite(key) ?? ironNew.sprite(key)) : alchemy.sprite(key)
                if let sprite = found {
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(cell.civilization))
                    let f = Catalogue.standard.stats(kind).footprint
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: rect.midX, y: rect.minY + 14 + Double(f.x + f.y) * 16),
                                  in: context)
                }
                let text = "\(kind.name), \(isIron ? "Iron" : "Alchemy"), \(String(describing: cell.civilization).capitalized), "
                    + (cell.complete ? "complete" : "building")
                Preview.label(text, in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 17)
            }
        }
        return context.makeImage()
    }

    /// An Alchemy-age town at game size on the ground: the town hall amid
    /// houses, the store, the pen, the barracks, a farm, the stable and the
    /// siege workshop, a tower, a row of palisade and a stone wall, with a
    /// house, the tower and a farm still being built.
    static func scene() -> CGImage? {
        let terrain = TerrainSprites()
        let size = 20, width = size * 128, height = size * 64 + 200
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(rgb("#6fa39a"))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        func screen(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: Double(width) / 2 + (x - y) * 64, y: Double(height) - 180 - (x + y) * 32)
        }
        for y in 0..<size {
            for x in 0..<size {
                let path = y == 10 || (x == 10 && y >= 3 && y <= 15)
                let kind: Terrain = path ? .dirt : .grass
                if let tile = terrain.sprite(SpriteKey(.terrain(kind, variant: (x * 7 + y * 3) % 4), .complete)) {
                    Preview.place(tile.base, anchor: tile.anchor, at: screen(Double(x) + 0.5, Double(y) + 0.5), in: context)
                }
            }
        }
        struct Placed { var kind: BuildingKind; var x: Int; var y: Int; var complete: Bool; var civilization: Civilization }
        var placed: [Placed] = [
            Placed(kind: .townCentre, x: 7, y: 6, complete: true, civilization: .rome),
            Placed(kind: .house, x: 5, y: 7, complete: true, civilization: .rome),
            Placed(kind: .house, x: 7, y: 3, complete: true, civilization: .rome),
            Placed(kind: .house, x: 11, y: 7, complete: true, civilization: .rome),
            Placed(kind: .house, x: 5, y: 4, complete: false, civilization: .rome),
            Placed(kind: .barracks, x: 11, y: 11, complete: true, civilization: .rome),
            Placed(kind: .tower, x: 9, y: 2, complete: false, civilization: .rome),
            Placed(kind: .tower, x: 15, y: 9, complete: true, civilization: .rome),
            Placed(kind: .farm, x: 2, y: 8, complete: true, civilization: .rome),
            Placed(kind: .farm, x: 2, y: 12, complete: false, civilization: .rome),
            Placed(kind: .stable, x: 7, y: 14, complete: true, civilization: .rome),
        ]
        func depth(_ p: Placed) -> Double {
            let f = Catalogue.standard.stats(p.kind).footprint
            return Double(p.x) + Double(p.y) + Double(f.x + f.y) / 2
        }
        for p in placed.sorted(by: { depth($0) < depth($1) }) {
            let f = Catalogue.standard.stats(p.kind).footprint
            let key = SpriteKey(.building(p.kind, .alchemy), p.complete ? .complete : .underConstruction)
            guard let sprite = alchemy.sprite(key) else { continue }
            let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(p.civilization))
            Preview.place(image, anchor: sprite.anchor,
                          at: screen(Double(p.x) + Double(f.x) / 2, Double(p.y) + Double(f.y) / 2), in: context)
        }
        return context.makeImage()
    }

    /// A building drawn three times larger than in the game, tinted in Rome's colour, for close inspection.
    static func enlarged(_ kind: BuildingKind, complete: Bool) -> CGImage? {
        let canvas = AlchemyOldBuildingsArt.canvas(kind).scaled(to: 6)
        guard let drawn = Raster.render(on: canvas, { svg in
            var painter = AlchemyOldBuildingsPainter(layer: svg.layer)
            painter.building(kind, complete: complete)
            svg = painter.svg
        }) else { return nil }
        let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: TeamColour.of(.rome))
        guard let context = Raster.bitmap(width: image.width, height: image.height) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        field(context, rect, colour: "#d6b25e", joints: "#c8a453")
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
