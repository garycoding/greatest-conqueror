// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age alchemist's workshop: the Alchemy age's workshop grown
// into a chemical works. A building of red brick, two storeys on a plinth of
// stone, under a roof of slate with a gable of brick and a round window; a
// broad laboratory window on its front shows retorts, an alembic and flasks
// of coloured liquor, and its door stands open on the glow of the furnace
// within. Beside it a tall square chimney of brick, tapering, banded in iron
// and capped in stone, carries the furnaces' smoke high over the town. An
// iron vat with a band of the owner's colour stands in the yard with kegs of
// powder stacked beside it; a banner of the owner's colour hangs from the
// upper storey and a pennant flies from the gable. Its footprint is three
// tiles square: x and y run from -1.5 to 1.5.

extension IndustrialOldBuildingsLatePainter {
    mutating func workshop(complete: Bool) {
        typealias I = IndustrialOldBuildingsLateInk
        block(-1.5, -1.5, 1.5, 1.5, 0, Workshop.ground, top: .colour(I.earth), left: .colour(I.earthShade),
              right: .colour(I.earthShade), width: 1)
        cobbles()
        if complete { workshopComplete() } else { workshopRising() }
    }

    /// The workshop's measures: on the map in tiles, heights in points.
    private enum Workshop {
        static let ground = 1.5
        static let house = (x0: -1.25, y0: -1.2, x1: 0.5, y1: 0.2)
        static let storey = 26.0, eave = 46.0, ridge = 70.0
        /// The chimney rises from the furnace through the ridge, near the gable.
        /// The chimney stands free in the yard, beside the gable.
        static let stack = (x: 0.98, y: -1.0, foot: 0.2, head: 0.13)
        static let chimneyTop = 118.0
        static let over = 0.1
    }

    /// Cobbles before the door and along the house's front, at fixed places.
    private mutating func cobbles() {
        typealias I = IndustrialOldBuildingsLateInk
        let g = Workshop.ground
        let apron = level(-1.3, 0.2, 0.6, 0.62, g)
        colour(apron, .colour(I.paving))
        var joints = PathData()
        for y in stride(from: 0.3, to: 0.62, by: 0.1) { joints.move(iso(-1.3, y, g)); joints.line(iso(0.6, y, g)) }
        var x = -1.22
        while x < 0.6 { joints.move(iso(x, 0.2, g)); joints.line(iso(x, 0.62, g)); x += 0.14 }
        svg.path(joints, stroke: .colour(I.pavingShade), width: 0.6)
        line([apron[3], apron[2]], width: 0.6, opacity: 0.6)
        // Scattered grit and coal over the yard.
        let places: [(Double, Double)] = [(-1.2, 1.1), (-0.5, 1.3), (0.2, 1.0), (1.2, -1.1), (1.25, -0.2), (-1.3, -1.35), (0.9, 1.35),
                                          (-0.9, 0.85)]
        for (k, (px, py)) in places.enumerated() {
            svg.ellipse(iso(px, py, g), 1.5, 0.75, fill: .colour(k % 2 == 0 ? I.earthShade : I.dark), opacity: k % 2 == 0 ? 1 : 0.6)
        }
    }

    // MARK: The workshop complete

