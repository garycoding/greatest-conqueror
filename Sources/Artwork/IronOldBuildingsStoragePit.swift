// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age storage pit: the Bronze age's store grown one age richer. A deep
// pit lined with dressed stone, its kerb painted with the owner's colour,
// holds timber, stone and bars of iron; a crane of timber with iron fittings
// lifts a basket out of it on a pulley, a shelter of red tile keeps amphorae
// dry at the back, and more goods stand about the paved yard. Its footprint is
// two tiles square: x and y run from -1 to 1.

extension IronOldBuildingsPainter {
    mutating func storagePit(complete: Bool) {
        typealias I = IronOldBuildingsInk
        // The yard, paved with flagstones.
        block(-1, -1, 1, 1, 0, 1.5, top: .colour(I.paving), left: .colour(I.pavingShade), right: .colour(I.pavingShade),
              width: 1)
        if complete { store() } else { storeDug() }
    }

    private mutating func store() {
        typealias I = IronOldBuildingsInk
        let h0 = 1.5, rim = 5.0, floor = -4.0, e = 0.62
        // The shelter at the back left: a roof of tile on four posts over amphorae.
        let (s0, s1, t0, t1) = (-0.98, -0.66, -0.98, -0.2)
        shadow(level(s0, t0, s1 + 0.1, t1 + 0.12, h0), opacity: 0.16)
        for (x, y) in [(s0 + 0.03, t0 + 0.03), (s1, t0 + 0.03)] { pole(iso(x, y, h0), iso(x, y, h0 + 24), width: 1.4) }
        for i in 0..<3 { amphora(at: iso(-0.84, -0.84 + Double(i) * 0.22, h0), size: 0.72, paint: i == 1 ? I.clayShade : I.clay) }
        for (x, y) in [(s0 + 0.03, t1), (s1, t1)] { pole(iso(x, y, h0), iso(x, y, h0 + 24), width: 1.4) }
        hippedRoof(s0, t0, s1, t1, eaves: h0 + 24, overhang: 0.04)
        // The crane's post at the back right, behind the pit.
        let foot = iso(0.8, -0.8, h0), head = foot - P(0, 40)
        pole(foot, head, width: 2.4, colour: I.timber)
        shell(-e, -e, e, e, from: h0, floor: floor, to: rim, thickness: 0.07, lit: .colour(I.stone),
              shade: .colour(I.stoneShade), top: .colour(I.stoneTop), ground: .colour(I.dark)) { p in
            // The lining's courses on the far walls.
            let length = 2 * (e - 0.07) * 32
            p.wall(.left, from: -e + 0.07, -e + 0.07, at: floor) { q in q.courses(0, length, 0, rim - floor, course: 3.4, brick: 9) }
            p.wall(.right, from: -e + 0.07, e - 0.07, at: floor) { q in q.courses(0, length, 0, rim - floor, course: 3.4, brick: 9) }
            // In the pit, the farther first: bars of iron, dressed stone, and amphorae.
            p.ironBars(-0.28, -0.32, on: floor, count: 5)
            p.stones(0.2, -0.32, on: floor)
            p.amphora(at: p.iso(-0.4, 0.1, floor), size: 0.9)
            p.amphora(at: p.iso(-0.36, 0.3, floor), size: 0.85, paint: I.clayShade)
        }
        // The yard in front of the kerb, over the pit's floor where it would show below the kerb's foot.
        colour(level(-e, e, e, 0.99, h0), .colour(I.paving))
        colour(level(e, -e, 0.99, 0.99, h0), .colour(I.paving))
        line([iso(-e, e, h0), iso(e, e, h0), iso(e, -e, h0)], width: 1.2)
        // The kerb's band in the owner's colour, on its two outer faces.
        wall(.left, from: -e, e, at: h0) { p in p.paintedBand(0, 2 * e * 32, 1, 2.5) }
        wall(.right, from: e, e, at: h0) { p in p.paintedBand(0, 2 * e * 32, 1, 2.5) }
        // The crane: a jib out over the pit, braced to the post, a pulley at its
        // end, and a rope down to a basket; the winding drum on the post.
        let tip = head + P(-42, 10)
        pole(head + P(1.5, -1), tip, width: 1.8, colour: I.timberLight)
        pole(foot - P(0, 22), head + (tip - head) * 0.42, width: 1.2, colour: I.timberLight)
        for p in [head, head + (tip - head) * 0.42, foot - P(0, 22)] {
            svg.circle(p, 0.9, fill: .colour(I.ironDark), stroke: .colour(I.line), width: 0.4)
        }
        let rope = tip + P(0, 19)
        line([tip, rope], width: 0.7)
        line([tip, head + P(0, 26)], width: 0.6)
        svg.circle(tip, 2, fill: .colour(I.timberLight), stroke: .colour(I.line), width: 0.7)
        svg.circle(tip, 0.6, fill: .colour(I.ironDark))
        line([rope, rope + P(-1.8, 2)], width: 0.6)
        line([rope, rope + P(1.8, 2)], width: 0.6)
        basket(at: rope + P(0, 6.6), size: 0.9)
        let drum = head + P(0, 26)
        svg.ellipse(drum, 3, 2, fill: .colour(I.timber), stroke: .colour(I.line), width: 0.7)
        line([drum + P(-2.4, -0.4), drum + P(-5, -3.4)], width: 1.1)
        pennant(at: head - P(0, 1), height: 11, length: 14)
        // Stone and timber at the front of the yard.
        blocks(0.68, 0.4, 0.92, 0.7, from: h0, courses: 2)
        logs(-0.72, -0.2, 0.84, on: h0, radius: 1.5)
    }

