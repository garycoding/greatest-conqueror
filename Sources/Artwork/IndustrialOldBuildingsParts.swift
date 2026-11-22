// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The parts the Industrial age adds to the older buildings: roofs of
// blue-grey slate with iron finials and cresting, and bargeboards painted the
// light colour; walls of red brick laid in courses, with string courses,
// pilasters and dressings of stone; sash windows and panelled doors with
// fanlights; chimney stacks with pots of clay; gas lamps, cast-iron railings,
// columns and drainpipes; a clock; battlements; and the banners, pennants and
// painted bands that carry the owner's colour, each edged in the light colour
// and charged with a cogwheel.

extension IndustrialOldBuildingsPainter {
    // MARK: Roofs of slate

    /// One slope of a roof of slate. Its eave runs from `start` on the map
    /// along the unit vector `along` for `length` tiles at `h` points up; the
    /// slope rises toward `inward` for `depth` tiles to the ridge at `top`
    /// points. A hip cuts in `hip0` tiles at the eave's start and `hip1` at its
    /// end (zero for a gable). The slates are laid in courses across the slope,
    /// their joints staggered, a few of them paler; `rows` is false for a slope
    /// that barely shows.
    mutating func slateSlope(_ start: (Double, Double), along: (Double, Double), inward: (Double, Double),
                             length: Double, depth: Double, hip0: Double, hip1: Double, from h: Double,
                             to top: Double, _ paint: String, rows: Bool) {
        typealias I = IndustrialOldBuildingsInk
        func at(_ u: Double, _ s: Double) -> P {
            iso(start.0 + along.0 * u + inward.0 * depth * s, start.1 + along.1 * u + inward.1 * depth * s, h + (top - h) * s)
        }
        let outline = [at(0, 0), at(length, 0), at(length - hip1, 1), at(hip0, 1)]
        colour(outline, .colour(paint))
        if rows {
            let count = max(4, Int(((top - h) / 3.4).rounded()))
            let pitch = 0.095
            var joints = PathData(), edges = PathData(), courses = PathData()
            for k in 0..<count {
                let s0 = Double(k) / Double(count), s1 = Double(k + 1) / Double(count)
                let lo = hip0 * s1, hi = length - hip1 * s1
                // The pale few: picked by a fixed rule, so that every drawing is the same.
                var u = (k % 2 == 0 ? pitch / 2 : pitch) + lo
                var j = 0
                while u < hi - 0.03 {
                    if (k * 7 + j * 5) % 13 == 0, u + pitch < hi {
                        let mid = (s0 + s1) / 2
                        colour([at(u, s0), at(u + pitch, s0), at(u + pitch, mid + (s1 - mid) * 0.9), at(u, mid + (s1 - mid) * 0.9)],
                               .colour(I.slateLight), opacity: 0.7)
                    }
                    joints.move(at(u, s0)); joints.line(at(u, s1))
                    u += pitch
                    j += 1
                }
                if k > 0 {
                    courses.move(at(hip0 * s0, s0)); courses.line(at(length - hip1 * s0, s0))
                }
                // The lit lower edge of each course.
                edges.move(at(hip0 * s0 + 0.01, s0) + P(0, -0.6)); edges.line(at(length - hip1 * s0 - 0.01, s0) + P(0, -0.6))
            }
            svg.path(edges, stroke: .colour(I.slateLight), width: 0.5, opacity: 0.8)
            svg.path(joints, stroke: .colour(I.slateDark), width: 0.4, opacity: 0.7)
            svg.path(courses, stroke: .colour(I.slateDark), width: 0.55, opacity: 0.9)
        }
        line(outline, closed: true, width: 1)
    }

    /// The thickness of an eave from `a` to `b` on the screen: the edge of the
    /// slates over a fascia painted the light colour.
    mutating func eaveEdge(_ a: P, _ b: P) {
        typealias I = IndustrialOldBuildingsInk
        let drop = P(0, 1.6)
        shape([a, b, b + drop, a + drop], .colour(I.slateDark), width: 0.7)
        shape([a + drop, b + drop, b + drop * 1.9, a + drop * 1.9], .colour(I.plasterShade), width: 0.6)
    }