    private mutating func workshopComplete() {
        typealias I = IndustrialOldBuildingsLateInk
        let (x0, y0, x1, y1) = Workshop.house
        let g = Workshop.ground, storey = Workshop.storey, eave = Workshop.eave
        let front = (x1 - x0) * 32, end = (y1 - y0) * 32
        shadow([iso(x1, y0, g), iso(x1 + 0.45, y0 + 0.15, g), iso(x1 + 0.45, y1 + 0.15, g), iso(x1, y1, g)], opacity: 0.12)
        stack(top: Workshop.chimneyTop, smoking: true)
        // Two storeys of brick on a plinth of stone, a string course between them.
        block(x0, y0, x1, y1, g, eave, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: g) { p in
            p.shape(p.panel(0, 0, front, 3), .colour(I.stone), width: 0.6)
            p.courses(0, front, 3, eave - g, course: 2.5, brick: 6, opacity: 0.3)
            p.brickQuoins(0, front, eave - g)
            p.frontWindow(6, 7, width: 24, height: 13)
            p.furnaceDoor(front - 13, width: 11, height: 18)
            p.shape(p.panel(0, storey - g, front, storey - g + 1.6), .colour(I.stoneTop), width: 0.5)
            p.casement(front * 0.5 - 4, storey - g + 3.2, width: 8, height: 8.6)
            p.casement(front * 0.82 - 4, storey - g + 3.2, width: 8, height: 8.6)
            p.hanging(front * 0.17, top: eave - g - 6.5, width: 9, length: 13.5)
        }
        wall(.right, from: x1, y1, at: g) { p in
            p.shape(p.panel(0, 0, end, 3), .colour(I.stoneShade), width: 0.6)
            p.courses(0, end, 3, eave - g, course: 2.5, brick: 6, opacity: 0.3)
            p.brickQuoins(0, end, eave - g)
            p.casement(end * 0.3 - 3.5, 8, width: 7, height: 10)
            p.casement(end * 0.7 - 3.5, 8, width: 7, height: 10)
            p.shape(p.panel(0, storey - g, end, storey - g + 1.6), .colour(I.stone), width: 0.5)
            p.casement(end * 0.3 - 3.5, storey - g + 6.5, width: 7, height: 10)
            p.casement(end * 0.7 - 3.5, storey - g + 6.5, width: 7, height: 10)
        }
        slateRoof(x0, y0, x1, y1, eave: eave, ridge: Workshop.ridge, over: Workshop.over)
        vat(0.95, -0.28)
        kegs()
        bench(-1.15, 0.95)
    }

    /// A broad window on a wall drawn with `wall`, its foot at (`u`, `v`):
    /// a frame of stone round a dark room, and on the sill the chemist's
    /// glass: an alembic on its stand, a retort, and flasks of coloured liquor.
    mutating func frontWindow(_ u: Double, _ v: Double, width w: Double, height h: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        shape(panel(u - 1.6, v - 0.4, u + w + 1.6, v + h + 1.8), .colour(I.stoneTop), width: 0.7)
        shape(panel(u, v, u + w, v + h), .colour(I.greenDark), width: 0.8)
        // A glimmer of the furnace's light on the room's far wall.
        colour(panel(u + w * 0.62, v + 0.6, u + w - 0.6, v + h - 0.6), .colour(I.fire), opacity: 0.35)
        // A shelf across the back, with jars on it.
        line([uv(u + 0.4, v + h * 0.62), uv(u + w - 0.4, v + h * 0.62)], width: 0.7)
        for (k, ju) in [3.0, 6.0, 15.5].enumerated() {
            shape(panel(u + ju, v + h * 0.62, u + ju + 2, v + h * 0.62 + 2.6), .colour(k == 1 ? I.brassShade : I.stone), width: 0.4)
        }
        // The alembic: a round flask over a small flame, its still-head, and the beak running down to a receiver.
        let a = uv(u + 5, v + 0.6)
        line([a + P(-2.4, 0), a + P(-2.4, -2.6)], width: 0.7)
        line([a + P(2.4, 0), a + P(2.4, -2.6)], width: 0.7)
        shape([a + P(-1, -0.4), a + P(0, -2.2), a + P(1, -0.4)], .colour(I.fireCore), width: 0.4)
        svg.circle(a + P(0, -5) + P(-0.5, 0.4), 2.8, fill: .colour(I.glass))
        svg.circle(a + P(0, -4.6) + P(-0.5, 0.4), 2.2, fill: .colour(I.smoke))
        svg.circle(a + P(0, -5), 2.8, fill: .none, stroke: .colour(I.line), width: 0.6)
        shape([a + P(-1, -7.4), a + P(1, -7.4), a + P(1.6, -9.6), a + P(-1.6, -9.6)], .colour(I.glass), width: 0.55)
        line([a + P(1.4, -9), a + P(7, -5.6)], width: 1.4)
        svg.line([a + P(1.4, -9), a + P(7, -5.6)], stroke: .colour(I.glass), width: 0.6)
        svg.circle(a + P(7.6, -2) + P(-0.4, 0.3), 1.9, fill: .colour(I.brickTop))
        svg.circle(a + P(7.6, -2), 1.9, fill: .none, stroke: .colour(I.line), width: 0.55)
        line([a + P(7.6, -3.9), a + P(7.6, -5)], width: 0.8)
        // The retort: a bulb with a long neck bent down to the right.
        let b = uv(u + 15, v + 0.6)
        svg.ellipse(b + P(0, -3) + P(-0.5, 0.4), 3, 2.7, fill: .colour(I.glass))
        svg.ellipse(b + P(0, -2.4) + P(-0.5, 0.4), 2.4, 1.8, fill: .colour(I.brassLight))
        svg.ellipse(b + P(0, -3), 3, 2.7, fill: .none, stroke: .colour(I.line), width: 0.6)
        var neck = PathData()
        neck.move(b + P(1.6, -5.2)); neck.quad(b + P(4, -8.6), b + P(7.4, -3.2))
        svg.path(neck, stroke: .colour(I.line), width: 1.6)
        svg.path(neck, stroke: .colour(I.glass), width: 0.7)
        // Flasks: a tall one of blue liquor, and a squat one of red.
        let f = uv(u + w - 2.6, v + 0.6)
        shape([f + P(-1.6, 0), f + P(1.6, 0), f + P(0.6, -3.6), f + P(0.6, -7), f + P(-0.6, -7), f + P(-0.6, -3.6)], .colour(I.glass),
              width: 0.55)
        colour([f + P(-1.4, -0.2), f + P(1.4, -0.2), f + P(0.8, -2.6), f + P(-0.8, -2.6)], .colour(I.greenLight))
        // The sill.
        shape(panel(u - 2.2, v - 1.4, u + w + 2.2, v), .colour(I.stoneTop), width: 0.6)
        // Mullion and transom of the window.
        line([uv(u + w / 2, v + h * 0.65), uv(u + w / 2, v + h)], width: 0.9)
    }

