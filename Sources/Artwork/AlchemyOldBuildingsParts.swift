// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The parts the Alchemy age adds to the older buildings: steep roofs of
// slate, hipped or gabled, with gilt finials and weathervanes; walls
// half-timbered in dark oak over plaster; windows glazed in leaded panes;
// doors of painted plank hung on iron; a clock; battlements; and the banners,
// pennants and painted bands that carry the owner's colour, charged with the
// alchemist's sign of the sun in the light colour.

extension AlchemyOldBuildingsPainter {
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
        typealias I = AlchemyOldBuildingsInk
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
    /// slates over a board of oak.
    mutating func eaveEdge(_ a: P, _ b: P) {
        typealias I = AlchemyOldBuildingsInk
        let drop = P(0, 1.6)
        shape([a, b, b + drop, a + drop], .colour(I.slateDark), width: 0.7)
        shape([a + drop, b + drop, b + drop * 1.9, a + drop * 1.9], .colour(I.oak), width: 0.6)
    }

    /// A steep hipped roof of slate over the block from (x0, y0) to (x1, y1),
    /// overhanging it by `overhang` tiles, its eaves at `h` points and its
    /// ridge `rise` points above them (by default as steep as the age builds);
    /// a square block takes a pyramid. A gilt finial stands at each end of the
    /// ridge, or at the apex, when `finials`. Returns the height of the ridge.
    @discardableResult
    mutating func hippedRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eaves h: Double, rise: Double? = nil,
                             overhang o: Double = 0.07, finials: Bool = true) -> Double {
        typealias I = AlchemyOldBuildingsInk
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
    /// given the wall's width and the ridge's height above the eaves. A gilt
    /// finial stands on the gable's apex when `finials`.
    mutating func gableAlongX(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double,
                              over: Double = 0.08, gableWall: Paint, finials: Bool = true,
                              gable: (inout AlchemyOldBuildingsPainter, Double, Double) -> Void = { _, _, _ in }) {
        typealias I = AlchemyOldBuildingsInk
        let ym = (y0 + y1) / 2
        let (a0, a1, b0, b1) = (x0 - over, x1 + over, y0 - over, y1 + over)
        let drop = (ridge - eave) * over / (ym - y0)
        colour([iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a0, b0, eave - drop)], .colour(I.slateShade))
        let triangle = [iso(x1, y1, eave), iso(x1, y0, eave), iso(x1, ym, ridge)]
        colour(triangle, gableWall)
        wall(.right, from: x1, y1, at: eave) { p in gable(&p, (y1 - y0) * 32, ridge - eave) }
        line(triangle, closed: true, width: 0.9)
        // The verge: the slates' edge over a bargeboard of oak.
        let edge = P(0, 2.2)
        colour([iso(a1, b1, eave - drop), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a1, b0, eave - drop) + edge,
                iso(a1, ym, ridge) + edge, iso(a1, b1, eave - drop) + edge], .colour(I.oak))
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
    /// gilt finial stands on the gable's apex when `finials`.
    mutating func gableAlongY(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double,
                              over: Double = 0.08, gableWall: Paint, finials: Bool = true,
                              gable: (inout AlchemyOldBuildingsPainter, Double, Double) -> Void = { _, _, _ in }) {
        typealias I = AlchemyOldBuildingsInk
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
        // The verge over the gable: the slates' edge on a bargeboard of oak.
        let edge = P(0, 2.2)
        let rake = [iso(a0, b1, eave - drop), iso(xm, b1, ridge), iso(a1, b1, eave - drop)]
        colour([rake[0], rake[1], rake[2], rake[2] + edge, rake[1] + edge, rake[0] + edge], .colour(I.oak))
        line([rake[0], rake[1], rake[2], rake[2] + edge, rake[1] + edge, rake[0] + edge], closed: true, width: 0.9)
        svg.line([iso(xm, b0, ridge), iso(xm, b1, ridge)], stroke: .colour(I.line), width: 2.8)
        svg.line([iso(xm, b0, ridge), iso(xm, b1, ridge)], stroke: .colour(I.ironLight), width: 1.3)
        if finials {
            finial(at: iso(xm, b1, ridge), size: 1)
        }
    }

    // MARK: Gilt

    /// A gilt finial standing at `p` on the screen: a short spike through a ball.
    mutating func finial(at p: P, size s: Double = 1) {
        typealias I = AlchemyOldBuildingsInk
        svg.line([p + P(0, 0.6), p - P(0, 6.4 * s)], stroke: .colour(I.line), width: 1.4 * s)
        svg.line([p, p - P(0, 6 * s)], stroke: .colour(I.giltShade), width: 0.6 * s)
        svg.circle(p - P(0, 3.2 * s), 1.6 * s, fill: .colour(I.gilt), stroke: .colour(I.line), width: 0.5)
        svg.circle(p - P(0.5 * s, 3.7 * s), 0.55 * s, fill: .colour(I.giltLight))
    }

    /// A weathervane standing at `p` on the screen, `height` points tall: an
    /// iron rod, a gilt ball, the arms of the four quarters, and a gilt vane
    /// of an arrow with a pennon for its tail.
    mutating func weathervane(at p: P, height: Double) {
        typealias I = AlchemyOldBuildingsInk
        let top = p - P(0, height)
        svg.line([p, top], stroke: .colour(I.line), width: 1.3)
        svg.line([p, top], stroke: .colour(I.ironLight), width: 0.5)
        let ball = p - P(0, height * 0.3)
        svg.circle(ball, 1.9, fill: .colour(I.gilt), stroke: .colour(I.line), width: 0.5)
        svg.circle(ball + P(-0.6, -0.6), 0.6, fill: .colour(I.giltLight))
        // The arms, seen at the angle of the map.
        let arms = p - P(0, height * 0.55)
        line([arms + P(-4.4, 2.2), arms + P(4.4, -2.2)], width: 0.6)
        line([arms + P(-4.4, -2.2), arms + P(4.4, 2.2)], width: 0.6)
        // The vane: a pennon behind, an arrowhead before.
        let v = top + P(0, 3)
        let vane = [v + P(-8, -2.8), v + P(-1, -1.4), v + P(5, -1.1), v + P(5, 1.1), v + P(-1, 1.4), v + P(-8, 2.8), v + P(-6, 0)]
        shape(vane, .colour(I.giltLight), width: 0.6)
        shape([v + P(5, -2.4), v + P(9, 0), v + P(5, 2.4)], .colour(I.giltLight), width: 0.6)
        svg.circle(top, 0.8, fill: .colour(I.gilt), stroke: .colour(I.line), width: 0.4)
    }

    /// A clock's face on a wall drawn with `wall`, centred on (`u`, `v`),
    /// `r` points across its ring: a ring of gilt round a light dial, its hours
    /// marked, its hands at ten o'clock.
    mutating func clock(_ u: Double, _ v: Double, radius r: Double) {
        typealias I = AlchemyOldBuildingsInk
        let c = uv(u, v)
        svg.circle(c + shift * 0.6, r, fill: .colour(I.gilt))
        svg.circle(c, r, fill: .none, stroke: .colour(I.line), width: 0.8)
        svg.circle(c, r * 0.76, fill: .colour(I.light), stroke: .colour(I.line), width: 0.6)
        var ticks = PathData()
        for k in 0..<12 {
            let a = Double(k) * .pi / 6
            let dir = P(sin(a), -cos(a))
            ticks.move(c + dir * (r * 0.62)); ticks.line(c + dir * (r * (k % 3 == 0 ? 0.44 : 0.54)))
        }
        svg.path(ticks, stroke: .colour(I.line), width: k3Width(r))
        // The hour hand toward ten, the minute hand toward twelve.
        let hour = P(sin(-.pi / 3), -cos(-.pi / 3))
        svg.line([c, c + hour * (r * 0.42)], stroke: .colour(I.line), width: max(0.7, r * 0.14))
        svg.line([c, c + P(0, -r * 0.6)], stroke: .colour(I.line), width: max(0.5, r * 0.09))
        svg.circle(c, max(0.5, r * 0.12), fill: .colour(I.giltShade))
    }

    private func k3Width(_ r: Double) -> Double { max(0.4, r * 0.08) }

    // MARK: Windows and doors

    /// Lead cames in a diamond lattice across the light from (u0, v0) to (u1, v1).
    private mutating func lattice(_ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double, pitch: Double = 1.8) {
        typealias I = AlchemyOldBuildingsInk
        var d = PathData()
        // Lines rising at two in one, either way, clipped to the light.
        for direction in [1.0, -1.0] {
            var c = -(v1 - v0) / 2 - (u1 - u0)
            while c < (u1 - u0) + (v1 - v0) {
                // The line u = u0 + c + direction * (v - v0) / 2, for v from v0 to v1, clipped to u0...u1.
                var a: (Double, Double)?, b: (Double, Double)?
                let steps = 24
                for i in 0...steps {
                    let v = v0 + (v1 - v0) * Double(i) / Double(steps)
                    let u = (direction > 0 ? u0 : u1) + direction * (c + (v - v0) / 2)
                    if u >= u0 - 0.001 && u <= u1 + 0.001 {
                        if a == nil { a = (u, v) }
                        b = (u, v)
                    }
                }
                if let a, let b, a != b { d.move(uv(a.0, a.1)); d.line(uv(b.0, b.1)) }
                c += pitch
            }
        }
        svg.path(d, stroke: .colour(I.glassDark), width: 0.35, opacity: 0.9)
    }

    /// A window glazed in leaded panes on a wall drawn with `wall`: its foot at
    /// (`u`, `v`), `w` wide and `h` tall, divided by `lights` into lights by
    /// mullions, in a frame of `frame` (oak in a timbered wall, stone in a
    /// stone one) on a sill.
    mutating func casement(_ u: Double, _ v: Double, w: Double, h: Double, lights: Int = 2,
                           frame: String = AlchemyOldBuildingsInk.oak) {
        typealias I = AlchemyOldBuildingsInk
        shape(panel(u - 1, v - 0.4, u + w + 1, v + h + 1), .colour(frame), width: 0.6)
        let gap = 0.9, each = (w - gap * Double(lights - 1)) / Double(lights)
        for k in 0..<lights {
            let a = u + Double(k) * (each + gap)
            colour(panel(a, v, a + each, v + h), .colour(I.glass))
            // The sky caught in the upper part of the glass.
            colour([uv(a, v + h * 0.45), uv(a + each * 0.55, v + h), uv(a, v + h)], .colour(I.glassLight), opacity: 0.8)
            lattice(a, v, a + each, v + h)
            line(panel(a, v, a + each, v + h), closed: true, width: 0.5)
        }
        shape(panel(u - 1.6, v - 1.3, u + w + 1.6, v - 0.2), .colour(frame == I.oak ? I.oakLight : I.stoneTop), width: 0.55)
    }

    /// A door of planks painted `paint`, hung on iron straps, centred on `u`
    /// and standing on `v` on a wall drawn with `wall`, `w` wide and `h` tall
    /// to the crown of its round head, in a surround of `surround`.
    mutating func door(_ u: Double, _ v: Double, w: Double, h: Double, paint: String = AlchemyOldBuildingsInk.teal,
                       surround: String = AlchemyOldBuildingsInk.stoneTop) {
        typealias I = AlchemyOldBuildingsInk
        let r = w / 2
        arch(u, v, width: w + 3, height: h + 1.5, .colour(surround), line: 0.8)
        arch(u, v, width: w, height: h, .colour(paint), line: 0.9)
        var planks = PathData()
        for k in 1..<max(2, Int(w / 2.4)) {
            let x = u - r + w * Double(k) / Double(max(2, Int(w / 2.4)))
            planks.move(uv(x, v + 0.3)); planks.line(uv(x, v + h - r * 0.4))
        }
        svg.path(planks, stroke: .colour(I.line), width: 0.4, opacity: 0.6)
        for vv in [v + h * 0.22, v + h * 0.62] {
            shape(panel(u - r + 0.3, vv - 0.45, u + r * 0.3, vv + 0.45), .colour(I.iron), width: 0.4)
        }
        svg.circle(uv(u + r * 0.55, v + h * 0.42), 0.8, fill: .none, stroke: .colour(I.ironDark), width: 0.45)
    }

    // MARK: Half-timbering

    /// The frame of a half-timbered wall drawn with `wall`, `length` long from
    /// `v0` to `v1`: a sill and a plate, posts at `posts`, a rail at `rail`
    /// between them, and a brace rising from the sill to each post's head in
    /// the bays named by `braces` (by the index of the post to their left,
    /// and whether they lean right). Panels of plaster fill the rest.
    mutating func framing(_ length: Double, from v0: Double, to v1: Double, posts: [Double], rail: Double? = nil,
                          braces: [(Int, Bool)] = []) {
        let t = 2.0
        if let rail {
            for (a, b) in zip(posts, posts.dropFirst()) { timber(uv(a, rail), uv(b, rail), width: t * 0.85) }
        }
        for (i, right) in braces where i + 1 < posts.count {
            let a = posts[i], b = posts[i + 1]
            let top = rail ?? v1
            if right { timber(uv(a + 1, v0 + 0.6), uv(b - 0.6, top - 0.8), width: t * 0.85) } else {
                timber(uv(b - 1, v0 + 0.6), uv(a + 0.6, top - 0.8), width: t * 0.85)
            }
        }
        for u in posts { timber(uv(u, v0), uv(u, v1), width: t) }
        timber(uv(0, v0 + t / 2), uv(length, v0 + t / 2), width: t)
        timber(uv(0, v1 - t / 2), uv(length, v1 - t / 2), width: t)
    }

    /// Close studding: upright timbers every `step` from `u0` to `u1`, from
    /// `v0` to `v1`, the plaster showing between them in narrow panels.
    mutating func studs(_ u0: Double, _ u1: Double, from v0: Double, to v1: Double, step: Double = 4.2) {
        var u = u0
        while u <= u1 + 0.01 {
            timber(uv(u, v0), uv(u, v1), width: 1.5)
            u += step
        }
    }

    // MARK: Battlements

    /// A merlon of stone standing on the map at (x, y) on `h`, `s` tiles
    /// square and `height` points tall.
    mutating func merlon(_ x: Double, _ y: Double, s: Double, on h: Double, height: Double, raw: Bool = false) {
        typealias I = AlchemyOldBuildingsInk
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

    /// The alchemist's sign of the sun, the owner's charge, at `p` in the
    /// light colour: a ring round a point, with short rays.
    mutating func sun(at p: P, radius r: Double) {
        typealias I = AlchemyOldBuildingsInk
        svg.circle(p, r, fill: .none, stroke: .colour(I.light), width: max(0.45, r * 0.3))
        svg.circle(p, max(0.35, r * 0.28), fill: .colour(I.light))
        var rays = PathData()
        for k in 0..<8 {
            let a = Double(k) * .pi / 4
            let dir = P(sin(a), -cos(a))
            rays.move(p + dir * (r * 1.4)); rays.line(p + dir * (r * 1.85))
        }
        svg.path(rays, stroke: .colour(I.light), width: max(0.4, r * 0.24))
    }

    /// A band of the owner's colour along a wall drawn with `wall`, from `u0`
    /// to `u1`, between `v0` and `v1`, edged with plaster so that every team's
    /// colour stands clear of the timber and stone around it.
    mutating func paintedBand(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double) {
        typealias I = AlchemyOldBuildingsInk
        colour(panel(u0, v0 - 0.9, u1, v1 + 0.9), .colour(I.light))
        colour(panel(u0, v0, u1, v1), .team)
        for v in [v0 - 0.9, v0, v1, v1 + 0.9] { line([uv(u0, v), uv(u1, v)], width: v == v0 || v == v1 ? 0.55 : 0.6) }
    }

    /// A banner of the owner's colour hanging on a wall drawn with `wall` from
    /// a rod at `top`, centred on `u`, `width` wide and `length` long, its foot
    /// cut in three points, charged with the sun.
    mutating func banner(_ u: Double, top v: Double, width: Double, length: Double) {
        typealias I = AlchemyOldBuildingsInk
        let r = width / 2
        let outline = [uv(u - r, v), uv(u + r, v), uv(u + r, v - length), uv(u + r * 0.5, v - length + 2.2), uv(u, v - length),
                       uv(u - r * 0.5, v - length + 2.2), uv(u - r, v - length)]
        shape(outline, .team, width: 0.9)
        sun(at: uv(u, v - length * 0.42), radius: width * 0.16)
        // The rod, with an iron knob at each end.
        line([uv(u - r - 1.4, v), uv(u + r + 1.4, v)], width: 1.4)
        for s in [-1.0, 1.0] { svg.circle(uv(u + s * (r + 1.4), v), 0.7, fill: .colour(I.ironDark)) }
    }

    /// A pole standing at `foot` on the screen, `height` points tall, with a
    /// swallow-tailed pennant of the owner's colour streaming to the right
    /// from its top, `length` points long, charged with the sun.
    mutating func pennant(at foot: P, height: Double, length: Double = 15) {
        typealias I = AlchemyOldBuildingsInk
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
        colour(.team) { d, o in d = cloth(o) }
        sun(at: top + P(5.2 * k, 5 * k), radius: 1.5 * k)
        line(width: 0.9) { d in d = cloth(P(0, 0)) }
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.line), width: 2.3)
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.oakLight), width: 1.2)
        svg.circle(top - P(0, 1.6), 1.1, fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.5)
    }

    /// A heater shield hung on a wall drawn with `wall`, centred on (`u`,
    /// `v`), `w` wide and `h` tall: its field of the owner's colour under a
    /// light chevron, edged with iron.
    mutating func shield(_ u: Double, _ v: Double, w: Double, h: Double) {
        typealias I = AlchemyOldBuildingsInk
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
        colour(.colour(I.iron)) { d, o in d = trace(o, 0) }
        svg.path(trace(shift * 0.5, 0.7), fill: .team)
        // The chevron, in the light colour.
        svg.polygon([c + P(-r + 0.8, -h * 0.02), c + P(0, -h * 0.3), c + P(r - 0.8, -h * 0.02), c + P(r - 0.8, h * 0.14),
                     c + P(0, -h * 0.14), c + P(-r + 0.8, h * 0.14)], fill: .colour(I.light))
        line(width: 0.75) { d in d = trace(P(0, 0), 0) }
    }
}
