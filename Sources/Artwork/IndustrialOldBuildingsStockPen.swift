// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age stock pen: the Alchemy age's pen fenced anew in cast
// iron. Railings of iron bars with spear points run between piers of red
// brick under caps and balls of stone, round a floor of beaten earth and
// straw. A gate of wrought iron, a plate of the owner's colour on each leaf,
// stands between taller piers flying the owner's pennants; a byre of brick
// under a roof of slate shelters the back corner with hay at its door; a
// stone trough with an iron pump holds water; and an ox and two sheep stand
// inside. Its footprint is three tiles square: x and y run from -1.5 to 1.5.

extension IndustrialOldBuildingsPainter {
    mutating func stockPen(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        strawWisps([(-0.6, -0.2, 20), (-0.7, 0.9, -15), (-0.2, 0.4, 10), (0.3, 0.6, 35), (0.9, -0.2, -25), (1.1, 1.0, 5),
                    (-1.2, 1.1, 30), (0.6, -0.6, -10), (-0.3, 0.1, 15), (1.2, 0.4, -30), (0.1, 1.2, 25), (0.2, -0.3, -20)], on: 1.5)
        if complete { pen() } else { penRising() }
    }

    /// Wisps of straw on the ground at fixed places, each turned by its angle.
    mutating func strawWisps(_ places: [(Double, Double, Double)], on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        var d = PathData()
        for (x, y, turn) in places {
            let c = iso(x, y, h)
            let u = P.direction(90 + turn) * 2.6
            d.move(c - u); d.line(c + u)
            d.move(c - u + P(0.8, 1)); d.line(c + u * 0.6 + P(0.8, 1))
        }
        svg.path(d, stroke: .colour(I.strawShade), width: 0.8)
    }

