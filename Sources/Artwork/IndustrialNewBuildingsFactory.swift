// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age factory: a shed of brick under a saw-tooth roof, its
// teeth of bottle-green slate each ending in a steep face of glass turned to the
// viewer. A tall round stack of brick rises from the yard and gives off coal
// smoke. Wide doors in the shed's end stand open on a field gun within; a
// signboard in the owner's colour runs along the front, under the glass, and
// a flag of the owner's colour flies from the front corner. The yard holds
// coal, iron girders, crates and drums of oil. Its footprint is three tiles
// square: x and y run from -1.5 to 1.5.

extension IndustrialNewBuildingsPainter {
    mutating func factory(complete: Bool) {
        typealias I = IndustrialNewBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, Factory.ground, top: .colour(I.yard), left: .colour(I.yardShade), right: .colour(I.yardShade),
              width: 1)
        factoryCinders()
        if complete { factoryComplete() } else { factoryRising() }
    }

    /// The factory's measures: on the map in tiles, heights in points.
    private enum Factory {
        static let ground = 1.5
        static let shed = (x0: -1.38, y0: -1.38, x1: 0.32, y1: 0.98)
        static let eave = 34.0, rise = 14.0
        static let teeth = 4
        /// The stack stands in the yard behind the shed's end.
        static let stack = (x: 0.98, y: -0.92)
        static let stackTop = 148.0
        /// The great doors in the shed's end: from `u0` to `u1` along it, `height` tall.
        static let doors = (u0: 22.0, u1: 44.0, height: 22.0)
    }

    /// Cinders and coal dust scattered over the yard, at fixed places, and the
    /// path of beaten cinder before the shed's front.
    private mutating func factoryCinders() {
        typealias I = IndustrialNewBuildingsInk
        let g = Factory.ground
        let places: [(Double, Double)] = [(-1.2, 1.25), (-0.6, 1.35), (0.15, 1.2), (1.3, -1.25), (0.6, -1.3), (1.35, 0.05),
                                          (0.5, 1.35), (-0.95, 1.1), (0.8, 0.2), (1.25, 1.3)]
        for (k, (px, py)) in places.enumerated() {
            svg.ellipse(iso(px, py, g), 1.6, 0.8, fill: .colour(k % 2 == 0 ? I.yardShade : I.sootDark), opacity: k % 2 == 0 ? 1 : 0.55)
        }
    }

    // MARK: The factory complete

    private mutating func factoryComplete() {
        typealias I = IndustrialNewBuildingsInk
        let (x0, y0, x1, y1) = Factory.shed
        let g = Factory.ground, eave = Factory.eave
        let front = (x1 - x0) * 32, end = (y1 - y0) * 32
        // The shed's shadow on the yard at its right.
        shadow([iso(x1, y0, g), iso(x1 + 0.5, y0 + 0.2, g), iso(x1 + 0.5, y1 + 0.2, g), iso(x1, y1, g)], opacity: 0.13)
        factoryStack(rising: false)
        brickwork(x0, y0, x1, y1, g, eave)
        wall(.left, from: x0, y1, at: g) { p in
            p.plinth(front)
            for u in [5.0, 18.5] {
                p.pier(u - 3.2, eave - g)
                p.archedWindow(u, 4.4, width: 8.4, height: 10.5)
            }
            p.pier(31.0 - 3.2, eave - g)
            p.smallDoor(33.5, width: 7.5, height: 13.5)
            p.pier(front - 6.6, eave - g)
            p.signboard(1.6, 19.2, front - 1.6, 28.4, text: "WORKS")
            p.cornice(front, eave - g)
        }
        wall(.right, from: x1, y1, at: g) { p in
            p.plinth(end)
            p.archedWindow(4, 4.4, width: 8.4, height: 13)
            p.archedWindow(end - 13, 4.4, width: 8.4, height: 13)
            p.greatDoors(Factory.doors.u0, Factory.doors.u1, height: Factory.doors.height)
        }
        fieldGun()
        wall(.right, from: x1, y1, at: g) { p in
            p.lintel(Factory.doors.u0, Factory.doors.u1, height: Factory.doors.height)
            p.cornice(end, eave - g)
        }
        sawtoothRoof(rising: false)
        flag(at: iso(x1, y1, eave + Factory.rise + 1), height: 20, length: 16)
        factoryYard()
    }

    /// A course of light stone at the foot of a wall drawn with `wall`, `length` long.
    mutating func plinth(_ length: Double) {
        typealias I = IndustrialNewBuildingsInk
        shape(panel(0, 0, length, 2.6), .colour(I.lightShade), width: 0.6)
    }

    /// A band of light stone along the top of a wall drawn with `wall`, `length`
    /// long and `height` tall, with a row of dentils under it.
    mutating func cornice(_ length: Double, _ height: Double) {
        typealias I = IndustrialNewBuildingsInk
        shape(panel(-0.4, height - 2.2, length + 0.4, height + 0.4), .colour(I.lightTop), width: 0.7)
        var d = PathData()
        var u = 1.6
        while u < length - 1 { d.move(uv(u, height - 2.2)); d.line(uv(u, height - 3.4)); u += 2.4 }
        svg.path(d, stroke: .colour(I.line), width: 0.9, opacity: 0.75)
    }

    /// A pier of brick standing out from a wall drawn with `wall`, from `u`, 3.2 wide and `height` tall.
    fileprivate mutating func pier(_ u: Double, _ height: Double) {
        typealias I = IndustrialNewBuildingsInk
        colour(panel(u, 2.6, u + 3.2, height - 2.2), .colour(I.brickLit))
        line([uv(u, 2.6), uv(u, height - 2.2)], width: 0.6, opacity: 0.8)
        line([uv(u + 3.2, 2.6), uv(u + 3.2, height - 2.2)], width: 0.8)
        courses(u, u + 3.2, 2.6, height - 2.2, opacity: 0.3)
    }

    /// A small door of bottle-green planks on a wall drawn with `wall`, from `u`, with a fanlight.
    fileprivate mutating func smallDoor(_ u: Double, width w: Double, height h: Double) {
        typealias I = IndustrialNewBuildingsInk
        shape(panel(u - 1.2, 0, u + w + 1.2, h + 1.6), .colour(I.brickDark), width: 0.6)
        shape(panel(u, 0, u + w, h - 3), .colour(I.green), width: 0.8)
        colour(panel(u + 0.6, 0.6, u + w * 0.45, h - 3.6), .colour(I.greenLit))
        line([uv(u + w / 2, 0.4), uv(u + w / 2, h - 3.4)], width: 0.5)
        shape(panel(u, h - 2.6, u + w, h), .colour(I.glass), width: 0.6)
        svg.circle(uv(u + w * 0.82, h * 0.42), 0.55, fill: .colour(I.brass))
        shape(panel(u - 1.2, -1.1, u + w + 1.2, 0.1), .colour(I.lightTop), width: 0.5)
    }

    /// The great doors in the shed's end, on a wall drawn with `wall`, from
    /// `u0` to `u1`: an opening, its two leaves of bottle-green planks folded back
    /// against the wall, and the dusk of the shop within.
    fileprivate mutating func greatDoors(_ u0: Double, _ u1: Double, height h: Double) {
        typealias I = IndustrialNewBuildingsInk
        let w = u1 - u0, leaf = w / 2 - 0.6
        // The leaves, folded back.
        for (a, b) in [(u0 - leaf, u0), (u1, u1 + leaf)] {
            shape(panel(a, 0.3, b, h - 0.8), .colour(I.green), width: 0.8)
            for k in 1..<4 {
                let x = a + (b - a) * Double(k) / 4
                line([uv(x, 0.8), uv(x, h - 1.3)], width: 0.4, opacity: 0.7)
            }
            line([uv(a, 0.6), uv(b, h - 1.4)], width: 0.8, opacity: 0.9)
            line([uv(a, 4), uv(b, 4)], width: 0.8)
            line([uv(a, h - 5), uv(b, h - 5)], width: 0.8)
        }
        // The shop within.
        shape(panel(u0, 0, u1, h), .colour(I.dark), width: 1)
        colour(panel(u0 + 0.6, 0, u1 - 0.6, h * 0.3), .colour(I.sootDark))
        // An iron column far within, and the glow of a forge at the back.
        line([uv(u0 + 4, 3), uv(u0 + 4, h)], width: 1.4, opacity: 0.8)
        svg.ellipse(uv(u1 - 4, h * 0.55), 2.6, 3.6, fill: .colour(I.fire), opacity: 0.55)
        svg.ellipse(uv(u1 - 4, h * 0.5), 1.3, 1.9, fill: .colour(I.fireCore), opacity: 0.7)
        // The light from the door on the floor before the gun.
        colour(panel(u0 + 1, 0, u1 - 1, 1.4), .colour(I.yard), opacity: 0.6)
    }

    /// The riveted lintel of iron over the great doors, on a wall drawn with
    /// `wall`, from `u0` to `u1` at `h`, on bearings of stone.
    fileprivate mutating func lintel(_ u0: Double, _ u1: Double, height h: Double) {
        typealias I = IndustrialNewBuildingsInk
        shape(panel(u0 - 2.4, h, u1 + 2.4, h + 3), .colour(I.soot), width: 0.8)
        var rivets = PathData()
        var u = u0 - 1
        while u < u1 + 1.5 {
            rivets.move(uv(u, h + 1.5)); rivets.line(uv(u + 0.01, h + 1.5))
            u += 2.2
        }
        svg.path(rivets, stroke: .colour(I.sootLit), width: 0.9)
        shape(panel(u0 - 3.4, h - 1.4, u0 - 0.2, h), .colour(I.lightTop), width: 0.5)
        shape(panel(u1 + 0.2, h - 1.4, u1 + 3.4, h), .colour(I.lightTop), width: 0.5)
    }

    /// A field gun standing in the shop, facing out of the great doors, seen
    /// through them: its spoked wheels, its shield, and its barrel catching the
    /// light from the door. It is cut to the doors' opening.
    private mutating func fieldGun() {
        typealias I = IndustrialNewBuildingsInk
        let (_, _, x1, y1) = Factory.shed
        let g = Factory.ground, h = Factory.doors.height
        let ya = y1 - Factory.doors.u0 / 32, yb = y1 - Factory.doors.u1 / 32
        let opening = [iso(x1, ya, g), iso(x1, yb, g), iso(x1, yb, g + h), iso(x1, ya, g + h)]
        let points = opening.map { "\(num($0.x)),\(num($0.y))" }.joined(separator: " ")
        svg.raw("<clipPath id=\"factory-doors\"><polygon points=\"\(points)\"/></clipPath><g clip-path=\"url(#factory-doors)\">")
        let cy = (ya + yb) / 2, ax = x1 - 0.2, r = 6.4, axle = g + r
        /// A spoked wheel of timber with an iron tyre, in the plane facing +y at `y`.
        func wheel(_ p: inout IndustrialNewBuildingsPainter, at y: Double, dim: Bool) {
            p.wall(.left, from: ax, y, at: axle) { q in
                q.svg.circle(P(0, 0), r + 0.6, fill: .colour(I.line))
                q.svg.circle(P(0, 0) + q.shift * 0.4, r - 0.2, fill: .colour(dim ? I.sootShade : I.steel))
                q.svg.circle(P(0, 0), r - 1.4, fill: .colour(dim ? I.dark : I.sootDark))
                var spokes = PathData()
                for k in 0..<10 {
                    let a = Double(k) * .pi / 5
                    spokes.move(P(cos(a), sin(a)) * 1.2); spokes.line(P(cos(a), sin(a)) * (r - 1.4))
                }
                q.svg.path(spokes, stroke: .colour(I.line), width: 1.5)
                q.svg.path(spokes, stroke: .colour(dim ? I.timberDark : I.timberLight), width: 0.7)
                q.svg.circle(P(0, 0), r - 1.4, fill: .none, stroke: .colour(I.line), width: 0.6)
                q.svg.circle(P(0, 0), 1.6, fill: .colour(I.soot), stroke: .colour(I.line), width: 0.6)
            }
        }
        wheel(&self, at: cy - 0.16, dim: true)
        // The trail, running back into the shop.
        pole(iso(ax, cy, axle - 1), iso(ax - 0.42, cy, g + 1), width: 2.2, colour: I.sootShade)
        // The shield: a plate turned to the doors, its upper corners cut.
        let sx = ax + 0.02
        wall(.right, from: sx, cy + 0.15, at: g + 2.6) { q in
            let w = 0.3 * 32
            let plate = [q.uv(0, 0), q.uv(w, 0), q.uv(w, 9.4), q.uv(w - 1.6, 11.4), q.uv(1.6, 11.4), q.uv(0, 9.4)]
            q.shape(plate, .colour(I.sootLit), width: 0.8)
            q.colour([q.uv(0.6, 0.6), q.uv(3.2, 0.6), q.uv(3.2, 10.8), q.uv(1.8, 10.8), q.uv(0.6, 9.2)], .colour(I.steel), opacity: 0.6)
            for (u, v) in [(1.2, 1.2), (w - 1.2, 1.2), (1.2, 8.6), (w - 1.2, 8.6)] { q.svg.circle(q.uv(u, v), 0.35, fill: .colour(I.line)) }
        }
        // The barrel, running out through the shield toward the doors.
        barrel(sx, x1 + 0.02, cy, axle + 2.4, radius: 1.6, body: I.soot, lit: I.steel, shade: I.sootDark, end: I.dark)
        wheel(&self, at: cy + 0.16, dim: false)
        svg.raw("</g>")
    }

    /// The saw-tooth roof over the shed: teeth running along x, each rising
    /// toward the viewer in bottle-green slate and ending in a steep face of glass, the
    /// zigzag of their ends seen on the shed's end. Being built, it is iron
    /// trusses only, over the back of the shed.
    private mutating func sawtoothRoof(rising: Bool) {
        typealias I = IndustrialNewBuildingsInk
        let (x0, y0, x1, y1) = Factory.shed
        let eave = Factory.eave, rise = Factory.rise
        let n = Factory.teeth, w = (y1 - y0) / Double(n)
        let over = 0.04
        for k in 0..<n {
            let a = y0 + Double(k) * w, b = a + w
            if rising {
                guard k < 2 else { continue }
                for x in stride(from: x0 + 0.02, through: x1, by: (x1 - x0 - 0.04) / 3) {
                    truss(x, a, b, eave: eave, rise: rise)
                }
                // Purlins along the slope, and the ridge.
                for t in [0.0, 0.5, 1.0] {
                    pole(iso(x0, a + w * t, eave + rise * t), iso(x1, a + w * t, eave + rise * t), width: 0.9, colour: I.soot)
                }
                continue
            }
            // The slope of slate, from the low back edge up to the glass.
            let slope = [iso(x0 - over, a, eave), iso(x1 + over, a, eave), iso(x1 + over, b, eave + rise), iso(x0 - over, b, eave + rise)]
            colour(slope, .colour(I.green))
            var courses = PathData()
            for t in stride(from: 0.2, to: 0.95, by: 0.2) {
                courses.move(iso(x0 - over, a + w * t, eave + rise * t)); courses.line(iso(x1 + over, a + w * t, eave + rise * t))
            }
            svg.path(courses, stroke: .colour(I.greenDark), width: 0.6, opacity: 0.85)
            var lit = PathData()
            for t in stride(from: 0.18, to: 0.95, by: 0.2) {
                lit.move(iso(x0 - over + 0.02, a + w * t, eave + rise * t)); lit.line(iso(x1 + over - 0.02, a + w * t, eave + rise * t))
            }
            svg.path(lit, stroke: .colour(I.greenLit), width: 0.5, opacity: 0.8)
            line(slope, closed: true, width: 1)
            // The glass, in iron bars, facing the viewer; its frame of bottle green.
            let glassLength = (x1 - x0 + 2 * over) * 32
            wall(.left, from: x0 - over, b, at: eave) { p in
                p.shape(p.panel(0, 0, glassLength, rise), .colour(I.glass), width: 0.9)
                p.colour(p.panel(0.4, 0.4, glassLength - 0.4, rise * 0.45), .colour(I.glassShade), opacity: 0.85)
                var bars = PathData()
                var u = 3.0
                while u < glassLength - 1 { bars.move(p.uv(u, 0)); bars.line(p.uv(u, rise)); u += 3.6 }
                bars.move(p.uv(0, rise / 2)); bars.line(p.uv(glassLength, rise / 2))
                p.svg.path(bars, stroke: .colour(I.greenShade), width: 0.55)
                p.line(p.panel(0, 0, glassLength, rise), closed: true, width: 0.9)
                p.colour(p.panel(0, rise - 1.4, glassLength, rise), .colour(I.greenDark))
                p.line([p.uv(0, rise - 1.4), p.uv(glassLength, rise - 1.4)], width: 0.6)
            }
            // The tooth's end, in brick, where the zigzag shows.
            let end = [iso(x1, a, eave), iso(x1, b, eave), iso(x1, b, eave + rise)]
            colour(end, .colour(I.brickShade))
            wall(.right, from: x1, b, at: eave) { p in
                // Courses only within the triangle, which narrows as it rises.
                var d = PathData()
                var v = 3.2
                while v < rise - 1 {
                    d.move(p.uv(0, v)); d.line(p.uv(w * 32 * (1 - v / rise), v)); v += 3.2
                }
                p.svg.path(d, stroke: .colour(I.line), width: 0.42, opacity: 0.32)
            }
            // The verge: the slope's edge capped in stone.
            colour([iso(x1 + over, a, eave), iso(x1 + over, b, eave + rise), iso(x1 + over, b, eave + rise + 1.6),
                    iso(x1 + over, a, eave + 1.6)], .colour(I.lightTop))
            line([iso(x1 + over, a, eave + 1.6), iso(x1 + over, b, eave + rise + 1.6)], width: 0.8)
            line(end, closed: true, width: 0.9)
        }
        if !rising {
            // The gutter along the front, over the cornice.
            line([iso(x0, y1, eave), iso(x1, y1, eave)], width: 1.4)
        }
    }

    /// One iron truss of a saw-tooth roof standing at `x`, from `a` to `b` along y:
    /// a tie at the eave, a post at the glass, and a rafter between.
    private mutating func truss(_ x: Double, _ a: Double, _ b: Double, eave: Double, rise: Double) {
        typealias I = IndustrialNewBuildingsInk
        let foot = iso(x, a, eave), toe = iso(x, b, eave), head = iso(x, b, eave + rise)
        pole(foot, toe, width: 1, colour: I.soot)
        pole(toe, head, width: 1.1, colour: I.soot)
        pole(foot, head, width: 1.2, colour: I.sootLit)
        let mid = iso(x, (a + b) / 2, eave)
        pole(mid, iso(x, (a + b) / 2, eave + rise / 2), width: 0.7, colour: I.soot)
        pole(mid, head, width: 0.6, colour: I.soot)
    }

    /// The round stack of brick in the yard, narrowing as it rises, on a square
    /// plinth, with bands of stone, a crown of iron, and coal smoke drifting
    /// from its mouth. Being built, it stands a third of its height within a
    /// tower of scaffolding.
    private mutating func factoryStack(rising: Bool) {
        typealias I = IndustrialNewBuildingsInk
        let (cx, cy) = Factory.stack, g = Factory.ground
        let r0 = 0.19, r1 = 0.13, plinth = 16.0
        let top = rising ? 64.0 : Factory.stackTop
        shadow([iso(cx + 0.24, cy - 0.24, g), iso(cx + 0.9, cy - 0.05, g), iso(cx + 0.95, cy + 0.1, g), iso(cx + 0.24, cy + 0.24, g)],
               opacity: 0.12)
        brickwork(cx - 0.25, cy - 0.25, cx + 0.25, cy + 0.25, g, plinth, top: .colour(I.lightTop), fresh: rising)
        wall(.left, from: cx - 0.25, cy + 0.25, at: g) { p in p.shape(p.panel(0, plinth - g - 2.2, 16, plinth - g), .colour(I.lightTop), width: 0.6) }
        wall(.right, from: cx + 0.25, cy + 0.25, at: g) { p in p.shape(p.panel(0, plinth - g - 2.2, 16, plinth - g), .colour(I.lightTop), width: 0.6) }
        // An arched flue opening at its foot.
        wall(.left, from: cx - 0.25, cy + 0.25, at: g) { p in
            p.shape([p.uv(5.4, 0), p.uv(10.6, 0), p.uv(10.6, 6), p.uv(8, 8), p.uv(5.4, 6)], .colour(I.dark), width: 0.6)
        }
        let rTop = r0 + (r1 - r0) * (top - plinth) / (Factory.stackTop - plinth)
        let lit = rising ? I.freshBrick : I.brickLit, mid = rising ? I.freshBrick : I.brick, shade = rising ? I.freshBrickShade : I.brickShade
        frustum(cx, cy, r0, rTop, plinth, top, lit: lit, mid: mid, shade: shade, top: rising ? .colour(I.dark) : nil)
        rings(cx, cy, r0, r1, plinth, Factory.stackTop, every: 3.2, from: plinth + 3.2, to: top, opacity: 0.32)
        if rising {
            // The stack's rim, open, and the scaffold tower round it.
            let r = rTop + 0.06
            scaffold([(cx - r, cy + r), (cx + r, cy + r), (cx + r, cy - r)], from: g, height: top + 8, levels: [20, 40, 60], boards: 60,
                     inward: (0, -0.1))
            flag(at: iso(cx + r, cy + r, top + 8), height: 16, length: 15)
            return
        }
        // Bands of stone, two thirds up and under the crown.
        for (h, size) in [(78.0, 2.4), (top - 14, 2.4)] {
            let r = r0 + (r1 - r0) * (h - plinth) / (top - plinth) + 0.012
            frustum(cx, cy, r, r, h, h + size, lit: I.lightTop, mid: I.light, shade: I.lightShade, width: 0.8)
        }
        // The crown: an iron collar standing out, and a cap of soot.
        frustum(cx, cy, r1 + 0.01, r1 + 0.035, top - 9, top - 4, lit: I.sootLit, mid: I.soot, shade: I.sootShade, width: 0.9)
        frustum(cx, cy, r1 + 0.035, r1 + 0.035, top - 4, top, lit: I.sootLit, mid: I.soot, shade: I.sootShade, top: .colour(I.sootDark),
                width: 0.9)
        let mouth = arc(cx, cy, r1 - 0.01, from: 0, to: 360, at: top, steps: 24)
        colour(mouth, .colour(I.oil))
        // Coal smoke, drifting to the right and paling as it goes.
        let m = iso(cx, cy, top)
        puff(at: m + P(1.5, -6), radius: 4.6, colour: I.smoke)
        puff(at: m + P(8, -15), radius: 5.6, colour: I.smoke)
        puff(at: m + P(16.5, -23), radius: 6, colour: I.smokeLight)
        puff(at: m + P(24.5, -28), radius: 4.2, colour: I.smokeLight)
    }

    /// The yard's contents: a heap of coal by the stack, iron girders, crates
    /// and drums of oil.
    private mutating func factoryYard() {
        typealias I = IndustrialNewBuildingsInk
        let g = Factory.ground
        coal(1.15, -0.25, radius: 0.24, height: 11)
        girders(0.55, 1.3, 0.62, on: g, count: 3)
        drum(at: iso(1.3, 0.25, g))
        drum(at: iso(1.32, 0.5, g), paint: I.soot, lit: I.sootLit)
        crate(0.62, 1.05, on: g)
        crate(0.62, 1.05, size: 0.2, height: 6, on: g + 7)
        crate(0.95, 1.12, on: g)
        drum(at: iso(-0.2, 1.3, g), size: 0.95)
    }

    // MARK: The factory being built

    /// The factory being built: its brick walls raised part of their height,
    /// higher at the back, the opening of the great doors left in the end; the
    /// iron trusses of the roof's back teeth standing on iron columns; the stack
    /// a third built within its scaffold, flying the owner's flag; and brick,
    /// girders and timber to hand.
    private mutating func factoryRising() {
        typealias I = IndustrialNewBuildingsInk
        let (x0, y0, x1, y1) = Factory.shed
        let g = Factory.ground, eave = Factory.eave
        let t = 0.16
        // The back walls, nearly to the eave.
        brickwork(x0, y0, x1, y0 + t, g, eave, top: .colour(I.freshBrick), fresh: true)
        brickwork(x0, y0 + t, x0 + t, y1, g, 26, top: .colour(I.freshBrick), fresh: true)
        // Iron columns within, carrying the trusses of the back teeth.
        let w = (y1 - y0) / Double(Factory.teeth)
        for y in [y0 + w, y0 + 2 * w] {
            for x in stride(from: x0 + 0.02, through: x1, by: (x1 - x0 - 0.04) / 3) {
                pole(iso(x, y, g), iso(x, y, eave), width: 1.6, colour: I.sootLit)
            }
        }
        sawtoothRoof(rising: true)
        // The stack, a third built, behind the end wall.
        factoryStack(rising: true)
        // The end wall, low, with the doors' opening; then the front, lowest.
        let doorA = y1 - Factory.doors.u0 / 32, doorB = y1 - Factory.doors.u1 / 32
        brickwork(x1 - t, y0 + t, x1, doorB, g, 20, top: .colour(I.freshBrick), fresh: true)
        brickwork(x1 - t, doorA, x1, y1, g, 14, top: .colour(I.freshBrick), fresh: true)
        brickwork(x0 + t, y1 - t, x1 - t, y1, g, 9, top: .colour(I.freshBrick), fresh: true)
        // The lintel of iron, waiting on the ground before the doors.
        block(x1 + 0.12, doorB, x1 + 0.22, doorA + 0.1, g, g + 2.4, top: .colour(I.sootLit), left: .colour(I.soot), right: .colour(I.sootShade),
              width: 0.8)
        // Materials beside.
        bricks(-1.25, 1.12, -0.85, 1.4, from: g, courses: 3)
        bricks(-0.7, 1.15, -0.35, 1.42, from: g, courses: 2)
        girders(0.55, 1.3, 0.75, on: g, count: 3)
        planks(0.0, 0.5, 1.3, on: g, count: 3)
        bricks(1.05, -0.2, 1.35, 0.1, from: g, courses: 2)
        drum(at: iso(1.32, 0.42, g), paint: I.soot, lit: I.sootLit)
    }
}
