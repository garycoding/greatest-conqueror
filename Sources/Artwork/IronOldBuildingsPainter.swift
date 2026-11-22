// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The drawing kit of the Iron-age looks of the older buildings: the palette,
// the projection of a footprint onto the screen, and the parts the buildings
// are made of. Units are points of the screen at zoom 1, y downward, with the
// origin on the ground at the centre of the footprint; a sprite is drawn at
// two pixels a point. The kit follows the Bronze batch's
// (`BronzeBuildingsPainter`), so that the two ages read as one game, and adds
// what the Iron age builds with: dressed stone, red tile, columns and iron.

/// The Iron age's palette (docs/art-style.md, "Palettes"): sea green, iron
/// grey, legion red and the light, with the line every age shares, and the
/// shades of them that stone, plaster, tile, timber and iron need.
enum IronOldBuildingsInk {
    static let line = "#2a2420"
    /// Dressed stone, the iron grey: its top, its lit face, its shaded face.
    static let stone = "#b8b0a0"
    static let stoneTop = "#d0c9b9"
    static let stoneShade = "#958c7c"
    /// A darker stone, for a plinth or a footing.
    static let footing = "#9e9686"
    static let footingShade = "#7f7768"
    /// Stone freshly cut, not yet weathered: walls being raised.
    static let rawStone = "#d6cdb9"
    static let rawStoneTop = "#e4ddcc"
    static let rawStoneShade = "#b1a792"
    /// Lime plaster and pale marble, the light colour: its top, its lit face, its shaded face.
    static let light = "#efe0c2"
    static let plasterTop = "#f6ecd6"
    static let plasterShade = "#d6c4a0"
    /// Flagstones: a paved court or a yard.
    static let paving = "#d4cdbd"
    static let pavingShade = "#b4ac9b"
    /// Roof tile, the legion red: its lit slope, its shaded slope, and its dark.
    static let tile = "#c8402f"
    static let tileLight = "#d65c46"
    static let tileShade = "#a43222"
    static let tileDark = "#7a2518"
    /// Painted wood, the sea green: doors and shutters.
    static let sea = "#6fa39a"
    static let seaLight = "#8cb9b0"
    static let seaShade = "#4f8178"
    /// Beaten earth: a yard, a bank, the floor of a pen.
    static let earth = "#bfae8c"
    static let earthShade = "#998868"
    static let timber = "#8a5a33"
    static let timberLight = "#a8743f"
    static let timberDark = "#6b4a2a"
    static let reed = "#cda85e"
    static let reedShade = "#a9863f"
    /// Wrought iron: fittings, grilles, bands, the heads of weapons.
    static let iron = "#5f5b56"
    static let ironLight = "#8e8981"
    static let ironDark = "#3c3936"
    /// Gilt, for a finial or a boss: used sparingly.
    static let gilt = "#d8a95a"
    /// Fired clay: amphorae and jars.
    static let clay = "#c9845a"
    static let clayShade = "#a5653f"
    /// A doorway's or a pit's dark.
    static let dark = "#3d3029"
}

/// A wall of a block that faces the viewer: the one facing +y (on the screen's
/// lower left) or the one facing +x (on its lower right).
enum IronOldBuildingsSide: Sendable {
    case left, right

    /// How far the wall's foot falls for each point it runs to the right.
    var slope: Double { self == .left ? 0.5 : -0.5 }
}

