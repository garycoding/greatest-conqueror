// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age stock pen: a pen of timber rails between plastered piers of
// mud brick, round a floor of beaten earth and straw. A gate of planks with
// bronze fittings stands between taller piers flying the owner's pennant; a
// shelter of reed covers the back corner, a stone trough holds water, and an
// ox and two sheep stand inside. Its footprint is three tiles square: x and y
// run from -1.5 to 1.5.

extension BronzeBuildingsPainter {
    mutating func stockPen(complete: Bool) {
        typealias I = BronzeBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        straw()
        if complete { pen() } else { penRising() }
    }

    /// Wisps of straw over the floor, at fixed places.
    private mutating func straw() {
        typealias I = BronzeBuildingsInk
        let places: [(Double, Double, Double)] = [
            (-1.1, -0.6, 20), (-0.7, 0.9, -15), (-0.2, -1.0, 10), (0.3, 0.6, 35), (0.9, -0.2, -25), (1.1, 1.0, 5),
            (-1.2, 1.1, 30), (0.6, -1.1, -10), (-0.3, 0.1, 15), (1.2, 0.4, -30), (0.1, 1.2, 25), (-0.9, -1.2, -20),
        ]
        var d = PathData()
        for (x, y, turn) in places {
            let c = iso(x, y, 1.5)
            let u = P.direction(90 + turn) * 2.6
            d.move(c - u); d.line(c + u)
            d.move(c - u + P(0.8, 1)); d.line(c + u * 0.6 + P(0.8, 1))
        }
        svg.path(d, stroke: .colour(I.reedShade), width: 0.8)
    }

    /// A plastered pier of mud brick at (x, y), `height` points tall, with a capping of fired brick.
    private mutating func pier(_ x: Double, _ y: Double, height: Double, from h0: Double = 1.5) {
        typealias I = BronzeBuildingsInk
        let s = 0.075
        block(x - s, y - s, x + s, y + s, h0, h0 + height, top: .colour(I.plasterTop), left: .colour(I.light),
              right: .colour(I.plasterShade), width: 0.9)
        block(x - s - 0.015, y - s - 0.015, x + s + 0.015, y + s + 0.015, h0 + height, h0 + height + 2,
              top: .colour(I.terracottaTop), left: .colour(I.terracotta), right: .colour(I.terracottaShade), width: 0.8)
    }

    /// Two rails of timber from (x0, y0) to (x1, y1).
    private mutating func rails(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, levels: [Double] = [5, 10]) {
        for h in levels { pole(iso(x0, y0, 1.5 + h), iso(x1, y1, 1.5 + h), width: 1.4) }
    }

    private mutating func pen() {
        typealias I = BronzeBuildingsInk
        let e = 1.4, piers: [Double] = [-1.4, -0.7, 0, 0.7, 1.4]
        // The two sides at the back, then what stands inside, then the two at the front.
        for (a, b) in zip(piers, piers.dropFirst()) { rails(a, -e, b, -e); rails(-e, a, -e, b) }
        for p in piers { pier(p, -e, height: 13) }
        for p in piers.dropFirst() { pier(-e, p, height: 13) }
        shelter()
        trough()
        sheep(at: iso(0.75, -0.55, 1.5), facing: -1)
        ox(at: iso(0.15, 0.2, 1.5))
        sheep(at: iso(-0.55, 0.75, 1.5), facing: 1)
        // The front left side, with the gate in its middle.
        let gate = (-0.32, 0.32)
        rails(-e, e, gate.0, e)
        rails(gate.1, e, e, e)
        gateOfPlanks(gate.0, gate.1, e)
        for p in [-0.7, 0.7] { pier(p, e, height: 13) }
        for x in [gate.0, gate.1] { pier(x, e, height: 18) }
        pennant(at: iso(gate.0, e, 21.5), height: 13, length: 15)
        pennant(at: iso(gate.1, e, 21.5), height: 13, length: 15)
        // The front right side.
        for (a, b) in zip(piers, piers.dropFirst()) { rails(e, a, e, b) }
        for p in piers.dropFirst() { pier(e, p, height: 13) }
    }

