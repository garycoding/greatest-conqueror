// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The drawing kit the bridge's looks share. A piece is drawn in the bridge's
// own coordinates: `u` along the run, in tiles from the tile's centre; `V`
// across the whole bridge, from -1 at its far edge through 0 at the line
// between the lanes to 1 at its near edge (the second row's side, toward the
// screen's foot); and `h` in points above the water. Along x, u is the map's
// x and V its y; along y the two change places, so that one drawing gives
// both runs, each lit as every building is lit: the face looking toward +y
// (the screen's lower left) in the light, the face looking toward +x (its
// lower right) in shade.
//
// The deck rises over the piece from `back` points at its back edge (u =
// -0.5) to `front` at its front edge (u = 0.5). A point at or above the
// deck's height at a bank (`BridgesLook.deckHeight`) rises with it in full,
// a point lower down in proportion to its height, and the water not at all,
// so that piers and piles stretch from the water to the deck.

/// Draws one layer of a bridge piece: its picture or its team-colour mask.
struct BridgesPainter {
    var svg: SVG
    let run: BridgeRun
    /// 0 for the far lane, 1 for the near.
    let lane: Int
    let back: Double, front: Double
    /// Whether the piece is the middle of its row.
    let middle: Bool

    /// How far a field of colour sits from its line on the screen, in points:
    /// the slight misregistration of the style (docs/art-style.md).
    static let register = P(-1.0, 0.7)
    /// The smaller shift of small parts: posts, piles, stones.
    static let nudge = P(-0.6, 0.45)
    /// How far a part that runs the length of the piece is drawn past each
    /// edge of the tile, so that two pieces side by side overlap rather than
    /// leave a hairline where their anti-aliased edges meet.
    static let overlap = 0.02
    /// The deck's height at a bank.
    static let deck = BridgesLook.deckHeight

    init(layer: Layer, place: BridgePlace) {
        svg = SVG(layer: layer)
        run = place.run
        lane = place.lane
        back = Double(place.heights.back)
        front = Double(place.heights.front)
        middle = place.middle
    }

    /// Whether this is the near lane.
    var near: Bool { lane == 1 }
    /// The lane's outer edge across the bridge: -1 or 1.
    var outer: Double { near ? 1 : -1 }
    /// The lane's half of the bridge across, from the far side to the near: (-1, 0) or (0, 1).
    var span: (Double, Double) { near ? (0, 1) : (-1, 0) }

    // MARK: The projection

    /// How far the deck has risen at `u` along the piece, in points.
    func rise(_ u: Double) -> Double { back + (front - back) * (min(max(u, -0.5), 0.5) + 0.5) }

    /// The deck's walking surface at `u`, in points above the water.
    func deckAt(_ u: Double) -> Double { Self.deck + rise(u) }

    /// The screen point `h` points above the water at `u` along the run and
    /// `V` across the bridge, raised with the deck as the kit's note says.
    func at(_ u: Double, _ V: Double, _ h: Double = 0) -> P {
        fixed(u, V, h + rise(u) * min(max(h / Self.deck, 0), 1))
    }

    /// The screen point exactly `h` points above the water, not raised with
    /// the deck: for what is shaped to the rise already, such as an arch.
    func fixed(_ u: Double, _ V: Double, _ h: Double) -> P {
        let v = V - (near ? 0.5 : -0.5)
        let x = run == .alongX ? u : v, y = run == .alongX ? v : u
        return P((x - y) * 32, (x + y) * 16 - h)
    }

    /// A level rectangle from `u0` to `u1` along and `v0` to `v1` across, at
    /// height `h`.
    func level(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, _ h: Double) -> [P] {
        [at(u0, v0, h), at(u1, v0, h), at(u1, v1, h), at(u0, v1, h)]
    }

    /// An upright face across the run at `u`, from `v0` to `v1`, from `h0` up to `h1`.
    func across(_ u: Double, _ v0: Double, _ v1: Double, _ h0: Double, _ h1: Double) -> [P] {
        [at(u, v0, h0), at(u, v1, h0), at(u, v1, h1), at(u, v0, h1)]
    }

    /// An upright face along the run at `v`, from `u0` to `u1`, from `h0` up to `h1`.
    func along(_ v: Double, _ u0: Double, _ u1: Double, _ h0: Double, _ h1: Double) -> [P] {
        [at(u0, v, h0), at(u1, v, h0), at(u1, v, h1), at(u0, v, h1)]
    }

