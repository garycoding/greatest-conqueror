// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The drawing kit of the Bronze-age buildings: the palette, the projection of a
// footprint onto the screen, and the parts the buildings are made of. Units are
// points of the screen at zoom 1, y downward, with the origin on the ground at
// the centre of the footprint; a sprite is drawn at two pixels a point.

/// The Bronze age's palette (docs/art-style.md, "Palettes"): sand, terracotta,
/// verdigris and the light, with the line every age shares, and the shades of
/// them that brick, plaster, timber and bronze need.
enum BronzeBuildingsInk {
    static let line = "#2a2420"
    /// Sun-dried mud brick, the ground's sand: its top, its lit wall, its shaded wall.
    static let sand = "#d9b46c"
    static let sandTop = "#e4c483"
    static let sandShade = "#b8924f"
    /// Fired brick and painted bands.
    static let terracotta = "#c2683c"
    static let terracottaTop = "#d07c4e"
    static let terracottaShade = "#a0532d"
    /// A paler clay, for a second course of brick.
    static let clay = "#d9905f"
    static let clayShade = "#b56d42"
    static let verdigris = "#2f6b6b"
    static let verdigrisLight = "#4b8681"
    /// Lime plaster, the light colour: its top, its lit wall, its shaded wall.
    static let light = "#efe0c2"
    static let plasterTop = "#f5ead2"
    static let plasterShade = "#d8c49d"
    /// A paved court or a beaten floor.
    static let paving = "#e6cf9c"
    static let pavingShade = "#cdb27a"
    /// Beaten earth: a yard, a bank, the floor of a pen.
    static let earth = "#c9a663"
    static let earthShade = "#a5834a"
    /// Fresh mud brick, not yet plastered: walls being raised.
    static let rawBrick = "#cf9a5c"
    static let rawBrickTop = "#dcad74"
    static let rawBrickShade = "#a7743e"
    static let timber = "#8a5a33"
    static let timberLight = "#a8743f"
    static let timberDark = "#6b4a2a"
    static let reed = "#cda85e"
    static let reedShade = "#a9863f"
    /// Cast bronze: fittings, studs, a gong.
    static let bronze = "#b47b36"
    static let bronzeLight = "#dba75c"
    static let bronzeShade = "#8a5c26"
    static let stone = "#b8b0a0"
    static let stoneTop = "#d0c9b9"
    static let stoneShade = "#958c7c"
    /// A doorway's or a pit's dark.
    static let dark = "#3d3029"
}

/// A wall of a block that faces the viewer: the one facing +y (on the screen's
/// lower left) or the one facing +x (on its lower right).
enum BronzeBuildingsSide: Sendable {
    case left, right

    /// How far the wall's foot falls for each point it runs to the right.
    var slope: Double { self == .left ? 0.5 : -0.5 }
}

/// Draws one layer of a building: its picture or its team-colour mask.
struct BronzeBuildingsPainter {
    var svg: SVG
    /// The colour's offset from its line in the current frame of drawing.
    private var shift: P

    /// How far a field of colour sits from its line on the screen, in points:
    /// the slight misregistration of the style (docs/art-style.md).
    static let register = P(-1.0, 0.7)

    init(layer: Layer) {
        svg = SVG(layer: layer)
        shift = Self.register
    }

    // MARK: The projection

    /// The screen point of a place: `x` and `y` in tiles from the footprint's
    /// centre along the map's axes, `h` in points above the ground.
    func iso(_ x: Double, _ y: Double, _ h: Double = 0) -> P {
        P((x - y) * 32, (x + y) * 16 - h)
    }

    /// The four corners of a level rectangle of the map at height `h`, from the
    /// back corner round by the right.
    func level(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ h: Double = 0) -> [P] {
        [iso(x0, y0, h), iso(x1, y0, h), iso(x1, y1, h), iso(x0, y1, h)]
    }

    // MARK: Colour and line

    /// A flat field of colour, a little out of register with its line.
    mutating func colour(_ points: [P], _ paint: Paint, opacity: Double = 1) {
        svg.polygon(points.map { $0 + shift }, fill: paint, opacity: opacity)
    }

    /// A field of colour bounded by path data written by `trace`, which is given
    /// the offset to add to every point.
    mutating func colour(_ paint: Paint, opacity: Double = 1, _ trace: (inout PathData, P) -> Void) {
        var d = PathData()
        trace(&d, shift)
        svg.path(d, fill: paint, opacity: opacity)
    }

