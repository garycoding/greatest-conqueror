// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age boat house (ruled 2026-11-21): the Stone age's shelter on
// piles grown into a boathouse of dressed stone on a cobbled quay. Its gable
// faces the water (+x, the screen's lower right) under a steep roof of slate
// with a gilt weathervane; a great round-headed water door opens in the
// gable, a smack's bow showing in its dark, a loft door above it with a hoist
// beam, a pulley and a hook. A slipway of flagstones with two oak runners runs
// from the water door to the edge of the footprint, an iron-capped bollard
// at each side of its foot; the owner's pennant flies from a staff beside it.
// The long wall has a door of teal plank, a leaded window, a banner of the
// owner's colour and the owner's band under the eaves; nets hang to dry on a
// rack, with creels, an anchor and barrels of herring about the quay. Under
// construction: the walls raised partway in fresh stone, the water door's arch
// turned on a wooden centring, scaffolding with the pennant, and a smack's
// keel and ribs on the stocks on the slipway. Its footprint is two tiles
// square: x and y run from -1 to 1; the water may lie beside any edge.
//
// It is drawn in two views (ruled 2026-11-22): the side view above, its water
// side toward +x, and the back view, the same building turned a quarter so
// that its water side lies toward -y (the screen's upper right), running away
// from the viewer. In the back view the landward gable faces the viewer on
// the lower left, with its cart doors, a lantern and a loft window, and the
// long wall shows on the lower right; the slipway, its bollards, the pennant,
// the hoist and the weathervane show beyond the building. The drawing mirrors
// the two views for the other two edges.

/// The boat house's measurements, about the centre of its footprint: distances
/// in tiles along the map's axes, heights in points.
private enum Boathouse {
    /// The walls' foot (the quay's top), their extent, the eaves and the ridge.
    static let h0 = 1.5, x0 = -0.84, x1 = 0.3, y0 = -0.62, y1 = 0.38, eave = 25.0, ridge = 50.0
    /// The slipway, from the water door to the footprint's edge, and its height above the quay.
    static let slipX1 = 0.98, slipY0 = -0.33, slipY1 = 0.09, slip = 1.0
    /// The water door, on the gable's wall: its middle along the wall, its width and its height to the crown.
    static let doorWidth = 19.0, doorHeight = 19.0
    /// The gable wall's length, and the water door's middle along it.
    static var gableLength: Double { (y1 - y0) * 32 }
    static var doorMiddle: Double { gableLength / 2 }
    /// The long wall's length.
    static var sideLength: Double { (x1 - x0) * 32 }
    /// The dock (ruled 2026-11-22), in the side view's frame: a stone quay from
    /// the footprint's edge out over the water, as wide as the slipway it
    /// continues and at its height, its steps down to the water at its end.
    static let dockX0 = 1.0, dockX1 = 1.88, dockStep = 0.065

    /// Where a place given in the side view's frame (`a` along x, toward the
    /// water; `b` along y) lies on the map: the same place in the side view,
    /// and in the back view the building turned a quarter, so that +x goes to
    /// -y and +y to +x.
    static func turn(_ a: Double, _ b: Double, back: Bool) -> (x: Double, y: Double) {
        back ? (b, -a) : (a, b)
    }

    /// The walls' extent in the back view: the side view's turned.
    static let backX0 = y0, backX1 = y1, backY0 = -x1, backY1 = -x0
    /// The long wall's door, middle along the wall from its landward end, in
    /// the back view: further along than in the side view, clear of the quoins
    /// at the near corner, which is the landward one there.
    static let backDoor = 10.5
}

extension AlchemyOldBuildingsPainter {
    /// The boat house, complete or under construction, in the side view
    /// (its water toward +x) or the back view (its water toward -y).
    /// The quay's dock runs out over the water beyond the footprint: behind
    /// everything in the back view, before everything in the side view.
    mutating func boatHouse(complete: Bool, back: Bool = false) {
        if back { dock(complete: complete, back: true) }
        cobbles(1, height: Boathouse.h0)
        switch (complete, back) {
        case (true, false): stoneBoathouse()
        case (false, false): stoneBoathouseRising()
        case (true, true): stoneBoathouseFromBehind()
        case (false, true): stoneBoathouseRisingFromBehind()
        }
        if !back { dock(complete: complete, back: false) }
    }

    // MARK: The complete boat house

