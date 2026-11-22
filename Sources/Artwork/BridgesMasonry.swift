// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The masonry bridges: the Roman bridge of the Iron age and the fortified
// bridge of the Alchemy age. Each piece is one arch, springing from piers on
// its two joints, so that a row of pieces shows pier, arch, pier from bank to
// bank. The arch is shaped to the rise: its crown stands a ring's depth and a
// course below the deck at the piece's middle, so that the arches grow toward
// the middle of the bridge as the deck rises over them. The near lane draws
// the near face (the spandrels, the ring of voussoirs, the cutwaters) and the
// near parapet; the far lane draws its half of the road and the far parapet's
// inner face, which is what shows of the far side.

/// What makes a masonry bridge one age's and not another's.
struct BridgesMasonryStyle {
    var stone: String, stoneTop: String, stoneShade: String
    /// The paler dressed stone of the voussoirs and copings.
    var dressed: String
    var paving: String, pavingShade: String
    /// The darker stone of the kerb between the lanes.
    var kerb: String
    var staff: String
    /// Each pier's half-thickness along the run, in tiles.
    var pier: Double
    /// Where the arch springs above the water, in points.
    var spring: Double
    /// A round (Roman) arch, or a flatter segmental one.
    var round: Bool
    /// Pointed cutwaters carried up to the road, with refuges in the parapet over them.
    var refuges: Bool
    /// The parapet's height in points.
    var parapet: Double
}

extension BridgesPainter {
    /// The arch's half-span in tiles.
    private func archHalf(_ style: BridgesMasonryStyle) -> Double { 0.5 - style.pier }

    /// The arch's crown, in points above the water.
    private func crown(_ style: BridgesMasonryStyle) -> Double { deckAt(0) - 2.6 }

    /// The arch's underside at `u` (from -half to half), in points above the water.
    private func intrados(_ style: BridgesMasonryStyle, _ u: Double, grow: Double = 0) -> Double {
        let a = archHalf(style) + grow, s = style.spring, rise = crown(style) - s + grow * 30
        let x = min(max(u / a, -1), 1)
        if style.round { return s + rise * (1 - x * x).squareRoot() }
        // A segment of a circle: a span 36 points a tile, rising `rise`.
        let half = a * 36, r = (half * half + rise * rise) / (2 * rise)
        return s + ((r * r - (u * 36) * (u * 36)).squareRoot() - (r - rise))
    }

    /// The arch's curve on the face at `v`, from the springing at -half to the one at half.
    private func arc(_ style: BridgesMasonryStyle, v: Double, grow: Double = 0, from: Double = -1, to: Double = 1) -> [P] {
        let a = archHalf(style) + grow, steps = 16
        return (0...steps).map { k in
            let u = a * (from + (to - from) * Double(k) / Double(steps))
            return fixed(u, v, intrados(style, u, grow: grow))
        }
    }

    /// The outline across of the bridge's side at `u`: its outer edge, bulging
    /// round a refuge at each joint where the style has them.
    private func edge(_ style: BridgesMasonryStyle, _ u: Double) -> Double {
        guard style.refuges else { return outer }
        let bulge = [-0.5, 0.5].map { j in 0.22 * max(0, 1 - abs(u - j) / style.pier) }.max()!
        return outer * (1 + bulge)
    }

    /// The points along the run where the side's outline turns.
    private func edgeTurns(_ style: BridgesMasonryStyle) -> [Double] {
        let e = Self.overlap
        guard style.refuges else { return [-0.5 - e, 0.5 + e] }
        let p = style.pier
        return [-0.5 - p, -0.5, -0.5 + p, 0.5 - p, 0.5, 0.5 + p]
    }

    mutating func masonry(_ style: BridgesMasonryStyle, complete: Bool) {
        let h = Self.deck
        let (v0, v1) = span
        film(level(-0.5, 0.5, v0, v1 + (near ? 0.12 : 0), 0), opacity: 0.2)
        if near {
            nearFace(style, complete: complete)
        } else if !complete {
            // The far lane's piers rise to the springing, and the centring stands between them.
            for u in [-0.5, 0.5] {
                block(u - style.pier, u + style.pier, -1, 0, -0.4, style.spring, top: style.stoneTop, lit: style.stone,
                      shade: style.stoneShade, width: 0.6)
            }
            centring(style, v: -0.6)
        }
        guard complete else {
            if near { stonesWaiting(style) }
            colours(farFoot: at(-0.5, outer * 0.9, style.spring + 2), nearTop: at(-0.5, 1.05, style.spring + 2),
                    staff: style.staff)
            return
        }
        road(style)
        parapet(style)
        colours(farFoot: at(0, outer * 0.98, h + style.parapet), nearTop: at(-0.22, 1.01, h + style.parapet),
                staff: style.staff, length: 6)
    }

