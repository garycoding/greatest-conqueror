// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The things that stand about the Iron-age looks of the older buildings: what
// a building site needs (scaffold, stacked stone, roof tiles, column drums,
// logs, a basket, a ladder, a hoist) and the household's jars and amphorae and
// the temple's braziers. Places are given as on the map,
// in tiles from the footprint's centre, and heights in points.

extension IronOldBuildingsPainter {
    /// A pole of timber from `a` to `b` on the screen, outlined.
    mutating func pole(_ a: P, _ b: P, width: Double = 1.6, colour paint: String = IronOldBuildingsInk.timberLight) {
        svg.line([a, b], stroke: .colour(IronOldBuildingsInk.line), width: width + 1.1)
        svg.line([a, b], stroke: .colour(paint), width: width)
    }

    /// Scaffolding: upright poles standing at `feet` on the map, from `h0` up
    /// `height` points, tied by ledgers between neighbours at each of `levels`,
    /// with boards laid toward the wall at `boards`.
    mutating func scaffold(_ feet: [(x: Double, y: Double)], from h0: Double, height: Double, levels: [Double],
                           boards: Double? = nil) {
        typealias I = IronOldBuildingsInk
        if let boards {
            for (a, b) in zip(feet, feet.dropFirst()) {
                let dx = b.x - a.x, dy = b.y - a.y
                // The boards run from the poles back toward the wall they stand along.
                let nx = dy == 0 ? 0 : (dy > 0 ? 0.13 : -0.13), ny = dx == 0 ? 0 : (dx > 0 ? -0.13 : 0.13)
                let deck = [iso(a.x, a.y, h0 + boards), iso(b.x, b.y, h0 + boards), iso(b.x + nx, b.y + ny, h0 + boards),
                            iso(a.x + nx, a.y + ny, h0 + boards)]
                colour(deck, .colour(I.timberLight))
                colour([deck[0], deck[1], deck[1] + P(0, 1.3), deck[0] + P(0, 1.3)], .colour(I.timber))
                line(deck, closed: true, width: 0.7)
                line([deck[0] + P(0, 1.3), deck[1] + P(0, 1.3)], width: 0.7)
                for t in [0.33, 0.66] {
                    line([deck[0] + (deck[1] - deck[0]) * t, deck[3] + (deck[2] - deck[3]) * t], width: 0.45)
                }
            }
        }
        for level in levels {
            for (a, b) in zip(feet, feet.dropFirst()) {
                pole(iso(a.x, a.y, h0 + level), iso(b.x, b.y, h0 + level), width: 1.1)
            }
        }
        for foot in feet {
            pole(iso(foot.x, foot.y, h0), iso(foot.x, foot.y, h0 + height))
            // The lashings where the ledgers cross.
            for level in levels {
                let at = iso(foot.x, foot.y, h0 + level)
                line([at + P(-1.3, -0.9), at + P(1.3, 0.9)], width: 0.8)
            }
        }
    }

