// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The things that stand about the Alchemy-age looks of the older buildings:
// what a building site needs (scaffold, stacked stone, squared oak, slates, a
// ladder, a basket of mortar, a treadwheel crane) and the barrels, sacks and
// crates of a prosperous town. Places are given as on the map, in tiles from
// the footprint's centre, and heights in points.

extension AlchemyOldBuildingsPainter {
    /// A pole of timber from `a` to `b` on the screen, outlined.
    mutating func pole(_ a: P, _ b: P, width: Double = 1.6, colour paint: String = AlchemyOldBuildingsInk.timberLight) {
        svg.line([a, b], stroke: .colour(AlchemyOldBuildingsInk.line), width: width + 1.1)
        svg.line([a, b], stroke: .colour(paint), width: width)
    }

    /// Scaffolding: upright poles standing at `feet` on the map, from `h0` up
    /// `height` points, tied by ledgers between neighbours at each of `levels`,
    /// with boards laid at `boards` toward `inward` (tiles along x and y).
    mutating func scaffold(_ feet: [(x: Double, y: Double)], from h0: Double, height: Double, levels: [Double],
                           boards: Double? = nil, inward: (x: Double, y: Double) = (0, -0.13)) {
        typealias I = AlchemyOldBuildingsInk
        if let boards {
            for (a, b) in zip(feet, feet.dropFirst()) {
                let deck = [iso(a.x, a.y, h0 + boards), iso(b.x, b.y, h0 + boards),
                            iso(b.x + inward.x, b.y + inward.y, h0 + boards), iso(a.x + inward.x, a.y + inward.y, h0 + boards)]
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
        // A brace across the first bay, so that the scaffold stands.
        if feet.count > 1, let last = levels.last {
            let (a, b) = (feet[0], feet[1])
            pole(iso(a.x, a.y, h0 + 1), iso(b.x, b.y, h0 + last), width: 0.9)
        }
        for foot in feet {
            pole(iso(foot.x, foot.y, h0), iso(foot.x, foot.y, h0 + height))
            for level in levels {
                let at = iso(foot.x, foot.y, h0 + level)
                line([at + P(-1.3, -0.9), at + P(1.3, 0.9)], width: 0.8)
            }
        }
    }

    /// Blocks of fresh-cut stone stacked on the map from (x0, y0) to (x1, y1),
    /// from `h0`, `courses` high.
    mutating func blocks(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, courses: Int) {
        typealias I = AlchemyOldBuildingsInk
        let course = 4.0, h1 = h0 + Double(courses) * course
        block(x0, y0, x1, y1, h0, h1, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade),
              width: 0.9)
        for c in 1..<max(courses, 1) {
            let h = h0 + Double(c) * course
            line([iso(x0, y1, h), iso(x1, y1, h), iso(x1, y0, h)], width: 0.55, opacity: 0.85)
        }
        for c in 0..<courses {
            let h = h0 + Double(c) * course
            for t in c % 2 == 0 ? [0.5] : [0.25, 0.75] {
                let x = x0 + (x1 - x0) * t, y = y1 + (y0 - y1) * t
                line([iso(x, y1, h + 0.3), iso(x, y1, h + course - 0.3)], width: 0.55, opacity: 0.85)
                line([iso(x1, y, h + 0.3), iso(x1, y, h + course - 0.3)], width: 0.55, opacity: 0.85)
            }
        }
    }

    /// A squared timber of oak lying on the map from (x0, y0) to (x1, y1) at
    /// `h`, `size` points square, its sawn end toward the viewer.
    mutating func beam(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, on h: Double, size s: Double = 2.6) {
        typealias I = AlchemyOldBuildingsInk
        let a = iso(x0, y0, h), b = iso(x1, y1, h)
        let up = P(0, -s)
        let along = b - a
        let across = abs(along.x) > 0.01 && along.y / along.x > 0 ? P(-s * 0.9, s * 0.45) : P(s * 0.9, s * 0.45)
        colour([a, b, b + up, a + up], .colour(I.oakLight))
        colour([a + up, b + up, b + up - across, a + up - across], .colour(I.timberLight))
        line([a, b, b + up, a + up], closed: true, width: 0.8)
        line([a + up, a + up - across, b + up - across, b + up], width: 0.8)
        line([a + up * 0.5 + along * 0.2, a + up * 0.5 + along * 0.55], width: 0.4, opacity: 0.7)
    }

    /// Squared timbers stacked along x from (x, y), `length` tiles long: three
    /// below and two above.
    mutating func timbers(_ x: Double, _ y: Double, length: Double, on h: Double) {
        for (row, offsets) in [[0.0, 0.09, 0.18], [0.045, 0.135]].enumerated() {
            for dy in offsets { beam(x, y + dy, x + length, y + dy, on: h + Double(row) * 2.6, size: 2.6) }
        }
    }

    /// Slates stacked on edge on the map from (x0, y0) to (x1, y1), from `h0`,
    /// `height` points high, in a crate of laths.
    mutating func slates(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, height: Double = 6) {
        typealias I = AlchemyOldBuildingsInk
        block(x0, y0, x1, y1, h0, h0 + height, top: .colour(I.slateLight), left: .colour(I.slate), right: .colour(I.slateShade),
              width: 0.9)
        var d = PathData()
        var x = x0 + 0.03
        while x < x1 - 0.015 {
            d.move(iso(x, y1, h0 + 0.4)); d.line(iso(x, y1, h0 + height)); d.line(iso(x, y0, h0 + height))
            x += 0.03
        }
        svg.path(d, stroke: .colour(I.slateDark), width: 0.4, opacity: 0.85)
        pole(iso(x0, y1, h0 + height * 0.35), iso(x1, y1, h0 + height * 0.35), width: 0.8)
    }

    /// A barrel of oak bound with iron hoops, standing at `p` on the screen.
    mutating func barrel(at p: P, size s: Double = 1) {
        typealias I = AlchemyOldBuildingsInk
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-3.4 * s, 0) + o)
            d.quad(p + P(-4.6 * s, -4.6 * s) + o, p + P(-3.4 * s, -9.2 * s) + o)
            d.line(p + P(3.4 * s, -9.2 * s) + o)
            d.quad(p + P(4.6 * s, -4.6 * s) + o, p + P(3.4 * s, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.timber)) { d, o in d = outline(o) }
        colour(.colour(I.timberLight)) { d, o in
            d.move(p + P(-3.4 * s, 0) + o)
            d.quad(p + P(-4.6 * s, -4.6 * s) + o, p + P(-3.4 * s, -9.2 * s) + o)
            d.line(p + P(-1 * s, -9.2 * s) + o)
            d.quad(p + P(-1.6 * s, -4.6 * s) + o, p + P(-1 * s, 0) + o)
            d.close()
        }
        line(width: 0.8) { d in d = outline(P(0, 0)) }
        for v in [1.6, 7.6] {
            line([p + P(-3.9 * s, -v * s), p + P(3.9 * s, -v * s)], width: 0.9)
        }
        svg.ellipse(p + P(0, -9.2 * s), 3.4 * s, 1.1 * s, fill: .colour(I.timberDark), stroke: .colour(I.line), width: 0.6)
    }

    /// A sack of grain or flour, tied at its neck, standing at `p` on the screen.
    mutating func sack(at p: P, size s: Double = 1) {
        typealias I = AlchemyOldBuildingsInk
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-4 * s, 0) + o)
            d.quad(p + P(-5 * s, -5 * s) + o, p + P(-1.6 * s, -8.4 * s) + o)
            d.line(p + P(-2.2 * s, -10.4 * s) + o)
            d.line(p + P(2.2 * s, -10.4 * s) + o)
            d.line(p + P(1.6 * s, -8.4 * s) + o)
            d.quad(p + P(5 * s, -5 * s) + o, p + P(4 * s, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.straw)) { d, o in d = outline(o) }
        line(width: 0.8) { d in d = outline(P(0, 0)) }
        line([p + P(-1.8 * s, -8.6 * s), p + P(1.8 * s, -8.6 * s)], width: 0.9)
        line([p + P(1 * s, -1.4 * s), p + P(2.6 * s, -5 * s)], width: 0.4, opacity: 0.6)
    }

    /// A crate of boards at (x0, y0) to (x1, y1) on the map, from `h0`, `height` points tall.
    mutating func crate(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double, height: Double) {
        typealias I = AlchemyOldBuildingsInk
        block(x0, y0, x1, y1, h0, h0 + height, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.8)
        wall(.left, from: x0, y1, at: h0) { p in
            let w = (x1 - x0) * 32
            p.line([p.uv(0.6, 0.6), p.uv(w - 0.6, height - 0.6)], width: 0.6)
            p.line([p.uv(0, height / 2), p.uv(w, height / 2)], width: 0.4, opacity: 0.7)
        }
    }

    /// A ladder from its feet to its head, both given as pairs of points on the screen.
    mutating func ladder(foot a: P, _ b: P, head c: P, _ d: P, rungs: Int) {
        typealias I = AlchemyOldBuildingsInk
        pole(a, c, width: 1)
        pole(b, d, width: 1)
        for i in 1...rungs {
            let t = Double(i) / Double(rungs + 1)
            svg.line([a + (c - a) * t, b + (d - b) * t], stroke: .colour(I.line), width: 1)
        }
    }

    /// A basket of mortar standing at `p` on the screen.
    mutating func basket(at p: P, size s: Double = 1) {
        typealias I = AlchemyOldBuildingsInk
        let body = [p + P(-3.4 * s, -4 * s), p + P(3.4 * s, -4 * s), p + P(2.6 * s, 0), p + P(-2.6 * s, 0)]
        shape(body, .colour(I.straw), width: 0.8)
        svg.ellipse(p + P(0, -4 * s), 3.4 * s, 1.2 * s, fill: .colour(I.plasterTop), stroke: .colour(I.line), width: 0.7)
        line([p + P(-3 * s, -2.2 * s), p + P(3 * s, -2.2 * s)], width: 0.5)
    }

    /// A heap of loose earth or sand standing at `p` on the screen.
    mutating func heap(at p: P, width w: Double, height h: Double, paint: String = AlchemyOldBuildingsInk.earth,
                       shade: String = AlchemyOldBuildingsInk.earthShade) {
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
        colour(.colour(paint)) { d, o in d = trace(o) }
        svg.path("M\(num(p.x + w * 0.06)),\(num(p.y - h * 0.72)) q\(num(w * 0.1)),\(num(h * 0.04)) \(num(w * 0.2)),\(num(h * 0.22)) "
                 + "q\(num(w * 0.16)),\(num(h * 0.25)) \(num(w * 0.24)),\(num(h * 0.5)) L\(num(p.x + w * 0.1)),\(num(p.y)) Z",
                 fill: .colour(shade))
        line(width: 0.9) { d in d = trace(P(0, 0)) }
        for (dx, dy) in [(-0.26, -0.3), (-0.1, -0.62), (0.12, -0.4), (0.3, -0.18), (-0.36, -0.12), (0.02, -0.2)] {
            svg.circle(p + P(w * dx, h * dy), 0.6, fill: .colour(AlchemyOldBuildingsInk.line), opacity: 0.55)
        }
    }

    /// A treadwheel crane standing on the map at (x, y) on `h`: a great wheel
    /// of oak in which a man walks, beside the upright that carries the jib,
    /// its rope lifting a block `drop` points below the jib's end. The jib
    /// reaches `reach` points to the left on the screen and stands `height`
    /// points tall.
    mutating func treadwheel(_ x: Double, _ y: Double, on h: Double, height: Double, reach: Double, drop: Double) {
        typealias I = AlchemyOldBuildingsInk
        let foot = iso(x, y, h)
        // The frame's feet and the upright.
        pole(foot + P(-9, 0), foot + P(9, 0), width: 2.2, colour: I.oak)
        let head = foot - P(0, height)
        pole(foot + P(-7, 0), head + P(0, 10), width: 1.3, colour: I.oakLight)
        pole(foot, head, width: 2.6, colour: I.oak)
        // The wheel, seen a little from the side.
        let hub = foot - P(4, 12)
        svg.ellipse(hub + P(-0.6, 0.4), 6.2, 11, fill: .colour(I.timber), opacity: 0.35)
        svg.ellipse(hub, 6.2, 11, fill: .none, stroke: .colour(I.line), width: 2.6)
        svg.ellipse(hub, 6.2, 11, fill: .none, stroke: .colour(I.timberLight), width: 1.4)
        var spokes = PathData()
        for k in 0..<6 {
            let a = Double(k) * .pi / 6
            spokes.move(hub + P(cos(a) * 6.2, sin(a) * 11)); spokes.line(hub - P(cos(a) * 6.2, sin(a) * 11))
        }
        svg.path(spokes, stroke: .colour(I.timberDark), width: 0.8)
        svg.circle(hub, 1.2, fill: .colour(I.ironDark))
        // The jib, its brace, the rope and the block on its hook.
        let tip = head + P(-reach, 6)
        pole(head + P(2, -1), tip, width: 1.8, colour: I.oakLight)
        pole(foot - P(0, height * 0.55), head + (tip - head) * 0.4, width: 1.1, colour: I.oakLight)
        svg.circle(tip, 1.8, fill: .colour(I.timberLight), stroke: .colour(I.line), width: 0.6)
        line([tip, tip + P(0, drop)], width: 0.7)
        line([tip, hub + P(0, -2)], width: 0.55, opacity: 0.8)
        let hook = tip + P(0, drop)
        line([hook, hook + P(-2.4, 2.4)], width: 0.6)
        line([hook, hook + P(2.4, 2.4)], width: 0.6)
        let s = hook + P(0, 2.4)
        let cube = [s + P(-4.2, 0), s + P(0, -2.1), s + P(4.2, 0), s + P(4.2, 3.8), s + P(0, 5.9), s + P(-4.2, 3.8)]
        colour(cube, .colour(I.rawStone))
        colour([s + P(0, 2.1), s + P(4.2, 0), s + P(4.2, 3.8), s + P(0, 5.9)], .colour(I.rawStoneShade))
        colour([s + P(-4.2, 0), s + P(0, -2.1), s + P(4.2, 0), s + P(0, 2.1)], .colour(I.rawStoneTop))
        line(cube, closed: true, width: 0.8)
        line([s + P(-4.2, 0), s + P(0, 2.1), s + P(4.2, 0)], width: 0.6)
        line([s + P(0, 2.1), s + P(0, 5.9)], width: 0.6)
    }
}
