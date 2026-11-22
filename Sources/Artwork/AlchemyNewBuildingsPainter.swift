// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The drawing kit of the Alchemy age's new buildings: the palette, the
// projection of a footprint onto the screen, and the parts the buildings are
// made of. It follows the kit of the Iron age's new buildings, so that the two
// ages read as one game: units are points of the screen at zoom 1, y downward,
// with the origin on the ground at the centre of the footprint; a sprite is
// drawn at two pixels a point. The Alchemy age adds round work: towers, cones
// of slate, and battlements that run round them.

/// The Alchemy age's palette (docs/art-style.md, "Palettes"): gilt, deep teal,
/// wine and the light, with the line every age shares, and the shades of them
/// that dressed stone, slate, timber, iron, glass, fire and smoke need. The
/// owner's colour is never laid next to the wine or the gilt.
enum AlchemyNewBuildingsInk {
    static let line = "#2a2420"
    /// Gilt: finials, brass, and the light of a furnace.
    static let gilt = "#d6b25e"
    static let giltLight = "#ead08a"
    static let giltShade = "#a8873c"
    /// Deep teal: slate roofs, painted doors and shutters.
    static let teal = "#2f5a5a"
    static let tealLit = "#4a7a77"
    static let tealShade = "#224343"
    static let tealDark = "#183232"
    /// Wine: shutters, a door, the dye of the alchemist's liquors.
    static let wine = "#7a3a5a"
    static let wineLight = "#985675"
    static let wineShade = "#5c2a43"
    /// The light colour: lime plaster and parchment.
    static let light = "#efe0c2"
    static let plasterTop = "#f6ecd6"
    static let plasterShade = "#d7c49f"
    /// Dressed stone, a warm grey a shade paler than the Iron age's: its top,
    /// its lit face, its shaded face, its darkest.
    static let stoneTop = "#e0d8c6"
    static let stone = "#c6bca7"
    static let stoneShade = "#a09682"
    static let stoneDark = "#7f7666"
    /// Fresh stone, not yet weathered, on a building site.
    static let rawStone = "#ddd2ba"
    static let rawStoneTop = "#ebe3d0"
    static let rawStoneShade = "#b8ad95"
    /// Beaten earth and gravel, and the paving of a road.
    static let earth = "#a98a5c"
    static let earthShade = "#87693f"
    static let paving = "#cfc5b0"
    static let pavingShade = "#ada28a"
    static let timber = "#8a5a33"
    static let timberLight = "#a8743f"
    static let timberDark = "#6b4a2a"
    /// Wrought iron: a portcullis, hoops, hinges.
    static let iron = "#5f5a55"
    static let ironLight = "#8b857d"
    static let ironDark = "#3c3936"
    /// A doorway's or a window's dark.
    static let dark = "#3d3029"
    /// The fire of a furnace: its outer glow and its white heart.
    static let fire = "#e0913a"
    static let fireCore = "#f8dc8c"
    /// Smoke tinted by what burns: teal, wine and gilt, paled.
    static let smokeTeal = "#8fb8ae"
    static let smokeWine = "#b98ea8"
    static let smokeGilt = "#ecdaa2"
    /// Glass, and the liquors in it.
    static let glass = "#cfe0d6"
}

/// A wall of a block that faces the viewer: the one facing +y (on the screen's
/// lower left) or the one facing +x (on its lower right).
enum AlchemyNewBuildingsSide: Sendable {
    case left, right

    /// How far the wall's foot falls for each point it runs to the right.
    var slope: Double { self == .left ? 0.5 : -0.5 }
}

/// Draws one layer of a building: its picture or its team-colour mask.
struct AlchemyNewBuildingsPainter {
    var svg: SVG
    /// The colour's offset from its line in the current frame of drawing.
    private(set) var shift: P

