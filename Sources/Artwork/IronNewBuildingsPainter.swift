// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The drawing kit of the Iron age's new buildings: the palette, the projection
// of a footprint onto the screen, and the parts the buildings are made of. It
// follows the kit of the Bronze-age buildings, so that the two ages read as one
// game: units are points of the screen at zoom 1, y downward, with the origin on
// the ground at the centre of the footprint; a sprite is drawn at two pixels a point.

/// The Iron age's palette (docs/art-style.md, "Palettes"): sea green, iron grey,
/// legion red and the light, with the line every age shares, and the shades of
/// them that dressed stone, roof tile, timber, iron and a field of grain need.
enum IronNewBuildingsInk {
    static let line = "#2a2420"
    /// The ground's sea green, and its shades: a painted door, a trough of water.
    static let seaGreen = "#6fa39a"
    static let seaGreenLight = "#8dbab1"
    static let seaGreenShade = "#4f8279"
    /// Dressed stone, the iron grey: its top, its lit face, its shaded face.
    static let stoneTop = "#d3ccbd"
    static let stone = "#b8b0a0"
    static let stoneShade = "#948b7b"
    static let stoneDark = "#776f62"
    /// The worn walkway along the top of a wall.
    static let walkway = "#a39a89"
    /// Fired roof tile, the legion red.
    static let tile = "#c8402f"
    static let tileTop = "#d65a47"
    static let tileShade = "#9f3022"
    /// Lime plaster, the light colour.
    static let light = "#efe0c2"
    static let plasterTop = "#f5ead2"
    static let plasterShade = "#d6c39f"
    /// Beaten earth and ploughed soil.
    static let earth = "#b68b5e"
    static let earthShade = "#946c45"
    static let soil = "#8d6243"
    static let soilDark = "#6e4a32"
    static let timber = "#8a5a33"
    static let timberLight = "#a8743f"
    static let timberDark = "#6b4a2a"
    /// Wrought iron: fittings, tyres, a hook.
    static let iron = "#5f5a55"
    static let ironLight = "#8b857d"
    /// Ripe grain, and the hay and straw that come of it.
    static let grain = "#dcb253"
    static let grainLight = "#ecd083"
    static let grainShade = "#b48a36"
    static let straw = "#d4b468"
    static let strawShade = "#a98a42"
    /// A horse's chestnut coat and dark mane.
    static let horse = "#a9643a"
    static let horseShade = "#7c4528"
    /// A doorway's dark.
    static let dark = "#3d3029"
}

/// A wall of a block that faces the viewer: the one facing +y (on the screen's
/// lower left) or the one facing +x (on its lower right).
enum IronNewBuildingsSide: Sendable {
    case left, right

    /// How far the wall's foot falls for each point it runs to the right.
    var slope: Double { self == .left ? 0.5 : -0.5 }
}

/// Draws one layer of a building: its picture or its team-colour mask.
struct IronNewBuildingsPainter {
    var svg: SVG
    /// The colour's offset from its line in the current frame of drawing.
    private var shift: P