    /// The open door of the furnace room on a wall drawn with `wall`, centred
    /// on `u`: an arch of voussoirs over the dark within, where the furnace's
    /// mouth glows, its door of bottle-green planks folded back against the wall.
    mutating func furnaceDoor(_ u: Double, width w: Double, height h: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        // The door leaf, folded back against the wall at the left.
        shape(panel(u - w / 2 - w * 0.7, 0, u - w / 2, h - w / 2), .colour(I.green), width: 0.8)
        for k in 1...2 {
            let x = u - w / 2 - w * 0.7 * Double(k) / 3
            line([uv(x, 0.4), uv(x, h - w / 2 - 0.4)], width: 0.4, opacity: 0.7)
        }
        for v in [2.4, h - w / 2 - 2.4] { line([uv(u - w / 2 - w * 0.7, v), uv(u - w / 2, v)], width: 0.8, opacity: 0.9) }
        voussoirs(u, 0, width: w, height: h, depth: 2, count: 7)
        arch(u, 0, width: w, height: h, .colour(I.dark), line: 1)
        // The furnace within: its glow filling the back of the room, its mouth burning white-hot.
        arch(u, 0, width: w - 2.4, height: h - 3, .colour(I.fire), line: 0.01)
        arch(u + 0.6, 0, width: w - 5.2, height: h - 6.4, .colour(I.fireCore), line: 0.01)
        shape(panel(u - w / 2 + 1.6, 0, u + w / 2 - 1.6, 4.6), .colour(I.stoneDark), width: 0.6)
        arch(u, 0.8, width: 4.6, height: 3.4, .colour(I.fireCore), line: 0.6)
        // A step.
        shape(panel(u - w / 2 - 1.4, -1.2, u + w / 2 + 1.4, 0.2), .colour(I.stoneTop), width: 0.6)
    }

    /// Quoins of stone up both ends of a wall drawn with `wall`, from `u0`
    /// to `u1`, above the plinth to `height`.
    mutating func brickQuoins(_ u0: Double, _ u1: Double, _ height: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        var v = 3.0, k = 0
        while v < height - 0.5 {
            let top = min(v + 3.4, height), reach = k % 2 == 0 ? 4.2 : 2.6
            shape(panel(u0, v, u0 + reach, top), .colour(I.stoneTop), width: 0.45)
            shape(panel(u1 - reach, v, u1, top), .colour(I.stoneTop), width: 0.45)
            v = top
            k += 1
        }
    }

