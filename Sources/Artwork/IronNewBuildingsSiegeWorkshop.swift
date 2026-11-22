// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age siege workshop: a large shed open on every side, its roof of
// red tile on posts of timber braced at the head, over a catapult half built:
// its frame on wheels, its uprights and their crossbar raised, its arm lying
// ready in the yard. A crane of shear legs and a windlass beside the shed
// lifts a beam, flying the owner's pennant; a banner of the owner's colour
// hangs from the shed's front, and squared beams lie stacked in the yard. Its
// footprint is three tiles square: x and y run from -1.5 to 1.5.

extension IronNewBuildingsPainter {
    mutating func siegeWorkshop(complete: Bool) {
        typealias I = IronNewBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        chippings(on: 1.5)
        if complete { shed() } else { shedRising() }
    }

    private static let shedBox = (x0: -1.36, y0: -1.36, x1: 0.62, y1: -0.05)
    private static let shedEave = 38.0
    private static let shedRidge = 54.0
    /// The posts along the back; the front is open between its two corner posts.
    private static let postsAlongX: [Double] = [-1.32, -0.37, 0.58]
    private static let postsAlongY: [Double] = [-1.32, -0.09]

    /// Chips and shavings of timber over the yard, at fixed places.
    private mutating func chippings(on h: Double) {
        typealias I = IronNewBuildingsInk
        let places: [(Double, Double)] = [(-0.9, 0.6), (-0.2, 0.9), (0.4, 0.5), (1.0, 1.1), (-1.1, 1.2), (0.8, -0.9), (1.2, 0.2),
                                          (-0.5, -0.2), (0.1, -1.0), (-1.0, -0.6)]
        for (k, (x, y)) in places.enumerated() {
            let c = iso(x, y, h)
            let t = Double(k % 3) * 0.6
            svg.polygon([c + P(-1.4, 0), c + P(0.2 + t, -0.8), c + P(1.4, 0.2), c + P(-0.2, 0.7)], fill: .colour(I.timberLight))
        }
    }

    private mutating func shed() {
        typealias I = IronNewBuildingsInk
        let (x0, y0, x1, y1) = Self.shedBox
        let h0 = 1.5, eave = Self.shedEave
        // The floor under the roof lies in its shade.
        shadow(level(x0, y0, x1 + 0.3, y1 + 0.22, h0), opacity: 0.16)
        backFrame()
        beamsStacked(-1.2, -1.2, on: h0)
        beamsStacked(-0.3, -1.2, on: h0)
        frontFrame()
        // The banner of the owner's colour, hung from the front plate at its left.
        wall(.left, from: x0, y1, at: h0) { p in p.hanging(12, top: eave - 2.6, width: 9, length: 17) }
        gabledRoof(x0, y0, x1, y1, eave: eave, ridge: Self.shedRidge, over: 0.1, gableWall: .colour(I.timber)) { p, w, rise in
            for u in stride(from: 3.4, to: w - 1, by: 3.4) {
                let top = rise * (1 - abs(u - w / 2) / (w / 2)) - 0.6
                if top > 0.6 { p.line([p.uv(u, 0.4), p.uv(u, top)], width: 0.45, opacity: 0.7) }
            }
            // A round opening for light in the gable.
            p.svg.circle(p.uv(w / 2, rise * 0.4), 2.6, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.7)
        }
        // The catapult stands half under the roof, at its open front.
        catapultFrame()
        workbench(at: (0.62, 0.98))
        catapultArm()
        crane(complete: true)
    }

    /// The posts along the back and at the left end, with their plates and braces.
    private mutating func backFrame() {
        typealias I = IronNewBuildingsInk
        let (x0, y0, x1, _) = Self.shedBox
        let h0 = 1.5, eave = Self.shedEave
        for x in Self.postsAlongX { post(x, Self.postsAlongY[0], from: h0, to: eave) }
        for y in Self.postsAlongY.dropFirst() { post(Self.postsAlongX[0], y, from: h0, to: eave) }
        pole(iso(x0, Self.postsAlongY[0], eave), iso(x1, Self.postsAlongY[0], eave), width: 2.4, colour: I.timber)
        pole(iso(Self.postsAlongX[0], y0, eave), iso(Self.postsAlongX[0], Self.shedBox.y1, eave), width: 2.4, colour: I.timber)
        for (a, b) in zip(Self.postsAlongX, Self.postsAlongX.dropFirst()) {
            brace(from: (a, Self.postsAlongY[0]), toward: (a + 0.26, Self.postsAlongY[0]), eave: eave)
            brace(from: (b, Self.postsAlongY[0]), toward: (b - 0.26, Self.postsAlongY[0]), eave: eave)
        }
    }

