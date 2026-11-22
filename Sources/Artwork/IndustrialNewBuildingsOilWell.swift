// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age oil well: a tall derrick of timber, braced in each bay,
// over the well, with the owner's flag at its crown; a walking-beam pump
// beside it, its beam rocking on a samson post, driven by a band wheel and
// reaching into the derrick to work the well; a riveted storage tank painted
// in the light colour, banded in the owner's colour, fed by a pipe from the
// well; and a dark stain of oil spread on the ground round the well. Its
// footprint is two tiles square: x and y run from -1 to 1.

extension IndustrialNewBuildingsPainter {
    mutating func oilWell(complete: Bool) {
        typealias I = IndustrialNewBuildingsInk
        block(-1, -1, 1, 1, 0, Well.ground, top: .colour(I.yard), left: .colour(I.yardShade), right: .colour(I.yardShade), width: 1)
        if complete { oilWellComplete() } else { oilWellRising() }
    }

    /// The well's measures: on the map in tiles, heights in points.
    private enum Well {
        static let ground = 1.5
        /// The well, at the derrick's centre.
        static let centre = (x: -0.36, y: -0.36)
        /// The derrick's half-breadth at its foot and at its crown, and its height.
        static let foot = 0.36, crown = 0.075, height = 110.0
        /// The tank's centre, radius and height.
        static let tank = (x: 0.47, y: -0.44, r: 0.3, height: 30.0)
        /// The plane of the pump, along y at this x, and the band wheel's place along it.
        static let pumpX = -0.36, wheelY = 0.6, samsonY = 0.16
    }

    // MARK: The oil well complete

    private mutating func oilWellComplete() {
        typealias I = IndustrialNewBuildingsInk
        let g = Well.ground
        oilStain()
        // The pipe from the well head to the tank.
        let (cx, cy) = Well.centre
        pole(iso(cx, cy, g + 3), iso(Well.tank.x - Well.tank.r * 0.7, cy, g + 3), width: 1.6, colour: I.soot)
        pole(iso(Well.tank.x - Well.tank.r * 0.7, cy, g + 3), iso(Well.tank.x - Well.tank.r * 0.85, Well.tank.y + 0.05, g + 3), width: 1.6,
             colour: I.soot)
        derrick(upTo: Well.height, back: true)
        wellHead(rigged: true)
        // The pump's beam within the derrick, before the derrick's near faces.
        pump(inside: true)
        derrick(upTo: Well.height, back: false)
        pump(inside: false)
        storageTank(complete: true)
        // Drums of oil by the tank, and a spare length of pipe.
        drum(at: iso(0.72, 0.42, g), size: 0.95, paint: I.soot, lit: I.sootLit)
        drum(at: iso(0.86, 0.2, g), size: 0.95)
        girders(0.05, 0.62, 0.78, on: g, count: 1, across: 1)
    }

    /// The stain of crude oil on the ground round the well: an uneven pool,
    /// darkest at the well, with runs toward the front and a sheen on it.
    private mutating func oilStain() {
        typealias I = IndustrialNewBuildingsInk
        let g = Well.ground, (cx, cy) = Well.centre
        // An uneven outline, its radius varying round it, at fixed places.
        let radii: [Double] = [0.5, 0.56, 0.62, 0.74, 0.86, 0.7, 0.62, 0.78, 0.94, 0.72, 0.58, 0.52, 0.48, 0.46, 0.5, 0.46]
        func pool(_ scale: Double, _ ox: Double, _ oy: Double) -> [P] {
            radii.enumerated().map { k, r in
                let a = Double(k) / Double(radii.count) * 2 * .pi
                return iso(cx + ox + cos(a) * r * scale, cy + oy + sin(a) * r * scale, g)
            }
        }
        func smooth(_ points: [P]) -> PathData {
            var d = PathData()
            let n = points.count
            d.move((points[n - 1] + points[0]) * 0.5)
            for k in 0..<n { d.quad(points[k], (points[k] + points[(k + 1) % n]) * 0.5) }
            d.close()
            return d
        }
        let outer = pool(1, 0.06, 0.12), inner = pool(0.55, 0.02, 0.04)
        svg.path(smooth(outer), fill: .colour(I.oil), opacity: 0.55)
        svg.path(smooth(inner), fill: .colour(I.oil), opacity: 0.8)
        svg.path(smooth(outer), stroke: .colour(I.line), width: 0.6, opacity: 0.5)
        // The sheen: soft curls of a bluish grey on the pool.
        for (dx, dy, w) in [(0.25, 0.3, 7.0), (-0.05, 0.5, 5.0), (0.35, 0.05, 4.0)] {
            let p = iso(cx + dx, cy + dy, g)
            svg.path({ var d = PathData(); d.move(p + P(-w / 2, 0)); d.quad(p + P(0, -1.6), p + P(w / 2, 0.2)); return d }(),
                     stroke: .colour(I.oilSheen), width: 0.9, opacity: 0.9)
        }
    }

