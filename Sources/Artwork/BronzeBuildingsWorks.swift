// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The things that stand about the Bronze-age buildings: what a building site
// needs (scaffold, stacked bricks, logs, a basket of mud, a ladder) and the
// household's jars and the temple's braziers. Places are given as on the map,
// in tiles from the footprint's centre, and heights in points.

extension BronzeBuildingsPainter {
    /// A pole of timber from `a` to `b` on the screen, outlined.
    mutating func pole(_ a: P, _ b: P, width: Double = 1.6, colour paint: String = BronzeBuildingsInk.timberLight) {
        svg.line([a, b], stroke: .colour(BronzeBuildingsInk.line), width: width + 1.1)
        svg.line([a, b], stroke: .colour(paint), width: width)
    }

    /// Scaffolding: upright poles standing at `feet` on the map, from `h0` up
    /// `height` points, tied by ledgers between neighbours at each of `levels`,
    /// with boards laid toward the wall at `boards`.
    mutating func scaffold(_ feet: [(x: Double, y: Double)], from h0: Double, height: Double, levels: [Double],
                           boards: Double? = nil) {
        typealias I = BronzeBuildingsInk
        if let boards {
            for (a, b) in zip(feet, feet.dropFirst()) {
                let dx = b.x - a.x, dy = b.y - a.y
                // The boards run from the poles back toward the wall they stand along.
                let nx = dy == 0 ? 0 : (dy > 0 ? 0.13 : -0.13), ny = dx == 0 ? 0 : (dx > 0 ? -0.13 : 0.13)
                let deck = [iso(a.x, a.y, h0 + boards), iso(b.x, b.y, h0 + boards), iso(b.x + nx, b.y + ny, h0 + boards),
                            iso(a.x + nx, a.y + ny, h0 + boards)]
                colour(deck, .colour(I.timberLight))
                colour([deck[0], deck[1], deck[1] + P(0, 1.3), deck[0] + P(0, 1.3)], .colour(I.timber))
                line(deck, closed: true, width: 0.7)
                line([deck[0] + P(0, 1.3), deck[1] + P(0, 1.3)], width: 0.7)
                for t in [0.33, 0.66] {
                    line([deck[0] + (deck[1] - deck[0]) * t, deck[3] + (deck[2] - deck[3]) * t], width: 0.45)
                }
            }
        }
        for level in levels {
            for (a, b) in zip(feet, feet.dropFirst()) {
                pole(iso(a.x, a.y, h0 + level), iso(b.x, b.y, h0 + level), width: 1.1)
            }
        }
        for foot in feet {
            pole(iso(foot.x, foot.y, h0), iso(foot.x, foot.y, h0 + height))
            // The lashings where the ledgers cross.
            for level in levels {
                let at = iso(foot.x, foot.y, h0 + level)
                line([at + P(-1.3, -0.9), at + P(1.3, 0.9)], width: 0.8)
            }
        }
    }

    /// Mud bricks stacked in courses on the map from (x0, y0) to (x1, y1), from `h0`.
    mutating func bricks(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double = 0, courses: Int) {
        typealias I = BronzeBuildingsInk
        let course = 2.4, h1 = h0 + Double(courses) * course
        block(x0, y0, x1, y1, h0, h1, top: .colour(I.sandTop), left: .colour(I.sand), right: .colour(I.sandShade), width: 0.9)
        for c in 1..<courses {
            let h = h0 + Double(c) * course
            line([iso(x0, y1, h), iso(x1, y1, h), iso(x1, y0, h)], width: 0.5, opacity: 0.8)
        }
        // The joints between bricks, staggered from course to course.
        for c in 0..<courses {
            let h = h0 + Double(c) * course
            let offset = c % 2 == 0 ? 0.0 : 0.5
            var t = 0.25 + offset * 0.25
            while t < 0.95 {
                let x = x0 + (x1 - x0) * t
                line([iso(x, y1, h + 0.3), iso(x, y1, h + course - 0.3)], width: 0.5, opacity: 0.8)
                let y = y1 + (y0 - y1) * t
                line([iso(x1, y, h + 0.3), iso(x1, y, h + course - 0.3)], width: 0.5, opacity: 0.8)
                t += 0.5
            }
        }
    }

