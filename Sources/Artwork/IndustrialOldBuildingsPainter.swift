// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The drawing kit of the Industrial-age looks of the older buildings: the
// palette, the projection of a footprint onto the screen, and the means of
// drawing blocks and walls. Units are points of the screen at zoom 1, y
// downward, with the origin on the ground at the centre of the footprint; a
// sprite is drawn at two pixels a point. The kit follows the Alchemy batch's
// (`AlchemyOldBuildingsPainter`), so that the ages read as one game; the parts
// the Industrial age builds with (brick, slate, sash windows, cast iron, gas
// lamps, chimney pots) are in `IndustrialOldBuildingsParts.swift`.

/// The Industrial age's palette (docs/art-style.md, "Palettes"): brick,
/// bottle green and soot on parchment, with the line every age shares, and
/// the shades of them that brick, dressed stone, slate, cast iron, glass, fire
/// and smoke need. Bottle green replaced the palette's green on 2026-11-19, as
/// the green was nearly Shang's colour. The owner's colour is never laid
/// against the brick or the green: a rim of the light colour always stands
/// between them.
enum IndustrialOldBuildingsInk {
    static let line = "#2a2420"
    /// Red brick: its top, its lit face, its shaded face, and its darkest
    /// (a burnt header, a sooted course).
    static let brick = "#b5603a"
    static let brickTop = "#cd7f57"
    static let brickShade = "#8c4a2e"
    static let brickDark = "#6c3622"
    /// Dressed stone, a cool limestone: its top, its lit face, its shaded face, its dark.
    static let stone = "#cbc3b1"
    static let stoneTop = "#e2dccd"
    static let stoneShade = "#a59d8b"
    static let stoneDark = "#837b6b"
    /// A darker stone, for a plinth or a footing.
    static let footing = "#9d9584"
    static let footingShade = "#7c7466"
    /// Stone and brick freshly laid: walls being raised.
    static let rawStone = "#dcd5c4"
    static let rawStoneTop = "#ebe6d8"
    static let rawStoneShade = "#b8b09e"
    static let rawBrick = "#cc7650"
    static let rawBrickShade = "#a35a3b"
    /// The parchment light: painted sashes, stucco, a rim round the owner's colour.
    static let light = "#efe0c2"
    static let plasterTop = "#f6ecd6"
    static let plasterShade = "#d5c29d"
    /// Granite setts and flagstones: a paved yard.
    static let paving = "#b9b2a2"
    static let pavingShade = "#958e80"
    /// Slate, a neutral grey with little blue in it, kept clear of Shang's
    /// colour and the blues of Egypt and Greece: its lit slope, its shaded
    /// slope, its dark.
    static let slate = "#575c61"
    static let slateLight = "#73787d"
    static let slateShade = "#45494e"
    static let slateDark = "#2c2f33"
    /// Bottle-green paint: doors, shutters, painted ironwork.
    static let green = "#2f5a46"
    static let greenLight = "#467360"
    static let greenShade = "#234536"
    static let greenDark = "#183126"
    /// Soot: a chimney's crown, coal, smoke-stained stone.
    static let soot = "#6b6258"
    static let sootLight = "#8a8177"
    static let sootDark = "#4a433c"
    /// Brass: a bell, a clock's hands, a lamp's fittings.
    static let brass = "#bf9f5a"
    static let brassLight = "#dcc489"
    static let brassShade = "#8f7438"
    /// Glass in sash windows, dark, catching the sky.
    static let glass = "#6d8692"
    static let glassLight = "#b8ccd0"
    static let glassDark = "#435866"
    /// The flame of a gas lamp, and its glow.
    static let flame = "#f3d98c"
    /// Beaten earth: a yard, the floor of a pen.
    static let earth = "#ad9067"
    static let earthShade = "#8b734f"
    /// Oak, and lighter sawn wood.
    static let oak = "#5b3d2a"
    static let oakLight = "#74503a"
    static let timber = "#8a5a33"
    static let timberLight = "#a8743f"
    static let timberDark = "#6b4a2a"
    static let straw = "#d8bb6a"
    static let strawShade = "#ab8e42"
    /// Cast and wrought iron: columns, railings, bands, girders.
    static let iron = "#4f4c49"
    static let ironLight = "#807a73"
    static let ironDark = "#32302e"
    /// Fired clay: chimney pots and drainpipes' collars.
    static let clay = "#c98c62"
    static let clayShade = "#a06a45"
    /// A doorway's or a pit's dark.
    static let dark = "#3d3029"
    /// The fire of a furnace: its outer glow and its white heart.
    static let fire = "#e0913a"
    static let fireCore = "#f8dc8c"
    /// Smoke and steam from the stacks: soot grey, paler, darker.
    static let smoke = "#a39c92"
    static let smokeLight = "#cdc7bc"
    static let smokeDark = "#7d766d"
}