    /// A steep hipped roof of slate over the block from (x0, y0) to (x1, y1),
    /// overhanging it by `overhang` tiles, its eaves at `h` points and its
    /// ridge `rise` points above them (by default as steep as the age builds);
    /// a square block takes a pyramid. A iron finial stands at each end of the
    /// ridge, or at the apex, when `finials`. Returns the height of the ridge.
    @discardableResult
    mutating func hippedRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eaves h: Double, rise: Double? = nil,
                             overhang o: Double = 0.07, finials: Bool = true) -> Double {
        typealias I = IndustrialOldBuildingsInk
        let (a, b, c, d) = (x0 - o, y0 - o, x1 + o, y1 + o)
        let lx = c - a, ly = d - b
        let k = min(lx, ly) / 2
        let top = h + (rise ?? 46 * k)
        slateSlope((c, b), along: (-1, 0), inward: (0, 1), length: lx, depth: k, hip0: k, hip1: k, from: h, to: top, I.slateShade,
                   rows: false)
        slateSlope((a, b), along: (0, 1), inward: (1, 0), length: ly, depth: k, hip0: k, hip1: k, from: h, to: top, I.slateShade,
                   rows: false)
        slateSlope((a, d), along: (1, 0), inward: (0, -1), length: lx, depth: k, hip0: k, hip1: k, from: h, to: top, I.slate,
                   rows: true)
        slateSlope((c, d), along: (0, -1), inward: (-1, 0), length: ly, depth: k, hip0: k, hip1: k, from: h, to: top, I.slateShade,
                   rows: true)
        eaveEdge(iso(a, d, h), iso(c, d, h))
        eaveEdge(iso(c, d, h), iso(c, b, h))
        let wide = lx >= ly
        let r0 = iso(a + k, b + k, top), r1 = wide ? iso(c - k, b + k, top) : iso(a + k, d - k, top)
        let hips = wide ? [(iso(a, d, h), r0), (iso(c, d, h), r1), (iso(c, b, h), r1)]
                        : [(iso(a, d, h), r1), (iso(c, d, h), r1), (iso(c, b, h), r0)]
        for (p, q) in hips {
            svg.line([p, q], stroke: .colour(I.line), width: 2)
            svg.line([p, q], stroke: .colour(I.ironLight), width: 0.9)
        }
        svg.line([r0, r1], stroke: .colour(I.line), width: 2.6)
        svg.line([r0, r1], stroke: .colour(I.ironLight), width: 1.3)
        if finials {
            finial(at: r0, size: 1)
            if r1 != r0 { finial(at: r1, size: 1) }
        }
        return top
    }

    /// A steep gabled roof of slate over a box from (x0, y0) to (x1, y1), its
    /// ridge running along x at `ridge` points and its eaves at `eave`,
    /// overhanging by `over` tiles. Its gable faces +x (the screen's lower
    /// right); `gable` draws on the gable's wall before the verge covers it,
    /// given the wall's width and the ridge's height above the eaves. An iron
    /// finial stands on the gable's apex when `finials`.
    mutating func gableAlongX(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double,
                              over: Double = 0.08, gableWall: Paint, finials: Bool = true,
                              gable: (inout IndustrialOldBuildingsPainter, Double, Double) -> Void = { _, _, _ in }) {
        typealias I = IndustrialOldBuildingsInk
        let ym = (y0 + y1) / 2
        let (a0, a1, b0, b1) = (x0 - over, x1 + over, y0 - over, y1 + over)
        let drop = (ridge - eave) * over / (ym - y0)
        colour([iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a0, b0, eave - drop)], .colour(I.slateShade))
        let triangle = [iso(x1, y1, eave), iso(x1, y0, eave), iso(x1, ym, ridge)]
        colour(triangle, gableWall)
        wall(.right, from: x1, y1, at: eave) { p in gable(&p, (y1 - y0) * 32, ridge - eave) }
        line(triangle, closed: true, width: 0.9)
        // The verge: the slates' edge over a bargeboard painted the light colour.
        let edge = P(0, 2.2)
        colour([iso(a1, b1, eave - drop), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a1, b0, eave - drop) + edge,
                iso(a1, ym, ridge) + edge, iso(a1, b1, eave - drop) + edge], .colour(I.light))
        slateSlope((a0, b1), along: (1, 0), inward: (0, -1), length: a1 - a0, depth: b1 - ym, hip0: 0, hip1: 0,
                   from: eave - drop, to: ridge, I.slate, rows: true)
        eaveEdge(iso(a0, b1, eave - drop), iso(a1, b1, eave - drop))
        line([iso(a1, ym, ridge), iso(a1, ym, ridge) + edge, iso(a1, b0, eave - drop) + edge, iso(a1, b0, eave - drop)], width: 0.9)
        line([iso(a1, b1, eave - drop) + edge, iso(a1, ym, ridge) + edge], width: 0.9)
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.line), width: 2.8)
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.ironLight), width: 1.3)
        if finials {
            finial(at: iso(a1, ym, ridge), size: 1)
        }
    }

    /// A steep gabled roof of slate over a box from (x0, y0) to (x1, y1), its
    /// ridge running along y at `ridge` points and its eaves at `eave`. Its
    /// gable faces +y (the screen's lower left); `gable` draws on the gable's
    /// wall, given the wall's width and the ridge's height above the eaves. A
    /// iron finial stands on the gable's apex when `finials`.
    mutating func gableAlongY(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double,
                              over: Double = 0.08, gableWall: Paint, finials: Bool = true,
                              gable: (inout IndustrialOldBuildingsPainter, Double, Double) -> Void = { _, _, _ in }) {
        typealias I = IndustrialOldBuildingsInk
        let xm = (x0 + x1) / 2
        let (a0, a1, b0, b1) = (x0 - over, x1 + over, y0 - over, y1 + over)
        let drop = (ridge - eave) * over / (xm - x0)
        colour([iso(xm, b0, ridge), iso(xm, b1, ridge), iso(a0, b1, eave - drop), iso(a0, b0, eave - drop)], .colour(I.slateShade))
        let triangle = [iso(x0, y1, eave), iso(x1, y1, eave), iso(xm, y1, ridge)]
        colour(triangle, gableWall)
        wall(.left, from: x0, y1, at: eave) { p in gable(&p, (x1 - x0) * 32, ridge - eave) }
        line(triangle, closed: true, width: 0.9)
        slateSlope((a1, b1), along: (0, -1), inward: (-1, 0), length: b1 - b0, depth: a1 - xm, hip0: 0, hip1: 0,
                   from: eave - drop, to: ridge, I.slateShade, rows: true)
        eaveEdge(iso(a1, b1, eave - drop), iso(a1, b0, eave - drop))
        // The verge over the gable: the slates' edge on a bargeboard painted the light colour.
        let edge = P(0, 2.2)
        let rake = [iso(a0, b1, eave - drop), iso(xm, b1, ridge), iso(a1, b1, eave - drop)]
        colour([rake[0], rake[1], rake[2], rake[2] + edge, rake[1] + edge, rake[0] + edge], .colour(I.light))
        line([rake[0], rake[1], rake[2], rake[2] + edge, rake[1] + edge, rake[0] + edge], closed: true, width: 0.9)
        svg.line([iso(xm, b0, ridge), iso(xm, b1, ridge)], stroke: .colour(I.line), width: 2.8)
        svg.line([iso(xm, b0, ridge), iso(xm, b1, ridge)], stroke: .colour(I.ironLight), width: 1.3)
        if finials {
            finial(at: iso(xm, b1, ridge), size: 1)
        }
    }

    // MARK: Ironwork on the roofs

    /// An iron finial standing at `p` on the screen: a short shaft through a
    /// ball, ending in a spear point.
    mutating func finial(at p: P, size s: Double = 1) {
        typealias I = IndustrialOldBuildingsInk
        svg.line([p + P(0, 0.6), p - P(0, 6.6 * s)], stroke: .colour(I.line), width: 1.3 * s)
        svg.line([p, p - P(0, 5.8 * s)], stroke: .colour(I.ironLight), width: 0.5 * s)
        svg.circle(p - P(0, 2.8 * s), 1.3 * s, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        svg.circle(p - P(0.4 * s, 3.2 * s), 0.4 * s, fill: .colour(I.ironLight))
        shape([p - P(1.1 * s, 5.4 * s), p - P(0, 8.2 * s), p + P(1.1 * s, -5.4 * s)], .colour(I.iron), width: 0.45)
    }

    /// Iron cresting along a ridge from `a` to `b` on the screen: a rail
    /// with small fleurs standing on it, `height` points tall.
    mutating func cresting(_ a: P, _ b: P, height: Double = 3.4) {
        typealias I = IndustrialOldBuildingsInk
        let d = b - a, length = (d.x * d.x + d.y * d.y).squareRoot()
        guard length > 2 else { return }
        let count = max(2, Int(length / 3.4))
        var stems = PathData(), rail = PathData()
        rail.move(a - P(0, height * 0.55)); rail.line(b - P(0, height * 0.55))
        for k in 0...count {
            let t = Double(k) / Double(count), p = a + d * t
            stems.move(p); stems.line(p - P(0, height))
        }
        svg.path(stems, stroke: .colour(I.line), width: 0.75)
        svg.path(rail, stroke: .colour(I.line), width: 0.6)
        for k in 0...count {
            let p = a + d * (Double(k) / Double(count))
            svg.circle(p - P(0, height), 0.55, fill: .colour(I.ironDark))
        }
    }

    /// A weathervane of iron standing at `p` on the screen, `height` points
    /// tall: a rod, a ball, the arms of the four quarters, and a vane of an
    /// arrow with a pennon for its tail.
    mutating func weathervane(at p: P, height: Double) {
        typealias I = IndustrialOldBuildingsInk
        let top = p - P(0, height)
        svg.line([p, top], stroke: .colour(I.line), width: 1.3)
        svg.line([p, top], stroke: .colour(I.ironLight), width: 0.5)
        let ball = p - P(0, height * 0.3)
        svg.circle(ball, 1.8, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        svg.circle(ball + P(-0.6, -0.6), 0.55, fill: .colour(I.ironLight))
        let arms = p - P(0, height * 0.55)
        line([arms + P(-4.4, 2.2), arms + P(4.4, -2.2)], width: 0.6)
        line([arms + P(-4.4, -2.2), arms + P(4.4, 2.2)], width: 0.6)
        let v = top + P(0, 3)
        let vane = [v + P(-8, -2.8), v + P(-1, -1.4), v + P(5, -1.1), v + P(5, 1.1), v + P(-1, 1.4), v + P(-8, 2.8), v + P(-6, 0)]
        shape(vane, .colour(I.iron), width: 0.6)
        shape([v + P(5, -2.4), v + P(9, 0), v + P(5, 2.4)], .colour(I.iron), width: 0.6)
        svg.circle(top, 0.8, fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.4)
    }

    /// A clock's face on a wall drawn with `wall`, centred on (`u`, `v`),
    /// `r` points across its ring: a dial of the light colour in a black
    /// iron ring set in a square of stone, its hours marked, its brass hands
    /// at ten o'clock.
    mutating func clock(_ u: Double, _ v: Double, radius r: Double) {
        typealias I = IndustrialOldBuildingsInk
        let c = uv(u, v)
        shape(panel(u - r - 1.2, v - r - 1.2, u + r + 1.2, v + r + 1.2), .colour(I.stoneTop), width: 0.6)
        svg.circle(c + shift * 0.6, r, fill: .colour(I.ironDark))
        svg.circle(c, r, fill: .none, stroke: .colour(I.line), width: 0.8)
        svg.circle(c, r * 0.8, fill: .colour(I.plasterTop), stroke: .colour(I.line), width: 0.5)
        var ticks = PathData()
        for k in 0..<12 {
            let a = Double(k) * .pi / 6
            let dir = P(sin(a), -cos(a))
            ticks.move(c + dir * (r * 0.7)); ticks.line(c + dir * (r * (k % 3 == 0 ? 0.48 : 0.58)))
        }
        svg.path(ticks, stroke: .colour(I.line), width: max(0.4, r * 0.08))
        let hour = P(sin(-.pi / 3), -cos(-.pi / 3))
        svg.line([c, c + hour * (r * 0.42)], stroke: .colour(I.line), width: max(0.7, r * 0.14))
        svg.line([c, c + P(0, -r * 0.62)], stroke: .colour(I.line), width: max(0.5, r * 0.09))
        svg.circle(c, max(0.5, r * 0.12), fill: .colour(I.brass))
    }

    // MARK: Brick

    /// Brickwork on a wall drawn with `wall`, from `u0` to `u1` and `v0` to
    /// `v1`: courses of stretchers in English garden-wall bond, the joints
    /// staggered, and a few burnt headers picked out darker by a fixed rule.
    mutating func brickwork(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, course: Double = 2.5,
                            brick: Double = 6, opacity: Double = 0.3, burnt: Bool = true) {
        typealias I = IndustrialOldBuildingsInk
        var d = PathData()
        var v = v0, row = 0
        while v < v1 - 0.3 {
            let top = min(v + course, v1)
            if v > v0 { d.move(uv(u0, v)); d.line(uv(u1, v)) }
            var u = u0 + (row % 2 == 0 ? brick / 2 : brick)
            var j = 0
            while u < u1 - 0.4 {
                if u > u0 + 0.4 { d.move(uv(u, v + 0.2)); d.line(uv(u, top - 0.2)) }
                if burnt, (row * 5 + j * 3) % 11 == 0, u + brick < u1 {
                    colour(panel(u + 0.25, v + 0.25, u + brick - 0.25, top - 0.25), .colour(I.brickDark), opacity: 0.35)
                }
                u += brick
                j += 1
            }
            v += course
            row += 1
        }
        svg.path(d, stroke: .colour(I.line), width: 0.35, opacity: opacity)
    }

    /// A string course of dressed stone across a wall drawn with `wall`, from
    /// `u0` to `u1`, between `v0` and `v1`, its top lit.
    mutating func stringCourse(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(u0, v0, u1, v1), .colour(I.stoneTop), width: 0.55)
        line([uv(u0, v0 + (v1 - v0) * 0.4), uv(u1, v0 + (v1 - v0) * 0.4)], width: 0.35, opacity: 0.45)
    }

    /// A pilaster of brick standing proud of a wall drawn with `wall`,
    /// centred on `u`, `w` wide, from `v0` to `v1`: its lit edge and a stone cap.
    mutating func pilaster(_ u: Double, _ v0: Double, _ v1: Double, w: Double = 3) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(u - w / 2, v0, u + w / 2, v1), .colour(I.brickTop), width: 0.5)
        line([uv(u + w / 2 - 0.6, v0 + 0.3), uv(u + w / 2 - 0.6, v1 - 0.3)], width: 0.35, opacity: 0.4)
        shape(panel(u - w / 2 - 0.6, v1 - 1.2, u + w / 2 + 0.6, v1), .colour(I.stoneTop), width: 0.45)
    }

    // MARK: Windows and doors

    /// A sash window on a wall drawn with `wall`: its foot at (`u`, `v`), `w`
    /// wide and `h` tall, `lights` sashes side by side, each of two sashes, one
    /// over the other, of two panes each, in frames painted the light colour,
    /// under a lintel and over a sill of dressed stone. A `frame` other than
    /// stone gives a segmental arch of brick for the lintel.
    mutating func casement(_ u: Double, _ v: Double, w: Double, h: Double, lights: Int = 2,
                           frame: String = IndustrialOldBuildingsInk.stoneTop) {
        typealias I = IndustrialOldBuildingsInk
        let stoneDressed = frame == I.stoneTop || frame == I.stone
        // The reveal, in shadow.
        colour(panel(u - 0.9, v - 0.2, u + w + 0.9, v + h + 0.7), .colour(I.dark), opacity: 0.55)
        let gap = 1.3, each = (w - gap * Double(lights - 1)) / Double(lights)
        for k in 0..<lights {
            let a = u + Double(k) * (each + gap)
            shape(panel(a - 0.5, v - 0.3, a + each + 0.5, v + h + 0.4), .colour(I.light), width: 0.5)
            let m = v + h * 0.5
            for (s0, s1) in [(v + 0.4, m - 0.35), (m + 0.35, v + h - 0.1)] {
                colour(panel(a + 0.25, s0, a + each - 0.25, s1), .colour(I.glass))
                // The sky caught in the upper corner of each sash.
                colour([uv(a + 0.25, s0 + (s1 - s0) * 0.35), uv(a + 0.25 + (each - 0.5) * 0.6, s1), uv(a + 0.25, s1)],
                       .colour(I.glassLight), opacity: 0.75)
            }
            // The meeting rail and the glazing bar.
            svg.line([uv(a, m), uv(a + each, m)], stroke: .colour(I.light), width: 0.9)
            svg.line([uv(a + each / 2, v + 0.3), uv(a + each / 2, v + h)], stroke: .colour(I.light), width: 0.5)
            line(panel(a + 0.25, v + 0.4, a + each - 0.25, v + h - 0.1), closed: true, width: 0.4)
            line([uv(a, m), uv(a + each, m)], width: 0.3, opacity: 0.6)
        }
        if lights > 1 {
            for k in 1..<lights {
                let a = u + Double(k) * (each + gap) - gap
                shape(panel(a, v - 0.3, a + gap, v + h + 0.4), .colour(stoneDressed ? I.stoneTop : I.light), width: 0.4)
            }
        }
        if stoneDressed {
            shape(panel(u - 1.6, v + h + 0.6, u + w + 1.6, v + h + 2.4), .colour(I.stoneTop), width: 0.55)
            shape(panel(u + w / 2 - 0.8, v + h + 0.6, u + w / 2 + 0.8, v + h + 2.8), .colour(I.stone), width: 0.4)
        } else {
            // A segmental arch of brick on edge.
            let r0 = h + 0.6, r1 = h + 2.6
            let (a0, a1, a2) = (uv(u - 1, v + r0), uv(u + w / 2, v + r0 + 2.2), uv(u + w + 1, v + r0))
            let (b0, b1, b2) = (uv(u + w + 1.2, v + r1), uv(u + w / 2, v + r1 + 2.2), uv(u - 1.2, v + r1))
            colour(.colour(I.brickShade)) { d, o in
                d.move(a0 + o); d.quad(a1 + o, a2 + o); d.line(b0 + o); d.quad(b1 + o, b2 + o); d.close()
            }
            line(width: 0.5) { d in
                d.move(a0); d.quad(a1, a2)
                d.move(b2); d.quad(b1, b0)
            }
        }
        shape(panel(u - 1.7, v - 1.5, u + w + 1.7, v - 0.2), .colour(I.stoneTop), width: 0.55)
    }

    /// A panelled door painted `paint`, centred on `u` and standing on `v` on
    /// a wall drawn with `wall`, `w` wide and `h` tall to the crown of its
    /// round head: four sunk panels, a brass knob, and a fanlight of glass
    /// with radiating bars in the head, in a surround of `surround`.
    mutating func door(_ u: Double, _ v: Double, w: Double, h: Double, paint: String = IndustrialOldBuildingsInk.green,
                       surround: String = IndustrialOldBuildingsInk.stoneTop) {
        typealias I = IndustrialOldBuildingsInk
        let r = w / 2
        arch(u, v, width: w + 3.2, height: h + 1.6, .colour(surround), line: 0.8)
        arch(u, v, width: w, height: h, .colour(paint), line: 0.9)
        // The fanlight: a half-round of glass over the transom.
        let spring = v + h - r
        let (f0, f1, f2, f3, f4) = (uv(u - r + 0.6, spring), uv(u + r - 0.6, spring), uv(u + r - 0.6, v + h - 0.6),
                                    uv(u, v + h - 0.6), uv(u - r + 0.6, v + h - 0.6))
        colour(.colour(I.glass)) { d, o in
            d.move(f0 + o); d.line(f1 + o); d.quad(f2 + o, f3 + o); d.quad(f4 + o, f0 + o); d.close()
        }
        var bars = PathData()
        for k in 1..<4 {
            let a = Double(k) * .pi / 4
            bars.move(uv(u, spring)); bars.line(uv(u - cos(a) * (r - 0.8), spring + sin(a) * (r - 0.9)))
        }
        svg.path(bars, stroke: .colour(I.light), width: 0.4)
        svg.line([uv(u - r, spring), uv(u + r, spring)], stroke: .colour(I.line), width: 0.6)
        // Four sunk panels, two over two.
        let pw = (w - 2.2) / 2
        for (a, b) in [(v + 1, v + (spring - v) * 0.42), (v + (spring - v) * 0.5, spring - 0.9)] where b - a > 1 {
            for s in [u - r + 0.8, u + 0.3] {
                colour(panel(s, a, s + pw - 0.2, b), .colour(I.line), opacity: 0.2)
                line(panel(s, a, s + pw - 0.2, b), closed: true, width: 0.35)
            }
        }
        svg.circle(uv(u + r * 0.6, v + (spring - v) * 0.46), 0.6, fill: .colour(I.brass), stroke: .colour(I.line), width: 0.3)
        // The step.
        shape(panel(u - r - 1.6, v - 0.2, u + r + 1.6, v + 0.9), .colour(I.stoneTop), width: 0.5)
    }

    // MARK: Chimneys, lamps and ironwork

    /// A chimney stack of brick on the map from (x0, y0) to (x1, y1), from
    /// `h0` to `h1` points up, capped in stone, with `pots` pots of clay
    /// standing on it in a row along x.
    mutating func chimneyStack(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double, to h1: Double,
                               pots: Int = 2) {
        typealias I = IndustrialOldBuildingsInk
        block(x0, y0, x1, y1, h0, h1, top: .colour(I.brickTop), left: .colour(I.brick), right: .colour(I.brickShade), width: 1)
        wall(.left, from: x0, y1, at: h0) { p in p.brickwork(0, (x1 - x0) * 32, 0, h1 - h0, course: 2.2, brick: 4.6, burnt: false) }
        wall(.right, from: x1, y1, at: h0) { p in p.brickwork(0, (y1 - y0) * 32, 0, h1 - h0, course: 2.2, brick: 4.6, burnt: false) }
        let o = 0.025
        block(x0 - o, y0 - o, x1 + o, y1 + o, h1, h1 + 1.6, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.8)
        colour(level(x0 + 0.02, y0 + 0.02, x1 - 0.02, y1 - 0.02, h1 + 1.6), .colour(I.soot), opacity: 0.6)
        let ym = (y0 + y1) / 2
        for k in 0..<pots {
            let x = x0 + (x1 - x0) * (Double(k) + 0.5) / Double(pots)
            let c = iso(x, ym, h1 + 1.6)
            let r = min(2.2, (x1 - x0) * 32 / Double(pots) * 0.32)
            colour([c + P(-r, 0), c + P(-r * 0.8, -5), c + P(r * 0.8, -5), c + P(r, 0)], .colour(I.clay))
            colour([c + P(r * 0.1, 0), c + P(r * 0.1, -5), c + P(r * 0.8, -5), c + P(r, 0)], .colour(I.clayShade))
            line([c + P(-r, 0), c + P(-r * 0.8, -5), c + P(r * 0.8, -5), c + P(r, 0)], width: 0.6)
            svg.ellipse(c + P(0, -5), r * 0.95, r * 0.42, fill: .colour(I.clay), stroke: .colour(I.line), width: 0.5)
            svg.ellipse(c + P(0, -5), r * 0.55, r * 0.24, fill: .colour(I.dark))
        }
    }

    /// A gas lamp of cast iron standing at `foot` on the screen, `height`
    /// points tall: a fluted post on a plinth, a cross-bar for the
    /// lamplighter's ladder, and a lantern of four panes alight.
    mutating func gasLamp(at foot: P, height: Double = 26) {
        typealias I = IndustrialOldBuildingsInk
        let top = foot - P(0, height)
        svg.ellipse(foot + P(1.4, 0.6), 3, 1.3, fill: .colour("#000000"), opacity: 0.16)
        shape([foot + P(-1.8, 0), foot + P(-1.8, -3), foot + P(1.8, -3), foot + P(1.8, 0)], .colour(I.iron), width: 0.6)
        shape([foot + P(-1.2, -3), foot + P(-0.7, -height + 6), foot + P(0.7, -height + 6), foot + P(1.2, -3)], .colour(I.iron),
              width: 0.6)
        svg.line([foot + P(-0.2, -3.4), top + P(-0.2, 6.4)], stroke: .colour(I.ironLight), width: 0.4)
        line([top + P(-3.4, 7.6), top + P(3.4, 7.6)], width: 0.9)
        // The lantern: a tapering glass of four panes under a cap and a finial.
        let lantern = [top + P(-1.4, 6), top + P(-2.8, 0.6), top + P(2.8, 0.6), top + P(1.4, 6)]
        colour(lantern, .colour(I.flame))
        colour([top + P(0.4, 6), top + P(0.8, 0.6), top + P(2.8, 0.6), top + P(1.4, 6)], .colour(I.brassLight), opacity: 0.7)
        line(lantern, closed: true, width: 0.6)
        line([top + P(0, 6), top + P(0, 0.6)], width: 0.35)
        shape([top + P(-3.6, 0.8), top + P(0, -2.4), top + P(3.6, 0.8)], .colour(I.iron), width: 0.6)
        svg.circle(top + P(0, -3.2), 0.8, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.4)
    }

    /// Cast-iron railings on the map from (x0, y0) to (x1, y1) on `h`,
    /// `height` points tall: a top and a bottom rail, bars between them every
    /// `step` points ending in spear points, and a stouter post at each end.
    mutating func railing(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, on h: Double, height: Double = 8,
                          step: Double = 2.2) {
        typealias I = IndustrialOldBuildingsInk
        let a = iso(x0, y0, h), b = iso(x1, y1, h)
        let d = b - a, length = (d.x * d.x + d.y * d.y).squareRoot()
        let count = max(1, Int(length / step))
        var bars = PathData(), points = PathData()
        for k in 0...count {
            let p = a + d * (Double(k) / Double(count))
            bars.move(p); bars.line(p - P(0, height))
            points.move(p - P(0.6, height - 0.4)); points.line(p - P(0, height + 1.4)); points.line(p - P(-0.6, height - 0.4))
        }
        svg.path(bars, stroke: .colour(I.line), width: 0.85)
        svg.path(points, stroke: .colour(I.line), width: 0.55)
        for v in [1.6, height - 1.4] {
            svg.line([a - P(0, v), b - P(0, v)], stroke: .colour(I.line), width: 1.3)
            svg.line([a - P(0, v), b - P(0, v)], stroke: .colour(I.ironLight), width: 0.4)
        }
        for p in [a, b] {
            shape([p + P(-1, 0.4), p + P(-1, -height - 1), p + P(1, -height - 1), p + P(1, 0.4)], .colour(I.iron), width: 0.55)
            svg.circle(p - P(0, height + 1.8), 1, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.4)
        }
    }

    /// A cast-iron column on a wall drawn with `wall` (or in front of one),
    /// centred on `u`, from `v0` to `v1`: a plinth, a slender shaft with its lit
    /// edge, and a flared capital.
    mutating func column(_ u: Double, _ v0: Double, _ v1: Double, w: Double = 2) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(u - w * 0.9, v0, u + w * 0.9, v0 + 2), .colour(I.iron), width: 0.5)
        shape(panel(u - w / 2, v0 + 2, u + w / 2, v1 - 2), .colour(I.iron), width: 0.5)
        svg.line([uv(u - w * 0.15, v0 + 2.4), uv(u - w * 0.15, v1 - 2.4)], stroke: .colour(I.ironLight), width: 0.4)
        shape([uv(u - w / 2, v1 - 2), uv(u - w * 1.1, v1), uv(u + w * 1.1, v1), uv(u + w / 2, v1 - 2)], .colour(I.iron), width: 0.5)
    }

    /// A drainpipe of cast iron down a wall drawn with `wall` at `u`, from
    /// `v1` to the ground, with a hopper head at its top.
    mutating func drainpipe(_ u: Double, from v1: Double) {
        typealias I = IndustrialOldBuildingsInk
        svg.line([uv(u, 0.4), uv(u, v1 - 1)], stroke: .colour(I.line), width: 1.5)
        svg.line([uv(u, 0.4), uv(u, v1 - 1)], stroke: .colour(I.iron), width: 0.7)
        shape([uv(u - 1.4, v1), uv(u + 1.4, v1), uv(u + 0.8, v1 - 2), uv(u - 0.8, v1 - 2)], .colour(I.iron), width: 0.45)
    }

    // MARK: Battlements

    /// A merlon of stone standing on the map at (x, y) on `h`, `s` tiles
    /// square and `height` points tall.
    mutating func merlon(_ x: Double, _ y: Double, s: Double, on h: Double, height: Double, raw: Bool = false) {
        typealias I = IndustrialOldBuildingsInk
        block(x - s / 2, y - s / 2, x + s / 2, y + s / 2, h, h + height, top: .colour(raw ? I.rawStoneTop : I.stoneTop),
              left: .colour(raw ? I.rawStone : I.stone), right: .colour(raw ? I.rawStoneShade : I.stoneShade), width: 0.8)
    }

    /// Battlements round the top of a block from (x0, y0) to (x1, y1) at `h`:
    /// merlons along each edge, `count` to a side, the farther ones first, so
    /// that the nearer hide them.
    mutating func battlements(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, on h: Double, count: Int,
                              height: Double = 5, front: Bool) {
        let s = min(x1 - x0, y1 - y0) / (Double(count) * 2 - 1)
        var places: [(Double, Double)] = []
        for k in 0..<count {
            let t = Double(k) / Double(count - 1)
            let x = x0 + s / 2 + (x1 - x0 - s) * t, y = y0 + s / 2 + (y1 - y0 - s) * t
            if front {
                places.append((x, y1 - s / 2)); places.append((x1 - s / 2, y))
            } else {
                places.append((x, y0 + s / 2)); places.append((x0 + s / 2, y))
            }
        }
        var seen: [(Double, Double)] = []
        for p in places.sorted(by: { ($0.0 + $0.1, $0.0) < ($1.0 + $1.1, $1.0) })
        where !seen.contains(where: { abs($0.0 - p.0) < 0.001 && abs($0.1 - p.1) < 0.001 }) {
            seen.append(p)
            merlon(p.0, p.1, s: s, on: h, height: height)
        }
    }

    // MARK: Team colour

    /// The Industrial age's charge on the owner's colour, in the light
    /// colour: a cogwheel of eight teeth round a hub.
    mutating func cog(at p: P, radius r: Double) {
        typealias I = IndustrialOldBuildingsInk
        var teeth = PathData()
        for k in 0..<8 {
            let a = Double(k) * .pi / 4
            let dir = P(sin(a), -cos(a))
            teeth.move(p + dir * (r * 0.9)); teeth.line(p + dir * (r * 1.45))
        }
        svg.path(teeth, stroke: .colour(I.light), width: max(0.6, r * 0.5))
        svg.circle(p, r, fill: .none, stroke: .colour(I.light), width: max(0.5, r * 0.42))
        svg.circle(p, max(0.3, r * 0.24), fill: .colour(I.light))
    }

    /// A band of the owner's colour along a wall drawn with `wall`, from `u0`
    /// to `u1`, between `v0` and `v1`, edged with the light colour so that
    /// every team's colour stands clear of the brick and stone around it.
    mutating func paintedBand(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double) {
        typealias I = IndustrialOldBuildingsInk
        colour(panel(u0, v0 - 0.9, u1, v1 + 0.9), .colour(I.light))
        colour(panel(u0, v0, u1, v1), .team)
        for v in [v0 - 0.9, v0, v1, v1 + 0.9] { line([uv(u0, v), uv(u1, v)], width: v == v0 || v == v1 ? 0.55 : 0.6) }
    }

    /// A banner of the owner's colour hanging on a wall drawn with `wall` from
    /// an iron rod at `top`, centred on `u`, `width` wide and `length` long,
    /// its foot cut in three points, edged in the light colour and charged
    /// with the cog.
    mutating func banner(_ u: Double, top v: Double, width: Double, length: Double) {
        typealias I = IndustrialOldBuildingsInk
        let r = width / 2
        let outline = [uv(u - r, v), uv(u + r, v), uv(u + r, v - length), uv(u + r * 0.5, v - length + 2.2), uv(u, v - length),
                       uv(u - r * 0.5, v - length + 2.2), uv(u - r, v - length)]
        let rim = [uv(u - r - 1, v), uv(u + r + 1, v), uv(u + r + 1, v - length - 1.2), uv(u + r * 0.5, v - length + 1.2),
                   uv(u, v - length - 1.2), uv(u - r * 0.5, v - length + 1.2), uv(u - r - 1, v - length - 1.2)]
        shape(rim, .colour(I.light), width: 0.6)
        shape(outline, .team, width: 0.7)
        cog(at: uv(u, v - length * 0.42), radius: width * 0.16)
        line([uv(u - r - 1.6, v), uv(u + r + 1.6, v)], width: 1.4)
        for s in [-1.0, 1.0] { svg.circle(uv(u + s * (r + 1.6), v), 0.7, fill: .colour(I.ironDark)) }
    }

    /// A flagpole of iron standing at `foot` on the screen, `height` points
    /// tall, with a swallow-tailed pennant of the owner's colour streaming
    /// to the right from its top, `length` points long, edged in the light
    /// colour and charged with the cog.
    mutating func pennant(at foot: P, height: Double, length: Double = 15) {
        typealias I = IndustrialOldBuildingsInk
        let top = foot - P(0, height)
        let k = length / 15
        func cloth(_ o: P) -> PathData {
            var d = PathData()
            d.move(top + P(0.6, 1.2) + o)
            d.quad(top + P(7 * k, -0.8 * k) + o, top + P(15 * k, 2 * k) + o)
            d.line(top + P(10.5 * k, 5.2 * k) + o)
            d.line(top + P(15 * k, 8.6 * k) + o)
            d.quad(top + P(7 * k, 9.6 * k) + o, top + P(0.6, 9.6 * k) + o)
            d.close()
            return d
        }
        svg.path(cloth(shift), stroke: .colour(I.light), width: 2.6)
        colour(.team) { d, o in d = cloth(o) }
        cog(at: top + P(5.2 * k, 5 * k), radius: 1.4 * k)
        line(width: 0.8) { d in d = cloth(P(0, 0)) }
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.line), width: 2.1)
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.ironLight), width: 0.9)
        svg.circle(top - P(0, 1.6), 1.1, fill: .colour(I.brass), stroke: .colour(I.line), width: 0.5)
    }

    /// A shield hung on a wall drawn with `wall`, centred on (`u`, `v`), `w`
    /// wide and `h` tall: its field of the owner's colour under a light
    /// chevron, edged with the light colour and iron.
    mutating func shield(_ u: Double, _ v: Double, w: Double, h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let c = uv(u, v), r = w / 2
        func trace(_ o: P, _ inset: Double) -> PathData {
            var d = PathData()
            d.move(c + P(-r + inset, -h / 2 + inset) + o)
            d.line(c + P(r - inset, -h / 2 + inset) + o)
            d.line(c + P(r - inset, h * 0.05) + o)
            d.quad(c + P(r - inset, h * 0.36) + o, c + P(0, h / 2 - inset) + o)
            d.quad(c + P(-r + inset, h * 0.36) + o, c + P(-r + inset, h * 0.05) + o)
            d.close()
            return d
        }
        colour(.colour(I.light)) { d, o in d = trace(o, 0) }
        svg.path(trace(shift * 0.5, 0.9), fill: .team)
        svg.polygon([c + P(-r + 1, -h * 0.02), c + P(0, -h * 0.3), c + P(r - 1, -h * 0.02), c + P(r - 1, h * 0.14),
                     c + P(0, -h * 0.14), c + P(-r + 1, h * 0.14)], fill: .colour(I.light))
        line(width: 0.75) { d in d = trace(P(0, 0), 0) }
    }
}

