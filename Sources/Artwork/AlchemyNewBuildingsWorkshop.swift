// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age alchemist's workshop: a house with a ground storey of
// dressed stone and an upper storey framed in timber and plastered, under a
// roof of teal slate. A tall chimney of stone rises through its ridge and
// gives off smoke coloured by what is burned below; alembics, retorts and
// flasks of coloured liquor stand in its broad front window; its door stands
// open on the glow of the furnace within, which lights the ground before it;
// and kegs of powder are stacked in the yard. A banner of the owner's colour
// hangs from the upper storey and a pennant flies from the gable. Its
// footprint is three tiles square: x and y run from -1.5 to 1.5.

extension AlchemyNewBuildingsPainter {
    mutating func workshop(complete: Bool) {
        typealias I = AlchemyNewBuildingsInk
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
        static let chimney = (x0: 0.06, y0: -0.66, x1: 0.36, y1: -0.34)
        static let chimneyTop = 122.0
        static let over = 0.1
    }

    /// Cobbles before the door and along the house's front, at fixed places.
    private mutating func cobbles() {
        typealias I = AlchemyNewBuildingsInk
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
        typealias I = AlchemyNewBuildingsInk
        let (x0, y0, x1, y1) = Workshop.house
        let g = Workshop.ground, storey = Workshop.storey, eave = Workshop.eave
        let front = (x1 - x0) * 32, end = (y1 - y0) * 32
        shadow([iso(x1, y0, g), iso(x1 + 0.45, y0 + 0.15, g), iso(x1 + 0.45, y1 + 0.15, g), iso(x1, y1, g)], opacity: 0.12)
        // The ground storey, of dressed stone.
        block(x0, y0, x1, y1, g, storey, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: g) { p in
            p.courses(0, front, 0, storey - g, brick: 9)
            p.frontWindow(6, 7, width: 24, height: 13)
            p.furnaceDoor(front - 13, width: 11, height: 18)
        }
        wall(.right, from: x1, y1, at: g) { p in
            p.courses(0, end, 0, storey - g, brick: 9)
            p.window(10, 9, width: 5, height: 9, shutters: true)
        }
        // The upper storey, framed in timber, standing out a little over the stone.
        let o = 0.04
        block(x0 - o, y0 - o, x1 + o, y1 + o, storey, eave, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        wall(.left, from: x0 - o, y1 + o, at: storey) { p in
            p.timberFrame(front + 2 * o * 32, eave - storey, posts: 7)
            p.casement(front * 0.5 - 4, 6.5, width: 8, height: 8)
            p.casement(front * 0.82 - 4, 6.5, width: 8, height: 8)
            p.hanging(front * 0.17, top: eave - storey - 6, width: 9, length: 13.5)
        }
        wall(.right, from: x1 + o, y1 + o, at: storey) { p in
            p.timberFrame(end + 2 * o * 32, eave - storey, posts: 5)
            p.casement(end * 0.3 - 3.5, 6.5, width: 7, height: 8)
        }
        // The jetty's beam under the upper storey.
        line([iso(x0 - o, y1 + o, storey), iso(x1 + o, y1 + o, storey), iso(x1 + o, y0 - o, storey)], width: 1.6)
        slateRoof(x0 - o, y0 - o, x1 + o, y1 + o, eave: eave, ridge: Workshop.ridge, over: Workshop.over)
        chimney(roofFront: y1 + o + Workshop.over)
        kegs()
        bench(-1.15, 0.95)
    }

    /// A broad window on a wall drawn with `wall`, its foot at (`u`, `v`):
    /// a frame of stone round a dark room, and on the sill the alchemist's
    /// glass: an alembic on its stand, a retort, and flasks of coloured liquor.
    mutating func frontWindow(_ u: Double, _ v: Double, width w: Double, height h: Double) {
        typealias I = AlchemyNewBuildingsInk
        shape(panel(u - 1.6, v - 0.4, u + w + 1.6, v + h + 1.8), .colour(I.stoneTop), width: 0.7)
        shape(panel(u, v, u + w, v + h), .colour(I.tealDark), width: 0.8)
        // A glimmer of the furnace's light on the room's far wall.
        colour(panel(u + w * 0.62, v + 0.6, u + w - 0.6, v + h - 0.6), .colour(I.fire), opacity: 0.35)
        // A shelf across the back, with jars on it.
        line([uv(u + 0.4, v + h * 0.62), uv(u + w - 0.4, v + h * 0.62)], width: 0.7)
        for (k, ju) in [3.0, 6.0, 15.5].enumerated() {
            shape(panel(u + ju, v + h * 0.62, u + ju + 2, v + h * 0.62 + 2.6), .colour(k == 1 ? I.giltShade : I.stone), width: 0.4)
        }
        // The alembic: a round flask over a small flame, its still-head, and the beak running down to a receiver.
        let a = uv(u + 5, v + 0.6)
        line([a + P(-2.4, 0), a + P(-2.4, -2.6)], width: 0.7)
        line([a + P(2.4, 0), a + P(2.4, -2.6)], width: 0.7)
        shape([a + P(-1, -0.4), a + P(0, -2.2), a + P(1, -0.4)], .colour(I.fireCore), width: 0.4)
        svg.circle(a + P(0, -5) + P(-0.5, 0.4), 2.8, fill: .colour(I.glass))
        svg.circle(a + P(0, -4.6) + P(-0.5, 0.4), 2.2, fill: .colour(I.smokeTeal))
        svg.circle(a + P(0, -5), 2.8, fill: .none, stroke: .colour(I.line), width: 0.6)
        shape([a + P(-1, -7.4), a + P(1, -7.4), a + P(1.6, -9.6), a + P(-1.6, -9.6)], .colour(I.glass), width: 0.55)
        line([a + P(1.4, -9), a + P(7, -5.6)], width: 1.4)
        svg.line([a + P(1.4, -9), a + P(7, -5.6)], stroke: .colour(I.glass), width: 0.6)
        svg.circle(a + P(7.6, -2) + P(-0.4, 0.3), 1.9, fill: .colour(I.wineLight))
        svg.circle(a + P(7.6, -2), 1.9, fill: .none, stroke: .colour(I.line), width: 0.55)
        line([a + P(7.6, -3.9), a + P(7.6, -5)], width: 0.8)
        // The retort: a bulb with a long neck bent down to the right.
        let b = uv(u + 15, v + 0.6)
        svg.ellipse(b + P(0, -3) + P(-0.5, 0.4), 3, 2.7, fill: .colour(I.glass))
        svg.ellipse(b + P(0, -2.4) + P(-0.5, 0.4), 2.4, 1.8, fill: .colour(I.giltLight))
        svg.ellipse(b + P(0, -3), 3, 2.7, fill: .none, stroke: .colour(I.line), width: 0.6)
        var neck = PathData()
        neck.move(b + P(1.6, -5.2)); neck.quad(b + P(4, -8.6), b + P(7.4, -3.2))
        svg.path(neck, stroke: .colour(I.line), width: 1.6)
        svg.path(neck, stroke: .colour(I.glass), width: 0.7)
        // Flasks: a tall one of teal liquor, and a squat one of wine.
        let f = uv(u + w - 2.6, v + 0.6)
        shape([f + P(-1.6, 0), f + P(1.6, 0), f + P(0.6, -3.6), f + P(0.6, -7), f + P(-0.6, -7), f + P(-0.6, -3.6)], .colour(I.glass),
              width: 0.55)
        colour([f + P(-1.4, -0.2), f + P(1.4, -0.2), f + P(0.8, -2.6), f + P(-0.8, -2.6)], .colour(I.tealLit))
        // The sill.
        shape(panel(u - 2.2, v - 1.4, u + w + 2.2, v), .colour(I.stoneTop), width: 0.6)
        // Mullion and transom of the window.
        line([uv(u + w / 2, v + h * 0.65), uv(u + w / 2, v + h)], width: 0.9)
    }

    /// The open door of the furnace room on a wall drawn with `wall`, centred
    /// on `u`: an arch of voussoirs over the dark within, where the furnace's
    /// mouth glows, its door of teal planks folded back against the wall.
    mutating func furnaceDoor(_ u: Double, width w: Double, height h: Double) {
        typealias I = AlchemyNewBuildingsInk
        // The door leaf, folded back against the wall at the left.
        shape(panel(u - w / 2 - w * 0.7, 0, u - w / 2, h - w / 2), .colour(I.teal), width: 0.8)
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

    /// The timber frame of a plastered storey on a wall drawn with `wall`,
    /// `length` long and `height` tall: a sill and a plate, `posts` posts,
    /// a rail at mid height, and a brace in each end bay.
    mutating func timberFrame(_ length: Double, _ height: Double, posts: Int) {
        typealias I = AlchemyNewBuildingsInk
        let s = 1.6
        func beam(_ a: P, _ b: P, width: Double = s) {
            svg.line([a, b], stroke: .colour(I.line), width: width + 1)
            svg.line([a + shift * 0.5, b + shift * 0.5], stroke: .colour(I.timber), width: width)
        }
        let mid = height * 0.45
        beam(uv(0, mid), uv(length, mid), width: 1.2)
        for k in 0..<posts {
            let u = length * Double(k) / Double(posts - 1)
            beam(uv(u, 0), uv(u, height))
        }
        let bay = length / Double(posts - 1)
        beam(uv(0.6, mid), uv(bay - 0.6, height - 0.6), width: 1.2)
        beam(uv(length - 0.6, mid), uv(length - bay + 0.6, height - 0.6), width: 1.2)
        beam(uv(0, 0.8), uv(length, 0.8), width: 2)
        beam(uv(0, height - 0.8), uv(length, height - 0.8), width: 2)
    }

    /// A small casement window of leaded panes on a wall drawn with `wall`, its foot at (`u`, `v`).
    mutating func casement(_ u: Double, _ v: Double, width w: Double, height h: Double) {
        typealias I = AlchemyNewBuildingsInk
        shape(panel(u, v, u + w, v + h), .colour(I.tealDark), width: 0.8)
        var lead = PathData()
        lead.move(uv(u + w / 2, v)); lead.line(uv(u + w / 2, v + h))
        lead.move(uv(u, v + h / 2)); lead.line(uv(u + w, v + h / 2))
        lead.move(uv(u + 0.6, v + 0.6)); lead.line(uv(u + w / 2 - 0.4, v + h / 2 - 0.4))
        lead.move(uv(u + w / 2 + 0.4, v + h / 2 + 0.4)); lead.line(uv(u + w - 0.6, v + h - 0.6))
        svg.path(lead, stroke: .colour(I.tealLit), width: 0.45)
        shape(panel(u - 0.8, v - 1, u + w + 0.8, v), .colour(I.timberLight), width: 0.5)
    }

    /// A gabled roof of teal slate over a box from (x0, y0) to (x1, y1), its
    /// eaves at `eave` and its ridge running along x at `ridge`, overhanging by
    /// `over` tiles, its gable end (facing +x) framed in timber and plastered.
    private mutating func slateRoof(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, eave: Double, ridge: Double,
                                    over: Double) {
        typealias I = AlchemyNewBuildingsInk
        let ym = (y0 + y1) / 2
        let (a0, a1, b0, b1) = (x0 - over, x1 + over, y0 - over, y1 + over)
        let drop = (ridge - eave) * over / (ym - y0)
        colour([iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a0, b0, eave - drop)], .colour(I.tealShade))
        // The gable's end wall.
        let triangle = [iso(x1, y1, eave), iso(x1, y0, eave), iso(x1, ym, ridge)]
        colour(triangle, .colour(I.plasterShade))
        wall(.right, from: x1, y1, at: eave) { p in
            let w = (y1 - y0) * 32, rise = ridge - eave
            func post(_ a: P, _ b: P) {
                p.svg.line([a, b], stroke: .colour(I.line), width: 2.4)
                p.svg.line([a, b], stroke: .colour(I.timber), width: 1.4)
            }
            post(p.uv(w / 2, 0), p.uv(w / 2, rise - 1))
            post(p.uv(w * 0.2, 0), p.uv(w / 2, rise * 0.62))
            post(p.uv(w * 0.8, 0), p.uv(w / 2, rise * 0.62))
            post(p.uv(w * 0.18, rise * 0.36), p.uv(w * 0.82, rise * 0.36))
            p.svg.circle(p.uv(w / 2, rise * 0.62) + P(0, 1.5), 1.6, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
        }
        line(triangle, closed: true, width: 0.9)
        // The roof's thickness along the gable, then the front slope.
        let edge = P(0, 2.2)
        colour([iso(a1, b1, eave - drop), iso(a1, ym, ridge), iso(a1, b0, eave - drop), iso(a1, b0, eave - drop) + edge,
                iso(a1, ym, ridge) + edge, iso(a1, b1, eave - drop) + edge], .colour(I.tealDark))
        let front = [iso(a0, ym, ridge), iso(a1, ym, ridge), iso(a1, b1, eave - drop), iso(a0, b1, eave - drop)]
        colour([front[3], front[2], front[2] + edge, front[3] + edge], .colour(I.tealDark))
        colour(front, .colour(I.teal))
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
        svg.path(courses, stroke: .colour(I.tealDark), width: 0.8)
        svg.path(joints, stroke: .colour(I.tealDark), width: 0.45, opacity: 0.8)
        // A lit band along the lower edge of each course.
        var lit = PathData()
        for k in 1..<rows {
            let t = Double(k) / Double(rows) - 0.02
            let y = b1 + (ym - b1) * t, h = (eave - drop) + (ridge - eave + drop) * t
            lit.move(iso(a0 + 0.02, y, h)); lit.line(iso(a1 - 0.02, y, h))
        }
        svg.path(lit, stroke: .colour(I.tealLit), width: 0.5, opacity: 0.8)
        line(front, closed: true, width: 1.1)
        line([front[3], front[3] + edge, front[2] + edge, front[2]], width: 0.9)
        line([iso(a1, ym, ridge), iso(a1, ym, ridge) + edge, iso(a1, b0, eave - drop) + edge, iso(a1, b0, eave - drop)], width: 0.9)
        line([front[2] + edge, iso(a1, ym, ridge) + edge], width: 0.9)
        // The ridge's capping, and the pennant on the gable's peak.
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.line), width: 3.2)
        svg.line([iso(a0, ym, ridge), iso(a1, ym, ridge)], stroke: .colour(I.tealLit), width: 1.6)
        finial(at: iso(a0, ym, ridge), size: 0.8)
        pennant(at: iso(a1, ym, ridge), height: 17, length: 16)
    }

