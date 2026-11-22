// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The timber beam bridge of the Bronze age: sawn planks across squared
// stringers, on a trestle at each joint of squared posts braced crosswise
// and capped by a beam; a squared kerb parting the lanes; and along each side
// a rail of posts with bronze caps and woven wattle panels between them.

/// The colours of the beam bridge, from the Bronze age's palette.
enum BridgesBeamInk {
    static let top = "#b8854d"
    static let topAlt = "#a8743f"
    static let highlight = "#cf9f66"
    static let lit = "#8a5a33"
    static let shade = "#6b4a2a"
    static let wattle = "#cda85e"
    static let wattleShade = "#a9863f"
    static let bronze = "#b47b36"
    static let bronzeLight = "#d9a35a"
}

extension BridgesPainter {
    mutating func beams(complete: Bool) {
        typealias K = BridgesBeamInk
        let h = Self.deck, e = Self.overlap
        let (v0, v1) = span
        let count = 8, step = 1.0 / Double(count)
        let laid = complete ? 0.5 : 0.0
        let posts = near ? [0.3, 0.86] : [-0.86, -0.3]

        film(level(-0.5, laid, v0, v1 + (near ? 0.08 : 0), 0), opacity: 0.2)
        // The trestles: squared posts, braced crosswise, under a cap beam.
        for u in [-0.5, 0.5] {
            for v in posts {
                let foot = at(u, v, 0)
                submerged(at: foot, width: 2.8)
                block(u - 0.025, u + 0.025, v - 0.025, v + 0.025, -0.4, h - 2.6, top: K.highlight, lit: K.lit,
                      shade: K.shade, width: 0.6)
                ripple(at: foot, 2.3)
            }
            pole(at(u, posts[0], h - 2.8), at(u, posts[1], 0.8), width: 1.1, colour: end(K.lit, K.shade), line: 0.5)
            pole(at(u, posts[1], h - 2.8), at(u, posts[0], 0.8), width: 1.1, colour: end(K.lit, K.shade), line: 0.5)
            block(u - 0.04, u + 0.04, v0, v1, h - 2.6, h - 1.4, top: K.highlight, lit: K.lit, shade: K.shade, width: 0.6)
        }
        // The stringers.
        for v in posts {
            block(-0.5 - e, 0.5 + e, v - 0.03, v + 0.03, h - 1.4, h - 0.1, top: K.highlight, lit: K.lit, shade: K.shade,
                  width: 0.55)
        }
        // The near edge of the deck: a fascia board over the plank ends.
        if near {
            colour(along(1, -0.5 - e, laid + (complete ? e : 0), h - 1.1, h), .colour(side(K.lit, K.shade)))
            line([at(-0.5, 1, h - 1.1), at(laid, 1, h - 1.1)], width: 0.6)
        }

        // The planks, as far as they are laid.
        // The deck whole, then every other log or plank a shade apart over it, so that no seam shows between them.
        colour(level(-0.5 - e, laid + (complete ? e : 0), v0, v1, h), .colour(K.top))
        for k in 0..<count where k % 2 == 1 {
            let u0 = -0.5 + Double(k) * step, u1 = u0 + step
            guard u1 <= laid + 0.001 else { continue }
            colour(level(u0 - (k == 0 ? e : 0), u1 + (k == count - 1 ? e : 0), v0, v1, h),
                   .colour(K.topAlt))
        }
        for k in 0...count {
            let u = -0.5 + Double(k) * step
            guard u <= laid + 0.001 else { continue }
            line([at(u, v0, h), at(u, v1, h)], width: 0.5, opacity: 0.8)
            guard k < count, u + step <= laid + 0.001 else { continue }
            let mid = u + step / 2
            // The grain, and a nail over each stringer.
            line([at(mid + step * 0.12, v0 + 0.15, h), at(mid + step * 0.12, v0 + 0.4, h)], width: 0.4, opacity: 0.45)
            line([at(mid - step * 0.15, v1 - 0.4, h), at(mid - step * 0.15, v1 - 0.18, h)], width: 0.4, opacity: 0.45)
            for v in posts { svg.circle(at(mid, v, h), 0.42, fill: .colour(K.shade)) }
        }
        line([at(-0.5, outer, h), at(laid, outer, h)], width: near ? 1 : 0.8)
        if !complete {
            line([at(laid, v0, h), at(laid, v1, h)], width: 0.8)
            // Planks across the bare stringers, and a stack on the laid ones.
            for (u, skew) in [(0.12, 0.04), (0.34, -0.05)] {
                block(u, u + 0.09, v0 + 0.06 + max(skew, 0), v1 - 0.06 + min(skew, 0), h, h + 0.6, top: K.highlight,
                      lit: K.lit, shade: K.shade, width: 0.55)
            }
            let sv = near ? 0.3 : -0.75
            block(-0.4, -0.12, sv, sv + 0.4, h, h + 0.9, top: K.highlight, lit: K.lit, shade: K.shade, width: 0.6)
            block(-0.37, -0.09, sv + 0.02, sv + 0.42, h + 0.9, h + 1.8, top: K.highlight, lit: K.lit, shade: K.shade,
                  width: 0.6)
        }

        // The kerb between the lanes, laid by the near lane over the line.
        if near && complete {
            block(-0.5 - e, 0.5 + e, -0.035, 0.035, h, h + 1.3, top: K.highlight, lit: K.lit, shade: K.shade, width: 0.55)
        }
        // The rail: posts with bronze caps, a top rail, and wattle between.
        let railV = outer * 0.95
        if complete {
            for (a, b) in [(-0.5, 0.0), (0.0, 0.5)] { wattle(a, b, railV, h + 0.5, h + 5.2) }
            block(-0.5 - e, 0.5 + e, railV - 0.02, railV + 0.02, h + 5.2, h + 6.1, top: K.highlight, lit: K.lit,
                  shade: K.shade, width: 0.55)
        }
        for u in complete ? [-0.5, 0.0, 0.5] : [-0.5] {
            block(u - 0.022, u + 0.022, railV - 0.022, railV + 0.022, h - 1, h + 6.6, top: K.highlight, lit: K.lit,
                  shade: K.shade, width: 0.55)
            let cap = at(u, railV, h + 6.6)
            svg.ellipse(cap + P(-0.3, 0.2), 1.9, 0.9, fill: .colour(K.bronze))
            svg.ellipse(cap, 1.9, 0.9, fill: .none, stroke: .colour(BridgesInk.line), width: 0.5)
            svg.circle(cap + P(-0.5, -0.2), 0.45, fill: .colour(K.bronzeLight))
        }
        colours(farFoot: at(complete ? 0 : -0.5, railV, h + 6.6), nearTop: at(-0.25, railV, h + 6.1), staff: K.shade)
    }