/// Draws one layer of a building: its picture or its team-colour mask.
struct IronOldBuildingsPainter {
    var svg: SVG
    /// The colour's offset from its line in the current frame of drawing.
    fileprivate(set) var shift: P

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
        svg.path(d, stroke: .colour(IronOldBuildingsInk.line), width: width, opacity: opacity)
    }

    /// The dark line along path data written by `trace`.
    mutating func line(width: Double = 1.1, opacity: Double = 1, _ trace: (inout PathData) -> Void) {
        var d = PathData()
        trace(&d)
        svg.path(d, stroke: .colour(IronOldBuildingsInk.line), width: width, opacity: opacity)
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
                        outer: Bool = true, width: Double = 1.2, inside: (inout IronOldBuildingsPainter) -> Void = { _ in }) {
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

    /// A sharpened stake of timber standing at (x, y) on `h`, `height` points
    /// tall to its point and `radius` points thick.
    mutating func stake(_ x: Double, _ y: Double, on h: Double, height: Double, radius r: Double) {
        typealias I = IronOldBuildingsInk
        let foot = iso(x, y, h), shoulder = foot - P(0, height - r * 1.8), tip = foot - P(0, height)
        colour([foot + P(-r, 0), foot + P(r, 0), shoulder + P(r, 0), tip, shoulder + P(-r, 0)], .colour(I.timber))
        // The lit side of the round stake.
        colour([foot + P(-r, 0), foot + P(-r * 0.2, 0), shoulder + P(-r * 0.2, 0), tip, shoulder + P(-r, 0)],
               .colour(I.timberLight))
        line([foot + P(-r, 0.4), shoulder + P(-r, 0), tip, shoulder + P(r, 0), foot + P(r, 0.4)], width: 0.9)
        line([shoulder + P(-r, 0), shoulder + P(r * 0.1, r * 0.5), shoulder + P(r, 0)], width: 0.6)
    }

    /// Draws on a wall as on flat paper. `content` is given points written
    /// `P(u, -v)`: `u` points along the wall from its left end on the screen,
    /// `v` points up from `h`. The left wall faces +y and runs along x from
    /// (`x`, `y`); the right wall faces +x and runs back along y from (`x`, `y`).
    mutating func wall(_ side: IronOldBuildingsSide, from x: Double, _ y: Double, at h: Double = 0,
                       _ content: (inout IronOldBuildingsPainter) -> Void) {
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
        svg.path(trace(P(0, 0)), stroke: .colour(IronOldBuildingsInk.line), width: width2)
    }

    /// Courses of masonry on a wall drawn with `wall`, from `u0` to `u1` and
    /// `v0` to `v1`: a line along each course, and the joints between the
    /// blocks staggered from one course to the next. The defaults are dressed
    /// stone; smaller numbers give brick.
    mutating func courses(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, course: Double = 4.2,
                          brick: Double = 10.5, opacity: Double = 0.42) {
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
        svg.path(d, stroke: .colour(IronOldBuildingsInk.line), width: 0.45, opacity: opacity)
    }

    /// A flight of stone steps climbing toward −y between `x0` and `x1`: its foot
    /// at (`y0`, `h0`), its head at (`y1`, `h1`), on solid stone down to `h0`.
    mutating func flight(_ x0: Double, _ x1: Double, foot y0: Double, _ h0: Double, head y1: Double, _ h1: Double,
                         steps: Int, side: String = IronOldBuildingsInk.stoneShade) {
        typealias I = IronOldBuildingsInk
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
            colour(level(x0, y(i + 1), x1, y(i), h(i + 1)), .colour(I.stoneTop))
            colour([iso(x0, y(i), h(i)), iso(x1, y(i), h(i)), iso(x1, y(i), h(i + 1)), iso(x0, y(i), h(i + 1))],
                   .colour(I.stone))
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
    /// colour stands clear of the stone around it.
    mutating func paintedBand(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double) {
        typealias I = IronOldBuildingsInk
        colour(panel(u0, v0 - 0.9, u1, v1 + 0.9), .colour(I.light))
        colour(panel(u0, v0, u1, v1), .team)
        for v in [v0 - 0.9, v0, v1, v1 + 0.9] { line([uv(u0, v), uv(u1, v)], width: v == v0 || v == v1 ? 0.55 : 0.6) }
    }

    /// A cloth in the team's colour hanging on a wall from `top`, `width` wide
    /// and `length` long, its foot cut in a swallowtail, with a wreath on it.
    mutating func hanging(_ u: Double, top v: Double, width: Double, length: Double) {
        let r = width / 2
        let outline = [uv(u - r, v), uv(u + r, v), uv(u + r, v - length), uv(u, v - length + 2.6), uv(u - r, v - length)]
        shape(outline, .team, width: 0.9)
        wreath(at: uv(u, v - length * 0.42), radius: width * 0.26)
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
        // A wreath on the cloth, in the light colour.
        wreath(at: top + P(5.4 * k, 5 * k), radius: 2 * k)
        line(width: 0.9) { d in d = cloth(P(0, 0)) }
        svg.line([foot, top - P(0, 1)], stroke: .colour(IronOldBuildingsInk.timberDark), width: 1.5)
        // An iron finial with a gilt tip.
        let f = top - P(0, 1)
        shape([f + P(-1.3, 0), f + P(0, -3.4), f + P(1.3, 0), f + P(0, 1)], .colour(IronOldBuildingsInk.iron), width: 0.7)
        svg.circle(f + P(0, -3.4), 0.7, fill: .colour(IronOldBuildingsInk.gilt))
    }
}