    /// The dark line through the points.
    mutating func line(_ points: [P], closed: Bool = false, width: Double = 1.1, opacity: Double = 1) {
        var d = PathData()
        d.move(points[0])
        for point in points.dropFirst() { d.line(point) }
        if closed { d.close() }
        svg.path(d, stroke: .colour(BronzeBuildingsInk.line), width: width, opacity: opacity)
    }

    /// The dark line along path data written by `trace`.
    mutating func line(width: Double = 1.1, opacity: Double = 1, _ trace: (inout PathData) -> Void) {
        var d = PathData()
        trace(&d)
        svg.path(d, stroke: .colour(BronzeBuildingsInk.line), width: width, opacity: opacity)
    }

    /// A shape: its colour, then its line.
    mutating func shape(_ points: [P], _ paint: Paint, width: Double = 1.1) {
        colour(points, paint)
        line(points, closed: true, width: width)
    }

    /// A shadow on the ground or a wall: a darker film over what is drawn.
    mutating func shadow(_ points: [P], opacity: Double = 0.14) {
        svg.polygon(points, fill: .colour("#000000"), opacity: opacity)
    }

    // MARK: Blocks

    /// A block on the map from (x0, y0) to (x1, y1), from `h0` to `h1` points
    /// up: the two walls that face the viewer and, unless `top` is nil, its top.
    mutating func block(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ h0: Double, _ h1: Double,
                        top: Paint?, left: Paint, right: Paint, width: Double = 1.2) {
        colour([iso(x0, y1, h0), iso(x1, y1, h0), iso(x1, y1, h1), iso(x0, y1, h1)], left)
        colour([iso(x1, y1, h0), iso(x1, y0, h0), iso(x1, y0, h1), iso(x1, y1, h1)], right)
        if let top { colour(level(x0, y0, x1, y1, h1), top) }
        line([iso(x0, y1, h1), iso(x0, y1, h0), iso(x1, y1, h0), iso(x1, y0, h0), iso(x1, y0, h1)], width: width)
        line([iso(x1, y1, h0), iso(x1, y1, h1)], width: width)
        if top != nil {
            line(level(x0, y0, x1, y1, h1), closed: true, width: width)
        } else {
            line([iso(x0, y1, h1), iso(x1, y1, h1), iso(x1, y0, h1)], width: width)
        }
    }

    /// An enclosure open to the sky from (x0, y0) to (x1, y1): walls `t` tiles
    /// thick from `h0` up to `h1`, round a floor at `floor` (a roof inside its
    /// parapet, the ground inside walls being raised, the bottom of a pit). The
    /// two inner walls at the back show, and `inside` draws what stands within,
    /// before the front walls hide its foot. A pit (`outer` false) has no outer walls.
    mutating func shell(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double, floor: Double,
                        to h1: Double, thickness t: Double, lit: Paint, shade: Paint, top: Paint, ground: Paint,
                        outer: Bool = true, width: Double = 1.2, inside: (inout BronzeBuildingsPainter) -> Void = { _ in }) {
        let (a0, b0, a1, b1) = (x0 + t, y0 + t, x1 - t, y1 - t)
        colour(level(a0, b0, a1, b1, floor), ground)
        // The inner face of the wall at the back right faces +y, lit; the one at the back left faces +x.
        colour([iso(a0, b0, floor), iso(a1, b0, floor), iso(a1, b0, h1), iso(a0, b0, h1)], lit)
        colour([iso(a0, b1, floor), iso(a0, b0, floor), iso(a0, b0, h1), iso(a0, b1, h1)], shade)
        line([iso(a0, b1, floor), iso(a0, b0, floor), iso(a1, b0, floor)], width: width * 0.7)
        line([iso(a0, b0, floor), iso(a0, b0, h1)], width: width * 0.7)
        // The tops of the walls at the back, behind whatever stands inside.
        if t > 0 {
            colour([iso(x0, y0, h1), iso(x1, y0, h1), iso(a1, b0, h1), iso(a0, b0, h1)], top)
            colour([iso(x0, y1, h1), iso(x0, y0, h1), iso(a0, b0, h1), iso(a0, b1, h1)], top)
            line([iso(a0, b1, h1), iso(a0, b0, h1), iso(a1, b0, h1)], width: width * 0.8)
        }
        line([iso(x0, y1, h1), iso(x0, y0, h1), iso(x1, y0, h1)], width: width)
        inside(&self)
        if outer {
            colour([iso(x0, y1, h0), iso(x1, y1, h0), iso(x1, y1, h1), iso(x0, y1, h1)], lit)
            colour([iso(x1, y1, h0), iso(x1, y0, h0), iso(x1, y0, h1), iso(x1, y1, h1)], shade)
        }
        if t > 0 {
            colour([iso(x1, y0, h1), iso(x1, y1, h1), iso(a1, b1, h1), iso(a1, b0, h1)], top)
            colour([iso(x1, y1, h1), iso(x0, y1, h1), iso(a0, b1, h1), iso(a1, b1, h1)], top)
            line([iso(a0, b1, h1), iso(a1, b1, h1), iso(a1, b0, h1)], width: width * 0.8)
        }
        if outer {
            line([iso(x0, y1, h1), iso(x0, y1, h0), iso(x1, y1, h0), iso(x1, y0, h0), iso(x1, y0, h1)], width: width)
            line([iso(x1, y1, h0), iso(x1, y1, h1)], width: width)
        }
        line([iso(x0, y1, h1), iso(x1, y1, h1), iso(x1, y0, h1)], width: width)
    }

