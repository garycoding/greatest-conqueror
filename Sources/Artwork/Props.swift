// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// What people hold, and the marks that show a blow landing. Each is drawn at a
// hand, along a direction given, like the limbs, in degrees from straight
// down, positive toward the front.

extension Drawing {
    /// A stone axe, its handle running from the hand toward `degrees` and its
    /// blade at the far end, its edge leading the swing (the approved worker's axe).
    mutating func axe(at hand: P, degrees: Double) {
        let u = P.direction(degrees), across = P(-u.y, u.x)
        let head = hand + u * 15
        svg.line([hand - u * 3, head], stroke: .colour(Ink.handle), width: 3)
        svg.polygon([head + across * 0.5 + u * 0.5, head + across * 6 + u * 2, head + across * 6 - u * 6.5,
                     head + across * 0.5 - u * 4.5], fill: .colour(Ink.stone), stroke: .colour(Ink.line), width: 1.3)
    }

    /// A builder's mallet: a short handle and a stone head lashed across it.
    mutating func mallet(at hand: P, degrees: Double) {
        let u = P.direction(degrees), across = P(-u.y, u.x)
        let head = hand + u * 11.5
        svg.line([hand - u * 2.5, head], stroke: .colour(Ink.handle), width: 2.6)
        let corners = [head + across * 4 + u * 1.6, head + across * 3.2 + u * 3.2, head - across * 3.4 + u * 3,
                       head - across * 4.2 + u * 1, head - across * 3.4 - u * 2.6, head + across * 3.4 - u * 2.4]
        // The stone's colour a little out of register with its line.
        svg.polygon(corners.map { $0 + P(-0.7, 0.6) }, fill: .colour(Ink.stone))
        svg.polygon(corners, fill: .none, stroke: .colour(Ink.line), width: 1.3)
        // The lashing.
        svg.line([head - across * 1.6 - u * 2.4, head - across * 1.6 + u * 3], stroke: .colour(Ink.darkHide), width: 1.1)
        svg.line([head + across * 1.4 - u * 2.4, head + across * 1.4 + u * 3], stroke: .colour(Ink.darkHide), width: 1.1)
    }

    /// A heavy wooden club, thin at the grip and swelling to a rounded head.
    mutating func club(at hand: P, degrees: Double, length: Double = 20) {
        let u = P.direction(degrees), across = P(-u.y, u.x)
        let grip = hand - u * 2.5, end = hand + u * length
        func outline(_ shift: P) -> PathData {
            var d = PathData()
            d.move(grip + across * 1.3 + shift)
            d.quad(hand + u * (length * 0.55) + across * 2 + shift, end + across * 3.5 + shift)
            d.quad(end + u * 4.2 + shift, end - across * 3.5 + shift)
            d.quad(hand + u * (length * 0.55) - across * 2 + shift, grip - across * 1.3 + shift)
            d.close()
            return d
        }
        svg.path(outline(P(-0.8, 0.7)), fill: .colour(Ink.wood))
        svg.path(outline(P(0, 0)), stroke: .colour(Ink.line), width: 1.4)
        // Knots in the wood.
        for (t, side) in [(0.62, 1.0), (0.86, -1.0)] {
            let at = hand + u * (length * t) + across * (side * 1.2)
            svg.line([at - u * 1.1, at + u * 1.1], stroke: .colour(Ink.line), width: 1)
        }
    }

    /// A walking staff with a knot at its head, through the hand at `degrees`
    /// (the angle of its lower end), reaching `above` units up and `below` down.
    mutating func staff(at hand: P, degrees: Double, above: Double, below: Double) {
        let u = P.direction(degrees)
        let top = hand - u * above, bottom = hand + u * below
        svg.line([bottom, top], stroke: .colour(Ink.wood), width: 2.6)
        svg.line([bottom + P(0.9, 0), top + P(0.9, 0)], stroke: .colour(Ink.line), width: 0.8, opacity: 0.55)
        svg.circle(top - u * 1.2 + P(-0.5, 0.4), 2.5, fill: .colour(Ink.wood))
        svg.circle(top - u * 1.2, 2.5, fill: .none, stroke: .colour(Ink.line), width: 1.3)
    }

    /// A stone tablet scored with marks, held at `hand` and turned by `degrees`;
    /// seen from the back (`marked` false), its face is blank.
    mutating func tablet(at hand: P, degrees: Double, marked: Bool = true) {
        svg.group(at: hand, turned: degrees) { svg in
            svg.path("M-3.6,-9.4 h7.6 q1.2,0 1.2,1.2 v9.4 q0,1.2 -1.2,1.2 h-7.6 q-1.2,0 -1.2,-1.2 v-9.4 q0,-1.2 1.2,-1.2 Z",
                     fill: .colour(Ink.stone))
            svg.path("M-3,-10 h7.6 q1.2,0 1.2,1.2 v9.4 q0,1.2 -1.2,1.2 h-7.6 q-1.2,0 -1.2,-1.2 v-9.4 q0,-1.2 1.2,-1.2 Z",
                     stroke: .colour(Ink.line), width: 1.2)
            if marked {
                svg.path("M-2.4,-7.4 h5.4 M-2.4,-5 h3.8 M-2.4,-2.6 h5 M2.6,-5 l1.2,0", stroke: .colour(Ink.line), width: 0.8)
            }
        }
    }

