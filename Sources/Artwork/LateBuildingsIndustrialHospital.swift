// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The hospital, of the age of hospitals, in the Industrial look: a
// Victorian infirmary of red brick. Its ward block of two tall storeys stands
// on a plinth of stone, with quoins, a string course carrying a band of the
// owner's colour, a cornice of dressed stone, and long sash windows in even
// rows, as the wards of the age were lit and aired. Its hipped roof of slate
// carries iron cresting, two chimney stacks, and a louvred lantern on the
// ridge for the air of the wards, flying the owner's pennant. Before it
// stands the entrance pavilion under its own gable, which bears a roundel of
// the owner's colour charged with a cross in the light colour, the sign of a
// place of healing; a portico of cast-iron columns, its frieze in the
// owner's colour, shelters the door. Lawns flank the paved path; linen dries
// on a line, a bench and a bath chair stand in the court, and gas lamps
// light the path. Its footprint is three tiles square: x and y run from -1.5
// to 1.5.

extension IndustrialOldBuildingsPainter {
    mutating func hospital(complete: Bool) {
        cobbles(1.5, height: 3)
        if complete { infirmary() } else { infirmaryRising() }
    }

    private static let ward = (x0: -1.36, y0: -1.36, x1: 0.96, y1: 0.0)
    private static let pavilion = (x0: -0.52, x1: 0.12, y1: 0.36)
    private static let wardFloor = 21.0
    private static let wardEaves = 40.0
    /// Where the windows of the ward block's long front stand, either side of
    /// the pavilion (from `p0` to `p1` along it), and those of its end.
    private static func frontWindows(_ front: Double, _ p0: Double, _ p1: Double) -> [Double] {
        [5.0, 16.0, p1 + 5.6, p1 + 16.6].filter { $0 + 5 < front - 3 && ($0 + 5 < p0 - 3 || $0 > p1 + 3) }
    }
    private static let sideWindows = [5.0, 15.4, 25.8, 36.2]