    /// A pier of brick at (x, y), `height` points tall, under a cap of
    /// stone with a ball of stone on it; fresh and uncapped when `raw`.
    private mutating func penPier(_ x: Double, _ y: Double, height: Double, ball: Bool = true, raw: Bool = false) {
        typealias I = IndustrialOldBuildingsInk
        let s = 0.075, h0 = 1.5
        block(x - s, y - s, x + s, y + s, h0, h0 + height, top: .colour(I.brickTop),
              left: .colour(raw ? I.rawBrick : I.brick), right: .colour(raw ? I.rawBrickShade : I.brickShade), width: 0.9)
        for side in [IndustrialOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x - s : x + s, y + s, at: h0) { p in
                p.brickwork(0, 2 * s * 32, 0, height, course: 2.2, brick: 4.8, opacity: 0.35, burnt: false)
            }
        }
        guard !raw else { return }
        block(x - s - 0.02, y - s - 0.02, x + s + 0.02, y + s + 0.02, h0 + height, h0 + height + 2,
              top: .colour(I.stoneTop), left: .colour(I.stoneTop), right: .colour(I.stone), width: 0.8)
        if ball {
            let c = iso(x, y, h0 + height + 2) - P(0, 2.6)
            svg.circle(c + shift * 0.5, 2.6, fill: .colour(I.stoneTop))
            svg.circle(c + P(0.9, 0.7), 1.6, fill: .colour(I.stone))
            svg.circle(c, 2.6, fill: .none, stroke: .colour(I.line), width: 0.8)
        }
    }

    /// Cast-iron railings from (x0, y0) to (x1, y1); only the lower rail
    /// fixed when `levels` holds one height.
    private mutating func penRails(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, levels: [Double] = [5, 10]) {
        typealias I = IndustrialOldBuildingsInk
        if levels.count > 1 {
            railing(x0, y0, x1, y1, on: 1.5, height: 10, step: 2.4)
        } else {
            for h in levels {
                svg.line([iso(x0, y0, 1.5 + h), iso(x1, y1, 1.5 + h)], stroke: .colour(I.line), width: 1.4)
                svg.line([iso(x0, y0, 1.5 + h), iso(x1, y1, 1.5 + h)], stroke: .colour(I.ironLight), width: 0.5)
            }
        }
    }

    private static let byreBox = (x0: -1.32, y0: -1.32, x1: -0.2, y1: -0.76)

    private mutating func pen() {
        let e = 1.4, piers: [Double] = [-1.4, -0.7, 0, 0.7, 1.4]
        for (a, b) in zip(piers, piers.dropFirst()) { penRails(a, -e, b, -e); penRails(-e, a, -e, b) }
        for p in piers { penPier(p, -e, height: 12) }
        for p in piers.dropFirst() { penPier(-e, p, height: 12) }
        byre(complete: true)
        stoneTrough()
        sheep(at: iso(0.75, -0.5, 1.5), facing: -1)
        ox(at: iso(0.1, 0.2, 1.5))
        sheep(at: iso(-0.95, 0.15, 1.5), facing: 1)
        // The front left side, with the gate in its middle.
        let gate = (-0.32, 0.32)
        penRails(-e, e, gate.0, e)
        penRails(gate.1, e, e, e)
        plankGate(gate.0, gate.1, e)
        for p in [-0.7, 0.7] { penPier(p, e, height: 12) }
        for x in [gate.0, gate.1] { penPier(x, e, height: 17, ball: false) }
        pennant(at: iso(gate.0, e, 20.5), height: 13, length: 14)
        pennant(at: iso(gate.1, e, 20.5), height: 13, length: 14)
        // The front right side.
        for (a, b) in zip(piers, piers.dropFirst()) { penRails(e, a, e, b) }
        for p in piers.dropFirst() { penPier(e, p, height: 12) }
    }

    /// A gate of wrought iron between x0 and x1 on the side at y, in two
    /// leaves: bars with spear points under an arched top rail, scrolls at
    /// the foot, and on each leaf a plate of the owner's colour edged in the
    /// light colour and charged with the cog.
    private mutating func plankGate(_ x0: Double, _ x1: Double, _ y: Double) {
        typealias I = IndustrialOldBuildingsInk
        wall(.left, from: x0, y, at: 1.5) { p in
            let w = (x1 - x0) * 32, half = w / 2
            for (a, b) in [(1.0, half - 0.3), (half + 0.3, w - 1)] {
                var bars = PathData()
                var u = a + 1
                while u < b - 0.4 {
                    let rise = 2.6 * sin((u - a) / (b - a) * .pi)
                    bars.move(p.uv(u, 0.6)); bars.line(p.uv(u, 12 + rise))
                    u += 1.7
                }
                p.svg.path(bars, stroke: .colour(I.line), width: 0.7)
                let (r0, r1, r2) = (p.uv(a, 12), p.uv((a + b) / 2, 15.2), p.uv(b, 12))
                p.line(width: 1.3) { d in d.move(r0); d.quad(r1, r2) }
                for v in [1.2, 6.6] { p.line([p.uv(a, v), p.uv(b, v)], width: 1.1) }
                p.line([p.uv(a, 0.4), p.uv(a, 12.4)], width: 1.3)
                p.line([p.uv(b, 0.4), p.uv(b, 12.4)], width: 1.3)
                let c = (a + b) / 2
                p.shape(p.panel(c - 4, 7.6, c + 4, 11.8), .colour(I.light), width: 0.5)
                p.shape(p.panel(c - 3.2, 8.3, c + 3.2, 11.1), .team, width: 0.5)
                p.cog(at: p.uv(c, 9.7), radius: 0.8)
            }
        }
    }

    /// The byre at the back corner: a shed of brick under a gabled roof of
    /// slate, open at its door with hay inside; or, being built, its first
    /// courses and the timber of its door frame standing.
    private mutating func byre(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.byreBox
        let h0 = 1.5, eave = 21.0
        let length = (x1 - x0) * 32, depth = (y1 - y0) * 32
        guard complete else {
            shell(x0, y0, x1, y1, from: h0, floor: h0, to: h0 + 8, thickness: 0.06, lit: .colour(I.rawBrick),
                  shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.earthShade))
            wall(.left, from: x0, y1, at: h0) { p in
                p.brickwork(0, length, 0, 8, opacity: 0.4, burnt: false)
                p.shape(p.panel(13, 0, 23, 8), .colour(I.dark), width: 0.8)
            }
            wall(.right, from: x1, y1, at: h0) { p in p.brickwork(0, depth, 0, 8, opacity: 0.4, burnt: false) }
            pole(iso(-0.9, y1, h0 + 8), iso(-0.9, y1, h0 + 15), width: 1.6, colour: I.timberLight)
            pole(iso(-0.59, y1, h0 + 8), iso(-0.59, y1, h0 + 15), width: 1.6, colour: I.timberLight)
            pole(iso(-0.92, y1, h0 + 15), iso(-0.57, y1, h0 + 15), width: 1.6, colour: I.timberLight)
            return
        }
        shadow([iso(x1, y0, h0), iso(x1 + 0.24, y0 + 0.12, h0), iso(x1 + 0.24, y1 + 0.1, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, eave, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, length, 2), .colour(I.footing), width: 0.5)
            p.brickwork(0, length, 2, eave - h0)
            p.casement(4, 8, w: 5, h: 6, lights: 1, frame: I.brick)
            p.casement(29, 8, w: 5, h: 6, lights: 1, frame: I.brick)
            // The door, open, with hay in the dark within.
            p.shape(p.panel(13, 0, 23, 14), .colour(I.dark), width: 0.9)
            func at(_ u: Double, _ v: Double) -> P { P(u, -v) }
            p.colour(.colour(I.straw)) { d, o in
                d.move(at(13, 0) + o); d.line(at(13, 6) + o); d.quad(at(16, 9) + o, at(19, 7) + o)
                d.quad(at(21.5, 8.6) + o, at(23, 6) + o); d.line(at(23, 0) + o); d.close()
            }
            p.line([p.uv(15, 3), p.uv(16, 6.6)], width: 0.45)
            p.line([p.uv(19.4, 2.4), p.uv(20.2, 5.8)], width: 0.45)
            p.shape(p.panel(23.2, 0.4, 27.6, 13.6), .colour(I.timberLight), width: 0.7)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, depth, 2), .colour(I.footingShade), width: 0.5)
            p.brickwork(0, depth, 2, eave - h0)
        }
        gableAlongX(x0, y0, x1, y1, eave: eave, ridge: eave + 12, over: 0.06, gableWall: .colour(I.brickShade)) { p, w, r in
            p.gableBrickwork(w, r)
            p.svg.circle(p.uv(w / 2 - 4, r * 0.35), 1.6, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// A trough of stone holding water, along the back right side, filled by an iron pump.
    private mutating func stoneTrough() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = (0.25, -1.28, 1.1, -1.08)
        block(x0, y0, x1, y1, 1.5, 6, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.9)
        shape(level(x0 + 0.04, y0 + 0.04, x1 - 0.04, y1 - 0.04, 6), .colour(I.glass), width: 0.7)
        line([iso(x0 + 0.2, y0 + 0.1, 6), iso(x0 + 0.45, y0 + 0.1, 6)], width: 0.5, opacity: 0.7)
        // The pump of cast iron at the trough's end: a fluted barrel, a spout, a handle.
        let foot = iso(x1 + 0.1, (y0 + y1) / 2, 1.5)
        shape([foot + P(-1.8, 0), foot + P(-1.4, -15), foot + P(1.4, -15), foot + P(1.8, 0)], .colour(I.green), width: 0.7)
        svg.line([foot + P(-0.6, -1), foot + P(-0.5, -14)], stroke: .colour(I.greenLight), width: 0.5)
        svg.ellipse(foot - P(0, 15.6), 2.2, 1, fill: .colour(I.greenShade), stroke: .colour(I.line), width: 0.5)
        svg.circle(foot - P(0, 17), 1, fill: .colour(I.green), stroke: .colour(I.line), width: 0.4)
        shape([foot + P(-1.4, -10), foot + P(-5, -8.6), foot + P(-5.4, -7.2), foot + P(-1.4, -8.6)], .colour(I.green), width: 0.5)
        line([foot + P(1.2, -14), foot + P(6, -19), foot + P(7.4, -18.4)], width: 1)
    }

    /// The pen being built: piers of brick raised at the corners and the
    /// gate, the first rail along the back, the byre's walls begun, the
    /// owner's pennant on the gate's pier, and bricks, timber and mortar to hand.
    private mutating func penRising() {
        typealias I = IndustrialOldBuildingsInk
        let e = 1.4
        penRails(-e, -e, 0.7, -e, levels: [5])
        penRails(-e, -e, -e, 0, levels: [5])
        penPier(-e, -e, height: 12)
        penPier(0, -e, height: 12)
        penPier(0.7, -e, height: 7, raw: true)
        penPier(-e, -0.7, height: 12)
        penPier(-e, 0, height: 6, raw: true)
        byre(complete: false)
        bricks(0.3, -0.5, 0.6, -0.2, from: 1.5, height: 5)
        timbers(-0.6, 0.3, length: 1.0, on: 1.5)
        basket(at: iso(0.75, 0.45, 1.5), size: 1)
        bricks(-0.85, 0.3, -0.6, 0.55, from: 1.5, height: 4)
        penPier(e, -e, height: 9, raw: true)
        penPier(-0.32, e, height: 17, ball: false)
        penPier(0.32, e, height: 10, raw: true)
        penPier(e, e, height: 5, raw: true)
        pennant(at: iso(-0.32, e, 20.5), height: 13, length: 14)
        // The gate's iron leaves, waiting against the front.
        wall(.left, from: 0.5, e + 0.05, at: 1.5) { p in
            var bars = PathData()
            var u = 1.2
            while u < 16 { bars.move(p.uv(u, 0.3)); bars.line(p.uv(u + 1.4, 6.6)); u += 1.8 }
            p.svg.path(bars, stroke: .colour(I.line), width: 0.7)
            p.line([p.uv(0, 0.6), p.uv(16, 0.6)], width: 1.1)
            p.line([p.uv(1.4, 6.4), p.uv(17.4, 6.4)], width: 1.1)
        }
    }
}
