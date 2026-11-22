// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The parts the Iron age adds to the older buildings: roofs of red tile, hipped
// or gabled under a pediment, columns of plastered stone, windows barred with
// iron or closed by painted shutters, the legion's oblong shield and its
// standard, and the wreath that marks the owner's colour.

extension IronOldBuildingsPainter {
    // MARK: Roofs

    /// One slope of a roof of red tile. Its eave runs from `start` on the map
    /// along the unit vector `along` for `length` tiles at `h` points up; the
    /// slope rises toward `inward` for `depth` tiles to the ridge at `top`
    /// points. A hip cuts in `hip0` tiles at the eave's start and `hip1` at its
    /// end (zero for a gable). The tiles are laid in rows of cover tiles running
    /// up the slope, crossed by the courses; `rows` is false for a slope that
    /// barely shows.
    private mutating func slope(_ start: (Double, Double), along: (Double, Double), inward: (Double, Double),
                                length: Double, depth: Double, hip0: Double, hip1: Double, from h: Double,
                                to top: Double, _ paint: String, rows: Bool) {
        typealias I = IronOldBuildingsInk
        func at(_ u: Double, _ s: Double) -> P {
            iso(start.0 + along.0 * u + inward.0 * depth * s, start.1 + along.1 * u + inward.1 * depth * s, h + (top - h) * s)
        }
        let outline = [at(0, 0), at(length, 0), at(length - hip1, 1), at(hip0, 1)]
        colour(outline, .colour(paint))
        if rows {
            // The cover tiles: a raised roll of tile, lit on its left, every tenth of a tile.
            let pitch = 0.1
            var light = PathData(), dark = PathData()
            var u = pitch / 2
            while u < length - 0.02 {
                var reach = 1.0
                if hip0 > 0 { reach = min(reach, u / hip0) }
                if hip1 > 0 { reach = min(reach, (length - u) / hip1) }
                if reach > 0.08 {
                    light.move(at(u, 0) + P(-0.7, 0)); light.line(at(u, reach) + P(-0.7, 0))
                    dark.move(at(u, 0)); dark.line(at(u, reach))
                }
                u += pitch
            }
            svg.path(light, stroke: .colour(I.tileLight), width: 0.8, opacity: 0.9)
            svg.path(dark, stroke: .colour(I.tileDark), width: 0.5, opacity: 0.85)
            // The courses across the slope.
            var courses = PathData()
            for s in stride(from: 0.22, to: 0.95, by: 0.22) {
                courses.move(at(hip0 * s, s)); courses.line(at(length - hip1 * s, s))
            }
            svg.path(courses, stroke: .colour(I.tileDark), width: 0.4, opacity: 0.55)
        }
        line(outline, closed: true, width: 1)
    }

    /// The thickness of tile along an eave from `a` to `b` on the screen, with
    /// the round ends of the cover tiles along it.
    private mutating func eave(_ a: P, _ b: P, ends: Int) {
        typealias I = IronOldBuildingsInk
        let drop = P(0, 1.8)
        shape([a, b, b + drop, a + drop], .colour(I.tileDark), width: 0.8)
        for i in 0..<ends {
            let p = a + (b - a) * ((Double(i) + 0.5) / Double(ends)) + drop * 0.5
            svg.circle(p, 0.75, fill: .colour(I.tileShade), stroke: .colour(I.line), width: 0.4)
        }
    }