    /// A sling: two cords from the hand to a pouch holding a stone, `length` along `degrees`.
    mutating func sling(at hand: P, degrees: Double, length: Double = 10, loaded: Bool = true) {
        let u = P.direction(degrees), across = P(-u.y, u.x)
        let pouch = hand + u * length
        svg.line([hand, pouch + across * 1.3], stroke: .colour(Ink.line), width: 0.9)
        svg.line([hand, pouch - across * 1.3], stroke: .colour(Ink.line), width: 0.9)
        svg.group(at: pouch, turned: -degrees) { svg in
            svg.ellipse(P(0, 0.4), 2, 2.4, fill: .colour(Ink.hide), stroke: .colour(Ink.line), width: 1)
            if loaded { svg.circle(P(0, 1.6), 1.3, fill: .colour(Ink.stone), stroke: .colour(Ink.line), width: 0.8) }
        }
    }

    /// A slinger's stone in flight.
    mutating func stone(at p: P) {
        svg.circle(p, 1.5, fill: .colour(Ink.stone), stroke: .colour(Ink.line), width: 0.9)
    }

    /// A pole held at `hand`, standing upright with a pennant in the team's colour
    /// streaming back from its top; `wave` moves the cloth through its ripple.
    /// `reach` is how far the cloth streams toward the screen's left as a share
    /// of its length (seen from another side, less; negative, to the right).
    mutating func banner(at hand: P, foot: Double, top: Double, wave: Double, reach: Double = 1) {
        let x = hand.x
        svg.line([P(x, foot), P(x, top)], stroke: .colour(Ink.handle), width: 2.4)
        // The pennant: a swallowtail whose free edge ripples.
        func w(_ along: Double) -> Double { 1.5 * sin(2 * .pi * wave - along * 2.6) * along }
        let t = top + 1.5
        var d = PathData()
        d.move(P(x, t))
        d.quad(P(x - 8 * reach, t - 1.5 + w(0.5)), P(x - 17 * reach, t + 1 + w(1)))
        d.line(P(x - 12.5 * reach, t + 5.5 + w(0.8)))
        d.line(P(x - 17 * reach, t + 10 + w(1)))
        d.quad(P(x - 8 * reach, t + 12 + w(0.5)), P(x, t + 11))
        d.close()
        var shifted = PathData()
        shifted.move(P(x - 0.8, t + 0.8))
        shifted.quad(P(x - 8 * reach - 0.8, t - 0.7 + w(0.5)), P(x - 17 * reach - 0.8, t + 1.8 + w(1)))
        shifted.line(P(x - 12.5 * reach - 0.8, t + 6.3 + w(0.8)))
        shifted.line(P(x - 17 * reach - 0.8, t + 10.8 + w(1)))
        shifted.quad(P(x - 8 * reach - 0.8, t + 12.8 + w(0.5)), P(x - 0.8, t + 11.8))
        shifted.close()
        svg.path(shifted, fill: .team)
        // A sun on the cloth, in the light colour.
        svg.circle(P(x - 6 * reach, t + 5.6 + w(0.35)), 2 * min(1, abs(reach) + 0.25), fill: .colour(Ink.light))
        svg.path(d, stroke: .colour(Ink.line), width: 1.3)
        // The finial.
        svg.path("M\(num(x - 1.6)),\(num(top + 0.4)) L\(num(x)),\(num(top - 3.4)) L\(num(x + 1.6)),\(num(top + 0.4)) Z",
                 fill: .colour(Ink.stone), stroke: .colour(Ink.line), width: 1)
    }

    // MARK: Marks

    /// Chips of wood flying from a blow (the approved chop's).
    mutating func chips(at p: P) {
        svg.path("M\(num(p.x)),\(num(p.y)) l6,-5 M\(num(p.x + 1)),\(num(p.y + 7)) l7,0 M\(num(p.x)),\(num(p.y + 14)) l6,4",
                 stroke: .colour(Ink.line), width: 1.3)
    }

    /// Short lines bursting from the point where a blow lands.
    mutating func impact(at p: P, size: Double = 1) {
        var d = PathData()
        for angle in stride(from: 20.0, through: 160.0, by: 35.0) {
            let u = P.direction(angle)
            d.move(p + u * (3 * size))
            d.line(p + u * (7 * size))
        }
        svg.path(d, stroke: .colour(Ink.line), width: 1.3)
    }

    /// Short lines bursting from `p` between the directions `from` and `to`
    /// (degrees from straight down, positive toward the front; 180 is straight up).
    mutating func burst(at p: P, from: Double, to: Double, size: Double = 1) {
        var d = PathData()
        for i in 0..<5 {
            let u = P.direction(mix(from, to, Double(i) / 4))
            d.move(p + u * (2.6 * size))
            d.line(p + u * (6 * size))
        }
        svg.path(d, stroke: .colour(Ink.line), width: 1.2)
    }

    /// The arc a swung weapon leaves behind it: around `centre`, at `radius`,
    /// from `from` to `to` degrees.
    mutating func swish(around centre: P, radius: Double, from: Double, to: Double) {
        var d = PathData()
        let steps = 6
        for i in 0...steps {
            let a = mix(from, to, Double(i) / Double(steps))
            let p = centre + P.direction(a) * radius
            if i == 0 { d.move(p) } else { d.line(p) }
        }
        svg.path(d, stroke: .colour(Ink.line), width: 1.1, opacity: 0.6)
        var inner = PathData()
        for i in 0...steps {
            let a = mix(from, to, 0.35 + 0.65 * Double(i) / Double(steps))
            let p = centre + P.direction(a) * (radius - 3)
            if i == 0 { inner.move(p) } else { inner.line(p) }
        }
        svg.path(inner, stroke: .colour(Ink.line), width: 1, opacity: 0.45)
    }

    /// Three short strokes above the head: a thought arriving.
    mutating func insight() {
        svg.path("M-3,-74 l-2,-3.6 M2.6,-76 l0,-4 M8,-74 l2,-3.6", stroke: .colour(Ink.line), width: 1.3)
    }
}
