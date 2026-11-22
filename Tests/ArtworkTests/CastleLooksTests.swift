// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The castle in its three looks, the Iron (the fort of the legions), the
/// Alchemy and the Industrial: each drawn by its own batch, all three the same
/// size on the same anchor.
@Suite struct CastleLooksTests {
    static let looks: [Look] = [.iron, .alchemy, .industrial]

    /// The castle is drawn in each look of the ages that have it, by the batch
    /// approved for that look, and in no look as another (`StandIn`).
    @Test func eachLookOfTheCastleIsItsOwn() throws {
        let sprites = GameSprites()
        for age in Age.allCases where age >= Catalogue.standard.stats(.castle).age {
            #expect(SpriteSubject.of(.building(.castle), ownerAge: age) == .building(.castle, age.look))
        }
        let iron = IronNewBuildingSprites(), alchemy = AlchemyNewBuildingSprites(), industrial = IndustrialOldBuildingSprites()
        for pose in [SpritePose.complete, .underConstruction] {
            let own: [(Look, any SpriteSource)] = [(.iron, iron), (.alchemy, alchemy), (.industrial, industrial)]
            var bytes: [Data] = []
            for (look, batch) in own {
                let key = SpriteKey(.building(.castle, look), pose)
                let sprite = try #require(batch.sprite(key), "\(key)")
                let drawn = try #require(sprites.sprite(key), "\(key)")
                let data = try #require(sprite.base.dataProvider?.data as Data?)
                #expect(data == drawn.base.dataProvider?.data as Data?, "\(key) is not its batch's")
                bytes.append(data)
            }
            // The Iron look is not the Alchemy look drawn again.
            #expect(bytes[0] != bytes[1])
        }
    }

    /// The three looks share the canvas and the anchor, so that the castle
    /// keeps its size and place from one age to the next; the Iron fort stands
    /// lower than the later castles, but not much.
    @Test func theLooksAreTheSameSize() throws {
        var tops: [Look: Int] = [:]
        var first: SpriteImage?
        for look in Self.looks {
            let sprite = try #require(GameSprites().sprite(SpriteKey(.building(.castle, look), .complete)))
            if let first {
                #expect(sprite.base.width == first.base.width && sprite.base.height == first.base.height, "\(look)")
                #expect(sprite.anchor == first.anchor, "\(look)")
            }
            first = first ?? sprite
            tops[look] = try #require(CastlePixels(sprite.base).top(alphaAbove: 128))
        }
        let anchorRow = Int((1 - (first?.anchor.y ?? 0)) * Double(first?.base.height ?? 0))
        let rise = tops.mapValues { anchorRow - $0 }
        let iron = try #require(rise[.iron]), alchemy = try #require(rise[.alchemy])
        #expect(iron <= alchemy, "the Iron fort rises \(iron) pixels, the Alchemy castle \(alchemy)")
        #expect(Double(iron) >= 0.7 * Double(alchemy), "the Iron fort rises \(iron) pixels, the Alchemy castle \(alchemy)")
    }

    /// The Iron castle, complete and being built, carries enough of the
    /// owner's colour to be seen at game size.
    @Test func theIronCastleCarriesTeamColour() throws {
        for pose in [SpritePose.complete, .underConstruction] {
            let sprite = try #require(IronNewBuildingSprites().sprite(SpriteKey(.building(.castle, .iron), pose)))
            let mask = try #require(sprite.teamMask)
            let pixels = CastlePixels(mask)
            var coloured = 0
            for y in 0..<pixels.height { for x in 0..<pixels.width where pixels.alpha(x, y) > 200 { coloured += 1 } }
            #expect(coloured >= 400, "only \(coloured) pixels of team colour in the \(pose) castle")
        }
    }
}

/// An image's pixels, premultiplied RGBA, the top row first.
private struct CastlePixels {
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

    /// The topmost row holding a pixel more opaque than `alphaAbove`.
    func top(alphaAbove threshold: UInt8) -> Int? {
        for y in 0..<height { for x in 0..<width where alpha(x, y) > threshold { return y } }
        return nil
    }
}

/// The pictures for the person's ruling, written to the directory named by the
/// environment variable `CASTLE_RENDERS`; skipped when it is not set: for each
/// look, an animated GIF of the castle complete and then under construction,
/// at 12 frames a second, drawn large in Sumer's colour with the sprite at game
/// size beside it, and a still sheet of both poses; and a sheet of the three
/// looks side by side at game size.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["CASTLE_RENDERS"] != nil))
struct CastleLooksRenders {
    let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CASTLE_RENDERS"] ?? "/", isDirectory: true)
    let sprites = GameSprites()

    static func name(_ look: Look) -> String {
        switch look {
        case .iron: "Iron"
        case .alchemy: "Alchemy"
        case .industrial: "Industrial"
        default: "\(look)"
        }
    }

