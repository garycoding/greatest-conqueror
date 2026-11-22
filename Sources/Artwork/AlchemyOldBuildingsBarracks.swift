// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age barracks: the Iron age's hall grown into a garrison. Its
// ground floor is of dressed stone, pierced by loops for guns and hung with
// heater shields in the owner's colour; its upper floor, where the soldiers
// sleep, is half-timbered in oak with leaded windows, under a steep hipped
// roof of slate with gilt finials. It is entered by an arched gate of oak
// studded with iron between two crenellated towers, and a great banner of
// the owner's colour hangs over the gate. In the yard stand a rack of pikes
// and halberds, an archery butt of straw, and the owner's standard. Its
// footprint is three tiles square: x and y run from -1.5 to 1.5.

extension AlchemyOldBuildingsPainter {
    mutating func barracks(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 2, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        if complete { garrison() } else { garrisonRising() }
    }

    private static let garrisonBox = (x0: -1.38, y0: -1.38, x1: 1.02, y1: 0.12)
    private static let gateTowers: [(x0: Double, x1: Double)] = [(-0.68, -0.36), (0.14, 0.46)]
    private static let gateTowerFront = 0.4

    /// The stone ground floor's wall drawn with `wall`, `length` long and `height` tall.
    private mutating func garrisonStone(_ length: Double, _ height: Double, quoinAtStart: Bool) {
        typealias I = AlchemyOldBuildingsInk
        colour(panel(0, 0, length, 3), .colour(I.footing))
        line([uv(0, 3), uv(length, 3)], width: 0.6)
        courses(0, length, 3, height, course: 3.9, brick: 9.6)
        quoins(at: quoinAtStart ? 0 : length, atStart: quoinAtStart, from: 3, to: height, course: 3.9)
    }

