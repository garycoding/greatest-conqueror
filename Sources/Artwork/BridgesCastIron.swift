// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The cast-iron bridge of the Industrial age, after the Iron Bridge over the
// Severn (1779): on stone piers at each joint, cast-iron ribs arch under the
// deck, each rib three concentric arcs tied by radial members, with rings of
// iron in the spandrels between the arcs and the deck; a road of granite
// setts with a painted line between the lanes; and a cast-iron railing of
// slender balusters between posts with ball finials. The ironwork is painted
// in the age's green. The ribs' crowns follow the deck's rise, so that they
// grow toward the middle of the bridge.

extension BridgesPainter {
    mutating func castIron(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let h = Self.deck, e = Self.overlap
        let (v0, v1) = span
        let pier = 0.08, spring = 1.4
        let a = 0.5 - pier
        film(level(-0.5, complete ? 0.5 : 0, v0, v1 + (near ? 0.1 : 0), 0), opacity: 0.2)

        /// A rib's arc at `v`: from the springing, rising `lift` points above the inner arc.
        func rib(_ u: Double, lift: Double = 0) -> Double {
            let crown = deckAt(0) - 1.8 - 2.2
            let x = min(max(u / a, -1), 1)
            return spring + lift + (crown - spring) * (1 - x * x).squareRoot()
        }
        func curve(_ v: Double, lift: Double = 0, from: Double = -1, to: Double = 1) -> [P] {
            (0...20).map { k in
                let u = a * (from + (to - from) * Double(k) / 20)
                return fixed(u, v, rib(u, lift: lift))
            }
        }
        func stroke(_ points: [P], width: Double, colour paint: String) {
            var d = PathData()
            d.move(points[0])
            for q in points.dropFirst() { d.line(q) }
            svg.path(d, stroke: .colour(BridgesInk.line), width: width + 1.1)
            svg.path(d, stroke: .colour(paint), width: width)
        }

        // The piers at both joints: dressed stone with a cornice at the springing.
        if near || !complete {
            for u in [-0.5, 0.5] {
                let foot = at(u, outer * 1.04, 0)
                submerged(at: foot, width: 4)
                block(u - pier, u + pier, near ? 0 : -1.04, near ? 1.04 : 0, -0.4, spring, top: I.stone, lit: I.stoneShade,
                      shade: I.stoneDark, width: 0.7)
                block(u - pier - 0.012, u + pier + 0.012, near ? 0 : -1.06, near ? 1.06 : 0, spring, spring + 0.7,
                      top: I.stoneTop, lit: I.stone, shade: I.stoneShade, width: 0.6)
                ripple(at: foot, 3.4)
            }
        }

        // The ribs: the inner one in shade, then the outer one in full, with its rings and members.
        let ribs = near ? [0.36, 0.99] : [-0.99, -0.36]
        let order = near ? ribs : ribs.reversed()
        for (n, v) in order.enumerated() {
            let full = near && n == 1
            let paint = full ? side(I.greenLight, I.green) : I.greenShade
            let to = complete ? 1.0 : 0.0
            stroke(curve(v, to: to), width: 2.4, colour: paint)
            guard full || complete else { continue }
            stroke(curve(v, lift: 1.6, to: to), width: 1.5, colour: paint)
            // The third arc, shorter, nearer the deck.
            stroke(curve(v, lift: 3.0, from: -0.72, to: min(0.72, to)), width: 1.0, colour: paint)
            // Radial members between the arcs.
            for t in stride(from: -0.9, through: to - 0.05, by: 0.15) {
                let u = a * t
                stroke([fixed(u, v, rib(u)), fixed(u, v, rib(u, lift: abs(t) < 0.72 ? 3.0 : 1.6))], width: 0.7,
                       colour: paint)
            }
            guard full else { continue }
            // Rings in the spandrels over the haunches, and uprights to the deck.
            for t in [-0.86, 0.86] where t < to {
                let u = a * t
                let low = rib(u, lift: 1.6), high = deckAt(u) - 1.8
                let c = fixed(u, v, (low + high) / 2), r = max(0.8, (high - low) / 2 - 0.3)
                svg.circle(c, r + 0.55, fill: .none, stroke: .colour(BridgesInk.line), width: 1.6)
                svg.circle(c, r + 0.55, fill: .none, stroke: .colour(paint), width: 0.9)
            }
            for t in [-0.6, -0.4, 0.4, 0.6] where t < to {
                let u = a * t
                stroke([fixed(u, v, rib(u, lift: 3.0)), at(u, v, h - 1.8)], width: 0.8, colour: paint)
            }
        }

        // The deck: a fascia girder along the near edge, then the road of setts.
        let laid = complete ? 0.5 + e : 0.0
        if near {
            let fascia = along(1, -0.5 - e, laid, h - 1.8, h)
            colour(fascia, .colour(side(I.green, I.greenShade)))
            for k in 0..<12 {
                let u = -0.5 + (Double(k) + 0.5) / 12
                guard u < laid else { continue }
                svg.circle(at(u, 1, h - 0.45), 0.32, fill: .colour(I.greenDark))
                svg.circle(at(u, 1, h - 1.35), 0.32, fill: .colour(I.greenDark))
            }
            line(fascia, closed: true, width: 0.8)
        }
        colour(level(-0.5 - e, laid, v0, v1, h), .colour(I.paving))
        // Setts: rows across the lane, each row's joints offset from the last.
        let rows = 4
        for r in 1..<rows {
            let v = v0 + (v1 - v0) * Double(r) / Double(rows)
            line([at(-0.5, v, h), at(laid - e, v, h)], width: 0.35, opacity: 0.45)
        }
        for k in 0...16 {
            let u = -0.5 + Double(k) / 16
            guard u < laid - 0.01 else { continue }
            for r in 0..<rows where (k + r) % 2 == 0 {
                let va = v0 + (v1 - v0) * Double(r) / Double(rows), vb = v0 + (v1 - v0) * Double(r + 1) / Double(rows)
                line([at(u, va, h), at(u, vb, h)], width: 0.35, opacity: 0.4)
            }
        }
        if near && complete {
            // The line between the lanes, painted in dashes.
            for k in 0..<4 {
                let u = -0.5 + Double(k) * 0.25 + 0.04
                colour(level(u, u + 0.15, -0.022, 0.022, h), .colour(I.plasterTop), shift: P(0, 0))
            }
        }
        line([at(-0.5, outer, h), at(laid, outer, h)], width: near ? 1 : 0.8)
        if !complete {
            line([at(0, v0, h), at(0, v1, h)], width: 0.8)
            // Cross girders bare beyond the laid road, and a rib's segment lying ready.
            for u in [0.16, 0.38] {
                block(u, u + 0.04, v0 + 0.04, v1 - 0.04, h - 1.4, h - 0.2, top: I.greenLight, lit: I.green,
                      shade: I.greenShade, width: 0.5)
            }
            pole(at(-0.4, near ? 0.3 : -0.7, h + 0.8), at(-0.08, near ? 0.6 : -0.4, h + 0.8), width: 2, colour: I.green,
                 line: 0.6)
        }

        // The railing: posts with ball finials, top and bottom rails, and balusters.
        let railV = outer * 0.97, top = h + 5.6
        let end = complete ? 0.5 : 0.0
        var k = 0
        var u = -0.5 + 1.0 / 24
        while u < end {
            if k % 6 != 5 { line([at(u, railV, h + 0.9), at(u, railV, top)], width: 0.55, colour: I.greenDark) }
            u += 1.0 / 24; k += 1
        }
        for hh in [h + 0.9, top] {
            pole(at(-0.5 - e, railV, hh), at(end + e, railV, hh), width: 1.1, colour: side(I.greenLight, I.green), line: 0.45)
        }
        for u in stride(from: -0.5, through: end, by: 0.25) {
            post(u, railV, h, top + 1.2, width: 1.6, colour: side(I.greenLight, I.green), line: 0.5)
            let ball = at(u, railV, top + 2)
            svg.circle(ball + Self.nudge, 1.05, fill: .colour(I.brass))
            svg.circle(ball, 1.05, fill: .none, stroke: .colour(BridgesInk.line), width: 0.5)
        }
        colours(farFoot: at(complete ? 0 : -0.5, railV, top + 2.6), nearTop: at(-0.375, railV, top), staff: I.sootDark)
    }
}