    /// A coping of rounded scallops along an edge from `a` to `b` on the
    /// screen, `count` of them rising `rise` points, filled with `paint`.
    mutating func scallops(_ a: P, _ b: P, count: Int, rise: Double, _ paint: Paint) {
        func trace(_ o: P) -> PathData {
            var d = PathData()
            d.move(a + o)
            for i in 0..<count {
                let s = a + (b - a) * (Double(i) / Double(count)), e = a + (b - a) * (Double(i + 1) / Double(count))
                d.quad((s + e) * 0.5 + P(0, -2 * rise) + o, e + o)
            }
            return d
        }
        colour(paint) { d, o in
            d = trace(o)
            d.close()
        }
        line(width: 0.9) { d in d = trace(P(0, 0)) }
    }

    /// Stepped merlons along a wall drawn with `wall`, standing on `v`, from `u0` to `u1`.
    mutating func merlons(_ u0: Double, _ u1: Double, on v: Double, size s: Double = 1, _ paint: Paint) {
        let pitch = 6.4 * s
        var u = u0 + 0.6 * s
        while u + 4.6 * s <= u1 + 0.01 {
            let w = 4.6 * s
            shape([uv(u, v), uv(u, v + 3 * s), uv(u + 1.1 * s, v + 3 * s), uv(u + 1.1 * s, v + 4.8 * s),
                   uv(u + w - 1.1 * s, v + 4.8 * s), uv(u + w - 1.1 * s, v + 3 * s), uv(u + w, v + 3 * s), uv(u + w, v)],
                  paint, width: 0.8)
            u += pitch
        }
    }

    /// A sharpened stake of timber standing at (x, y) on `h`, `height` points
    /// tall to its point and `radius` points thick.
    mutating func stake(_ x: Double, _ y: Double, on h: Double, height: Double, radius r: Double) {
        typealias I = BronzeBuildingsInk
        let foot = iso(x, y, h), shoulder = foot - P(0, height - r * 1.8), tip = foot - P(0, height)
        colour([foot + P(-r, 0), foot + P(r, 0), shoulder + P(r, 0), tip, shoulder + P(-r, 0)], .colour(I.timber))
        // The lit side of the round stake.
        colour([foot + P(-r, 0), foot + P(-r * 0.2, 0), shoulder + P(-r * 0.2, 0), tip, shoulder + P(-r, 0)],
               .colour(I.timberLight))
        line([foot + P(-r, 0.4), shoulder + P(-r, 0), tip, shoulder + P(r, 0), foot + P(r, 0.4)], width: 0.9)
        line([shoulder + P(-r, 0), shoulder + P(r * 0.1, r * 0.5), shoulder + P(r, 0)], width: 0.6)
    }

    /// A round shield hung at `p` on the screen: a face of the team's colour
    /// with a light spiral, and a bronze rim and boss.
    mutating func shield(at p: P, radius r: Double) {
        typealias I = BronzeBuildingsInk
        svg.ellipse(p + shift, r, r * 1.08, fill: .colour(I.bronze))
        svg.ellipse(p + shift * 0.5, r * 0.74, r * 0.8, fill: .team)
        svg.path("M\(num(p.x)),\(num(p.y)) m\(num(-r * 0.42)),0 a\(num(r * 0.42)),\(num(r * 0.42)) 0 1 1 \(num(r * 0.42)),\(num(r * 0.42))",
                 stroke: .colour(I.light), width: 0.7)
        svg.ellipse(p, r, r * 1.08, fill: .none, stroke: .colour(I.line), width: 0.9)
        svg.circle(p, r * 0.18, fill: .colour(I.bronzeLight), stroke: .colour(I.line), width: 0.5)
    }

