// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The things that stand about the Industrial-age looks of the older buildings:
// what a building site needs (scaffold, stacked stone and brick, squared
// timber, slates, a ladder, a basket of mortar, a derrick crane with its
// winch) and the barrels, sacks and crates of a trading town. Places are given as on the map, in tiles from
// the footprint's centre, and heights in points.

extension IndustrialOldBuildingsPainter {
    /// A pole of timber from `a` to `b` on the screen, outlined.
    mutating func pole(_ a: P, _ b: P, width: Double = 1.6, colour paint: String = IndustrialOldBuildingsInk.timberLight) {
        svg.line([a, b], stroke: .colour(IndustrialOldBuildingsInk.line), width: width + 1.1)
        svg.line([a, b], stroke: .colour(paint), width: width)
    }

    /// Scaffolding: upright poles standing at `feet` on the map, from `h0` up
    /// `height` points, tied by ledgers between neighbours at each of `levels`,
    /// with boards laid at `boards` toward `inward` (tiles along x and y).
    mutating func scaffold(_ feet: [(x: Double, y: Double)], from h0: Double, height: Double, levels: [Double],
                           boards: Double? = nil, inward: (x: Double, y: Double) = (0, -0.13)) {
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
        pole(a, c, width: 1)
        pole(b, d, width: 1)
        for i in 1...rungs {
            let t = Double(i) / Double(rungs + 1)
            svg.line([a + (c - a) * t, b + (d - b) * t], stroke: .colour(I.line), width: 1)
        }
    }

    /// A basket of mortar standing at `p` on the screen.
    mutating func basket(at p: P, size s: Double = 1) {
        typealias I = IndustrialOldBuildingsInk
        let body = [p + P(-3.4 * s, -4 * s), p + P(3.4 * s, -4 * s), p + P(2.6 * s, 0), p + P(-2.6 * s, 0)]
        shape(body, .colour(I.straw), width: 0.8)
        svg.ellipse(p + P(0, -4 * s), 3.4 * s, 1.2 * s, fill: .colour(I.plasterTop), stroke: .colour(I.line), width: 0.7)
        line([p + P(-3 * s, -2.2 * s), p + P(3 * s, -2.2 * s)], width: 0.5)
    }

