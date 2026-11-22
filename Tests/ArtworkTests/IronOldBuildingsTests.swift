// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

@Suite struct IronOldBuildingsTests {
    /// One source shared by the tests that only look at the sprites.
    private static let source = IronOldBuildingSprites()

    /// The buildings of the Stone and Bronze ages, the boat house among them: the batch's kinds.
    private static let kinds = Catalogue.standard.buildings.filter { $0.age <= .bronze && $0.kind != .bridge }.map(\.kind)

    /// Every key of the batch: each of those buildings in the Iron age's look,
    /// complete and under construction, at frame 0.
    private static let batch: [SpriteKey] = kinds.flatMap { kind in
        [SpriteKey(.building(kind, .iron), .complete), SpriteKey(.building(kind, .iron), .underConstruction)]
    }

    /// The boat house's back view (ruled 2026-11-22), complete and under construction: the only keys not in the side view.
    private static let backs: [SpriteKey] = [SpriteKey(.building(.boatHouse, .iron), .complete, view: .back),
                                             SpriteKey(.building(.boatHouse, .iron), .underConstruction, view: .back)]

    @Test func everyKeyOfTheBatchHasASpriteAndNoOtherKeyDoes() {
        #expect(Self.batch.count == 16)
        var keys = SpriteKey.required(through: .ai)
        for kind in BuildingKind.allCases {
            for age in Age.allCases {
                keys.append(SpriteKey(.building(kind, age), .complete))
                keys.append(SpriteKey(.building(kind, age), .underConstruction))
            }
        }
        for key in Self.batch {
            keys.append(SpriteKey(key.subject, key.pose, frame: 1))
            keys.append(SpriteKey(key.subject, key.pose, frame: 11))
            keys.append(SpriteKey(key.subject, .standing))
            keys.append(SpriteKey(key.subject, .working))
        }
        // Every one of those keys in every other view as well.
        keys += keys.flatMap { key in SpriteView.allCases.filter { $0 != .side }.map { SpriteKey(key.subject, key.pose, frame: key.frame, view: $0) } }
        let supplied = Set(keys.filter { Self.source.sprite($0) != nil })
        #expect(supplied == Set(Self.batch + Self.backs))
    }

    /// The batch draws views of the Iron boat house alone, so that `GameSprites`
    /// asks it for no other subject's views, and gives the back view from it.
    @Test func onlyTheBoatHouseIsDrawnInViews() throws {
        for kind in BuildingKind.allCases {
            for age in Age.allCases {
                let subject = SpriteSubject.building(kind, age)
                #expect(Self.source.drawsViews(of: subject) == (subject == .building(.boatHouse, .iron)), "\(subject)")
            }
        }
        #expect(!Self.source.drawsViews(of: .unit(.boat, .iron)))
        let sprites = GameSprites()
        for key in Self.backs {
            let routed = try #require(sprites.sprite(key), "\(key)")
            let own = try #require(Self.source.sprite(key))
            #expect(IronOldBuildingsPixels(routed.base).bytes == IronOldBuildingsPixels(own.base).bytes, "\(key)")
        }
    }

    /// The back view is the same building turned: drawn on the side view's
    /// canvas, standing at its anchor, carrying team colour where the side
    /// does, and a different picture.
    @Test func theBackViewKeepsTheSidesCanvasAndDiffersFromIt() throws {
        for back in Self.backs {
            let side = try #require(Self.source.sprite(SpriteKey(back.subject, back.pose)))
            let sprite = try #require(Self.source.sprite(back), "\(back)")
            #expect(sprite.base.width == side.base.width && sprite.base.height == side.base.height, "\(back)")
            #expect(sprite.anchor == side.anchor, "\(back)")
            #expect((sprite.teamMask != nil) == (side.teamMask != nil), "\(back)")
            #expect(IronOldBuildingsPixels(sprite.base).bytes != IronOldBuildingsPixels(side.base).bytes, "\(back)")
        }
    }

    /// A building takes the look of its owner's age: once its owner is in the
    /// Iron age, every building of the earlier ages is drawn from here.
    @Test func everyOlderBuildingOfAnIronAgeOwnerIsSupplied() {
        for kind in Self.kinds {
            let stats = Catalogue.standard.stats(kind)
            let entity = EntityView(id: EntityID(1), owner: PlayerID(0), kind: .building(kind), position: MapPosition(x: 5, y: 5),
                                    tile: GridPoint(4, 4), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle)
            let subject = SpriteSubject.of(entity, ownerAge: .iron)
            #expect(Self.source.sprite(SpriteKey(subject, .complete)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(subject, .underConstruction)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(SpriteSubject.of(entity, ownerAge: .bronze), .complete)) == nil, "\(kind)")
        }
    }

