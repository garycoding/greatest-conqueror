// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The drawing kit of the Industrial age's new buildings: the palette, the
// projection of a footprint onto the screen, and the parts the buildings are
// made of. It follows the kit of the Alchemy age's new buildings, so that the
// two ages read as one game: units are points of the screen at zoom 1, y
// downward, with the origin on the ground at the centre of the footprint; a
// sprite is drawn at two pixels a point. The Industrial age adds brick laid in
// courses, cast iron, glass in iron bars, riveted plate, and coal smoke.

/// The Industrial age's palette (docs/art-style.md, "Palettes"), its navy
/// replaced by bottle green (ruled 2026-11-19: the navy was nearly Shang's
/// colour): brick, bottle green, soot and the light, with the line every age
/// shares, and the shades of them that brick, slate, iron, glass, timber, oil
/// and smoke need. The owner's colour is never laid next to the brick or the
/// bottle green: every part that carries it is framed in the light colour or
/// set on soot.
enum IndustrialNewBuildingsInk {
    static let line = "#2a2420"
    /// Brick: its lit face, its shaded face, its darkest, and fresh brick on a site.
    static let brick = "#c2683c"
    static let brickLit = "#cf7a4c"
    static let brickShade = "#9e5230"
    static let brickDark = "#7c3d23"
    static let freshBrick = "#d4855a"
    static let freshBrickShade = "#b06a43"
    /// Bottle green: slate roofs, painted iron, doors and window frames.
    static let green = "#2f5a46"
    static let greenLit = "#4a7a61"
    static let greenShade = "#234836"
    static let greenDark = "#183428"
    /// Soot: cast iron, engines, coal and cinders.
    static let soot = "#6b6258"
    static let sootLit = "#867c70"
    static let sootShade = "#544c44"
    static let sootDark = "#3c3631"
    /// The light colour: dressings of stone, paint, and the parchment of a sign.
    static let light = "#efe0c2"
    static let lightTop = "#f6ecd6"
    static let lightShade = "#d7c49f"
    static let lightDark = "#b9a77f"
    /// The yard: cinders and beaten earth, a cooler brown than the Alchemy age's.
    static let yard = "#9f8a6a"
    static let yardShade = "#7f6c50"
    static let ballast = "#a59c8e"
    static let ballastShade = "#857c70"
    static let timber = "#8a5a33"
    static let timberLight = "#a8743f"
    static let timberDark = "#6b4a2a"
    /// Steel worn bright: the heads of rails, a piston rod.
    static let steel = "#b4aea4"
    /// Brass: a locomotive's dome and the hands of a clock.
    static let brass = "#c9a24e"
    /// A doorway's or a window's dark.
    static let dark = "#3d3029"
    /// Glass in the light, and the sky in it.
    static let glass = "#cbdbe0"
    static let glassShade = "#9fb6c2"
    /// Crude oil, its lighter edge, and the sheen on it.
    static let oil = "#1f1a17"
    static let oilShade = "#3b3433"
    static let oilSheen = "#5a5560"
    static let oilViolet = "#776a86"
    /// Reeds by an oil field: green, and dried.
    static let reed = "#7e8a52"
    static let reedDry = "#b39a5c"
    /// The fire of a furnace or a firebox.
    static let fire = "#e0913a"
    static let fireCore = "#f8dc8c"
    /// Coal smoke, and steam.
    static let smoke = "#a49a8e"
    static let smokeLight = "#cbc1b2"
    static let steam = "#f1ebdf"
}

/// A wall of a block that faces the viewer: the one facing +y (on the screen's
/// lower left) or the one facing +x (on its lower right).
enum IndustrialNewBuildingsSide: Sendable {
    case left, right

    /// How far the wall's foot falls for each point it runs to the right.
    var slope: Double { self == .left ? 0.5 : -0.5 }
}

/// Draws one layer of a building: its picture or its team-colour mask.
struct IndustrialNewBuildingsPainter {
    var svg: SVG
    /// The colour's offset from its line in the current frame of drawing.
    private(set) var shift: P