    /// A heap of loose earth or sand standing at `p` on the screen.
    mutating func heap(at p: P, width w: Double, height h: Double, paint: String = IndustrialOldBuildingsInk.earth,
                       shade: String = IndustrialOldBuildingsInk.earthShade) {
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
            svg.circle(p + P(w * dx, h * dy), 0.6, fill: .colour(IndustrialOldBuildingsInk.line), opacity: 0.55)
        }
    }

    /// A derrick crane standing on the map at (x, y) on `h`: a mast of timber
    /// on a footing of iron, guyed back, with a hand winch of iron geared to
    /// its drum, its jib reaching `reach` points to the left on the screen from
    /// a mast `height` points tall, its chain lifting a load of bricks `drop`
    /// points below the jib's end.
    mutating func derrick(_ x: Double, _ y: Double, on h: Double, height: Double, reach: Double, drop: Double) {
        typealias I = IndustrialOldBuildingsInk
        let foot = iso(x, y, h)
        pole(foot + P(-8, 1), foot + P(8, -1), width: 2.2, colour: I.iron)
        let head = foot - P(0, height)
        // The guys back to the footing, and the mast.
        line([head, foot + P(9, 2)], width: 0.5, opacity: 0.8)
        line([head, foot + P(-6, 3)], width: 0.5, opacity: 0.8)
        pole(foot, head, width: 2.6, colour: I.timber)
        // The winch: two iron cheeks, a drum wound with chain, a gear and a crank.
        let w = foot + P(4.6, -4)
        shape([w + P(-2.6, 4), w + P(-1.6, -2.4), w + P(1.6, -2.4), w + P(2.6, 4)], .colour(I.iron), width: 0.6)
        svg.circle(w + P(0, -1), 2.6, fill: .colour(I.ironDark), stroke: .colour(I.line), width: 0.5)
        var cogs = PathData()
        for k in 0..<10 {
            let a = Double(k) * .pi / 5
            cogs.move(w + P(cos(a) * 2.6, -1 + sin(a) * 2.6)); cogs.line(w + P(cos(a) * 3.3, -1 + sin(a) * 3.3))
        }
        svg.path(cogs, stroke: .colour(I.line), width: 0.7)
        svg.circle(w + P(0, -1), 0.8, fill: .colour(I.ironLight))
        line([w + P(0, -1), w + P(3.6, -3.2), w + P(5, -3.2)], width: 0.9)
        // The jib, its tie to the masthead, the chain and the load on its hook.
        let heel = foot - P(0, height * 0.3)
        let tip = head + P(-reach, 4)
        pole(heel, tip, width: 1.8, colour: I.timberLight)
        line([head, tip], width: 0.6)
        svg.circle(tip, 1.5, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        line([tip, tip + P(0, drop)], width: 0.75)
        line([tip, w + P(0, -2)], width: 0.5, opacity: 0.7)
        let hook = tip + P(0, drop)
        line([hook, hook + P(-3.4, 2.6)], width: 0.6)
        line([hook, hook + P(3.4, 2.6)], width: 0.6)
        let s = hook + P(0, 2.6)
        let cube = [s + P(-4.4, 0), s + P(0, -2.2), s + P(4.4, 0), s + P(4.4, 3.6), s + P(0, 5.8), s + P(-4.4, 3.6)]
        colour(cube, .colour(I.rawBrick))
        colour([s + P(0, 2.2), s + P(4.4, 0), s + P(4.4, 3.6), s + P(0, 5.8)], .colour(I.rawBrickShade))
        colour([s + P(-4.4, 0), s + P(0, -2.2), s + P(4.4, 0), s + P(0, 2.2)], .colour(I.brickTop))
        line(cube, closed: true, width: 0.8)
        line([s + P(-4.4, 0), s + P(0, 2.2), s + P(4.4, 0)], width: 0.6)
        line([s + P(0, 2.2), s + P(0, 5.8)], width: 0.6)
        line([s + P(-4.4, 1.8), s + P(0, 4), s + P(4.4, 1.8)], width: 0.35, opacity: 0.5)
    }

    /// New bricks stacked on the map from (x0, y0) to (x1, y1) from `h0`,
    /// `height` points high, on a pallet of boards, their courses showing.
    mutating func bricks(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, height: Double = 6) {
        typealias I = IndustrialOldBuildingsInk
        block(x0 - 0.02, y0 - 0.02, x1 + 0.02, y1 + 0.02, h0, h0 + 1.2, top: nil, left: .colour(I.timberLight),
              right: .colour(I.timber), width: 0.6)
        block(x0, y0, x1, y1, h0 + 1.2, h0 + 1.2 + height, top: .colour(I.brickTop), left: .colour(I.rawBrick),
              right: .colour(I.rawBrickShade), width: 0.8)
        wall(.left, from: x0, y1, at: h0 + 1.2) { p in
            p.brickwork(0, (x1 - x0) * 32, 0, height, course: 1.6, brick: 3.6, opacity: 0.45, burnt: false)
        }
        wall(.right, from: x1, y1, at: h0 + 1.2) { p in
            p.brickwork(0, (y1 - y0) * 32, 0, height, course: 1.6, brick: 3.6, opacity: 0.45, burnt: false)
        }
    }
}

/// What a cart carries.
enum IndustrialOldBuildingsLoad: Sendable {
    case empty, sacks, sheaves, crates
}