    /// One log lying along the map's x axis from `x0` to `x1` at `y`, resting on
    /// `h`, `radius` points thick; its cut end shows toward +x.
    mutating func log(_ x0: Double, _ x1: Double, _ y: Double, on h: Double, radius r: Double = 2.2) {
        typealias I = BronzeBuildingsInk
        let body = [iso(x0, y, h), iso(x1, y, h), iso(x1, y, h + 2 * r), iso(x0, y, h + 2 * r)]
        colour(body, .colour(I.timber))
        line([body[3], body[2]], width: 0.9)
        line([body[0], body[1]], width: 0.9)
        line([iso(x0, y, h), iso(x0, y, h + 2 * r)], width: 0.9)
        let end = iso(x1, y, h + r)
        svg.ellipse(end + P(-0.5, 0.4), r * 0.62, r, fill: .colour(I.timberLight))
        svg.ellipse(end, r * 0.62, r, fill: .none, stroke: .colour(I.line), width: 0.8)
        svg.ellipse(end, r * 0.22, r * 0.4, fill: .none, stroke: .colour(I.line), width: 0.5)
    }

    /// A pile of logs along x centred on `y`: three below, two on them, one on
    /// top, drawn from the farthest to the nearest.
    mutating func logs(_ x0: Double, _ x1: Double, _ y: Double, on h: Double = 0, radius r: Double = 2.2) {
        // Side by side, the logs are a diameter apart on the screen: about 34 points a tile along y.
        let spacing = 2 * r / 34
        var pile: [(y: Double, h: Double)] = []
        for (row, count) in [3, 2, 1].enumerated() {
            for i in 0..<count {
                pile.append((y + (Double(i) - Double(count - 1) / 2) * spacing, h + Double(row) * r * 1.7))
            }
        }
        for one in pile.sorted(by: { ($0.y, $0.h) < ($1.y, $1.h) }) { log(x0, x1, one.y, on: one.h, radius: r) }
    }

    /// A roof of reed thatch: its top given by four corners on the screen in
    /// the order of `level` (back, right, front, left), `thickness` points deep
    /// at its two front edges, with straw hatched over it running from the
    /// back edges toward the front, and a ragged fringe of straw ends below.
    mutating func thatch(_ c: [P], thickness: Double) {
        typealias I = BronzeBuildingsInk
        let edge = P(0, thickness)
        colour([c[3], c[2], c[2] + edge, c[3] + edge], .colour(I.reedShade))
        colour([c[2], c[1], c[1] + edge, c[2] + edge], .colour(I.reedShade))
        colour(c, .colour(I.reed))
        // Straw: short strokes in rows across the roof, each pointing to the front corner.
        var d = PathData()
        let rows = 7, columns = 8
        for i in 0..<rows {
            for j in 0..<columns {
                let s = (Double(i) + 0.5 + (j % 2 == 0 ? 0 : 0.35)) / Double(rows), t = (Double(j) + 0.5) / Double(columns)
                let a = c[0] + (c[1] - c[0]) * t, b = c[3] + (c[2] - c[3]) * t
                let p = a + (b - a) * s
                let toward = (c[2] - c[0]) * (1 / 14.0)
                let length = 0.8 + Double((i * 7 + j * 3) % 4) * 0.12
                d.move(p - toward * length)
                d.line(p + toward * length)
            }
        }
        svg.path(d, stroke: .colour(I.reedShade), width: 0.55)
        line(c, closed: true, width: 0.9)
        // The fringe: straw ends hanging below the two front edges.
        var fringe = PathData()
        for (a, b) in [(c[3], c[2]), (c[2], c[1])] {
            let count = Int(((b - a).x.magnitude + (b - a).y.magnitude) / 2.2)
            for k in 0...count {
                let p = a + (b - a) * (Double(k) / Double(max(count, 1))) + edge
                fringe.move(p)
                fringe.line(p + P(k % 2 == 0 ? -0.3 : 0.3, k % 3 == 0 ? 2.2 : 1.5))
            }
        }
        svg.path(fringe, stroke: .colour(I.line), width: 0.6)
        line([c[3] + edge, c[2] + edge, c[1] + edge], width: 0.8)
        line([c[3], c[3] + edge], width: 0.8)
        line([c[2], c[2] + edge], width: 0.8)
        line([c[1], c[1] + edge], width: 0.8)
    }