    /// A woven wattle panel along the rail at `v`, from `u0` to `u1`, from `h0` to `h1`.
    private mutating func wattle(_ u0: Double, _ u1: Double, _ v: Double, _ h0: Double, _ h1: Double) {
        typealias K = BridgesBeamInk
        colour(along(v, u0, u1, h0, h1), .colour(side(K.wattle, K.wattleShade)), shift: Self.nudge)
        // The stakes, and the withies woven between them.
        let stakes = 5
        for k in 1..<stakes {
            let u = u0 + (u1 - u0) * Double(k) / Double(stakes)
            line([at(u, v, h0), at(u, v, h1)], width: 0.55, colour: K.shade, opacity: 0.9)
        }
        let rows = 4
        for r in 0..<rows {
            let hh = h0 + (h1 - h0) * (Double(r) + 0.5) / Double(rows)
            var d = PathData()
            d.move(at(u0, v, hh))
            for k in 0..<stakes {
                let ua = u0 + (u1 - u0) * Double(k) / Double(stakes), ub = u0 + (u1 - u0) * Double(k + 1) / Double(stakes)
                let bulge = (k + r) % 2 == 0 ? 0.7 : -0.7
                d.quad(at((ua + ub) / 2, v, hh + bulge), at(ub, v, hh))
            }
            svg.path(d, stroke: .colour(BridgesInk.line), width: 0.4, opacity: 0.6)
        }
        line(along(v, u0, u1, h0, h1), closed: true, width: 0.6)
    }
}