extension IndustrialOldBuildingsPainter {
    /// A two-wheeled cart standing on the map at (x, y) on `h`, its bed
    /// running along x, `length` tiles long: a bed of boards painted bottle green
    /// with sideboards, a pair of tall wheels of spoked timber with iron
    /// tyres, shafts reaching forward to the right, a prop under them, and
    /// `load` heaped in it.
    mutating func cart(_ x: Double, _ y: Double, on h: Double, length: Double = 0.5, load: IndustrialOldBuildingsLoad) {
        typealias I = IndustrialOldBuildingsInk
        let (x0, x1, y0, y1) = (x - length / 2, x + length / 2, y - 0.12, y + 0.12)
        let bed = h + 7.5, side = 4.5, r = 6.6
        shadow(level(x0 - 0.04, y0, x1 + 0.3, y1 + 0.1, h), opacity: 0.14)
        // The far wheel, half hidden.
        wall(.left, from: x - 0.02, y0 - 0.02, at: h) { p in
            p.svg.circle(p.uv(0, r), r, fill: .none, stroke: .colour(I.line), width: 2)
            p.svg.circle(p.uv(0, r), r, fill: .none, stroke: .colour(I.timberDark), width: 0.9)
        }
        // The shafts, and the prop under their ends.
        let tipA = iso(x1 + 0.42, y0 + 0.03, h + 4), tipB = iso(x1 + 0.42, y1 - 0.03, h + 4)
        pole(iso(x0 + 0.1, y0 + 0.03, bed), tipA, width: 1.4, colour: I.timber)
        pole(iso(x1 + 0.42, (y0 + y1) / 2, h), iso(x1 + 0.42, (y0 + y1) / 2, h + 4), width: 1.1, colour: I.timberDark)
        // The bed and its sideboards.
        block(x0, y0, x1, y1, bed, bed + 1.6, top: .colour(I.timberLight), left: .colour(I.green), right: .colour(I.greenShade),
              width: 0.8)
        switch load {
        case .empty: break
        case .sacks:
            for (dx, dy) in [(-0.12, -0.04), (0.08, -0.05), (-0.02, 0.06), (0.16, 0.05)] {
                sack(at: iso(x + dx, y + dy, bed + 1.6), size: 0.75)
            }
        case .sheaves:
            for (dx, dy) in [(-0.14, -0.05), (0.04, -0.05), (0.2, -0.05), (-0.1, 0.06), (0.1, 0.06)] {
                sheaf(at: iso(x + dx, y + dy, bed + 1.6), size: 0.8)
            }
        case .crates:
            crate(x0 + 0.04, y0 + 0.02, x0 + 0.24, y1 - 0.02, from: bed + 1.6, height: 5)
            crate(x0 + 0.27, y0 + 0.02, x1 - 0.04, y1 - 0.02, from: bed + 1.6, height: 4)
            barrel(at: iso(x0 + 0.38, y, bed + 5.6), size: 0.65)
        }
        for (a, b, paint) in [(iso(x0, y1, bed + 1.6), iso(x1, y1, bed + 1.6), I.greenLight)] {
            shape([a, b, b - P(0, side), a - P(0, side)], .colour(paint), width: 0.7)
            var slats = PathData()
            for k in 1..<5 {
                let t = Double(k) / 5, p = a + (b - a) * t
                slats.move(p); slats.line(p - P(0, side))
            }
            svg.path(slats, stroke: .colour(I.line), width: 0.4, opacity: 0.6)
        }
        shape([iso(x1, y1, bed + 1.6), iso(x1, y0, bed + 1.6), iso(x1, y0, bed + 1.6 + side), iso(x1, y1, bed + 1.6 + side)],
              .colour(I.greenShade), width: 0.7)
        pole(iso(x0 + 0.1, y1 + 0.01, bed), tipB, width: 1.5, colour: I.timberLight)
        // The near wheel: an iron tyre, a felloe of timber, twelve spokes and a hub.
        wall(.left, from: x, y1 + 0.03, at: h) { p in
            let c = p.uv(0, r)
            p.svg.circle(c + p.shift, r, fill: .colour(I.timber), opacity: 0.25)
            p.svg.circle(c, r, fill: .none, stroke: .colour(I.line), width: 2.2)
            p.svg.circle(c, r, fill: .none, stroke: .colour(I.iron), width: 1)
            p.svg.circle(c, r - 1.3, fill: .none, stroke: .colour(I.timberLight), width: 1)
            var spokes = PathData()
            for k in 0..<6 {
                let a = Double(k) * .pi / 6
                spokes.move(c + P(cos(a), sin(a)) * (r - 1.3)); spokes.line(c - P(cos(a), sin(a)) * (r - 1.3))
            }
            p.svg.path(spokes, stroke: .colour(I.line), width: 1.1)
            p.svg.path(spokes, stroke: .colour(I.timberLight), width: 0.45)
            p.svg.circle(c, 1.5, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// A sheaf of grain standing at `p` on the screen, bound at its waist.
    mutating func sheaf(at p: P, size s: Double = 1) {
        typealias I = IndustrialOldBuildingsInk
        let outline = [p + P(-2.6 * s, 0), p + P(-1.2 * s, -4 * s), p + P(-2.4 * s, -8 * s), p + P(0, -9 * s),
                       p + P(2.4 * s, -8 * s), p + P(1.2 * s, -4 * s), p + P(2.6 * s, 0)]
        shape(outline, .colour(I.straw), width: 0.6)
        colour([p + P(0.4 * s, 0), p + P(0.6 * s, -4 * s), p + P(1.6 * s, -8.4 * s), p + P(2.4 * s, -8 * s),
                p + P(1.2 * s, -4 * s), p + P(2.6 * s, 0)], .colour(I.strawShade), opacity: 0.8)
        line([p + P(-1.2 * s, -4 * s), p + P(1.2 * s, -4 * s)], width: 0.8)
        var ears = PathData()
        for dx in [-1.6, -0.5, 0.6, 1.6] { ears.move(p + P(dx * s, -7.8 * s)); ears.line(p + P(dx * 1.2 * s, -9.6 * s)) }
        svg.path(ears, stroke: .colour(I.strawShade), width: 0.6)
    }
}