    /// The posts along the front and at the right end, with their plates and braces.
    private mutating func frontFrame() {
        typealias I = IronNewBuildingsInk
        let (x0, y0, x1, y1) = Self.shedBox
        let h0 = 1.5, eave = Self.shedEave
        let front = Self.postsAlongY.last!, (first, end) = (Self.postsAlongX.first!, Self.postsAlongX.last!)
        post(end, front, from: h0, to: eave)
        pole(iso(end, y0, eave), iso(end, y1, eave), width: 2.4, colour: I.timber)
        pole(iso(x0, front, eave), iso(x1, front, eave), width: 2.4, colour: I.timber)
        brace(from: (first, front), toward: (first + 0.3, front), eave: eave)
        brace(from: (end, front), toward: (end - 0.3, front), eave: eave)
        brace(from: (end, front), toward: (end, front - 0.3), eave: eave)
    }

    /// A squared post of timber at (x, y), from `h0` to `h1`, on a pad of stone.
    private mutating func post(_ x: Double, _ y: Double, from h0: Double, to h1: Double) {
        typealias I = IronNewBuildingsInk
        let s = 0.05
        block(x - 0.08, y - 0.08, x + 0.08, y + 0.08, h0, h0 + 2, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.7)
        block(x - s, y - s, x + s, y + s, h0 + 2, h1, top: nil, left: .colour(I.timberLight), right: .colour(I.timber), width: 0.9)
    }

    /// A brace from the head of the post at `a` toward the post at `b`, both on the map.
    private mutating func brace(from a: (Double, Double), toward b: (Double, Double), eave: Double) {
        typealias I = IronNewBuildingsInk
        let foot = iso(a.0, a.1, eave - 10), head = iso(b.0, b.1, eave - 1)
        pole(foot, head, width: 1.4, colour: I.timber)
    }

    /// Squared beams stacked along x from (x, y), three below and two above.
    private mutating func beamsStacked(_ x: Double, _ y: Double, on h: Double) {
        for (row, offsets) in [[0.0, 0.1, 0.2], [0.05, 0.15]].enumerated() {
            for dy in offsets { beam(x, y + dy, x + 0.75, y + dy, on: h + Double(row) * 3, size: 3) }
        }
    }