    /// The near face: the water and shade under the arch, the pier's flank and
    /// the barrel's soffit seen through it, the spandrels and piers, the ring
    /// of voussoirs, the courses, and the cutwaters.
    private mutating func nearFace(_ style: BridgesMasonryStyle, complete: Bool) {
        let h = Self.deck, a = archHalf(style), s = style.spring
        let opening = arc(style, v: 1) + [at(a, 1, 0), at(-a, 1, 0)]
        if complete {
            // Under the arch: the shade on the water, the soffit, the back pier's flank.
            film(opening, opacity: 0.32)
            let soffit = arc(style, v: 1) + arc(style, v: 0.25).reversed()
            colour(soffit, .colour(style.stoneShade), shift: P(0, 0))
            film(soffit, opacity: 0.25)
            colour(across(-a, 0.25, 1, 0, s), .colour(end(style.stone, style.stoneShade)), shift: P(0, 0))
            film(across(-a, 0.25, 1, 0, s), opacity: 0.2)
            line(arc(style, v: 0.25), width: 0.5, opacity: 0.5)
        }
        // The face: piers and spandrels round the arch, up to the road.
        let top = complete ? h : s
        var face: [P] = [at(-0.5 - Self.overlap, 1, top), at(0.5 + Self.overlap, 1, top), at(0.5 + Self.overlap, 1, 0),
                         at(a, 1, 0)]
        if complete {
            face += arc(style, v: 1).reversed()
        } else {
            face += [at(a, 1, s), at(-a, 1, s)]
        }
        face += [at(-a, 1, 0), at(-0.5 - Self.overlap, 1, 0)]
        if complete {
            colour(face, .colour(side(style.stone, style.stoneShade)))
            courses(style)
            ring(style, from: -1, to: 1)
            line(face, closed: true, width: 0.9)
        } else {
            // Building: the piers stand to the springing; the centring carries the back half of the ring.
            for (u0, u1) in [(-0.5 - Self.overlap, -a), (a, 0.5 + Self.overlap)] {
                let pier = [at(u0, 1, 0), at(u1, 1, 0), at(u1, 1, s), at(u0, 1, s)]
                colour(pier, .colour(side(style.stone, style.stoneShade)))
                line(pier, closed: true, width: 0.8)
                colour(level(u0, u1, 0.2, 1, s), .colour(style.stoneTop))
                line(level(u0, u1, 0.2, 1, s), closed: true, width: 0.6)
            }
            centring(style, v: 0.85)
            ring(style, from: -1, to: 0)
        }
        for u in [-0.5, 0.5] { cutwater(style, at: u, complete: complete) }
    }

    /// The ring of voussoirs round the arch's face, from `from` to `to` along
    /// its half-span (-1 to 1), with the keystone where the ring is whole.
    private mutating func ring(_ style: BridgesMasonryStyle, from: Double, to: Double) {
        let grow = 0.05
        let inner = arc(style, v: 1, from: from, to: to), outerArc = arc(style, v: 1, grow: grow, from: from, to: to)
        colour(inner + outerArc.reversed(), .colour(style.dressed), shift: Self.nudge)
        let stones = 11, a = archHalf(style)
        for k in 0...stones {
            let t = -1 + 2 * Double(k) / Double(stones)
            guard t >= from - 0.001, t <= to + 0.001 else { continue }
            // Radial joints: the same angle on both curves.
            let theta = acos(t)
            let ui = a * cos(theta), uo = (a + grow) * cos(theta)
            line([fixed(ui, 1, intrados(style, ui)), fixed(uo, 1, intrados(style, uo, grow: grow))], width: 0.5,
                 opacity: 0.85)
        }
        if from <= -0.999 && to >= 0.999 {
            // The keystone, a little prouder than the rest.
            let k = 0.045
            let key = [fixed(-k, 1, intrados(style, -k)), fixed(k, 1, intrados(style, k)),
                       fixed(k * 1.25, 1, intrados(style, k * 1.25, grow: grow) + 0.8),
                       fixed(-k * 1.25, 1, intrados(style, -k * 1.25, grow: grow) + 0.8)]
            shape(key, .colour(style.stoneTop), width: 0.6, shift: Self.nudge)
        }
        line(inner, width: 0.8)
        line(outerArc, width: 0.6)
    }