    /// The colour of a face that looks across the run toward the viewer (+v):
    /// lit along x, where it faces +y, and in shade along y.
    func side(_ lit: String, _ shade: String) -> String { run == .alongX ? lit : shade }

    /// The colour of a face that looks along the run toward the viewer (+u):
    /// in shade along x, where it faces +x, and lit along y.
    func end(_ lit: String, _ shade: String) -> String { run == .alongX ? shade : lit }

    // MARK: Colour and line

    /// A flat field of colour, a little out of register with its line.
    mutating func colour(_ points: [P], _ paint: Paint, shift: P = BridgesPainter.register, opacity: Double = 1) {
        svg.polygon(points.map { $0 + shift }, fill: paint, opacity: opacity)
    }

    /// The dark line through the points.
    mutating func line(_ points: [P], closed: Bool = false, width: Double = 1, colour: String = BridgesInk.line,
                       opacity: Double = 1) {
        var d = PathData()
        d.move(points[0])
        for point in points.dropFirst() { d.line(point) }
        if closed { d.close() }
        svg.path(d, stroke: .colour(colour), width: width, opacity: opacity)
    }

    /// A shape: its colour, then its line all round.
    mutating func shape(_ points: [P], _ paint: Paint, width: Double = 0.9, shift: P = BridgesPainter.register) {
        colour(points, paint, shift: shift)
        line(points, closed: true, width: width)
    }

    /// A darker film over what is drawn: shadow on the water or under a vault.
    mutating func film(_ points: [P], opacity: Double) {
        svg.polygon(points, fill: .colour(BridgesInk.line), opacity: opacity)
    }

    /// A timber or a bar from `a` to `b`, `width` points thick on the screen:
    /// its colour a little out of register, then its line.
    mutating func pole(_ a: P, _ b: P, width: Double, colour paint: String, line: Double = 0.8) {
        let d = b - a, l = max(0.001, (d.x * d.x + d.y * d.y).squareRoot())
        let n = P(-d.y / l, d.x / l) * (width / 2)
        shape([a + n, b + n, b - n, a - n], .colour(paint), width: line, shift: BridgesPainter.nudge)
    }

    /// An upright post standing at (`u`, `v`) from `h0` to `h1`.
    mutating func post(_ u: Double, _ v: Double, _ h0: Double, _ h1: Double, width: Double, colour: String,
                       line: Double = 0.8) {
        pole(at(u, v, h0), at(u, v, h1), width: width, colour: colour, line: line)
    }

    /// A block from `u0` to `u1` along and `v0` to `v1` across, from `h0` up
    /// to `h1`: its top, the face toward +v and the face toward +u, each
    /// coloured as the light falls on it, then its line.
    mutating func block(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double, _ h0: Double, _ h1: Double,
                        top: String, lit: String, shade: String, width: Double = 0.8, shift: P = BridgesPainter.nudge) {
        colour(along(v1, u0, u1, h0, h1), .colour(side(lit, shade)), shift: shift)
        colour(across(u1, v0, v1, h0, h1), .colour(end(lit, shade)), shift: shift)
        colour(level(u0, u1, v0, v1, h1), .colour(top), shift: shift)
        line([at(u0, v1, h0), at(u1, v1, h0), at(u1, v0, h0), at(u1, v0, h1), at(u0, v0, h1), at(u0, v1, h1)],
             closed: true, width: width)
        line([at(u0, v1, h1), at(u1, v1, h1), at(u1, v0, h1)], width: width * 0.8)
        line([at(u1, v1, h1), at(u1, v1, h0)], width: width * 0.8)
    }

    /// A slack cord from `a` to `b`, hanging `sag` points at its middle: its
    /// colour a little out of register, then a thin line.
    mutating func cord(_ a: P, _ b: P, sag: Double, colour: String, width: Double = 1.5) {
        func trace(_ o: P) -> PathData {
            var d = PathData()
            d.move(a + o)
            d.quad((a + b) * 0.5 + P(0, 2 * sag) + o, b + o)
            return d
        }
        svg.path(trace(BridgesPainter.nudge), stroke: .colour(colour), width: width)
        svg.path(trace(P(0, 0)), stroke: .colour(BridgesInk.line), width: 0.6)
    }