    /// How far a field of colour sits from its line on the screen, in points:
    /// the slight misregistration of the style, as the Alchemy buildings have it.
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

    /// The point of a circle of the map, centred on (`cx`, `cy`) with radius
    /// `r` tiles, at `degrees` round it from +x toward +y, `h` points up. The
    /// side nearest the viewer is at 45 degrees; the circle's leftmost point on
    /// the screen is at 135 and its rightmost at -45.
    func round(_ cx: Double, _ cy: Double, _ r: Double, _ degrees: Double, _ h: Double) -> P {
        let a = degrees * .pi / 180
        return iso(cx + r * cos(a), cy + r * sin(a), h)
    }

    /// Points along an arc of a circle of the map at height `h`, from `a0` to `a1` degrees.
    func arc(_ cx: Double, _ cy: Double, _ r: Double, from a0: Double, to a1: Double, at h: Double, steps: Int = 18) -> [P] {
        (0...steps).map { round(cx, cy, r, a0 + (a1 - a0) * Double($0) / Double(steps), h) }
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
        svg.path(d, stroke: .colour(IndustrialNewBuildingsInk.line), width: width, opacity: opacity)
    }

    /// The dark line along path data written by `trace`.
    mutating func line(width: Double = 1.1, opacity: Double = 1, _ trace: (inout PathData) -> Void) {
        var d = PathData()
        trace(&d)
        svg.path(d, stroke: .colour(IndustrialNewBuildingsInk.line), width: width, opacity: opacity)
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

    /// A block of brick: `block` in the brick's colours, with its courses drawn on both faces.
    mutating func brickwork(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ h0: Double, _ h1: Double,
                            top: Paint? = nil, fresh: Bool = false, width: Double = 1.1) {
        typealias I = IndustrialNewBuildingsInk
        block(x0, y0, x1, y1, h0, h1, top: top, left: .colour(fresh ? I.freshBrick : I.brick),
              right: .colour(fresh ? I.freshBrickShade : I.brickShade), width: width)
        wall(.left, from: x0, y1, at: h0) { p in p.courses(0, (x1 - x0) * 32, 0, h1 - h0) }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, (y1 - y0) * 32, 0, h1 - h0) }
    }

    /// Draws on a wall as on flat paper. `content` is given points written
    /// `P(u, -v)`: `u` points along the wall from its left end on the screen,
    /// `v` points up from `h`. The left wall faces +y and runs along x from
    /// (`x`, `y`); the right wall faces +x and runs back along y from (`x`, `y`).
    mutating func wall(_ side: IndustrialNewBuildingsSide, from x: Double, _ y: Double, at h: Double = 0,
                       _ content: (inout IndustrialNewBuildingsPainter) -> Void) {
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

    /// Courses of brick on a wall drawn with `wall`, from `u0` to `u1` and `v0`
    /// to `v1`: a line along each course, and the joints staggered from one
    /// course to the next. Brick is laid in finer courses than the stone of the
    /// earlier ages.
    mutating func courses(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, course: Double = 3.2,
                          brick: Double = 6.4, opacity: Double = 0.42, phase: Double = 0) {
        var d = PathData()
        var v = v0, row = 0
        while v < v1 - 0.6 {
            if v > v0 { d.move(uv(u0, v)); d.line(uv(u1, v)) }
            var u = u0 + phase + (row % 2 == 0 ? brick / 2 : brick)
            while u < u1 - 0.8 {
                if u > u0 + 0.8 {
                    d.move(uv(u, v + 0.3))
                    d.line(uv(u, min(v + course, v1) - 0.3))
                }
                u += brick
            }
            v += course
            row += 1
        }
        svg.path(d, stroke: .colour(IndustrialNewBuildingsInk.line), width: 0.42, opacity: opacity)
    }

    /// A window on a wall drawn with `wall`, its foot at (`u`, `v`), under a
    /// segmental arch of brick on end: a sill of stone, a frame of bottle green and
    /// small panes of glass in iron bars.
    mutating func archedWindow(_ u: Double, _ v: Double, width w: Double, height h: Double, lit: Bool = true) {
        typealias I = IndustrialNewBuildingsInk
        let rise = w * 0.22
        func at(_ a: Double, _ b: Double) -> P { P(a, -b) }
        func outline(_ e: Double, _ o: P) -> PathData {
            var d = PathData()
            d.move(at(u - e, v - e) + o)
            d.line(at(u + w + e, v - e) + o)
            d.line(at(u + w + e, v + h) + o)
            d.quad(at(u + w / 2, v + h + 2 * rise + e) + o, at(u - e, v + h) + o)
            d.close()
            return d
        }
        // The arch of brick on end over the opening.
        colour(.colour(I.brickDark)) { d, o in d = outline(1.3, o) }
        line(width: 0.6) { d in d = outline(1.3, P(0, 0)) }
        colour(.colour(lit ? I.glass : I.glassShade)) { d, o in d = outline(0, o) }
        // The sky's reflection, darker toward the foot.
        colour(panel(u + 0.4, v + 0.3, u + w - 0.4, v + h * 0.45), .colour(I.glassShade), opacity: 0.8)
        var bars = PathData()
        for k in 1..<3 { let x = u + w * Double(k) / 3; bars.move(uv(x, v)); bars.line(uv(x, v + h + rise)) }
        var y = v + h / 4
        while y < v + h + rise * 0.6 { bars.move(uv(u, y)); bars.line(uv(u + w, y)); y += h / 4 }
        svg.path(bars, stroke: .colour(I.green), width: 0.55)
        line(width: 0.8) { d in d = outline(0, P(0, 0)) }
        shape(panel(u - 1.4, v - 1.6, u + w + 1.4, v - 0.3), .colour(I.lightTop), width: 0.55)
    }

    /// A plain rectangular window with a lintel of stone, its foot at (`u`, `v`).
    mutating func sash(_ u: Double, _ v: Double, width w: Double, height h: Double) {
        typealias I = IndustrialNewBuildingsInk
        shape(panel(u, v, u + w, v + h), .colour(I.glass), width: 0.7)
        colour(panel(u + 0.3, v + 0.3, u + w - 0.3, v + h * 0.5), .colour(I.glassShade), opacity: 0.8)
        var bars = PathData()
        bars.move(uv(u + w / 2, v)); bars.line(uv(u + w / 2, v + h))
        bars.move(uv(u, v + h / 2)); bars.line(uv(u + w, v + h / 2))
        svg.path(bars, stroke: .colour(I.green), width: 0.6)
        line(panel(u, v, u + w, v + h), closed: true, width: 0.7)
        shape(panel(u - 1, v + h, u + w + 1, v + h + 1.6), .colour(I.lightTop), width: 0.5)
        shape(panel(u - 0.8, v - 1.2, u + w + 0.8, v - 0.1), .colour(I.lightTop), width: 0.5)
    }

    // MARK: Round work

    /// An upright cylinder or a cone cut short: centred on (`cx`, `cy`), `r0`
    /// tiles in radius at `h0` narrowing to `r1` at `h1`, lit on its left and
    /// shaded on its right. Its top is drawn when `top` is given.
    mutating func frustum(_ cx: Double, _ cy: Double, _ r0: Double, _ r1: Double, _ h0: Double, _ h1: Double, lit: String,
                          mid: String, shade: String, top: Paint? = nil, width: Double = 1.1) {
        func band(_ a0: Double, _ a1: Double) -> [P] {
            arc(cx, cy, r0, from: a0, to: a1, at: h0) + arc(cx, cy, r1, from: a1, to: a0, at: h1)
        }
        colour(band(-45, 135), .colour(mid))
        colour(band(80, 135), .colour(lit))
        colour(band(-45, 6), .colour(shade))
        if let top {
            colour(arc(cx, cy, r1, from: 0, to: 360, at: h1, steps: 36), top)
            line(arc(cx, cy, r1, from: 0, to: 360, at: h1, steps: 36), closed: true, width: width)
        } else {
            line(arc(cx, cy, r1, from: -45, to: 135, at: h1), width: width)
        }
        line(arc(cx, cy, r0, from: -45, to: 135, at: h0), width: width)
        line([round(cx, cy, r0, -45, h0), round(cx, cy, r1, -45, h1)], width: width)
        line([round(cx, cy, r0, 135, h0), round(cx, cy, r1, 135, h1)], width: width)
    }

    /// Rings round a frustum drawn with `frustum`, every `step` points from `h0`
    /// to `h1`: the courses of a brick stack, or the seams of riveted plate.
    mutating func rings(_ cx: Double, _ cy: Double, _ r0: Double, _ r1: Double, _ h0: Double, _ h1: Double, every step: Double,
                        from v0: Double, to v1: Double, width: Double = 0.42, opacity: Double = 0.42) {
        var d = PathData()
        var v = v0
        while v < v1 - 0.3 {
            let r = r0 + (r1 - r0) * (v - h0) / (h1 - h0)
            let ring = arc(cx, cy, r, from: -45, to: 135, at: v, steps: 14)
            d.move(ring[0])
            for p in ring.dropFirst() { d.line(p) }
            v += step
        }
        svg.path(d, stroke: .colour(IndustrialNewBuildingsInk.line), width: width, opacity: opacity)
    }

    /// The convex hull of the points (Andrew's monotone chain), clockwise on the screen.
    func hull(_ points: [P]) -> [P] {
        let sorted = points.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        guard sorted.count > 2 else { return sorted }
        func cross(_ o: P, _ a: P, _ b: P) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        var lower: [P] = [], upper: [P] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    /// The end of a cylinder lying along x: a circle in the plane facing +x at
    /// `x`, centred on `y` tiles and `h` points up, `radius` points across.
    func endCircle(_ x: Double, _ y: Double, _ h: Double, radius: Double, steps: Int = 28) -> [P] {
        (0..<steps).map { k in
            let a = Double(k) / Double(steps) * 2 * .pi
            // A point `radius` along the wall is radius / 35.8 tiles of the map.
            return iso(x, y - radius * cos(a) / 35.8, h + radius * sin(a))
        }
    }

    /// A cylinder lying along x from `x0` to `x1`, its axis `y` tiles and `h`
    /// points up, `radius` points across: a boiler or a tank wagon's barrel.
    /// Its end facing +x is drawn by `end`.
    mutating func barrel(_ x0: Double, _ x1: Double, _ y: Double, _ h: Double, radius: Double, body: String, lit: String,
                         shade: String, end: String) {
        let back = endCircle(x0, y, h, radius: radius), front = endCircle(x1, y, h, radius: radius)
        let outline = hull(back + front)
        colour(outline, .colour(body))
        // A lit band along its upper side, and shade along its foot.
        let topBack = iso(x0, y, h + radius * 0.62), topFront = iso(x1, y, h + radius * 0.62)
        let litBand = hull([topBack + P(0, -radius * 0.3), topFront + P(0, -radius * 0.3), topBack + P(-radius * 0.5, -radius * 0.1),
                            topFront + P(-radius * 0.5, -radius * 0.1), topBack + P(-radius * 0.3, radius * 0.25),
                            topFront + P(-radius * 0.3, radius * 0.25)])
        colour(litBand, .colour(lit))
        let footBack = iso(x0, y, h - radius * 0.7), footFront = iso(x1, y, h - radius * 0.7)
        colour(hull([footBack, footFront, footBack + P(radius * 0.4, radius * 0.5), footFront + P(radius * 0.4, radius * 0.5),
                     footBack + P(0, radius * 0.6), footFront + P(0, radius * 0.6)]), .colour(shade), opacity: 0.9)
        line(outline, closed: true, width: 1)
        colour(front, .colour(end))
        line(front, closed: true, width: 0.9)
    }

    // MARK: Timber, iron and materials

    /// A pole of timber or iron from `a` to `b` on the screen, outlined.
    mutating func pole(_ a: P, _ b: P, width: Double = 1.6, colour paint: String = IndustrialNewBuildingsInk.timberLight) {
        svg.line([a, b], stroke: .colour(IndustrialNewBuildingsInk.line), width: width + 1.1)
        svg.line([a, b], stroke: .colour(paint), width: width)
    }

    /// Scaffolding: upright poles standing at `feet` on the map, from `h0` up
    /// `height` points, tied by ledgers between neighbours at each of `levels`,
    /// with boards at `boards` running toward `inward` (tiles along x and y).
    mutating func scaffold(_ feet: [(x: Double, y: Double)], from h0: Double, height: Double, levels: [Double],
                           boards: Double? = nil, inward: (x: Double, y: Double) = (0, -0.13)) {
        typealias I = IndustrialNewBuildingsInk
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
        // A brace across each bay.
        for (a, b) in zip(feet, feet.dropFirst()) {
            pole(iso(a.x, a.y, h0 + 1), iso(b.x, b.y, h0 + (levels.first ?? height)), width: 0.9, colour: I.timber)
        }
        for foot in feet {
            pole(iso(foot.x, foot.y, h0), iso(foot.x, foot.y, h0 + height))
            for level in levels {
                let at = iso(foot.x, foot.y, h0 + level)
                line([at + P(-1.3, -0.9), at + P(1.3, 0.9)], width: 0.8)
            }
        }
    }

    /// Bricks stacked on a pallet on the map from (x0, y0) to (x1, y1), from
    /// `h0`, `courses` high.
    mutating func bricks(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, courses: Int) {
        typealias I = IndustrialNewBuildingsInk
        block(x0 - 0.02, y0 - 0.02, x1 + 0.02, y1 + 0.02, h0, h0 + 1.4, top: .colour(I.timberLight), left: .colour(I.timber),
              right: .colour(I.timberDark), width: 0.7)
        let top = h0 + 1.4 + Double(courses) * 2.4
        block(x0, y0, x1, y1, h0 + 1.4, top, top: .colour(I.freshBrick), left: .colour(I.freshBrick), right: .colour(I.freshBrickShade),
              width: 0.8)
        wall(.left, from: x0, y1, at: h0 + 1.4) { p in p.courses(0, (x1 - x0) * 32, 0, top - h0 - 1.4, course: 2.4, brick: 5, opacity: 0.55) }
        wall(.right, from: x1, y1, at: h0 + 1.4) { p in p.courses(0, (y1 - y0) * 32, 0, top - h0 - 1.4, course: 2.4, brick: 5, opacity: 0.55) }
    }

    /// Planks or squared beams stacked along x from `x0` to `x1` at `y`, `count` high.
    mutating func planks(_ x0: Double, _ x1: Double, _ y: Double, on h: Double = 0, count: Int = 4) {
        typealias I = IndustrialNewBuildingsInk
        for k in 0..<count {
            let base = h + Double(k) * 1.6
            block(x0 + Double(k % 2) * 0.03, y - 0.12, x1 - Double(k % 2) * 0.02, y + 0.12, base, base + 1.6,
                  top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark), width: 0.7)
        }
    }

    /// Iron girders or rails stacked along x from `x0` to `x1` at `y`, `count`
    /// high: each a slim bar of soot with its bright edge.
    mutating func girders(_ x0: Double, _ x1: Double, _ y: Double, on h: Double = 0, count: Int = 3, across: Int = 2) {
        typealias I = IndustrialNewBuildingsInk
        for k in 0..<count {
            for j in 0..<across {
                let base = h + Double(k) * 1.9, yy = y + Double(j) * 0.11 - Double(k % 2) * 0.05
                block(x0 + Double(k % 2) * 0.04, yy - 0.04, x1 - Double(k % 2) * 0.03, yy + 0.04, base, base + 1.9,
                      top: .colour(I.sootLit), left: .colour(I.soot), right: .colour(I.sootShade), width: 0.6)
            }
        }
    }

    /// A drum of oil standing at `p` on the screen, `size` across: a cylinder of
    /// painted iron with two rolling hoops and a bung on its lid.
    mutating func drum(at p: P, size s: Double = 1, paint: String = IndustrialNewBuildingsInk.green,
                       lit litPaint: String = IndustrialNewBuildingsInk.greenLit) {
        typealias I = IndustrialNewBuildingsInk
        let w = 3.6 * s, h = 8.4 * s
        svg.ellipse(p + P(0.8, 0.4), w * 1.15, 1.6 * s, fill: .colour("#000000"), opacity: 0.16)
        let body = [p + P(-w, 0), p + P(w, 0), p + P(w, -h), p + P(-w, -h)]
        colour(body, .colour(paint))
        colour([p + P(-w, 0), p + P(-w * 0.2, 0), p + P(-w * 0.2, -h), p + P(-w, -h)], .colour(litPaint))
        svg.ellipse(p + shift * 0.5, w, 1.3 * s, fill: .colour(paint))
        line([p + P(-w, -h), p + P(-w, 0)], width: 0.8)
        line([p + P(w, -h), p + P(w, 0)], width: 0.8)
        line(width: 0.8) { d in d.move(p + P(-w, 0)); d.quad(p + P(0, 2.6 * s), p + P(w, 0)) }
        for v in [0.33, 0.66] {
            line(width: 0.7) { d in d.move(p + P(-w, -h * v)); d.quad(p + P(0, -h * v + 2.6 * s), p + P(w, -h * v)) }
        }
        svg.ellipse(p + P(0, -h) + shift * 0.5, w, 1.3 * s, fill: .colour(litPaint))
        svg.ellipse(p + P(0, -h), w, 1.3 * s, fill: .none, stroke: .colour(I.line), width: 0.7)
        svg.circle(p + P(w * 0.4, -h), 0.55 * s, fill: .colour(I.dark))
    }

    /// A wooden crate on the map from (x, y), `size` tiles square and `h` points tall.
    mutating func crate(_ x: Double, _ y: Double, size: Double = 0.22, height: Double = 7, on h0: Double = 0) {
        typealias I = IndustrialNewBuildingsInk
        block(x, y, x + size, y + size, h0, h0 + height, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.8)
        let a = size * 32
        wall(.left, from: x, y + size, at: h0) { p in
            p.line([p.uv(0.8, 0.8), p.uv(a - 0.8, height - 0.8)], width: 0.6)
            p.line([p.uv(0, height / 2), p.uv(a, height / 2)], width: 0.5, opacity: 0.6)
        }
        wall(.right, from: x + size, y + size, at: h0) { p in
            p.line([p.uv(0.8, height - 0.8), p.uv(a - 0.8, 0.8)], width: 0.6)
        }
    }

    /// A heap of coal on the map at (x, y), `radius` tiles across and `height` points tall.
    mutating func coal(_ x: Double, _ y: Double, radius r: Double, height: Double) {
        typealias I = IndustrialNewBuildingsInk
        // A mound: its foot round the circle, its shoulders lower and narrower, and a rounded crown.
        let foot = arc(x, y, r, from: -45, to: 135, at: 0, steps: 12)
        let shoulder = arc(x, y, r * 0.62, from: -45, to: 135, at: height * 0.68, steps: 10)
        let crown = arc(x, y, r * 0.24, from: -45, to: 135, at: height, steps: 6)
        let heap = hull(foot + shoulder + crown)
        colour(heap, .colour(I.sootDark))
        let lit = hull(arc(x, y, r, from: 75, to: 135, at: 0, steps: 6) + arc(x, y, r * 0.62, from: 75, to: 135, at: height * 0.68, steps: 5)
                       + [iso(x, y, height)])
        colour(lit, .colour(I.soot))
        line(heap, closed: true, width: 0.9)
        // Lumps catching the light.
        let lumps: [(Double, Double)] = [(100, 0.3), (60, 0.5), (20, 0.25), (110, 0.7), (40, 0.8), (80, 0.1), (0, 0.55), (125, 0.45)]
        for (k, (a, t)) in lumps.enumerated() {
            let p = round(x, y, r * (1 - t * 0.7), a, height * t * 0.9)
            svg.circle(p, 0.85, fill: .colour(k % 2 == 0 ? I.sootLit : I.soot), stroke: .colour(I.line), width: 0.3)
        }
    }

    /// A puff of smoke at `p`: a cluster of round billows of one colour under one outline.
    mutating func puff(at p: P, radius r: Double, colour: String) {
        let billows: [(P, Double)] = [(P(-r * 0.7, r * 0.15), r * 0.72), (P(0, -r * 0.35), r), (P(r * 0.8, r * 0.1), r * 0.78),
                                      (P(r * 0.1, r * 0.45), r * 0.7)]
        for (o, s) in billows { svg.circle(p + o, s, fill: .colour(IndustrialNewBuildingsInk.line)) }
        for (o, s) in billows { svg.circle(p + o + shift * 0.4, s - 0.9, fill: .colour(colour)) }
        // A curl of shade under the billows.
        line(width: 0.5, opacity: 0.5) { d in
            d.move(p + P(-r * 0.6, r * 0.3)); d.quad(p + P(0, r * 0.8), p + P(r * 0.7, r * 0.35))
        }
    }

    // MARK: Team colour

    /// The Industrial age's mark, in the light colour: a cog wheel.
    mutating func mark(at p: P, radius r: Double) {
        typealias I = IndustrialNewBuildingsInk
        var teeth: [P] = []
        let n = 8
        for k in 0..<(n * 4) {
            let a = Double(k) / Double(n * 4) * 2 * .pi
            let outer = (k % 4 == 1 || k % 4 == 2)
            teeth.append(p + P(cos(a), sin(a)) * (outer ? r : r * 0.74))
        }
        svg.polygon(teeth, fill: .colour(I.light))
        svg.circle(p, r * 0.32, fill: .colour(I.light))
        svg.ellipse(p, r * 0.48, r * 0.48, fill: .none, stroke: .team, width: r * 0.16)
    }

    /// A pole standing at `foot`, `height` points tall, with a square flag in
    /// the team's colour flying to the right from its top, `length` points
    /// long, edged at its hoist in the light colour, the age's mark on it, and
    /// a ball of iron at the pole's head.
    mutating func flag(at foot: P, height: Double, length: Double = 15) {
        typealias I = IndustrialNewBuildingsInk
        let top = foot - P(0, height)
        let k = length / 15
        func cloth(_ o: P, from start: Double) -> PathData {
            var d = PathData()
            d.move(top + P(start, 1) + o)
            d.cubic(top + P(5 * k, -1.4 * k) + o, top + P(10 * k, 2 * k) + o, top + P(15 * k, 0.4 * k) + o)
            d.line(top + P(15 * k, 10 * k) + o)
            d.cubic(top + P(10 * k, 11.6 * k) + o, top + P(5 * k, 8.2 * k) + o, top + P(start, 10.4 * k) + o)
            d.close()
            return d
        }
        colour(.colour(I.light)) { d, o in d = cloth(o, from: 0.6) }
        colour(.team) { d, o in d = cloth(o, from: 3 * k) }
        mark(at: top + P(9 * k, 5.4 * k), radius: 2.6 * k)
        line(width: 0.4, opacity: 0.7) { d in d.move(top + P(3 * k, 1.2 * k)); d.line(top + P(3 * k, 10.4 * k)) }
        line(width: 0.9) { d in d = cloth(P(0, 0), from: 0.6) }
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.line), width: 2.2)
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.sootLit), width: 1.2)
        svg.circle(top - P(0, 2), 1.4, fill: .colour(I.sootLit), stroke: .colour(I.line), width: 0.6)
    }

    /// A painted signboard on a wall drawn with `wall`, from (`u0`, `v0`) to
    /// (`u1`, `v1`): a field of the team's colour framed in the light colour,
    /// with the age's mark at its left and `text` lettered beside it.
    mutating func signboard(_ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double, text: String) {
        let e = 1.2
        shape(panel(u0, v0, u1, v1), .colour(IndustrialNewBuildingsInk.light), width: 0.8)
        colour(panel(u0 + e, v0 + e, u1 - e, v1 - e), .team)
        line(panel(u0 + e, v0 + e, u1 - e, v1 - e), closed: true, width: 0.4, opacity: 0.7)
        let h = v1 - v0
        mark(at: uv(u0 + h * 0.62, (v0 + v1) / 2), radius: h * 0.3)
        lettering(text, from: u0 + h * 1.3, to: u1 - e - 1, v0 + h * 0.3, v1 - h * 0.3)
    }

    /// Capital letters in the light colour on a wall drawn with `wall`, centred
    /// between `u0` and `u1`, from `v0` to `v1`: drawn as strokes, for the few
    /// letters the signs need.
    mutating func lettering(_ text: String, from u0: Double, to u1: Double, _ v0: Double, _ v1: Double) {
        let h = v1 - v0, w = h * 0.62, gap = h * 0.32
        let total = Double(text.count) * w + Double(text.count - 1) * gap
        var u = (u0 + u1 - total) / 2
        var letters = PathData()
        let m = (v0 + v1) / 2
        for c in text {
            let (l, r) = (u, u + w)
            func stroke(_ points: [(Double, Double)]) {
                letters.move(uv(points[0].0, points[0].1))
                for q in points.dropFirst() { letters.line(uv(q.0, q.1)) }
            }
            switch c {
            case "W": stroke([(l, v1), (l + w * 0.25, v0), (l + w * 0.5, m), (l + w * 0.75, v0), (r, v1)])
            case "O": stroke([(l, v0 + h * 0.2), (l, v1 - h * 0.2), (l + w * 0.25, v1), (r - w * 0.25, v1), (r, v1 - h * 0.2),
                              (r, v0 + h * 0.2), (r - w * 0.25, v0), (l + w * 0.25, v0), (l, v0 + h * 0.2)])
            case "R": stroke([(l, v0), (l, v1), (r - w * 0.2, v1), (r, v1 - h * 0.2), (r, m + h * 0.15), (r - w * 0.2, m), (l, m)])
                      stroke([(l + w * 0.4, m), (r, v0)])
            case "K": stroke([(l, v0), (l, v1)]); stroke([(r, v1), (l, m), (r, v0)])
            case "S": stroke([(r, v1), (l + w * 0.15, v1), (l, v1 - h * 0.25), (l + w * 0.15, m), (r - w * 0.15, m), (r, v0 + h * 0.25),
                              (r - w * 0.15, v0), (l, v0)])
            case "A": stroke([(l, v0), (l + w * 0.5, v1), (r, v0)]); stroke([(l + w * 0.22, v0 + h * 0.4), (r - w * 0.22, v0 + h * 0.4)])
            case "I": stroke([(l + w * 0.5, v0), (l + w * 0.5, v1)])
            case "L": stroke([(l, v1), (l, v0), (r, v0)])
            case "E": stroke([(r, v1), (l, v1), (l, v0), (r, v0)]); stroke([(l, m), (r - w * 0.2, m)])
            case "T": stroke([(l, v1), (r, v1)]); stroke([(l + w * 0.5, v1), (l + w * 0.5, v0)])
            case "N": stroke([(l, v0), (l, v1), (r, v0), (r, v1)])
            case "Y": stroke([(l, v1), (l + w * 0.5, m), (r, v1)]); stroke([(l + w * 0.5, m), (l + w * 0.5, v0)])
            default: break
            }
            u += w + gap
        }
        svg.path(letters, stroke: .colour(IndustrialNewBuildingsInk.light), width: 0.7)
    }
}
