// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore
import Synchronization

/// The fruit bush (`SiteKind.fruit`, ruled 2026-11-22), drawn in each of the
/// five looks in the Cartoon Modern style of docs/art-style.md: a wild bramble
/// in the Stone look, a pomegranate in its basin in the Bronze, a cornel cherry
/// kerbed with stone in the Iron, a bush vine in the Alchemy and a staked
/// gooseberry in the Industrial (`FruitBushesLooks.swift`).
///
/// A site has no owner, so the bush is seen in the look of the age of the
/// player who sees it: the drawing asks for it in the pose
/// `SpritePose.complete(in:)` of that look, at frame 0 (`SiteKind.isDrawnInEachLook`).
/// The pose `complete` gives the Stone look, for whatever asks without a look.
/// The bush stands still, as the tree does, and carries no team's colour, so
/// it has no mask. It stands on the centre of its tile, about a worker's
/// height, on the canvas of the other sites; each picture is written as SVG,
/// drawn by macOS and grained by Core Image, when first asked for, and kept.
public final class FruitBushSprites: SpriteSource {
    /// Every key this source supplies: the bush in each look, and `complete`.
    public static let keys: [SpriteKey] = Look.allCases.map { SpriteKey(.site(.fruit), .complete(in: $0)) }
        + [SpriteKey(.site(.fruit), .complete)]

    private let cache = Mutex<[Look: SpriteImage]>([:])

    public init() {}

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let look = Self.look(of: key) else { return nil }
        if let known = cache.withLock({ $0[look] }) { return known }
        guard let drawn = Self.draw(look) else { return nil }
        return cache.withLock { cache in
            if let known = cache[look] { return known }
            cache[look] = drawn
            return drawn
        }
    }

    /// The look a key of this batch shows; nil for a key that is not one.
    static func look(of key: SpriteKey) -> Look? {
        guard key.subject == .site(.fruit), key.frame == 0, key.view == .side else { return nil }
        if key.pose == .complete { return .stone }
        return Look.allCases.first { key.pose == .complete(in: $0) }
    }

    /// The bush in a look drawn afresh, without the cache: at the game's two
    /// pixels a point unless another scale is asked for (to look closely).
    static func draw(_ look: Look, pixelsPerPoint: Double = 2) -> SpriteImage? {
        let canvas = FruitBushPainter.canvas.scaled(to: pixelsPerPoint)
        var svg = SVG(layer: .base)
        FruitBushPainter.draw(look, &svg)
        guard let context = Raster.draw(svg.document(canvas), on: canvas) else { return nil }
        if let grain = Grain.image(width: canvas.pixelWidth, height: canvas.pixelHeight) { Raster.grain(context, with: grain) }
        guard let image = context.makeImage() else { return nil }
        return SpriteImage(base: image, teamMask: nil, anchor: canvas.anchor)
    }
}