    /// A gate of planks between x0 and x1 on the side at y, bound with bronze,
    /// a band of the owner's colour painted across it.
    private mutating func gateOfPlanks(_ x0: Double, _ x1: Double, _ y: Double) {
        typealias I = BronzeBuildingsInk
        wall(.left, from: x0, y, at: 1.5) { p in
            let w = (x1 - x0) * 32
            p.shape(p.panel(0, 0.6, w, 13), .colour(I.timberLight), width: 0.9)
            var u = w / 5
            while u < w - 0.5 { p.line([p.uv(u, 0.9), p.uv(u, 12.7)], width: 0.5); u += w / 5 }
            p.colour(p.panel(0, 8.4, w, 10.6), .team)
            p.line([p.uv(0, 8.4), p.uv(w, 8.4)], width: 0.6)
            p.line([p.uv(0, 10.6), p.uv(w, 10.6)], width: 0.6)
            p.line([p.uv(1.2, 2), p.uv(w - 1.2, 7.4)], width: 0.9)
            for v in [3.4, 11.8] {
                p.shape(p.panel(0.4, v - 0.6, 4.2, v + 0.6), .colour(I.bronzeLight), width: 0.5)
                p.shape(p.panel(w - 4.2, v - 0.6, w - 0.4, v + 0.6), .colour(I.bronzeLight), width: 0.5)
            }
        }
    }

    /// A lean-to of reed over the back corner, on four posts, with hay beneath.
    private mutating func shelter() {
        typealias I = BronzeBuildingsInk
        let (x0, y0, x1, y1) = (-1.32, -1.32, -0.34, -0.5)
        let high = 25.0, low = 18.0
        heap(at: iso(-0.95, -1.0, 1.5), width: 22, height: 10)
        for (x, y, h) in [(x0 + 0.04, y0 + 0.04, high), (x1, y0 + 0.04, high)] { pole(iso(x, y, 1.5), iso(x, y, h), width: 1.3) }
        for (x, y) in [(x0 + 0.04, y1), (x1, y1)] { pole(iso(x, y, 1.5), iso(x, y, low), width: 1.3) }
        // The roof slopes down toward the front.
        thatch([iso(x0 - 0.04, y0 - 0.04, high + 1), iso(x1 + 0.06, y0 - 0.04, high + 1), iso(x1 + 0.06, y1 + 0.1, low),
                iso(x0 - 0.04, y1 + 0.1, low)], thickness: 2)
    }

    /// A trough of stone holding water, along the back right side.
    private mutating func trough() {
        typealias I = BronzeBuildingsInk
        let (x0, y0, x1, y1) = (0.25, -1.28, 1.1, -1.08)
        block(x0, y0, x1, y1, 1.5, 6, top: .colour(I.stone), left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.9)
        shape(level(x0 + 0.04, y0 + 0.04, x1 - 0.04, y1 - 0.04, 6), .colour(I.verdigrisLight), width: 0.7)
        line([iso(x0 + 0.2, y0 + 0.1, 6), iso(x0 + 0.45, y0 + 0.1, 6)], width: 0.5, opacity: 0.7)
    }

    /// An ox standing at `p` on the screen, facing right: the approved scene's ox, small.
    private mutating func ox(at p: P) {
        typealias I = BronzeBuildingsInk
        svg.ellipse(p + P(0, 0.6), 12, 3, fill: .colour("#000000"), opacity: 0.14)
        // The legs, then the body over them.
        for x in [-8.2, -5, 5.2, 8.4] {
            line([p + P(x, -6), p + P(x, -0.2), p + P(x + 1.4, -0.2)], width: 1)
        }
        let body = [p + P(-11, -14), p + P(9, -14), p + P(10.6, -12.4), p + P(10.6, -7.4), p + P(9, -5.8), p + P(-11, -5.8),
                    p + P(-12.6, -7.4), p + P(-12.6, -12.4)]
        shape(body, .colour("#b9623a"), width: 1)
        // A tail, and the pattern on the hide.
        line([p + P(-12.4, -12), p + P(-14.4, -9), p + P(-14, -5)], width: 0.8)
        line(width: 0.6) { d in
            d.move(p + P(-6, -10.6)); d.quad(p + P(-3, -13.4), p + P(0, -10.6)); d.quad(p + P(-3, -8), p + P(-6, -10.6))
            d.move(p + P(2.4, -9.6)); d.quad(p + P(4.4, -11.4), p + P(6.4, -9.6))
        }
        // The head, its horns, and an eye.
        let head = [p + P(9, -15.6), p + P(15.6, -18), p + P(17.4, -12), p + P(12.4, -9.8)]
        shape(head, .colour("#b9623a"), width: 1)
        line(width: 0.9) { d in
            d.move(p + P(12.4, -16.8)); d.quad(p + P(10.6, -21.4), p + P(14.6, -22.8))
            d.move(p + P(14.6, -17.4)); d.quad(p + P(17.4, -20.6), p + P(20.6, -19.4))
        }
        svg.circle(p + P(14.6, -14.6), 0.7, fill: .colour(I.line))
    }