    @Test func everySpriteCarriesTeamColour() throws {
        for key in Self.batch + Self.backs {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = IronOldBuildingsPixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 60, "only \(coloured) pixels of team colour in \(key)")
        }
    }

    /// The anchor is the centre of the footprint's diamond: the diamond placed by
    /// the anchor is what the drawing covers, reaching its left, bottom and right
    /// corners and overhanging none of them.
    @Test func theAnchorIsTheCentreOfTheFootprintsDiamond() throws {
        for key in Self.batch + Self.backs {
            guard case .building(let kind, _) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key))
            let footprint = Catalogue.standard.stats(kind).footprint
            let pixels = IronOldBuildingsPixels(sprite.base)
            let centreX = sprite.anchor.x * Double(pixels.width)
            let centreY = (1 - sprite.anchor.y) * Double(pixels.height)
            // Two pixels a point: a tile's diamond is 128 by 64 pixels.
            let halfWidth = Double(footprint.x + footprint.y) * 32, halfHeight = Double(footprint.x + footprint.y) * 16
            let drawn = try #require(pixels.bounds(alphaAbove: 128), "\(key) is empty")
            let tolerance = 5.0
            // The boat house's jetty runs out over the water beyond the diamond,
            // toward the lower right or the upper right, on the canvas grown for
            // it (BronzeBuildingsArt.canvas); its left corner and top are as for any building.
            if kind == .boatHouse {
                #expect(drawn.minY > 0 && drawn.minX > 0, "\(key) reaches the edge of its picture")
                #expect(abs(Double(drawn.minX) - (centreX - halfWidth)) <= tolerance, "\(key): left \(drawn.minX), corner \(centreX - halfWidth)")
                #expect(Double(drawn.maxX + 1) >= centreX + halfWidth - tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
                continue
            }
            // Nothing is cut off by the edges of the picture.
            #expect(drawn.minY > 0 && drawn.minX > 0 && drawn.maxX < pixels.width - 1 && drawn.maxY < pixels.height - 1,
                    "\(key) reaches the edge of its picture")
            #expect(abs(Double(drawn.minX) - (centreX - halfWidth)) <= tolerance, "\(key): left \(drawn.minX), corner \(centreX - halfWidth)")
            #expect(abs(Double(drawn.maxX + 1) - (centreX + halfWidth)) <= tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
            #expect(abs(Double(drawn.maxY + 1) - (centreY + halfHeight)) <= tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
        }
    }

    /// Each building keeps the canvas, and so the size and the anchor, of its Bronze look.
    @Test func eachBuildingKeepsItsBronzeCanvas() throws {
        let bronze = BronzeBuildingSprites()
        for key in Self.batch {
            guard case .building(let kind, _) = key.subject else { continue }
            let iron = try #require(Self.source.sprite(key))
            let old = try #require(bronze.sprite(SpriteKey(.building(kind, .bronze), key.pose)))
            #expect(iron.base.width == old.base.width && iron.base.height == old.base.height, "\(key)")
            #expect(iron.anchor == old.anchor, "\(key)")
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = IronOldBuildingSprites(), second = IronOldBuildingSprites()
        for key in Self.batch + Self.backs {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(IronOldBuildingsPixels(a.base).bytes == IronOldBuildingsPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(IronOldBuildingsPixels(maskA).bytes == IronOldBuildingsPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor)
        }
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let fresh = IronOldBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "the batch took \(elapsed)")
    }

    // MARK: Rendering for inspection

    /// Writes the contact sheet, the scene and enlarged drawings for a person
    /// to judge, into the directory named by `ARTWORK_RENDERS`; skipped when it
    /// is not set.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] != nil))
    func rendersTheSheetAndTheScene() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] ?? "/", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Preview.writePNG(try #require(IronOldBuildingsPreview.contactSheet(Self.kinds)),
                             to: directory.appendingPathComponent("iron-old-buildings-contact-sheet.png"))
        try Preview.writePNG(try #require(IronOldBuildingsPreview.scene()),
                             to: directory.appendingPathComponent("iron-old-buildings-scene.png"))
        for kind in Self.kinds {
            for complete in [true, false] {
                let image = try #require(IronOldBuildingsPreview.enlarged(kind, complete: complete))
                try Preview.writePNG(image, to: directory.appendingPathComponent(
                    "iron-old-\(kind)-\(complete ? "complete" : "under-construction")-enlarged.png"))
            }
        }
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct IronOldBuildingsPixels {
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
private enum IronOldBuildingsPreview {
    static let iron = IronOldBuildingSprites()
    static let bronze = BronzeBuildingSprites()
    static let civilizations: [Civilization] = [.sumer, .egypt]

    /// A flat field of `colour` with the faint diamonds of the map's tiles and the grain over it.
    static func field(_ context: CGContext, _ rect: CGRect, colour: String, joints: String) {
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

    /// For each kind, a row: its Bronze look, then its Iron look in two
    /// civilizations' colours, complete and then under construction.
    static func contactSheet(_ kinds: [BuildingKind]) -> CGImage? {
        let cellW = 440, cellH = 390, label = 34
        let columns = 6
        let width = cellW * columns, height = (cellH + label) * kinds.count + 60
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0xef / 255.0, green: 0xe0 / 255.0, blue: 0xc2 / 255.0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The buildings of the earlier ages in the Iron age's look, beside their Bronze look",
                      in: context, at: CGPoint(x: 16, y: height - 44), size: 26)
        for (row, kind) in kinds.enumerated() {
            let top = height - 60 - row * (cellH + label)
            for column in 0..<columns {
                let complete = column < 3, which = column % 3
                let isBronze = which == 0
                let civilization = isBronze ? civilizations[0] : civilizations[which - 1]
                let source: SpriteSource = isBronze ? bronze : iron
                let key = SpriteKey(.building(kind, isBronze ? .bronze : .iron), complete ? .complete : .underConstruction)
                let rect = CGRect(x: column * cellW + 6, y: top - label - cellH + 6, width: cellW - 12, height: cellH - 12)
                field(context, rect, colour: isBronze ? "#d9b46c" : "#6fa39a", joints: isBronze ? "#cba55e" : "#64978e")
                if let sprite = source.sprite(key) {
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(civilization))
                    let f = Catalogue.standard.stats(kind).footprint
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: rect.midX, y: rect.minY + 14 + Double(f.x + f.y) * 16),
                                  in: context)
                }
                let text = "\(kind.name), \(isBronze ? "Bronze" : "Iron, \(civilization)"), \(complete ? "complete" : "under construction")"
                Preview.label(text, in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 17)
            }
        }
        return context.makeImage()
    }

    /// An Iron-age town at game size: grass and paths, the town centre amid
    /// houses, the store, the pen, the barracks, a tower, and a row of
    /// palisade, one of the houses and the tower still being built.
    static func scene() -> CGImage? {
        let terrain = TerrainSprites()
        let size = 16, width = size * 128, height = size * 64 + 160
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0x6f / 255.0, green: 0xa3 / 255.0, blue: 0x9a / 255.0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        /// The pixel of the image (origin bottom left) at a point of the map.
        func screen(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: Double(width) / 2 + (x - y) * 64, y: Double(height) - 140 - (x + y) * 32)
        }
        for y in 0..<size {
            for x in 0..<size {
                let path = y == 9 || (x == 9 && y >= 4)
                let kind: Terrain = path ? .dirt : .grass
                if let tile = terrain.sprite(SpriteKey(.terrain(kind, variant: (x * 7 + y * 3) % 4), .complete)) {
                    Preview.place(tile.base, anchor: tile.anchor, at: screen(Double(x) + 0.5, Double(y) + 0.5), in: context)
                }
            }
        }
        struct Placed { var kind: BuildingKind; var x: Int; var y: Int; var complete: Bool; var civilization: Civilization }
        var placed: [Placed] = [
            Placed(kind: .townCentre, x: 6, y: 6, complete: true, civilization: .sumer),
            Placed(kind: .house, x: 4, y: 7, complete: true, civilization: .sumer),
            Placed(kind: .house, x: 7, y: 3, complete: true, civilization: .sumer),
            Placed(kind: .house, x: 4, y: 4, complete: false, civilization: .sumer),
            Placed(kind: .storagePit, x: 10, y: 6, complete: true, civilization: .sumer),
            Placed(kind: .stockPen, x: 5, y: 10, complete: true, civilization: .sumer),
            Placed(kind: .barracks, x: 10, y: 10, complete: true, civilization: .sumer),
            Placed(kind: .watchTower, x: 9, y: 3, complete: false, civilization: .sumer),
            Placed(kind: .watchTower, x: 13, y: 8, complete: true, civilization: .sumer),
        ]
        for y in 2..<8 { placed.append(Placed(kind: .palisade, x: 13, y: y, complete: true, civilization: .sumer)) }
        for x in 9..<12 { placed.append(Placed(kind: .palisade, x: x, y: 2, complete: true, civilization: .sumer)) }
        placed.append(Placed(kind: .palisade, x: 12, y: 2, complete: false, civilization: .sumer))
        func depth(_ p: Placed) -> Double {
            let f = Catalogue.standard.stats(p.kind).footprint
            return Double(p.x) + Double(p.y) + Double(f.x + f.y) / 2
        }
        for p in placed.sorted(by: { depth($0) < depth($1) }) {
            let f = Catalogue.standard.stats(p.kind).footprint
            let key = SpriteKey(.building(p.kind, .iron), p.complete ? .complete : .underConstruction)
            guard let sprite = iron.sprite(key) else { continue }
            let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(p.civilization))
            Preview.place(image, anchor: sprite.anchor,
                          at: screen(Double(p.x) + Double(f.x) / 2, Double(p.y) + Double(f.y) / 2), in: context)
        }
        return context.makeImage()
    }

    /// A building drawn three times larger than in the game, tinted in Sumer's colour, for close inspection.
    static func enlarged(_ kind: BuildingKind, complete: Bool) -> CGImage? {
        let canvas = IronOldBuildingsArt.canvas(kind).scaled(to: 6)
        guard let drawn = Raster.render(on: canvas, { svg in
            var painter = IronOldBuildingsPainter(layer: svg.layer)
            painter.building(kind, complete: complete)
            svg = painter.svg
        }) else { return nil }
        let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: TeamColour.of(.sumer))
        guard let context = Raster.bitmap(width: image.width, height: image.height) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        field(context, rect, colour: "#6fa39a", joints: "#64978e")
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
