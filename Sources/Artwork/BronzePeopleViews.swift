// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The geometry the Bronze age's people need in the views other than the side
// (ruled 2026-11-21: eight facings, five views drawn, the other three
// mirrored), beyond what the figure kit gives (FigureViews.swift). It is used
// only when `Drawing.view` is not the side, so that the side drawing stays as
// it was.
//
// Three things are placed here. A thing held in a hand lies in the figure's
// own upright plane, as the arm swings: its run toward the figure's front is
// shortened by the view's turn, and its height kept. A thing drawn on a
// garment in profile is spread across the garment as the view shows it, or put
// at a place round the body (the front, the back, a flank) and drawn over the
// body or under it as that place faces the viewer or not. And the head is
// taken as a round section, so that a cap, a helmet or a patch of hair can be
// given by its edge at each turn about the head and drawn in any view.

enum BronzePeopleViews {
    // MARK: Held things

    /// How a run toward the figure's front shows across the screen in a view:
    /// shortened by the turn, but never under three tenths, so that a thing seen
    /// end on keeps some breadth and the side it leans to.
    static func across(_ view: SpriteView) -> Double { max(abs(cos(view.yaw * .pi / 180)), 0.3) }

    /// The mapping for a thing held in a hand and drawn in profile about the
    /// hand there: in this view, about the hand where it falls, its run toward
    /// the front shortened.
    static func held(_ d: Drawing, front: Bool) -> (P) -> P {
        let from = front ? d.joints.frontHand : d.joints.backHand
        return carried(d.view, from: from, to: d.hand(front: front))
    }

    /// The mapping that carries a point drawn in profile about `from` to `to`, its run toward the front shortened.
    static func carried(_ view: SpriteView, from: P, to: P) -> (P) -> P {
        let k = across(view)
        return { p in to + P((p.x - from.x) * k, p.y - from.y) }
    }

    /// A direction in the figure's own plane (degrees from straight down,
    /// positive toward the front) as it shows on the screen, and how far a unit
    /// along it reaches there.
    static func onScreen(_ view: SpriteView, _ degrees: Double) -> (degrees: Double, reach: Double) {
        let u = P.direction(degrees)
        let x = u.x * across(view)
        return (atan2(x, u.y) * 180 / .pi, (x * x + u.y * u.y).squareRoot())
    }

    // MARK: Garments

