// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The oil field: a site of one tile, drawn as the terrain's sites are (on the
// same canvas, anchored at the tile's centre on the ground, with no team's
// colour). Crude oil seeps up through the ground into a dark pool with a sheen
// on it and a run spilling toward the front; the ground round it is stained;
// reeds grow at its back and side, and a bubble breaks on its face. It lies
// flat and low within the tile's diamond, so that an oil well standing over
// it covers it.

extension IndustrialNewBuildingsPainter {
    /// The oil field, on a canvas whose origin is the tile's centre on the ground.
    mutating func oilField() {
        typealias I = IndustrialNewBuildingsInk
        // The stain of the seep on the ground: a wide, faint, uneven halo.
        let halo = blob(0.0, 0.02, radius: 0.44, [1, 0.93, 0.86, 0.95, 1.05, 0.98, 0.9, 0.82, 0.88, 0.97, 1.04, 0.96])
        svg.path(smoothed(halo), fill: .colour(I.oil), opacity: 0.34)
        let damp = blob(0.04, 0.06, radius: 0.38, [1, 0.9, 1.06, 0.94, 0.86, 1.08, 0.98, 0.9, 1.02, 0.92])
        svg.path(smoothed(damp), fill: .colour(I.oil), opacity: 0.3)
        // Reeds at the back of the pool, behind it.
        reeds(at: iso(-0.3, -0.26), [(-3.2, 10, -2.4), (-1.2, 13, -0.6), (0.8, 11.5, 1.6), (2.6, 8.5, 3.2)], heads: [1])
        reeds(at: iso(0.26, -0.34), [(-2, 9, -1.6), (0, 11.5, 0.8), (1.8, 8, 2.4)], heads: [1])
        // The pool, and the run spilling from it toward the front.
        let pool = blob(-0.03, -0.03, radius: 0.36, [1, 1.08, 0.96, 0.88, 1.02, 1.12, 1.0, 0.9, 0.84, 0.94])
        let run = blob(0.25, 0.26, radius: 0.12, [1, 1.3, 1.1, 0.8, 0.9, 1.2, 0.9, 0.85])
        colour(I.oilShade, outline: run)
        colour(I.oilShade, outline: pool)
        svg.path(smoothed(pool.map { $0 + P(0.6, 0.5) }, scale: 0.82, about: iso(-0.03, -0.03)), fill: .colour(I.oil))
        svg.path(smoothed(run.map { $0 + P(0.4, 0.3) }, scale: 0.7, about: iso(0.25, 0.26)), fill: .colour(I.oil))
        svg.path(smoothed(pool), stroke: .colour(I.line), width: 1)
        svg.path(smoothed(run), stroke: .colour(I.line), width: 0.9)
        // The sheen: curls of blue-grey and a glint of the light on the pool's face.
        let c = iso(-0.03, -0.03)
        for (o, w, paint, width) in [(P(-6, -2.2), 11.0, I.oilSheen, 1.3), (P(3.5, 2), 8.0, I.oilSheen, 1.1),
                                     (P(-2.5, 3), 6.0, I.oilViolet, 1), (P(-7, -3.4), 4.0, I.light, 0.8)] {
            var d = PathData()
            d.move(c + o + P(-w / 2, 0.4)); d.quad(c + o + P(0, -1.3), c + o + P(w / 2, 0.3))
            svg.path(d, stroke: .colour(paint), width: width, opacity: 0.9)
        }
        // A bubble breaking on the face, and a small one beside it.
        let b = c + P(7.5, -1)
        svg.ellipse(b, 1.8, 1.1, fill: .colour(I.oilShade), stroke: .colour(I.line), width: 0.6)
        svg.circle(b + P(-0.6, -0.3), 0.45, fill: .colour(I.light))
        svg.ellipse(b + P(3.2, 1.2), 0.9, 0.55, fill: .none, stroke: .colour(I.oilSheen), width: 0.6)
        // A clump of reeds at the pool's left edge, in front of it.
        reeds(at: iso(-0.14, 0.34), [(-2.2, 8, -2.8), (-0.4, 10, -0.2), (1.4, 7, 1.6)], heads: [])
    }

    /// A field of colour, out of register with its line, bounded by the
    /// smoothed outline through `outline`.
    private mutating func colour(_ paint: String, outline: [P]) {
        let shift = self.shift
        svg.path(smoothed(outline.map { $0 + shift }), fill: .colour(paint))
    }

    /// An uneven closed outline round (x, y) on the ground, `radius` tiles,
    /// the radius scaled at each of its points in turn by `factors`.
    private func blob(_ x: Double, _ y: Double, radius r: Double, _ factors: [Double]) -> [P] {
        factors.enumerated().map { k, f in
            let a = Double(k) / Double(factors.count) * 2 * .pi
            return iso(x + cos(a) * r * f, y + sin(a) * r * f)
        }
    }

    /// A smooth closed path through the midpoints of the outline, its corners
    /// rounded, scaled by `scale` about `about`.
    private func smoothed(_ outline: [P], scale: Double = 1, about centre: P = P(0, 0)) -> PathData {
        let points = outline.map { centre + ($0 - centre) * scale }
        var d = PathData()
        let n = points.count
        d.move((points[n - 1] + points[0]) * 0.5)
        for k in 0..<n { d.quad(points[k], (points[k] + points[(k + 1) % n]) * 0.5) }
        d.close()
        return d
    }

    /// A clump of reeds standing at `foot`: each reed `(x, height, lean)` in
    /// points, a blade curving as it rises, green or dried; those numbered in
    /// `heads` carry a brown head.
    private mutating func reeds(at foot: P, _ blades: [(Double, Double, Double)], heads: [Int]) {
        typealias I = IndustrialNewBuildingsInk
        for (k, (x, h, lean)) in blades.enumerated() {
            let base = foot + P(x, 0), tip = foot + P(x + lean, -h)
            var d = PathData()
            d.move(base); d.quad(base + P(lean * 0.2, -h * 0.6), tip)
            svg.path(d, stroke: .colour(I.line), width: 1.7)
            svg.path(d, stroke: .colour(k % 3 == 2 ? I.reedDry : I.reed), width: 0.8)
            if heads.contains(k) {
                let head = foot + P(x + lean * 0.75, -h * 0.72)
                svg.ellipse(head, 0.9, 2.2, fill: .colour(I.timberDark), stroke: .colour(I.line), width: 0.5)
            }
        }
    }
}
