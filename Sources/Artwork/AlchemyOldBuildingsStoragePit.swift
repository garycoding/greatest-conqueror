// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age storage pit: the Iron age's store grown one age richer. A
// deep cellar lined with dressed stone, its kerb painted with the owner's
// colour, holds barrels, crates and sacks; a crane of oak with iron fittings
// swings a barrel out of it on a pulley, under the owner's pennant; and a
// shed of oak posts under a steep roof of slate, with a gilt finial, keeps
// more barrels dry at the back. Its footprint is two tiles square: x and y
// run from -1 to 1.

extension AlchemyOldBuildingsPainter {
    mutating func storagePit(complete: Bool) {
        cobbles(1, height: 1.5)
        if complete { cellar() } else { cellarDug() }
    }

    /// The shed at the back left: posts of oak under a gabled roof of slate.
    private mutating func storeShed(roofed: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let h0 = 1.5, (x0, y0, x1, y1) = (-0.98, -0.98, -0.62, -0.12), eave = 17.0
        shadow(level(x0, y0, x1 + 0.12, y1 + 0.12, h0), opacity: 0.16)
        for (x, y) in [(x0 + 0.03, y0 + 0.03), (x1 - 0.03, y0 + 0.03)] { pole(iso(x, y, h0), iso(x, y, h0 + eave), width: 1.6, colour: I.oak) }
        if roofed {
            for i in 0..<3 { barrel(at: iso(-0.8, -0.84 + Double(i) * 0.24, h0), size: 0.78) }
        }
        for (x, y) in [(x0 + 0.03, y1 - 0.03), (x1 - 0.03, y1 - 0.03)] { pole(iso(x, y, h0), iso(x, y, h0 + eave), width: 1.6, colour: I.oak) }
        guard roofed else {
            pole(iso(x0 + 0.03, y1 - 0.03, h0 + eave), iso(x1 - 0.03, y1 - 0.03, h0 + eave), width: 1.6, colour: I.oak)
            return
        }
        pole(iso(x1 - 0.03, y0, h0 + eave - 0.6), iso(x1 - 0.03, y1, h0 + eave - 0.6), width: 1.8, colour: I.oak)
        gableAlongY(x0, y0, x1, y1, eave: h0 + eave, ridge: h0 + eave + 10, over: 0.04, gableWall: .colour(I.light)) { p, w, r in
            p.timber(p.uv(w / 2, 0), p.uv(w / 2, r - 1), width: 1.5)
            p.timber(p.uv(1, 1), p.uv(w - 1, 1), width: 1.6)
        }
    }

    private mutating func cellar() {
        typealias I = AlchemyOldBuildingsInk
        let h0 = 1.5, rim = 5.0, floor = -4.0, e = 0.58, cx = 0.08
        storeShed(roofed: true)
        // The crane's post at the back right, behind the cellar.
        let foot = iso(0.8, -0.8, h0), head = foot - P(0, 42)
        pole(foot, head, width: 2.6, colour: I.oak)
        shell(cx - e, -e, cx + e, e, from: h0, floor: floor, to: rim, thickness: 0.07, lit: .colour(I.stone),
              shade: .colour(I.stoneShade), top: .colour(I.stoneTop), ground: .colour(I.dark)) { p in
            let length = 2 * (e - 0.07) * 32
            p.wall(.left, from: cx - e + 0.07, -e + 0.07, at: floor) { q in q.courses(0, length, 0, rim - floor, course: 3.4, brick: 8) }
            p.wall(.right, from: cx - e + 0.07, e - 0.07, at: floor) { q in q.courses(0, length, 0, rim - floor, course: 3.4, brick: 8) }
            // In the cellar, the farther first: crates, barrels and sacks.
            p.crate(cx - 0.4, -0.42, cx - 0.12, -0.16, from: floor, height: 7)
            p.barrel(at: p.iso(cx + 0.2, -0.3, floor), size: 0.9)
            p.barrel(at: p.iso(cx + 0.35, -0.05, floor), size: 0.9)
            p.sack(at: p.iso(cx - 0.32, 0.12, floor), size: 0.9)
            p.sack(at: p.iso(cx - 0.12, 0.3, floor), size: 0.85)
        }
        colour(level(cx - e, e, cx + e, 0.99, h0), .colour(I.paving))
        colour(level(cx + e, -e, 0.99, 0.99, h0), .colour(I.paving))
        line([iso(cx - e, e, h0), iso(cx + e, e, h0), iso(cx + e, -e, h0)], width: 1.2)
        wall(.left, from: cx - e, e, at: h0) { p in p.paintedBand(0, 2 * e * 32, 1, 2.6) }
        wall(.right, from: cx + e, e, at: h0) { p in p.paintedBand(0, 2 * e * 32, 1, 2.6) }
        // The crane: a jib out over the cellar, braced to the post and strapped with iron,
        // a pulley at its end, and a barrel in a sling; the winding drum on the post.
        let tip = head + P(-40, 9)
        pole(head + P(1.5, -1), tip, width: 2, colour: I.oakLight)
        pole(foot - P(0, 24), head + (tip - head) * 0.42, width: 1.3, colour: I.oakLight)
        for p in [head, head + (tip - head) * 0.42, foot - P(0, 24), head + (tip - head) * 0.8] {
            svg.circle(p, 1, fill: .colour(I.ironDark), stroke: .colour(I.line), width: 0.4)
        }
        let rope = tip + P(0, 17)
        line([tip, rope], width: 0.7)
        line([tip, head + P(0, 27)], width: 0.6)
        svg.circle(tip, 2, fill: .colour(I.timberLight), stroke: .colour(I.line), width: 0.7)
        svg.circle(tip, 0.6, fill: .colour(I.ironDark))
        line([rope, rope + P(-3, 3)], width: 0.6)
        line([rope, rope + P(3, 3)], width: 0.6)
        barrel(at: rope + P(0, 12), size: 0.85)
        let drum = head + P(0, 27)
        svg.ellipse(drum, 3, 2.2, fill: .colour(I.timber), stroke: .colour(I.line), width: 0.7)
        line([drum + P(-2.4, -0.4), drum + P(-5, -3.4)], width: 1.1)
        pennant(at: head - P(0, 1), height: 11, length: 13)
        finial(at: head - P(0, 0.4), size: 0.6)
        // Goods waiting in the yard.
        crate(0.62, 0.66, 0.9, 0.92, from: h0, height: 6)
        sack(at: iso(-0.55, 0.85, h0), size: 0.85)
        barrel(at: iso(-0.82, 0.62, h0), size: 0.8)
    }

