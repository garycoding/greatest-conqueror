// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore

// The ground: one diamond of the map for each terrain and variant, in flat
// colour with a few marks, and the grain over it. Units are points, with the
// origin at the tile's centre and y running downward, as SVG has it.

extension TerrainSprites {
    /// A tile: the map's diamond, 64 by 32 points (`Projection.tileWidth` and
    /// `tileHeight`), with its ground drawn a little beyond its edges (`spread`),
    /// at two pixels a point, its centre at the image's centre. The image is
    /// the enlarged diamond's box, 68 by 34 points: the drawing takes a tile's
    /// size from its image and centres it on the tile, so that neighbours
    /// overlap by the spread and no seam shows between them, as MapDrawing's
    /// placeholder tiles do. A box of the tile's own size would cut the spread
    /// off at its corners and notch the map's outer edge at every tile.
    static let tileCanvas = Canvas(minX: -34, minY: -17, width: 68, height: 34, pixelsPerUnit: 2)

    /// How much larger than the tile's diamond its ground is drawn: 17/16, the
    /// diamond enlarged about its centre until its edges lie 0.89 points beyond
    /// the tile's (14.31 points, the distance from the centre to an edge, times
    /// 1/16), past the half-covered pixels of its own edge. Where two tiles
    /// meet, each is then fully opaque up to and over the line between them.
    static let spread = 17.0 / 16.0

    /// The ground's colour for each terrain: the same in every variant, so that
    /// tiles of one terrain run together without a visible edge.
    static func ground(_ terrain: Terrain) -> String {
        switch terrain {
        case .grass: TerrainInk.grass
        case .dirt: TerrainInk.dirt
        case .sand: TerrainInk.sand
        case .forest: TerrainInk.forest
        case .shallowWater: TerrainInk.shallowWater
        case .deepWater: TerrainInk.deepWater
        }
    }

    /// The grain of one tile: a piece of a larger sheet of the same grain, a
    /// different piece for each terrain and variant, so that the speckles do not
    /// repeat in step with the tiles.
    static func tileGrain(_ index: Int, canvas: Canvas) -> CGImage? {
        let width = canvas.pixelWidth, height = canvas.pixelHeight, side = max(512, 2 * width)
        guard let sheet = Grain.image(width: side, height: side) else { return nil }
        let x = (index * 157) % (side - width), y = (index * 89) % (side - height)
        return sheet.cropping(to: CGRect(x: x, y: y, width: width, height: height))
    }

    /// The tile in SVG: the ground, then the marks, each well inside the diamond
    /// so that no neighbour's ground cuts one.
    static func drawTile(_ terrain: Terrain, variant: Int, _ svg: inout SVG) {
        let s = spread
        svg.polygon([P(0, -16 * s), P(32 * s, 0), P(0, 16 * s), P(-32 * s, 0)], fill: .colour(ground(terrain)))
        var scatter = TerrainScatter(seed: UInt64(1 + terrain.rawValue * variantCount + variant))
        switch terrain {
        case .grass: grassMarks(variant, &scatter, &svg)
        case .dirt: dirtMarks(variant, &scatter, &svg)
        case .sand: sandMarks(variant, &scatter, &svg)
        case .forest: forestMarks(variant, &scatter, &svg)
        case .shallowWater: shallowMarks(variant, &scatter, &svg)
        case .deepWater: deepMarks(variant, &scatter, &svg)
        }
    }

    // MARK: Each terrain's marks

    /// Open grass: the dusk lilac, with tufts of moss and, on some tiles, a few
    /// small pale flowers or a pebble.
    private static func grassMarks(_ variant: Int, _ scatter: inout TerrainScatter, _ svg: inout SVG) {
        for _ in 0..<(3 + variant % 2) {
            tuft(&svg, at: scatter.point(), size: scatter.between(0.75, 1.1), colour: TerrainInk.grassTuft)
        }
        switch variant {
        case 1: flowers(&svg, at: scatter.point(), scatter: &scatter)
        case 2: pebble(&svg, at: scatter.point(), rx: 1.5, ry: 0.95, fill: TerrainInk.grassShade)
        case 3:
            flowers(&svg, at: scatter.point(), scatter: &scatter)
            shadow(&svg, at: scatter.point(), rx: 4.5, ry: 1.6, colour: TerrainInk.grassShade)
        default: shadow(&svg, at: scatter.point(), rx: 5, ry: 1.8, colour: TerrainInk.grassShade)
        }
    }

