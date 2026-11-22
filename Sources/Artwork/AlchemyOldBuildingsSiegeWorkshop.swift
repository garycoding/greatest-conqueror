// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age siege workshop: the Iron age's shed grown into a gun
// works. A long shed of oak posts, braced at the head and open at the front,
// stands under a steep roof of slate with gilt finials; at its back a forge
// of stone glows, its chimney rising through the roof. Before it a cannon of
// iron lies finished on its carriage, a pyramid of shot beside it; a crane of
// shear legs lifts a beam, flying the owner's pennant, and a banner of the
// owner's colour hangs from the shed's front. Its footprint is three tiles
// square: x and y run from -1.5 to 1.5.

extension AlchemyOldBuildingsPainter {
    mutating func siegeWorkshop(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        strawWisps([(-0.9, 0.6, 20), (-0.2, 0.9, -40), (0.4, 0.5, 60), (1.0, 1.1, 10), (-1.1, 1.2, -20), (1.2, 0.2, 35)], on: 1.5)
        if complete { gunWorks() } else { gunWorksRising() }
    }

    private static let worksBox = (x0: -1.36, y0: -1.36, x1: 0.62, y1: -0.1)
    private static let worksEave = 36.0
    private static let worksRidge = 56.0
    private static let worksPostsX: [Double] = [-1.32, -0.37, 0.58]
    private static let worksPostsY: [Double] = [-1.32, -0.14]

    /// A squared post of oak at (x, y), from `h0` to `h1`, on a pad of stone.
    private mutating func worksPost(_ x: Double, _ y: Double, from h0: Double, to h1: Double) {
        typealias I = AlchemyOldBuildingsInk
        let s = 0.05
        block(x - 0.08, y - 0.08, x + 0.08, y + 0.08, h0, h0 + 2.4, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.7)
        block(x - s, y - s, x + s, y + s, h0 + 2.4, h1, top: nil, left: .colour(I.oakLight), right: .colour(I.oak), width: 0.9)
    }

    /// A brace from a post's head at `a` toward `b`, both on the map, under the plate at `eave`.
    private mutating func worksBrace(from a: (Double, Double), toward b: (Double, Double), eave: Double) {
        pole(iso(a.0, a.1, eave - 10), iso(b.0, b.1, eave - 1), width: 1.5, colour: AlchemyOldBuildingsInk.oak)
    }