    /// The castle in `look` drawn at `pixelsPerUnit`, by the painter its batch uses.
    static func drawn(_ look: Look, complete: Bool, pixelsPerUnit: Double) -> Rendered? {
        let canvas = AlchemyNewBuildingsArt.canvas(.castle).scaled(to: pixelsPerUnit)
        switch look {
        case .iron:
            return Raster.render(on: canvas) { svg in
                var painter = IronOldBuildingsPainter(layer: svg.layer)
                painter.castle(complete: complete)
                svg = painter.svg
            }
        case .alchemy:
            return Raster.render(on: canvas) { svg in
                var painter = AlchemyNewBuildingsPainter(layer: svg.layer)
                painter.building(.castle, complete: complete)
                svg = painter.svg
            }
        case .industrial:
            return IndustrialOldBuildingsArt.draw(.castle, complete: complete, pixelsPerUnit: pixelsPerUnit)
        default:
            return nil
        }
    }

    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let colour = TeamColour.of(.sumer)
        let width = 1640, height = 1120, groundLine = 280.0, scale = 3.4
        let ground = Preview.ground(width: width, height: height, tile: 256, grained: false)
        let large = AlchemyNewBuildingsArt.canvas(.castle).scaled(to: scale)
        for look in CastleLooksTests.looks {
            var frames: [CGImage] = []
            for complete in [true, false] {
                let drawn = try #require(Self.drawn(look, complete: complete, pixelsPerUnit: scale))
                let big = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                let pose: SpritePose = complete ? .complete : .underConstruction
                let sprite = try #require(sprites.sprite(SpriteKey(.building(.castle, look), pose)))
                let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                for _ in 0..<SpriteKey.framesPerPose * 2 {
                    let context = Raster.bitmap(width: width, height: height)!
                    context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                    Preview.place(big, anchor: large.anchor, at: CGPoint(x: 500, y: groundLine), in: context)
                    Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: 1320, y: groundLine + 120), in: context)
                    Preview.label("Castle, \(Self.name(look)) look, in Sumer's colour", in: context,
                                  at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                    Preview.label((complete ? "complete" : "under construction") + ", 12 frames a second (a building is still)",
                                  in: context, at: CGPoint(x: 28, y: 28), size: 22)
                    Preview.label("at game size", in: context, at: CGPoint(x: 1260, y: 60), size: 18)
                    frames.append(context.makeImage()!)
                }
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("castle-\(look).gif"))
        }
    }

    /// For each look, both poses drawn large in Sumer's colour, with the
    /// sprites at game size under them.
    @Test func sheets() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scale = 3.0, large = AlchemyNewBuildingsArt.canvas(.castle).scaled(to: scale)
        let column = Int(large.width * large.pixelsPerUnit) + 60
        let width = column * 2 + 40, height = Int(large.height * large.pixelsPerUnit) + 640
        for look in CastleLooksTests.looks {
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(Preview.ground(width: width, height: height, tile: 256),
                         in: CGRect(x: 0, y: 0, width: width, height: height))
            Preview.label("Castle, \(Self.name(look)) look: complete and under construction", in: context,
                          at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
            for (i, complete) in [true, false].enumerated() {
                let x = 20 + Double(i * column) + Double(column) / 2
                let drawn = try #require(Self.drawn(look, complete: complete, pixelsPerUnit: scale))
                Preview.place(Preview.tinted(base: drawn.base, mask: drawn.mask, colour: .of(.sumer)), anchor: large.anchor,
                              at: CGPoint(x: x, y: 640), in: context)
                Preview.label(complete ? "complete" : "under construction", in: context,
                              at: CGPoint(x: x - Double(column) / 2 + 20, y: Double(height) - 100), size: 22)
                let key = SpriteKey(.building(.castle, look), complete ? .complete : .underConstruction)
                let sprite = try #require(sprites.sprite(key))
                Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer)),
                              anchor: sprite.anchor, at: CGPoint(x: x, y: 170), in: context)
                Preview.label("at game size", in: context, at: CGPoint(x: x + 250, y: 60), size: 18)
            }
            try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("castle-\(look)-sheet.png"))
        }
        // The line of the castle: the three looks side by side at game size.
        let lineWidth = 3 * 600 + 40, lineHeight = 1900
        let context = Raster.bitmap(width: lineWidth, height: lineHeight)!
        context.draw(Preview.ground(width: lineWidth, height: lineHeight, tile: 128),
                     in: CGRect(x: 0, y: 0, width: lineWidth, height: lineHeight))
        Preview.label("The castle's line at game size, in Sumer's colour and then Egypt's", in: context,
                      at: CGPoint(x: 28, y: Double(lineHeight) - 52), size: 24)
        for (i, look) in CastleLooksTests.looks.enumerated() {
            let x = 20 + Double(i) * 600 + 300
            let rows: [(SpritePose, Civilization)] = [(.complete, .sumer), (.underConstruction, .sumer), (.complete, .egypt)]
            for (r, (pose, civilization)) in rows.enumerated() {
                let sprite = try #require(sprites.sprite(SpriteKey(.building(.castle, look), pose)))
                Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(civilization)), anchor: sprite.anchor,
                              at: CGPoint(x: x, y: Double(lineHeight) - 560 - Double(r) * 560), in: context)
            }
            Preview.label(Self.name(look), in: context, at: CGPoint(x: x - 280, y: Double(lineHeight) - 100), size: 22)
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("castle-line.png"))
    }
}
