// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore
import Synchronization

/// The ground, the resource sites and the outcrop, drawn in the Cartoon Modern
/// style of docs/art-style.md with the Stone age's palette.
///
/// - Every `Terrain`, in `variantCount` variants, so that neighbouring tiles
///   differ (`SpriteSubject.terrain`). A tile is the map's diamond, 64 by 32
///   points, its ground drawn a little beyond the diamond's edges so that
///   neighbours overlap and no seam shows between them (`tileCanvas`).
/// - Every site on land (`SpriteSubject.site`): a tree, prey and gold,
///   standing on the centre of its tile.
/// - The outcrop (`SpriteSubject.outcrop`): plain rock, darker and lower than
///   a gold mine.
///
/// Each is drawn in the pose `complete`, at frame 0; every other key returns
/// `nil`. None carries a team's colour, so none has a mask. Each picture is
/// written as SVG, drawn by macOS and grained by Core Image (docs/decisions.md,
/// "Verifications"); it is drawn when first asked for, and kept.
public final class TerrainSprites: SpriteSource {
    /// The variants of each terrain, numbered from 0.
    public static let variantCount = 4

    /// Every key this source supplies.
    public static let keys: [SpriteKey] = {
        var keys: [SpriteKey] = []
        for terrain in Terrain.allCases {
            for variant in 0..<variantCount { keys.append(SpriteKey(.terrain(terrain, variant: variant), .complete)) }
        }
        for kind in SiteKind.allCases where kind != .fish && StandIn.site(kind) == kind { keys.append(SpriteKey(.site(kind), .complete)) }
        keys.append(SpriteKey(.outcrop, .complete))
        return keys
    }()

    private let cache = Mutex<[SpriteKey: SpriteImage]>([:])

    public init() {}

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard Self.supplies(key) else { return nil }
        if let known = cache.withLock({ $0[key] }) { return known }
        guard let drawn = Self.draw(key.subject) else { return nil }
        return cache.withLock { cache in
            if let known = cache[key] { return known }
            cache[key] = drawn
            return drawn
        }
    }

    /// Whether the key is one of this batch's.
    static func supplies(_ key: SpriteKey) -> Bool {
        guard key.pose == .complete, key.frame == 0 else { return false }
        switch key.subject {
        case .terrain(_, let variant): return (0..<variantCount).contains(variant)
        // The fish: drawn by `StoneBoatSprites`; the fruit bush: by none, as its stand-in (`StandIn.site`).
        case .site(let kind): return kind != .fish && StandIn.site(kind) == kind
        case .outcrop: return true
        case .unit, .building: return false
        }
    }

    /// A subject of this batch drawn afresh, without the cache: at the game's
    /// two pixels a point unless another scale is asked for (to look closely).
    static func draw(_ subject: SpriteSubject, pixelsPerPoint: Double = 2) -> SpriteImage? {
        guard let canvas = canvas(for: subject)?.scaled(to: pixelsPerPoint) else { return nil }
        let grain: CGImage?
        if case .terrain(let terrain, let variant) = subject {
            grain = tileGrain(terrain.rawValue * variantCount + variant, canvas: canvas)
        } else {
            grain = Grain.image(width: canvas.pixelWidth, height: canvas.pixelHeight)
        }
        guard let image = picture(on: canvas, grain: grain, { svg in sketch(subject, &svg) }) else { return nil }
        return SpriteImage(base: image, teamMask: nil, anchor: canvas.anchor)
    }

    /// The canvas of a subject of this batch, in points: its size, and its
    /// anchor at the tile's centre on the ground. Nil for any other subject.
    static func canvas(for subject: SpriteSubject) -> Canvas? {
        switch subject {
        case .terrain(_, let variant): (0..<variantCount).contains(variant) ? tileCanvas : nil
        case .site(.tree): treeCanvas
        case .site: siteCanvas
        case .outcrop: siteCanvas
        case .unit, .building: nil
        }
    }

    /// The SVG of a subject of this batch.
    static func sketch(_ subject: SpriteSubject, _ svg: inout SVG) {
        switch subject {
        case .terrain(let terrain, let variant): drawTile(terrain, variant: variant, &svg)
        case .site(let kind): drawSite(kind, &svg)
        case .outcrop: drawOutcrop(&svg)
        case .unit, .building: break
        }
    }

    /// A picture drawn by macOS from one SVG routine, with the grain laid over
    /// what is drawn. Nothing here carries a team's colour, so no mask is drawn.
    static func picture(on canvas: Canvas, grain: CGImage?, _ draw: (inout SVG) -> Void) -> CGImage? {
        var svg = SVG(layer: .base)
        draw(&svg)
        guard let context = Raster.draw(svg.document(canvas), on: canvas) else { return nil }
        if let grain { Raster.grain(context, with: grain) }
        return context.makeImage()
    }
}

/// The colours of the ground and the sites: the Stone age's palette
/// (docs/art-style.md, "Palettes") and shades of it, with the few colours of
/// the metals, which no age's palette holds.
enum TerrainInk {
    // The palette.
    static let line = Ink.line
    static let lilac = Ink.ground
    static let hide = Ink.hide
    static let moss = Ink.moss
    static let light = Ink.light

    // The ground of each terrain. Open grass is the palette's ground, the dusk lilac.
    static let grass = Ink.ground
    static let forest = "#7f9150"
    static let dirt = "#b07f58"
    static let sand = "#e4d0a8"
    static let shallowWater = "#93a5c4"
    static let deepWater = "#5c6a90"

    // Marks on the ground.
    static let grassTuft = "#7e8a52"
    static let grassShade = "#958898"
    static let forestShade = "#68783f"
    static let forestLeaf = "#a07a4c"
    static let dirtShade = "#9a6c48"
    static let sandShade = "#cdb487"
    static let shallowLight = "#e6e8ee"
    static let shallowShade = "#8193b4"
    static let deepLight = "#a0add0"
    static let deepShade = "#525f84"

    // Trees.
    static let needlesLit = "#6f8746"
    static let needlesShade = "#4f6435"
    static let bark = Ink.wood

    // The outcrop.
    static let outcropTop = "#776c72"
    static let outcropLit = "#665c62"
    static let outcropShade = "#4f474c"

    // Gold: dark warm rock with yellow veins and nuggets.
    static let goldTop = "#9a7c5c"
    static let goldLit = "#836447"
    static let goldShade = "#634a35"
    static let gold = "#f0c240"
    static let goldGlint = "#fde69c"

    // Prey.
    static let deerHide = Ink.hide
    static let deerSpot = Ink.light
}