    /// How far a field of colour sits from its line on the screen, in points:
    /// the slight misregistration of the style, as the Bronze buildings have it.
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
        svg.path(d, stroke: .colour(IronNewBuildingsInk.line), width: width, opacity: opacity)
    }

    /// The dark line along path data written by `trace`.
    mutating func line(width: Double = 1.1, opacity: Double = 1, _ trace: (inout PathData) -> Void) {
        var d = PathData()
        trace(&d)
        svg.path(d, stroke: .colour(IronNewBuildingsInk.line), width: width, opacity: opacity)
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

    /// A block of dressed stone: `block` in the iron grey, with its courses drawn on both faces.
    mutating func ashlar(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ h0: Double, _ h1: Double,
                         course: Double = 4.4, stone: Double = 9, width: Double = 1.1) {
        typealias I = IronNewBuildingsInk
        block(x0, y0, x1, y1, h0, h1, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade), width: width)
        wall(.left, from: x0, y1, at: h0) { p in p.courses(0, (x1 - x0) * 32, 0, h1 - h0, course: course, brick: stone) }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, (y1 - y0) * 32, 0, h1 - h0, course: course, brick: stone) }
    }

    /// Draws on a wall as on flat paper. `content` is given points written
    /// `P(u, -v)`: `u` points along the wall from its left end on the screen,
    /// `v` points up from `h`. The left wall faces +y and runs along x from
    /// (`x`, `y`); the right wall faces +x and runs back along y from (`x`, `y`).
    mutating func wall(_ side: IronNewBuildingsSide, from x: Double, _ y: Double, at h: Double = 0,
                       _ content: (inout IronNewBuildingsPainter) -> Void) {
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

    /// Courses of stone on a wall drawn with `wall`, from `u0` to `u1` and
    /// `v0` to `v1`: a line along each course, and the joints staggered from
    /// one course to the next.
    mutating func courses(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, course: Double = 4.4,
                          brick: Double = 9, opacity: Double = 0.55, phase: Double = 0) {
        var d = PathData()
        var v = v0, row = 0
        while v < v1 - 0.6 {
            if v > v0 { d.move(uv(u0, v)); d.line(uv(u1, v)) }
            var u = u0 + phase + (row % 2 == 0 ? brick / 2 : brick)
            while u < u1 - 0.8 {
                if u > u0 + 0.8 {
                    d.move(uv(u, v + 0.4))
                    d.line(uv(u, min(v + course, v1) - 0.4))
                }
                u += brick
            }
            v += course
            row += 1
        }
        svg.path(d, stroke: .colour(IronNewBuildingsInk.line), width: 0.5, opacity: opacity)
    }

    // MARK: Roofs

    /// A gabled roof of red tile over a box from (x0, y0) to (x1, y1), its
    /// eaves at `eave` and its ridge running along x at `ridge`, overhanging by
    /// `over` tiles. `gable` draws on the gable's end wall (facing +x) before
    /// the roof's edge covers it; it is given the wall's width and the height
    /// of the ridge above the eaves.
    mutating func gabledRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double,
                             over: Double = 0.08, gableWall: Paint, gable: (inout IronNewBuildingsPainter, Double, Double) -> Void = { _, _, _ in }) {
        typealias I = IronNewBuildingsInk
        let ym = (y0 + y1) / 2
        let (a0, a1, b0, b1) = (x0 - over, x1 + over, y0 - over, y1 + over)
        // How far the roof falls over the overhang.
        let drop = (ridge - eave) * over / (ym - y0)
        // The back slope, mostly hidden behind the ridge.
        colour([iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a0, b0, eave - drop)], .colour(I.tileShade))
        // The gable's end wall.
        let triangle = [iso(x1, y1, eave), iso(x1, y0, eave), iso(x1, ym, ridge)]
        colour(triangle, gableWall)
        wall(.right, from: x1, y1, at: eave) { p in gable(&p, (y1 - y0) * 32, ridge - eave) }
        line(triangle, closed: true, width: 0.9)
        // The roof's thickness along the gable, then the front slope.
        let edge = P(0, 2.2)
        colour([iso(a1, b1, eave - drop), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a1, b0, eave - drop) + edge,
                iso(a1, ym, ridge) + edge, iso(a1, b1, eave - drop) + edge], .colour(I.tileShade))
        let front = [iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b1, eave - drop), iso(a0, b1, eave - drop)]
        colour([front[3], front[2], front[2] + edge, front[3] + edge], .colour(I.tileShade))
        colour(front, .colour(I.tile))
        // The tiles: rolls running from the eaves to the ridge, and the courses across them.
        var rolls = PathData()
        let count = Int(((a1 - a0) * 32 / 5.2).rounded())
        for k in 1..<count {
            let x = a0 + (a1 - a0) * Double(k) / Double(count)
            rolls.move(iso(x, b1, eave - drop) + P(0, 1.6))
            rolls.line(iso(x, ym, ridge))
        }
        svg.path(rolls, stroke: .colour(I.tileShade), width: 1.5)
        svg.path(rolls, stroke: .colour(I.tileTop), width: 0.6)
        var courses = PathData()
        for t in stride(from: 0.2, to: 0.95, by: 0.2) {
            let y = b1 + (ym - b1) * t, h = (eave - drop) + (ridge - eave + drop) * t
            courses.move(iso(a0, y, h)); courses.line(iso(a1, y, h))
        }
        svg.path(courses, stroke: .colour(I.line), width: 0.45, opacity: 0.55)
        line(front, closed: true, width: 1.1)
        line([front[3], front[3] + edge, front[2] + edge, front[2]], width: 0.9)
        line([iso(a1, ym, ridge), iso(a1, ym, ridge) + edge, iso(a1, b0, eave - drop) + edge, iso(a1, b0, eave - drop)], width: 0.9)
        line([front[2] + edge, iso(a1, ym, ridge) + edge], width: 0.9)
        // The ridge's capping tiles.
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.line), width: 3.2)
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.tileTop), width: 1.6)
    }

    // MARK: Timber and iron

    /// A pole of timber from `a` to `b` on the screen, outlined.
    mutating func pole(_ a: P, _ b: P, width: Double = 1.6, colour paint: String = IronNewBuildingsInk.timberLight) {
        svg.line([a, b], stroke: .colour(IronNewBuildingsInk.line), width: width + 1.1)
        svg.line([a, b], stroke: .colour(paint), width: width)
    }

    /// A squared beam lying on the map from (x0, y0) to (x1, y1) at `h`, `size` points square.
    mutating func beam(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, on h: Double, size s: Double = 2.6) {
        typealias I = IronNewBuildingsInk
        let a = iso(x0, y0, h), b = iso(x1, y1, h)
        let up = P(0, -s)
        // The beam's near side, its top, and its cut end.
        let along = b - a
        let across = abs(along.x) > 0.01 && along.y / along.x > 0 ? P(-s * 0.9, s * 0.45) : P(s * 0.9, s * 0.45)
        colour([a, b, b + up, a + up], .colour(I.timber))
        colour([a + up, b + up, b + up - across, a + up - across], .colour(I.timberLight))
        line([a, b, b + up, a + up], closed: true, width: 0.8)
        line([a + up, a + up - across, b + up - across, b + up], width: 0.8)
        line([a + up * 0.5 + along * 0.2, a + up * 0.5 + along * 0.55], width: 0.4, opacity: 0.7)
    }

    /// Scaffolding: upright poles standing at `feet` on the map, from `h0` up
    /// `height` points, tied by ledgers between neighbours at each of `levels`,
    /// with boards at `boards` running toward `inward` (tiles along x and y).
    mutating func scaffold(_ feet: [(x: Double, y: Double)], from h0: Double, height: Double, levels: [Double],
                           boards: Double? = nil, inward: (x: Double, y: Double) = (0, -0.13)) {
        typealias I = IronNewBuildingsInk
        if let boards {
            for (a, b) in zip(feet, feet.dropFirst()) {
                let deck = [iso(a.x, a.y, h0 + boards), iso(b.x, b.y, h0 + boards),
                            iso(b.x + inward.x, b.y + inward.y, h0 + boards), iso(a.x + inward.x, a.y + inward.y, h0 + boards)]
                colour(deck, .colour(I.timberLight))
                colour([deck[0], deck[1], deck[1] + P(0, 1.3), deck[0] + P(0, 1.3)], .colour(I.timber))
                line(deck, closed: true, width: 0.7)
                line([deck[0] + P(0, 1.3), deck[1] + P(0, 1.3)], width: 0.7)
            }
        }
        for level in levels {
            for (a, b) in zip(feet, feet.dropFirst()) { pole(iso(a.x, a.y, h0 + level), iso(b.x, b.y, h0 + level), width: 1.1) }
        }
        for foot in feet {
            pole(iso(foot.x, foot.y, h0), iso(foot.x, foot.y, h0 + height))
            for level in levels {
                let at = iso(foot.x, foot.y, h0 + level)
                line([at + P(-1.3, -0.9), at + P(1.3, 0.9)], width: 0.8)
            }
        }
    }

    /// A fence of posts and two rails from one place on the map to another, standing on `h0`, with `posts` posts.
    mutating func fence(from a: (Double, Double), to b: (Double, Double), posts: Int, on h0: Double = 1.5, height: Double = 10) {
        typealias I = IronNewBuildingsInk
        for rail in [height * 0.4, height * 0.84] { pole(iso(a.0, a.1, h0 + rail), iso(b.0, b.1, h0 + rail), width: 1.2) }
        for k in 0..<posts {
            let t = Double(k) / Double(posts - 1)
            let x = a.0 + (b.0 - a.0) * t, y = a.1 + (b.1 - a.1) * t
            pole(iso(x, y, h0), iso(x, y, h0 + height), width: 1.7, colour: I.timber)
        }
    }

    /// Roof tiles of red clay stacked on the map from (x0, y0) to (x1, y1), from `h0`, `courses` high.
    mutating func roofTiles(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, courses: Int) {
        typealias I = IronNewBuildingsInk
        let course = 1.8, h1 = h0 + Double(courses) * course
        block(x0, y0, x1, y1, h0, h1, top: .colour(I.tileTop), left: .colour(I.tile), right: .colour(I.tileShade), width: 0.8)
        for c in 1..<courses {
            let h = h0 + Double(c) * course
            line([iso(x0, y1, h), iso(x1, y1, h), iso(x1, y0, h)], width: 0.45, opacity: 0.8)
        }
        var rolls = PathData()
        var x = x0 + 0.06
        while x < x1 - 0.03 { rolls.move(iso(x, y0, h1)); rolls.line(iso(x, y1, h1)); x += 0.08 }
        svg.path(rolls, stroke: .colour(I.tileShade), width: 0.9)
    }

    /// Dressed stones stacked on the map from (x0, y0) to (x1, y1), from `h0`, `courses` high.
    mutating func stones(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, courses: Int) {
        let course = 3.6
        ashlar(x0, y0, x1, y1, h0, h0 + Double(courses) * course, course: course, stone: 7, width: 0.9)
    }

    /// Planks stacked along x from `x0` to `x1` at `y`, `count` high.
    mutating func planks(_ x0: Double, _ x1: Double, _ y: Double, on h: Double = 0, count: Int = 4) {
        typealias I = IronNewBuildingsInk
        for k in 0..<count {
            let base = h + Double(k) * 1.6
            block(x0 + Double(k % 2) * 0.03, y - 0.12, x1 - Double(k % 2) * 0.02, y + 0.12, base, base + 1.6,
                  top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark), width: 0.7)
        }
    }

    /// A sack of grain or seed standing at `p` on the screen.
    mutating func sack(at p: P, size s: Double = 1) {
        typealias I = IronNewBuildingsInk
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-3.6 * s, 0) + o)
            d.cubic(p + P(-4.8 * s, -4 * s) + o, p + P(-3.4 * s, -7.4 * s) + o, p + P(-1.4 * s, -8 * s) + o)
            d.line(p + P(-2 * s, -9.6 * s) + o)
            d.line(p + P(2 * s, -9.6 * s) + o)
            d.line(p + P(1.4 * s, -8 * s) + o)
            d.cubic(p + P(3.4 * s, -7.4 * s) + o, p + P(4.8 * s, -4 * s) + o, p + P(3.6 * s, 0) + o)
            d.close()
            return d
        }
        svg.ellipse(p + P(0.6, 0.4), 4.6 * s, 1.3 * s, fill: .colour("#000000"), opacity: 0.15)
        colour(.colour(I.light)) { d, o in d = outline(o) }
        line(width: 0.8) { d in d = outline(P(0, 0)) }
        line([p + P(-1.6 * s, -8 * s), p + P(1.6 * s, -8 * s)], width: 0.8)
        line([p + P(0.6 * s, -5.4 * s), p + P(2 * s, -2.6 * s)], width: 0.45, opacity: 0.6)
    }

    // MARK: Team colour

    /// A band of the owner's colour along a wall drawn with `wall`, from `u0`
    /// to `u1`, between `v0` and `v1`, edged with plaster so that every team's
    /// colour stands clear of the stone around it.
    mutating func paintedBand(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double) {
        typealias I = IronNewBuildingsInk
        colour(panel(u0, v0 - 0.9, u1, v1 + 0.9), .colour(I.light))
        colour(panel(u0, v0, u1, v1), .team)
        for v in [v0 - 0.9, v0, v1, v1 + 0.9] { line([uv(u0, v), uv(u1, v)], width: v == v0 || v == v1 ? 0.55 : 0.6) }
    }

    /// A pole standing at `foot`, `height` points tall, with a pennant in the
    /// team's colour streaming to the right from its top, `length` points long,
    /// and an iron finial.
    mutating func pennant(at foot: P, height: Double, length: Double = 15) {
        typealias I = IronNewBuildingsInk
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
        // A wreath on the cloth, in the light colour: the Iron age's mark where the Bronze age had a sun.
        svg.ellipse(top + P(5.4 * k, 5 * k), 1.9 * k, 1.9 * k, fill: .none, stroke: .colour(I.light), width: 0.8 * k)
        line(width: 0.9) { d in d = cloth(P(0, 0)) }
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.timberDark), width: 1.5)
        let f = top - P(0, 1)
        shape([f + P(-1.2, 0), f + P(0, -3.4), f + P(1.2, 0), f + P(0, 0.9)], .colour(I.ironLight), width: 0.7)
    }

    /// A cloth in the team's colour hanging on a wall drawn with `wall` from
    /// `top`, `width` wide and `length` long, its foot fringed, with a wreath on it.
    mutating func hanging(_ u: Double, top v: Double, width: Double, length: Double) {
        typealias I = IronNewBuildingsInk
        let r = width / 2
        let outline = [uv(u - r, v), uv(u + r, v), uv(u + r, v - length), uv(u, v - length + 2.4), uv(u - r, v - length)]
        shape(outline, .team, width: 0.9)
        svg.ellipse(uv(u, v - length * 0.42), width * 0.24, width * 0.24, fill: .none, stroke: .colour(I.light), width: 0.8)
        line([uv(u - r - 1.2, v), uv(u + r + 1.2, v)], width: 1.3)
    }
}