    /// A loop for a gun on a wall drawn with `wall`: a slit ending in a round, at (`u`, `v`).
    private mutating func gunLoop(_ u: Double, _ v: Double) {
        typealias I = AlchemyOldBuildingsInk
        shape(panel(u - 0.6, v + 1.2, u + 0.6, v + 7), .colour(I.dark), width: 0.5)
        svg.circle(uv(u, v + 1), 1.3, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
    }

    private mutating func garrison() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.garrisonBox
        let h0 = 2.0, f = 20.0, e = 36.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        let g0 = (Self.gateTowers[0].x1 - x0) * 32, g1 = (Self.gateTowers[1].x0 - x0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, f, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.garrisonStone(front, f - h0, quoinAtStart: false)
            p.door((g0 + g1) / 2, 0, w: g1 - g0 - 5, h: 15, paint: I.oakLight)
            for u in [7.0, 16.0] { p.shield(u, 11, w: 6, h: 7.4) }
            for u in [front - 19.0, front - 10] { p.shield(u, 11, w: 6, h: 7.4) }
            for u in [11.5, front - 14.5] { p.gunLoop(u, 3.6) }
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.garrisonStone(side, f - h0, quoinAtStart: true)
            for u in stride(from: 8.0, to: side - 4, by: 12) { p.gunLoop(u, 5) }
        }
        block(x0, y0, x1, y1, f, e, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        wall(.left, from: x0, y1, at: f) { p in
            let posts = stride(from: 1.0, through: front - 1, by: (front - 2) / 8).map { $0 }
            p.framing(front, from: 0, to: e - f, posts: posts, rail: 6, braces: [(0, true), (1, false), (6, true), (7, false)])
            for k in [2, 5] { p.casement(posts[k] + 1.6, 6.6, w: posts[k + 1] - posts[k] - 3.2, h: 7, lights: 2) }
            p.paintedBand(0, front, 0.6, 2.6)
        }
        wall(.right, from: x1, y1, at: f) { p in
            p.framing(side, from: 0, to: e - f, posts: [1, 12.8, 24.6, 36.4, side - 1], rail: 6, braces: [(0, true), (3, false)])
            p.casement(14.4, 6.6, w: 8.6, h: 7, lights: 2)
            p.casement(26.2, 6.6, w: 8.6, h: 7, lights: 2)
            p.paintedBand(0, side, 0.6, 2.6)
        }
        shadow([iso(x0, y1, e - 2.2), iso(x1, y1, e - 2.2), iso(x1, y1, e), iso(x0, y1, e)], opacity: 0.12)
        shadow([iso(x1, y1, e - 2.2), iso(x1, y0, e - 2.2), iso(x1, y0, e), iso(x1, y1, e)], opacity: 0.12)
        hippedRoof(x0, y0, x1, y1, eaves: e, rise: 30, overhang: 0.07)
        // The towers either side of the gate, and the banner hung between them.
        for tower in Self.gateTowers { gateTower(tower.x0, y1, tower.x1, Self.gateTowerFront, from: h0, complete: true) }
        wall(.left, from: x0, y1 + 0.01, at: h0) { p in p.banner((g0 + g1) / 2, top: f + 12, width: 11, length: 15) }
        pikeRack(-1.15, 0.95)
        archeryButt(at: iso(0.72, 0.98, h0))
        standard(at: iso(1.22, 0.62, h0), height: 56)
    }

    /// A tower from (x0, y0) to (x1, y1), standing out before the hall's wall,
    /// of dressed stone with quoins and a loop, crenellated at its top.
    private mutating func gateTower(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double, complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let h1 = complete ? 44.0 : 14.0
        block(x0, y0, x1, y1, h0, h1, top: complete ? nil : .colour(I.rawStoneTop), left: .colour(complete ? I.stone : I.rawStone),
              right: .colour(complete ? I.stoneShade : I.rawStoneShade), width: 1.1)
        let w = (x1 - x0) * 32, d = (y1 - y0) * 32
        wall(.left, from: x0, y1, at: h0) { p in
            p.colour(p.panel(0, 0, w, 3), .colour(complete ? I.footing : I.rawStoneShade))
            p.line([p.uv(0, 3), p.uv(w, 3)], width: 0.6)
            p.courses(0, w, 3, h1 - h0, course: 3.9, brick: 9.6)
            guard complete else { return }
            p.quoins(at: 0, atStart: true, from: 3, to: h1 - h0 - 2, course: 3.9)
            p.gunLoop(w / 2 + 1.5, 9)
            p.shape(p.panel(w / 2 - 0.7, 26, w / 2 + 2.3, 33), .colour(I.dark), width: 0.6)
            p.shape(p.panel(-0.3, h1 - h0 - 2, w + 0.3, h1 - h0), .colour(I.stoneTop), width: 0.6)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.colour(p.panel(0, 0, d, 3), .colour(complete ? I.footingShade : I.rawStoneShade))
            p.line([p.uv(0, 3), p.uv(d, 3)], width: 0.6)
            p.courses(0, d, 3, h1 - h0, course: 3.9, brick: 9.6)
            guard complete else { return }
            p.shape(p.panel(-0.3, h1 - h0 - 2, d + 0.3, h1 - h0), .colour(I.stone), width: 0.6)
        }
        guard complete else { return }
        colour(level(x0, y0, x1, y1, h1), .colour(I.footing))
        line(level(x0, y0, x1, y1, h1), closed: true, width: 0.9)
        battlements(x0, y0, x1, y1, on: h1, count: 2, height: 5, front: false)
        battlements(x0, y0, x1, y1, on: h1, count: 2, height: 5, front: true)
    }

    /// A rack of pikes and halberds with iron heads, its foot at (x, y), along x.
    private mutating func pikeRack(_ x: Double, _ y: Double) {
        typealias I = AlchemyOldBuildingsInk
        let h0 = 2.0, length = 0.55
        pole(iso(x, y, h0), iso(x, y, h0 + 12), width: 1.3, colour: I.oak)
        for i in 0..<6 {
            let along = x + length * (0.1 + Double(i) * 0.16)
            let foot = iso(along, y - 0.06, h0), head = iso(along + 0.015, y - 0.1, h0 + 34)
            svg.line([foot, head], stroke: .colour(I.line), width: 1.5)
            svg.line([foot, head], stroke: .colour(I.timberLight), width: 0.7)
            shape([head, head + P(1, 3), head + P(0, 5.6), head + P(-1, 3)], .colour(I.ironLight), width: 0.55)
            if i % 2 == 1 {
                // A halberd: an axe blade and a hook below the spike.
                shape([head + P(0.4, 5.6), head + P(4.2, 4.6), head + P(4.6, 9.4), head + P(0.4, 9)], .colour(I.ironLight), width: 0.55)
                line([head + P(-0.4, 6.4), head + P(-2.6, 5.2)], width: 0.8)
            }
        }
        pole(iso(x + length, y, h0), iso(x + length, y, h0 + 12), width: 1.3, colour: I.oak)
        pole(iso(x - 0.04, y, h0 + 10), iso(x + length + 0.04, y, h0 + 10), width: 1.3, colour: I.oakLight)
    }

    /// An archery butt standing at `p` on the screen: a round of bound straw
    /// on a trestle, painted in rings, with arrows in it.
    private mutating func archeryButt(at p: P) {
        typealias I = AlchemyOldBuildingsInk
        svg.ellipse(p + P(0, 0.6), 7, 2, fill: .colour("#000000"), opacity: 0.14)
        pole(p + P(-4, 0), p + P(-1, -14), width: 1.2, colour: I.oak)
        pole(p + P(4, 0), p + P(1, -14), width: 1.2, colour: I.oak)
        let c = p - P(0, 13)
        svg.ellipse(c + shift * 0.5, 6.2, 7.4, fill: .colour(I.straw))
        svg.ellipse(c, 6.2, 7.4, fill: .none, stroke: .colour(I.line), width: 0.9)
        svg.ellipse(c, 4.4, 5.3, fill: .colour(I.light), stroke: .colour(I.line), width: 0.5)
        svg.ellipse(c, 2.6, 3.2, fill: .colour(I.teal), stroke: .colour(I.line), width: 0.5)
        svg.ellipse(c, 1, 1.2, fill: .colour(I.dark))
        for (dx, dy, k) in [(1.4, -2.0, 1.0), (-2.2, 1.6, -1.0), (0.4, 3.4, 1.0)] {
            let a = c + P(dx, dy)
            line([a, a + P(4 * k, -1.6)], width: 0.7)
            line([a + P(4 * k, -1.6), a + P(5 * k, -2.6)], width: 0.5)
            line([a + P(4 * k, -1.6), a + P(5.2 * k, -0.8)], width: 0.5)
        }
    }

    /// The owner's standard standing at `p` on the screen: a tall pole under
    /// an iron spearhead, a crossbar, and from it a long banner of the owner's colour.
    private mutating func standard(at p: P, height: Double) {
        typealias I = AlchemyOldBuildingsInk
        let top = p - P(0, height)
        svg.ellipse(p + P(0, 0.4), 4, 1.4, fill: .colour("#000000"), opacity: 0.14)
        svg.line([p, top], stroke: .colour(I.line), width: 2.7)
        svg.line([p, top], stroke: .colour(I.oakLight), width: 1.6)
        let bar = top + P(0, 6)
        let (w, l) = (13.0, 20.0)
        let cloth = [bar + P(-w / 2, 0), bar + P(w / 2, 0), bar + P(w / 2, l), bar + P(w / 4, l - 3), bar + P(0, l),
                     bar + P(-w / 4, l - 3), bar + P(-w / 2, l)]
        shape(cloth, .team, width: 1)
        sun(at: bar + P(0, l * 0.42), radius: w * 0.16)
        pole(bar + P(-w / 2 - 1.6, 0), bar + P(w / 2 + 1.6, 0), width: 1.2, colour: I.oak)
        for s in [-1.0, 1.0] { svg.circle(bar + P(s * (w / 2 + 1.6), 0), 0.9, fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.4) }
        shape([top + P(-1.5, 0.4), top + P(0, -5.4), top + P(1.5, 0.4)], .colour(I.ironLight), width: 0.7)
    }

    /// The barracks being built: the ground floor's walls of fresh stone half
    /// raised round the gate's opening, the towers begun, scaffolding with the
    /// owner's pennant, and stone, oak and slates to hand.
    private mutating func garrisonRising() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.garrisonBox
        let h0 = 2.0, top = 15.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.1, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.earth)) { p in
            p.blocks(-0.9, -0.9, -0.6, -0.6, from: h0, courses: 2)
            p.basket(at: p.iso(-0.2, -0.6, h0), size: 0.9)
            p.timbers(0.0, -1.2, length: 0.8, on: h0)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, front, 0, top - h0, course: 3.9, brick: 9.6)
            let g0 = (Self.gateTowers[0].x1 - x0) * 32, g1 = (Self.gateTowers[1].x0 - x0) * 32
            p.shape(p.panel(g0 + 2, 0, g1 - 2, top - h0), .colour(I.dark), width: 1)
        }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, side, 0, top - h0, course: 3.9, brick: 9.6) }
        blocks(x0, y0, x0 + 0.1, y0 + 0.9, from: top, courses: 1)
        blocks(x0 + 0.1, y0, 0.2, y0 + 0.1, from: top, courses: 1)
        for tower in Self.gateTowers { gateTower(tower.x0, y1, tower.x1, Self.gateTowerFront, from: h0, complete: false) }
        scaffold([(x1 + 0.14, 0.05), (x1 + 0.14, -0.6), (x1 + 0.14, -1.25)], from: h0, height: 28, levels: [10, 20], boards: 10)
        pennant(at: iso(x1 + 0.14, 0.05, h0 + 28), height: 12, length: 13)
        blocks(0.55, 0.72, 0.85, 1.0, from: h0, courses: 2)
        slates(0.95, 0.75, 1.2, 1.05, from: h0, height: 6)
        timbers(-0.3, 1.05, length: 0.8, on: h0)
        ladder(foot: iso(-1.0, 0.62, h0), iso(-0.84, 0.62, h0), head: iso(-1.0, y1 + 0.02, top + 3), iso(-0.84, y1 + 0.02, top + 3),
               rungs: 5)
        barrel(at: iso(-1.2, 1.2, h0), size: 0.9)
    }
}
