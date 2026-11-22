// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// Renders the fruit bush for a person to judge, into the directory named by
/// the environment variable `FRUIT_BUSHES_RENDERS`; skipped when it is not set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FRUIT_BUSHES_RENDERS"] != nil))
struct FruitBushesRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FRUIT_BUSHES_RENDERS"] ?? "/", isDirectory: true)

    private static func caption(_ look: Look) -> String {
        switch look {
        case .stone: "a wild bramble, blackberries ripe and red"
        case .bronze: "a pomegranate in its watering basin"
        case .iron: "a cornel cherry, clipped and kerbed with stone"
        case .alchemy: "a vine trained as a bush, its grapes in bunches"
        case .industrial: "a gooseberry, staked and labelled in its bed"
        }
    }

    /// One animated GIF per look at 12 frames a second: the bush's one pose,
    /// still as the tree is, drawn large on a patch of ground, and beside it the
    /// sprite itself at game size, next to a Stone worker in Sumer's colour.
    @Test func animations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = FruitBushSprites()
        let worker = try #require(CartoonSprites().sprite(SpriteKey(.unit(.worker, .stone), .standing)))
        let colour = TeamColour.of(.sumer)
        let width = 1100, height = 560, groundLine = 110.0, scale = 6.0
        let ground = Preview.ground(width: width, height: height, tile: 384, grained: false)
        for look in Look.allCases {
            let big = try #require(FruitBushSprites.draw(look, pixelsPerPoint: scale))
            let small = try #require(sprites.sprite(SpriteKey(.site(.fruit), .complete(in: look))))
            var frames: [CGImage] = []
            for frame in 0..<SpriteKey.framesPerPose {
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                Preview.place(big.base, anchor: big.anchor, at: CGPoint(x: 360, y: groundLine), in: context)
                Preview.place(small.base, anchor: small.anchor, at: CGPoint(x: 860, y: groundLine), in: context)
                let person = Preview.tinted(base: worker.base, mask: worker.teamMask, colour: colour)
                Preview.place(person, anchor: worker.anchor, at: CGPoint(x: 960, y: groundLine), in: context)
                Preview.label("The fruit bush, \(look.name) age", in: context, at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                Preview.label(Self.caption(look) + "; standing still, as the tree does, frame \(frame) of 12",
                              in: context, at: CGPoint(x: 28, y: 28), size: 20)
                Preview.label("at game size, beside a worker", in: context, at: CGPoint(x: 790, y: 70), size: 18)
                frames.append(context.makeImage()!)
            }
            try Preview.writeGIF(frames, to: directory.appendingPathComponent("fruit-bush-\(look.name.lowercased()).gif"))
        }
    }

    /// Every look in one sheet: drawn large in a row, and beneath each the
    /// sprite at game size between a Stone worker and a tree.
    @Test func sheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = FruitBushSprites()
        let worker = try #require(CartoonSprites().sprite(SpriteKey(.unit(.worker, .stone), .standing)))
        let tree = try #require(TerrainSprites().sprite(SpriteKey(.site(.tree), .complete)))
        let person = Preview.tinted(base: worker.base, mask: worker.teamMask, colour: TeamColour.of(.sumer))
        let column = 440, width = column * Look.allCases.count, height = 900
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false),
                     in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The fruit bush in the five looks: drawn large, and at game size between a worker and a tree",
                      in: context, at: CGPoint(x: 24, y: Double(height) - 48), size: 26)
        for (i, look) in Look.allCases.enumerated() {
            let left = Double(i * column)
            Preview.label(look.name, in: context, at: CGPoint(x: left + 24, y: Double(height) - 100), size: 24)
            let big = try #require(FruitBushSprites.draw(look, pixelsPerPoint: 5))
            Preview.place(big.base, anchor: big.anchor, at: CGPoint(x: left + Double(column) / 2, y: 330), in: context)
            Preview.label(Self.caption(look), in: context, at: CGPoint(x: left + 24, y: 240), size: 15)
            let small = try #require(sprites.sprite(SpriteKey(.site(.fruit), .complete(in: look))))
            Preview.place(person, anchor: worker.anchor, at: CGPoint(x: left + 110, y: 70), in: context)
            Preview.place(small.base, anchor: small.anchor, at: CGPoint(x: left + 220, y: 70), in: context)
            Preview.place(tree.base, anchor: tree.anchor, at: CGPoint(x: left + 340, y: 70), in: context)
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("fruit-bush-sheet.png"))
    }
}