    /// How far a field of colour sits from its line on the screen, in points:
    /// the slight misregistration of the style, as the Iron buildings have it.
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
        svg.path(d, stroke: .colour(AlchemyNewBuildingsInk.line), width: width, opacity: opacity)
    }

    /// The dark line along path data written by `trace`.
    mutating func line(width: Double = 1.1, opacity: Double = 1, _ trace: (inout PathData) -> Void) {
        var d = PathData()
        trace(&d)
        svg.path(d, stroke: .colour(AlchemyNewBuildingsInk.line), width: width, opacity: opacity)
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

    /// A block of dressed stone: `block` in the stone's colours, with its courses drawn on both faces.
    mutating func ashlar(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ h0: Double, _ h1: Double,
                         course: Double = 4.4, stone: Double = 9, fresh: Bool = false, width: Double = 1.1) {
        typealias I = AlchemyNewBuildingsInk
        block(x0, y0, x1, y1, h0, h1, top: .colour(fresh ? I.rawStoneTop : I.stoneTop), left: .colour(fresh ? I.rawStone : I.stone),
              right: .colour(fresh ? I.rawStoneShade : I.stoneShade), width: width)
        wall(.left, from: x0, y1, at: h0) { p in p.courses(0, (x1 - x0) * 32, 0, h1 - h0, course: course, brick: stone) }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, (y1 - y0) * 32, 0, h1 - h0, course: course, brick: stone) }
    }

    /// Draws on a wall as on flat paper. `content` is given points written
    /// `P(u, -v)`: `u` points along the wall from its left end on the screen,
    /// `v` points up from `h`. The left wall faces +y and runs along x from
    /// (`x`, `y`); the right wall faces +x and runs back along y from (`x`, `y`).
    mutating func wall(_ side: AlchemyNewBuildingsSide, from x: Double, _ y: Double, at h: Double = 0,
                       _ content: (inout AlchemyNewBuildingsPainter) -> Void) {
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
                          brick: Double = 9, opacity: Double = 0.5, phase: Double = 0) {
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
        svg.path(d, stroke: .colour(AlchemyNewBuildingsInk.line), width: 0.5, opacity: opacity)
    }

    /// An opening on a wall drawn with `wall` under a round arch: centred on
    /// `u`, standing on `v`, `width` wide and `height` tall to its crown.
    mutating func arch(_ u: Double, _ v: Double, width: Double, height: Double, _ paint: Paint, line lineWidth: Double = 0.9) {
        func at(_ a: Double, _ b: Double) -> P { P(a, -b) }
        func trace(_ o: P) -> PathData {
            var d = PathData()
            let r = width / 2, spring = v + height - r
            d.move(at(u - r, v) + o)
            d.line(at(u - r, spring) + o)
            for k in 1...12 {
                let a = Double.pi * Double(k) / 12
                d.line(at(u - r * cos(a), spring + r * sin(a)) + o)
            }
            d.line(at(u + r, v) + o)
            d.close()
            return d
        }
        colour(paint) { d, o in d = trace(o) }
        line(width: lineWidth) { d in d = trace(P(0, 0)) }
    }

    /// A ring of voussoirs round an arch drawn with `arch`, `depth` deep.
    mutating func voussoirs(_ u: Double, _ v: Double, width: Double, height: Double, depth: Double = 2, count: Int = 7) {
        typealias I = AlchemyNewBuildingsInk
        arch(u, v, width: width + 2 * depth, height: height + depth, .colour(I.stoneTop), line: 0.8)
        let r = width / 2, spring = v + height - r
        var joints = PathData()
        for k in 1..<count {
            let a = Double.pi * Double(k) / Double(count)
            joints.move(uv(u - r * cos(a), spring + r * sin(a)))
            joints.line(uv(u - (r + depth) * cos(a), spring + (r + depth) * sin(a)))
        }
        svg.path(joints, stroke: .colour(I.line), width: 0.45)
    }

    /// A narrow slit for an archer on a wall drawn with `wall`, its foot at (`u`, `v`).
    mutating func slit(_ u: Double, _ v: Double, height: Double = 7) {
        typealias I = AlchemyNewBuildingsInk
        shape(panel(u - 0.8, v, u + 0.8, v + height), .colour(I.dark), width: 0.6)
        shape(panel(u - 1.9, v + height * 0.45, u + 1.9, v + height * 0.45 + 1.2), .colour(I.dark), width: 0.5)
    }

    /// The part of the polygon `subject` that lies within the convex polygon
    /// `window`, both on the screen (Sutherland and Hodgman's clipping).
    func clipped(_ subject: [P], to window: [P]) -> [P] {
        let n = window.count
        guard n >= 3 else { return [] }
        // Which side of each edge is inside: the side the window's centre lies on.
        let centre = window.reduce(P(0, 0), +) * (1 / Double(n))
        func cross(_ a: P, _ b: P, _ p: P) -> Double { (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) }
        var output = subject
        for i in 0..<n {
            let a = window[i], b = window[(i + 1) % n]
            let sign: Double = cross(a, b, centre) >= 0 ? 1 : -1
            func inside(_ p: P) -> Bool { cross(a, b, p) * sign >= 0 }
            func meet(_ p: P, _ q: P) -> P {
                let cp = cross(a, b, p), cq = cross(a, b, q)
                return p + (q - p) * (cp / (cp - cq))
            }
            let input = output
            output = []
            guard let last = input.last else { return [] }
            var previous = last
            for current in input {
                if inside(current) {
                    if !inside(previous) { output.append(meet(previous, current)) }
                    output.append(current)
                } else if inside(previous) {
                    output.append(meet(previous, current))
                }
                previous = current
            }
        }
        return output
    }

    /// The opening of a wall being built, open to the sky: `opening` is the
    /// outline of its top on the screen (convex), and the floor within lies
    /// `depth` points below it. The inner faces of the wall at the back show
    /// in shade, and the floor's earth below them.
    mutating func hollow(_ opening: [P], depth: Double) {
        typealias I = AlchemyNewBuildingsInk
        colour(opening, .colour(I.rawStoneShade))
        let floor = clipped(opening.map { $0 + P(0, depth) }, to: opening)
        if floor.count >= 3 {
            svg.polygon(floor, fill: .colour(I.earthShade))
            line(floor, closed: true, width: 0.5, opacity: 0.6)
        }
        line(opening, closed: true, width: 0.8)
    }

    // MARK: Round work

    /// A round tower's shaft, or any upright cylinder: centred on (`cx`, `cy`),
    /// `r` tiles in radius, from `h0` to `h1`, lit on its left and shaded on
    /// its right, with courses of stone round it unless `course` is nil. Its top
    /// is drawn when `top` is given.
    mutating func cylinder(_ cx: Double, _ cy: Double, _ r: Double, _ h0: Double, _ h1: Double, lit: String, mid: String,
                           shade: String, top: Paint? = nil, course: Double? = 4.4, brick: Double = 9, width: Double = 1.1,
                           fresh: Bool = false) {
        func band(_ a0: Double, _ a1: Double) -> [P] {
            arc(cx, cy, r, from: a0, to: a1, at: h0) + arc(cx, cy, r, from: a1, to: a0, at: h1)
        }
        colour(band(-45, 135), .colour(mid))
        colour(band(78, 135), .colour(lit))
        colour(band(-45, 8), .colour(shade))
        if let course {
            var d = PathData()
            var v = h0 + course, row = 0
            // Joints a stone apart along the face: about `brick` points of the screen at the front.
            let step = brick / (r * 45.25) * 180 / .pi
            while v < h1 - 0.6 {
                let ring = arc(cx, cy, r, from: -45, to: 135, at: v)
                d.move(ring[0])
                for p in ring.dropFirst() { d.line(p) }
                v += course
            }
            v = h0
            while v < h1 - 0.6 {
                var a = -45 + (row % 2 == 0 ? step / 2 : step)
                while a < 133 {
                    if a > -43 {
                        d.move(round(cx, cy, r, a, v + 0.4))
                        d.line(round(cx, cy, r, a, min(v + course, h1) - 0.4))
                    }
                    a += step
                }
                v += course
                row += 1
            }
            svg.path(d, stroke: .colour(AlchemyNewBuildingsInk.line), width: 0.5, opacity: fresh ? 0.4 : 0.5)
        }
        if let top {
            colour(arc(cx, cy, r, from: 0, to: 360, at: h1, steps: 36), top)
            line(arc(cx, cy, r, from: 0, to: 360, at: h1, steps: 36), closed: true, width: width)
        } else {
            line(arc(cx, cy, r, from: -45, to: 135, at: h1), width: width)
        }
        line(arc(cx, cy, r, from: -45, to: 135, at: h0), width: width)
        line([round(cx, cy, r, -45, h0), round(cx, cy, r, -45, h1)], width: width)
        line([round(cx, cy, r, 135, h0), round(cx, cy, r, 135, h1)], width: width)
    }

    /// A round tower of stone, from `h0` to `h1`, with a moulded footing.
    mutating func roundShaft(_ cx: Double, _ cy: Double, _ r: Double, _ h0: Double, _ h1: Double, fresh: Bool = false) {
        typealias I = AlchemyNewBuildingsInk
        let footing = min(5, h1 - h0)
        // The tower's shadow on the ground at its right.
        shadow(arc(cx + 0.1, cy - 0.05, r, from: -60, to: 60, at: h0) + [round(cx, cy, r, 60, h0)], opacity: 0.12)
        cylinder(cx, cy, r + 0.03, h0, h0 + footing, lit: I.stone, mid: I.stoneShade, shade: I.stoneDark, course: nil, width: 1)
        if h1 > h0 + footing {
            cylinder(cx, cy, r, h0 + footing, h1, lit: fresh ? I.rawStoneTop : I.stoneTop, mid: fresh ? I.rawStone : I.stone,
                     shade: fresh ? I.rawStoneShade : I.stoneShade, top: fresh ? .colour(I.rawStoneTop) : nil, course: 4.4,
                     brick: 8, fresh: fresh)
        }
        if fresh {
            // Being built, the tower is a ring of wall open at the top.
            hollow(arc(cx, cy, r - 0.08, from: 0, to: 360, at: h1, steps: 36), depth: min(9, h1 - h0 - 2))
        }
    }

    /// A slit for an archer on a round tower's face, at `degrees` round it and `v` points up.
    mutating func roundSlit(_ cx: Double, _ cy: Double, _ r: Double, at degrees: Double, _ v: Double, height: Double = 8) {
        typealias I = AlchemyNewBuildingsInk
        let foot = round(cx, cy, r, degrees, v)
        // Narrower the farther round the face it lies.
        let w = 0.9 * max(0.35, cos((degrees - 45) * .pi / 180))
        shape([foot + P(-w, 0), foot + P(w, 0), foot + P(w, -height), foot + P(-w, -height)], .colour(I.dark), width: 0.55)
        shape([foot + P(-w * 2.3, -height * 0.45), foot + P(w * 2.3, -height * 0.45), foot + P(w * 2.3, -height * 0.45 - 1.1),
               foot + P(-w * 2.3, -height * 0.45 - 1.1)], .colour(I.dark), width: 0.45)
    }

    /// The crown of a round tower standing at `h`: a parapet on corbels,
    /// standing out `out` tiles from the shaft, with `merlons` merlons round
    /// it. `inside` draws what rises within the parapet (a roof of slate, a
    /// banner) between its back and its front.
    mutating func roundBattlement(_ cx: Double, _ cy: Double, _ r: Double, at h: Double, out: Double = 0.05, merlons: Int = 10,
                                  inside: (inout AlchemyNewBuildingsPainter) -> Void = { _ in }) {
        typealias I = AlchemyNewBuildingsInk
        let ro = r + out, ri = ro - 0.07, solid = 5.0, m = 5.5
        // Corbels under the parapet's front.
        for k in 0..<9 {
            let a = -40 + 170 * Double(k) / 8
            let top = round(cx, cy, ro, a, h - 0.4), foot = round(cx, cy, r, a, h - 6)
            let w = 1.3 * max(0.4, cos((a - 45) * .pi / 180))
            shape([top + P(-w, 0), top + P(w, 0), foot + P(w, 0), foot + P(0, 1.2), foot + P(-w, 0)], .colour(I.stoneShade),
                  width: 0.5)
        }
        // The floor within, and the parapet's inner face at the back.
        colour(arc(cx, cy, ri, from: 0, to: 360, at: h, steps: 36), .colour(I.pavingShade))
        colour(arc(cx, cy, ri, from: 135, to: 315, at: h) + arc(cx, cy, ri, from: 315, to: 135, at: h + solid),
               .colour(I.stone))
        line(arc(cx, cy, ri, from: 135, to: 315, at: h), width: 0.6)
        // The back merlons, seen from within.
        let span = 360.0 / Double(merlons)
        for k in 0..<merlons {
            let a0 = 135 + span * Double(k) + span * 0.2, a1 = a0 + span * 0.55
            guard a1 <= 316 else { continue }
            let face = arc(cx, cy, ri, from: a0, to: a1, at: h + solid, steps: 4) + arc(cx, cy, ri, from: a1, to: a0, at: h + solid + m, steps: 4)
            colour(face, .colour(I.stone))
            colour(arc(cx, cy, ri, from: a0, to: a1, at: h + solid + m, steps: 4) + arc(cx, cy, ro, from: a1, to: a0, at: h + solid + m, steps: 4),
                   .colour(I.stoneTop))
            line(face, closed: true, width: 0.7)
        }
        // The back rim between the merlons.
        colour(arc(cx, cy, ro, from: 135, to: 315, at: h + solid) + arc(cx, cy, ri, from: 315, to: 135, at: h + solid), .colour(I.stoneTop))
        line(arc(cx, cy, ro, from: 135, to: 315, at: h + solid), width: 0.8)
        inside(&self)
        // The parapet's front, its rim, and the front merlons.
        cylinder(cx, cy, ro, h - 0.5, h + solid, lit: I.stoneTop, mid: I.stone, shade: I.stoneShade, course: nil, width: 1)
        colour(arc(cx, cy, ro, from: -45, to: 135, at: h + solid) + arc(cx, cy, ri, from: 135, to: -45, at: h + solid), .colour(I.stoneTop))
        line(arc(cx, cy, ri, from: -45, to: 135, at: h + solid), width: 0.6)
        for k in 0..<merlons {
            let a0 = -45 + span * Double(k) + span * 0.2, a1 = a0 + span * 0.55
            guard a1 <= 136 else { continue }
            let mid = (a0 + a1) / 2
            let paint = mid > 80 ? I.stoneTop : mid < 10 ? I.stoneShade : I.stone
            let face = arc(cx, cy, ro, from: a0, to: a1, at: h + solid, steps: 4) + arc(cx, cy, ro, from: a1, to: a0, at: h + solid + m, steps: 4)
            colour(arc(cx, cy, ro, from: a0, to: a1, at: h + solid + m, steps: 4) + arc(cx, cy, ri, from: a1, to: a0, at: h + solid + m, steps: 4),
                   .colour(I.stoneTop))
            colour(face, .colour(paint))
            line(face, closed: true, width: 0.8)
            line(arc(cx, cy, ri, from: a0, to: a1, at: h + solid + m, steps: 4), width: 0.5)
        }
    }

    /// A cone of slate on a round tower: its eaves a circle of `r` tiles at
    /// `h`, its point `rise` points above, and a gilt finial.
    @discardableResult
    mutating func cone(_ cx: Double, _ cy: Double, _ r: Double, at h: Double, rise: Double) -> P {
        typealias I = AlchemyNewBuildingsInk
        let apex = iso(cx, cy, h + rise)
        func slope(_ a0: Double, _ a1: Double) -> [P] { arc(cx, cy, r, from: a0, to: a1, at: h, steps: 12) + [apex] }
        colour(slope(-45, 135), .colour(I.teal))
        colour(slope(70, 135), .colour(I.tealLit))
        colour(slope(-45, 10), .colour(I.tealShade))
        // Courses of slate round the cone, and a few seams running up it.
        var d = PathData()
        for t in stride(from: 0.18, to: 0.9, by: 0.16) {
            let ring = arc(cx, cy, r * (1 - t), from: -45, to: 135, at: h + rise * t, steps: 12)
            d.move(ring[0]); for p in ring.dropFirst() { d.line(p) }
        }
        svg.path(d, stroke: .colour(I.tealDark), width: 0.6, opacity: 0.9)
        var seams = PathData()
        for a in stride(from: -25.0, to: 130, by: 22) {
            seams.move(round(cx, cy, r, a, h)); seams.line(apex)
        }
        svg.path(seams, stroke: .colour(I.tealDark), width: 0.4, opacity: 0.6)
        // The eaves, flared a little.
        let eaves = arc(cx, cy, r, from: -45, to: 135, at: h, steps: 18)
        colour(eaves + arc(cx, cy, r * 1.0, from: 135, to: -45, at: h - 1.6, steps: 18), .colour(I.tealDark))
        line([round(cx, cy, r, -45, h)] + [apex] + [round(cx, cy, r, 135, h)], width: 1.1)
        line(eaves.map { $0 + P(0, 1.6) }, width: 1)
        line([eaves.first!, eaves.first! + P(0, 1.6)], width: 0.8)
        line([eaves.last!, eaves.last! + P(0, 1.6)], width: 0.8)
        finial(at: apex)
        return apex
    }

    /// A gilt finial: a ball and a spike.
    mutating func finial(at p: P, size s: Double = 1) {
        typealias I = AlchemyNewBuildingsInk
        line([p, p - P(0, 6 * s)], width: 1.1)
        svg.circle(p - P(0, 2.4 * s), 1.5 * s, fill: .colour(I.gilt), stroke: .colour(I.line), width: 0.5)
        shape([p - P(0.8 * s, 4.6 * s), p - P(0, 7.6 * s), p - P(-0.8 * s, 4.6 * s)], .colour(I.giltLight), width: 0.5)
    }

    // MARK: Straight battlements

    /// Merlons along the top of a straight wall at `h`, from `a` to `b` along
    /// x (when `alongX`) or y, on the line `at` of the other axis, `depth`
    /// tiles thick toward the wall's inside. Merlons are drawn from the far end.
    mutating func merlons(alongX: Bool, from a: Double, to b: Double, at c: Double, depth: Double, on h: Double,
                          height m: Double = 6, size: Double = 0.13, gap: Double = 0.1) {
        typealias I = AlchemyNewBuildingsInk
        var t = a + gap / 2
        while t + size <= b + 0.001 {
            let (x0, x1) = alongX ? (t, t + size) : (min(c, c + depth), max(c, c + depth))
            let (y0, y1) = alongX ? (min(c, c + depth), max(c, c + depth)) : (t, t + size)
            block(x0, y0, x1, y1, h, h + m, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.75)
            t += size + gap
        }
    }

    // MARK: Timber, iron and materials

    /// A pole of timber from `a` to `b` on the screen, outlined.
    mutating func pole(_ a: P, _ b: P, width: Double = 1.6, colour paint: String = AlchemyNewBuildingsInk.timberLight) {
        svg.line([a, b], stroke: .colour(AlchemyNewBuildingsInk.line), width: width + 1.1)
        svg.line([a, b], stroke: .colour(paint), width: width)
    }

    /// A squared beam lying on the map from (x0, y0) to (x1, y1) at `h`, `size` points square.
    mutating func beam(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, on h: Double, size s: Double = 2.6) {
        typealias I = AlchemyNewBuildingsInk
        let a = iso(x0, y0, h), b = iso(x1, y1, h)
        let up = P(0, -s)
        let along = b - a
        let across = abs(along.x) > 0.01 && along.y / along.x > 0 ? P(-s * 0.9, s * 0.45) : P(s * 0.9, s * 0.45)
        colour([a, b, b + up, a + up], .colour(I.timber))
        colour([a + up, b + up, b + up - across, a + up - across], .colour(I.timberLight))
        line([a, b, b + up, a + up], closed: true, width: 0.8)
        line([a + up, a + up - across, b + up - across, b + up], width: 0.8)
    }

    /// Scaffolding: upright poles standing at `feet` on the map, from `h0` up
    /// `height` points, tied by ledgers between neighbours at each of `levels`,
    /// with boards at `boards` running toward `inward` (tiles along x and y).
    mutating func scaffold(_ feet: [(x: Double, y: Double)], from h0: Double, height: Double, levels: [Double],
                           boards: Double? = nil, inward: (x: Double, y: Double) = (0, -0.13)) {
        typealias I = AlchemyNewBuildingsInk
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
        // A short brace at the foot of each bay.
        for (a, b) in zip(feet, feet.dropFirst()) {
            let t = min(1, 0.32 / max(0.01, abs(b.x - a.x) + abs(b.y - a.y)))
            pole(iso(a.x, a.y, h0 + 1), iso(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, h0 + (levels.first ?? height)), width: 0.9,
                 colour: I.timber)
        }
        for foot in feet {
            pole(iso(foot.x, foot.y, h0), iso(foot.x, foot.y, h0 + height))
            for level in levels {
                let at = iso(foot.x, foot.y, h0 + level)
                line([at + P(-1.3, -0.9), at + P(1.3, 0.9)], width: 0.8)
            }
        }
    }

    /// Dressed stones stacked on the map from (x0, y0) to (x1, y1), from `h0`, `courses` high.
    mutating func stones(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, courses: Int) {
        let course = 3.6
        ashlar(x0, y0, x1, y1, h0, h0 + Double(courses) * course, course: course, stone: 7, fresh: true, width: 0.9)
    }

    /// Planks or squared beams stacked along x from `x0` to `x1` at `y`, `count` high.
    mutating func planks(_ x0: Double, _ x1: Double, _ y: Double, on h: Double = 0, count: Int = 4) {
        typealias I = AlchemyNewBuildingsInk
        for k in 0..<count {
            let base = h + Double(k) * 1.6
            block(x0 + Double(k % 2) * 0.03, y - 0.12, x1 - Double(k % 2) * 0.02, y + 0.12, base, base + 1.6,
                  top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark), width: 0.7)
        }
    }

    /// A trough of lime mortar on the map from (x, y), with a trowel standing in it.
    mutating func mortar(_ x: Double, _ y: Double, on h: Double) {
        typealias I = AlchemyNewBuildingsInk
        block(x, y, x + 0.34, y + 0.24, h, h + 2.8, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.8)
        colour(level(x + 0.04, y + 0.04, x + 0.3, y + 0.2, h + 2.8), .colour(I.plasterShade))
        line([iso(x + 0.1, y + 0.12, h + 3), iso(x + 0.24, y + 0.06, h + 7)], width: 1)
    }

    /// A keg of powder lying or standing at `p` on the screen, `size` across:
    /// staves of timber, hoops of iron, and the bung.
    mutating func keg(at p: P, size s: Double = 1, lying: Bool = false, marked: Bool = false) {
        typealias I = AlchemyNewBuildingsInk
        if lying {
            // Its end toward the viewer at the left, its body running back to the right.
            let body = [p + P(-1, -7.4 * s), p + P(7 * s, -7.4 * s - 3.5 * s), p + P(7 * s, -3.5 * s), p + P(-1, 0)]
            colour(body, .colour(I.timber))
            line(body, closed: true, width: 0.8)
            for t in [0.2, 0.8] {
                let a = p + P(-1 + 8 * s * t, -3.5 * s * t), b = a + P(0, -7.4 * s)
                line([a, b], width: 1.1)
            }
            svg.ellipse(p + P(-1, -3.7 * s) + shift * 0.6, 3.3 * s, 3.9 * s, fill: .colour(I.timberLight))
            svg.ellipse(p + P(-1, -3.7 * s), 3.3 * s, 3.9 * s, fill: .none, stroke: .colour(I.line), width: 0.8)
            svg.ellipse(p + P(-1, -3.7 * s), 2.3 * s, 2.9 * s, fill: .none, stroke: .colour(I.iron), width: 0.6)
            return
        }
        let w = 4.2 * s, h = 9 * s
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-w * 0.86, 0) + o)
            d.quad(p + P(-w * 1.12, -h / 2) + o, p + P(-w * 0.86, -h) + o)
            d.line(p + P(w * 0.86, -h) + o)
            d.quad(p + P(w * 1.12, -h / 2) + o, p + P(w * 0.86, 0) + o)
            d.close()
            return d
        }
        svg.ellipse(p + P(0.8, 0.4), w * 1.1, 1.6 * s, fill: .colour("#000000"), opacity: 0.15)
        colour(.colour(I.timber)) { d, o in d = outline(o) }
        colour([p + P(-w * 0.8, -h * 0.05) + shift, p + P(-w * 0.2, -h * 0.05) + shift, p + P(-w * 0.2, -h * 0.95) + shift,
                p + P(-w * 0.8, -h * 0.95) + shift], .colour(I.timberLight))
        line(width: 0.8) { d in d = outline(P(0, 0)) }
        for v in [0.2, 0.8] {
            line([p + P(-w * 1.02, -h * v), p + P(w * 1.02, -h * v)], width: 1.1)
        }
        line([p + P(w * 0.35, -h * 0.1), p + P(w * 0.4, -h * 0.9)], width: 0.4, opacity: 0.6)
        // The lid, and its bung.
        svg.ellipse(p + P(0, -h) + shift * 0.6, w * 0.86, 1.4 * s, fill: .colour(I.timberLight))
        svg.ellipse(p + P(0, -h), w * 0.86, 1.4 * s, fill: .none, stroke: .colour(I.line), width: 0.7)
        svg.circle(p + P(w * 0.25, -h), 0.6 * s, fill: .colour(I.dark))
        if marked {
            // A cross stencilled in the light colour, to mark the keg as powder.
            let c = p + P(0, -h / 2)
            svg.line([c + P(-1.4 * s, -1.4 * s), c + P(1.4 * s, 1.4 * s)], stroke: .colour(I.light), width: 0.8 * s)
            svg.line([c + P(-1.4 * s, 1.4 * s), c + P(1.4 * s, -1.4 * s)], stroke: .colour(I.light), width: 0.8 * s)
        }
    }

    // MARK: Team colour

    /// The Alchemy age's mark, in the light colour: the sign for gold, a ring with a point at its centre.
    mutating func mark(at p: P, radius r: Double) {
        typealias I = AlchemyNewBuildingsInk
        svg.ellipse(p, r, r, fill: .none, stroke: .colour(I.light), width: max(0.6, r * 0.32))
        svg.circle(p, r * 0.32, fill: .colour(I.light))
    }

    /// A pole standing at `foot`, `height` points tall, with a swallow-tailed
    /// pennant in the team's colour streaming to the right from its top,
    /// `length` points long, and an iron finial.
    mutating func pennant(at foot: P, height: Double, length: Double = 15) {
        typealias I = AlchemyNewBuildingsInk
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
        mark(at: top + P(5.4 * k, 5 * k), radius: 1.9 * k)
        line(width: 0.9) { d in d = cloth(P(0, 0)) }
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.line), width: 2.3)
        svg.line([foot, top - P(0, 1)], stroke: .colour(I.timberDark), width: 1.3)
        let f = top - P(0, 1)
        shape([f + P(-1.2, 0), f + P(0, -3.4), f + P(1.2, 0), f + P(0, 0.9)], .colour(I.ironLight), width: 0.7)
    }

    /// A great square banner flown from a pole standing at `foot`, `height`
    /// points tall: the cloth `width` wide and `length` long, rippling, in the
    /// team's colour with a border of the light colour and the age's mark.
    mutating func banner(at foot: P, height: Double, width w: Double = 20, length l: Double = 14) {
        typealias I = AlchemyNewBuildingsInk
        let top = foot - P(0, height)
        func cloth(_ o: P, inset e: Double) -> PathData {
            var d = PathData()
            let a = top + P(1.2 + e, 1 + e), b = top + P(w - e, 2.6 + e), c = top + P(w - e, 2.6 + l - e), f = top + P(1.2 + e, 1 + l - e)
            d.move(a + o)
            d.cubic(a + P(w * 0.3, -3) + o, b + P(-w * 0.35, 3) + o, b + o)
            d.line(c + o)
            d.cubic(c + P(-w * 0.35, 3) + o, f + P(w * 0.3, -3) + o, f + o)
            d.close()
            return d
        }
        colour(.colour(I.light)) { d, o in d = cloth(o, inset: 0) }
        colour(.team) { d, o in d = cloth(o, inset: 1.3) }
        mark(at: top + P(1.2 + w * 0.48, 1.5 + l * 0.5), radius: l * 0.2)
        line(width: 0.9) { d in d = cloth(P(0, 0), inset: 0) }
        line(width: 0.4, opacity: 0.7) { d in d = cloth(P(0, 0), inset: 1.3) }
        svg.line([foot, top - P(0, 2)], stroke: .colour(I.line), width: 2.6)
        svg.line([foot, top - P(0, 2)], stroke: .colour(I.timberDark), width: 1.5)
        let f = top - P(0, 2)
        shape([f + P(-1.3, 0), f + P(0, -3.8), f + P(1.3, 0), f + P(0, 1)], .colour(I.ironLight), width: 0.7)
    }

    /// A long banner in the team's colour hanging on a wall drawn with `wall`
    /// from `top`, `width` wide and `length` long, edged in the light colour,
    /// its foot cut to a point, with the age's mark on it, from an iron rod.
    mutating func hanging(_ u: Double, top v: Double, width: Double, length: Double) {
        typealias I = AlchemyNewBuildingsInk
        let r = width / 2
        let outer = [uv(u - r, v), uv(u + r, v), uv(u + r, v - length + 3), uv(u, v - length), uv(u - r, v - length + 3)]
        let e = 1.1
        let inner = [uv(u - r + e, v - 0.6), uv(u + r - e, v - 0.6), uv(u + r - e, v - length + 3.4), uv(u, v - length + 1.4),
                     uv(u - r + e, v - length + 3.4)]
        colour(outer, .colour(I.light))
        colour(inner, .team)
        mark(at: uv(u, v - length * 0.4), radius: width * 0.2)
        line(outer, closed: true, width: 0.9)
        line(inner, closed: true, width: 0.4, opacity: 0.7)
        line([uv(u - r - 1.4, v + 0.2), uv(u + r + 1.4, v + 0.2)], width: 1.4)
        svg.line([uv(u - r - 1.4, v + 0.2), uv(u + r + 1.4, v + 0.2)], stroke: .colour(I.iron), width: 0.6)
    }
}