    /// The derrick's half-breadth at height `h`.
    private func derrickHalf(_ h: Double) -> Double {
        Well.foot + (Well.crown - Well.foot) * h / Well.height
    }

    /// A corner of the derrick at height `h`: `sx` and `sy` are -1 or 1.
    private func derrickCorner(_ sx: Double, _ sy: Double, _ h: Double) -> P {
        let s = derrickHalf(h), (cx, cy) = Well.centre
        return iso(cx + sx * s, cy + sy * s, Well.ground + h)
    }

    /// The derrick, up to `top` points: its back faces (the two turned away
    /// from the viewer, drawn darker) or its near faces, each with its legs, the
    /// girts across it, and a brace across each bay; with the crown, its sheave
    /// and the flag when it stands to its full height.
    private mutating func derrick(upTo top: Double, back: Bool) {
        typealias I = IndustrialNewBuildingsInk
        let girts = [14.0, 34, 56, 80, Well.height - 4].filter { $0 <= top + 0.1 }
        let faces: [((Double, Double), (Double, Double))] = back
            ? [((-1, 1), (-1, -1)), ((-1, -1), (1, -1))]
            : [((-1, 1), (1, 1)), ((1, 1), (1, -1))]
        let paint = back ? I.timberDark : I.timberLight
        if !back {
            // Sills under the legs.
            for (sx, sy) in [(-1.0, 1.0), (1.0, 1.0), (1.0, -1.0)] {
                let c = Well.centre, s = Well.foot
                block(c.x + sx * s - 0.05, c.y + sy * s - 0.05, c.x + sx * s + 0.05, c.y + sy * s + 0.05, Well.ground, Well.ground + 2.4,
                      top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark), width: 0.6)
            }
        }
        for (a, b) in faces {
            var levels = [0.0] + girts
            if levels.last! < top - 0.1 { levels.append(top) }
            for (h0, h1) in zip(levels, levels.dropFirst()) {
                // A brace across the bay, from one foot to the other head.
                pole(derrickCorner(a.0, a.1, h0), derrickCorner(b.0, b.1, h1), width: back ? 0.8 : 1, colour: back ? I.timberDark : I.timber)
            }
            for h in girts { pole(derrickCorner(a.0, a.1, h), derrickCorner(b.0, b.1, h), width: back ? 1 : 1.3, colour: paint) }
        }
        let legs: [(Double, Double)] = back ? [(-1, -1)] : [(-1, 1), (1, 1), (1, -1)]
        for (sx, sy) in legs {
            pole(derrickCorner(sx, sy, 0), derrickCorner(sx, sy, top), width: back ? 1.6 : 2.2, colour: paint)
        }
        guard !back, top >= Well.height - 0.1 else { return }
        // The crown: a frame of timber over the top, its sheave, and the flag.
        let (cx, cy) = Well.centre, s = Well.crown + 0.03, h = Well.ground + Well.height
        block(cx - s, cy - s, cx + s, cy + s, h, h + 3, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.8)
        let sheave = iso(cx, cy, h + 6.5)
        svg.ellipse(sheave, 2.2, 3.4, fill: .colour(I.sootLit), stroke: .colour(I.line), width: 0.7)
        svg.circle(sheave, 0.7, fill: .colour(I.dark))
        flag(at: iso(cx + s, cy + s, h + 3), height: 16, length: 15)
    }

    /// The head of the well within the derrick: its casing and valve, and the
    /// line from the crown's sheave down to the pump's rod.
    private mutating func wellHead(rigged: Bool) {
        typealias I = IndustrialNewBuildingsInk
        let g = Well.ground, (cx, cy) = Well.centre
        if rigged { line([iso(cx, cy, g + Well.height + 4), iso(cx, cy, g + 26)], width: 0.6, opacity: 0.8) }
        frustum(cx, cy, 0.07, 0.07, g, g + 4, lit: I.sootLit, mid: I.soot, shade: I.sootShade, top: .colour(I.sootLit), width: 0.8)
        frustum(cx, cy, 0.04, 0.04, g + 4, g + 9, lit: I.sootLit, mid: I.soot, shade: I.sootShade, top: .colour(I.sootLit), width: 0.7)
        // The valve's wheel.
        let v = iso(cx, cy, g + 7)
        svg.ellipse(v + P(3, 0), 1.2, 2, fill: .none, stroke: .colour(I.line), width: 0.8)
        line([v, v + P(3, 0)], width: 0.6)
    }

    /// The walking-beam pump, in the plane along y through the well: a band
    /// wheel turned by its belt, a crank and a pitman rod rocking the beam on
    /// its samson post, and the beam's horse head over the well, hung with the
    /// pump's rod. `inside` draws only the part within the derrick; otherwise the rest.
    private mutating func pump(inside: Bool) {
        typealias I = IndustrialNewBuildingsInk
        let g = Well.ground, x = Well.pumpX
        let origin = 0.92
        func u(_ y: Double) -> Double { (origin - y) * 32 }
        let wellU = u(Well.centre.y), wheelU = u(Well.wheelY), samsonU = u(Well.samsonY)
        let frontFace = u(Well.centre.y + Well.foot)
        let pivot = 27.0, tilt = 2.2
        wall(.right, from: x, origin, at: g) { p in
            let id = inside ? "pump-inside" : "pump-outside"
            let (c0, c1) = inside ? (frontFace, 200.0) : (-50.0, frontFace)
            p.svg.raw("<clipPath id=\"\(id)\"><rect x=\"\(num(c0))\" y=\"-200\" width=\"\(num(c1 - c0))\" height=\"400\"/></clipPath>"
                      + "<g clip-path=\"url(#\(id))\">")
            /// A point on the beam, `t` along it from the pivot (positive toward the well), at its top or foot.
            func beam(_ du: Double, _ dv: Double) -> P { p.uv(samsonU + du, pivot + dv - du * tilt / 20) }
            // The pump's rod hanging from the horse head into the well.
            let head = wellU - samsonU
            p.line([beam(head, -5), p.uv(wellU, 9)], width: 1.4)
            p.svg.line([beam(head, -5), p.uv(wellU, 9)], stroke: .colour(I.steel), width: 0.6)
            // The samson post: two legs and a cap.
            if !inside {
                p.pole(p.uv(samsonU - 5, 0), p.uv(samsonU, pivot - 1.4), width: 2, colour: I.timber)
                p.pole(p.uv(samsonU + 5, 0), p.uv(samsonU, pivot - 1.4), width: 2, colour: I.timber)
                p.pole(p.uv(samsonU - 3.2, 9), p.uv(samsonU + 3.2, 9), width: 1.2, colour: I.timberDark)
                // The band wheel on its frame, and its belt running back.
                let wheel = p.uv(wheelU, 10), r = 8.0
                p.pole(p.uv(wheelU - 4, 0), wheel, width: 1.6, colour: I.timberDark)
                p.pole(p.uv(wheelU + 4, 0), wheel, width: 1.6, colour: I.timberDark)
                p.svg.circle(wheel, r + 0.6, fill: .colour(I.line))
                p.svg.circle(wheel + p.shift * 0.4, r - 0.3, fill: .colour(I.timberLight))
                p.svg.circle(wheel, r - 1.6, fill: .colour(I.yardShade))
                var spokes = PathData()
                for k in 0..<8 {
                    let a = Double(k) * .pi / 4 + 0.2
                    spokes.move(wheel + P(cos(a), sin(a)) * 1.2); spokes.line(wheel + P(cos(a), sin(a)) * (r - 1.6))
                }
                p.svg.path(spokes, stroke: .colour(I.line), width: 1.4)
                p.svg.path(spokes, stroke: .colour(I.timber), width: 0.6)
                p.svg.circle(wheel, r - 1.6, fill: .none, stroke: .colour(I.line), width: 0.6)
                p.svg.circle(wheel, 1.6, fill: .colour(I.soot), stroke: .colour(I.line), width: 0.5)
                // The crank pin and the pitman rod up to the beam's tail.
                let pin = wheel + P(4.4, -2)
                p.pole(pin, beam(-(samsonU - wheelU) + 1, -1.2), width: 1.3, colour: I.timber)
                p.svg.circle(pin, 0.9, fill: .colour(I.steel), stroke: .colour(I.line), width: 0.5)
            }
            // The beam: a squared timber, its lit top, from its tail past the pivot to the horse head.
            let tail = -(samsonU - wheelU) - 1.5
            let body = [beam(tail, 1.4), beam(head - 1, 1.4), beam(head - 1, -1.8), beam(tail, -1.8)]
            p.shape(body, .colour(I.timber), width: 0.9)
            p.colour([beam(tail + 0.4, 1.3), beam(head - 1.4, 1.3), beam(head - 1.4, 0.2), beam(tail + 0.4, 0.2)], .colour(I.timberLight))
            // The horse head: a curved iron face over the well.
            let h0 = beam(head - 1.6, 2.6), h1 = beam(head - 1.6, -6)
            p.shape([h0, h0 + P(2.2, 0.4), h1 + P(3.4, 0), h1 + P(0.6, 0.6)], .colour(I.sootLit), width: 0.8)
            // The pivot's bearing on the post.
            if !inside {
                p.svg.circle(p.uv(samsonU, pivot), 1.5, fill: .colour(I.soot), stroke: .colour(I.line), width: 0.6)
            }
            p.svg.raw("</g>")
        }
    }

    /// The storage tank: a cylinder of riveted plate painted in the light
    /// colour, banded in the owner's colour with the age's mark, under a low
    /// cone of soot, with a ladder up its side. Being built, only its lowest
    /// ring of plates stands.
    private mutating func storageTank(complete: Bool) {
        typealias I = IndustrialNewBuildingsInk
        let g = Well.ground, t = Well.tank
        let top = complete ? g + t.height : g + 9
        shadow(arc(t.x + 0.12, t.y - 0.04, t.r, from: -80, to: 80, at: g) + [round(t.x, t.y, t.r, 80, g)], opacity: 0.14)
        // A footing of concrete.
        frustum(t.x, t.y, t.r + 0.03, t.r + 0.03, g, g + 2, lit: I.lightShade, mid: I.lightDark, shade: I.lightDark, width: 0.8)
        frustum(t.x, t.y, t.r, t.r, g + 2, top, lit: I.lightTop, mid: I.light, shade: I.lightShade,
                top: complete ? nil : .colour(I.lightDark))
        // The seams of the plates, with their rivets.
        rings(t.x, t.y, t.r, t.r, g + 2, top, every: 7, from: g + 9, to: top, width: 0.5, opacity: 0.55)
        var seams = PathData()
        for a in stride(from: -20.0, to: 135, by: 38) {
            seams.move(round(t.x, t.y, t.r, a, g + 2)); seams.line(round(t.x, t.y, t.r, a, top))
        }
        svg.path(seams, stroke: .colour(I.line), width: 0.45, opacity: 0.45)
        guard complete else {
            hollowRing(t.x, t.y, t.r, at: top)
            return
        }
        // The band in the owner's colour, edged in the lighter paint, with the mark at its front.
        let b0 = g + 15, b1 = g + 23
        let band = arc(t.x, t.y, t.r, from: -45, to: 135, at: b0) + arc(t.x, t.y, t.r, from: 135, to: -45, at: b1)
        colour(band, .team)
        line(arc(t.x, t.y, t.r, from: -45, to: 135, at: b0), width: 0.5, opacity: 0.8)
        line(arc(t.x, t.y, t.r, from: -45, to: 135, at: b1), width: 0.5, opacity: 0.8)
        // The shade of the band's right side, laid over the team's colour as a film.
        shadow(arc(t.x, t.y, t.r, from: -45, to: 10, at: b0) + arc(t.x, t.y, t.r, from: 10, to: -45, at: b1), opacity: 0.18)
        mark(at: round(t.x, t.y, t.r, 60, (b0 + b1) / 2), radius: 3)
        // The roof: a low cone of soot, with a hatch.
        let apex = iso(t.x, t.y, top + 7)
        let cone = hull(arc(t.x, t.y, t.r + 0.02, from: 0, to: 360, at: top, steps: 36) + [apex])
        colour(cone, .colour(I.soot))
        colour(arc(t.x, t.y, t.r + 0.02, from: 60, to: 150, at: top, steps: 8) + [apex], .colour(I.sootLit))
        colour(arc(t.x, t.y, t.r + 0.02, from: -60, to: 10, at: top, steps: 8) + [apex], .colour(I.sootShade))
        line(cone, closed: true, width: 1)
        line([round(t.x, t.y, t.r + 0.02, 45, top), apex], width: 0.4, opacity: 0.5)
        shape([apex + P(-2.6, 3), apex + P(1, 4.6), apex + P(2.6, 3.4), apex + P(-1, 1.8)], .colour(I.sootShade), width: 0.6)
        // The ladder up the side toward the viewer's left.
        let foot0 = round(t.x, t.y, t.r + 0.02, 112, g + 2), foot1 = round(t.x, t.y, t.r + 0.02, 124, g + 2)
        let head0 = round(t.x, t.y, t.r + 0.02, 112, top + 2), head1 = round(t.x, t.y, t.r + 0.02, 124, top + 2)
        line([foot0, head0], width: 1)
        line([foot1, head1], width: 1)
        var rungs = PathData()
        var v = 3.0
        while v < top - g {
            rungs.move(foot0 + P(0, -v)); rungs.line(foot1 + P(0, -v)); v += 2.8
        }
        svg.path(rungs, stroke: .colour(I.line), width: 0.6)
    }

    /// The open top of a ring of plate being built, at `h`.
    private mutating func hollowRing(_ cx: Double, _ cy: Double, _ r: Double, at h: Double) {
        typealias I = IndustrialNewBuildingsInk
        let rim = arc(cx, cy, r, from: 0, to: 360, at: h, steps: 36)
        colour(rim, .colour(I.lightDark))
        let floor = arc(cx, cy, r - 0.03, from: 180, to: 360, at: h - 6, steps: 18)
        svg.polygon(floor + arc(cx, cy, r - 0.03, from: 0, to: 180, at: h, steps: 18), fill: .colour(I.yardShade))
        line(rim, closed: true, width: 0.8)
    }

    // MARK: The oil well being built

    /// The oil well being built: the derrick raised to half its height, the
    /// owner's flag on a pole lashed to its top; the tank's first ring of
    /// plates standing, more plates stacked; the timber for the derrick and
    /// the pump laid out; and a drum, with the first spill of oil at the well.
    private mutating func oilWellRising() {
        typealias I = IndustrialNewBuildingsInk
        let g = Well.ground, (cx, cy) = Well.centre
        let p = iso(cx + 0.1, cy + 0.2, g)
        svg.ellipse(p, 10, 4.4, fill: .colour(I.oil), opacity: 0.45)
        let top = 56.0
        derrick(upTo: top, back: true)
        wellHead(rigged: false)
        derrick(upTo: top, back: false)
        // The flag, lashed to the derrick's near leg.
        let leg = derrickCorner(1, 1, top)
        flag(at: leg, height: 18, length: 15)
        storageTank(complete: false)
        // Timber for the rest of the derrick and the beam, and plates for the tank.
        planks(-0.45, 0.35, 0.72, on: g, count: 3)
        planks(-0.85, -0.25, 0.42, on: g, count: 2)
        for k in 0..<3 {
            let h = g + Double(k) * 1.4
            block(0.45 + Double(k) * 0.02, 0.05, 0.85, 0.3 - Double(k) * 0.02, h, h + 1.4, top: .colour(I.light), left: .colour(I.lightShade),
                  right: .colour(I.lightDark), width: 0.6)
        }
        drum(at: iso(0.82, 0.62, g), size: 0.95, paint: I.soot, lit: I.sootLit)
    }
}