    /// The ward block's wall drawn with `wall`, `length` long and `height`
    /// tall: a plinth of stone, the brickwork, quoins at both corners when
    /// `quoined`, and the string course with the owner's band at the upper floor.
    private mutating func wardWall(_ length: Double, _ height: Double, floor f: Double, lit: Bool, quoined: Bool = true) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(0, 0, length, 3), .colour(lit ? I.footing : I.footingShade), width: 0.6)
        brickwork(0, length, 3, height)
        if quoined {
            quoins(at: 0, atStart: true, from: 3, to: height - 2, course: 3.6, reach: 3)
            quoins(at: length, atStart: false, from: 3, to: height - 2, course: 3.6, reach: 3)
        }
        stringCourse(0, length, f - 1.2, f + 0.6)
        paintedBand(0, length, f + 1.6, f + 3.2)
    }

    /// A roundel of the owner's colour on a wall drawn with `wall`, centred on
    /// (`u`, `v`), `r` points in radius: a rim of the light colour and a ring
    /// of stone, and on the field a cross of the light colour.
    private mutating func crossRoundel(_ u: Double, _ v: Double, radius r: Double) {
        typealias I = IndustrialOldBuildingsInk
        let c = uv(u, v)
        svg.circle(c + shift, r + 1.6, fill: .colour(I.stoneTop))
        svg.circle(c + shift * 0.5, r + 0.7, fill: .colour(I.light))
        svg.circle(c + shift * 0.5, r, fill: .team)
        let a = r * 0.2, b = r * 0.68
        svg.polygon([c + P(-a, -b), c + P(a, -b), c + P(a, -a), c + P(b, -a), c + P(b, a), c + P(a, a), c + P(a, b), c + P(-a, b),
                     c + P(-a, a), c + P(-b, a), c + P(-b, -a), c + P(-a, -a)], fill: .colour(I.light))
        svg.circle(c, r + 1.6, fill: .none, stroke: .colour(I.line), width: 0.7)
        svg.circle(c, r, fill: .none, stroke: .colour(I.line), width: 0.5)
    }

    private mutating func infirmary() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.ward
        let h0 = 3.0, f = Self.wardFloor, e = Self.wardEaves
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        lawns()
        shadow([iso(x1, y0, h0), iso(x1 + 0.32, y0 + 0.16, h0), iso(x1 + 0.32, y1 + 0.14, h0), iso(x1, y1, h0)])
        // The ward block: two storeys of brick, each lit by rows of tall sashes.
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        let p0 = (Self.pavilion.x0 - x0) * 32, p1 = (Self.pavilion.x1 - x0) * 32
        wall(.left, from: x0, y1, at: h0) { p in
            p.wardWall(front, e - h0, floor: f - h0, lit: true)
            for u in Self.frontWindows(front, p0, p1) {
                p.casement(u, 5, w: 5, h: 10.6, lights: 1, frame: I.brick)
                p.casement(u, f - h0 + 5, w: 5, h: 11.4, lights: 1, frame: I.brick)
            }
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.wardWall(side, e - h0, floor: f - h0, lit: false)
            for u in Self.sideWindows {
                p.casement(u, 5, w: 5, h: 10.6, lights: 1, frame: I.brick)
                p.casement(u, f - h0 + 5, w: 5, h: 11.4, lights: 1, frame: I.brick)
            }
        }
        cornice(x0, y0, x1, y1, at: e + 1.6, depth: 2.4)
        shadow([iso(x0, y1, e - 2.4), iso(x1, y1, e - 2.4), iso(x1, y1, e), iso(x0, y1, e)], opacity: 0.12)
        let ridge = hippedRoof(x0, y0, x1, y1, eaves: e + 1.6, rise: 20, overhang: 0.06, finials: true)
        let ym = (y0 + y1) / 2, k = (y1 - y0 + 0.12) / 2
        cresting(iso(x0 - 0.06 + k, ym, ridge), iso(-0.38, ym, ridge))
        cresting(iso(-0.02, ym, ridge), iso(x1 + 0.06 - k, ym, ridge))
        chimneyStack(-0.98, -0.8, -0.78, -0.6, from: ridge - 8, to: ridge + 5, pots: 2)
        chimneyStack(0.42, -0.8, 0.62, -0.6, from: ridge - 8, to: ridge + 5, pots: 2)
        lantern(-0.2, ym, on: ridge)
        entrance()
        // The court: linen on its line, a bench, a bath chair, and the lamps of the path.
        washingLine(from: (-1.26, 0.98), to: (-0.66, 0.98), on: h0)
        gardenBench(at: (0.62, 0.92), on: h0)
        bathChair(at: iso(1.2, -0.36, h0))
        gasLamp(at: iso(-0.5, 1.32, h0), height: 22)
        gasLamp(at: iso(0.1, 1.32, h0), height: 22)
    }

    /// Two lawns of the bottle green either side of the path to the door, edged with a low kerb.
    private mutating func lawns() {
        typealias I = IndustrialOldBuildingsInk
        let h = 3.0
        for (a, b) in [(-1.36, -0.5), (0.1, 1.36)] {
            let plot = level(a, 0.5, b, 1.36, h)
            colour(plot, .colour(I.greenLight))
            line(plot, closed: true, width: 0.7)
            // A few tufts, so that it reads as grass.
            var tufts = PathData()
            var n = 0
            for x in stride(from: a + 0.12, to: b - 0.05, by: 0.2) {
                for y in stride(from: 0.62, to: 1.3, by: 0.22) {
                    let c = iso(x + (n % 2 == 0 ? 0.04 : -0.03), y, h)
                    tufts.move(c + P(-1.2, 0)); tufts.line(c + P(-0.4, -1.6)); tufts.line(c + P(0.2, 0))
                    tufts.line(c + P(0.9, -1.4)); tufts.line(c + P(1.4, 0))
                    n += 1
                }
            }
            svg.path(tufts, stroke: .colour(I.greenShade), width: 0.5, opacity: 0.8)
        }
    }

    /// The lantern on the ridge at (x, y) on `h`: a louvred box of painted
    /// board under a pyramid of slate, and the owner's pennant on its apex.
    private mutating func lantern(_ x: Double, _ y: Double, on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let s = 0.15, top = h + 9
        block(x - s, y - s, x + s, y + s, h - 4, top, top: nil, left: .colour(I.light), right: .colour(I.plasterShade), width: 0.8)
        for side in [IndustrialOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x - s : x + s, y + s, at: h - 4) { p in
                let w = 2 * s * 32
                p.shape(p.panel(1.6, 4.4, w - 1.6, 11.6), .colour(I.greenShade), width: 0.5)
                for v in stride(from: 5.6, to: 11.2, by: 1.3) { p.line([p.uv(1.8, v), p.uv(w - 1.8, v - 0.5)], width: 0.4) }
            }
        }
        let apex = hippedRoof(x - s, y - s, x + s, y + s, eaves: top, rise: 6, overhang: 0.03, finials: false)
        pennant(at: iso(x, y, apex), height: 13, length: 13)
    }

    /// The entrance pavilion before the ward block: a bay of brick under its
    /// own gable with the roundel, the door under a fanlight, a portico of
    /// cast-iron columns before it, and steps of stone.
    private mutating func entrance() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, x1, y1) = (Self.pavilion.x0, Self.pavilion.x1, Self.pavilion.y1)
        let yb = Self.ward.y1, h0 = 3.0, f = Self.wardFloor, e = Self.wardEaves
        let w = (x1 - x0) * 32, d = (y1 - yb) * 32
        block(x0, yb, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.wardWall(w, e - h0, floor: f - h0, lit: true)
            p.door(w / 2, 3, w: 8, h: 14.4)
            p.casement(w / 2 - 4, f - h0 + 5, w: 8, h: 11.4, lights: 2)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.wardWall(d, e - h0, floor: f - h0, lit: false, quoined: false)
            p.casement(d / 2 - 2.2, f - h0 + 5, w: 4.4, h: 11.4, lights: 1)
        }
        cornice(x0, yb, x1, y1, at: e + 0.6, depth: 1.8)
        gableAlongY(x0, yb - 0.04, x1, y1, eave: e + 1.6, ridge: e + 17, over: 0.05, gableWall: .colour(I.brick)) { p, w, rise in
            p.gableBrickwork(w, rise)
            p.crossRoundel(w / 2, rise * 0.34, radius: 4.8)
        }
        // The steps, then the portico: two columns carrying a frieze of the owner's colour.
        let (a, b) = (-0.38, -0.02)
        block(a - 0.04, y1, b + 0.04, y1 + 0.26, h0, h0 + 1.2, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.6)
        block(a, y1, b, y1 + 0.18, h0 + 1.2, h0 + 2.4, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.6)
        let foot = h0 + 2.4, head = 17.0
        for x in [a + 0.03, b - 0.03] {
            let base = iso(x, y1 + 0.16, foot), cap = iso(x, y1 + 0.16, head)
            pole(base, cap, width: 2, colour: I.iron)
            svg.line([base + P(-0.4, -1), cap + P(-0.4, 1)], stroke: .colour(I.ironLight), width: 0.5)
            shape([cap + P(-1.8, 0.6), cap + P(1.8, 0.6), cap + P(1.2, -1), cap + P(-1.2, -1)], .colour(I.iron), width: 0.4)
        }
        block(a - 0.03, y1, b + 0.03, y1 + 0.2, head, head + 4, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.7)
        wall(.left, from: a - 0.03, y1 + 0.2, at: head) { p in p.paintedBand(0, (b - a + 0.06) * 32, 1.1, 2.9) }
    }

    /// A line of linen drying between two posts at `from` and `to` on `h`:
    /// sheets of the light colour hung from a sagging cord.
    private mutating func washingLine(from a: (Double, Double), to b: (Double, Double), on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let height = 17.0
        let p0 = iso(a.0, a.1, h), p1 = iso(b.0, b.1, h)
        for p in [p0, p1] {
            svg.ellipse(p + P(1, 0.5), 2.2, 0.9, fill: .colour("#000000"), opacity: 0.14)
            pole(p, p - P(0, height), width: 1.4, colour: I.timber)
        }
        let t0 = p0 - P(0, height - 1), t1 = p1 - P(0, height - 1)
        func cord(_ s: Double) -> P { t0 + (t1 - t0) * s + P(0, 3.2 * 4 * s * (1 - s)) }
        line(width: 0.5) { d in d.move(t0); d.quad((t0 + t1) * 0.5 + P(0, 6.4), t1) }
        let sheets: [(Double, Double, Double, String)] = [(0.1, 0.36, 9, I.light), (0.42, 0.62, 7.5, I.plasterTop),
                                                         (0.68, 0.9, 8.5, I.light)]
        for (s0, s1, drop, paint) in sheets {
            let q0 = cord(s0), q1 = cord(s1)
            let cloth = [q0, q1, q1 + P(0.4, drop), q0 + P(-0.3, drop + 0.4)]
            shape(cloth, .colour(paint), width: 0.6)
            line([q0 + (q1 - q0) * 0.5, q0 + (q1 - q0) * 0.5 + P(0, drop * 0.8)], width: 0.35, opacity: 0.4)
            for q in [q0, q1] { svg.line([q + P(0, -0.8), q + P(0, 1)], stroke: .colour(I.timberDark), width: 0.8) }
        }
    }

    /// A garden bench of oak and cast iron standing along x at (x, y) on `h`.
    private mutating func gardenBench(at place: (Double, Double), on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let (x, y) = place
        svg.polygon(level(x - 0.24, y - 0.04, x + 0.26, y + 0.1, h), fill: .colour("#000000"), opacity: 0.12)
        for dx in [-0.18, 0.18] { pole(iso(x + dx, y, h), iso(x + dx, y, h + 4), width: 1.2, colour: I.iron) }
        block(x - 0.22, y - 0.05, x + 0.22, y + 0.05, h + 4, h + 5.2, top: .colour(I.timberLight), left: .colour(I.timber),
              right: .colour(I.timberDark), width: 0.6)
        let back0 = iso(x - 0.22, y - 0.05, h + 5.2), back1 = iso(x + 0.22, y - 0.05, h + 5.2)
        shape([back0, back1, back1 - P(0, 4.4), back0 - P(0, 4.4)], .colour(I.timber), width: 0.6)
        line([back0 - P(0, 2.2), back1 - P(0, 2.2)], width: 0.35, opacity: 0.6)
    }

    /// A bath chair standing at `p` on the screen: a seat of wicker under a
    /// folding hood of bottle green on two tall wheels and a small leading
    /// one, with a handle behind and a rug of the light colour on its seat.
    private mutating func bathChair(at p: P) {
        typealias I = IndustrialOldBuildingsInk
        svg.ellipse(p + P(0, 0.6), 8, 2, fill: .colour("#000000"), opacity: 0.15)
        // The seat and its hood.
        let seat = p + P(-1, -7)
        shape([seat + P(-4.6, 0), seat + P(3.4, 0), seat + P(4, -3.4), seat + P(-4, -3.4)], .colour(I.straw), width: 0.6)
        shape([seat + P(-4.6, 0), seat + P(-4, -3.4), seat + P(-5.2, -10), seat + P(-1.2, -12), seat + P(0.6, -10.4),
               seat + P(-1.6, -3.4)], .colour(I.green), width: 0.6)
        line([seat + P(-4.4, -6.6), seat + P(-0.4, -8.4)], width: 0.4, opacity: 0.6)
        shape([seat + P(-1.6, -3.4), seat + P(4, -3.4), seat + P(4.6, 1.6), seat + P(1.4, 2)], .colour(I.light), width: 0.5)
        // The handle behind, the footboard before.
        line([seat + P(-4.6, -1), seat + P(-8.4, -5.6), seat + P(-9.6, -5.2)], width: 0.9)
        line([seat + P(3.4, 0), seat + P(7.4, 3.6), seat + P(8.6, 3.6)], width: 0.8)
        // The wheels: the great one spoked, the leading one small.
        let hub = p + P(-1.2, -4.2)
        svg.circle(hub, 4.2, fill: .none, stroke: .colour(I.line), width: 1.1)
        var spokes = PathData()
        for k in 0..<6 {
            let angle = Double(k) * .pi / 3
            spokes.move(hub); spokes.line(hub + P(cos(angle) * 4, sin(angle) * 4))
        }
        svg.path(spokes, stroke: .colour(I.line), width: 0.4)
        svg.circle(hub, 0.8, fill: .colour(I.iron))
        svg.circle(p + P(6.8, -1.6), 1.6, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.6)
    }

    /// The hospital being built: the ward block's walls of fresh brick half
    /// raised on their plinth, the window openings left; the pavilion begun;
    /// scaffolding with the owner's pennant; a ladder; and bricks, slates and
    /// timber to hand on the court.
    private mutating func infirmaryRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.ward
        let h0 = 3.0, top = 17.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        lawnsMarkedOut()
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.08, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.earth)) { p in
            p.bricks(-1.0, -1.0, -0.7, -0.72, from: h0, height: 5)
            p.basket(at: p.iso(-0.2, -0.7, h0), size: 0.9)
            p.timbers(0.1, -1.1, length: 0.7, on: h0)
        }
        let p0 = (Self.pavilion.x0 - x0) * 32, p1 = (Self.pavilion.x1 - x0) * 32
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 3), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, front, 3, top - h0, opacity: 0.4, burnt: false)
            for u in Self.frontWindows(front, p0, p1) {
                p.shape(p.panel(u, 5, u + 5, top - h0), .colour(I.dark), width: 0.7)
            }
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 3), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, side, 3, top - h0, opacity: 0.4, burnt: false)
            for u in Self.sideWindows { p.shape(p.panel(u, 5, u + 5, top - h0), .colour(I.dark), width: 0.7) }
        }
        // The pavilion's walls, lower still, round the opening of its door.
        let (a, b, yf) = (Self.pavilion.x0, Self.pavilion.x1, Self.pavilion.y1)
        let w = (b - a) * 32, d = (yf - y1) * 32
        block(a, y1, b, yf, h0, 11, top: .colour(I.brickTop), left: .colour(I.rawBrick), right: .colour(I.rawBrickShade), width: 1)
        wall(.left, from: a, yf, at: h0) { p in
            p.shape(p.panel(0, 0, w, 3), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, w, 3, 8, opacity: 0.4, burnt: false)
            p.shape(p.panel(w / 2 - 4, 3, w / 2 + 4, 8), .colour(I.dark), width: 0.8)
        }
        wall(.right, from: b, yf, at: h0) { p in
            p.shape(p.panel(0, 0, d, 3), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, d, 3, 8, opacity: 0.4, burnt: false)
        }
        scaffold([(x1 + 0.14, -0.02), (x1 + 0.14, -0.68), (x1 + 0.14, -1.32)], from: h0, height: 30, levels: [11, 22], boards: 11)
        pennant(at: iso(x1 + 0.14, -0.02, h0 + 30), height: 12, length: 13)
        ladder(foot: iso(-1.1, 0.42, h0), iso(-0.94, 0.42, h0), head: iso(-1.1, y1 + 0.02, top + 3), iso(-0.94, y1 + 0.02, top + 3),
               rungs: 5)
        bricks(0.3, 0.7, 0.6, 1.0, from: h0, height: 6)
        slates(0.8, 0.6, 1.06, 0.92, from: h0, height: 6)
        timbers(-0.2, 1.0, length: 0.8, on: h0)
        barrel(at: iso(-1.2, 1.18, h0), size: 0.9)
        heap(at: iso(1.2, 0.0, h0), width: 9, height: 4, paint: I.straw, shade: I.strawShade)
    }

    /// The lawns' plots marked out with pegs and a cord, not yet turfed.
    private mutating func lawnsMarkedOut() {
        typealias I = IndustrialOldBuildingsInk
        let h = 3.0
        for (a, b) in [(-1.36, -0.5), (0.1, 1.36)] {
            let plot = level(a, 0.5, b, 1.36, h)
            colour(plot, .colour(I.earth))
            line(plot, closed: true, width: 0.45, opacity: 0.7)
            for corner in plot { pole(corner, corner - P(0, 3), width: 0.9, colour: I.timberLight) }
        }
    }
}