    /// Where a shape's edges cross the height `y`, if it reaches it.
    static func span(_ shape: [P], at y: Double) -> (low: Double, high: Double)? {
        var xs: [Double] = []
        for k in shape.indices {
            let a = shape[k], b = shape[(k + 1) % shape.count]
            if (a.y - y) * (b.y - y) <= 0, a.y != b.y { xs.append(a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y)) }
        }
        guard let low = xs.min(), let high = xs.max(), high > low else { return nil }
        return (low, high)
    }

    /// A point drawn in profile on a garment whose profile is `outline`, spread
    /// across the garment as this view shows it (`Drawing.turned`): for a
    /// pattern that runs round the body, a belt, a fringe at the hem.
    static func spread(_ d: Drawing, _ p: P, on outline: [P]) -> P {
        guard d.view != .side, let side = span(outline, at: p.y), let seen = span(d.turned(outline), at: p.y) else { return p }
        let t = (p.x - side.low) / (side.high - side.low)
        return P(seen.low + t * (seen.high - seen.low), p.y)
    }

    /// A place round a garment at height `y`: `degrees` round from the figure's
    /// front toward its right side (90), its back (180) and its left (270), at
    /// `out` beyond the garment. The point on the screen, and how far the place
    /// faces the viewer, from 1 (straight at the viewer) to -1 (straight away).
    static func round(_ d: Drawing, on outline: [P], at y: Double, degrees: Double, out: Double = 0) -> (point: P, facing: Double) {
        let side = span(outline, at: y) ?? (-8, 8)
        let centre = (side.low + side.high) / 2, half = (side.high - side.low) / 2 + out, width = half * 0.95
        let a = degrees * .pi / 180, yaw = d.yaw * .pi / 180
        let x = centre + half * cos(a), z = width * sin(a)
        return (P(x * cos(yaw) - z * sin(yaw), y), sin(a + yaw))
    }

    /// A band worn across the body from `top` (a height and a place round the
    /// body, as `round` takes them) to `bottom`, running round by the shorter
    /// way given by `via` (the place it crosses between them), `width` high:
    /// the runs of it that face the viewer, each its upper edge then its lower.
    static func across(_ d: Drawing, on outline: [P], top: (y: Double, degrees: Double), bottom: (y: Double, degrees: Double),
                       via: Double, width: Double) -> [[P]] {
        // The turn from the top to the place it crosses, and on to the bottom.
        func unwrap(_ a: Double, near b: Double) -> Double {
            var a = a
            while a - b > 180 { a -= 360 }
            while b - a > 180 { a += 360 }
            return a
        }
        let middle = unwrap(via, near: top.degrees), end = unwrap(bottom.degrees, near: middle)
        var runs: [[(P, P)]] = [], run: [(P, P)] = []
        for i in 0...20 {
            let t = Double(i) / 20
            let degrees = t < 0.5 ? mix(top.degrees, middle, t * 2) : mix(middle, end, t * 2 - 1)
            let y = mix(top.y, bottom.y, t)
            let place = round(d, on: outline, at: y, degrees: degrees, out: 0.3)
            if place.facing > -0.05 {
                run.append((place.point + P(0, -width / 2), place.point + P(0, width / 2)))
            } else if !run.isEmpty { runs.append(run); run = [] }
        }
        if !run.isEmpty { runs.append(run) }
        return runs.filter { $0.count > 1 }.map { run in run.map(\.0) + run.reversed().map(\.1) }
    }

    /// Whether the figure's back is toward the viewer in this view.
    static func seesBack(_ view: SpriteView) -> Bool { view == .back || view == .backQuarter }

    // MARK: The head

    /// The head's outline, about which caps and hair are drawn (as `Drawing.headInView` draws it).
    static let headCentre = -57.5, headWide = 11.0, headHigh = 10.2

    /// The head's half breadth at height `y`, `out` beyond its outline.
    static func headRadius(_ y: Double, out: Double) -> Double {
        let t = (y - headCentre) / (headHigh + out)
        return (headWide + out) * max(0, 1 - t * t).squareRoot()
    }

    /// An edge round the head, given by its height at the front, over the ears and at the back.
    static func edge(front: Double, side: Double, back: Double) -> @Sendable (Double) -> Double {
        { degrees in
            let c = cos(degrees * .pi / 180)
            return side + (front - back) / 2 * c + ((front + back) / 2 - side) * c * c
        }
    }

    /// A cap over the head in a view: the head's outline, `out` beyond it, over
    /// the crown down to the cap's edge, which is at `rim(degrees)` round the head
    /// from the face (0) toward the right ear (90) and the nape (180). The crown
    /// stands `crown` higher than the head's, as a wrapped cloth or a helmet does.
    static func dome(_ view: SpriteView, out: Double, crown: Double = 0, rim: (Double) -> Double) -> [P] {
        let yaw = view.yaw
        var points: [P] = []
        // The edge across the side of the head that faces the viewer, from the screen's right to its left.
        for i in 0...24 {
            let turn = Double(i) * 7.5
            let y = rim(turn - yaw)
            points.append(P(headRadius(y, out: out) * cos(turn * .pi / 180), y))
        }
        // The outline over the crown, from the left end of the edge to its right end.
        let a = points.last!, b = points.first!
        let wide = headWide + out, high = headHigh + out
        var from = atan2(headCentre - a.y, -headRadius(a.y, out: out) / wide * high)
        if from < 0 { from += 2 * .pi }
        let to = atan2(headCentre - b.y, headRadius(b.y, out: out) / wide * high)
        let low = max(sin(from), sin(to), 0)
        for i in 1..<16 {
            let t = from + (to - from) * Double(i) / 16
            let rise = max(0, (sin(t) - low) / (1 - low))
            points.append(P(wide * cos(t), headCentre - high * sin(t) - crown * rise))
        }
        return points
    }

    /// A line round the head at `y(degrees)`, across the side that faces the viewer, from the screen's right to its left.
    static func ring(_ view: SpriteView, out: Double, _ y: (Double) -> Double) -> [P] {
        (0...24).map { i in
            let turn = Double(i) * 7.5
            let at = y(turn - view.yaw)
            return P(headRadius(at, out: out) * cos(turn * .pi / 180), at)
        }
    }

    /// A patch on the head's surface (hair, the cloth of a cap seen at the
    /// edge) from `from` to `to` degrees round the head, between the heights
    /// `top` and `bottom` there: the runs of it that face the viewer.
    static func patch(_ view: SpriteView, from: Double, to: Double, out: Double, top: (Double) -> Double,
                      bottom: (Double) -> Double) -> [[P]] {
        let yaw = view.yaw
        var runs: [[Double]] = [], run: [Double] = []
        let steps = max(Int((to - from) / 5), 2)
        for i in 0...steps {
            let a = from + (to - from) * Double(i) / Double(steps)
            let facing = sin((a + yaw) * .pi / 180) >= -0.02
            if facing { run.append(a) } else if !run.isEmpty { runs.append(run); run = [] }
        }
        if !run.isEmpty { runs.append(run) }
        return runs.filter { $0.count > 1 }.map { angles in
            func at(_ a: Double, _ y: Double) -> P { P(headRadius(y, out: out) * cos((a + yaw) * .pi / 180), y) }
            return angles.map { at($0, top($0)) } + angles.reversed().map { at($0, bottom($0)) }
        }
    }

    /// A point on the head's surface, `degrees` round from the face, at height
    /// `y`: on the screen, and how far it faces the viewer (1 straight at it).
    static func onHead(_ view: SpriteView, degrees: Double, y: Double, out: Double = 0) -> (point: P, facing: Double) {
        let turn = (degrees + view.yaw) * .pi / 180
        return (P(headRadius(y, out: out) * cos(turn), y), sin(turn))
    }

    /// A shape drawn about the face's centre as it shows from the front (x
    /// from the centre, to the screen's right), in a view that sees the face:
    /// from a quarter turn the face's centre moves 4.5 toward the screen's
    /// right, the half beyond it toward the head's edge narrowed and the half
    /// toward the ear widened, as the kit draws the face (`Drawing.headInView`).
    static func onFace(_ view: SpriteView, _ points: [P]) -> [P] {
        switch view {
        case .frontQuarter: points.map { P(4.5 + ($0.x > 0 ? $0.x * 0.7 : $0.x * 1.1), $0.y) }
        default: points
        }
    }
}