    /// The store being dug: the cellar open, its lining of stone laid partway
    /// up the far walls, its earth heaped behind it, a ladder down into it,
    /// the crane's post and the shed's posts set up, and stone waiting.
    private mutating func cellarDug() {
        typealias I = AlchemyOldBuildingsInk
        let h0 = 1.5, floor = -7.0, e = 0.56, cx = 0.1, lining = 5.2, length = 2 * e * 32
        storeShed(roofed: false)
        heap(at: iso(-0.3, -0.85, h0), width: 30, height: 11)
        let foot = iso(0.8, -0.8, h0)
        pole(foot, foot - P(0, 34), width: 2.6, colour: I.oak)
        pennant(at: foot - P(0, 34), height: 10, length: 13)
        shell(cx - e, -e, cx + e, e, from: h0, floor: floor, to: h0, thickness: 0, lit: .colour(I.earthShade),
              shade: .colour(I.dark), top: .colour(I.earth), ground: .colour(I.earthShade), outer: false) { p in
            p.wall(.left, from: cx - e, -e, at: floor) { q in
                q.shape([q.uv(0, 0), q.uv(length, 0), q.uv(length, lining - 3), q.uv(length * 0.55, lining - 3),
                         q.uv(length * 0.55, lining), q.uv(0, lining)], .colour(I.rawStone), width: 0.8)
                q.courses(0, length, 0, lining - 3, course: 3, brick: 8, opacity: 0.6)
                q.courses(0, length * 0.55, lining - 3, lining, course: 3, brick: 8, opacity: 0.6)
            }
            p.wall(.right, from: cx - e, e, at: floor) { q in
                q.shape([q.uv(0, 0), q.uv(length, 0), q.uv(length, lining), q.uv(length * 0.45, lining),
                         q.uv(length * 0.45, lining - 3), q.uv(0, lining - 3)], .colour(I.rawStoneShade), width: 0.8)
                q.courses(0, length, 0, lining - 3, course: 3, brick: 8, opacity: 0.6)
                q.courses(length * 0.45, length, lining - 3, lining, course: 3, brick: 8, opacity: 0.6)
            }
            p.basket(at: p.iso(cx - 0.2, -0.3, floor), size: 0.9)
            p.ladder(foot: p.iso(cx - 0.3, -0.42, floor), p.iso(cx - 0.08, -0.42, floor), head: p.iso(cx - 0.3, -e - 0.1, h0 + 6),
                     p.iso(cx - 0.08, -e - 0.1, h0 + 6), rungs: 4)
        }
        blocks(0.7, 0.36, 0.94, 0.66, from: h0, courses: 2)
        blocks(0.4, 0.72, 0.66, 0.94, from: h0, courses: 1)
        // The kerb's first stones, and its band of the owner's colour already painted on them.
        wall(.left, from: cx - e, e, at: h0) { p in
            p.shape(p.panel(0, 0, length * 0.6, 3.6), .colour(I.rawStone), width: 0.8)
            p.paintedBand(1, length * 0.6 - 1, 1, 2.6)
        }
        basket(at: iso(-0.8, 0.8, h0), size: 1)
        timbers(-0.9, 0.62, length: 0.42, on: h0)
    }
}
