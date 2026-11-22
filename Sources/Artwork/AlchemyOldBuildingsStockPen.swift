// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age stock pen: the Iron age's pen grown one age richer. Rails of
// oak run between piers of dressed stone under moulded caps, round a floor of
// beaten earth and straw. A gate of planks hung on iron straps, a band of the
// owner's colour across it, stands between taller piers flying the owner's
// pennants; a byre half-timbered in oak under a steep roof of slate, with a
// gilt finial, shelters the back corner with hay at its door; a stone trough
// holds water; and an ox and two sheep stand inside. Its footprint is three
// tiles square: x and y run from -1.5 to 1.5.

extension AlchemyOldBuildingsPainter {
    mutating func stockPen(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        strawWisps([(-0.6, -0.2, 20), (-0.7, 0.9, -15), (-0.2, 0.4, 10), (0.3, 0.6, 35), (0.9, -0.2, -25), (1.1, 1.0, 5),
                    (-1.2, 1.1, 30), (0.6, -0.6, -10), (-0.3, 0.1, 15), (1.2, 0.4, -30), (0.1, 1.2, 25), (0.2, -0.3, -20)], on: 1.5)
        if complete { pen() } else { penRising() }
    }

    /// Wisps of straw on the ground at fixed places, each turned by its angle.
    mutating func strawWisps(_ places: [(Double, Double, Double)], on h: Double) {
        typealias I = AlchemyOldBuildingsInk
        var d = PathData()
        for (x, y, turn) in places {
            let c = iso(x, y, h)
            let u = P.direction(90 + turn) * 2.6
            d.move(c - u); d.line(c + u)
            d.move(c - u + P(0.8, 1)); d.line(c + u * 0.6 + P(0.8, 1))
        }
        svg.path(d, stroke: .colour(I.strawShade), width: 0.8)
    }

