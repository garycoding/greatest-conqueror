// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age storage pit: the Stone age's pit grown into a store. A deep
// pit lined with fired brick, its rim painted with the owner's colour, holds
// timber, stone and ingots of bronze; a counterweighted hoist on a post lifts
// a basket out of it, and more goods stand stacked about the yard. Its
// footprint is two tiles square: x and y run from -1 to 1.

extension BronzeBuildingsPainter {
    mutating func storagePit(complete: Bool) {
        typealias I = BronzeBuildingsInk
        // The beaten yard.
        block(-1, -1, 1, 1, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade), width: 1)
        if complete { store() } else { storeDug() }
    }

    private mutating func store() {
        typealias I = BronzeBuildingsInk
        let h0 = 1.5, rim = 4.5, floor = -9.0, e = 0.66
        // The hoist's post at the back, behind the pit.
        let foot = iso(0.8, -0.8, h0), pivot = foot - P(0, 36)
        pole(foot, pivot - P(0, 2), width: 2.2, colour: I.timber)
        // Goods at the back of the yard: a pile of logs, and stone blocks.
        logs(-0.95, -0.4, -0.86, on: h0, radius: 1.8)
        shell(-e, -e, e, e, from: h0, floor: floor, to: rim, thickness: 0.07, lit: .colour(I.terracotta),
              shade: .colour(I.terracottaShade), top: .colour(I.terracottaTop), ground: .colour(I.dark)) { p in
            // In the pit, the farther first: ingots of bronze, dressed stone, and jars.
            p.ingots(-0.32, -0.36, on: floor, count: 5)
            p.stones(0.2, -0.36, on: floor)
            p.jar(at: p.iso(-0.44, 0.1, floor), size: 1.3, paint: I.clay)
            p.jar(at: p.iso(-0.4, 0.34, floor), size: 1.2)
        }
        // The rim's band in the owner's colour, on its two outer faces.
        wall(.left, from: -e, e, at: h0) { p in p.paintedBand(0, 2 * e * 32, 0.95, 2.05) }
        wall(.right, from: e, e, at: h0) { p in p.paintedBand(0, 2 * e * 32, 0.95, 2.05) }
        // The hoist: a beam across the top of the post, weighted with a stone
        // at its short end, a basket hanging from its long end over the pit.
        let tip = pivot + P(-40, -10), tail = pivot + P(9, 4)
        pole(tail, tip, width: 1.6)
        let rope = tip + P(0, 22)
        line([tip, rope], width: 0.7)
        basket(at: rope + P(0, 6), size: 0.9)
        svg.ellipse(tail + P(0.6, 4.6), 3.6, 3, fill: .colour(I.stoneShade), stroke: .colour(I.line), width: 0.9)
        line([tail, tail + P(0.4, 1.8)], width: 0.7)
        svg.circle(pivot, 1.3, fill: .colour(I.bronzeLight), stroke: .colour(I.line), width: 0.6)
        pennant(at: pivot - P(0, 1), height: 11, length: 14)
        // Jars at the yard's left corner.
        jar(at: iso(-0.82, 0.82, h0), size: 1.05)
        jar(at: iso(-0.6, 0.88, h0), size: 0.85, paint: I.clay)
    }

    /// Ingots of bronze cast in the shape of a hide, stacked `count` high at
    /// (x, y) on `h`, each laid across the one below.
    fileprivate mutating func ingots(_ x: Double, _ y: Double, on h: Double, count: Int) {
        typealias I = BronzeBuildingsInk
        let thick = 1.8
        for i in 0..<count {
            let b = h + Double(i) * thick
            let (a, c) = i % 2 == 0 ? (0.15, 0.09) : (0.09, 0.15)
            let (x0, y0, x1, y1) = (x - a, y - c, x + a, y + c)
            // The sides, then the top with its four corners drawn out like a hide's.
            colour([iso(x0, y1, b), iso(x1, y1, b), iso(x1, y1, b + thick), iso(x0, y1, b + thick)], .colour(I.bronze))
            colour([iso(x1, y1, b), iso(x1, y0, b), iso(x1, y0, b + thick), iso(x1, y1, b + thick)], .colour(I.bronzeShade))
            let top = b + thick, pull = 0.035
            let hide = [iso(x0, y0, top), iso((x0 + x1) / 2, y0 + pull, top), iso(x1, y0, top), iso(x1 - pull, (y0 + y1) / 2, top),
                        iso(x1, y1, top), iso((x0 + x1) / 2, y1 - pull, top), iso(x0, y1, top), iso(x0 + pull, (y0 + y1) / 2, top)]
            colour(hide, .colour(I.bronzeLight))
            line(hide, closed: true, width: 0.6)
            line([iso(x0, y1, top), iso(x0, y1, b), iso(x1, y1, b), iso(x1, y0, b), iso(x1, y0, top)], width: 0.6)
            line([iso(x1, y1, b), iso(x1, y1, top)], width: 0.6)
        }
    }

    /// A small heap of dressed stone blocks at (x, y) on `h`.
    fileprivate mutating func stones(_ x: Double, _ y: Double, on h: Double) {
        typealias I = BronzeBuildingsInk
        let s = 0.13
        for (dx, dy, dh) in [(-s, -s, 0.0), (s * 0.2, -s * 1.1, 0.0), (-s * 1.1, s * 0.2, 0.0), (0, 0, 0.0), (-s * 0.5, -s * 0.5, 5.2)] {
            let (cx, cy) = (x + dx, y + dy)
            block(cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2, h + dh, h + dh + 5.2, top: .colour(I.stoneTop),
                  left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.8)
        }
    }

    /// The store being dug: the pit open, its lining of fired brick laid
    /// partway up the far walls, its earth heaped behind it, a ladder down into
    /// it, the hoist's post set up, bricks waiting.
    private mutating func storeDug() {
        typealias I = BronzeBuildingsInk
        let h0 = 1.5, floor = -7.0, e = 0.62, lining = 4.4, length = 2 * e * 32
        let foot = iso(0.8, -0.8, h0)
        // The spoil: a heap of earth behind the pit.
        heap(at: iso(-0.66, -0.66, h0), width: 34, height: 12)
        pole(foot, foot - P(0, 30), width: 2.2, colour: I.timber)
        pennant(at: foot - P(0, 30), height: 10, length: 14)
        shell(-e, -e, e, e, from: h0, floor: floor, to: h0, thickness: 0, lit: .colour(I.earthShade),
              shade: .colour(I.dark), top: .colour(I.earth), ground: .colour(I.earthShade), outer: false) { p in
            // The lining's first courses on the two far walls, stepping down where the work has reached.
            p.wall(.left, from: -e, -e, at: floor) { q in
                q.shape([q.uv(0, 0), q.uv(length, 0), q.uv(length, lining - 2.2), q.uv(length * 0.6, lining - 2.2),
                         q.uv(length * 0.6, lining), q.uv(0, lining)], .colour(I.terracotta), width: 0.8)
                q.courses(0, length, 0, lining - 2.2, course: 2.2, brick: 5.6, opacity: 0.6)
                q.courses(0, length * 0.6, lining - 2.2, lining, course: 2.2, brick: 5.6, opacity: 0.6)
            }
            p.wall(.right, from: -e, e, at: floor) { q in
                q.shape([q.uv(0, 0), q.uv(length, 0), q.uv(length, lining), q.uv(length * 0.45, lining),
                         q.uv(length * 0.45, lining - 2.2), q.uv(0, lining - 2.2)], .colour(I.terracottaShade), width: 0.8)
                q.courses(0, length, 0, lining - 2.2, course: 2.2, brick: 5.6, opacity: 0.6)
                q.courses(length * 0.45, length, lining - 2.2, lining, course: 2.2, brick: 5.6, opacity: 0.6)
            }
            p.basket(at: p.iso(-0.2, -0.3, floor), size: 0.9)
            p.ladder(foot: p.iso(-0.3, -0.45, floor), p.iso(-0.08, -0.45, floor), head: p.iso(-0.3, -e - 0.1, h0 + 6),
                     p.iso(-0.08, -e - 0.1, h0 + 6), rungs: 4)
        }
        bricks(0.7, 0.38, 0.92, 0.66, from: h0, courses: 3)
        bricks(0.38, 0.72, 0.62, 0.92, from: h0, courses: 2)
        basket(at: iso(-0.78, 0.8, h0), size: 1)
        logs(-0.7, -0.2, 0.84, on: h0, radius: 1.5)
    }

    /// A heap of loose earth standing at `p` on the screen.
    mutating func heap(at p: P, width w: Double, height h: Double) {
        typealias I = BronzeBuildingsInk
        // Two humps, the larger behind, spreading low at the foot.
        func trace(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-w / 2, 0) + o)
            d.quad(p + P(-w * 0.4, -h * 0.45) + o, p + P(-w * 0.18, -h * 0.8) + o)
            d.quad(p + P(-w * 0.05, -h * 1.05) + o, p + P(w * 0.06, -h * 0.72) + o)
            d.quad(p + P(w * 0.16, -h * 0.68) + o, p + P(w * 0.26, -h * 0.5) + o)
            d.quad(p + P(w * 0.42, -h * 0.25) + o, p + P(w / 2, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.earth)) { d, o in d = trace(o) }
        // The shaded flank on the right.
        svg.path("M\(num(p.x + w * 0.06)),\(num(p.y - h * 0.72)) q\(num(w * 0.1)),\(num(h * 0.04)) \(num(w * 0.2)),\(num(h * 0.22)) "
                 + "q\(num(w * 0.16)),\(num(h * 0.25)) \(num(w * 0.24)),\(num(h * 0.5)) L\(num(p.x + w * 0.1)),\(num(p.y)) Z",
                 fill: .colour(I.earthShade))
        line(width: 0.9) { d in d = trace(P(0, 0)) }
        for (dx, dy) in [(-0.26, -0.3), (-0.1, -0.62), (0.12, -0.4), (0.3, -0.18), (-0.36, -0.12), (0.02, -0.2)] {
            svg.circle(p + P(w * dx, h * dy), 0.6, fill: .colour(I.line), opacity: 0.55)
        }
    }
}