extension IndustrialOldBuildingsPainter {
    // MARK: Arched openings

    /// A round-headed window on a wall drawn with `wall`, centred on `u` and
    /// standing on `v`, `w` wide and `h` tall to its crown: glass in a frame
    /// of the light colour, with a glazing bar, a transom at the springing and
    /// bars radiating in the head, under an archivolt of `surround` with a
    /// keystone, over a stone sill.
    mutating func archedWindow(_ u: Double, _ v: Double, w: Double, h: Double,
                               surround: String = IndustrialOldBuildingsInk.stoneTop) {
        typealias I = IndustrialOldBuildingsInk
        let r = w / 2, spring = v + h - r
        arch(u, v, width: w + 3, height: h + 1.5, .colour(surround), line: 0.6)
        arch(u, v, width: w, height: h, .colour(I.light), line: 0.6)
        arch(u, v + 0.5, width: w - 1.2, height: h - 1.1, .colour(I.glass), line: 0.4)
        // The sky caught in the glass.
        colour([uv(u - r + 0.6, v + (spring - v) * 0.3), uv(u + r * 0.2, spring + r * 0.6), uv(u - r + 0.6, spring + r * 0.4)],
               .colour(I.glassLight), opacity: 0.7)
        var bars = PathData()
        bars.move(uv(u, v + 0.5)); bars.line(uv(u, spring))
        bars.move(uv(u - r, spring)); bars.line(uv(u + r, spring))
        bars.move(uv(u - r, v + (spring - v) * 0.5)); bars.line(uv(u + r, v + (spring - v) * 0.5))
        for k in 1..<4 {
            let a = Double(k) * .pi / 4
            bars.move(uv(u, spring)); bars.line(uv(u - cos(a) * (r - 0.6), spring + sin(a) * (r - 0.6)))
        }
        svg.path(bars, stroke: .colour(I.light), width: 0.6)
        line([uv(u - r, spring), uv(u + r, spring)], width: 0.3, opacity: 0.6)
        shape(panel(u - 0.9, v + h - 0.4, u + 0.9, v + h + 1.9), .colour(I.stoneTop), width: 0.45)
        shape(panel(u - r - 1.8, v - 1.4, u + r + 1.8, v - 0.1), .colour(I.stoneTop), width: 0.5)
    }