    /// A pier of dressed stone at (x, y), `height` points tall, its courses
    /// jointed, under a moulded cap with a ball of stone on it.
    private mutating func penPier(_ x: Double, _ y: Double, height: Double, ball: Bool = true, raw: Bool = false) {
        typealias I = AlchemyOldBuildingsInk
        let s = 0.075, h0 = 1.5
        block(x - s, y - s, x + s, y + s, h0, h0 + height, top: .colour(raw ? I.rawStoneTop : I.stoneTop),
              left: .colour(raw ? I.rawStone : I.stone), right: .colour(raw ? I.rawStoneShade : I.stoneShade), width: 0.9)
        var v = 4.4
        while v < height - 1 {
            line([iso(x - s, y + s, h0 + v), iso(x + s, y + s, h0 + v), iso(x + s, y - s, h0 + v)], width: 0.45, opacity: 0.7)
            v += 4.4
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

    /// Two rails of oak from (x0, y0) to (x1, y1).
    private mutating func penRails(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, levels: [Double] = [5, 10]) {
        for h in levels { pole(iso(x0, y0, 1.5 + h), iso(x1, y1, 1.5 + h), width: 1.5, colour: AlchemyOldBuildingsInk.oakLight) }
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

    /// A gate of planks between x0 and x1 on the side at y, hung on straps of
    /// iron, with a band of the owner's colour painted across it.
    private mutating func plankGate(_ x0: Double, _ x1: Double, _ y: Double) {
        typealias I = AlchemyOldBuildingsInk
        wall(.left, from: x0, y, at: 1.5) { p in
            let w = (x1 - x0) * 32
            p.shape(p.panel(0, 0.6, w, 13), .colour(I.timberLight), width: 0.9)
            var u = w / 5
            while u < w - 0.5 { p.line([p.uv(u, 0.9), p.uv(u, 12.7)], width: 0.5); u += w / 5 }
            p.paintedBand(0.4, w - 0.4, 8.4, 10.6)
            p.line([p.uv(1.2, 2), p.uv(w - 1.2, 7.2)], width: 0.9)
            for v in [3.4, 12] {
                p.shape(p.panel(0.4, v - 0.6, 5.2, v + 0.6), .colour(I.iron), width: 0.5)
                p.shape(p.panel(w - 5.2, v - 0.6, w - 0.4, v + 0.6), .colour(I.iron), width: 0.5)
            }
        }
    }

    /// The byre at the back corner: a half-timbered shed under a gabled roof
    /// of slate, open at its door with hay inside; or, being built, its sill
    /// and posts standing.
    private mutating func byre(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.byreBox
        let h0 = 1.5, eave = 21.0
        let length = (x1 - x0) * 32, depth = (y1 - y0) * 32
        guard complete else {
            for x in [x0 + 0.03, -0.76, x1 - 0.03] {
                pole(iso(x, y1 - 0.03, h0), iso(x, y1 - 0.03, eave), width: 2, colour: I.oak)
            }
            pole(iso(x1 - 0.03, y0 + 0.03, h0), iso(x1 - 0.03, y0 + 0.03, eave), width: 2, colour: I.oak)
            pole(iso(x0, y1 - 0.03, eave), iso(-0.76, y1 - 0.03, eave), width: 2, colour: I.oak)
            beam(x0, y1 - 0.03, x1, y1 - 0.03, on: h0, size: 2.2)
            return
        }
        shadow([iso(x1, y0, h0), iso(x1 + 0.24, y0 + 0.12, h0), iso(x1 + 0.24, y1 + 0.1, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, eave, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.framing(length, from: 0, to: eave - h0, posts: [1, 12, 24, length - 1], rail: 9, braces: [(0, true), (2, false)])
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
            p.framing(depth, from: 0, to: eave - h0, posts: [1, depth - 1], rail: 9, braces: [(0, true)])
        }
        gableAlongX(x0, y0, x1, y1, eave: eave, ridge: eave + 12, over: 0.06, gableWall: .colour(I.light)) { p, w, r in
            p.timber(p.uv(w / 2, 0), p.uv(w / 2, r - 1), width: 1.6)
            p.timber(p.uv(1, 1), p.uv(w - 1, 1), width: 1.8)
            p.svg.circle(p.uv(w / 2 - 4, r * 0.35), 1.6, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// A trough of stone holding water, along the back right side.
    private mutating func stoneTrough() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = (0.25, -1.28, 1.1, -1.08)
        block(x0, y0, x1, y1, 1.5, 6, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.9)
        shape(level(x0 + 0.04, y0 + 0.04, x1 - 0.04, y1 - 0.04, 6), .colour(I.glass), width: 0.7)
        line([iso(x0 + 0.2, y0 + 0.1, 6), iso(x0 + 0.45, y0 + 0.1, 6)], width: 0.5, opacity: 0.7)
    }

    /// The pen being built: piers raised at the corners and the gate, the
    /// first rails along the back, the byre's frame begun, the owner's pennant
    /// on the gate's pier, and stone, oak and mortar to hand.
    private mutating func penRising() {
        typealias I = AlchemyOldBuildingsInk
        let e = 1.4
        penRails(-e, -e, 0.7, -e, levels: [5])
        penRails(-e, -e, -e, 0, levels: [5])
        penPier(-e, -e, height: 12)
        penPier(0, -e, height: 12)
        penPier(0.7, -e, height: 7, raw: true)
        penPier(-e, -0.7, height: 12)
        penPier(-e, 0, height: 6, raw: true)
        byre(complete: false)
        blocks(0.3, -0.5, 0.6, -0.2, from: 1.5, courses: 2)
        timbers(-0.6, 0.3, length: 1.0, on: 1.5)
        basket(at: iso(0.75, 0.45, 1.5), size: 1)
        blocks(-0.85, 0.3, -0.6, 0.55, from: 1.5, courses: 1)
        penPier(e, -e, height: 9, raw: true)
        penPier(-0.32, e, height: 17, ball: false)
        penPier(0.32, e, height: 10, raw: true)
        penPier(e, e, height: 5, raw: true)
        pennant(at: iso(-0.32, e, 20.5), height: 13, length: 14)
        // The gate's planks, waiting against the front.
        wall(.left, from: 0.5, e + 0.05, at: 1.5) { p in
            p.shape([p.uv(0, 0), p.uv(16, 0), p.uv(17.6, 6.8), p.uv(1.6, 6.8)], .colour(I.timberLight), width: 0.9)
            p.line([p.uv(5.6, 0.3), p.uv(6.6, 6.5)], width: 0.5)
            p.line([p.uv(11, 0.3), p.uv(12, 6.5)], width: 0.5)
        }
    }
}