    /// A sash window on a wall drawn with `wall`, its foot at (`u`, `v`):
    /// dark glass in frames of the light colour, two over two, under a
    /// segmental arch of brick and over a sill of stone.
    mutating func casement(_ u: Double, _ v: Double, width w: Double, height h: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        shape(panel(u - 0.5, v, u + w + 0.5, v + h), .colour(I.light), width: 0.6)
        colour(panel(u + 0.4, v + 0.5, u + w - 0.4, v + h - 0.5), .colour(I.greenDark))
        colour([uv(u + 0.4, v + h * 0.55), uv(u + w * 0.5, v + h - 0.5), uv(u + 0.4, v + h - 0.5)], .colour(I.greenLight), opacity: 0.6)
        var bars = PathData()
        bars.move(uv(u + w / 2, v + 0.5)); bars.line(uv(u + w / 2, v + h - 0.5))
        bars.move(uv(u, v + h / 2)); bars.line(uv(u + w, v + h / 2))
        svg.path(bars, stroke: .colour(I.light), width: 0.6)
        let (a0, a1, a2) = (uv(u - 1, v + h), uv(u + w / 2, v + h + 2.8), uv(u + w + 1, v + h))
        line(width: 2.4) { d in d.move(a0); d.quad(a1, a2) }
        svg.path({ var d = PathData(); d.move(a0); d.quad(a1, a2); return d }(), stroke: .colour(I.brickShade), width: 1.2)
        shape(panel(u - 1.2, v - 1.2, u + w + 1.2, v), .colour(I.stoneTop), width: 0.5)
    }