    /// The forest's floor: moss, with fallen leaves, tufts and now and then a twig.
    private static func forestMarks(_ variant: Int, _ scatter: inout TerrainScatter, _ svg: inout SVG) {
        for _ in 0..<(2 + variant % 2) {
            leaf(&svg, at: scatter.point(), angle: scatter.between(-50, 50), colour: TerrainInk.forestLeaf)
        }
        for _ in 0..<2 { tuft(&svg, at: scatter.point(), size: scatter.between(0.8, 1.1), colour: TerrainInk.forestShade) }
        if variant == 0 || variant == 2 { twig(&svg, at: scatter.point(), angle: scatter.between(-20, 20)) }
        if variant == 3 { shadow(&svg, at: scatter.point(), rx: 5, ry: 1.8, colour: TerrainInk.forestShade) }
    }

    /// Bare earth: the hide's brown, with pebbles, a crack and a clod or two.
    private static func dirtMarks(_ variant: Int, _ scatter: inout TerrainScatter, _ svg: inout SVG) {
        for _ in 0..<(2 + variant % 2) {
            let rx = scatter.between(1.2, 1.9)
            pebble(&svg, at: scatter.point(), rx: rx, ry: rx * 0.62, fill: TerrainInk.sand)
        }
        if variant != 1 { crack(&svg, at: scatter.point(spacing: 11), length: scatter.between(7, 10), scatter: &scatter) }
        for _ in 0..<(1 + variant % 3) {
            shadow(&svg, at: scatter.point(), rx: scatter.between(1.4, 2.4), ry: 0.9, colour: TerrainInk.dirtShade)
        }
    }

    /// Sand: the light, warmed, with ripples blown into it and a few grains.
    private static func sandMarks(_ variant: Int, _ scatter: inout TerrainScatter, _ svg: inout SVG) {
        for _ in 0..<(1 + variant % 2) {
            ripple(&svg, at: scatter.point(spacing: 11), width: scatter.between(7, 10), colour: TerrainInk.sandShade)
        }
        for _ in 0..<(4 + variant % 3) {
            svg.circle(scatter.point(spacing: 5), scatter.between(0.4, 0.6), fill: .colour(TerrainInk.sandShade))
        }
        if variant == 2 { pebble(&svg, at: scatter.point(), rx: 1.4, ry: 0.9, fill: TerrainInk.light) }
    }

    /// Shallow water: a pale blue of the dusk, with the light's waves on it and
    /// stones showing through.
    private static func shallowMarks(_ variant: Int, _ scatter: inout TerrainScatter, _ svg: inout SVG) {
        for _ in 0..<(1 + variant % 2) {
            let at = scatter.point(spacing: 10)
            svg.ellipse(at, scatter.between(1.4, 2.2), 0.9, fill: .colour(TerrainInk.shallowShade))
        }
        for _ in 0..<2 {
            wave(&svg, at: scatter.point(margin: 0.24, spacing: 12), width: scatter.between(7, 9), colour: TerrainInk.shallowLight)
        }
    }

    /// Deep water: the dusk's blue, darker, with longer, fainter waves.
    private static func deepMarks(_ variant: Int, _ scatter: inout TerrainScatter, _ svg: inout SVG) {
        for _ in 0..<(1 + variant % 2) {
            wave(&svg, at: scatter.point(margin: 0.25, spacing: 13), width: scatter.between(9, 12), colour: TerrainInk.deepLight)
        }
        wave(&svg, at: scatter.point(margin: 0.25, spacing: 13), width: scatter.between(7, 9), colour: TerrainInk.deepShade,
             line: 1)
    }
}

extension TerrainSprites {
    // MARK: The marks

    /// A tuft of grass: four blades curving up and outward from a short base.
    private static func tuft(_ svg: inout SVG, at p: P, size s: Double, colour: String) {
        var d = PathData()
        let blades: [(Double, P)] = [(-1.6, P(-3, -2.4)), (-0.5, P(-0.9, -3.6)), (0.6, P(1.1, -3.3)), (1.6, P(3, -2))]
        for (foot, tip) in blades {
            let base = p + P(foot * s, 0), end = p + tip * s
            d.move(base)
            d.quad(P(base.x + (end.x - base.x) * 0.15, base.y + (end.y - base.y) * 0.65), end)
        }
        svg.path(d, stroke: .colour(colour), width: 0.75)
    }

    /// Three small pale flowers with the hide's colour at their hearts.
    private static func flowers(_ svg: inout SVG, at p: P, scatter: inout TerrainScatter) {
        for offset in [P(-1.8, 0.4), P(0.6, -0.8), P(1.9, 0.9)] {
            let at = p + offset + P(scatter.between(-0.3, 0.3), scatter.between(-0.2, 0.2))
            svg.circle(at, 0.85, fill: .colour(TerrainInk.light))
            svg.circle(at, 0.3, fill: .colour(TerrainInk.hide))
        }
    }