    /// The courses of the face's stones: a joint every 2.2 points of height
    /// where the face is whole, with the upright joints staggered course by course.
    private mutating func courses(_ style: BridgesMasonryStyle) {
        let a = archHalf(style)
        var level = 1.6, row = 0
        while level < deckAt(0.5) + 3 && level < deckAt(-0.5) + 3 {
            var run: [P] = []
            func flush() { if run.count > 1 { line(run, width: 0.4, opacity: 0.55) }; run = [] }
            let steps = 40
            for k in 0...steps {
                let u = -0.5 + Double(k) / Double(steps)
                let clear = level < deckAt(u) - 0.6 && (abs(u) > a + 0.05 || level > intrados(style, u, grow: 0.05) + 0.4)
                if clear { run.append(fixed(u, 1, level)) } else { flush() }
            }
            flush()
            // Upright joints, staggered.
            var u = -0.5 + (row % 2 == 0 ? 0.06 : 0.13)
            while u < 0.5 {
                let clearBelow = level - 2.2 > 0.3 && (abs(u) > a + 0.05 || level - 2.2 > intrados(style, u, grow: 0.05) + 0.4)
                if clearBelow && level < deckAt(u) - 0.6 {
                    line([fixed(u, 1, level - 2.2), fixed(u, 1, level)], width: 0.4, opacity: 0.5)
                }
                u += 0.14
            }
            level += 2.2
            row += 1
        }
    }

    /// A cutwater on the near face at the joint `u`: a pointed prism standing
    /// out from the pier, capped at the springing, or (with refuges) carried
    /// up to the road.
    private mutating func cutwater(_ style: BridgesMasonryStyle, at u: Double, complete: Bool) {
        let p = style.pier, tip = 1.22
        let top = style.refuges && complete ? Self.deck : style.spring + 1.2
        let foot = at(u, tip, 0)
        submerged(at: foot, width: 5)
        let left = [at(u - p, 1, 0), at(u, tip, 0), at(u, tip, top), at(u - p, 1, top)]
        let right = [at(u, tip, 0), at(u + p, 1, 0), at(u + p, 1, top), at(u, tip, top)]
        colour(left, .colour(side(style.stone, style.stoneShade)))
        colour(right, .colour(end(style.stone, style.stoneShade)))
        // Courses across both faces.
        var c = 1.6
        while c < top - 0.4 {
            line([at(u - p, 1, c), at(u, tip, c), at(u + p, 1, c)], width: 0.4, opacity: 0.5)
            c += 2.2
        }
        line(left + [right[1], right[2]], closed: false, width: 0.8)
        line([at(u, tip, 0), at(u, tip, top)], width: 0.6)
        if !(style.refuges && complete) {
            // A pointed cap of dressed stone.
            let apex = at(u, 1.02, top + 2.2)
            shape([at(u - p, 1, top), at(u, tip, top), apex], .colour(side(style.dressed, style.stoneShade)), width: 0.6,
                  shift: Self.nudge)
            shape([at(u, tip, top), at(u + p, 1, top), apex], .colour(end(style.dressed, style.stoneShade)), width: 0.6,
                  shift: Self.nudge)
        }
        ripple(at: foot, 4)
    }

    /// The road: the lane's half, paved, and the kerb between the lanes (the near lane's).
    private mutating func road(_ style: BridgesMasonryStyle) {
        let h = Self.deck, e = Self.overlap
        let (v0, v1) = span
        colour(level(-0.5 - e, 0.5 + e, v0, v1, h), .colour(style.paving))
        if style.refuges {
            // The refuges' floors at the joints.
            for j in [-0.5, 0.5] {
                colour([at(j - style.pier, outer, h), at(j, outer * 1.18, h), at(j + style.pier, outer, h)],
                       .colour(style.paving))
            }
        }
        // Paving stones: three rows to the lane, joints staggered, each piece's pattern ending on its edges.
        let rows = 3
        for r in 0..<rows {
            let va = v0 + (v1 - v0) * Double(r) / Double(rows), vb = v0 + (v1 - v0) * Double(r + 1) / Double(rows)
            if r > 0 { line([at(-0.5, va, h), at(0.5, va, h)], width: 0.4, opacity: 0.4) }
            let offset = r % 2 == 0 ? 0.0 : 1.0 / 12
            var u = -0.5 + offset + (style.round ? 1.0 / 6 : 1.0 / 8)
            while u < 0.5 - 0.01 {
                // Roman paving is polygonal: each joint leans a little, one way then the other.
                let lean = style.round ? (Int((u + 1) * 24) % 2 == 0 ? 0.025 : -0.025) : 0
                line([at(u - lean, va + 0.02, h), at(u + lean, vb - 0.02, h)], width: 0.4, opacity: 0.45)
                u += style.round ? 1.0 / 6 : 1.0 / 8
            }
        }
        if near {
            // The kerb between the lanes: a line of darker stones.
            let w = 0.035
            colour(level(-0.5 - e, 0.5 + e, -w, w, h + 0.5), .colour(style.kerb), shift: Self.nudge)
            colour(along(w, -0.5 - e, 0.5 + e, h, h + 0.5), .colour(side(style.stoneShade, style.stoneShade)), shift: Self.nudge)
            for k in 0...6 {
                let u = -0.5 + Double(k) / 6
                line([at(u, -w, h + 0.5), at(u, w, h + 0.5)], width: 0.4, opacity: 0.6)
            }
            line([at(-0.5, w, h + 0.5), at(0.5, w, h + 0.5)], width: 0.5)
            line([at(-0.5, w, h), at(0.5, w, h)], width: 0.4, opacity: 0.6)
        }
    }