    /// A gabled roof of slate over a box from (x0, y0) to (x1, y1), its eaves
    /// at `eave` and its ridge running along x at `ridge`, overhanging by
    /// `over` tiles, its gable end (facing +x) of brick with a round window.
    private mutating func slateRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double,
                                    over: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        let ym = (y0 + y1) / 2
        let (a0, a1, b0, b1) = (x0 - over, x1 + over, y0 - over, y1 + over)
        let drop = (ridge - eave) * over / (ym - y0)
        colour([iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a0, b0, eave - drop)], .colour(I.slateShade))
        // The gable's end wall, of brick, with a round window.
        let triangle = [iso(x1, y1, eave), iso(x1, y0, eave), iso(x1, ym, ridge)]
        colour(triangle, .colour(I.brickShade))
        wall(.right, from: x1, y1, at: eave) { p in
            let w = (y1 - y0) * 32, rise = ridge - eave
            var d = PathData()
            var v = 2.5
            while v < rise - 1.5 {
                let half = w / 2 * (1 - v / rise) - 0.5
                d.move(p.uv(w / 2 - half, v)); d.line(p.uv(w / 2 + half, v))
                v += 2.5
            }
            p.svg.path(d, stroke: .colour(I.line), width: 0.35, opacity: 0.3)
            p.svg.circle(p.uv(w / 2, rise * 0.4), 3.6, fill: .colour(I.stoneTop), stroke: .colour(I.line), width: 0.6)
            p.svg.circle(p.uv(w / 2, rise * 0.4), 2.4, fill: .colour(I.greenDark), stroke: .colour(I.line), width: 0.45)
            p.svg.line([p.uv(w / 2 - 2.4, rise * 0.4), p.uv(w / 2 + 2.4, rise * 0.4)], stroke: .colour(I.light), width: 0.45)
            p.svg.line([p.uv(w / 2, rise * 0.4 - 2.4), p.uv(w / 2, rise * 0.4 + 2.4)], stroke: .colour(I.light), width: 0.45)
        }
        line(triangle, closed: true, width: 0.9)
        // The roof's thickness along the gable, then the front slope.
        let edge = P(0, 2.2)
        colour([iso(a1, b1, eave - drop), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a1, b0, eave - drop) + edge,
                iso(a1, ym, ridge) + edge, iso(a1, b1, eave - drop) + edge], .colour(I.slateDark))
        let front = [iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b1, eave - drop), iso(a0, b1, eave - drop)]
        colour([front[3], front[2], front[2] + edge, front[3] + edge], .colour(I.slateDark))
        colour(front, .colour(I.slate))
        // The slates: courses across the slope, and their joints staggered.
        var courses = PathData(), joints = PathData()
        let rows = 7
        for k in 1..<rows {
            let t = Double(k) / Double(rows)
            let y = b1 + (ym - b1) * t, h = (eave - drop) + (ridge - eave + drop) * t
            courses.move(iso(a0, y, h)); courses.line(iso(a1, y, h))
        }
        for k in 0..<rows {
            let t0 = Double(k) / Double(rows), t1 = Double(k + 1) / Double(rows)
            var x = a0 + (k % 2 == 0 ? 0.09 : 0.18)
            while x < a1 - 0.05 {
                let ya = b1 + (ym - b1) * t0, ha = (eave - drop) + (ridge - eave + drop) * t0
                let yb = b1 + (ym - b1) * t1, hb = (eave - drop) + (ridge - eave + drop) * t1
                joints.move(iso(x, ya, ha) + P(0, -0.5)); joints.line(iso(x, yb, hb) + P(0, 0.5))
                x += 0.18
            }
        }
        svg.path(courses, stroke: .colour(I.slateDark), width: 0.8)
        svg.path(joints, stroke: .colour(I.slateDark), width: 0.45, opacity: 0.8)
        // A lit band along the lower edge of each course.
        var lit = PathData()
        for k in 1..<rows {
            let t = Double(k) / Double(rows) - 0.02
            let y = b1 + (ym - b1) * t, h = (eave - drop) + (ridge - eave + drop) * t
            lit.move(iso(a0 + 0.02, y, h)); lit.line(iso(a1 - 0.02, y, h))
        }
        svg.path(lit, stroke: .colour(I.slateLight), width: 0.5, opacity: 0.8)
        line(front, closed: true, width: 1.1)
        line([front[3], front[3] + edge, front[2] + edge, front[2]], width: 0.9)
        line([iso(a1, ym, ridge), iso(a1, ym, ridge) + edge, iso(a1, b0, eave - drop) + edge, iso(a1, b0, eave - drop)], width: 0.9)
        line([front[2] + edge, iso(a1, ym, ridge) + edge], width: 0.9)
        // The ridge's capping, and the pennant on the gable's peak.
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.line), width: 3.2)
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.slateLight), width: 1.6)
        finial(at: iso(a0, ym, ridge), size: 0.8)
        pennant(at: iso(a1, ym, ridge), height: 17, length: 16)
    }

    /// The chimney standing free in the yard: a square stack of brick on a
    /// plinth of stone, tapering as it rises to `top`, banded in iron, under
    /// a corbelled cap of stone; giving off smoke when `smoking`.
    private mutating func stack(top: Double, smoking: Bool) {
        typealias I = IndustrialOldBuildingsLateInk
        let (cx, cy, foot, head) = (Workshop.stack.x, Workshop.stack.y, Workshop.stack.foot, Workshop.stack.head)
        let g = Workshop.ground, plinth = g + 7
        func r(_ h: Double) -> Double { foot + (head - foot) * (h - plinth) / (Workshop.chimneyTop - plinth) }
        shadow([iso(cx + foot, cy - foot, g), iso(cx + foot + 0.5, cy - foot + 0.1, g), iso(cx + foot + 0.5, cy + foot + 0.1, g),
                iso(cx + foot, cy + foot, g)], opacity: 0.14)
        let s0 = foot + 0.05
        block(cx - s0, cy - s0, cx + s0, cy + s0, g, plinth, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade))
        let rt = r(top)
        let left = [iso(cx - foot, cy + foot, plinth), iso(cx + foot, cy + foot, plinth), iso(cx + rt, cy + rt, top), iso(cx - rt, cy + rt, top)]
        let right = [iso(cx + foot, cy + foot, plinth), iso(cx + foot, cy - foot, plinth), iso(cx + rt, cy - rt, top), iso(cx + rt, cy + rt, top)]
        colour(left, .colour(smoking ? I.brick : I.rawBrick))
        colour(right, .colour(smoking ? I.brickShade : I.rawBrickShade))
        // Its courses, a burnt brick picked out here and there.
        var d = PathData()
        var h = plinth + 2.5, k = 0
        while h < top - 1 {
            let q = r(h)
            d.move(iso(cx - q, cy + q, h)); d.line(iso(cx + q, cy + q, h)); d.line(iso(cx + q, cy - q, h))
            if k % 3 == 1 {
                let u = Double((k * 7) % 5) / 5 * 1.6 * q - 0.8 * q
                let a = iso(cx + u, cy + q, h), b = iso(cx + u + 0.12, cy + q, h)
                colour([a, b, b - P(0, 2.5), a - P(0, 2.5)], .colour(I.brickDark), opacity: 0.35)
            }
            h += 2.5
            k += 1
        }
        svg.path(d, stroke: .colour(I.line), width: 0.35, opacity: 0.3)
        line(left, closed: true, width: 1.1)
        line(right, closed: true, width: 1.1)
        guard smoking else { return }
        // Bands of iron up the stack.
        for hb in stride(from: plinth + 18, to: top - 8, by: 20) {
            let q = r(hb) + 0.01
            let band = [iso(cx - q, cy + q, hb), iso(cx + q, cy + q, hb), iso(cx + q, cy - q, hb), iso(cx + q, cy - q, hb + 1.6),
                        iso(cx + q, cy + q, hb + 1.6), iso(cx - q, cy + q, hb + 1.6)]
            shape(band, .colour(I.iron), width: 0.5)
        }
        // The corbelled cap of stone, and the flue's sooted mouth.
        let c = rt + 0.03, c2 = rt + 0.06
        block(cx - c, cy - c, cx + c, cy + c, top, top + 2, top: nil, left: .colour(I.stoneTop), right: .colour(I.stone), width: 0.9)
        block(cx - c2, cy - c2, cx + c2, cy + c2, top + 2, top + 4.4, top: .colour(I.stoneTop), left: .colour(I.stoneTop),
              right: .colour(I.stone), width: 0.9)
        shape(level(cx - rt + 0.02, cy - rt + 0.02, cx + rt - 0.02, cy + rt - 0.02, top + 4.4), .colour(I.sootDark), width: 0.6)
        let mouth = iso(cx, cy, top + 4.4)
        puff(at: mouth + P(1.4, -5), radius: 4, colour: I.smokeDark)
        puff(at: mouth + P(7, -13), radius: 5, colour: I.smoke)
        puff(at: mouth + P(15, -20), radius: 5.2, colour: I.smokeLight)
        puff(at: mouth + P(24, -25), radius: 3.6, colour: I.smoke)
    }

    /// An iron vat standing in the yard at (x, y): a riveted drum on a plinth
    /// of brick, a band of the owner's colour round it edged in the light
    /// colour, a rim and a pipe running from it toward the works.
    private mutating func vat(_ x: Double, _ y: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        let g = Workshop.ground, r = 0.22, h0 = g + 3, h1 = g + 22
        shadow(arc(x + 0.12, y - 0.04, r, from: -60, to: 60, at: g) + [round(x, y, r, 60, g)], opacity: 0.12)
        cylinder(x, y, r + 0.03, g, h0, lit: I.brickTop, mid: I.brick, shade: I.brickShade, course: nil, width: 0.9)
        cylinder(x, y, r, h0, h1, lit: I.ironLight, mid: I.iron, shade: I.ironDark, top: .colour(I.iron), course: nil, width: 1)
        // The owner's band, between two rims of the light colour.
        let (b0, b1) = (h0 + 9, h0 + 13.4)
        colour(arc(x, y, r, from: -45, to: 135, at: b0 - 1) + arc(x, y, r, from: 135, to: -45, at: b1 + 1), .colour(I.light))
        colour(arc(x, y, r, from: -45, to: 135, at: b0) + arc(x, y, r, from: 135, to: -45, at: b1), .team)
        line(arc(x, y, r, from: -45, to: 135, at: b0), width: 0.45)
        line(arc(x, y, r, from: -45, to: 135, at: b1), width: 0.45)
        mark(at: round(x, y, r, 45, (b0 + b1) / 2), radius: 1.1)
        // Rivets in rows, and the rim.
        for hv in [h0 + 2.5, h0 + 17] {
            for a in stride(from: -35.0, to: 130, by: 18) {
                svg.circle(round(x, y, r, a, hv), 0.35, fill: .colour(I.ironDark))
            }
        }
        line(arc(x, y, r - 0.04, from: 0, to: 360, at: h1, steps: 36), closed: true, width: 0.6)
        // The pipe from its top toward the works' gable.
        let pa = round(x, y, r * 0.5, 160, h1), pb = iso(0.5, y, h1 + 2)
        svg.line([pa, pa - P(0, 3), pb], stroke: .colour(I.line), width: 2.4)
        svg.line([pa, pa - P(0, 3), pb], stroke: .colour(I.ironLight), width: 1)
    }

    /// A puff of smoke at `p`: a cluster of round billows of one colour under one outline.
    private mutating func puff(at p: P, radius r: Double, colour: String) {
        let billows: [(P, Double)] = [(P(-r * 0.7, r * 0.15), r * 0.72), (P(0, -r * 0.35), r), (P(r * 0.8, r * 0.1), r * 0.78),
                                      (P(r * 0.1, r * 0.45), r * 0.7)]
        for (o, s) in billows { svg.circle(p + o, s, fill: .colour(IndustrialOldBuildingsLateInk.line)) }
        for (o, s) in billows { svg.circle(p + o + shift * 0.4, s - 0.9, fill: .colour(colour)) }
        // A curl of shade under the billows.
        line(width: 0.5, opacity: 0.5) { d in
            d.move(p + P(-r * 0.6, r * 0.3)); d.quad(p + P(0, r * 0.8), p + P(r * 0.7, r * 0.35))
        }
    }

    /// Kegs of powder stacked in the yard, each stencilled with a cross: a
    /// row of three standing, two on them, one at the top, and two beside.
    private mutating func kegs() {
        let g = Workshop.ground, x = 1.1, rise = 9.4
        let layers: [[Double]] = [[0.34, 0.6, 0.86], [0.47, 0.73], [0.6]]
        for (level, row) in layers.enumerated() {
            for y in row { keg(at: iso(x, y, g + Double(level) * rise), marked: true) }
        }
        keg(at: iso(0.86, 1.12, g), size: 0.95, marked: true)
        keg(at: iso(1.2, 1.18, g), size: 1, marked: true)
    }

    /// A bench in the yard at (x, y) with a mortar and pestle and a crucible on it.
    private mutating func bench(_ x: Double, _ y: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        let g = Workshop.ground, top = g + 8
        for (dx, dy) in [(0.0, -0.1), (0.45, -0.1), (0.0, 0.04), (0.45, 0.04)] {
            pole(iso(x + dx + 0.04, y + dy, g), iso(x + dx + 0.04, y + dy, top), width: 1.1, colour: I.timberDark)
        }
        block(x, y - 0.14, x + 0.52, y + 0.06, top, top + 1.8, top: .colour(I.timberLight), left: .colour(I.timber),
              right: .colour(I.timberDark), width: 0.8)
        // The mortar of stone, and its pestle.
        let m = iso(x + 0.14, y - 0.04, top + 1.8)
        shape([m + P(-2.6, 0), m + P(2.6, 0), m + P(3, -3), m + P(-3, -3)], .colour(I.stone), width: 0.6)
        svg.ellipse(m + P(0, -3), 3, 0.9, fill: .colour(I.stoneDark), stroke: .colour(I.line), width: 0.5)
        pole(m + P(0.6, -3), m + P(3.6, -7.4), width: 0.9, colour: I.timberLight)
        // A crucible of clay, glowing.
        let c = iso(x + 0.38, y - 0.04, top + 1.8)
        shape([c + P(-2, 0), c + P(2, 0), c + P(2.6, -3.4), c + P(-2.6, -3.4)], .colour(I.earthShade), width: 0.6)
        svg.ellipse(c + P(0, -3.4), 2.6, 0.8, fill: .colour(I.fireCore), stroke: .colour(I.line), width: 0.5)
    }

    // MARK: The workshop being built

    /// The works being built: the brick of the ground storey raised part of
    /// its height on its plinth, its door's opening left, the chimney's
    /// stack half raised inside scaffolding, scaffolding along the front
    /// flying the owner's pennant, and bricks, timber and mortar to hand.
    private mutating func workshopRising() {
        typealias I = IndustrialOldBuildingsLateInk
        let (x0, y0, x1, y1) = Workshop.house
        let g = Workshop.ground
        // The chimney's stack, half raised inside its scaffold.
        let (cx, cy) = (Workshop.stack.x, Workshop.stack.y)
        scaffold([(cx - 0.32, cy - 0.32), (cx + 0.32, cy - 0.32)], from: g, height: 62, levels: [20, 40, 58])
        stack(top: 54, smoking: false)
        scaffold([(cx - 0.32, cy + 0.32), (cx + 0.32, cy + 0.32), (cx + 0.32, cy - 0.32)], from: g, height: 62,
                 levels: [20, 40, 58], boards: 40, inward: (0, -0.12))
        pennant(at: iso(cx + 0.32, cy + 0.32, g + 62), height: 12, length: 14)
        // The walls at the back, raised higher; the front lower, with the door's opening.
        for (a0, b0, a1, b1, h) in [(x0, y0, x1, y0 + 0.12, 24.0), (x0, y0 + 0.12, x0 + 0.12, y1, 20.0), (x1 - 0.12, y0 + 0.12, x1, y1, 14.0),
                                    (x0, y1 - 0.12, x1 - 0.55, y1, 10.0), (x1 - 0.2, y1 - 0.12, x1, y1, 18.0)] {
            block(a0, b0, a1, b1, g, h, top: .colour(I.brickTop), left: .colour(I.rawBrick), right: .colour(I.rawBrickShade))
            wall(.left, from: a0, b1, at: g) { p in p.courses(0, (a1 - a0) * 32, 3, h - g, course: 2.5, brick: 6, opacity: 0.35) }
            wall(.right, from: a1, b1, at: g) { p in p.courses(0, (b1 - b0) * 32, 3, h - g, course: 2.5, brick: 6, opacity: 0.35) }
            colour(level(a0, b1 - 0.001, a1, b1, g), .colour(I.stone))
        }
        // Scaffolding along the front, flying the owner's pennant.
        scaffold([(x0 - 0.12, y1 + 0.22), (x1 + 0.2, y1 + 0.22)], from: g, height: 34, levels: [14, 28],
                 boards: 14, inward: (0, -0.1))
        pennant(at: iso(x0 - 0.12, y1 + 0.22, g + 34), height: 12, length: 14)
        // Materials beside.
        planks(-1.1, -0.45, 1.05, on: g, count: 4)
        brickStack(0.85, 0.75, 1.2, 1.05, height: 6)
        brickStack(1.0, 0.1, 1.3, 0.35, height: 4)
        mortar(0.0, 0.85, on: g)
    }

    /// New bricks stacked on the map from (x0, y0) to (x1, y1), `height` points high, on a pallet.
    private mutating func brickStack(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, height: Double) {
        typealias I = IndustrialOldBuildingsLateInk
        let g = Workshop.ground
        block(x0, y0, x1, y1, g, g + 1.2, top: nil, left: .colour(I.timberLight), right: .colour(I.timber), width: 0.6)
        block(x0, y0, x1, y1, g + 1.2, g + 1.2 + height, top: .colour(I.brickTop), left: .colour(I.rawBrick),
              right: .colour(I.rawBrickShade), width: 0.8)
        wall(.left, from: x0, y1, at: g + 1.2) { p in p.courses(0, (x1 - x0) * 32, 0, height, course: 1.6, brick: 3.6, opacity: 0.45) }
        wall(.right, from: x1, y1, at: g + 1.2) { p in p.courses(0, (y1 - y0) * 32, 0, height, course: 1.6, brick: 3.6, opacity: 0.45) }
    }
}