    /// Bars of iron stacked `count` layers high at (x, y) on `h`, each layer
    /// laid across the one below.
    fileprivate mutating func ironBars(_ x: Double, _ y: Double, on h: Double, count: Int) {
        typealias I = IronOldBuildingsInk
        let thick = 1.7
        for i in 0..<count {
            let b = h + Double(i) * thick
            for k in [-1.0, 1.0] {
                let (x0, y0, x1, y1) = i % 2 == 0
                    ? (x - 0.17, y + k * 0.05 - 0.035, x + 0.17, y + k * 0.05 + 0.035)
                    : (x + k * 0.05 - 0.035, y - 0.17, x + k * 0.05 + 0.035, y + 0.17)
                block(x0, y0, x1, y1, b, b + thick, top: .colour(I.ironLight), left: .colour(I.iron), right: .colour(I.ironDark),
                      width: 0.6)
            }
        }
    }

    /// A small heap of dressed stone blocks at (x, y) on `h`.
    fileprivate mutating func stones(_ x: Double, _ y: Double, on h: Double) {
        typealias I = IronOldBuildingsInk
        let s = 0.13
        for (dx, dy, dh) in [(-s, -s, 0.0), (s * 0.2, -s * 1.1, 0.0), (-s * 1.1, s * 0.2, 0.0), (0, 0, 0.0), (-s * 0.5, -s * 0.5, 5.2)] {
            let (cx, cy) = (x + dx, y + dy)
            block(cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2, h + dh, h + dh + 5.2, top: .colour(I.stoneTop),
                  left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.8)
        }
    }

    /// The store being dug: the pit open, its lining of stone laid partway up
    /// the far walls, its earth heaped behind it, a ladder down into it, the
    /// crane's post set up, and stone waiting.
    private mutating func storeDug() {
        typealias I = IronOldBuildingsInk
        let h0 = 1.5, floor = -7.0, e = 0.6, lining = 5.2, length = 2 * e * 32
        let foot = iso(0.8, -0.8, h0)
        // The spoil: a heap of earth behind the pit.
        heap(at: iso(-0.66, -0.66, h0), width: 34, height: 12)
        pole(foot, foot - P(0, 32), width: 2.4, colour: I.timber)
        pennant(at: foot - P(0, 32), height: 10, length: 14)
        shell(-e, -e, e, e, from: h0, floor: floor, to: h0, thickness: 0, lit: .colour(I.earthShade),
              shade: .colour(I.dark), top: .colour(I.earth), ground: .colour(I.earthShade), outer: false) { p in
            // The lining's first courses on the two far walls, stepping down where the work has reached.
            p.wall(.left, from: -e, -e, at: floor) { q in
                q.shape([q.uv(0, 0), q.uv(length, 0), q.uv(length, lining - 3), q.uv(length * 0.55, lining - 3),
                         q.uv(length * 0.55, lining), q.uv(0, lining)], .colour(I.rawStone), width: 0.8)
                q.courses(0, length, 0, lining - 3, course: 3, brick: 9, opacity: 0.6)
                q.courses(0, length * 0.55, lining - 3, lining, course: 3, brick: 9, opacity: 0.6)
            }
            p.wall(.right, from: -e, e, at: floor) { q in
                q.shape([q.uv(0, 0), q.uv(length, 0), q.uv(length, lining), q.uv(length * 0.45, lining),
                         q.uv(length * 0.45, lining - 3), q.uv(0, lining - 3)], .colour(I.rawStoneShade), width: 0.8)
                q.courses(0, length, 0, lining - 3, course: 3, brick: 9, opacity: 0.6)
                q.courses(length * 0.45, length, lining - 3, lining, course: 3, brick: 9, opacity: 0.6)
            }
            p.basket(at: p.iso(-0.2, -0.3, floor), size: 0.9)
            p.ladder(foot: p.iso(-0.3, -0.45, floor), p.iso(-0.08, -0.45, floor), head: p.iso(-0.3, -e - 0.1, h0 + 6),
                     p.iso(-0.08, -e - 0.1, h0 + 6), rungs: 4)
        }
        blocks(0.68, 0.36, 0.92, 0.66, from: h0, courses: 2)
        blocks(0.36, 0.7, 0.62, 0.92, from: h0, courses: 1)
        basket(at: iso(-0.78, 0.8, h0), size: 1)
        logs(-0.7, -0.2, 0.84, on: h0, radius: 1.5)
    }
}