    /// Rings on the water about the foot of a pile or a pier at `foot`, `r`
    /// points wide: the front of an ellipse in the light of the water's waves.
    mutating func ripple(at foot: P, _ r: Double) {
        var d = PathData()
        d.move(foot + P(-r, -0.2))
        d.quad(foot + P(0, r * 0.55), foot + P(r, -0.2))
        svg.path(d, stroke: .colour(BridgesInk.ripple), width: 0.8, opacity: 0.9)
        var e = PathData()
        e.move(foot + P(-r - 1.8, 1.2))
        e.quad(foot + P(-r * 0.4, 2.4), foot + P(-r * 0.1, 2.1))
        svg.path(e, stroke: .colour(BridgesInk.ripple), width: 0.6, opacity: 0.7)
    }

    /// The part of a pile or a pier below the water, `width` wide at `foot`:
    /// the water's own colour unknown, a dark film suggests its depth.
    mutating func submerged(at foot: P, width: Double, depth: Double = 2.2) {
        let r = width / 2
        film([foot + P(-r, 0), foot + P(r, 0), foot + P(r * 0.8, depth), foot + P(-r * 0.8, depth)], opacity: 0.22)
    }

    /// A small swallowtail pennant in the team's colour on a staff whose foot
    /// is at `foot`, `height` points tall, with a dot in the light colour.
    mutating func pennant(at foot: P, height: Double, staff: String) {
        let top = foot - P(0, height)
        func cloth(_ o: P) -> PathData {
            var d = PathData()
            d.move(top + P(0.4, 0.9) + o)
            d.quad(top + P(4.4, 0.2) + o, top + P(8.8, 1.5) + o)
            d.line(top + P(6.4, 3.4) + o)
            d.line(top + P(8.8, 5.4) + o)
            d.quad(top + P(4.4, 6.1) + o, top + P(0.4, 6) + o)
            d.close()
            return d
        }
        svg.line([foot, top - P(0, 0.6)], stroke: .colour(staff), width: 1.3)
        svg.line([foot + P(0.55, 0), top + P(0.55, 0)], stroke: .colour(BridgesInk.line), width: 0.45, opacity: 0.8)
        svg.path(cloth(BridgesPainter.nudge), fill: .team)
        svg.circle(top + P(3.2, 3.3), 0.95, fill: .colour(BridgesInk.light))
        svg.path(cloth(P(0, 0)), stroke: .colour(BridgesInk.line), width: 0.7)
        svg.circle(top - P(0, 1), 0.9, fill: .colour(BridgesInk.finial), stroke: .colour(BridgesInk.line), width: 0.5)
    }

    /// A short cloth in the team's colour hanging from `top`, `length` points
    /// long, stirring a little: the near lane's mark of its owner.
    mutating func banner(at top: P, length: Double, width: Double = 4.2) {
        func cloth(_ o: P) -> PathData {
            var d = PathData()
            d.move(top + P(-width / 2, 0) + o)
            d.line(top + P(width / 2, 0) + o)
            d.quad(top + P(width / 2 + 0.6, length * 0.5) + o, top + P(width / 2, length) + o)
            d.line(top + P(0, length - 1.6) + o)
            d.line(top + P(-width / 2, length) + o)
            d.quad(top + P(-width / 2 + 0.5, length * 0.5) + o, top + P(-width / 2, 0) + o)
            d.close()
            return d
        }
        svg.path(cloth(BridgesPainter.nudge), fill: .team)
        svg.circle(top + P(0, length * 0.42), 0.9, fill: .colour(BridgesInk.light))
        svg.path(cloth(P(0, 0)), stroke: .colour(BridgesInk.line), width: 0.6)
        svg.line([top + P(-width / 2 - 0.8, 0), top + P(width / 2 + 0.8, 0)], stroke: .colour(BridgesInk.line), width: 0.9)
    }

    /// The owner's colour on the piece: a pennant on the far lane's rail, a
    /// banner on the near lane's; `farFoot` and `nearTop` are where each goes.
    mutating func colours(farFoot: P, nearTop: P, staff: String, length: Double = 5) {
        if near { banner(at: nearTop, length: length) } else { pennant(at: farFoot, height: 7.5, staff: staff) }
    }
}

/// The colours every look shares: the line, the light, and the water's marks.
enum BridgesInk {
    static let line = Ink.line
    static let light = Ink.light
    /// The waves' light on the water (`TerrainInk.shallowLight`).
    static let ripple = TerrainInk.shallowLight
    /// The knob atop a pennant's staff.
    static let finial = "#c9a35a"
}
