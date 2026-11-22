// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The log bridge of the Stone age, as the first builders crossed a river:
// round logs laid side by side across stringers, lashed to them with grass
// rope, on a bent of driven piles at each joint, each bent capped by a log
// across. A log lying along the middle parts the two lanes, and a rope rail
// on posts runs along each side. Eight logs to the tile, every other one a
// shade apart, so that the pattern runs on from piece to piece.

/// The colours of the log bridge, from the Stone age's palette of hide and moss.
enum BridgesLogInk {
    static let top = "#b98a58"
    static let topAlt = "#a87a4b"
    static let highlight = "#cfa070"
    static let lit = "#8a5a33"
    static let shade = "#6b4a2a"
    static let cutEnd = "#d9b47e"
    static let rope = "#d9b47e"
}

extension BridgesPainter {
    mutating func logs(complete: Bool) {
        typealias K = BridgesLogInk
        let h = Self.deck, e = Self.overlap
        let (v0, v1) = span
        let count = 8, step = 1.0 / Double(count)
        let laid = complete ? 0.5 : 0.0
        let piles = near ? [0.3, 0.86] : [-0.86, -0.3]

        // The water in the deck's shadow.
        film(level(-0.5, laid, v0, v1 + (near ? 0.08 : 0), 0), opacity: 0.2)
        // The bents at both ends: the piles, and the log across them.
        for u in [-0.5, 0.5] {
            for v in piles { logPile(u, v, top: h - 2.4) }
            pole(at(u, v0, h - 2.6), at(u, v1, h - 2.6), width: 2.4, colour: end(K.lit, K.shade), line: 0.7)
        }
        // The stringers, along the run under the deck.
        for v in piles {
            pole(at(-0.5 - e, v, h - 1.3), at(0.5 + e, v, h - 1.3), width: 2.0, colour: side(K.lit, K.shade), line: 0.6)
        }

        // The logs across, as far as they are laid.
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
            line([at(u, v0, h), at(u, v1, h)], width: 0.7, opacity: 0.8)
            guard k < count, u + step <= laid + 0.001 else { continue }
            let mid = u + step / 2
            // A log's lit crown, its bark, and its lashing to the outer stringer.
            line([at(mid - step * 0.18, v0 + 0.03, h), at(mid - step * 0.18, v1 - 0.03, h)], width: 0.8,
                 colour: K.highlight, opacity: 0.9)
            line([at(mid + step * 0.15, outer * 0.55, h), at(mid + step * 0.15, outer * 0.42, h)], width: 0.4,
                 opacity: 0.5)
            if k % 2 == 0 {
                let a = at(mid, outer * 0.86, h + 0.3), b = at(mid, outer * 0.86, h - 2)
                svg.line([a, b], stroke: .colour(K.rope), width: 1.1)
                svg.line([a + P(0.4, 0), b + P(0.4, 0)], stroke: .colour(BridgesInk.line), width: 0.35, opacity: 0.7)
            }
            // The cut ends along the near side.
            if near {
                let end = at(mid, 1, h - 1.1)
                svg.ellipse(end + Self.nudge, 1.75, 1.3, fill: .colour(K.cutEnd))
                svg.ellipse(end, 1.75, 1.3, fill: .none, stroke: .colour(BridgesInk.line), width: 0.5)
                svg.circle(end + P(0.2, 0), 0.4, fill: .colour(K.lit))
            }
        }
        line([at(-0.5, outer, h), at(laid, outer, h)], width: near ? 1 : 0.8)
        if !complete {
            line([at(laid, v0, h), at(laid, v1, h)], width: 0.8)
            // Logs waiting on the bare stringers, and two more on the laid ones.
            for (u, skew) in [(0.14, 0.04), (0.36, -0.05)] {
                pole(at(u, v0 + 0.08, h + 0.9), at(u + skew, v1 - 0.08, h + 0.9), width: 2.6, colour: K.top, line: 0.6)
            }
            pole(at(-0.36, near ? 0.15 : -0.85, h + 1.2), at(-0.1, near ? 0.75 : -0.25, h + 1.2), width: 2.4,
                 colour: K.topAlt, line: 0.6)
        }

        // The log between the lanes (the near lane lays it, over the line), then the rail.
        if near && complete {
            pole(at(-0.5 - e, 0, h + 1.1), at(0.5 + e, 0, h + 1.1), width: 2.3, colour: side(K.lit, K.shade), line: 0.6)
            line([at(-0.5, 0, h + 1.9), at(0.5, 0, h + 1.9)], width: 0.6, colour: K.highlight, opacity: 0.8)
            for u in [-0.25, 0.25] {
                let a = at(u, 0, h + 2.2), b = at(u, 0, h - 0.1)
                svg.line([a, b], stroke: .colour(K.rope), width: 1.1)
            }
        }
        let railV = outer * 0.95
        let posts = complete ? [-0.5, 0.0, 0.5] : [-0.5]
        for u in posts { post(u, railV, h - 1, h + 7, width: 1.6, colour: side(K.lit, K.shade), line: 0.6) }
        if complete {
            for (a, b) in [(-0.5, 0.0), (0.0, 0.5)] {
                cord(at(a, railV, h + 6.4), at(b, railV, h + 6.4), sag: 0.9, colour: K.rope)
                cord(at(a, railV, h + 3.4), at(b, railV, h + 3.4), sag: 0.6, colour: K.rope, width: 1.2)
            }
        }
        colours(farFoot: at(complete ? 0 : -0.5, railV, h + 7), nearTop: at(-0.25, railV, h + 6.2), staff: K.shade)
    }

    /// A driven log pile standing in the water at (`u`, `v`), its sawn top at `top`.
    private mutating func logPile(_ u: Double, _ v: Double, top: Double) {
        typealias K = BridgesLogInk
        let foot = at(u, v, 0)
        submerged(at: foot, width: 3)
        post(u, v, -0.4, top, width: 3, colour: side(K.lit, K.shade), line: 0.7)
        let cap = at(u, v, top)
        svg.ellipse(cap + P(-0.2, 0.1), 1.5, 0.6, fill: .colour(K.cutEnd))
        ripple(at: foot, 2.4)
    }
}
