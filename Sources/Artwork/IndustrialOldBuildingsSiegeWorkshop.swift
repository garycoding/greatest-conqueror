// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age siege workshop: the Alchemy age's gun shed rebuilt as
// a brick works. Its back and its left end are walls of red brick lit by
// round-headed windows, its right end a gable of brick with arched doors for
// the guns and a round window, and its front stands open on columns of cast
// iron carrying a girder, under a roof of slate with a ventilator. At its
// back a forge glows, its square chimney of brick, banded in iron and capped
// in stone, rising high above the roof. Before it a cannon of iron lies
// finished on its carriage, a pyramid of shot beside it; shear legs of iron
// lift a girder, flying the owner's pennant, and a banner of the owner's
// colour hangs from the front girder, over a band of it along the walls.
// Its footprint is three tiles square: x and y run from -1.5 to 1.5.

extension IndustrialOldBuildingsPainter {
    mutating func siegeWorkshop(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
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

    /// A column of cast iron at (x, y), from `h0` to `h1`, on a pad of stone,
    /// with a flared capital.
    private mutating func worksPost(_ x: Double, _ y: Double, from h0: Double, to h1: Double) {
        typealias I = IndustrialOldBuildingsInk
        let s = 0.03
        block(x - 0.07, y - 0.07, x + 0.07, y + 0.07, h0, h0 + 2.4, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.7)
        block(x - 0.045, y - 0.045, x + 0.045, y + 0.045, h0 + 2.4, h0 + 4, top: nil, left: .colour(I.iron), right: .colour(I.ironDark),
              width: 0.6)
        block(x - s, y - s, x + s, y + s, h0 + 4, h1 - 2.6, top: nil, left: .colour(I.iron), right: .colour(I.ironDark), width: 0.7)
        svg.line([iso(x - s * 0.4, y + s, h0 + 4.4), iso(x - s * 0.4, y + s, h1 - 3)], stroke: .colour(I.ironLight), width: 0.4)
        shape([iso(x - s, y + s, h1 - 2.6), iso(x + s, y + s, h1 - 2.6), iso(x + s, y - s, h1 - 2.6), iso(x + 0.07, y - 0.07, h1),
               iso(x + 0.07, y + 0.07, h1), iso(x - 0.07, y + 0.07, h1)], .colour(I.iron), width: 0.6)
    }

    /// A girder of riveted iron on the map from (x0, y0) to (x1, y1) at
    /// `h` points up, `depth` points deep: its web and flanges.
    private mutating func worksGirder(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, at h: Double, depth: Double = 3) {
        typealias I = IndustrialOldBuildingsInk
        let a = iso(x0, y0, h), b = iso(x1, y1, h)
        shape([a, b, b + P(0, depth), a + P(0, depth)], .colour(I.iron), width: 0.7)
        svg.line([a + P(0, 0.7), b + P(0, 0.7)], stroke: .colour(I.ironLight), width: 0.5)
        let d = b - a, length = (d.x * d.x + d.y * d.y).squareRoot()
        var k = 2.2
        while k < length - 1 {
            svg.circle(a + d * (k / length) + P(0, depth / 2 + 0.3), 0.35, fill: .colour(I.ironDark))
            k += 2.6
        }
    }

    /// The forge at the back of the shed: a hearth of brick with its fire,
    /// and its square chimney of brick, banded in iron and capped in stone,
    /// rising to `top` points, through the roof.
    private mutating func forge(top: Double, lit: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let h0 = 1.5, (x0, y0, x1, y1) = (-1.2, -1.2, -0.78, -0.86)
        let (cx0, cy0, cx1, cy1) = (-1.2, -1.2, -0.96, -1.0)
        block(cx0, cy0, cx1, cy1, h0, top, top: .colour(I.brickTop), left: .colour(I.brick), right: .colour(I.brickShade), width: 0.9)
        for side in [IndustrialOldBuildingsSide.left, .right] {
            let w = side == .left ? (cx1 - cx0) * 32 : (cy1 - cy0) * 32
            wall(side, from: side == .left ? cx0 : cx1, cy1, at: h0) { p in
                p.brickwork(0, w, 0, top - h0, course: 2.4, brick: 5, burnt: false)
                // Iron bands up the stack.
                guard lit else { return }
                for v in stride(from: top - h0 - 6, to: 40.0, by: -8) {
                    p.shape(p.panel(0, v, w, v + 1.2), .colour(I.iron), width: 0.4)
                }
            }
        }
        if lit {
            block(cx0 - 0.03, cy0 - 0.03, cx1 + 0.03, cy1 + 0.03, top, top + 2.2, top: .colour(I.stoneTop), left: .colour(I.stone),
                  right: .colour(I.stoneShade), width: 0.8)
            colour(level(cx0 + 0.02, cy0 + 0.02, cx1 - 0.02, cy1 - 0.02, top + 2.2), .colour(I.sootDark))
            // Smoke drifting off to the right.
            let mouth = iso((cx0 + cx1) / 2, (cy0 + cy1) / 2, top + 4)
            for (o, r, paint) in [(P(1.6, -2.2), 2.6, I.smokeDark), (P(5.4, -4.4), 3.2, I.smoke), (P(10, -5.6), 3.6, I.smokeLight)] {
                svg.circle(mouth + o + shift * 0.6, r, fill: .colour(paint))
                svg.circle(mouth + o, r, fill: .none, stroke: .colour(I.line), width: 0.6)
            }
        }
        block(x0, y0, x1, y1, h0, h0 + 10, top: .colour(I.brickTop), left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: h0) { p in
            let w = (x1 - x0) * 32
            p.brickwork(0, w, 0, 10, course: 2.4, brick: 5, burnt: false)
            p.arch(w / 2, 1.6, width: 7, height: 6.4, .colour(I.dark), line: 0.8)
            if lit {
                p.svg.ellipse(p.uv(w / 2, 3.2), 2.8, 1.6, fill: .colour(I.fire))
                p.svg.ellipse(p.uv(w / 2, 3.4), 1.6, 1, fill: .colour(I.fireCore))
            }
        }
    }

    private mutating func gunWorks() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.worksBox
        let h0 = 1.5, eave = Self.worksEave, t = 0.08
        let length = (x1 - x0) * 32, depth = (y1 - y0) * 32
        shadow(level(x0, y0, x1 + 0.3, y1 + 0.22, h0), opacity: 0.16)
        // The floor of the works, paved.
        colour(level(x0, y0, x1, y1, h0), .colour(I.pavingShade))
        // The back wall and the left end, seen from within.
        block(x0, y0, x1, y0 + t, h0, eave, top: .colour(I.brickTop), left: .colour(I.brickShade), right: .colour(I.brickShade))
        wall(.left, from: x0, y0 + t, at: h0) { p in
            p.brickwork(0, length, 0, eave - h0, opacity: 0.25, burnt: false)
            for u in stride(from: 16.0, to: length - 8, by: 15) { p.archedWindow(u, 13, w: 5, h: 11) }
        }
        block(x0, y0 + t, x0 + t, y1, h0, eave, top: .colour(I.brickTop), left: .colour(I.brick), right: .colour(I.brickDark))
        wall(.right, from: x0 + t, y1, at: h0) { p in p.brickwork(0, (y1 - y0 - t) * 32, 0, eave - h0, opacity: 0.25, burnt: false) }
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, t * 32, 2.4), .colour(I.footing), width: 0.5)
            p.paintedBand(0, t * 32, eave - h0 - 6, eave - h0 - 4.4)
        }
        forge(top: Self.worksRidge + 6, lit: true)
        // Barrels of powder and girders stacked within.
        barrel(at: iso(-0.2, -1.1, h0), size: 0.9)
        barrel(at: iso(0.05, -1.0, h0), size: 0.9)
        for k in 0..<3 {
            let y = -0.66 + Double(k) * 0.08
            worksGirder(-0.9, y, -0.2, y, at: h0 + 3.4 + Double(k % 2) * 1.6, depth: 2)
        }
        // The right end: a wall of brick with doors for the guns.
        block(x1 - t, y0 + t, x1, y1, h0, eave, top: .colour(I.brickTop), left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, depth, 2.4), .colour(I.footingShade), width: 0.5)
            p.brickwork(0, depth, 2.4, eave - h0)
            p.quoins(at: 0, atStart: true, from: 2.4, to: eave - h0, course: 3.2, reach: 3.4)
            p.quoins(at: depth, atStart: false, from: 2.4, to: eave - h0, course: 3.2, reach: 3.4)
            p.archedDoors(depth / 2, 2.4, w: 14, h: 22)
            p.paintedBand(0, depth / 2 - 9, eave - h0 - 6, eave - h0 - 4.4)
            p.paintedBand(depth / 2 + 9, depth, eave - h0 - 6, eave - h0 - 4.4)
        }
        // The front: columns of cast iron carrying the girder, and the banner hung from it.
        let front = Self.worksPostsY[1]
        for x in Self.worksPostsX.dropFirst() where x < x1 - 0.1 { worksPost(x, front, from: h0, to: eave - 3) }
        worksPost(-0.85, front, from: h0, to: eave - 3)
        worksGirder(x0, y1, x1, y1, at: eave, depth: 3.4)
        wall(.left, from: x0, y1, at: h0) { p in p.banner(length * 0.62, top: eave - h0 - 3.6, width: 9, length: 14) }
        gableAlongX(x0, y0, x1, y1, eave: eave, ridge: Self.worksRidge, over: 0.08, gableWall: .colour(I.brickShade)) { p, w, rise in
            p.gableBrickwork(w, rise)
            p.svg.circle(p.uv(w / 2, rise * 0.42), 3.2, fill: .colour(I.stoneTop), stroke: .colour(I.line), width: 0.6)
            p.svg.circle(p.uv(w / 2, rise * 0.42), 2, fill: .colour(I.glass), stroke: .colour(I.line), width: 0.45)
            p.svg.line([p.uv(w / 2 - 2, rise * 0.42), p.uv(w / 2 + 2, rise * 0.42)], stroke: .colour(I.light), width: 0.4)
            p.svg.line([p.uv(w / 2, rise * 0.42 - 2), p.uv(w / 2, rise * 0.42 + 2)], stroke: .colour(I.light), width: 0.4)
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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

    /// The crane: shear legs of iron standing beside the works, stayed back to
    /// a stake, with a winch between their feet, lifting a girder (or a column
    /// while the works is being built), the owner's pennant at its head.
    private mutating func gunCrane(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let h0 = 1.5, (cx, cy) = (1.05, -0.72), apex = iso(cx, cy, 66)
        let feet = [(1.3, -1.25), (1.3, -0.2)]
        svg.line([apex, iso(1.46, cy, h0)], stroke: .colour(I.line), width: 0.6)
        pole(iso(1.46, cy, h0), iso(1.46, cy, h0 + 5), width: 1.2, colour: I.oak)
        pole(iso(feet[0].0, feet[0].1, h0), apex, width: 2.2, colour: I.iron)
        let drum = (iso(1.3, -1.13, h0 + 7), iso(1.3, -0.32, h0 + 7))
        pole(drum.0, drum.1, width: 3.4, colour: I.ironLight)
        let crank = drum.1
        line([crank, crank + P(2.4, 4), crank + P(4.6, 3)], width: 1.1)
        let hook = iso(cx, cy, 30)
        svg.line([drum.0 + (drum.1 - drum.0) * 0.45, apex], stroke: .colour(I.line), width: 0.6)
        svg.line([apex, hook], stroke: .colour(I.line), width: 0.7)
        svg.circle(apex + P(0, 2.4), 1.8, fill: .colour(I.ironDark), stroke: .colour(I.line), width: 0.6)
        if complete {
            let a = iso(cx, cy - 0.42, 22), b = iso(cx, cy + 0.42, 22)
            svg.line([hook, a + P(0, -1)], stroke: .colour(I.line), width: 0.6)
            svg.line([hook, b + P(0, -1)], stroke: .colour(I.line), width: 0.6)
            worksGirder(cx, cy - 0.42, cx, cy + 0.42, at: 22, depth: 3)
        } else {
            pole(hook + P(-1, 2), hook + P(4, 22), width: 2.2, colour: I.iron)
        }
        line([hook, hook + P(0, 2.4), hook + P(1.6, 3.2), hook + P(2.2, 1.6)], width: 1)
        pole(iso(feet[1].0, feet[1].1, h0), apex, width: 2.2, colour: I.iron)
        pennant(at: apex, height: 10, length: 14)
    }

    /// The works being built: the forge's chimney half raised, the back wall
    /// and the left end of fresh brick risen partway, the first columns of
    /// iron standing on their pads with a girder across them, the crane
    /// lifting another column, and bricks and slates to hand.
    private mutating func gunWorksRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.worksBox
        let h0 = 1.5, eave = Self.worksEave, t = 0.08, wallTop = 18.0
        let length = (x1 - x0) * 32
        colour(level(x0, y0, x1, y1, h0), .colour(I.pavingShade), opacity: 0.7)
        block(x0, y0, x1 - 0.5, y0 + t, h0, wallTop, top: .colour(I.brickTop), left: .colour(I.rawBrickShade),
              right: .colour(I.rawBrickShade))
        wall(.left, from: x0, y0 + t, at: h0) { p in
            p.brickwork(0, length - 16, 0, wallTop - h0, opacity: 0.3, burnt: false)
        }
        block(x0, y0 + t, x0 + t, y1, h0, wallTop, top: .colour(I.brickTop), left: .colour(I.rawBrick), right: .colour(I.rawBrickShade))
        forge(top: 40, lit: false)
        let front = Self.worksPostsY[1]
        worksPost(-0.85, front, from: h0, to: eave - 3)
        worksPost(Self.worksPostsX[1], front, from: h0, to: eave - 3)
        worksGirder(-0.92, y1, Self.worksPostsX[1] + 0.07, y1, at: eave, depth: 3.4)
        timbers(-0.1, -0.7, length: 0.75, on: h0)
        slates(-1.0, 0.65, -0.45, 0.95, from: h0, height: 7)
        bricks(-0.3, 0.7, 0.1, 0.95, from: h0, height: 6)
        bricks(0.62, 0.3, 0.92, 0.55, from: h0, height: 4)
        sack(at: iso(-1.2, 1.2, h0))
        gunCrane(complete: false)
    }
}