    /// A hipped roof of red tile over the block from (x0, y0) to (x1, y1),
    /// overhanging it by `overhang` tiles, its eaves at `h` points and its ridge
    /// `rise` points above them; a square block takes a pyramid. Without a
    /// `rise` the roof is pitched just steeply enough that its far slopes show
    /// only as a sliver above the ridge, as a shallower roof would show them
    /// as a second, flat-looking roof behind the first. Returns the height of the ridge.
    @discardableResult
    mutating func hippedRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eaves h: Double, rise: Double? = nil,
                             overhang o: Double = 0.06) -> Double {
        typealias I = IronOldBuildingsInk
        let (a, b, c, d) = (x0 - o, y0 - o, x1 + o, y1 + o)
        let lx = c - a, ly = d - b
        let k = min(lx, ly) / 2
        // A far slope is edge-on at a rise of 32 points for each tile from its eave to the ridge.
        let top = h + (rise ?? 30 * k)
        // The two slopes at the back first, which the nearer two hide but at the ridge.
        slope((c, b), along: (-1, 0), inward: (0, 1), length: lx, depth: k, hip0: k, hip1: k, from: h, to: top, I.tileLight,
              rows: false)
        slope((a, b), along: (0, 1), inward: (1, 0), length: ly, depth: k, hip0: k, hip1: k, from: h, to: top, I.tileLight,
              rows: false)
        slope((a, d), along: (1, 0), inward: (0, -1), length: lx, depth: k, hip0: k, hip1: k, from: h, to: top, I.tile,
              rows: true)
        slope((c, d), along: (0, -1), inward: (-1, 0), length: ly, depth: k, hip0: k, hip1: k, from: h, to: top, I.tileShade,
              rows: true)
        eave(iso(a, d, h), iso(c, d, h), ends: Int(lx / 0.1))
        eave(iso(c, d, h), iso(c, b, h), ends: Int(ly / 0.1))
        // The ridge and the hips, capped with tile.
        let wide = lx >= ly
        let r0 = iso(a + k, b + k, top), r1 = wide ? iso(c - k, b + k, top) : iso(a + k, d - k, top)
        let hips = wide ? [(iso(a, d, h), r0), (iso(c, d, h), r1), (iso(c, b, h), r1)]
                        : [(iso(a, d, h), r1), (iso(c, d, h), r1), (iso(c, b, h), r0)]
        for (p, q) in hips {
            svg.line([p, q], stroke: .colour(I.line), width: 1.9)
            svg.line([p, q], stroke: .colour(I.tileShade), width: 0.9)
        }
        svg.line([r0, r1], stroke: .colour(I.line), width: 2.6)
        svg.line([r0, r1], stroke: .colour(I.tileDark), width: 1.4)
        return top
    }

    /// A gabled roof of red tile over the block from (x0, y0) to (x1, y1), its
    /// ridge running along y and its gable facing +y (the screen's lower left),
    /// closed by a pediment of plastered stone whose face carries the owner's
    /// colour round a light wreath. The eaves are at `h`, the ridge `rise` above.
    mutating func gabledRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eaves h: Double, rise: Double,
                             overhang o: Double = 0.06) {
        typealias I = IronOldBuildingsInk
        let (a, b, c, d) = (x0 - o, y0 - o, x1 + o, y1 + 0.02)
        let lx = c - a, ly = d - b, top = h + rise
        slope((a, b), along: (0, 1), inward: (1, 0), length: ly, depth: lx / 2, hip0: 0, hip1: 0, from: h, to: top, I.tileLight,
              rows: false)
        slope((c, d), along: (0, -1), inward: (-1, 0), length: ly, depth: lx / 2, hip0: 0, hip1: 0, from: h, to: top,
              I.tileShade, rows: true)
        eave(iso(c, d, h), iso(c, b, h), ends: Int(ly / 0.1))
        svg.line([iso((a + c) / 2, b, top), iso((a + c) / 2, d, top)], stroke: .colour(I.line), width: 2.8)
        svg.line([iso((a + c) / 2, b, top), iso((a + c) / 2, d, top)], stroke: .colour(I.tileDark), width: 1.5)
        // The pediment on the gable.
        let w = lx * 32
        wall(.left, from: a, d, at: h) { p in
            let edge = 2.4, slant = edge * (w / 2) / rise
            p.shape([p.uv(0, 0), p.uv(w, 0), p.uv(w / 2, rise)], .colour(I.light), width: 1.1)
            // The tympanum, inside the cornices: the owner's colour, with a wreath.
            let inner = [p.uv(slant * 1.1, edge), p.uv(w - slant * 1.1, edge), p.uv(w / 2, rise - edge * 1.15)]
            p.shape(inner, .team, width: 0.8)
            p.wreath(at: p.uv(w / 2, edge + (rise - 2.15 * edge) * 0.36), radius: min(3.2, rise * 0.16))
            // The cornice's mouldings, and the row of dentils under the slopes.
            p.line([p.uv(0, edge * 0.45), p.uv(w, edge * 0.45)], width: 0.5, opacity: 0.7)
            // The tiles of the slopes show along the pediment's top.
            p.line([p.uv(-0.6, -0.2), p.uv(w / 2, rise + 1.2), p.uv(w + 0.6, -0.2)], width: 1.6)
            // Acroteria: a palmette at the apex and at each corner.
            for (u, v) in [(w / 2, rise + 1), (1.2, 0.6), (w - 1.2, 0.6)] { p.palmette(at: p.uv(u, v)) }
        }
    }

    /// A small fan-shaped ornament of plaster standing at `p` on a wall.
    private mutating func palmette(at p: P) {
        typealias I = IronOldBuildingsInk
        func trace(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-1.2, 0) + o)
            d.quad(p + P(-2.6, -3.6) + o, p + P(0, -4.6) + o)
            d.quad(p + P(2.6, -3.6) + o, p + P(1.2, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.light)) { d, o in d = trace(o) }
        line(width: 0.7) { d in d = trace(P(0, 0)) }
        line([p + P(0, -0.4), p + P(0, -3.6)], width: 0.4)
    }

    // MARK: Columns, windows, doors

    /// A column of plastered stone standing at `foot` on the screen, `height`
    /// points to the top of its capital and `radius` points thick: a moulded
    /// base, a fluted shaft lit on its left, and a capital under a square abacus.
    mutating func column(at foot: P, height: Double, radius r: Double, lit: String = IronOldBuildingsInk.light,
                         shade: String = IronOldBuildingsInk.plasterShade) {
        let base = 1.8, capital = 3.2
        let b1 = foot - P(0, base), c0 = foot - P(0, height - capital), c1 = foot - P(0, height - 1.3)
        let top = foot - P(0, height)
        // The shaft.
        colour([b1 + P(-r, 0), b1 + P(r, 0), c0 + P(r * 0.9, 0), c0 + P(-r * 0.9, 0)], .colour(lit))
        colour([b1 + P(r * 0.3, 0), b1 + P(r, 0), c0 + P(r * 0.9, 0), c0 + P(r * 0.28, 0)], .colour(shade))
        line([b1 + P(-r, 0), c0 + P(-r * 0.9, 0)], width: 0.8)
        line([b1 + P(r, 0), c0 + P(r * 0.9, 0)], width: 0.8)
        var flutes = PathData()
        for f in [-0.45, 0.05, 0.6] { flutes.move(b1 + P(r * f, -0.6)); flutes.line(c0 + P(r * f * 0.9, 0.6)) }
        svg.path(flutes, stroke: .colour(IronOldBuildingsInk.line), width: 0.35, opacity: 0.5)
        // The base and the capital.
        shape([foot + P(-r * 1.4, 0), foot + P(r * 1.4, 0), b1 + P(r * 1.15, 0), b1 + P(-r * 1.15, 0)], .colour(lit), width: 0.7)
        shape([c0 + P(-r * 0.9, 0), c0 + P(r * 0.9, 0), c1 + P(r * 1.4, 0), c1 + P(-r * 1.4, 0)], .colour(lit), width: 0.7)
        shape([c1 + P(-r * 1.55, 0), c1 + P(r * 1.55, 0), top + P(r * 1.55, 0), top + P(-r * 1.55, 0)], .colour(shade), width: 0.7)
    }

    /// A window barred with iron on a wall drawn with `wall`: its foot at
    /// (`u`, `v`), `w` wide and `h` tall, in a frame of stone on a sill.
    mutating func grille(_ u: Double, _ v: Double, w: Double, h: Double) {
        typealias I = IronOldBuildingsInk
        shape(panel(u - 0.9, v - 0.2, u + w + 0.9, v + h + 1), .colour(I.light), width: 0.6)
        shape(panel(u, v, u + w, v + h), .colour(I.dark), width: 0.7)
        var bars = PathData()
        for i in 1..<max(2, Int(w / 1.9)) {
            let x = u + w * Double(i) / Double(max(2, Int(w / 1.9)))
            bars.move(uv(x, v + 0.2)); bars.line(uv(x, v + h - 0.2))
        }
        bars.move(uv(u + 0.2, v + h * 0.55)); bars.line(uv(u + w - 0.2, v + h * 0.55))
        svg.path(bars, stroke: .colour(I.ironLight), width: 0.6)
        shape(panel(u - 1.4, v - 1.1, u + w + 1.4, v), .colour(I.stoneTop), width: 0.6)
    }

    /// A window with its shutters of painted wood folded open, on a wall drawn
    /// with `wall`: its foot at (`u`, `v`), `w` wide and `h` tall.
    mutating func shuttered(_ u: Double, _ v: Double, w: Double, h: Double) {
        typealias I = IronOldBuildingsInk
        shape(panel(u, v, u + w, v + h), .colour(I.dark), width: 0.7)
        let s = w * 0.48
        for (a, b) in [(u - s, u), (u + w, u + w + s)] {
            shape(panel(a, v, b, v + h), .colour(I.sea), width: 0.6)
            line([uv(a + 0.5, v + h * 0.5), uv(b - 0.5, v + h * 0.5)], width: 0.4, opacity: 0.8)
        }
        shape(panel(u - s - 0.4, v - 1, u + w + s + 0.4, v), .colour(I.stoneTop), width: 0.55)
    }

    /// A door of planks under an arch of voussoirs, on a wall drawn with `wall`:
    /// centred on `u`, standing on `v`, `w` wide and `h` tall to the crown,
    /// its leaves painted `paint` and studded with iron.
    mutating func archedDoor(_ u: Double, _ v: Double, w: Double, h: Double, paint: String = IronOldBuildingsInk.sea) {
        typealias I = IronOldBuildingsInk
        let r = w / 2
        // The ring of voussoirs, a little wider than the opening.
        arch(u, v, width: w + 3.2, height: h + 1.6, .colour(I.stoneTop), line: 0.8)
        arch(u, v, width: w, height: h, .colour(paint), line: 0.9)
        var joints = PathData()
        for k in 1..<6 {
            let a = Double.pi * Double(k) / 6
            let c = uv(u, v + h - r)
            joints.move(c + P(-cos(a) * r, -sin(a) * r)); joints.line(c + P(-cos(a) * (r + 1.6), -sin(a) * (r + 1.6)))
        }
        svg.path(joints, stroke: .colour(I.line), width: 0.45)
        line([uv(u, v + 0.3), uv(u, v + h - 0.4)], width: 0.55)
        for vv in stride(from: v + 2.2, to: v + h - r, by: 3.2) {
            for uu in [u - r * 0.55, u + r * 0.55] { svg.circle(uv(uu, vv), 0.42, fill: .colour(I.ironDark)) }
        }
        for vv in [v + 2.4, v + h - r - 0.6] {
            line([uv(u - r + 0.4, vv), uv(u + r - 0.4, vv)], width: 0.6, opacity: 0.7)
        }
    }

    // MARK: Team colour

    /// A wreath of laurel in the light colour at `p`, open at its top: a ring
    /// of leaves along a thin stem.
    mutating func wreath(at p: P, radius r: Double) {
        typealias I = IronOldBuildingsInk
        let gap = 0.5
        let s = sin(gap), c = cos(gap)
        let d = "M\(num(p.x + r * s)),\(num(p.y - r * c)) A\(num(r)),\(num(r)) 0 1 1 \(num(p.x - r * s)),\(num(p.y - r * c))"
        svg.path(d, stroke: .colour(I.light), width: max(0.4, r * 0.16))
        // The leaves, in pairs either side of the stem.
        for i in 0..<9 {
            let a = gap + (2 * Double.pi - 2 * gap) * (Double(i) + 0.5) / 9
            let centre = p + P(sin(a), -cos(a)) * r
            for side in [-1.0, 1.0] {
                let leaf = centre + P(sin(a), -cos(a)) * (side * r * 0.22)
                svg.ellipse(leaf, r * 0.2, r * 0.12, fill: .colour(I.light))
            }
        }
    }

    /// The legion's oblong shield hung on a wall drawn with `wall`, centred on
    /// (`u`, `v`): `w` wide and `h` tall, curved, its face in the owner's colour
    /// with a light spine, an iron rim and a gilt boss.
    mutating func scutum(_ u: Double, _ v: Double, w: Double, h: Double) {
        typealias I = IronOldBuildingsInk
        let c = uv(u, v), rx = w / 2, ry = h / 2
        func trace(_ o: P) -> PathData {
            var d = PathData()
            d.move(c + P(-rx, -ry + 1.2) + o)
            d.quad(c + P(0, -ry - 0.8) + o, c + P(rx, -ry + 1.2) + o)
            d.line(c + P(rx, ry - 1.2) + o)
            d.quad(c + P(0, ry + 0.8) + o, c + P(-rx, ry - 1.2) + o)
            d.close()
            return d
        }
        colour(.colour(I.iron)) { d, o in d = trace(o) }
        svg.ellipse(c + shift * 0.5, rx - 0.7, ry - 0.7, fill: .team)
        svg.polygon([c + P(-rx + 0.7, -ry + 1.4), c + P(rx - 0.7, -ry + 1.4), c + P(rx - 0.7, ry - 1.4), c + P(-rx + 0.7, ry - 1.4)],
                    fill: .team)
        svg.line([c + P(0, -ry + 1.2), c + P(0, ry - 1.2)], stroke: .colour(I.light), width: 0.7)
        // The curve of the shield: its right side in shade.
        svg.polygon([c + P(rx * 0.55, -ry + 0.9), c + P(rx - 0.7, -ry + 1.4), c + P(rx - 0.7, ry - 1.4), c + P(rx * 0.55, ry - 0.9)],
                    fill: .colour("#000000"), opacity: 0.16)
        line(width: 0.8) { d in d = trace(P(0, 0)) }
        svg.ellipse(c, rx * 0.36, rx * 0.36, fill: .colour(I.gilt), stroke: .colour(I.line), width: 0.5)
    }

    /// The legion's standard standing at `p` on the screen: a pole under an iron
    /// spearhead, a crossbar, and from it a square banner in the owner's colour
    /// with a wreath and a fringe of gilt.
    mutating func vexillum(at p: P, height: Double, width w: Double = 13, length l: Double = 15) {
        typealias I = IronOldBuildingsInk
        let top = p - P(0, height)
        svg.ellipse(p + P(0, 0.4), 4, 1.4, fill: .colour("#000000"), opacity: 0.14)
        svg.line([p, top], stroke: .colour(I.line), width: 2.7)
        svg.line([p, top], stroke: .colour(I.timberDark), width: 1.6)
        let bar = top + P(0, 6)
        let cloth = [bar + P(-w / 2, 0), bar + P(w / 2, 0), bar + P(w / 2, l), bar + P(-w / 2, l)]
        shape(cloth, .team, width: 1)
        wreath(at: bar + P(0, l * 0.46), radius: w * 0.22)
        var fringe = PathData()
        for i in 0...Int(w / 1.3) {
            let x = -w / 2 + Double(i) * w / Double(Int(w / 1.3))
            fringe.move(bar + P(x, l)); fringe.line(bar + P(x, l + 2.2))
        }
        svg.path(fringe, stroke: .colour(I.gilt), width: 0.8)
        pole(bar + P(-w / 2 - 1.6, 0), bar + P(w / 2 + 1.6, 0), width: 1.2, colour: I.timberDark)
        for s in [-1.0, 1.0] { svg.circle(bar + P(s * (w / 2 + 1.6), 0), 0.9, fill: .colour(I.gilt), stroke: .colour(I.line), width: 0.4) }
        // The spearhead, and a gilt boss under it.
        shape([top + P(-1.5, 0.4), top + P(0, -5), top + P(1.5, 0.4)], .colour(I.ironLight), width: 0.7)
        svg.circle(top + P(0, 1.2), 1.4, fill: .colour(I.gilt), stroke: .colour(I.line), width: 0.5)
    }
}