    /// A pebble: its colour a little out of register with its line.
    private static func pebble(_ svg: inout SVG, at p: P, rx: Double, ry: Double, fill: String) {
        svg.ellipse(p + P(-0.35, 0.3), rx, ry, fill: .colour(fill))
        svg.ellipse(p, rx, ry, fill: .none, stroke: .colour(TerrainInk.line), width: 0.5, opacity: 0.7)
    }

    /// A soft patch of a deeper shade of the ground.
    private static func shadow(_ svg: inout SVG, at p: P, rx: Double, ry: Double, colour: String) {
        svg.ellipse(p, rx, ry, fill: .colour(colour), opacity: 0.7)
    }

    /// A crack in dry earth: a jagged line with a short branch.
    private static func crack(_ svg: inout SVG, at p: P, length: Double, scatter: inout TerrainScatter) {
        let half = length / 2
        var d = PathData()
        d.move(p + P(-half, scatter.between(-0.6, 0.6)))
        d.line(p + P(-half / 3, -1))
        d.line(p + P(half / 3, 0.7))
        d.line(p + P(half, scatter.between(-0.8, 0)))
        d.move(p + P(half / 3, 0.7))
        d.line(p + P(half / 3 + 1.6, 2))
        svg.path(d, stroke: .colour(TerrainInk.dirtShade), width: 0.7)
    }

    /// A ripple blown into sand: a shallow arch.
    private static func ripple(_ svg: inout SVG, at p: P, width: Double, colour: String) {
        var d = PathData()
        d.move(p + P(-width / 2, 0.7))
        d.quad(p + P(0, -1.3), p + P(width / 2, 0.7))
        svg.path(d, stroke: .colour(colour), width: 0.8)
    }

    /// A wave on water, as the reference scene draws it: a line with two crests.
    private static func wave(_ svg: inout SVG, at p: P, width: Double, colour: String, line: Double = 0.85) {
        let q = width / 4
        var d = PathData()
        d.move(p + P(-2 * q, 0))
        d.quad(p + P(-1.5 * q, -1.3), p + P(-q, 0))
        d.quad(p + P(-0.5 * q, 1.3), p + P(0, 0))
        d.quad(p + P(0.5 * q, -1.3), p + P(q, 0))
        d.quad(p + P(1.5 * q, 1.3), p + P(2 * q, 0))
        svg.path(d, stroke: .colour(colour), width: line)
    }

    /// A fallen leaf, with its midrib.
    private static func leaf(_ svg: inout SVG, at p: P, angle: Double, colour: String) {
        svg.group(at: p, turned: angle) { svg in
            svg.ellipse(P(0, 0), 1.7, 0.75, fill: .colour(colour))
            svg.line([P(-1.9, 0), P(1.5, 0)], stroke: .colour(TerrainInk.line), width: 0.4, opacity: 0.55)
        }
    }

    /// A fallen twig with one short branch.
    private static func twig(_ svg: inout SVG, at p: P, angle: Double) {
        svg.group(at: p, turned: angle) { svg in
            svg.line([P(-4, 0.4), P(0, -0.2), P(4, 0.3)], stroke: .colour(TerrainInk.bark), width: 0.8)
            svg.line([P(0.8, -0.2), P(2.4, -1.6)], stroke: .colour(TerrainInk.bark), width: 0.6)
        }
    }
}

/// Where on a tile its marks go: points spread evenly over the diamond, at a
/// distance from its edges and from one another, from a seeded sequence so
/// that the same tile is always drawn the same way.
struct TerrainScatter {
    private var generator: SeededGenerator
    private var placed: [P] = []

    init(seed: UInt64) { generator = SeededGenerator(seed: seed) }

    /// A number from 0 up to 1, from the top 53 bits of the sequence.
    mutating func unit() -> Double { Double(generator.next() >> 11) / 9_007_199_254_740_992 }

    mutating func between(_ low: Double, _ high: Double) -> Double { low + (high - low) * unit() }

    /// A point of the diamond. `margin` is the share of the tile's side kept
    /// clear along each edge (0.2 is about 5.7 points); `spacing` is the least
    /// distance from the points already given, kept where 40 tries allow.
    mutating func point(margin: Double = 0.2, spacing: Double = 9) -> P {
        var chosen = P(0, 0)
        for _ in 0..<40 {
            let u = between(margin, 1 - margin), v = between(margin, 1 - margin)
            chosen = P((u - v) * 32, (u + v - 1) * 16)
            if placed.allSatisfy({ hypot($0.x - chosen.x, $0.y - chosen.y) >= spacing }) { break }
        }
        placed.append(chosen)
        return chosen
    }
}