    /// The parapet along the lane's outer side, round the refuges where the
    /// style has them: the near lane shows its outer face, the far lane its
    /// inner face; both show the coping.
    private mutating func parapet(_ style: BridgesMasonryStyle) {
        let h = Self.deck, ph = style.parapet, t = 0.07
        let turns = edgeTurns(style)
        // The wall's line, and its inner line a thickness in.
        let wall = turns.map { ($0, edge(style, $0)) }
        let innerLine = wall.map { ($0.0, $0.1 - outer * t) }
        for (a, b) in zip(wall, wall.dropFirst()) {
            let (ia, ib) = (innerLine[wall.firstIndex { $0 == a }!], innerLine[wall.firstIndex { $0 == b }!])
            // The visible face: the outer for the near lane, the inner for the far.
            let (fa, fb) = near ? (a, b) : (ia, ib)
            let rising = abs(fb.1) > abs(fa.1) + 0.001, falling = abs(fb.1) < abs(fa.1) - 0.001
            let paint = near
                ? (rising ? side(style.stone, style.stoneShade) : falling ? end(style.stone, style.stoneShade) : side(style.stone, style.stoneShade))
                : side(style.stone, style.stoneShade)
            let face = [at(fa.0, fa.1, near ? 0 : h), at(fb.0, fb.1, near ? 0 : h), at(fb.0, fb.1, h + ph), at(fa.0, fa.1, h + ph)]
            if near {
                // The near face continues the spandrel up past the road.
                let upper = [at(fa.0, fa.1, h), at(fb.0, fb.1, h), at(fb.0, fb.1, h + ph), at(fa.0, fa.1, h + ph)]
                colour(upper, .colour(paint))
                line(upper, closed: true, width: 0.7)
            } else {
                colour(face, .colour(paint), shift: P(-0.5, 0.35))
                line(face, closed: true, width: 0.7)
            }
            // The coping.
            let coping = [at(a.0, a.1, h + ph), at(b.0, b.1, h + ph), at(ib.0, ib.1, h + ph), at(ia.0, ia.1, h + ph)]
            colour(coping, .colour(style.dressed), shift: Self.nudge)
            line(coping, closed: true, width: 0.6)
            // Joints in the wall's face.
            let (u0, u1) = (fa.0, fb.0)
            var u = u0 + 0.09
            while u < u1 - 0.03 {
                let f = (u - u0) / (u1 - u0), v = fa.1 + (fb.1 - fa.1) * f
                line([at(u, v, h + 0.3), at(u, v, h + ph - 0.3)], width: 0.4, opacity: 0.6)
                u += 0.125
            }
        }
    }

    /// The timber centring on which an arch is turned: ribs along the
    /// intrados at `v` with struts down to the piers.
    private mutating func centring(_ style: BridgesMasonryStyle, v: Double) {
        let a = archHalf(style)
        let timber = "#8a5a33", timberShade = "#6b4a2a"
        let curve = arc(style, v: v)
        var d = PathData()
        d.move(curve[0])
        for p in curve.dropFirst() { d.line(p) }
        svg.path(d, stroke: .colour(timberShade), width: 2.2)
        svg.path(d, stroke: .colour(timber), width: 1.2)
        for t in [-0.6, -0.2, 0.2, 0.6] {
            let u = a * t
            pole(fixed(u, v, intrados(style, u)), at(t < 0 ? -a : a, v, style.spring * 0.6), width: 1, colour: timber,
                 line: 0.4)
        }
        pole(at(-a, v, style.spring), at(a, v, style.spring), width: 1.2, colour: timberShade, line: 0.4)
    }

    /// Dressed stones lying on the near pier's top, waiting to be set.
    private mutating func stonesWaiting(_ style: BridgesMasonryStyle) {
        let s = style.spring
        block(-0.47, -0.4, 0.3, 0.5, s, s + 1.4, top: style.stoneTop, lit: style.dressed, shade: style.stoneShade, width: 0.5)
        block(0.4, 0.47, 0.5, 0.75, s, s + 1.4, top: style.stoneTop, lit: style.dressed, shade: style.stoneShade, width: 0.5)
        block(0.41, 0.46, 0.55, 0.7, s + 1.4, s + 2.8, top: style.stoneTop, lit: style.dressed, shade: style.stoneShade,
              width: 0.5)
    }
}