    /// The catapult's frame, half built under the roof: two sills joined by
    /// cross pieces, a wheel on the near side and its fellow waiting, and the
    /// uprights with their crossbar, braced back to the frame.
    private mutating func catapultFrame() {
        typealias I = IronNewBuildingsInk
        let h0 = 1.5, (ax, bx) = (-1.0, 0.2), (fy, ny) = (-0.4, 0.13), w = 4.0
        let up = h0 + w
        // The far sill, the cross pieces, the near sill.
        beam(ax, fy, bx, fy, on: up, size: 3.2)
        for x in [ax + 0.06, bx - 0.06] { beam(x, fy, x, ny, on: up, size: 3) }
        // The wheels' axle-blocks under the frame.
        for x in [ax + 0.2, bx - 0.25] {
            block(x - 0.05, fy, x + 0.05, ny, h0, up, top: nil, left: .colour(I.timberDark), right: .colour(I.timberDark), width: 0.7)
        }
        // The uprights and the crossbar where the arm will strike.
        let ux = -0.25
        for y in [fy, ny] { pole(iso(ux, y, up + 3), iso(ux, y, up + 20), width: 2.4, colour: I.timber) }
        for y in [fy, ny] { pole(iso(ux + 0.35, y, up + 3), iso(ux + 0.02, y, up + 15), width: 1.6, colour: I.timber) }
        pole(iso(ux, fy - 0.04, up + 18), iso(ux, ny + 0.04, up + 18), width: 2.6, colour: I.timberLight)
        // The padding of the crossbar, bound in rope.
        let pad = iso(ux, (fy + ny) / 2, up + 18)
        shape([pad + P(-3.4, -3), pad + P(3.4, 0.4), pad + P(3.4, 2.6), pad + P(-3.4, -0.8)], .colour(I.straw), width: 0.7)
        // The skein of rope at the back of the frame, its windlass not yet fitted.
        let skein = iso(ax + 0.2, (fy + ny) / 2, up + 3)
        svg.ellipse(skein + P(-0.6, 0.4), 5, 3.4, fill: .colour(I.straw))
        svg.ellipse(skein, 5, 3.4, fill: .none, stroke: .colour(I.line), width: 0.8)
        for k in -2...2 { line([skein + P(Double(k) * 1.6 - 1, -2.8), skein + P(Double(k) * 1.6 + 1, 2.8)], width: 0.4, opacity: 0.8) }
        beam(ax, ny, bx, ny, on: up, size: 3.2)
        // The near wheels: one fitted, and the place of the other bare.
        wheel(at: (ax + 0.2, ny + 0.05), on: h0, radius: 6.4)
        // The other wheel, leaning against the frame.
        wall(.left, from: bx - 0.38, ny + 0.12, at: h0) { p in
            p.svg.circle(p.uv(6, 6.2) + P(-0.8, 0.6), 6.2, fill: .colour(I.timberLight))
            p.svg.circle(p.uv(6, 6.2), 6.2, fill: .none, stroke: .colour(I.line), width: 0.9)
            p.svg.circle(p.uv(6, 6.2), 4.8, fill: .none, stroke: .colour(I.line), width: 0.5)
            for a in stride(from: 0.0, to: 180, by: 45) {
                let d = P.direction(a) * 4.8
                p.line([p.uv(6, 6.2) + d, p.uv(6, 6.2) - d], width: 0.7)
            }
            p.svg.circle(p.uv(6, 6.2), 1.3, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// A spoked wheel on the side of a frame, its hub at (x, y) on the map, its
    /// foot on `h`, in the plane facing +y, with a tyre of iron.
    private mutating func wheel(at c: (Double, Double), on h: Double, radius r: Double) {
        typealias I = IronNewBuildingsInk
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
            p.svg.circle(hub, 1.4, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// A small bench with a saw and an adze on it, its near end at (x, y).
    private mutating func workbench(at place: (Double, Double)) {
        typealias I = IronNewBuildingsInk
        let (x, y) = place, h0 = 1.5, top = 9.0
        for (dx, dy) in [(0.0, -0.12), (0.5, -0.12), (0.0, 0.0), (0.5, 0.0)] {
            pole(iso(x + dx + 0.04, y + dy, h0), iso(x + dx + 0.04, y + dy, top), width: 1.2, colour: I.timberDark)
        }
        block(x, y - 0.16, x + 0.58, y + 0.04, top, top + 1.8, top: .colour(I.timberLight), left: .colour(I.timber),
              right: .colour(I.timberDark), width: 0.8)
        // The saw: a blade of iron in a frame.
        let a = iso(x + 0.08, y - 0.06, top + 1.8), b = iso(x + 0.36, y - 0.06, top + 1.8)
        shape([a, b, b + P(0.6, -2), a + P(0.6, -2)], .colour(I.ironLight), width: 0.6)
        // The adze.
        let c = iso(x + 0.46, y - 0.1, top + 1.8)
        pole(c, c + P(4, -1), width: 0.9, colour: I.timberLight)
        shape([c + P(-0.6, 0.2), c + P(0.6, -1.6), c + P(1.4, -1), c + P(0.4, 0.6)], .colour(I.iron), width: 0.5)
    }

    /// The catapult's throwing arm lying on two trestles in the yard, its cup not yet fitted.
    private mutating func catapultArm() {
        typealias I = IronNewBuildingsInk
        let h0 = 1.5, y = 0.78, (x0, x1) = (-1.1, 0.25)
        for x in [x0 + 0.18, x1 - 0.18] {
            pole(iso(x - 0.06, y - 0.06, h0), iso(x, y, h0 + 7), width: 1.2, colour: I.timberDark)
            pole(iso(x + 0.06, y + 0.06, h0), iso(x, y, h0 + 7), width: 1.2, colour: I.timberDark)
            pole(iso(x - 0.06, y + 0.06, h0), iso(x, y, h0 + 7), width: 1.2, colour: I.timberDark)
        }
        beam(x0, y, x1, y, on: h0 + 7, size: 3.4)
        // Its bands of iron.
        for t in [0.15, 0.55] {
            let x = x0 + (x1 - x0) * t
            let p = iso(x, y, h0 + 7)
            shape([p + P(0, 0.2), p + P(1.6, 1), p + P(4.6, -2.6), p + P(3, -3.4)], .colour(I.iron), width: 0.5)
        }
    }

    /// The crane: shear legs standing beside the shed, stayed back to a stake,
    /// with a windlass between their feet, lifting a beam on a hook of iron
    /// (when the shed is `complete`) or holding a rafter for the roof (when it
    /// is being built), the owner's pennant at its head.
    private mutating func crane(complete: Bool) {
        typealias I = IronNewBuildingsInk
        let h0 = 1.5, (cx, cy) = (1.05, -0.72), apex = iso(cx, cy, 66)
        let feet = [(1.3, -1.25), (1.3, -0.2)]
        // The stay to its stake.
        svg.line([apex, iso(1.46, cy, h0)], stroke: .colour(I.line), width: 0.6)
        pole(iso(1.46, cy, h0), iso(1.46, cy, h0 + 5), width: 1.2, colour: I.timberDark)
        pole(iso(feet[0].0, feet[0].1, h0), apex, width: 2.2, colour: I.timber)
        // The windlass between the legs.
        let drum = (iso(1.3, -1.13, h0 + 7), iso(1.3, -0.32, h0 + 7))
        pole(drum.0, drum.1, width: 3.4, colour: I.timberLight)
        for t in [0.35, 0.45, 0.55] {
            let m = drum.0 + (drum.1 - drum.0) * t
            line([m + P(0, -1.9), m + P(0, 1.9)], width: 0.5, opacity: 0.8)
        }
        let crank = drum.1
        line([crank, crank + P(2.4, 4), crank + P(4.6, 3)], width: 1.1)
        // The rope from the windlass up to the head, and down to the load.
        let hook = iso(cx, cy, 30)
        svg.line([drum.0 + (drum.1 - drum.0) * 0.45, apex], stroke: .colour(I.line), width: 0.6)
        svg.line([apex, hook], stroke: .colour(I.line), width: 0.7)
        // A pulley at the head.
        svg.circle(apex + P(0, 2.4), 1.8, fill: .colour(I.timberDark), stroke: .colour(I.line), width: 0.6)
        if complete {
            // A beam slung from the hook, along y.
            let a = iso(cx, cy - 0.42, 22), b = iso(cx, cy + 0.42, 22)
            svg.line([hook, a + P(0, -3.6)], stroke: .colour(I.line), width: 0.6)
            svg.line([hook, b + P(0, -3.6)], stroke: .colour(I.line), width: 0.6)
            beam(cx, cy - 0.42, cx, cy + 0.42, on: 22, size: 3.6)
        } else {
            // A rafter on the hook, hanging nearly upright.
            pole(hook + P(-1, 2), hook + P(4, 22), width: 2.2, colour: I.timber)
        }
        line([hook, hook + P(0, 2.4), hook + P(1.6, 3.2), hook + P(2.2, 1.6)], width: 1)
        pole(iso(feet[1].0, feet[1].1, h0), apex, width: 2.2, colour: I.timber)
        pennant(at: apex, height: 10, length: 15)
    }

    /// The workshop being built: its posts set on their pads, the plates laid
    /// along the back and the left end, the first rafters raised, the crane
    /// lifting another, and beams and roof tiles to hand.
    private mutating func shedRising() {
        typealias I = IronNewBuildingsInk
        let (_, y0, _, y1) = Self.shedBox
        let h0 = 1.5, eave = Self.shedEave, ridge = Self.shedRidge
        let ym = (y0 + y1) / 2
        backFrame()
        // Rafters at the left end, and the ridge-pole begun.
        for x in [Self.postsAlongX[0], Self.postsAlongX[0] + 0.3] {
            pole(iso(x, y0, eave), iso(x, ym, ridge), width: 1.6, colour: I.timber)
            pole(iso(x, y1, eave), iso(x, ym, ridge), width: 1.6, colour: I.timber)
        }
        pole(iso(Self.postsAlongX[0] - 0.05, ym, ridge), iso(Self.postsAlongX[0] + 0.5, ym, ridge), width: 1.8, colour: I.timber)
        beamsStacked(-0.9, -0.3, on: h0)
        // The posts at the front, all set, their plate only begun.
        let front = Self.postsAlongY.last!, end = Self.postsAlongX.last!
        post(end, front, from: h0, to: eave)
        pole(iso(Self.postsAlongX[0], front, eave), iso(Self.postsAlongX[1], front, eave), width: 2.4, colour: I.timber)
        roofTiles(-1.0, 0.65, -0.45, 0.95, from: h0, courses: 4)
        roofTiles(-0.3, 0.7, 0.1, 0.95, from: h0, courses: 2)
        beamsStacked(0.05, 1.0, on: h0)
        sack(at: iso(-1.2, 1.2, h0))
        crane(complete: false)
    }
}