    /// The chimney rising through the roof from the furnace below: a square
    /// stack of stone standing on the slope (whose eaves, with their drop, lie
    /// along `roofFront`), with a capping, giving off smoke in three colours.
    private mutating func chimney(roofFront b1: Double) {
        typealias I = AlchemyNewBuildingsInk
        let (x0, y0, x1, y1) = Workshop.chimney, top = Workshop.chimneyTop
        let (_, h0, _, h1) = Workshop.house
        let ym = (h0 + h1) / 2, ridge = Workshop.ridge
        let drop = (ridge - Workshop.eave) * Workshop.over / (ym - h0 + 0.04)
        /// The height of the roof's surface at `y`, on either slope.
        func roof(_ y: Double) -> Double { ridge - abs(y - ym) / (b1 - ym) * (ridge - (Workshop.eave - drop)) }
        let hf = roof(y1), hb = roof(y0)
        // Its shadow on the slope at its right.
        shadow([iso(x1, y1, hf), iso(x1 + 0.22, y1, roof(y1) - 0.5), iso(x1 + 0.22, ym, ridge), iso(x1, ym, ridge)], opacity: 0.16)
        let left = [iso(x0, y1, hf), iso(x1, y1, hf), iso(x1, y1, top), iso(x0, y1, top)]
        let right = [iso(x1, y1, hf), iso(x1, ym, ridge), iso(x1, y0, hb), iso(x1, y0, top), iso(x1, y1, top)]
        colour(left, .colour(I.stone))
        colour(right, .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: hf) { p in p.courses(0, (x1 - x0) * 32, 0, top - hf, course: 4.4, brick: 6.4) }
        wall(.right, from: x1, y1, at: ridge) { p in p.courses(0, (y1 - y0) * 32, 0, top - ridge, course: 4.4, brick: 6.4) }
        line(left, closed: true, width: 1.1)
        line(right, closed: true, width: 1.1)
        // The lead flashing where it meets the slates.
        svg.line([iso(x0, y1, hf), iso(x1, y1, hf), iso(x1, ym, ridge)], stroke: .colour(I.line), width: 2.4)
        svg.line([iso(x0, y1, hf), iso(x1, y1, hf), iso(x1, ym, ridge)], stroke: .colour(I.ironLight), width: 1.2)
        // A band of stone two thirds up, the capping standing out, and the flue's dark.
        let band = top - 30
        block(x0 - 0.03, y0 - 0.03, x1 + 0.03, y1 + 0.03, band, band + 3, top: nil, left: .colour(I.stoneTop), right: .colour(I.stone),
              width: 0.9)
        block(x0 - 0.05, y0 - 0.05, x1 + 0.05, y1 + 0.05, top - 4, top, top: .colour(I.stoneTop), left: .colour(I.stoneTop),
              right: .colour(I.stone), width: 1)
        shape(level(x0 + 0.06, y0 + 0.06, x1 - 0.06, y1 - 0.06, top), .colour(I.dark), width: 0.6)
        let mouth = iso((x0 + x1) / 2, (y0 + y1) / 2, top)
        puff(at: mouth + P(1, -6), radius: 4.2, colour: I.smokeWine)
        puff(at: mouth + P(5, -16), radius: 5.4, colour: I.smokeTeal)
        puff(at: mouth + P(12, -28), radius: 5.6, colour: I.smokeGilt)
        puff(at: mouth + P(21, -37), radius: 3.8, colour: I.smokeWine)
    }