    private mutating func stoneBoathouse() {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let (x0, y0, x1, y1, h0, e) = (B.x0, B.y0, B.x1, B.y1, B.h0, B.eave)
        // Barrels of herring at the back of the quay, behind the slipway.
        barrel(at: iso(0.5, -0.88, h0), size: 0.8)
        barrel(at: iso(0.7, -0.84, h0), size: 0.8)
        barrel(at: iso(0.6, -0.92, h0) + P(0, -7.4), size: 0.72)
        // The building's shadow on the quay, to the right.
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.boathouseWall(B.sideLength, e - h0, quoinAtStart: false)
            p.door(7.5, 0, w: 7, h: 12)
            p.casement(14.5, 5, w: 9, h: 7, lights: 2, frame: I.stoneTop)
            p.paintedBand(0, B.sideLength, e - h0 - 4.4, e - h0 - 2.4)
            p.banner(30, top: e - h0 - 5.6, width: 6, length: 12)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.boathouseWall(B.gableLength, e - h0, quoinAtStart: true)
            p.waterDoor(open: true)
            p.paintedBand(0, B.gableLength, e - h0 - 4.4, e - h0 - 2.4)
            // A lantern on a bracket beside the water door.
            p.lantern(at: p.uv(B.doorMiddle + B.doorWidth / 2 + 4.4, 13), arm: -1)
        }
        // The roof, its gable to the water, the loft door and a round window in the gable.
        let ym = (y0 + y1) / 2
        gableAlongX(x0, y0, x1, y1, eave: e, ridge: B.ridge, over: 0.06, gableWall: .colour(I.stone), finials: false) { p, w, rise in
            // The courses, within the gable's triangle.
            var courses = PathData()
            for v in stride(from: 3.6, to: rise - 2, by: 3.6) {
                let inset = v / rise * w / 2
                courses.move(p.uv(inset + 0.4, v)); courses.line(p.uv(w - inset - 0.4, v))
            }
            p.svg.path(courses, stroke: .colour(I.line), width: 0.45, opacity: 0.4)
            p.shape(p.panel(w / 2 - 3.6, 1, w / 2 + 3.6, 11), .colour(I.stoneTop), width: 0.6)
            p.shape(p.panel(w / 2 - 2.8, 1.4, w / 2 + 2.8, 10.4), .colour(I.teal), width: 0.7)
            p.line([p.uv(w / 2, 1.6), p.uv(w / 2, 10.2)], width: 0.4, opacity: 0.6)
            for v in [3.4, 8.2] { p.shape(p.panel(w / 2 - 2.6, v - 0.4, w / 2 + 1.2, v + 0.4), .colour(I.iron), width: 0.35) }
            p.svg.circle(p.uv(w / 2, rise - 6.4), 2.3, fill: .colour(I.stoneTop), stroke: .colour(I.line), width: 0.6)
            p.svg.circle(p.uv(w / 2, rise - 6.4), 1.5, fill: .colour(I.glass), stroke: .colour(I.line), width: 0.4)
            p.svg.circle(p.uv(w / 2, rise - 6.4) + P(-0.4, -0.5), 0.5, fill: .colour(I.glassLight))
        }
        finial(at: iso(x0 - 0.06, ym, B.ridge), size: 0.9)
        weathervane(at: iso(x1 + 0.06, ym, B.ridge), height: 17)
        hoist(at: iso(x1, ym, e + 12.4), toward: P(9, 4.5))
        slipway()
        bowInTheDoor()
        // The owner's pennant on a staff at the slipway's foot, beside the water.
        pennant(at: iso(0.94, -0.46, h0), height: 34, length: 15)
        // An anchor leaning on the corner by the water door; before the long wall, nets drying on
        // their rack, creels, a coil of rope and a barrel.
        anchor(at: iso(x1 + 0.06, y1 - 0.08, h0))
        netRack(from: (-0.9, 0.42), to: (-0.9, 0.92))
        creel(at: iso(-0.3, 0.74, h0))
        creel(at: iso(-0.08, 0.86, h0), size: 0.9)
        rope(at: iso(0.18, 0.72, h0))
        barrel(at: iso(0.66, 0.62, h0), size: 0.8)
    }

    /// A lantern hanging at `lamp` on a wall drawn with `wall`, from a bracket
    /// reaching to the left (`arm` -1) or to the right (1).
    private mutating func lantern(at lamp: P, arm: Double) {
        typealias I = AlchemyOldBuildingsInk
        line([lamp + P(1.6 * arm, -3.6), lamp + P(0, -3.6), lamp + P(0, -2.4)], width: 0.8)
        shape([lamp + P(-1.4, -2.4), lamp + P(1.4, -2.4), lamp + P(1.1, 1.6), lamp + P(-1.1, 1.6)], .colour(I.giltLight), width: 0.6)
        svg.circle(lamp + P(0, -0.2), 0.7, fill: .colour(I.gilt))
    }

    /// A wall of the boat house drawn with `wall`, `length` long and `height`
    /// tall: a plinth of darker stone, courses, and quoins at the near corner.
    private mutating func boathouseWall(_ length: Double, _ height: Double, quoinAtStart: Bool) {
        typealias I = AlchemyOldBuildingsInk
        colour(panel(0, 0, length, 2.6), .colour(I.footing))
        line([uv(0, 2.6), uv(length, 2.6)], width: 0.6)
        courses(0, length, 2.6, height, course: 3.6, brick: 8.4)
        quoins(at: quoinAtStart ? 0 : length, atStart: quoinAtStart, from: 2.6, to: height, course: 3.6)
    }

    /// The water door on the gable's wall drawn with `wall`: a round head of
    /// voussoirs with a keystone, and the dark within; when `open`, the bow of
    /// a smack in it, its stem post, its strake of the owner's colour and its
    /// mast going up into the dark.
    private mutating func waterDoor(open: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let u = Boathouse.doorMiddle, w = Boathouse.doorWidth, h = Boathouse.doorHeight
        let r = w / 2, spring = h - r
        arch(u, 0, width: w + 5, height: h + 2.5, .colour(I.stoneTop), line: 0.8)
        voussoirs(u, spring: spring, inner: r, outer: r + 2.5, count: 9)
        arch(u, 0, width: w, height: h, .colour(I.dark), line: 0.9)
        // The keystone.
        shape([uv(u - 1.6, h + 2.9), uv(u + 1.6, h + 2.9), uv(u + 1.1, h - 0.3), uv(u - 1.1, h - 0.3)], .colour(I.stoneTop), width: 0.6)
        guard open else { return }
        // The smack's mast going up into the dark; its bow is drawn in front of the wall (`bowInTheDoor`).
        timber(uv(u - 0.6, 6), uv(u - 0.6, h - 1.2), width: 1.4, paint: I.timber)
        // Light on the water of the slip, under the bow.
        colour(panel(u - 8.4, 0, u + 8.4, 0.9), .colour(I.glass), opacity: 0.7)
    }

    /// The bow of a smack coming out of the water door onto the slipway's
    /// runners: its near side tarred below a strake of the owner's colour,
    /// the dark of its hold over the gunwale, and its stem post.
    private mutating func bowInTheDoor() {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let ym = (B.y0 + B.y1) / 2, keel = B.h0 + B.slip + 1.6, gunwale = keel + 8.5
        let (inside, stem) = (B.x1 - 0.1, B.x1 + 0.12)
        let nearIn = iso(inside, ym + 0.13, gunwale), farIn = iso(inside, ym - 0.13, gunwale)
        let top = iso(stem, ym, gunwale + 1.6), foot = iso(stem - 0.03, ym, keel)
        let keelIn = iso(inside, ym + 0.04, keel - 0.4)
        // The hold, dark, between the gunwales.
        shape([farIn, top, nearIn], .colour(I.dark), width: 0.8)
        // The near side, its strake of the owner's colour under the gunwale.
        shape([nearIn, top, foot, keelIn], .colour(I.timberDark), width: 0.9)
        let strake = [nearIn, top, top + P(0, 2.6), nearIn + P(0, 2.6)]
        colour(strake, .team)
        line([nearIn + P(0, 2.6), top + P(0, 2.6)], width: 0.5)
        line([nearIn, top], width: 0.9)
        // The stem post, standing a little above the gunwale.
        pole(foot, top + P(0.6, -2.4), width: 1.6, colour: I.oak)
    }

    /// The joints of a round arch's voussoirs on a wall drawn with `wall`:
    /// `count` stones round the half circle about (`u`, `spring`), from `inner` to `outer`.
    private mutating func voussoirs(_ u: Double, spring: Double, inner: Double, outer: Double, count: Int) {
        var joints = PathData()
        for k in 1..<count {
            let a = Double(k) / Double(count) * .pi
            joints.move(uv(u - inner * cos(a), spring + inner * sin(a)))
            joints.line(uv(u - outer * cos(a), spring + outer * sin(a)))
        }
        svg.path(joints, stroke: .colour(AlchemyOldBuildingsInk.line), width: 0.5, opacity: 0.8)
    }

    /// The hoist over the loft door at `p` on the screen: a beam of oak out
    /// toward the water by `reach` on the screen, a pulley at its end, and a
    /// rope down to a hook.
    private mutating func hoist(at p: P, toward reach: P) {
        typealias I = AlchemyOldBuildingsInk
        let tip = p + reach
        pole(p, tip, width: 2.2, colour: I.oak)
        svg.circle(tip + P(-0.6, 1.8), 1.6, fill: .colour(I.timberLight), stroke: .colour(I.line), width: 0.6)
        svg.circle(tip + P(-0.6, 1.8), 0.5, fill: .colour(I.ironDark))
        let hook = tip + P(1, 13)
        line([tip + P(1, 1.8), hook], width: 0.6)
        line([tip + P(-2.2, 1.8), tip + P(-2.6, 8)], width: 0.6)
        line(width: 0.8) { d in
            d.move(hook)
            d.quad(hook + P(0.2, 2.2), hook + P(-1.6, 1.8))
        }
    }

    /// The slipway: flagstones from the water door to the edge of the footprint,
    /// raised a little on the quay, two oak runners along it, and a bollard at
    /// each side of its foot; in the side view or, turned, in the back view.
    private mutating func slipway(back: Bool = false, runners: Bool = true, flags: Bool = true) {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let (sx0, sx1, sy0, sy1, h) = (B.x1, B.slipX1, B.slipY0, B.slipY1, B.h0 + B.slip)
        func at(_ a: Double, _ b: Double, _ z: Double) -> P {
            let p = B.turn(a, b, back: back)
            return iso(p.x, p.y, z)
        }
        if flags {
            let (p, q) = (B.turn(sx0, sy0, back: back), B.turn(sx1, sy1, back: back))
            block(min(p.x, q.x), min(p.y, q.y), max(p.x, q.x), max(p.y, q.y), B.h0, h, top: .colour(I.stoneTop), left: .colour(I.stone),
                  right: .colour(I.stoneShade), width: 0.9)
            var joints = PathData()
            for x in stride(from: sx0 + 0.14, to: sx1 - 0.05, by: 0.14) { joints.move(at(x, sy0, h)); joints.line(at(x, sy1, h)) }
            joints.move(at(sx0, (sy0 + sy1) / 2, h)); joints.line(at(sx1, (sy0 + sy1) / 2, h))
            svg.path(joints, stroke: .colour(I.line), width: 0.45, opacity: 0.45)
            // The water's wet on the stones toward the edge.
            colour([at(sx1 - 0.2, sy0 + 0.02, h), at(sx1 - 0.02, sy0 + 0.02, h), at(sx1 - 0.02, sy1 - 0.02, h), at(sx1 - 0.2, sy1 - 0.02, h)],
                   .colour(I.glass), opacity: 0.45)
        }
        if runners {
            for y in [sy0 + 0.1, sy1 - 0.1] {
                let (p, q) = (B.turn(sx0 + 0.02, y, back: back), B.turn(sx1 - 0.03, y, back: back))
                beam(p.x, p.y, q.x, q.y, on: h, size: 1.6)
            }
        }
        for y in [sy0 - 0.06, sy1 + 0.07] { bollard(at: at(sx1 - 0.08, y, B.h0)) }
    }

    /// A short bollard of stone capped in iron, a rope's turn about it.
    private mutating func bollard(at p: P) {
        typealias I = AlchemyOldBuildingsInk
        shape([p + P(-2, 0), p + P(-2, -5), p + P(2, -5), p + P(2, 0)], .colour(I.stone), width: 0.7)
        colour([p + P(0.6, 0), p + P(0.6, -5), p + P(2, -5), p + P(2, 0)], .colour(I.stoneShade))
        line([p + P(-2, 0), p + P(-2, -5), p + P(2, -5), p + P(2, 0)], width: 0.7)
        svg.ellipse(p + P(0, -5.2), 2.4, 1.1, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.6)
        svg.ellipse(p + P(0, -2.4), 2.2, 0.8, fill: .none, stroke: .colour(I.straw), width: 0.9)
    }

    /// A rack of two posts and a bar along the quay from `a` to `b`, nets hung
    /// over it to dry, falling in folds, with cork floats along their heads.
    private mutating func netRack(from a: (Double, Double), to b: (Double, Double)) {
        typealias I = AlchemyOldBuildingsInk
        let h0 = Boathouse.h0, top = 17.0
        let pa = iso(a.0, a.1, h0), pb = iso(b.0, b.1, h0)
        shadow([pa + P(-2, 1), pb + P(2, 1), pb + P(5, 3), pa + P(1, 3)], opacity: 0.1)
        pole(pa, pa - P(0, top + 1.5), width: 1.6, colour: I.oak)
        pole(pb, pb - P(0, top + 1.5), width: 1.6, colour: I.oak)
        // The nets: hung over the bar, falling in a curtain to above the ground, gathered in folds.
        let bar0 = pa - P(0, top), bar1 = pb - P(0, top)
        let steps = 8
        var curtain: [P] = [], hem: [P] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let at = bar0 + (bar1 - bar0) * t
            curtain.append(at)
            hem.append(at + P(0, 12.5 + 1.6 * sin(t * .pi * 3)))
        }
        colour(curtain + hem.reversed(), .colour(I.timberDark), opacity: 0.55)
        var mesh = PathData()
        for i in 0...steps {
            mesh.move(curtain[i]); mesh.line(hem[i])
        }
        for k in 1..<5 {
            let f = Double(k) / 5
            for i in 0...steps { let p = curtain[i] + (hem[i] - curtain[i]) * f; if i == 0 { mesh.move(p) } else { mesh.line(p) } }
        }
        svg.path(mesh, stroke: .colour(I.straw), width: 0.45, opacity: 0.85)
        line(curtain + hem.reversed(), closed: true, width: 0.6)
        pole(bar0 + P(-1, 0.5), bar1 + P(1, -0.5), width: 1.3, colour: I.oakLight)
        for i in stride(from: 1, to: steps, by: 2) {
            svg.ellipse(curtain[i] + P(0, 1.6), 1.1, 0.8, fill: .colour(I.clay), stroke: .colour(I.line), width: 0.45)
        }
    }

    /// An iron anchor leaning against the wall at `p` on the screen: shank, stock, arms and ring.
    private mutating func anchor(at p: P) {
        typealias I = AlchemyOldBuildingsInk
        let top = p + P(-3, -15)
        svg.line([p, top], stroke: .colour(I.line), width: 2.2)
        svg.line([p, top], stroke: .colour(I.iron), width: 1.1)
        line([top + P(-3.4, 1.8), top + P(3.4, -1.4)], width: 1.6)
        svg.circle(top + P(-0.3, -1.4), 1.2, fill: .none, stroke: .colour(I.line), width: 0.8)
        line(width: 1.8) { d in
            d.move(p + P(-5, -4)); d.quad(p + P(0, 1.4), p + P(5, -4))
        }
        line(width: 0.7) { d in
            d.move(p + P(-5, -4)); d.quad(p + P(0, 1.4), p + P(5, -4))
        }
        svg.path("M\(num(p.x - 5)),\(num(p.y - 4)) q\(num(0)),\(num(-0.4)) \(num(2.6)),\(num(1)) M\(num(p.x + 5)),\(num(p.y - 4)) q\(num(0)),\(num(-0.4)) \(num(-2.6)),\(num(1))",
                 stroke: .colour(I.ironLight), width: 0.5)
    }

    /// A creel of wicker, domed, its mouth dark, standing at `p` on the screen.
    private mutating func creel(at p: P, size s: Double = 1) {
        typealias I = AlchemyOldBuildingsInk
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-4.4 * s, 0) + o)
            d.quad(p + P(-4.8 * s, -6.4 * s) + o, p + P(0, -6.6 * s) + o)
            d.quad(p + P(4.8 * s, -6.4 * s) + o, p + P(4.4 * s, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.straw)) { d, o in d = outline(o) }
        var weave = PathData()
        for k in 1..<4 {
            let f = Double(k) / 4
            weave.move(p + P(-4.4 * s * (1 - f * 0.3), -6 * s * f)); weave.line(p + P(4.4 * s * (1 - f * 0.3), -6 * s * f))
        }
        for x in [-2.4, 0, 2.4] { weave.move(p + P(x * s, 0)); weave.line(p + P(x * 0.6 * s, -6.2 * s)) }
        svg.path(weave, stroke: .colour(I.strawShade), width: 0.5)
        svg.ellipse(p + P(1.4 * s, -3 * s), 1.4 * s, 1.2 * s, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.4)
        line(width: 0.8) { d in d = outline(P(0, 0)) }
    }

    /// A coil of rope lying on the quay at `p` on the screen.
    private mutating func rope(at p: P) {
        typealias I = AlchemyOldBuildingsInk
        for (k, r) in [4.6, 3.4, 2.2].enumerated() {
            svg.ellipse(p + P(0, -Double(k) * 0.9), r, r * 0.45, fill: .none, stroke: .colour(I.line), width: 1.6)
            svg.ellipse(p + P(0, -Double(k) * 0.9), r, r * 0.45, fill: .none, stroke: .colour(I.straw), width: 0.8)
        }
        line([p + P(4.4, -0.6), p + P(8, 0.8)], width: 1.4)
        svg.line([p + P(4.4, -0.6), p + P(8, 0.8)], stroke: .colour(I.straw), width: 0.6)
    }

    // MARK: Under construction

    /// The boat house being built: its walls raised partway in fresh stone, the
    /// water door's arch turned on a wooden centring, scaffolding along the long
    /// wall flying the pennant, a smack's keel and ribs on the stocks on the
    /// slipway's runners, and stone, slates and mortar to hand.
    private mutating func stoneBoathouseRising() {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let (x0, y0, x1, y1, h0) = (B.x0, B.y0, B.x1, B.y1, B.h0)
        let top = 15.0
        slates(0.62, -0.94, 0.9, -0.7, from: h0, height: 6)
        shadow([iso(x1, y0, h0), iso(x1 + 0.18, y0 + 0.1, h0), iso(x1 + 0.18, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.08, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.pavingShade)) { p in
            p.basket(at: p.iso(-0.5, -0.3, h0), size: 0.9)
            p.timbers(-0.6, -0.5, length: 0.5, on: h0)
        }
        // The back walls raised two courses higher toward the far corner, as the masons leave them.
        block(x0, y0, x1 - 0.34, y0 + 0.08, top, top + 7.2, top: .colour(I.rawStoneTop), left: .colour(I.rawStone),
              right: .colour(I.rawStoneShade), width: 0.9)
        block(x0, y0 + 0.08, x0 + 0.08, y1 - 0.36, top, top + 7.2, top: .colour(I.rawStoneTop), left: .colour(I.rawStone),
              right: .colour(I.rawStoneShade), width: 0.9)
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, B.sideLength, 0, top - h0, course: 3.6, brick: 8.4, opacity: 0.6)
            p.shape(p.panel(4, 0, 11, 11), .colour(I.dark), width: 0.9)
            p.shape(p.panel(3.4, 11, 11.6, 12.6), .colour(I.oak), width: 0.6)
            p.paintedBand(0, B.sideLength, 1, 2.6)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.courses(0, B.gableLength, 0, top - h0, course: 3.6, brick: 8.4, opacity: 0.6)
            p.centring()
        }
        // The slipway's runners laid on the quay, the keel and ribs of a smack on its stocks over them.
        slipway(runners: true, flags: false)
        smackOnTheStocks()
        // Scaffolding along the long wall, its tallest pole flying the owner's pennant.
        scaffold([(x0 + 0.04, y1 + 0.2), (-0.36, y1 + 0.2), (x1 - 0.06, y1 + 0.2)], from: h0, height: 30, levels: [12, 24], boards: 12,
                 inward: (0, -0.14))
        pennant(at: iso(x0 + 0.04, y1 + 0.2, h0 + 30), height: 11, length: 13)
        ladder(foot: iso(0.1, 0.82, h0), iso(0.24, 0.82, h0), head: iso(0.1, y1 + 0.26, h0 + 13), iso(0.24, y1 + 0.26, h0 + 13), rungs: 4)
        blocks(-0.9, 0.72, -0.62, 0.94, from: h0, courses: 2)
        blocks(0.62, 0.5, 0.88, 0.8, from: h0, courses: 1)
        basket(at: iso(0.46, 0.84, h0), size: 0.9)
    }

    /// The wooden centring the water door's arch is turned on, on a wall drawn
    /// with `wall`: a half circle of boards on two props, its first voussoirs
    /// laid up one side.
    private mutating func centring(at u: Double = Boathouse.doorMiddle, opening: String = AlchemyOldBuildingsInk.dark) {
        typealias I = AlchemyOldBuildingsInk
        let w = Boathouse.doorWidth, h = Boathouse.doorHeight
        let r = w / 2, spring = h - r
        // The opening between the jambs: dark from without, the light off the water from within.
        shape(panel(u - r, 0, u + r, 13.5), .colour(opening), width: 0.8)
        // The props and the centring's boards.
        for du in [-r + 1.6, r - 1.6] { timber(uv(u + du, 0), uv(u + du, spring), width: 1.4, paint: I.timberLight) }
        timber(uv(u - r, spring), uv(u + r, spring), width: 1.5, paint: I.timberLight)
        var arc: [P] = []
        for k in 0...10 {
            let a = Double(k) / 10 * .pi
            arc.append(uv(u - r * cos(a), spring + r * sin(a)))
        }
        shape(arc + [uv(u + r, spring - 0.4), uv(u - r, spring - 0.4)], .colour(I.timber), width: 0.7)
        timber(uv(u, spring), uv(u, spring + r - 0.4), width: 1.1, paint: I.timberLight)
        timber(uv(u - r * 0.7, spring + 0.4), uv(u, spring + r * 0.7), width: 1, paint: I.timberLight)
        // The first stones of the arch, laid up its left side on the centring.
        for k in 0..<3 {
            let a0 = Double(k) / 9 * .pi, a1 = Double(k + 1) / 9 * .pi
            let stone = [uv(u - r * cos(a0), spring + r * sin(a0)), uv(u - (r + 2.5) * cos(a0), spring + (r + 2.5) * sin(a0)),
                         uv(u - (r + 2.5) * cos(a1), spring + (r + 2.5) * sin(a1)), uv(u - r * cos(a1), spring + r * sin(a1))]
            shape(stone, .colour(I.rawStoneTop), width: 0.6)
        }
    }

    /// A smack's keel and ribs on the stocks over the slipway: the keel on
    /// three blocks, the stem and the stern post standing, and ribs curving up
    /// from the keel, the after ones not yet set.
    private mutating func smackOnTheStocks(back: Bool = false) {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let y = (B.slipY0 + B.slipY1) / 2, h = B.h0 + 3.5
        let xa = 0.42, xb = 0.86
        func at(_ a: Double, _ b: Double, _ z: Double) -> P {
            let p = B.turn(a, b, back: back)
            return iso(p.x, p.y, z)
        }
        // From the back, the stem is the farthest part: the stocks and ribs are drawn from it toward the viewer.
        for x in back ? [0.8, 0.64, 0.48] : [0.48, 0.64, 0.8] {
            let (p, q) = (B.turn(x - 0.035, y - 0.06, back: back), B.turn(x + 0.035, y + 0.06, back: back))
            block(min(p.x, q.x), min(p.y, q.y), max(p.x, q.x), max(p.y, q.y), B.h0, h - 0.5, top: .colour(I.timberLight),
                  left: .colour(I.timber), right: .colour(I.timberDark), width: 0.6)
        }
        // The ribs on the far side, then the keel, then those on the near side.
        let ribs = stride(from: xa + 0.07, through: xb - 0.12, by: 0.065).map { $0 }
        let order = back ? Array(ribs.enumerated().reversed()) : Array(ribs.enumerated())
        for (_, x) in order { rib(x, y, h, side: -1, back: back) }
        let (k0, k1) = (B.turn(xa, y, back: back), B.turn(xb, y, back: back))
        beam(k0.x, k0.y, k1.x, k1.y, on: h - 0.5, size: 2)
        // The stern post and the stem.
        pole(at(xa, y, h), at(xa - 0.03, y, h + 12), width: 1.8, colour: I.oak)
        pole(at(xb, y, h), at(xb + 0.06, y, h + 14), width: 1.8, colour: I.oak)
        for (i, x) in order where i % 2 == 0 || i > 2 { rib(x, y, h, side: 1, back: back) }
        // A plank of the strake already fitted near the stem, painted in the owner's colour.
        let near = [at(xb - 0.28, y + 0.13, h + 8.4), at(xb - 0.02, y + 0.04, h + 12.4), at(xb - 0.02, y + 0.04, h + 10.4),
                    at(xb - 0.28, y + 0.13, h + 6.6)]
        shape(near, .team, width: 0.6)
    }

    /// One rib of the smack on the stocks at `x`, curving up from the keel to
    /// the side `side` (-1 far, 1 near), given in the side view's frame.
    private mutating func rib(_ x: Double, _ y: Double, _ h: Double, side: Double, back: Bool = false) {
        typealias I = AlchemyOldBuildingsInk
        let points = [(y, h), (y + side * 0.1, h + 3), (y + side * 0.14, h + 8), (y + side * 0.15, h + 12)].map { b, z in
            let p = Boathouse.turn(x, b, back: back)
            return iso(p.x, p.y, z)
        }
        svg.line(points, stroke: .colour(I.line), width: 2.2)
        svg.line(points, stroke: .colour(side < 0 ? I.timberDark : I.timberLight), width: 1.1)
    }

    // MARK: The back view

    /// The complete boat house from behind, its water toward -y: beyond it the
    /// hoist over the loft door in the far gable, the slipway with its
    /// runners and bollards running to the water, the pennant at its foot and
    /// barrels of herring; toward the viewer the landward gable with its cart
    /// doors, a lantern and a loft window under the finial, and the long wall
    /// with its door, its window and the banner, nets drying on their rack,
    /// creels, a coil of rope and the anchor before it.
    private mutating func stoneBoathouseFromBehind() {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let (x0, y0, x1, y1, h0, e) = (B.backX0, B.backY0, B.backX1, B.backY1, B.h0, B.eave)
        let xm = (x0 + x1) / 2
        // Beyond the building, toward the water: the hoist, the slipway, the pennant and the barrels.
        hoist(at: iso(xm, y0, e + 12.4), toward: P(9, -4.5))
        slipway(back: true)
        pennant(at: iso(0.3, -0.92, h0), height: 34, length: 15)
        barrel(at: iso(0.5, -0.88, h0), size: 0.8)
        barrel(at: iso(0.7, -0.84, h0), size: 0.8)
        barrel(at: iso(0.6, -0.92, h0) + P(0, -7.4), size: 0.72)
        // The building's shadow on the quay, to the right.
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        // The landward gable, toward the viewer.
        wall(.left, from: x0, y1, at: h0) { p in
            p.boathouseWall(B.gableLength, e - h0, quoinAtStart: false)
            p.cartDoors(at: B.gableLength / 2 - 1)
            p.lantern(at: p.uv(4.6, 13), arm: 1)
            p.paintedBand(0, B.gableLength, e - h0 - 4.4, e - h0 - 2.4)
        }
        // The long wall, as in the side view, its landward end now the near corner.
        wall(.right, from: x1, y1, at: h0) { p in
            p.boathouseWall(B.sideLength, e - h0, quoinAtStart: true)
            p.door(B.backDoor, 0, w: 7, h: 12)
            p.casement(17.5, 5, w: 9, h: 7, lights: 2, frame: I.stoneTop)
            p.paintedBand(0, B.sideLength, e - h0 - 4.4, e - h0 - 2.4)
            p.banner(31.5, top: e - h0 - 5.6, width: 6, length: 12)
        }
        // The roof, its landward gable toward the viewer with a loft window and a round window in it.
        gableAlongY(x0, y0, x1, y1, eave: e, ridge: B.ridge, over: 0.06, gableWall: .colour(I.stone), finials: false) { p, w, rise in
            var courses = PathData()
            for v in stride(from: 3.6, to: rise - 2, by: 3.6) {
                let inset = v / rise * w / 2
                courses.move(p.uv(inset + 0.4, v)); courses.line(p.uv(w - inset - 0.4, v))
            }
            p.svg.path(courses, stroke: .colour(I.line), width: 0.45, opacity: 0.4)
            p.casement(w / 2 - 3.5, 2.4, w: 7, h: 6.4, lights: 2, frame: I.stoneTop)
            p.svg.circle(p.uv(w / 2, rise - 6.4), 2.3, fill: .colour(I.stoneTop), stroke: .colour(I.line), width: 0.6)
            p.svg.circle(p.uv(w / 2, rise - 6.4), 1.5, fill: .colour(I.glass), stroke: .colour(I.line), width: 0.4)
            p.svg.circle(p.uv(w / 2, rise - 6.4) + P(-0.4, -0.5), 0.5, fill: .colour(I.glassLight))
        }
        weathervane(at: iso(xm, y0 - 0.06, B.ridge), height: 17)
        finial(at: iso(xm, y1 + 0.06, B.ridge), size: 0.9)
        // Before the long wall: the anchor leaning on the corner by the water, a coil of rope, creels and the nets on their rack.
        anchor(at: iso(x1 + 0.06, y0 + 0.08, h0))
        rope(at: iso(0.72, -0.18, h0))
        creel(at: iso(0.86, 0.06, h0), size: 0.9)
        creel(at: iso(0.66, 0.24, h0))
        netRack(from: (0.9, 0.46), to: (0.9, 0.92))
    }

    /// The landward gable's cart doors on a wall drawn with `wall`: two leaves
    /// of teal plank under a round head of voussoirs, centred on `u`, each
    /// hung on iron straps with a ring.
    private mutating func cartDoors(at u: Double) {
        typealias I = AlchemyOldBuildingsInk
        let w = 12.0, h = 15.0, r = w / 2
        arch(u, 0, width: w + 4, height: h + 2, .colour(I.stoneTop), line: 0.8)
        voussoirs(u, spring: h - r, inner: r, outer: r + 2, count: 7)
        arch(u, 0, width: w, height: h, .colour(I.teal), line: 0.9)
        var planks = PathData()
        for du in [-3.6, -1.8, 1.8, 3.6] { planks.move(uv(u + du, 0.3)); planks.line(uv(u + du, h - r * 0.4)) }
        svg.path(planks, stroke: .colour(I.line), width: 0.4, opacity: 0.6)
        line([uv(u, 0), uv(u, h)], width: 0.8)
        for v in [h * 0.2, h * 0.58] {
            shape(panel(u - r + 0.3, v - 0.45, u - 0.9, v + 0.45), .colour(I.iron), width: 0.4)
            shape(panel(u + 0.9, v - 0.45, u + r - 0.3, v + 0.45), .colour(I.iron), width: 0.4)
        }
        for du in [-1.5, 1.5] { svg.circle(uv(u + du, h * 0.4), 0.8, fill: .none, stroke: .colour(I.ironDark), width: 0.45) }
    }

    /// The boat house being built, from behind: beyond the walls the slipway's
    /// runners and bollards and a smack's keel and ribs on the stocks over
    /// them; within, the water door's arch turned on its centring in the far
    /// gable, the light off the water in its opening; the far long wall raised
    /// higher toward the far corner; scaffolding along the near long wall
    /// flying the pennant, and stone, slates and mortar to hand.
    private mutating func stoneBoathouseRisingFromBehind() {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let (x0, y0, x1, y1, h0) = (B.backX0, B.backY0, B.backX1, B.backY1, B.h0)
        let top = 15.0, t = 0.08, xm = (x0 + x1) / 2
        slates(-0.94, 0.62, -0.7, 0.9, from: h0, height: 6)
        slipway(back: true, runners: true, flags: false)
        smackOnTheStocks(back: true)
        shadow([iso(x1, y0, h0), iso(x1 + 0.18, y0 + 0.1, h0), iso(x1 + 0.18, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: t, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.pavingShade)) { p in
            // The far long wall raised two courses higher toward the far corner, with a return along the far gable.
            p.block(x0, y0, x0 + t, y1 - 0.36, top, top + 7.2, top: .colour(I.rawStoneTop), left: .colour(I.rawStone),
                    right: .colour(I.rawStoneShade), width: 0.9)
            p.block(x0 + t, y0, x0 + 0.2, y0 + t, top, top + 7.2, top: .colour(I.rawStoneTop), left: .colour(I.rawStone),
                    right: .colour(I.rawStoneShade), width: 0.9)
            p.wall(.left, from: x0 + t, y0 + t, at: h0) { q in q.centring(at: (xm - x0 - t) * 32, opening: I.glass) }
            p.timbers(-0.5, 0.3, length: 0.5, on: h0)
            p.basket(at: p.iso(0.1, 0.06, h0), size: 0.9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, B.gableLength, 0, top - h0, course: 3.6, brick: 8.4, opacity: 0.6)
            p.shape(p.panel(9, 0, 21, 11), .colour(I.dark), width: 0.9)
            p.shape(p.panel(8.4, 11, 21.6, 12.6), .colour(I.oak), width: 0.6)
            p.paintedBand(0, B.gableLength, 1, 2.6)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.courses(0, B.sideLength, 0, top - h0, course: 3.6, brick: 8.4, opacity: 0.6)
            p.shape(p.panel(B.backDoor - 3.5, 0, B.backDoor + 3.5, 11), .colour(I.dark), width: 0.9)
            p.shape(p.panel(B.backDoor - 4.1, 11, B.backDoor + 4.1, 12.6), .colour(I.oak), width: 0.6)
        }
        blocks(0.5, -0.88, 0.8, -0.62, from: h0, courses: 1)
        // Scaffolding along the near long wall, its tallest pole flying the owner's pennant.
        scaffold([(x1 + 0.2, y1 - 0.04), (x1 + 0.2, 0.36), (x1 + 0.2, y0 + 0.06)], from: h0, height: 30, levels: [12, 24], boards: 12,
                 inward: (-0.14, 0))
        pennant(at: iso(x1 + 0.2, y1 - 0.04, h0 + 30), height: 11, length: 13)
        basket(at: iso(0.84, -0.46, h0), size: 0.9)
        ladder(foot: iso(0.82, -0.1, h0), iso(0.82, -0.24, h0), head: iso(x1 + 0.26, -0.1, h0 + 13), iso(x1 + 0.26, -0.24, h0 + 13), rungs: 4)
        blocks(0.72, 0.62, 0.94, 0.9, from: h0, courses: 2)
    }

    // MARK: The dock

    /// The dock (ruled 2026-11-22): a quay of dressed stone running on from
    /// the slipway straight out over the water, about a tile beyond the
    /// footprint, on a footing of darker stone with the water ringed about
    /// it; its flags at the slipway's height, two steps down to the water at
    /// its end, an iron mooring ring on its long side and a bollard by the
    /// steps. Under construction: its footing laid the whole way out, the
    /// first part raised in fresh stone, and a block waiting on the footing.
    /// In the side view's frame, turned for the back view.
    private mutating func dock(complete: Bool, back: Bool) {
        typealias I = AlchemyOldBuildingsInk
        typealias B = Boathouse
        let (a0, a1, b0, b1, h) = (B.dockX0, B.dockX1, B.slipY0, B.slipY1, B.h0 + B.slip)
        let foot = 0.9, out = 0.03, end = a1 + 2 * B.dockStep
        func at(_ a: Double, _ b: Double, _ z: Double) -> P {
            let p = B.turn(a, b, back: back)
            return iso(p.x, p.y, z)
        }
        /// A block given in the side view's frame.
        func box(_ a0: Double, _ b0: Double, _ a1: Double, _ b1: Double, _ z0: Double, _ z1: Double, _ top: String, _ lit: String,
                 _ shade: String, width: Double = 0.9) {
            let (p, q) = (B.turn(a0, b0, back: back), B.turn(a1, b1, back: back))
            block(min(p.x, q.x), min(p.y, q.y), max(p.x, q.x), max(p.y, q.y), z0, z1, top: .colour(top), left: .colour(lit),
                  right: .colour(shade), width: width)
        }
        // The water ringed about the footing: at its far corners and along its sides.
        let reach = complete ? end : a1
        for (a, b) in [(reach + out, b0 - out), (reach + out, b1 + out), (a0 + 0.3, b0 - out), (a0 + 0.62, b0 - out),
                       (a0 + 0.3, b1 + out), (a0 + 0.62, b1 + out)] {
            waterRing(at: at(a, b, 0), size: 1)
        }
        // The footing, the whole way out.
        box(a0, b0 - out, reach + out, b1 + out, 0, foot, complete ? I.footing : I.rawStoneShade, complete ? I.footing : I.rawStone,
            complete ? I.footingShade : I.rawStoneShade)
        guard complete else {
            // The first part raised in fresh stone, a block waiting on the footing beyond it.
            box(a0, b0, a0 + 0.42, b1, foot, h, I.rawStoneTop, I.rawStone, I.rawStoneShade)
            var joints = PathData()
            for a in stride(from: a0 + 0.14, to: a0 + 0.42, by: 0.14) { joints.move(at(a, b0, h)); joints.line(at(a, b1, h)) }
            svg.path(joints, stroke: .colour(I.line), width: 0.4, opacity: 0.45)
            box(a0 + 0.6, b0 + 0.06, a0 + 0.74, b0 + 0.2, foot, foot + 2.4, I.rawStoneTop, I.rawStone, I.rawStoneShade, width: 0.7)
            return
        }
        // The steps down to the water: from the back, the lower one is the farther and is drawn first.
        let steps = [(a1, a1 + B.dockStep, h * 2 / 3), (a1 + B.dockStep, end, h / 3)]
        if back { for (s0, s1, top) in steps.reversed() { box(s0, b0, s1, b1, foot, top, I.stoneTop, I.stone, I.stoneShade, width: 0.8) } }
        box(a0, b0, a1, b1, foot, h, I.stoneTop, I.stone, I.stoneShade)
        if !back { for (s0, s1, top) in steps { box(s0, b0, s1, b1, foot, top, I.stoneTop, I.stone, I.stoneShade, width: 0.8) } }
        // The flags, their joints across the quay and down its middle, and the wet toward its end.
        var joints = PathData()
        for a in stride(from: a0 + 0.14, to: a1 - 0.05, by: 0.14) { joints.move(at(a, b0, h)); joints.line(at(a, b1, h)) }
        joints.move(at(a0, (b0 + b1) / 2, h)); joints.line(at(a1, (b0 + b1) / 2, h))
        svg.path(joints, stroke: .colour(I.line), width: 0.45, opacity: 0.45)
        colour([at(a1 - 0.16, b0 + 0.02, h), at(a1 - 0.02, b0 + 0.02, h), at(a1 - 0.02, b1 - 0.02, h), at(a1 - 0.16, b1 - 0.02, h)],
               .colour(I.glass), opacity: 0.4)
        // The iron mooring ring on the quay's long side toward the viewer.
        let side = B.turn(a0, b1, back: back)
        wall(back ? .right : .left, from: side.x, side.y, at: foot) { p in
            // The joints of the dressed stones along it.
            p.courses(0, (a1 - a0) * 32, 0, h - foot, course: h - foot, brick: 6.4, opacity: 0.5)
            let u = (a1 - a0) * 32 * 0.55
            p.shape(p.panel(u - 1, h - foot - 1.3, u + 1, h - foot - 0.3), .colour(I.ironDark), width: 0.4)
            p.svg.ellipse(p.uv(u, h - foot - 2.2), 1.5, 1.3, fill: .none, stroke: .colour(I.line), width: 1.1)
            p.svg.ellipse(p.uv(u, h - foot - 2.2), 1.5, 1.3, fill: .none, stroke: .colour(I.ironLight), width: 0.45)
        }
        // A bollard by the head of the steps, on the side toward the viewer.
        bollard(at: at(a1 - 0.09, b1 - 0.09, h))
    }

    /// A ring on the water about the foot of something standing in it, at `p` on the screen.
    private mutating func waterRing(at p: P, size s: Double) {
        typealias I = AlchemyOldBuildingsInk
        svg.ellipse(p + P(0, 0.4), 4.2 * s, 1.8 * s, fill: .none, stroke: .colour(I.glassLight), width: 0.8, opacity: 0.85)
        svg.ellipse(p + P(0, 0.6), 6.2 * s, 2.7 * s, fill: .none, stroke: .colour(I.glassLight), width: 0.5, opacity: 0.5)
    }
}
