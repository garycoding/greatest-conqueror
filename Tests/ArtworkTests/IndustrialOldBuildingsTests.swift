// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

@Suite struct IndustrialOldBuildingsTests {
    /// One source shared by the tests that only look at the sprites.
    private static let source = IndustrialOldBuildingSprites()

    /// The buildings of the Stone, Bronze, Iron and Alchemy ages, the boat house among them: the batch's kinds.
    private static let kinds = Catalogue.standard.buildings.filter { $0.age <= .cannons }.map(\.kind)

    /// Every key of the batch: each of those buildings in the Industrial age's
    /// look, complete and under construction, at frame 0.
    private static let batch: [SpriteKey] = kinds.flatMap { kind in
        [SpriteKey(.building(kind, .industrial), .complete), SpriteKey(.building(kind, .industrial), .underConstruction)]
    }

    /// The boat house in the back view (ruled 2026-11-22), complete and under construction.
    private static let back: [SpriteKey] = [SpritePose.complete, .underConstruction].map {
        SpriteKey(.building(.boatHouse, .industrial), $0, view: .back)
    }

    /// Every sprite the batch draws: the batch in the side view, and the boat house's back view.
    private static let drawn = batch + back

    @Test func theBatchIsTheBuildingsOfTheEarlierAges() {
        #expect(Set(Self.kinds) == Set(IndustrialOldBuildingsArt.kinds))
        #expect(Self.batch.count == 16)
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
            for view in SpriteView.allCases { keys.append(key.seen(view)) }
        }
        let supplied = Set(keys.filter { Self.source.sprite($0) != nil })
        #expect(supplied == Set(Self.drawn))
    }

    /// Only the boat house is drawn in another view, and only in the back view;
    /// `GameSprites` asks this batch for it, and for no other building's view.
    @Test func onlyTheBoatHouseHasABackView() throws {
        #expect(Self.source.drawsViews(of: .building(.boatHouse, .industrial)))
        for kind in BuildingKind.allCases where kind != .boatHouse {
            #expect(!Self.source.drawsViews(of: .building(kind, .industrial)), "\(kind)")
        }
        for age in Look.allCases where age != .industrial {
            #expect(!Self.source.drawsViews(of: .building(.boatHouse, age)), "\(age)")
        }
        // The game's sprite in the back view is this batch's back view, not the side it would fall back to.
        let game = GameSprites()
        for key in Self.back {
            let theGames = try #require(game.sprite(key)), side = try #require(Self.source.sprite(key.seen(.side)))
            #expect(IndustrialOldBuildingsPixels(theGames.base).bytes != IndustrialOldBuildingsPixels(side.base).bytes, "\(key)")
        }
    }

    /// The back view is the same building on the same canvas: the side's size
    /// and anchor, a mask where the side has one, and a picture of its own.
    @Test func theBackViewMatchesTheSideInSizeAndAnchorButNotInPixels() throws {
        for key in Self.back {
            let back = try #require(Self.source.sprite(key)), side = try #require(Self.source.sprite(key.seen(.side)))
            #expect(back.base.width == side.base.width && back.base.height == side.base.height, "\(key)")
            #expect(back.anchor == side.anchor, "\(key)")
            #expect((back.teamMask == nil) == (side.teamMask == nil), "\(key)")
            #expect(IndustrialOldBuildingsPixels(back.base).bytes != IndustrialOldBuildingsPixels(side.base).bytes, "\(key)")
            let backMask = try #require(back.teamMask), sideMask = try #require(side.teamMask)
            #expect(IndustrialOldBuildingsPixels(backMask).bytes != IndustrialOldBuildingsPixels(sideMask).bytes, "\(key)")
        }
    }

    /// A building takes the look of its owner's age: once its owner is in the
    /// Industrial age, every building of the earlier ages is drawn from here.
    @Test func everyOlderBuildingOfAnIndustrialAgeOwnerIsSupplied() {
        for kind in Self.kinds {
            let stats = Catalogue.standard.stats(kind)
            let entity = EntityView(id: EntityID(1), owner: PlayerID(0), kind: .building(kind), position: MapPosition(x: 5, y: 5),
                                    tile: GridPoint(4, 4), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle)
            let subject = SpriteSubject.of(entity, ownerAge: .hospitals)
            #expect(Self.source.sprite(SpriteKey(subject, .complete)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(subject, .underConstruction)) != nil, "\(kind)")
            #expect(Self.source.sprite(SpriteKey(SpriteSubject.of(entity, ownerAge: .cannons), .complete)) == nil, "\(kind)")
        }
    }

    @Test func everySpriteCarriesTeamColour() throws {
        for key in Self.drawn {
            let sprite = try #require(Self.source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "no mask for \(key)")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height)
            // Enough of the mask is coloured to be seen at game size.
            let pixels = IndustrialOldBuildingsPixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 60, "only \(coloured) pixels of team colour in \(key)")
        }
    }

    /// The anchor is the centre of the footprint's diamond: the diamond placed by
    /// the anchor is what the drawing covers, reaching its left, bottom and right
    /// corners and overhanging none of them. The boat house's dock reaches
    /// beyond the diamond toward the water, to the right and, in the side view,
    /// below; there the drawing reaches the corner at least.
    @Test func theAnchorIsTheCentreOfTheFootprintsDiamond() throws {
        for key in Self.drawn {
            guard case .building(let kind, _) = key.subject else { continue }
            let sprite = try #require(Self.source.sprite(key))
            let footprint = Catalogue.standard.stats(kind).footprint
            let pixels = IndustrialOldBuildingsPixels(sprite.base)
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
            if kind == .boatHouse {
                #expect(right >= -tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
                if key.view == .side {
                    #expect(bottom >= -tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
                } else {
                    #expect(abs(bottom) <= tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
                }
                continue
            }
            #expect(abs(right) <= tolerance, "\(key): right \(drawn.maxX + 1), corner \(centreX + halfWidth)")
            #expect(abs(bottom) <= tolerance, "\(key): bottom \(drawn.maxY + 1), corner \(centreY + halfHeight)")
        }
    }

    /// Each building keeps the canvas, and so the size and the anchor, of its
    /// Alchemy look; the boat house has the canvas every age shares for it, the
    /// Stone look's grown 16 points to the right and 10 down for the dock
    /// (ruled 2026-11-22), in both its views.
    @Test func eachBuildingKeepsItsAlchemyCanvas() throws {
        let alchemyOld = AlchemyOldBuildingSprites(), alchemyNew = AlchemyNewBuildingSprites()
        let shared = Canvas(minX: -68, minY: -108, width: 152, height: 154, pixelsPerUnit: 2)
        for key in Self.drawn {
            guard case .building(let kind, _) = key.subject else { continue }
            let industrial = try #require(Self.source.sprite(key))
            if kind == .boatHouse {
                #expect(industrial.base.width == shared.pixelWidth && industrial.base.height == shared.pixelHeight, "\(key)")
                #expect(industrial.anchor == shared.anchor, "\(key)")
                continue
            }
            let alchemyKey = SpriteKey(.building(kind, .alchemy), key.pose)
            let alchemy = try #require(alchemyOld.sprite(alchemyKey) ?? alchemyNew.sprite(alchemyKey), "\(kind)")
            #expect(industrial.base.width == alchemy.base.width && industrial.base.height == alchemy.base.height, "\(key)")
            #expect(industrial.anchor == alchemy.anchor, "\(key)")
        }
    }

    /// The town hall stands above the other buildings of the town, and the castle above every building of the batch.
    @Test func theTownHallAndTheCastleStandAboveTheRest() throws {
        func height(_ kind: BuildingKind) throws -> Int {
            let sprite = try #require(Self.source.sprite(SpriteKey(.building(kind, .industrial), .complete)))
            let pixels = IndustrialOldBuildingsPixels(sprite.base)
            let drawn = try #require(pixels.bounds(alphaAbove: 128))
            return Int((1 - sprite.anchor.y) * Double(pixels.height)) - drawn.minY
        }
        let castle = try height(.castle), hall = try height(.townCentre)
        for kind in Self.kinds where kind != .castle {
            #expect(try height(kind) <= castle, "\(kind)")
            if kind != .townCentre { #expect(try height(kind) < hall, "\(kind)") }
        }
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let first = IndustrialOldBuildingSprites(), second = IndustrialOldBuildingSprites()
        for key in Self.drawn {
            let a = try #require(first.sprite(key)), b = try #require(second.sprite(key))
            #expect(IndustrialOldBuildingsPixels(a.base).bytes == IndustrialOldBuildingsPixels(b.base).bytes, "\(key)")
            let maskA = try #require(a.teamMask), maskB = try #require(b.teamMask)
            #expect(IndustrialOldBuildingsPixels(maskA).bytes == IndustrialOldBuildingsPixels(maskB).bytes, "\(key)")
            #expect(a.anchor == b.anchor)
        }
    }

    @Test func theBatchRendersInUnderThreeSeconds() {
        let fresh = IndustrialOldBuildingSprites()
        let elapsed = ContinuousClock().measure {
            for key in Self.batch { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(3), "the batch took \(elapsed)")
    }

    // MARK: Rendering for inspection

    /// Writes the contact sheet, the scene and enlarged drawings for a person
    /// to judge, into the directory named by `ARTWORK_RENDERS`; skipped when it
    /// is not set. `ARTWORK_ONLY` limits the enlarged drawings to the kinds it
    /// names, and leaves out the sheet and the scene; `ARTWORK_ENLARGED` draws
    /// all of them; `ARTWORK_SUFFIX` is added to the sheet's and the scene's names.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ARTWORK_RENDERS"] != nil))
    func rendersTheSheetAndTheScene() throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = URL(fileURLWithPath: environment["ARTWORK_RENDERS"] ?? "/", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let only = environment["ARTWORK_ONLY"].map { $0.split(separator: ",").map(String.init) }
        // A suffix for the sheet and the scene, so that a later round keeps the earlier files.
        let suffix = environment["ARTWORK_SUFFIX"] ?? ""
        if only == nil {
            try Preview.writePNG(try #require(IndustrialOldBuildingsPreview.contactSheet(Self.kinds)),
                                 to: directory.appendingPathComponent("industrial-old-buildings-contact-sheet\(suffix).png"))
            try Preview.writePNG(try #require(IndustrialOldBuildingsPreview.scene()),
                                 to: directory.appendingPathComponent("industrial-old-buildings-scene\(suffix).png"))
        }
        for kind in Self.kinds where only?.contains("\(kind)") ?? (environment["ARTWORK_ENLARGED"] != nil) {
            for complete in [true, false] {
                let image = try #require(IndustrialOldBuildingsPreview.enlarged(kind, complete: complete))
                try Preview.writePNG(image, to: directory.appendingPathComponent(
                    "industrial-old-\(kind)-\(complete ? "complete" : "under-construction")-enlarged.png"))
            }
        }
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct IndustrialOldBuildingsPixels {
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
private enum IndustrialOldBuildingsPreview {
    static let industrial = IndustrialOldBuildingSprites()
    static let alchemyOld = AlchemyOldBuildingSprites()
    static let alchemyNew = AlchemyNewBuildingSprites()

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

    /// For each kind, a row: its Alchemy look, complete and under
    /// construction, then its Industrial look complete in Rome's, Angkor's,
    /// Shang's and Olmec's colours, and under construction in Rome's and Shang's.
    static func contactSheet(_ kinds: [BuildingKind]) -> CGImage? {
        let cellW = 440, cellH = 420, label = 34
        let columns: [(age: Look, complete: Bool, civilization: Civilization)] = [
            (.alchemy, true, .rome), (.alchemy, false, .rome),
            (.industrial, true, .rome), (.industrial, true, .angkor), (.industrial, true, .shang), (.industrial, true, .olmec),
            (.industrial, false, .rome), (.industrial, false, .shang),
        ]
        let width = cellW * columns.count, height = (cellH + label) * kinds.count + 60
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(rgb("#efe0c2"))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The buildings of the earlier ages in the Industrial age's look, beside their Alchemy look",
                      in: context, at: CGPoint(x: 16, y: height - 44), size: 26)
        for (row, kind) in kinds.enumerated() {
            let top = height - 60 - row * (cellH + label)
            for (column, cell) in columns.enumerated() {
                let key = SpriteKey(.building(kind, cell.age), cell.complete ? .complete : .underConstruction)
                let rect = CGRect(x: column * cellW + 6, y: top - label - cellH + 6, width: cellW - 12, height: cellH - 12)
                let isAlchemy = cell.age == .alchemy
                field(context, rect, colour: isAlchemy ? "#d6b25e" : "#c2683c", joints: isAlchemy ? "#c8a453" : "#b45e34")
                let found = isAlchemy ? (alchemyOld.sprite(key) ?? alchemyNew.sprite(key)) : industrial.sprite(key)
                if let sprite = found {
                    let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(cell.civilization))
                    let f = Catalogue.standard.stats(kind).footprint
                    let scale = min(1, Double(rect.width - 8) / Double(image.width), Double(rect.height - 8) / Double(image.height))
                    Preview.place(image, anchor: sprite.anchor,
                                  at: CGPoint(x: rect.midX, y: rect.minY + 10 + Double(f.x + f.y) * 16 * scale), in: context,
                                  scale: scale)
                }
                let text = "\(kind.name), \(isAlchemy ? "Alchemy" : "Industrial"), \(String(describing: cell.civilization).capitalized), "
                    + (cell.complete ? "complete" : "building")
                Preview.label(text, in: context, at: CGPoint(x: Double(column * cellW + 10), y: Double(top - label + 6)), size: 16)
            }
        }
        return context.makeImage()
    }

    /// An Industrial-age town at game size on the ground: the town hall amid
    /// houses, the warehouse, the pen, the drill hall, farms, the stable, the
    /// works, the castle and the chemical works, a lookout, a palisade and a
    /// stone wall, with a house, a lookout and a farm still being built.
    static func scene() -> CGImage? {
        let terrain = TerrainSprites()
        let size = 24, width = size * 128, height = size * 64 + 260
        guard let context = Raster.bitmap(width: width, height: height) else { return nil }
        context.setFillColor(rgb("#9aa59a"))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        func screen(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: Double(width) / 2 + (x - y) * 64, y: Double(height) - 240 - (x + y) * 32)
        }
        for y in 0..<size {
            for x in 0..<size {
                let path = y == 10 || (x == 10 && y >= 3 && y <= 19)
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
            Placed(kind: .watchTower, x: 9, y: 2, complete: false, civilization: .rome),
            Placed(kind: .watchTower, x: 15, y: 9, complete: true, civilization: .rome),
            Placed(kind: .farm, x: 2, y: 8, complete: true, civilization: .rome),
            Placed(kind: .farm, x: 2, y: 12, complete: false, civilization: .rome),
            Placed(kind: .stable, x: 7, y: 14, complete: true, civilization: .rome),
            Placed(kind: .castle, x: 17, y: 2, complete: true, civilization: .rome),
            Placed(kind: .castle, x: 18, y: 16, complete: false, civilization: .shang),
            Placed(kind: .house, x: 19, y: 11, complete: true, civilization: .olmec),
            Placed(kind: .barracks, x: 1, y: 3, complete: true, civilization: .shang),
            Placed(kind: .stable, x: 19, y: 7, complete: true, civilization: .angkor),
        ]
        func depth(_ p: Placed) -> Double {
            let f = Catalogue.standard.stats(p.kind).footprint
            return Double(p.x) + Double(p.y) + Double(f.x + f.y) / 2
        }
        for p in placed.sorted(by: { depth($0) < depth($1) }) {
            let f = Catalogue.standard.stats(p.kind).footprint
            let key = SpriteKey(.building(p.kind, .industrial), p.complete ? .complete : .underConstruction)
            guard let sprite = industrial.sprite(key) else { continue }
            let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: TeamColour.of(p.civilization))
            Preview.place(image, anchor: sprite.anchor,
                          at: screen(Double(p.x) + Double(f.x) / 2, Double(p.y) + Double(f.y) / 2), in: context)
        }
        return context.makeImage()
    }

    /// A building drawn three times larger than in the game, tinted in Rome's colour, for close inspection.
    static func enlarged(_ kind: BuildingKind, complete: Bool) -> CGImage? {
        guard let drawn = IndustrialOldBuildingsArt.draw(kind, complete: complete, pixelsPerUnit: 6) else { return nil }
        let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: TeamColour.of(.rome))
        guard let context = Raster.bitmap(width: image.width, height: image.height) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        field(context, rect, colour: "#c2683c", joints: "#b45e34")
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
