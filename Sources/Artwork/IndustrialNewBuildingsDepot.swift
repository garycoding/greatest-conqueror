// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age railway depot: a station of brick under a roof of bottle-green
// slate, a clock in its gable and the owner's flag on its peak; before it a
// platform under a canopy of iron on slender bottle-green columns, its edge hung with
// a fretted valance; and along the platform a short length of track on
// ballast, closed at its far end by buffers, a tank engine standing at the
// platform, and a semaphore signal whose arm is painted in the owner's
// colour. Its footprint is three tiles square: x and y run from -1.5 to 1.5.

extension IndustrialNewBuildingsPainter {
    mutating func depot(complete: Bool) {
        typealias I = IndustrialNewBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, Depot.ground, top: .colour(I.yard), left: .colour(I.yardShade), right: .colour(I.yardShade),
              width: 1)
        if complete { depotComplete() } else { depotRising() }
    }

    /// The depot's measures: on the map in tiles, heights in points.
    private enum Depot {
        static let ground = 1.5
        static let station = (x0: -1.36, y0: -1.38, x1: 0.62, y1: -0.3)
        static let eave = 36.0, ridge = 56.0
        static let platform = (x0: -1.4, y0: -0.3, x1: 1.36, y1: 0.6, top: 7.0)
        /// The canopy: its back against the station at `back`, its front edge at `front`.
        static let canopy = (x0: -1.4, x1: 1.3, y0: -0.3, y1: 0.5, back: 30.0, front: 24.0)
        static let columns: [Double] = [-1.2, -0.58, 0.04, 0.66, 1.2]
        /// The track: the ballast's breadth, and the two rails.
        static let ballast = (y0: 0.66, y1: 1.26)
        static let rails = (0.83, 1.09)
        static let railTop = 4.6
    }

    // MARK: The depot complete

    private mutating func depotComplete() {
        typealias I = IndustrialNewBuildingsInk
        let g = Depot.ground
        station()
        platform(full: true)
        canopy()
        track(laidTo: 1.5, railsTo: 1.5)
        bufferStop()
        locomotive(at: -0.46)
        signal(at: 1.36, 1.36)
        // A trolley of parcels on the platform, by the station's end.
        crate(0.98, -0.18, size: 0.18, height: 5, on: g + Depot.platform.top)
        crate(1.0, 0.04, size: 0.16, height: 4.5, on: g + Depot.platform.top)
    }

    /// The station: walls of brick with windows and doors under the canopy, a
    /// roof of bottle-green slate with two chimneys, a clock in the gable, and the
    /// owner's flag on the gable's peak.
    private mutating func station() {
        typealias I = IndustrialNewBuildingsInk
        let (x0, y0, x1, y1) = Depot.station
        let g = Depot.ground, eave = Depot.eave
        let front = (x1 - x0) * 32, end = (y1 - y0) * 32
        shadow([iso(x1, y0, g), iso(x1 + 0.4, y0 + 0.16, g), iso(x1 + 0.4, y1, g), iso(x1, y1, g)], opacity: 0.12)
        brickwork(x0, y0, x1, y1, g, eave)
        wall(.left, from: x0, y1, at: g) { p in
            p.plinth(front)
            for u in [6.0, 18.0, 44.0, 56.0] { p.sash(u, 9, width: 6.4, height: 10) }
            p.doubleDoor(31.6 - 5, width: 10, height: 16)
            p.cornice(front, eave - g)
        }
        wall(.right, from: x1, y1, at: g) { p in
            p.plinth(end)
            p.archedWindow(6, 7, width: 7.6, height: 15)
            p.archedWindow(end - 13.6, 7, width: 7.6, height: 15)
            p.cornice(end, eave - g)
        }
        gableRoof(x0, y0, x1, y1, eave: eave, ridge: Depot.ridge, over: 0.08)
    }

    /// A pair of doors of bottle-green panels on a wall drawn with `wall`, from `u`,
    /// under a fanlight and a hood of stone.
    fileprivate mutating func doubleDoor(_ u: Double, width w: Double, height h: Double) {
        typealias I = IndustrialNewBuildingsInk
        shape(panel(u - 1.4, 0, u + w + 1.4, h + 2.2), .colour(I.lightShade), width: 0.6)
        shape(panel(u, 0, u + w, h - 4), .colour(I.green), width: 0.8)
        for k in 0..<2 {
            let a = u + Double(k) * w / 2
            colour(panel(a + 0.9, 1, a + w / 2 - 0.9, h * 0.42), .colour(I.greenLit))
            colour(panel(a + 0.9, h * 0.42 + 1.2, a + w / 2 - 0.9, h - 5), .colour(I.greenLit))
        }
        line([uv(u + w / 2, 0.3), uv(u + w / 2, h - 4.2)], width: 0.6)
        shape(panel(u, h - 3.6, u + w, h), .colour(I.glass), width: 0.6)
        line([uv(u + w / 2, h - 3.6), uv(u + w / 2, h)], width: 0.4)
        shape(panel(u - 2.2, h + 2.2, u + w + 2.2, h + 3.6), .colour(I.lightTop), width: 0.6)
    }

    /// A gabled roof of bottle-green slate over a box from (x0, y0) to (x1, y1), its
    /// eaves at `eave` and its ridge along x at `ridge`, overhanging by `over`
    /// tiles; a gable end of brick facing +x with a clock in it; two chimneys
    /// on the ridge; and the owner's flag on the gable's peak.
    private mutating func gableRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double, over: Double) {
        typealias I = IndustrialNewBuildingsInk
        let ym = (y0 + y1) / 2
        let (a0, a1, b0, b1) = (x0 - over, x1 + over, y0 - over, y1 + over)
        let drop = (ridge - eave) * over / (ym - y0)
        colour([iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a0, b0, eave - drop)], .colour(I.greenShade))
        // The gable's end wall, in brick, with the clock.
        let triangle = [iso(x1, y1, eave), iso(x1, y0, eave), iso(x1, ym, ridge)]
        colour(triangle, .colour(I.brickShade))
        let w = (y1 - y0) * 32, rise = ridge - eave
        wall(.right, from: x1, y1, at: eave) { p in
            var d = PathData()
            var v = 3.2
            while v < rise - 1 {
                let half = w / 2 * (1 - v / rise)
                d.move(p.uv(w / 2 - half, v)); d.line(p.uv(w / 2 + half, v)); v += 3.2
            }
            p.svg.path(d, stroke: .colour(I.line), width: 0.42, opacity: 0.32)
            p.clock(at: p.uv(w / 2, rise * 0.38), radius: 4.6)
        }
        line(triangle, closed: true, width: 0.9)
        // The roof's thickness along the gable, then the front slope.
        let edge = P(0, 2)
        colour([iso(a1, b1, eave - drop), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a1, b0, eave - drop) + edge,
                iso(a1, ym, ridge) + edge, iso(a1, b1, eave - drop) + edge], .colour(I.lightTop))
        let front = [iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b1, eave - drop), iso(a0, b1, eave - drop)]
        colour([front[3], front[2], front[2] + edge, front[3] + edge], .colour(I.greenDark))
        colour(front, .colour(I.green))
        var courses = PathData(), joints = PathData(), lit = PathData()
        let rows = 7
        for k in 1..<rows {
            let t = Double(k) / Double(rows)
            let y = b1 + (ym - b1) * t, h = (eave - drop) + (ridge - eave + drop) * t
            courses.move(iso(a0, y, h)); courses.line(iso(a1, y, h))
            let tl = t - 0.025
            let yl = b1 + (ym - b1) * tl, hl = (eave - drop) + (ridge - eave + drop) * tl
            lit.move(iso(a0 + 0.02, yl, hl)); lit.line(iso(a1 - 0.02, yl, hl))
        }
        for k in 0..<rows {
            let t0 = Double(k) / Double(rows), t1 = Double(k + 1) / Double(rows)
            var x = a0 + (k % 2 == 0 ? 0.08 : 0.16)
            while x < a1 - 0.05 {
                let ya = b1 + (ym - b1) * t0, ha = (eave - drop) + (ridge - eave + drop) * t0
                let yb = b1 + (ym - b1) * t1, hb = (eave - drop) + (ridge - eave + drop) * t1
                joints.move(iso(x, ya, ha) + P(0, -0.5)); joints.line(iso(x, yb, hb) + P(0, 0.5))
                x += 0.16
            }
        }
        svg.path(courses, stroke: .colour(I.greenDark), width: 0.75)
        svg.path(joints, stroke: .colour(I.greenDark), width: 0.42, opacity: 0.8)
        svg.path(lit, stroke: .colour(I.greenLit), width: 0.5, opacity: 0.8)
        line(front, closed: true, width: 1.1)
        line([front[3], front[3] + edge, front[2] + edge, front[2]], width: 0.9)
        line([iso(a1, ym, ridge), iso(a1, ym, ridge) + edge, iso(a1, b0, eave - drop) + edge, iso(a1, b0, eave - drop)], width: 0.9)
        line([front[2] + edge, iso(a1, ym, ridge) + edge], width: 0.9)
        // Two chimneys of brick astride the ridge.
        for cx in [x0 + 0.35, x1 - 0.55] {
            brickwork(cx - 0.08, ym - 0.08, cx + 0.08, ym + 0.08, ridge - 4, ridge + 9, top: .colour(I.lightTop))
            block(cx - 0.1, ym - 0.1, cx + 0.1, ym + 0.1, ridge + 7.4, ridge + 9, top: .colour(I.lightTop), left: .colour(I.light),
                  right: .colour(I.lightShade), width: 0.8)
            for (dx, h) in [(-0.035, 3.0), (0.035, 2.4)] {
                frustum(cx + dx, ym, 0.025, 0.025, ridge + 9, ridge + 9 + h, lit: I.sootLit, mid: I.soot, shade: I.sootShade,
                        top: .colour(I.dark), width: 0.6)
            }
        }
        // The ridge's capping, and the flag on the gable's peak.
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.line), width: 3)
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.greenLit), width: 1.5)
        flag(at: iso(a1, ym, ridge), height: 18, length: 16)
    }

    /// A clock at `c` on a wall drawn with `wall`: a face of the light colour
    /// in a ring of bottle green, its hours marked, its hands of brass at ten to two.
    fileprivate mutating func clock(at c: P, radius r: Double) {
        typealias I = IndustrialNewBuildingsInk
        svg.circle(c + shift * 0.5, r + 1, fill: .colour(I.green))
        svg.circle(c, r + 1, fill: .none, stroke: .colour(I.line), width: 0.8)
        svg.circle(c, r - 0.2, fill: .colour(I.lightTop), stroke: .colour(I.line), width: 0.5)
        var hours = PathData()
        for k in 0..<12 {
            let a = Double(k) * .pi / 6
            hours.move(c + P(sin(a), -cos(a)) * (r - 0.6)); hours.line(c + P(sin(a), -cos(a)) * (r - (k % 3 == 0 ? 1.8 : 1.2)))
        }
        svg.path(hours, stroke: .colour(I.line), width: 0.4)
        svg.line([c, c + P(sin(-1.05), -cos(-1.05)) * (r * 0.55)], stroke: .colour(I.line), width: 0.8)
        svg.line([c, c + P(sin(1.05), -cos(1.05)) * (r * 0.8)], stroke: .colour(I.line), width: 0.6)
        svg.circle(c, 0.5, fill: .colour(I.brass))
    }

    /// The platform: a deck of paving on a wall of brick, its edge coped in
    /// light stone. Being built, only its back part is raised.
    private mutating func platform(full: Bool) {
        typealias I = IndustrialNewBuildingsInk
        let (x0, y0, x1, y1, top) = Depot.platform
        let g = Depot.ground
        let end = full ? x1 : -0.2
        let h = g + top
        brickwork(x0, y0, end, y1, g, h - 1.4, top: .colour(I.lightShade))
        // The paving's joints, and the coping along the edge.
        var joints = PathData()
        var x = x0 + 0.2
        while x < end - 0.05 { joints.move(iso(x, y0, h - 1.4)); joints.line(iso(x, y1 - 0.12, h - 1.4)); x += 0.2 }
        for y in stride(from: y0 + 0.2, to: y1 - 0.12, by: 0.2) { joints.move(iso(x0, y, h - 1.4)); joints.line(iso(end, y, h - 1.4)) }
        svg.path(joints, stroke: .colour(I.lightDark), width: 0.5)
        block(x0, y1 - 0.12, end, y1 + 0.02, h - 2.4, h, top: .colour(I.lightTop), left: .colour(I.light), right: .colour(I.lightShade),
              width: 0.8)
        if !full {
            // The rest of its wall, two courses up.
            brickwork(end, y1 - 0.16, x1, y1, g, g + 4, top: .colour(I.freshBrick), fresh: true)
        }
    }

    /// The canopy over the platform: a lean-to roof of iron sheet with a band
    /// of glass, carried on bottle-green columns with brackets, its front and end hung
    /// with a fretted valance of the light colour; and the platform's shade under it.
    private mutating func canopy() {
        typealias I = IndustrialNewBuildingsInk
        let (x0, x1, y0, y1, back, front) = Depot.canopy
        let g = Depot.ground, deck = g + Depot.platform.top
        let cy = y1 - 0.06
        // Shade on the platform and the station's front.
        shadow(level(x0, y0, x1, y1 + 0.02, deck), opacity: 0.16)
        shadow([iso(Depot.station.x0, y0, g), iso(Depot.station.x1, y0, g), iso(Depot.station.x1, y0, back), iso(Depot.station.x0, y0, back)],
               opacity: 0.14)
        // Columns at the back where the canopy runs past the station's end.
        for x in Depot.columns where x > Depot.station.x1 + 0.05 {
            column(x, y0 + 0.06, from: deck, to: back - 1)
        }
        for x in Depot.columns { column(x, cy, from: deck, to: front - 1) }
        // The beam along the columns' heads.
        pole(iso(x0, cy, front - 1), iso(x1, cy, front - 1), width: 1.6, colour: I.green)
        // The roof: iron sheet, ribbed down its slope, with a band of glass.
        let roof = [iso(x0, y0, back), iso(x1, y0, back), iso(x1, y1, front), iso(x0, y1, front)]
        colour(roof, .colour(I.sootLit))
        func at(_ t: Double) -> (Double, Double) { (y0 + (y1 - y0) * t, back - (back - front) * t) }
        let (ga, ha) = at(0.16), (gb, hb) = at(0.78)
        let glassBand = [iso(x0, ga, ha), iso(x1, ga, ha), iso(x1, gb, hb), iso(x0, gb, hb)]
        colour(glassBand, .colour(I.glass))
        colour([iso(x0, ga, ha), iso(x1, ga, ha), iso(x1, (ga + gb) / 2, (ha + hb) / 2), iso(x0, (ga + gb) / 2, (ha + hb) / 2)],
               .colour(I.glassShade), opacity: 0.6)
        var ribs = PathData()
        var x = x0 + 0.06
        while x < x1 - 0.02 {
            ribs.move(iso(x, y0, back)); ribs.line(iso(x, ga, ha))
            ribs.move(iso(x, gb, hb)); ribs.line(iso(x, y1, front))
            x += 0.09
        }
        svg.path(ribs, stroke: .colour(I.sootShade), width: 0.5, opacity: 0.8)
        // The glazing bars over the glass, in bottle green.
        var bars = PathData()
        x = x0 + 0.06
        while x < x1 - 0.02 { bars.move(iso(x, ga, ha)); bars.line(iso(x, gb, hb)); x += 0.09 }
        svg.path(bars, stroke: .colour(I.green), width: 0.6)
        line(glassBand, closed: true, width: 0.6)
        line(roof, closed: true, width: 1)
        // The valance along the front, and down the end.
        let length = (x1 - x0) * 32
        wall(.left, from: x0, y1, at: front) { p in p.valance(length, depth: 3.6) }
        wall(.right, from: x1, y1, at: front) { p in
            p.valance((y1 - y0) * 32, depth: 3.6, rising: back - front)
        }
    }

    /// A column of cast iron, painted bottle-green, standing at (x, y) from `h0` to
    /// `h1`, with a base, a capital, and (unless `brackets` is false, whilst
    /// nothing rests on it) a bracket each way along the beam.
    private mutating func column(_ x: Double, _ y: Double, from h0: Double, to h1: Double, brackets: Bool = true) {
        typealias I = IndustrialNewBuildingsInk
        let foot = iso(x, y, h0), head = iso(x, y, h1)
        pole(foot, head, width: 1.5, colour: I.green)
        svg.line([foot + P(-0.3, 0), head + P(-0.3, 0)], stroke: .colour(I.greenLit), width: 0.5)
        shape([foot + P(-1.6, 0), foot + P(1.6, 0), foot + P(1.2, -2), foot + P(-1.2, -2)], .colour(I.greenShade), width: 0.6)
        shape([head + P(-1.8, 0), head + P(1.8, 0), head + P(1.2, 1.6), head + P(-1.2, 1.6)], .colour(I.lightShade), width: 0.6)
        // Brackets: quarter circles of iron to the beam either side.
        for side in [-1.0, 1.0] where brackets {
            let a = iso(x + side * 0.16, y, h1), b = iso(x, y, h1 - 5), corner = iso(x, y, h1)
            line(width: 0.9) { d in d.move(a); d.quad(corner + (a - corner) * 0.1, b) }
        }
    }

    /// A valance of boards on a wall drawn with `wall`, `length` long, hanging
    /// `depth` below its top, its foot cut into points; the top rising by
    /// `rising` points along its length, for the canopy's sloping end.
    fileprivate mutating func valance(_ length: Double, depth: Double, rising: Double = 0) {
        typealias I = IndustrialNewBuildingsInk
        let step = 2.4
        func top(_ u: Double) -> Double { rising * u / length }
        var outline: [P] = [uv(0, top(0))]
        var u = 0.0
        while u < length - 0.1 {
            let mid = min(u + step / 2, length), next = min(u + step, length)
            outline.append(uv(u, top(u) - depth + 1.4))
            outline.append(uv(mid, top(mid) - depth))
            outline.append(uv(next, top(next) - depth + 1.4))
            u = next
        }
        outline.append(uv(length, top(length)))
        shape(outline, .colour(I.lightTop), width: 0.6)
        line([uv(0, top(0) - 1.2), uv(length, top(length) - 1.2)], width: 0.4, opacity: 0.6)
    }

    /// The track: a bed of ballast the length of the footprint, sleepers laid
    /// on it to `laidTo` along x, and the two rails laid to `railsTo`.
    private mutating func track(laidTo sleepersEnd: Double, railsTo railsEnd: Double) {
        typealias I = IndustrialNewBuildingsInk
        let g = Depot.ground, (b0, b1) = Depot.ballast
        block(-1.5, b0, 1.5, b1, g, g + 1.6, top: .colour(I.ballast), left: .colour(I.ballastShade), right: .colour(I.ballastShade), width: 0.8)
        // Grit in the ballast, at fixed places.
        for k in 0..<26 {
            let x = -1.45 + Double(k) * 0.115, y = b0 + 0.06 + Double((k * 7) % 5) * 0.11
            svg.circle(iso(x, y, g + 1.6), 0.5, fill: .colour(k % 2 == 0 ? I.ballastShade : I.sootLit))
        }
        var x = -1.44
        while x < sleepersEnd - 0.1 {
            block(x, b0 + 0.05, x + 0.08, b1 - 0.05, g + 1.6, g + 2.6, top: .colour(I.timberLight), left: .colour(I.timber),
                  right: .colour(I.timberDark), width: 0.55)
            x += 0.16
        }
        for y in [Depot.rails.0, Depot.rails.1] {
            block(-1.5, y - 0.014, railsEnd, y + 0.014, g + 2.6, g + Depot.railTop, top: .colour(I.steel), left: .colour(I.soot),
                  right: .colour(I.sootShade), width: 0.6)
        }
    }

    /// Buffers closing the track's far end: a frame of timber over the rails
    /// with a beam across, two round buffers of iron facing along the track,
    /// and a lamp on top.
    private mutating func bufferStop() {
        typealias I = IndustrialNewBuildingsInk
        let g = Depot.ground, x = -1.42, (b0, b1) = Depot.ballast
        for y in [b0 + 0.08, b1 - 0.12] {
            block(x, y, x + 0.08, y + 0.04, g + 1.6, g + 11, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
                  width: 0.6)
        }
        // The struts running back to the rails.
        for y in [Depot.rails.0, Depot.rails.1] {
            pole(iso(x - 0.06, y, g + Depot.railTop), iso(x + 0.06, y, g + 9), width: 1.2, colour: I.timberDark)
        }
        block(x, b0 + 0.04, x + 0.1, b1 - 0.04, g + 6.5, g + 11.5, top: .colour(I.timberLight), left: .colour(I.timber),
              right: .colour(I.timberDark), width: 0.8)
        let face = (b1 - 0.04 - (b0 + 0.04)) * 32
        wall(.right, from: x + 0.1, b1 - 0.04, at: g + 6.5) { p in
            p.line([p.uv(1, 2.5), p.uv(face - 1, 2.5)], width: 0.4, opacity: 0.6)
        }
        for y in [Depot.rails.0, Depot.rails.1] {
            let c = iso(x + 0.16, y, g + 9)
            pole(iso(x + 0.1, y, g + 9), c, width: 1.6, colour: I.soot)
            svg.ellipse(c + shift * 0.4, 1.3, 2.3, fill: .colour(I.steel))
            svg.ellipse(c, 1.3, 2.3, fill: .none, stroke: .colour(I.line), width: 0.7)
        }
        // A lamp on the beam, its glass turned along the track.
        let lamp = iso(x + 0.05, (b0 + b1) / 2, g + 11.5)
        shape([lamp + P(-1.6, 0), lamp + P(1.6, 0), lamp + P(1.6, -3.6), lamp + P(-1.6, -3.6)], .colour(I.sootShade), width: 0.6)
        svg.circle(lamp + P(0.6, -1.8), 1, fill: .colour(I.fireCore), stroke: .colour(I.line), width: 0.4)
        shape([lamp + P(-1.8, -3.6), lamp + P(1.8, -3.6), lamp + P(0, -5)], .colour(I.soot), width: 0.5)
    }

    // MARK: The locomotive

    /// A tank engine standing on the track, its cab's back at `x0`, facing +x
    /// toward the open end: frames of soot black, three driving wheels coupled
    /// by a rod, side tanks painted with a panel of the owner's colour lined
    /// in the light colour, the boiler with its brass dome, the smokebox and
    /// its chimney with a wisp of steam, the cab, and the buffer beam.
    private mutating func locomotive(at x0: Double) {
        typealias I = IndustrialNewBuildingsInk
        let g = Depot.ground, rail = g + Depot.railTop
        let y0 = 0.78, y1 = 1.14, yc = (Depot.rails.0 + Depot.rails.1) / 2
        let cab = (x0: x0 - 0.24, x1: x0 + 0.08), front = x0 + 0.98
        let plate = rail + 5.4
        shadow(level(cab.x0, y0 + 0.04, front, y1 + 0.06, g + 2.7), opacity: 0.18)
        // The frames, between and below the running plate.
        block(cab.x0 + 0.04, y0 + 0.06, front - 0.04, y1 - 0.04, rail + 1.5, plate, top: nil, left: .colour(I.sootDark),
              right: .colour(I.sootDark), width: 0.8)
        // The cab.
        block(cab.x0, y0, cab.x1, y1, plate, plate + 15.5, top: nil, left: .colour(I.sootShade), right: .colour(I.soot), width: 1)
        let cabSide = (cab.x1 - cab.x0) * 32, cabFront = (y1 - y0) * 32
        wall(.left, from: cab.x0, y1, at: plate) { p in
            // The opening of the cab's side, and its lining.
            p.shape([p.uv(2.4, 7.4), p.uv(cabSide - 2, 7.4), p.uv(cabSide - 2, 13.4), p.uv(2.4, 13.4)], .colour(I.dark), width: 0.7)
            var lining = PathData()
            lining.move(p.uv(1.4, 1.4)); lining.line(p.uv(cabSide - 1.4, 1.4)); lining.line(p.uv(cabSide - 1.4, 5.8))
            lining.line(p.uv(1.4, 5.8)); lining.close()
            p.svg.path(lining, stroke: .colour(I.light), width: 0.5)
        }
        wall(.right, from: cab.x1, y1, at: plate) { p in
            // The spectacle plate: two round windows over the boiler.
            for u in [cabFront * 0.22, cabFront * 0.78] {
                p.svg.circle(p.uv(u, 12), 1.7, fill: .colour(I.glass), stroke: .colour(I.line), width: 0.7)
                p.svg.circle(p.uv(u - 0.3, 12.3), 0.6, fill: .colour(I.lightTop))
            }
        }
        // The cab's roof, curved, overhanging a little.
        let roofH = plate + 15.5
        block(cab.x0 - 0.04, y0 - 0.03, cab.x1 + 0.04, y1 + 0.03, roofH, roofH + 1.6, top: .colour(I.sootLit), left: .colour(I.soot),
              right: .colour(I.sootShade), width: 0.9)
        // The far side tank, behind the boiler.
        let tankEnd = front - 0.34
        block(cab.x1, y0, tankEnd, yc - 0.08, plate, plate + 8.4, top: .colour(I.soot), left: .colour(I.sootShade), right: .colour(I.soot),
              width: 0.9)
        // The boiler and the smokebox.
        let axis = plate + 7.4
        barrel(cab.x1, front - 0.2, yc, axis, radius: 5.6, body: I.sootShade, lit: I.sootLit, shade: I.sootDark, end: I.sootShade)
        // Bands round the boiler, in brass.
        for x in [cab.x1 + 0.2, cab.x1 + 0.46] {
            let ring = endCircle(x, yc, axis, radius: 5.65)
            // The half of the ring toward the viewer, from the top round to the foot.
            let half = Array(ring[(ring.count / 4)...(ring.count * 3 / 4)])
            svg.line(half, stroke: .colour(I.brass), width: 0.9)
        }
        barrel(front - 0.22, front - 0.06, yc, axis, radius: 6.1, body: I.sootDark, lit: I.soot, shade: I.sootDark, end: I.sootDark)
        // The smokebox door: a ring, its hinges, and its handle.
        let door = endCircle(front - 0.06, yc, axis, radius: 4.2)
        svg.polygon(door, fill: .colour(I.sootShade))
        line(door, closed: true, width: 0.7)
        svg.circle(iso(front - 0.06, yc, axis), 0.8, fill: .colour(I.steel), stroke: .colour(I.line), width: 0.4)
        // The side tanks, one on each side of the boiler; the near one shows.
        block(cab.x1, yc + 0.06, tankEnd, y1, plate, plate + 8.4, top: .colour(I.soot), left: .colour(I.sootShade), right: .colour(I.soot), width: 1)
        let tank = (tankEnd - cab.x1) * 32
        wall(.left, from: cab.x1, y1, at: plate) { p in
            // The panel in the owner's colour, lined in the light colour.
            p.shape(p.panel(1.4, 1.2, tank - 1.4, 7.4), .colour(I.light), width: 0.6)
            p.colour(p.panel(2.3, 2.1, tank - 2.3, 6.5), .team)
            p.line(p.panel(2.3, 2.1, tank - 2.3, 6.5), closed: true, width: 0.4, opacity: 0.7)
            p.mark(at: p.uv(tank / 2, 4.3), radius: 1.9)
        }
        // The dome, in brass, and the safety valves.
        let domeX = cab.x1 + 0.36
        frustum(domeX, yc, 0.07, 0.05, axis + 4.4, axis + 8.6, lit: "#e0c27a", mid: I.brass, shade: "#a07f36",
                top: .colour("#e0c27a"), width: 0.8)
        frustum(cab.x1 + 0.1, yc, 0.025, 0.025, axis + 4.8, axis + 8, lit: "#e0c27a", mid: I.brass, shade: "#a07f36", top: .colour(I.brass),
                width: 0.6)
        // The chimney on the smokebox, with its lip and a wisp of steam.
        let cx = front - 0.15
        frustum(cx, yc, 0.045, 0.04, axis + 5, axis + 11.5, lit: I.soot, mid: I.sootShade, shade: I.sootDark, width: 0.8)
        frustum(cx, yc, 0.058, 0.058, axis + 11.5, axis + 13, lit: I.soot, mid: I.sootShade, shade: I.sootDark, top: .colour(I.oil), width: 0.8)
        let mouth = iso(cx, yc, axis + 13)
        puff(at: mouth + P(-2, -5), radius: 3.2, colour: I.steam)
        puff(at: mouth + P(-7, -11), radius: 2.4, colour: I.steam)
        // The running plate's edge.
        line([iso(cab.x0, y1, plate), iso(front, y1, plate), iso(front, y0, plate)], width: 1.2)
        // Three driving wheels, coupled.
        let wheelR = 4.2, wheelH = rail + wheelR
        let wheelXs = [x0 + 0.06, x0 + 0.3, x0 + 0.54]
        for wx in wheelXs {
            wall(.left, from: wx, y1 + 0.005, at: wheelH) { p in
                p.svg.circle(P(0, 0), wheelR + 0.5, fill: .colour(I.line))
                p.svg.circle(P(0, 0) + p.shift * 0.4, wheelR - 0.3, fill: .colour(I.steel))
                p.svg.circle(P(0, 0), wheelR - 1.2, fill: .colour(I.sootShade))
                var spokes = PathData()
                for k in 0..<12 {
                    let a = Double(k) * .pi / 6
                    spokes.move(P(cos(a), sin(a)) * 1.2); spokes.line(P(cos(a), sin(a)) * (wheelR - 1.2))
                }
                p.svg.path(spokes, stroke: .colour(I.line), width: 0.6)
                p.svg.circle(P(0, 0), wheelR - 1.2, fill: .none, stroke: .colour(I.line), width: 0.5)
                p.svg.circle(P(0, 0), 1.3, fill: .colour(I.soot), stroke: .colour(I.line), width: 0.5)
                // The crank and its pin, a quarter turn round.
                p.svg.circle(P(0, -2.1), 0.6, fill: .colour(I.steel), stroke: .colour(I.line), width: 0.4)
            }
        }
        // The coupling rod between the crank pins.
        let rodA = iso(wheelXs.first!, y1 + 0.01, wheelH + 2.1), rodB = iso(wheelXs.last!, y1 + 0.01, wheelH + 2.1)
        pole(rodA, rodB, width: 1.1, colour: I.steel)
        // The cylinder at the front, and the buffer beam with its buffers and lamp.
        block(front - 0.3, y1 - 0.02, front - 0.12, y1 + 0.03, rail + 2.8, plate - 0.4, top: .colour(I.soot), left: .colour(I.sootShade),
              right: .colour(I.sootDark), width: 0.7)
        block(front - 0.04, y0 - 0.02, front, y1 + 0.02, rail + 2.4, plate + 0.6, top: .colour(I.soot), left: .colour(I.light),
              right: .colour(I.lightShade), width: 0.8)
        for y in [Depot.rails.0, Depot.rails.1] {
            let c = iso(front + 0.06, y, rail + 4)
            pole(iso(front, y, rail + 4), c, width: 1.4, colour: I.soot)
            svg.ellipse(c + shift * 0.4, 1.2, 2.1, fill: .colour(I.steel))
            svg.ellipse(c, 1.2, 2.1, fill: .none, stroke: .colour(I.line), width: 0.6)
        }
        let lamp = iso(front - 0.02, yc, plate + 0.6)
        shape([lamp + P(-1.3, 0), lamp + P(1.3, 0), lamp + P(1.3, -3), lamp + P(-1.3, -3)], .colour(I.lightTop), width: 0.5)
        svg.circle(lamp + P(0.4, -1.5), 0.7, fill: .colour(I.fireCore))
    }

    /// A semaphore signal standing at (x, y): a post painted in the light
    /// colour on a foot of soot, a ladder, the arm in the owner's colour with a
    /// band of the light colour, its spectacle of coloured glass, and a finial.
    private mutating func signal(at x: Double, _ y: Double) {
        typealias I = IndustrialNewBuildingsInk
        let g = Depot.ground, top = g + 50
        let foot = iso(x, y, g), head = iso(x, y, top)
        shadow([foot + P(-2, 0.4), foot + P(18, 9), foot + P(20, 8), foot + P(2, -0.4)], opacity: 0.12)
        shape([foot + P(-2.4, 0.6), foot + P(2.4, 0.6), foot + P(2, -4), foot + P(-2, -4)], .colour(I.soot), width: 0.7)
        // The ladder up the post's front.
        let ladderFoot = iso(x + 0.04, y + 0.04, g), ladderHead = iso(x + 0.04, y + 0.04, top - 12)
        pole(ladderFoot + P(-1.4, 0), ladderHead + P(-1.4, 0), width: 0.5, colour: I.soot)
        pole(ladderFoot + P(1.4, 0), ladderHead + P(1.4, 0), width: 0.5, colour: I.soot)
        var rungs = PathData()
        var v = 3.0
        while v < top - g - 13 { rungs.move(ladderFoot + P(-1.4, -v)); rungs.line(ladderFoot + P(1.4, -v)); v += 2.6 }
        svg.path(rungs, stroke: .colour(I.line), width: 0.5)
        pole(foot + P(0, -4), head, width: 2, colour: I.lightTop)
        svg.line([foot + P(-0.5, -4), head + P(-0.5, 0)], stroke: .colour(I.lightShade), width: 0.6)
        // The arm, turned toward trains coming along the track, standing out over it.
        wall(.right, from: x, y, at: top - 8) { p in
            let arm = [p.uv(-0.4, -1.6), p.uv(15, -1.4), p.uv(15, 2), p.uv(-0.4, 2.2)]
            p.shape(arm, .colour(I.light), width: 0.8)
            p.colour([p.uv(0.4, -0.9), p.uv(10.4, -0.8), p.uv(10.4, 1.5), p.uv(0.4, 1.6)], .team)
            p.colour([p.uv(12, -0.8), p.uv(14.3, -0.8), p.uv(14.3, 1.4), p.uv(12, 1.5)], .team)
            p.line([p.uv(0.4, -0.9), p.uv(10.4, -0.8), p.uv(10.4, 1.5), p.uv(0.4, 1.6)], closed: true, width: 0.35, opacity: 0.7)
            // The spectacle: a frame with a red and a green glass, at the arm's root.
            p.shape([p.uv(-4.6, -2.6), p.uv(-0.4, -2.6), p.uv(-0.4, 2.2), p.uv(-4.6, 2.2)], .colour(I.sootShade), width: 0.6)
            p.svg.circle(p.uv(-2.5, 0.9), 0.9, fill: .colour("#c45a4a"))
            p.svg.circle(p.uv(-2.5, -1.3), 0.9, fill: .colour("#7aa07a"))
        }
        // The lamp behind the spectacle, and the finial.
        let lamp = iso(x, y, top - 13)
        shape([lamp + P(-1.6, 0), lamp + P(1.6, 0), lamp + P(1.6, -3.4), lamp + P(-1.6, -3.4)], .colour(I.sootShade), width: 0.6)
        svg.circle(lamp + P(-0.4, -1.7), 0.8, fill: .colour(I.fireCore))
        svg.circle(head + P(0, -1.2), 1.3, fill: .colour(I.sootLit), stroke: .colour(I.line), width: 0.6)
        line([head + P(0, -2.4), head + P(0, -4.6)], width: 0.8)
    }

    // MARK: The depot being built

    /// The depot being built: the station's walls of brick raised part of
    /// their height with scaffolding along the front flying the owner's flag;
    /// the platform raised at its back end and begun along the rest; three of
    /// the canopy's columns standing; the ballast laid and the sleepers and
    /// rails part laid; and rails, sleepers and brick to hand.
    private mutating func depotRising() {
        typealias I = IndustrialNewBuildingsInk
        let (x0, y0, x1, y1) = Depot.station
        let g = Depot.ground, t = 0.14
        brickwork(x0, y0, x1, y0 + t, g, 24, top: .colour(I.freshBrick), fresh: true)
        brickwork(x0, y0 + t, x0 + t, y1, g, 20, top: .colour(I.freshBrick), fresh: true)
        brickwork(x1 - t, y0 + t, x1, y1, g, 15, top: .colour(I.freshBrick), fresh: true)
        // The front wall, low, with the doors' gap.
        brickwork(x0 + t, y1 - t, -0.55, y1, g, 11, top: .colour(I.freshBrick), fresh: true)
        brickwork(-0.2, y1 - t, x1 - t, y1, g, 8, top: .colour(I.freshBrick), fresh: true)
        // Scaffolding along the front, flying the flag.
        scaffold([(x0 - 0.02, y1 + 0.14), (-0.4, y1 + 0.14), (x1 + 0.12, y1 + 0.14), (x1 + 0.12, y0 + 0.2)], from: g, height: 34,
                 levels: [12, 24, 32], boards: 12, inward: (0, -0.1))
        flag(at: iso(x1 + 0.12, y1 + 0.14, g + 34), height: 14, length: 16)
        platform(full: false)
        // Three columns of the canopy, a beam between the first two.
        let deck = g + Depot.platform.top, cy = Depot.canopy.y1 - 0.06
        for x in Depot.columns.prefix(3) { column(x, cy, from: deck, to: Depot.canopy.front - 1, brackets: false) }
        pole(iso(Depot.columns[0], cy, Depot.canopy.front - 1), iso(Depot.columns[1], cy, Depot.canopy.front - 1), width: 1.6, colour: I.green)
        track(laidTo: 0.5, railsTo: 0.1)
        // Rails and sleepers waiting, and brick.
        girders(0.35, 1.3, 1.34, on: g, count: 2)
        planks(-1.3, -0.7, 1.38, on: g, count: 3)
        bricks(0.9, -0.95, 1.2, -0.65, from: g, courses: 3)
        bricks(0.95, -0.45, 1.25, -0.2, from: g, courses: 2)
    }
}