    /// The forge at the back of the shed: a hearth of stone with its fire, and
    /// its chimney, rising to `top` points, through where the roof will be.
    private mutating func forge(top: Double, lit: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let h0 = 1.5, (x0, y0, x1, y1) = (-1.28, -1.28, -0.86, -0.92)
        block(-1.24, -1.24, -1.04, -1.06, h0, top, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade),
              width: 0.9)
        wall(.left, from: -1.24, -1.06, at: h0) { p in p.courses(0, 6.4, 0, top - h0, course: 3.4, brick: 6.4, opacity: 0.5) }
        block(-1.26, -1.26, -1.02, -1.04, top, top + 1.6, top: .colour(I.dark), left: .colour(I.stoneTop), right: .colour(I.stone),
              width: 0.8)
        block(x0, y0, x1, y1, h0, h0 + 10, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in
            let w = (x1 - x0) * 32
            p.courses(0, w, 0, 10, course: 3.4, brick: 6.4, opacity: 0.5)
            p.arch(w / 2, 1.6, width: 7, height: 6.4, .colour(I.dark), line: 0.8)
            if lit {
                p.svg.ellipse(p.uv(w / 2, 3.2), 2.8, 1.6, fill: .colour(I.clay))
                p.svg.ellipse(p.uv(w / 2, 3.4), 1.6, 1, fill: .colour(I.giltLight))
            }
        }
    }

    private mutating func gunWorks() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.worksBox
        let h0 = 1.5, eave = Self.worksEave
        shadow(level(x0, y0, x1 + 0.3, y1 + 0.22, h0), opacity: 0.16)
        forge(top: Self.worksRidge + 6, lit: true)
        // The posts along the back and the left end, their plates and braces.
        for x in Self.worksPostsX { worksPost(x, Self.worksPostsY[0], from: h0, to: eave) }
        worksPost(Self.worksPostsX[0], Self.worksPostsY[1], from: h0, to: eave)
        pole(iso(x0, Self.worksPostsY[0], eave), iso(x1, Self.worksPostsY[0], eave), width: 2.4, colour: I.oak)
        pole(iso(Self.worksPostsX[0], y0, eave), iso(Self.worksPostsX[0], y1, eave), width: 2.4, colour: I.oak)
        for (a, b) in zip(Self.worksPostsX, Self.worksPostsX.dropFirst()) {
            worksBrace(from: (a, Self.worksPostsY[0]), toward: (a + 0.26, Self.worksPostsY[0]), eave: eave)
            worksBrace(from: (b, Self.worksPostsY[0]), toward: (b - 0.26, Self.worksPostsY[0]), eave: eave)
        }
        // Barrels of powder and stacked oak under the roof.
        barrel(at: iso(-0.2, -1.1, h0), size: 0.9)
        barrel(at: iso(0.05, -1.0, h0), size: 0.9)
        timbers(-0.75, -0.62, length: 0.7, on: h0)
        // The front: the posts at its ends, the plate, and the banner hung from it.
        let front = Self.worksPostsY[1], end = Self.worksPostsX[2]
        worksPost(end, front, from: h0, to: eave)
        pole(iso(end, y0, eave), iso(end, y1, eave), width: 2.4, colour: I.oak)
        pole(iso(x0, front, eave), iso(x1, front, eave), width: 2.4, colour: I.oak)
        worksBrace(from: (Self.worksPostsX[0], front), toward: (Self.worksPostsX[0] + 0.3, front), eave: eave)
        worksBrace(from: (end, front), toward: (end - 0.3, front), eave: eave)
        worksBrace(from: (end, front), toward: (end, front - 0.3), eave: eave)
        wall(.left, from: x0, y1, at: h0) { p in p.banner(13, top: eave - 9, width: 9, length: 15) }
        gableAlongX(x0, y0, x1, y1, eave: eave, ridge: Self.worksRidge, over: 0.1, gableWall: .colour(I.light)) { p, w, rise in
            p.timber(p.uv(w / 2, 0), p.uv(w / 2, rise - 1.2), width: 1.8)
            p.timber(p.uv(w * 0.2, rise * 0.4), p.uv(w * 0.8, rise * 0.4), width: 1.6)
            p.timber(p.uv(1, 1), p.uv(w - 1, 1), width: 2)
            p.timber(p.uv(w * 0.06, 1.6), p.uv(w * 0.42, rise * 0.4 - 0.6), width: 1.4)
            p.timber(p.uv(w * 0.94, 1.6), p.uv(w * 0.58, rise * 0.4 - 0.6), width: 1.4)
            p.svg.circle(p.uv(w / 2, rise * 0.62), 2.4, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.6)
        }
        cannon(at: (-0.55, 0.42))
        shotPile(at: (0.72, 0.6))
        barrel(at: iso(0.3, 0.98, h0), size: 0.95)
        gunCrane(complete: true)
    }

    /// A cannon of iron on its carriage, its trail at (x, y) on the map and
    /// its muzzle toward +x: two cheeks of oak, two wheels shod with iron,
    /// and the barrel, banded and with a dark bore.
    private mutating func cannon(at place: (Double, Double)) {
        typealias I = AlchemyOldBuildingsInk
        let (x, y) = place, h0 = 1.5, r = 7.2
        let axle = x + 0.62
        svg.ellipse(iso(axle, y, h0) + P(0, 1), 22, 6, fill: .colour("#000000"), opacity: 0.14)
        // The far wheel and the far cheek, then the barrel, then the near cheek and wheel.
        gunWheel(at: (axle, y - 0.16), on: h0, radius: r)
        beam(x, y - 0.1, axle + 0.12, y - 0.1, on: h0 + r - 1, size: 3)
        let a = iso(x + 0.22, y, h0 + r + 3.2), b = iso(axle + 0.5, y, h0 + r + 4.4)
        let (r0, r1) = (3.4, 2.4)
        colour([a + P(0, -r0), b + P(0, -r1), b + P(0, r1), a + P(0, r0)], .colour(I.iron))
        colour([a + P(0, -r0), b + P(0, -r1), b + P(0, -r1 * 0.3), a + P(0, -r0 * 0.3)], .colour(I.ironLight))
        line([a + P(0, -r0), b + P(0, -r1)], width: 0.9)
        line([a + P(0, r0), b + P(0, r1)], width: 0.9)
        for t in [0.12, 0.45, 0.9] {
            let m = a + (b - a) * t, rr = r0 + (r1 - r0) * t + 0.4
            shape([m + P(-0.8, -rr), m + P(0.8, -rr), m + P(0.8, rr), m + P(-0.8, rr)], .colour(I.ironDark), width: 0.5)
        }
        svg.ellipse(b, r1 * 0.62 + 0.4, r1 + 0.4, fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.8)
        svg.ellipse(b, r1 * 0.36, r1 * 0.6, fill: .colour(I.dark))
        svg.circle(a + P(-1.6, 0), 1.6, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.6)
        beam(x, y + 0.1, axle + 0.12, y + 0.1, on: h0 + r - 1, size: 3)
        gunWheel(at: (axle, y + 0.18), on: h0, radius: r)
        // The trail's end on the ground.
        beam(x - 0.12, y - 0.06, x + 0.06, y + 0.12, on: h0, size: 2.2)
    }

    /// A spoked wheel in the plane facing +y, its hub over (x, y) on the map,
    /// its foot on `h`, with a tyre of iron.
    private mutating func gunWheel(at c: (Double, Double), on h: Double, radius r: Double) {
        typealias I = AlchemyOldBuildingsInk
        wall(.left, from: c.0, c.1, at: h) { p in
            let hub = p.uv(0, r)
            p.svg.circle(hub + P(-0.8, 0.6), r, fill: .colour(I.timberLight))
            p.svg.circle(hub, r, fill: .none, stroke: .colour(I.iron), width: 1.6)
            p.svg.circle(hub, r + 0.8, fill: .none, stroke: .colour(I.line), width: 0.6)
            p.svg.circle(hub, r - 0.9, fill: .none, stroke: .colour(I.line), width: 0.5)
            for a in stride(from: 0.0, to: 180, by: 30) {
                let d = P.direction(a) * (r - 0.9)
                p.line([hub + d, hub - d], width: 0.7)
            }
            p.svg.circle(hub, 1.5, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// Round shot of iron stacked in a pyramid at (x, y) on the map.
    private mutating func shotPile(at place: (Double, Double)) {
        typealias I = AlchemyOldBuildingsInk
        let (x, y) = place, h0 = 1.5, r = 2.3, step = 0.072
        var balls: [(Double, Double, Double)] = []
        for layer in 0..<3 {
            let n = 3 - layer
            let off = Double(layer) * step / 2
            for i in 0..<n {
                for j in 0..<n {
                    balls.append((x + off + Double(i) * step, y + off + Double(j) * step, h0 + r + Double(layer) * r * 1.4))
                }
            }
        }
        for (bx, by, bh) in balls.sorted(by: { ($0.2, $0.0 + $0.1) < ($1.2, $1.0 + $1.1) }) {
            let c = iso(bx, by, bh)
            svg.circle(c, r, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.6)
            svg.circle(c + P(-0.7, -0.7), r * 0.35, fill: .colour(I.ironLight))
        }
    }

    /// The crane: shear legs standing beside the shed, stayed back to a stake,
    /// with a windlass between their feet, lifting a beam (or a rafter while
    /// the shed is being built), the owner's pennant at its head.
    private mutating func gunCrane(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let h0 = 1.5, (cx, cy) = (1.05, -0.72), apex = iso(cx, cy, 66)
        let feet = [(1.3, -1.25), (1.3, -0.2)]
        svg.line([apex, iso(1.46, cy, h0)], stroke: .colour(I.line), width: 0.6)
        pole(iso(1.46, cy, h0), iso(1.46, cy, h0 + 5), width: 1.2, colour: I.oak)
        pole(iso(feet[0].0, feet[0].1, h0), apex, width: 2.2, colour: I.oak)
        let drum = (iso(1.3, -1.13, h0 + 7), iso(1.3, -0.32, h0 + 7))
        pole(drum.0, drum.1, width: 3.4, colour: I.timberLight)
        let crank = drum.1
        line([crank, crank + P(2.4, 4), crank + P(4.6, 3)], width: 1.1)
        let hook = iso(cx, cy, 30)
        svg.line([drum.0 + (drum.1 - drum.0) * 0.45, apex], stroke: .colour(I.line), width: 0.6)
        svg.line([apex, hook], stroke: .colour(I.line), width: 0.7)
        svg.circle(apex + P(0, 2.4), 1.8, fill: .colour(I.timberDark), stroke: .colour(I.line), width: 0.6)
        if complete {
            let a = iso(cx, cy - 0.42, 22), b = iso(cx, cy + 0.42, 22)
            svg.line([hook, a + P(0, -3.6)], stroke: .colour(I.line), width: 0.6)
            svg.line([hook, b + P(0, -3.6)], stroke: .colour(I.line), width: 0.6)
            beam(cx, cy - 0.42, cx, cy + 0.42, on: 22, size: 3.6)
        } else {
            pole(hook + P(-1, 2), hook + P(4, 22), width: 2.2, colour: I.oak)
        }
        line([hook, hook + P(0, 2.4), hook + P(1.6, 3.2), hook + P(2.2, 1.6)], width: 1)
        pole(iso(feet[1].0, feet[1].1, h0), apex, width: 2.2, colour: I.oak)
        pennant(at: apex, height: 10, length: 14)
    }

    /// The works being built: the forge's chimney raised, the posts set on
    /// their pads, the plates laid along the back and the left end, the first
    /// rafters raised, the crane lifting another, and oak and slates to hand.
    private mutating func gunWorksRising() {
        typealias I = AlchemyOldBuildingsInk
        let (_, y0, _, y1) = Self.worksBox
        let h0 = 1.5, eave = Self.worksEave, ridge = Self.worksRidge
        let ym = (y0 + y1) / 2
        forge(top: 30, lit: false)
        for x in Self.worksPostsX { worksPost(x, Self.worksPostsY[0], from: h0, to: eave) }
        worksPost(Self.worksPostsX[0], Self.worksPostsY[1], from: h0, to: eave)
        pole(iso(Self.worksBox.x0, Self.worksPostsY[0], eave), iso(Self.worksBox.x1, Self.worksPostsY[0], eave), width: 2.4,
             colour: I.oak)
        pole(iso(Self.worksPostsX[0], y0, eave), iso(Self.worksPostsX[0], y1, eave), width: 2.4, colour: I.oak)
        for x in [Self.worksPostsX[0], Self.worksPostsX[0] + 0.3] {
            pole(iso(x, y0, eave), iso(x, ym, ridge), width: 1.7, colour: I.oak)
            pole(iso(x, y1, eave), iso(x, ym, ridge), width: 1.7, colour: I.oak)
        }
        pole(iso(Self.worksPostsX[0] - 0.05, ym, ridge), iso(Self.worksPostsX[0] + 0.5, ym, ridge), width: 1.9, colour: I.oak)
        timbers(-0.9, -0.3, length: 0.75, on: h0)
        let front = Self.worksPostsY[1], end = Self.worksPostsX[2]
        worksPost(end, front, from: h0, to: eave)
        pole(iso(Self.worksPostsX[0], front, eave), iso(Self.worksPostsX[1], front, eave), width: 2.4, colour: I.oak)
        slates(-1.0, 0.65, -0.45, 0.95, from: h0, height: 7)
        slates(-0.3, 0.7, 0.1, 0.95, from: h0, height: 5)
        timbers(0.05, 1.0, length: 0.75, on: h0)
        sack(at: iso(-1.2, 1.2, h0))
        gunCrane(complete: false)
    }
}