    /// A basket of wet mud standing at `at` on the screen.
    mutating func basket(at p: P, size s: Double = 1) {
        typealias I = BronzeBuildingsInk
        let body = [p + P(-3.4 * s, -4 * s), p + P(3.4 * s, -4 * s), p + P(2.6 * s, 0), p + P(-2.6 * s, 0)]
        shape(body, .colour(I.reed), width: 0.8)
        svg.ellipse(p + P(0, -4 * s), 3.4 * s, 1.2 * s, fill: .colour(I.timberDark), stroke: .colour(I.line), width: 0.7)
        line([p + P(-3 * s, -2.2 * s), p + P(3 * s, -2.2 * s)], width: 0.5)
    }

    /// A ladder from its feet to its head, both given as pairs of points on the screen.
    mutating func ladder(foot a: P, _ b: P, head c: P, _ d: P, rungs: Int) {
        typealias I = BronzeBuildingsInk
        pole(a, c, width: 1)
        pole(b, d, width: 1)
        for i in 1...rungs {
            let t = Double(i) / Double(rungs + 1)
            svg.line([a + (c - a) * t, b + (d - b) * t], stroke: .colour(I.line), width: 1)
        }
    }

    /// A tall jar of fired clay standing at `p` on the screen, `size` times its usual size.
    mutating func jar(at p: P, size s: Double = 1, paint: String = BronzeBuildingsInk.terracotta) {
        typealias I = BronzeBuildingsInk
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-1.4 * s, 0) + o)
            d.cubic(p + P(-4.6 * s, -1.5 * s) + o, p + P(-4.6 * s, -7.5 * s) + o, p + P(-1.6 * s, -8.6 * s) + o)
            d.line(p + P(-1.6 * s, -10 * s) + o)
            d.line(p + P(1.6 * s, -10 * s) + o)
            d.line(p + P(1.6 * s, -8.6 * s) + o)
            d.cubic(p + P(4.6 * s, -7.5 * s) + o, p + P(4.6 * s, -1.5 * s) + o, p + P(1.4 * s, 0) + o)
            d.close()
            return d
        }
        colour(.colour(paint)) { d, o in d = outline(o) }
        line(width: 0.9) { d in d = outline(P(0, 0)) }
        line([p + P(-3.3 * s, -5.6 * s), p + P(3.3 * s, -5.6 * s)], width: 0.6)
        line([p + P(-2.2 * s, -10 * s), p + P(2.2 * s, -10 * s)], width: 1)
    }

    /// A bronze brazier on three legs standing at `p` on the screen, with its fire.
    mutating func brazier(at p: P) {
        typealias I = BronzeBuildingsInk
        line([p + P(-2.6, 0), p + P(-1.6, -4.5)], width: 0.8)
        line([p + P(2.6, 0), p + P(1.6, -4.5)], width: 0.8)
        line([p + P(0, 0.6), p + P(0, -4.5)], width: 0.8)
        // The flame: two tongues, the inner paler.
        var flame = PathData()
        flame.move(p + P(-2.4, -6.2))
        flame.quad(p + P(-2.6, -9.6), p + P(-0.4, -12.6))
        flame.quad(p + P(0.2, -10), p + P(1, -11.6))
        flame.quad(p + P(2.8, -9), p + P(2.4, -6.2))
        flame.close()
        svg.path(flame, fill: .colour(I.terracottaTop), stroke: .colour(I.line), width: 0.6)
        svg.ellipse(p + P(0, -7.4), 1.1, 1.8, fill: .colour(I.bronzeLight))
        let bowl = [p + P(-3.6, -6.6), p + P(3.6, -6.6), p + P(2.2, -4.2), p + P(-2.2, -4.2)]
        shape(bowl, .colour(I.bronze), width: 0.8)
    }
}