    /// A puff of smoke at `p`: a cluster of round billows of one colour under one outline.
    private mutating func puff(at p: P, radius r: Double, colour: String) {
        let billows: [(P, Double)] = [(P(-r * 0.7, r * 0.15), r * 0.72), (P(0, -r * 0.35), r), (P(r * 0.8, r * 0.1), r * 0.78),
                                      (P(r * 0.1, r * 0.45), r * 0.7)]
        for (o, s) in billows { svg.circle(p + o, s, fill: .colour(AlchemyNewBuildingsInk.line)) }
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
        typealias I = AlchemyNewBuildingsInk
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

    /// The workshop being built: the stone of the ground storey raised part
    /// of its height, its door's jambs standing, the chimney's stack begun,
    /// the first posts of the upper storey's frame raised at the back,
    /// scaffolding along the front flying the owner's pennant, and stone,
    /// timber and mortar to hand.
    private mutating func workshopRising() {
        typealias I = AlchemyNewBuildingsInk
        let (x0, y0, x1, y1) = Workshop.house
        let g = Workshop.ground
        // The walls at the back, raised higher; the front lower, with the door's opening.
        ashlar(x0, y0, x1, y0 + 0.16, g, 22, course: 4.4, stone: 9, fresh: true)
        ashlar(x0, y0 + 0.16, x0 + 0.16, y1, g, 18, course: 4.4, stone: 9, fresh: true)
        // The furnace and its chimney's stack, begun within: the furnace's arch, cold, at its foot.
        let (c0, d0, c1, d1) = Workshop.chimney
        ashlar(c0 - 0.04, d0 - 0.04, c1 + 0.04, d1 + 0.04, g, 44, course: 4.4, stone: 6.4, fresh: true)
        hollow(level(c0 + 0.06, d0 + 0.06, c1 - 0.06, d1 - 0.06, 44), depth: 6)
        wall(.left, from: c0 - 0.04, d1 + 0.04, at: g) { p in p.arch(5.5, 0, width: 6, height: 7, .colour(I.dark), line: 0.8) }
        // Posts of the upper frame at the back corner, and a plate between them.
        for (px, py) in [(x0 + 0.06, y0 + 0.06), (x0 + 0.66, y0 + 0.06), (x0 + 0.06, y0 + 0.66)] {
            pole(iso(px, py, 22), iso(px, py, 46), width: 2, colour: I.timber)
        }
        pole(iso(x0 + 0.06, y0 + 0.06, 45), iso(x0 + 0.66, y0 + 0.06, 45), width: 2.2, colour: I.timber)
        pole(iso(x0 + 0.06, y0 + 0.06, 45), iso(x0 + 0.06, y0 + 0.66, 45), width: 2.2, colour: I.timber)
        pennant(at: iso(x0 + 0.06, y0 + 0.06, 46), height: 12, length: 14)
        ashlar(x1 - 0.16, y0 + 0.16, x1, y1, g, 14, course: 4.4, stone: 9, fresh: true)
        ashlar(x0, y1 - 0.16, x1 - 0.55, y1, g, 10, course: 4.4, stone: 9, fresh: true)
        ashlar(x1 - 0.2, y1 - 0.16, x1, y1, g, 20, course: 4.4, stone: 9, fresh: true)
        // Scaffolding along the front and the gable, flying the owner's pennant.
        scaffold([(x0 - 0.12, y1 + 0.22), (x1 + 0.2, y1 + 0.22), (x1 + 0.2, y0 - 0.1)], from: g, height: 40, levels: [14, 28, 38],
                 boards: 14, inward: (0, -0.1))
        pennant(at: iso(x1 + 0.2, y1 + 0.22, g + 40), height: 14, length: 15)
        // Materials beside.
        planks(-1.1, -0.45, 1.05, on: g, count: 4)
        stones(0.85, 0.75, 1.2, 1.05, from: g, courses: 2)
        stones(1.0, -1.3, 1.3, -1.05, from: g, courses: 1)
        mortar(0.0, 0.85, on: g)
        stones(-0.25, 1.15, 0.0, 1.35, from: g, courses: 1)
    }
}