    /// A pair of tall doors on a wall drawn with `wall` under a round head,
    /// centred on `u` and standing on `v`, `w` wide and `h` tall: planked,
    /// painted `paint`, with iron straps, and a fanlight in the head, in an
    /// archway of `surround` with a keystone. A cart or a horse passes through.
    mutating func archedDoors(_ u: Double, _ v: Double, w: Double, h: Double, paint: String = IndustrialOldBuildingsInk.green,
                              surround: String = IndustrialOldBuildingsInk.stoneTop, open: Bool = false) {
        typealias I = IndustrialOldBuildingsInk
        let r = w / 2, spring = v + h - r
        arch(u, v, width: w + 3.4, height: h + 1.7, .colour(surround), line: 0.7)
        arch(u, v, width: w, height: h, .colour(open ? I.dark : paint), line: 0.9)
        if !open {
            var planks = PathData()
            var x = u - r + 1.6
            while x < u + r - 0.8 {
                if abs(x - u) > 0.4 { planks.move(uv(x, v + 0.4)); planks.line(uv(x, spring - 0.2)) }
                x += 1.6
            }
            svg.path(planks, stroke: .colour(I.line), width: 0.35, opacity: 0.5)
            line([uv(u, v + 0.2), uv(u, spring)], width: 0.6)
            for vv in [v + (spring - v) * 0.2, v + (spring - v) * 0.75] {
                for s in [-1.0, 1.0] {
                    shape(panel(u + s * 0.8, vv - 0.4, u + s * (r - 0.6), vv + 0.4).map { $0 }, .colour(I.ironDark), width: 0.3)
                }
            }
        }
        // The fanlight in the head.
        let (f0, f1, f2, f3, f4) = (uv(u - r + 0.6, spring), uv(u + r - 0.6, spring), uv(u + r - 0.6, v + h - 0.6),
                                    uv(u, v + h - 0.6), uv(u - r + 0.6, v + h - 0.6))
        colour(.colour(open ? I.dark : I.glass)) { d, o in
            d.move(f0 + o); d.line(f1 + o); d.quad(f2 + o, f3 + o); d.quad(f4 + o, f0 + o); d.close()
        }
        if !open {
            var bars = PathData()
            for k in 1..<4 {
                let a = Double(k) * .pi / 4
                bars.move(uv(u, spring)); bars.line(uv(u - cos(a) * (r - 0.8), spring + sin(a) * (r - 0.9)))
            }
            svg.path(bars, stroke: .colour(I.light), width: 0.45)
        }
        svg.line([uv(u - r, spring), uv(u + r, spring)], stroke: .colour(I.line), width: 0.7)
        shape(panel(u - 1, v + h - 0.4, u + 1, v + h + 2.1), .colour(I.stoneTop), width: 0.45)
    }