    /// Blocks of dressed stone stacked on the map from (x0, y0) to (x1, y1),
    /// from `h0`, `courses` high.
    mutating func blocks(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, courses: Int) {
        typealias I = IronOldBuildingsInk
        let course = 4.0, h1 = h0 + Double(courses) * course
        block(x0, y0, x1, y1, h0, h1, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade),
              width: 0.9)
        for c in 1..<max(courses, 1) {
            let h = h0 + Double(c) * course
            line([iso(x0, y1, h), iso(x1, y1, h), iso(x1, y0, h)], width: 0.55, opacity: 0.85)
        }
        // The joints between the blocks, staggered from course to course.
        for c in 0..<courses {
            let h = h0 + Double(c) * course
            for t in c % 2 == 0 ? [0.5] : [0.25, 0.75] {
                let x = x0 + (x1 - x0) * t, y = y1 + (y0 - y1) * t
                line([iso(x, y1, h + 0.3), iso(x, y1, h + course - 0.3)], width: 0.55, opacity: 0.85)
                line([iso(x1, y, h + 0.3), iso(x1, y, h + course - 0.3)], width: 0.55, opacity: 0.85)
            }
        }
    }

    /// Roof tiles stacked on edge on the map from (x0, y0) to (x1, y1), from
    /// `h0`, `height` points high: rows of red tile, one behind another.
    mutating func roofTiles(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, height: Double = 6) {
        typealias I = IronOldBuildingsInk
        block(x0, y0, x1, y1, h0, h0 + height, top: .colour(I.tileLight), left: .colour(I.tile), right: .colour(I.tileShade),
              width: 0.9)
        var d = PathData()
        var x = x0 + 0.035
        while x < x1 - 0.02 {
            d.move(iso(x, y1, h0 + 0.4)); d.line(iso(x, y1, h0 + height)); d.line(iso(x, y0, h0 + height))
            x += 0.035
        }
        svg.path(d, stroke: .colour(I.tileDark), width: 0.45, opacity: 0.8)
    }

    /// A drum of a column lying on its side, along the map's x axis from `x0`
    /// to `x1` at `y`, resting on `h`, `radius` points thick; its face shows toward +x.
    mutating func drum(_ x0: Double, _ x1: Double, _ y: Double, on h: Double, radius r: Double) {
        typealias I = IronOldBuildingsInk
        let body = [iso(x0, y, h), iso(x1, y, h), iso(x1, y, h + 2 * r), iso(x0, y, h + 2 * r)]
        colour(body, .colour(I.rawStone))
        colour([body[0], body[1], body[1] - P(0, r * 0.7), body[0] - P(0, r * 0.7)], .colour(I.rawStoneShade))
        line([body[3], body[2]], width: 0.9)
        line([body[0], body[1]], width: 0.9)
        line([iso(x0, y, h), iso(x0, y, h + 2 * r)], width: 0.9)
        let end = iso(x1, y, h + r)
        svg.ellipse(end + P(-0.5, 0.4), r * 0.62, r, fill: .colour(I.rawStoneTop))
        svg.ellipse(end, r * 0.62, r, fill: .none, stroke: .colour(I.line), width: 0.8)
        svg.circle(end, r * 0.14, fill: .colour(I.dark))
    }

    /// An amphora of fired clay standing at `p` on the screen, `size` times its usual size.
    mutating func amphora(at p: P, size s: Double = 1, paint: String = IronOldBuildingsInk.clay) {
        typealias I = IronOldBuildingsInk
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(0, 0) + o)
            d.cubic(p + P(-1.6 * s, -2 * s) + o, p + P(-3.8 * s, -6 * s) + o, p + P(-3.4 * s, -9 * s) + o)
            d.cubic(p + P(-3.1 * s, -11 * s) + o, p + P(-1.4 * s, -11.6 * s) + o, p + P(-1 * s, -12.2 * s) + o)
            d.line(p + P(-1 * s, -14.4 * s) + o)
            d.line(p + P(1 * s, -14.4 * s) + o)
            d.line(p + P(1 * s, -12.2 * s) + o)
            d.cubic(p + P(1.4 * s, -11.6 * s) + o, p + P(3.1 * s, -11 * s) + o, p + P(3.4 * s, -9 * s) + o)
            d.cubic(p + P(3.8 * s, -6 * s) + o, p + P(1.6 * s, -2 * s) + o, p + P(0, 0) + o)
            d.close()
            return d
        }
        colour(.colour(paint)) { d, o in d = outline(o) }
        line(width: 0.8) { d in d = outline(P(0, 0)) }
        // The handles, from the neck to the shoulder.
        line(width: 0.7) { d in
            d.move(p + P(-1 * s, -13.4 * s)); d.quad(p + P(-3.6 * s, -13.6 * s), p + P(-3 * s, -10.6 * s))
            d.move(p + P(1 * s, -13.4 * s)); d.quad(p + P(3.6 * s, -13.6 * s), p + P(3 * s, -10.6 * s))
        }
        line([p + P(-1.4 * s, -14.4 * s), p + P(1.4 * s, -14.4 * s)], width: 0.9)
        line([p + P(-2.9 * s, -8 * s), p + P(2.9 * s, -8 * s)], width: 0.45, opacity: 0.8)
    }

    /// A hoist of two timbers leaning together, their feet at `a` and `b` on the
    /// screen and their head at `head`, with a pulley and an iron hook, from
    /// which a block of stone hangs `drop` points below the head.
    mutating func shearLegs(_ a: P, _ b: P, head: P, drop: Double) {
        typealias I = IronOldBuildingsInk
        pole(a, head, width: 1.8, colour: I.timber)
        pole(b, head, width: 1.8, colour: I.timber)
        line([head, head + P(0, drop)], width: 0.7)
        line([head + P(1.6, 0), b + (head - b) * 0.25], width: 0.6)
        svg.circle(head + P(0.8, 0.6), 1.8, fill: .colour(I.timberLight), stroke: .colour(I.line), width: 0.7)
        svg.circle(head + P(0.8, 0.6), 0.6, fill: .colour(I.ironDark))
        let hook = head + P(0, drop)
        line([hook, hook + P(-2.6, 2.6)], width: 0.6)
        line([hook, hook + P(2.6, 2.6)], width: 0.6)
        let s = hook + P(0, 2.6)
        let cube = [s + P(-4.4, 0), s + P(0, -2.2), s + P(4.4, 0), s + P(4.4, 4), s + P(0, 6.2), s + P(-4.4, 4)]
        colour(cube, .colour(I.rawStone))
        colour([s + P(0, 2.2), s + P(4.4, 0), s + P(4.4, 4), s + P(0, 6.2)], .colour(I.rawStoneShade))
        colour([s + P(-4.4, 0), s + P(0, -2.2), s + P(4.4, 0), s + P(0, 2.2)], .colour(I.rawStoneTop))
        line(cube, closed: true, width: 0.8)
        line([s + P(-4.4, 0), s + P(0, 2.2), s + P(4.4, 0)], width: 0.6)
        line([s + P(0, 2.2), s + P(0, 6.2)], width: 0.6)
    }

    /// One log lying along the map's x axis from `x0` to `x1` at `y`, resting on
    /// `h`, `radius` points thick; its cut end shows toward +x.
    mutating func log(_ x0: Double, _ x1: Double, _ y: Double, on h: Double, radius r: Double = 2.2) {
        typealias I = IronOldBuildingsInk
        let body = [iso(x0, y, h), iso(x1, y, h), iso(x1, y, h + 2 * r), iso(x0, y, h + 2 * r)]
        colour(body, .colour(I.timber))
        line([body[3], body[2]], width: 0.9)
        line([body[0], body[1]], width: 0.9)
        line([iso(x0, y, h), iso(x0, y, h + 2 * r)], width: 0.9)
        let end = iso(x1, y, h + r)
        svg.ellipse(end + P(-0.5, 0.4), r * 0.62, r, fill: .colour(I.timberLight))
        svg.ellipse(end, r * 0.62, r, fill: .none, stroke: .colour(I.line), width: 0.8)
        svg.ellipse(end, r * 0.22, r * 0.4, fill: .none, stroke: .colour(I.line), width: 0.5)
    }

    /// A pile of logs along x centred on `y`: three below, two on them, one on
    /// top, drawn from the farthest to the nearest.
    mutating func logs(_ x0: Double, _ x1: Double, _ y: Double, on h: Double = 0, radius r: Double = 2.2) {
        // Side by side, the logs are a diameter apart on the screen: about 34 points a tile along y.
        let spacing = 2 * r / 34
        var pile: [(y: Double, h: Double)] = []
        for (row, count) in [3, 2, 1].enumerated() {
            for i in 0..<count {
                pile.append((y + (Double(i) - Double(count - 1) / 2) * spacing, h + Double(row) * r * 1.7))
            }
        }
        for one in pile.sorted(by: { ($0.y, $0.h) < ($1.y, $1.h) }) { log(x0, x1, one.y, on: one.h, radius: r) }
    }

    /// A basket of mortar standing at `at` on the screen.
    mutating func basket(at p: P, size s: Double = 1) {
        typealias I = IronOldBuildingsInk
        let body = [p + P(-3.4 * s, -4 * s), p + P(3.4 * s, -4 * s), p + P(2.6 * s, 0), p + P(-2.6 * s, 0)]
        shape(body, .colour(I.reed), width: 0.8)
        svg.ellipse(p + P(0, -4 * s), 3.4 * s, 1.2 * s, fill: .colour(I.paving), stroke: .colour(I.line), width: 0.7)
        line([p + P(-3 * s, -2.2 * s), p + P(3 * s, -2.2 * s)], width: 0.5)
    }

    /// A ladder from its feet to its head, both given as pairs of points on the screen.
    mutating func ladder(foot a: P, _ b: P, head c: P, _ d: P, rungs: Int) {
        typealias I = IronOldBuildingsInk
        pole(a, c, width: 1)
        pole(b, d, width: 1)
        for i in 1...rungs {
            let t = Double(i) / Double(rungs + 1)
            svg.line([a + (c - a) * t, b + (d - b) * t], stroke: .colour(I.line), width: 1)
        }
    }

    /// A tall jar of fired clay standing at `p` on the screen, `size` times its usual size.
    mutating func jar(at p: P, size s: Double = 1, paint: String = IronOldBuildingsInk.clay) {
        typealias I = IronOldBuildingsInk
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-1.4 * s, 0) + o)
            d.cubic(p + P(-4.6 * s, -1.5 * s) + o, p + P(-4.6 * s, -7.5 * s) + o, p + P(-1.6 * s, -8.6 * s) + o)
            d.line(p + P(-1.6 * s, -10 * s) + o)
            d.line(p + P(1.6 * s, -10 * s) + o)
            d.line(p + P(1.6 * s, -8.6 * s) + o)
            d.cubic(p + P(4.6 * s, -7.5 * s) + o, p + P(4.6 * s, -1.5 * s) + o, p + P(1.4 * s, 0) + o)
            d.close()
            return d
        }
        colour(.colour(paint)) { d, o in d = outline(o) }
        line(width: 0.9) { d in d = outline(P(0, 0)) }
        line([p + P(-3.3 * s, -5.6 * s), p + P(3.3 * s, -5.6 * s)], width: 0.6)
        line([p + P(-2.2 * s, -10 * s), p + P(2.2 * s, -10 * s)], width: 1)
    }

    /// An iron brazier on three legs standing at `p` on the screen, with its fire.
    mutating func brazier(at p: P) {
        typealias I = IronOldBuildingsInk
        line([p + P(-2.6, 0), p + P(-1.6, -4.5)], width: 0.8)
        line([p + P(2.6, 0), p + P(1.6, -4.5)], width: 0.8)
        line([p + P(0, 0.6), p + P(0, -4.5)], width: 0.8)
        // The flame: two tongues, the inner paler.
        var flame = PathData()
        flame.move(p + P(-2.4, -6.2))
        flame.quad(p + P(-2.6, -9.6), p + P(-0.4, -12.6))
        flame.quad(p + P(0.2, -10), p + P(1, -11.6))
        flame.quad(p + P(2.8, -9), p + P(2.4, -6.2))
        flame.close()
        svg.path(flame, fill: .colour(I.tileLight), stroke: .colour(I.line), width: 0.6)
        svg.ellipse(p + P(0, -7.4), 1.1, 1.8, fill: .colour(I.gilt))
        let bowl = [p + P(-3.6, -6.6), p + P(3.6, -6.6), p + P(2.2, -4.2), p + P(-2.2, -4.2)]
        shape(bowl, .colour(I.iron), width: 0.8)
    }

    /// A heap of loose earth standing at `p` on the screen.
    mutating func heap(at p: P, width w: Double, height h: Double) {
        typealias I = IronOldBuildingsInk
        // Two humps, the larger behind, spreading low at the foot.
        func trace(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-w / 2, 0) + o)
            d.quad(p + P(-w * 0.4, -h * 0.45) + o, p + P(-w * 0.18, -h * 0.8) + o)
            d.quad(p + P(-w * 0.05, -h * 1.05) + o, p + P(w * 0.06, -h * 0.72) + o)
            d.quad(p + P(w * 0.16, -h * 0.68) + o, p + P(w * 0.26, -h * 0.5) + o)
            d.quad(p + P(w * 0.42, -h * 0.25) + o, p + P(w / 2, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.earth)) { d, o in d = trace(o) }
        // The shaded flank on the right.
        svg.path("M\(num(p.x + w * 0.06)),\(num(p.y - h * 0.72)) q\(num(w * 0.1)),\(num(h * 0.04)) \(num(w * 0.2)),\(num(h * 0.22)) "
                 + "q\(num(w * 0.16)),\(num(h * 0.25)) \(num(w * 0.24)),\(num(h * 0.5)) L\(num(p.x + w * 0.1)),\(num(p.y)) Z",
                 fill: .colour(I.earthShade))
        line(width: 0.9) { d in d = trace(P(0, 0)) }
        for (dx, dy) in [(-0.26, -0.3), (-0.1, -0.62), (0.12, -0.4), (0.3, -0.18), (-0.36, -0.12), (0.02, -0.2)] {
            svg.circle(p + P(w * dx, h * dy), 0.6, fill: .colour(I.line), opacity: 0.55)
        }
    }
}