    /// A sheep standing at `p` on the screen, facing right (1) or left (-1).
    private mutating func sheep(at p: P, facing f: Double) {
        typealias I = BronzeBuildingsInk
        svg.ellipse(p + P(0, 0.5), 7, 2, fill: .colour("#000000"), opacity: 0.14)
        for x in [-3.6, -1.6, 2, 4] { line([p + P(x * f, -3.4), p + P(x * f, 0)], width: 0.9) }
        // The fleece: a body of scallops.
        func fleece(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-6, -4) + o)
            d.quad(p + P(-8.2, -7) + o, p + P(-5.4, -9.4) + o)
            d.quad(p + P(-3, -12) + o, p + P(0, -10.2) + o)
            d.quad(p + P(3, -12) + o, p + P(5.4, -9.4) + o)
            d.quad(p + P(8.2, -7) + o, p + P(6, -4) + o)
            d.quad(p + P(0, -1.6) + o, p + P(-6, -4) + o)
            d.close()
            return d
        }
        colour(.colour(I.light)) { d, o in d = fleece(o) }
        line(width: 0.9) { d in d = fleece(P(0, 0)) }
        let head = p + P(6.8 * f, -9)
        svg.ellipse(head, 2.4, 1.9, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.6)
        line([head + P(-0.6 * f, -1.4), head + P(-2.2 * f, -0.4)], width: 0.8)
        svg.circle(head + P(0.9 * f, -0.4), 0.45, fill: .colour(I.light))
    }

    /// The pen being built: the piers raised at the corners and the gate, the
    /// first rails along the back, more rails stacked, the shelter's posts set.
    private mutating func penRising() {
        typealias I = BronzeBuildingsInk
        let e = 1.4
        rails(-e, -e, 0.7, -e, levels: [5])
        rails(-e, -e, -e, 0, levels: [5])
        pier(-e, -e, height: 13)
        pier(0, -e, height: 13)
        pier(0.7, -e, height: 7)
        pier(-e, -0.7, height: 13)
        pier(-e, 0, height: 6)
        for (x, y, h) in [(-1.28, -1.28, 25.0), (-0.34, -1.28, 25.0), (-1.28, -0.5, 18.0)] {
            pole(iso(x, y, 1.5), iso(x, y, 1.5 + h), width: 1.3)
        }
        bricks(0.3, -0.5, 0.65, -0.2, from: 1.5, courses: 4)
        logs(-0.6, 0.6, 0.35, on: 1.5, radius: 1.6)
        basket(at: iso(0.75, 0.45, 1.5), size: 1)
        bricks(-0.85, 0.3, -0.6, 0.55, from: 1.5, courses: 2)
        pier(e, -e, height: 9)
        pier(-0.32, e, height: 18)
        pier(0.32, e, height: 10)
        pier(e, e, height: 5)
        pennant(at: iso(-0.32, e, 21.5), height: 13, length: 15)
        // The gate's planks, waiting against the front.
        wall(.left, from: 0.5, e + 0.05, at: 1.5) { p in
            p.shape([p.uv(0, 0), p.uv(16, 0), p.uv(17.6, 6.8), p.uv(1.6, 6.8)], .colour(I.timberLight), width: 0.9)
            p.line([p.uv(5.6, 0.3), p.uv(6.6, 6.5)], width: 0.5)
            p.line([p.uv(11, 0.3), p.uv(12, 6.5)], width: 0.5)
        }
    }
}