    /// Draws on a wall as on flat paper. `content` is given points written
    /// `P(u, -v)`: `u` points along the wall from its left end on the screen,
    /// `v` points up from `h`. The left wall faces +y and runs along x from
    /// (`x`, `y`); the right wall faces +x and runs back along y from (`x`, `y`).
    mutating func wall(_ side: BronzeBuildingsSide, from x: Double, _ y: Double, at h: Double = 0,
                       _ content: (inout BronzeBuildingsPainter) -> Void) {
        let origin = iso(x, y, h)
        svg.raw("<g transform=\"matrix(1 \(num(side.slope)) 0 1 \(num(origin.x)) \(num(origin.y)))\">")
        let saved = shift
        // The same offset on the screen, written in the wall's own frame.
        shift = P(Self.register.x, Self.register.y - side.slope * Self.register.x)
        content(&self)
        shift = saved
        svg.raw("</g>")
    }

    /// A point on a wall drawn with `wall`: `u` along it, `v` up it.
    func uv(_ u: Double, _ v: Double) -> P { P(u, -v) }

    /// A rectangle on a wall, from (u0, v0) to (u1, v1).
    func panel(_ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double) -> [P] {
        [uv(u0, v0), uv(u1, v0), uv(u1, v1), uv(u0, v1)]
    }

    /// An arched opening on a wall: centred on `u`, standing on `v`, `width`
    /// wide and `height` tall to the crown of its arch.
    mutating func arch(_ u: Double, _ v: Double, width: Double, height: Double, _ paint: Paint, line width2: Double = 0.9) {
        let r = width / 2
        func trace(_ o: P) -> String {
            "M\(num(u - r + o.x)),\(num(-v + o.y)) L\(num(u - r + o.x)),\(num(-(v + height - r) + o.y)) "
                + "A\(num(r)),\(num(r)) 0 0 1 \(num(u + r + o.x)),\(num(-(v + height - r) + o.y)) "
                + "L\(num(u + r + o.x)),\(num(-v + o.y)) Z"
        }
        svg.path(trace(shift), fill: paint)
        svg.path(trace(P(0, 0)), stroke: .colour(BronzeBuildingsInk.line), width: width2)
    }

    /// Courses of brick on a wall drawn with `wall`, from `u0` to `u1` and
    /// `v0` to `v1`: a line along each course, and the joints between the
    /// bricks staggered from one course to the next.
    mutating func courses(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, course: Double = 2.6,
                          brick: Double = 6.4, opacity: Double = 0.5) {
        var d = PathData()
        var v = v0, row = 0
        while v < v1 - 0.4 {
            if v > v0 { d.move(uv(u0, v)); d.line(uv(u1, v)) }
            var u = u0 + (row % 2 == 0 ? brick / 2 : brick)
            while u < u1 - 0.6 {
                d.move(uv(u, v + 0.35))
                d.line(uv(u, min(v + course, v1) - 0.35))
                u += brick
            }
            v += course
            row += 1
        }
        svg.path(d, stroke: .colour(BronzeBuildingsInk.line), width: 0.45, opacity: opacity)
    }

    /// A zigzag along a wall from `u0` to `u1`, between `v0` and `v1`, its teeth `pitch` apart.
    mutating func zigzag(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, pitch: Double, width: Double = 0.9) {
        var points: [P] = []
        var u = u0, up = false
        while u <= u1 + 0.01 {
            points.append(uv(u, up ? v1 : v0))
            u += pitch / 2
            up.toggle()
        }
        line(points, width: width)
    }

