// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The fortified bridge of the Alchemy age, after the medieval bridges of
// Cahors (the Pont Valentré) and Monmouth: flatter segmental arches between
// stout piers, whose pointed cutwaters rise to the road and carry refuges in
// the parapet where people on foot stand aside; and on the middle piece a
// gatehouse across both lanes, its gate a pointed arch through which the
// road passes, with arrow slits, a corbelled parapet of crenels, and a roof
// of slate. The gatehouse stands on a level floor at the deck's highest
// point over the piece, so that its walls and roof are level however the
// road rises beneath them.

extension BridgesPainter {
    mutating func fortified(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let style = BridgesMasonryStyle(stone: I.stone, stoneTop: I.stoneTop, stoneShade: I.stoneShade,
                                        dressed: I.rawStone, paving: I.paving, pavingShade: I.pavingShade, kerb: I.footing,
                                        staff: I.oak, pier: 0.14, spring: 2.0, round: false, refuges: true, parapet: 3.2)
        masonry(style, complete: complete)
        if near && middle { gatehouse(complete: complete) }
    }

    /// The gatehouse over both lanes on the middle piece (drawn by the near
    /// lane, after the far lane's piece): complete, or its walls half raised.
    private mutating func gatehouse(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let a = 0.34, w = 1.1
        // The floor: the deck's highest point over the gatehouse.
        let floor = max(deckAt(-a), deckAt(a))
        let wall = complete ? floor + 30 : floor + 12
        func p(_ u: Double, _ v: Double, _ h: Double) -> P { fixed(u, v, h) }
        // The base meets the road: from the road up to the floor at each corner.
        func foot(_ u: Double) -> Double { deckAt(u) }

        // The +V face (along the run, toward the viewer) and the +u face (across, the gate's face).
        let sideFace = [p(-a, w, foot(-a)), p(a, w, foot(a)), p(a, w, wall), p(-a, w, wall)]
        let endFace = [p(a, -w, foot(a)), p(a, w, foot(a)), p(a, w, wall), p(a, -w, wall)]
        colour(sideFace, .colour(side(I.stone, I.stoneShade)))
        colour(endFace, .colour(end(I.stone, I.stoneShade)))
        // Courses on both faces.
        var c = floor + 2.4, row = 0
        while c < wall - 0.5 {
            line([p(-a, w, c), p(a, w, c), p(a, -w, c)], width: 0.4, opacity: 0.5)
            // Upright joints, staggered course by course, so that the walls read as dressed stone.
            let shift = row % 2 == 0 ? 0.0 : 0.5
            for k in 0..<5 {
                let u = -a + 2 * a * (Double(k) + shift + 0.25) / 5
                line([p(u, w, c), p(u, w, min(c + 2.4, wall))], width: 0.4, opacity: 0.45)
            }
            for k in 0..<12 {
                let v = -w + 2 * w * (Double(k) + shift + 0.25) / 12
                line([p(a, v, c), p(a, v, min(c + 2.4, wall))], width: 0.4, opacity: 0.45)
            }
            c += 2.4
            row += 1
        }
        // The gate: a pointed arch through the +u face, the road running into its shade.
        let gate = 0.62, spring = floor + 9, apex = floor + 16
        var arch: [P] = [p(a, gate, foot(a)), p(a, gate, spring)]
        for k in 1...8 {
            let t = Double(k) / 8
            // Two arcs meeting at the apex: each from a springing toward the other side.
            let v = gate - gate * (1 - cos(t * .pi / 2)) , h = spring + (apex - spring) * sin(t * .pi / 2)
            arch.append(p(a, v, h))
        }
        for k in (0..<8).reversed() {
            let t = Double(k) / 8
            let v = -gate + gate * (1 - cos(t * .pi / 2)), h = spring + (apex - spring) * sin(t * .pi / 2)
            arch.append(p(a, v, h))
        }
        arch.append(p(a, -gate, foot(a)))
        if complete {
            svg.polygon(arch, fill: .colour(I.ironDark))
            film(arch, opacity: 0.35)
            // A ring of dressed voussoirs round the gate, and the portcullis's teeth above.
            line(arch, width: 0.8)
            line(Array(arch.dropFirst(1).dropLast(1)).map { $0 + P(0, -1.2) }, width: 1.6, colour: I.rawStone)
            for k in 0..<7 {
                let v = -gate * 0.8 + gate * 1.6 * Double(k) / 6
                line([p(a, v, apex - 0.6), p(a, v, apex - 3.4)], width: 0.7, colour: I.iron)
            }
            // Arrow slits on the side face, two tiers.
            for (u, h) in [(-0.17, floor + 10), (0.12, floor + 10), (-0.02, floor + 20)] {
                svg.polygon([p(u - 0.012, w, h), p(u + 0.012, w, h), p(u + 0.012, w, h + 4.4), p(u - 0.012, w, h + 4.4)],
                            fill: .colour(I.ironDark))
                line([p(u - 0.03, w, h + 2.2), p(u + 0.03, w, h + 2.2)], width: 0.6, colour: I.ironDark)
            }
            // One slit over the gate.
            svg.polygon([p(a, -0.02, floor + 21), p(a, 0.02, floor + 21), p(a, 0.02, floor + 25), p(a, -0.02, floor + 25)],
                        fill: .colour(I.ironDark))
        } else {
            svg.polygon(arch.prefix(2) + [p(a, gate, wall), p(a, -gate, wall)] + arch.suffix(1), fill: .colour(I.ironDark))
            film(arch, opacity: 0.2)
        }
        line(sideFace, closed: true, width: 0.9)
        line(endFace, closed: true, width: 0.9)

        guard complete else {
            // The wall's top, rough, with a ladder and stones waiting.
            let top = [p(-a, -w, wall), p(a, -w, wall), p(a, w, wall), p(-a, w, wall)]
            colour(top, .colour(I.rawStoneShade), shift: P(0, 0))
            line(top, closed: true, width: 0.7)
            pole(p(-0.1, w + 0.15, foot(-0.1)), p(-0.1, w + 0.02, wall + 4), width: 1, colour: I.timber, line: 0.4)
            pole(p(0.02, w + 0.15, foot(0.02)), p(0.02, w + 0.02, wall + 4), width: 1, colour: I.timber, line: 0.4)
            for k in 1..<6 {
                let h = foot(0) + Double(k) * 2.6
                line([p(-0.1, w + 0.15 - 0.022 * Double(k), h), p(0.02, w + 0.15 - 0.022 * Double(k), h)], width: 0.8,
                     colour: I.timberDark)
            }
            return
        }

        // The corbelled parapet: a band standing out on corbels, crenellated.
        let o = 0.05, band = wall + 4
        let bandSide = [p(-a - o, w + o, wall), p(a + o, w + o, wall), p(a + o, w + o, band), p(-a - o, w + o, band)]
        let bandEnd = [p(a + o, -w - o, wall), p(a + o, w + o, wall), p(a + o, w + o, band), p(a + o, -w - o, band)]
        for k in 0...6 {
            let u = -a + 2 * a * Double(k) / 6
            shape([p(u - 0.012, w, wall - 2.4), p(u + 0.012, w, wall - 2.4), p(u + 0.012, w + o, wall), p(u - 0.012, w + o, wall)],
                  .colour(I.stoneShade), width: 0.4, shift: P(0, 0))
        }
        for k in 0...10 {
            let v = -w + 2 * w * Double(k) / 10
            shape([p(a, v - 0.012, wall - 2.4), p(a, v + 0.012, wall - 2.4), p(a + o, v + 0.012, wall), p(a + o, v - 0.012, wall)],
                  .colour(I.stoneShade), width: 0.4, shift: P(0, 0))
        }
        colour(bandSide, .colour(side(I.stone, I.stoneShade)))
        colour(bandEnd, .colour(end(I.stone, I.stoneShade)))
        line(bandSide, closed: true, width: 0.8)
        line(bandEnd, closed: true, width: 0.8)
        // The roof of slate: a pyramid over the parapet's walk, the far faces first.
        let r = wall + 3, peak = wall + 22, ri = 0.02
        let corners = [p(-a + ri, -w + ri, r), p(a - ri, -w + ri, r), p(a - ri, w - ri, r), p(-a + ri, w - ri, r)]
        let top = p(0, 0, peak)
        let faces: [(Int, Int, String)] = [(3, 0, I.slateShade), (0, 1, I.slateShade), (1, 2, end(I.slateLight, I.slate)),
                                           (2, 3, side(I.slateLight, I.slate))]
        for (i, j, paint) in faces {
            shape([corners[i], corners[j], top], .colour(paint), width: 0.8)
        }
        // Courses of slates on the two near faces.
        for f in stride(from: 0.2, through: 0.85, by: 0.16) {
            for (i, j) in [(1, 2), (2, 3)] {
                let a1 = corners[i] + (top - corners[i]) * f, b1 = corners[j] + (top - corners[j]) * f
                line([a1, b1], width: 0.4, opacity: 0.5)
            }
        }
        line([corners[2], top], width: 0.8)
        // The crenels on the band's top, in front of the roof's foot.
        /// A merlon on the band's top: its two outer faces and its top, at fixed heights.
        func merlon(_ u0: Double, _ u1: Double, _ v0: Double, _ v1: Double) {
            let h0 = band, h1 = band + 2.6
            colour([p(u0, v1, h0), p(u1, v1, h0), p(u1, v1, h1), p(u0, v1, h1)], .colour(side(I.stone, I.stoneShade)),
                   shift: Self.nudge)
            colour([p(u1, v0, h0), p(u1, v1, h0), p(u1, v1, h1), p(u1, v0, h1)], .colour(end(I.stone, I.stoneShade)),
                   shift: Self.nudge)
            colour([p(u0, v0, h1), p(u1, v0, h1), p(u1, v1, h1), p(u0, v1, h1)], .colour(I.stoneTop), shift: Self.nudge)
            line([p(u0, v1, h0), p(u1, v1, h0), p(u1, v0, h0), p(u1, v0, h1), p(u0, v0, h1), p(u0, v1, h1)], closed: true,
                 width: 0.5)
            line([p(u0, v1, h1), p(u1, v1, h1), p(u1, v1, h0)], width: 0.4)
        }
        for k in 0..<5 {
            let u0 = -a - o + (2 * (a + o)) * (Double(k) + 0.15) / 5, u1 = u0 + 2 * (a + o) * 0.45 / 5
            merlon(u0, u1, w + o - 0.05, w + o)
        }
        for k in 0..<9 {
            let v0 = -w - o + (2 * (w + o)) * (Double(k) + 0.15) / 9, v1 = v0 + 2 * (w + o) * 0.45 / 9
            merlon(a + o - 0.025, a + o, v0, v1)
        }
        // A finial and the owner's banner from the roof's peak, hanging over the gate.
        line([top, top + P(0, -6)], width: 1.1, colour: I.ironDark)
        svg.circle(top + P(0, -6.4), 0.9, fill: .colour(I.gilt))
        banner(at: p(a + o, 0, wall - 1), length: 7, width: 5)
    }
}