    /// A cornice of dressed stone round the top of a block from (x0, y0) to
    /// (x1, y1) at `h`, `depth` points deep, standing out `out` tiles.
    mutating func cornice(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, at h: Double, depth: Double = 2.2,
                          out: Double = 0.03) {
        typealias I = IndustrialOldBuildingsInk
        block(x0 - out, y0 - out, x1 + out, y1 + out, h - depth, h, top: .colour(I.stoneTop), left: .colour(I.stoneTop),
              right: .colour(I.stone), width: 0.8)
        // The dentils' shadow under it.
        shadow([iso(x0, y1, h - depth - 1.2), iso(x1, y1, h - depth - 1.2), iso(x1, y1, h - depth), iso(x0, y1, h - depth)],
               opacity: 0.1)
        shadow([iso(x1, y1, h - depth - 1.2), iso(x1, y0, h - depth - 1.2), iso(x1, y0, h - depth), iso(x1, y1, h - depth)],
               opacity: 0.14)
    }
}

extension IndustrialOldBuildingsPainter {
    /// Brickwork in a gable drawn with `wall` (as `gableAlongX` and
    /// `gableAlongY` give it), `w` wide at its foot and `rise` tall: courses
    /// and staggered joints, each cut to the triangle.
    mutating func gableBrickwork(_ w: Double, _ rise: Double, course: Double = 2.5, brick: Double = 6) {
        typealias I = IndustrialOldBuildingsInk
        var d = PathData()
        var v = course, row = 1
        func span(_ v: Double) -> (Double, Double) { (v / rise * w / 2 + 0.6, w - v / rise * w / 2 - 0.6) }
        while v < rise - 1.5 {
            let (a, b) = span(v)
            if b > a { d.move(uv(a, v)); d.line(uv(b, v)) }
            let (c0, c1) = span(v + course)
            var u = (row % 2 == 0 ? brick / 2 : brick)
            while u < w {
                if u > c0 && u < c1 { d.move(uv(u, v + 0.2)); d.line(uv(u, v + course - 0.2)) }
                u += brick
            }
            v += course
            row += 1
        }
        svg.path(d, stroke: .colour(I.line), width: 0.35, opacity: 0.3)
    }
}