    /// A flight of steps climbing toward −y between `x0` and `x1`: its foot at
    /// (`y0`, `h0`), its head at (`y1`, `h1`), on solid brick down to `h0`.
    mutating func flight(_ x0: Double, _ x1: Double, foot y0: Double, _ h0: Double, head y1: Double, _ h1: Double,
                         steps: Int, side: String = BronzeBuildingsInk.plasterShade) {
        typealias I = BronzeBuildingsInk
        let run = (y0 - y1) / Double(steps), rise = (h1 - h0) / Double(steps)
        func y(_ i: Int) -> Double { y0 - Double(i) * run }
        func h(_ i: Int) -> Double { h0 + Double(i) * rise }
        // The side facing +x, its edge stepped.
        var profile = [iso(x1, y0, h0)]
        for i in 0..<steps { profile += [iso(x1, y(i), h(i + 1)), iso(x1, y(i + 1), h(i + 1))] }
        profile.append(iso(x1, y1, h0))
        colour(profile, .colour(side))
        // Treads and risers, from the head down, so that the nearer steps lie over the farther.
        for i in (0..<steps).reversed() {
            colour(level(x0, y(i + 1), x1, y(i), h(i + 1)), .colour(I.plasterTop))
            colour([iso(x0, y(i), h(i)), iso(x1, y(i), h(i)), iso(x1, y(i), h(i + 1)), iso(x0, y(i), h(i + 1))],
                   .colour(I.plasterShade))
        }
        line(profile, closed: true, width: 1)
        for i in 0..<steps {
            line([iso(x0, y(i), h(i + 1)), iso(x1, y(i), h(i + 1))], width: 0.7)
        }
        var stringer = [iso(x0, y0, h0)]
        for i in 0..<steps { stringer += [iso(x0, y(i), h(i + 1)), iso(x0, y(i + 1), h(i + 1))] }
        line(stringer, width: 1)
    }

    // MARK: Team colour

    /// A band of the owner's colour along a wall drawn with `wall`, from `u0`
    /// to `u1`, between `v0` and `v1`, edged with plaster so that every team's
    /// colour stands clear of the brick around it.
    mutating func paintedBand(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double) {
        typealias I = BronzeBuildingsInk
        colour(panel(u0, v0 - 0.9, u1, v1 + 0.9), .colour(I.light))
        colour(panel(u0, v0, u1, v1), .team)
        for v in [v0 - 0.9, v0, v1, v1 + 0.9] { line([uv(u0, v), uv(u1, v)], width: v == v0 || v == v1 ? 0.55 : 0.6) }
    }

    /// A cloth in the team's colour hanging on a wall from `top`, `width` wide
    /// and `length` long, its foot cut in a swallowtail, with a sun on it.
    mutating func hanging(_ u: Double, top v: Double, width: Double, length: Double) {
        let r = width / 2
        let outline = [uv(u - r, v), uv(u + r, v), uv(u + r, v - length), uv(u, v - length + 2.6), uv(u - r, v - length)]
        shape(outline, .team, width: 0.9)
        svg.circle(uv(u, v - length * 0.42), width * 0.22, fill: .colour(BronzeBuildingsInk.light))
        // The rod it hangs from.
        line([uv(u - r - 1.2, v), uv(u + r + 1.2, v)], width: 1.3)
    }

    /// A pole standing at `foot`, `height` points tall, with a pennant in the
    /// team's colour streaming to the right from its top, `length` points long.
    mutating func pennant(at foot: P, height: Double, length: Double = 15) {
        let top = foot - P(0, height)
        let k = length / 15
        func cloth(_ o: P) -> PathData {
            var d = PathData()
            d.move(top + P(0.6, 1.2) + o)
            d.quad(top + P(7 * k, -0.6 * k) + o, top + P(15 * k, 2.2 * k) + o)
            d.line(top + P(10.5 * k, 5.2 * k) + o)
            d.line(top + P(15 * k, 8.6 * k) + o)
            d.quad(top + P(7 * k, 9.4 * k) + o, top + P(0.6, 9.6 * k) + o)
            d.close()
            return d
        }
        colour(.team) { d, o in d = cloth(o) }
        // A sun on the cloth, in the light colour.
        svg.circle(top + P(5.2 * k, 5 * k), 1.6 * k, fill: .colour(BronzeBuildingsInk.light))
        line(width: 0.9) { d in d = cloth(P(0, 0)) }
        svg.line([foot, top - P(0, 1)], stroke: .colour(BronzeBuildingsInk.timberDark), width: 1.5)
        // A bronze finial.
        let f = top - P(0, 1)
        shape([f + P(-1.3, 0), f + P(0, -3), f + P(1.3, 0), f + P(0, 1)], .colour(BronzeBuildingsInk.bronzeLight), width: 0.7)
    }
}