/// A wall of a block that faces the viewer: the one facing +y (on the screen's
/// lower left) or the one facing +x (on its lower right).
enum IndustrialOldBuildingsSide: Sendable {
    case left, right

    /// How far the wall's foot falls for each point it runs to the right.
    var slope: Double { self == .left ? 0.5 : -0.5 }
}

/// Draws one layer of a building: its picture or its team-colour mask.
struct IndustrialOldBuildingsPainter {
    var svg: SVG
    /// The colour's offset from its line in the current frame of drawing.
    private(set) var shift: P

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
        svg.path(d, stroke: .colour(IndustrialOldBuildingsInk.line), width: width, opacity: opacity)
    }

    /// The dark line along path data written by `trace`.
    mutating func line(width: Double = 1.1, opacity: Double = 1, _ trace: (inout PathData) -> Void) {
        var d = PathData()
        trace(&d)
        svg.path(d, stroke: .colour(IndustrialOldBuildingsInk.line), width: width, opacity: opacity)
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
    /// thick from `h0` up to `h1`, round a floor at `floor`. The two inner walls
    /// at the back show, and `inside` draws what stands within, before the
    /// front walls hide its foot. A pit (`outer` false) has no outer walls.
    mutating func shell(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double, floor: Double,
                        to h1: Double, thickness t: Double, lit: Paint, shade: Paint, top: Paint, ground: Paint,
                        outer: Bool = true, width: Double = 1.2,
                        inside: (inout IndustrialOldBuildingsPainter) -> Void = { _ in }) {
        let (a0, b0, a1, b1) = (x0 + t, y0 + t, x1 - t, y1 - t)
        colour(level(a0, b0, a1, b1, floor), ground)
        colour([iso(a0, b0, floor), iso(a1, b0, floor), iso(a1, b0, h1), iso(a0, b0, h1)], lit)
        colour([iso(a0, b1, floor), iso(a0, b0, floor), iso(a0, b0, h1), iso(a0, b1, h1)], shade)
        line([iso(a0, b1, floor), iso(a0, b0, floor), iso(a1, b0, floor)], width: width * 0.7)
        line([iso(a0, b0, floor), iso(a0, b0, h1)], width: width * 0.7)
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

    /// A paved yard filling the footprint from -e to e, `h` points thick, its
    /// cobbles laid in rows with a few stones picked out.
    mutating func cobbles(_ e: Double, height h: Double, every step: Double = 0.125) {
        typealias I = IndustrialOldBuildingsInk
        block(-e, -e, e, e, 0, h, top: .colour(I.paving), left: .colour(I.pavingShade), right: .colour(I.pavingShade), width: 1)
        var joints = PathData()
        var t = -e + step
        var row = 0
        while t < e - step / 2 {
            joints.move(iso(-e, t, h)); joints.line(iso(e, t, h))
            // Short joints across each row, staggered, so that the rows read as setts.
            var s = -e + (row % 2 == 0 ? step : step / 2)
            while s < e - 0.02 {
                joints.move(iso(s, t - step, h)); joints.line(iso(s, t, h))
                s += step
            }
            t += step
            row += 1
        }
        svg.path(joints, stroke: .colour(I.line), width: 0.35, opacity: 0.3)
    }

    // MARK: Walls as paper

    /// Draws on a wall as on flat paper. `content` is given points written
    /// `P(u, -v)`: `u` points along the wall from its left end on the screen,
    /// `v` points up from `h`. The left wall faces +y and runs along x from
    /// (`x`, `y`); the right wall faces +x and runs back along y from (`x`, `y`).
    mutating func wall(_ side: IndustrialOldBuildingsSide, from x: Double, _ y: Double, at h: Double = 0,
                       _ content: (inout IndustrialOldBuildingsPainter) -> Void) {
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

    /// A round-headed opening on a wall: centred on `u`, standing on `v`,
    /// `width` wide and `height` tall to the crown of its arch.
    mutating func arch(_ u: Double, _ v: Double, width: Double, height: Double, _ paint: Paint, line width2: Double = 0.9) {
        let r = width / 2
        func trace(_ o: P) -> String {
            "M\(num(u - r + o.x)),\(num(-v + o.y)) L\(num(u - r + o.x)),\(num(-(v + height - r) + o.y)) "
                + "A\(num(r)),\(num(r)) 0 0 1 \(num(u + r + o.x)),\(num(-(v + height - r) + o.y)) "
                + "L\(num(u + r + o.x)),\(num(-v + o.y)) Z"
        }
        svg.path(trace(shift), fill: paint)
        svg.path(trace(P(0, 0)), stroke: .colour(IndustrialOldBuildingsInk.line), width: width2)
    }

    /// Courses of masonry on a wall drawn with `wall`, from `u0` to `u1` and
    /// `v0` to `v1`: a line along each course, and the joints between the
    /// blocks staggered from one course to the next.
    mutating func courses(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, course: Double = 4.2,
                          brick: Double = 10.5, opacity: Double = 0.4, phase: Double = 0) {
        var d = PathData()
        var v = v0, row = 0
        while v < v1 - 0.4 {
            if v > v0 { d.move(uv(u0, v)); d.line(uv(u1, v)) }
            var u = u0 + phase + (row % 2 == 0 ? brick / 2 : brick)
            while u < u1 - 0.6 {
                if u > u0 + 0.6 {
                    d.move(uv(u, v + 0.35))
                    d.line(uv(u, min(v + course, v1) - 0.35))
                }
                u += brick
            }
            v += course
            row += 1
        }
        svg.path(d, stroke: .colour(IndustrialOldBuildingsInk.line), width: 0.45, opacity: opacity)
    }

    /// Quoins up the corner of a wall drawn with `wall` at `u` (its left end
    /// when `atStart`, else its right), from `v0` to `v1`: long and short
    /// stones in turn, in a lighter stone.
    mutating func quoins(at u: Double, atStart: Bool, from v0: Double, to v1: Double, course: Double = 4.4,
                         reach long: Double = 4.4) {
        typealias I = IndustrialOldBuildingsInk
        var v = v0, k = 0
        while v < v1 - 0.5 {
            let top = min(v + course, v1), reach = k % 2 == 0 ? long : long * 0.6
            let (a, b) = atStart ? (u, u + reach) : (u - reach, u)
            shape(panel(a, v, b, top), .colour(I.stoneTop), width: 0.5)
            v = top
            k += 1
        }
    }

    /// A timber of the framing on a wall drawn with `wall`, from `a` to `b`,
    /// `width` points broad: dark oak, outlined.
    mutating func timber(_ a: P, _ b: P, width w: Double = 2.2, paint: String = IndustrialOldBuildingsInk.oak) {
        let d = b - a, length = (d.x * d.x + d.y * d.y).squareRoot()
        guard length > 0 else { return }
        let n = P(-d.y / length * w / 2, d.x / length * w / 2)
        shape([a + n, b + n, b - n, a - n], .colour(paint), width: 0.5)
    }
}
