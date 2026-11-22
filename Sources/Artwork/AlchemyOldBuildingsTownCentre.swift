// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age town centre: the Iron age's temple grown into a town hall.
// Its ground floor is an open arcade of stone, where the market is held; its
// upper floor, the council's hall, is half-timbered in dark oak with tall
// leaded windows, under a steep hipped roof of slate with gilt finials.
// Before it stands the belfry: a tower of dressed stone with quoins, entered
// by an arched door, with a clock on each face, an open stage for the bell,
// and a spire of slate under a gilt weathervane, the tallest thing in the
// town. Banners of the owner's colour hang from the hall, a band of it runs
// along the floor of the upper storey, pennants fly at the court's corners,
// and a well stands on the cobbled court. Its footprint is three tiles
// square: x and y run from -1.5 to 1.5.

extension AlchemyOldBuildingsPainter {
    mutating func townCentre(complete: Bool) {
        cobbles(1.5, height: 3)
        if complete { townHall() } else { townHallRising() }
    }

    private static let hall = (x0: -1.32, y0: -1.32, x1: 0.98, y1: 0.3)
    private static let belfry = (x0: -0.5, y0: 0.3, x1: 0.14, y1: 0.94)
    private static let upperFloor = 23.0
    private static let hallEaves = 43.0
    private static let towerTop = 66.0
    private static let bellStage = 80.0

    /// The arcade along a wall drawn with `wall`: round arches on piers of
    /// stone, dark within, between `u0` and `u1`, `count` of them.
    private mutating func arcade(_ u0: Double, _ u1: Double, count: Int, height: Double) {
        typealias I = AlchemyOldBuildingsInk
        let bay = (u1 - u0) / Double(count)
        for k in 0..<count {
            let u = u0 + bay * (Double(k) + 0.5)
            arch(u, 0, width: bay - 2.4, height: height, .colour(I.stoneTop), line: 0.7)
            arch(u, 0, width: bay - 4.6, height: height - 1.6, .colour(I.dark), line: 0.9)
            // The keystone.
            shape(panel(u - 0.9, height - 1.4, u + 0.9, height + 0.4), .colour(I.stoneTop), width: 0.5)
        }
    }

    private mutating func townHall() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hall
        let h0 = 3.0, f = Self.upperFloor, e = Self.hallEaves
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        let (t0, t1) = ((Self.belfry.x0 - x0) * 32, (Self.belfry.x1 - x0) * 32)
        shadow([iso(x1, y0, h0), iso(x1 + 0.34, y0 + 0.18, h0), iso(x1 + 0.34, y1 + 0.14, h0), iso(x1, y1, h0)])
        // The ground floor: an arcade of stone along the front, windows at the side.
        block(x0, y0, x1, y1, h0, f, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.colour(p.panel(0, 0, front, 2.4), .colour(I.footing))
            p.courses(0, front, 2.4, f - h0, course: 3.9, brick: 9.6, opacity: 0.3)
            p.arcade(1.6, t0 - 1, count: 3, height: 15)
            p.arcade(t1 + 1, front - 1.6, count: 2, height: 15)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.colour(p.panel(0, 0, side, 2.4), .colour(I.footingShade))
            p.courses(0, side, 2.4, f - h0, course: 3.9, brick: 9.6)
            p.quoins(at: 0, atStart: true, from: 2.4, to: f - h0, course: 3.9)
            for u in [9.0, 23.0, 37.0] { p.casement(u, 6, w: 7, h: 9, lights: 2, frame: I.stoneTop) }
        }
        // The upper floor: the council's hall, half-timbered.
        block(x0, y0, x1, y1, f, e, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        wall(.left, from: x0, y1, at: f) { p in
            let posts = [1.0, 9.6, 18.2, 26.8, 35.4, 47.2, 55.8, 64.4, front - 1]
            p.framing(front, from: 0, to: e - f, posts: posts, rail: 6, braces: [(0, true), (7, false)])
            p.studs(11.8, 16.2, from: 0, to: 6, step: 2.2)
            for u in [11.0, 19.6, 28.2, 57.2] { p.casement(u, 8, w: 6, h: 9.4, lights: 1) }
            p.banner(5.3, top: e - f - 1.6, width: 6, length: 14)
            p.banner(front - 5.3, top: e - f - 1.6, width: 6, length: 14)
            p.paintedBand(0, front, 0.6, 2.8)
        }
        wall(.right, from: x1, y1, at: f) { p in
            p.framing(side, from: 0, to: e - f, posts: [1, 13.5, 26, 38.5, side - 1], rail: 6, braces: [(0, true), (3, false)])
            p.casement(15, 8, w: 9, h: 9.4, lights: 2)
            p.casement(40.5, 8, w: 9, h: 9.4, lights: 2)
            p.banner(32.2, top: e - f - 1.6, width: 6, length: 14)
            p.paintedBand(0, side, 0.6, 2.8)
        }
        shadow([iso(x0, y1, e - 2.4), iso(x1, y1, e - 2.4), iso(x1, y1, e), iso(x0, y1, e)], opacity: 0.12)
        shadow([iso(x1, y1, e - 2.4), iso(x1, y0, e - 2.4), iso(x1, y0, e), iso(x1, y1, e)], opacity: 0.12)
        hippedRoof(x0, y0, x1, y1, eaves: e, rise: 36, overhang: 0.07)
        dormer(0.62, on: (x0, y0, x1, y1), eaves: e, rise: 36)
        belfryTower()
        well(at: (1.0, 0.98))
        pennant(at: iso(-1.36, 1.36, 3), height: 38, length: 15)
        pennant(at: iso(1.32, -1.32, 3), height: 38, length: 13)
    }

    /// A dormer window standing on the front slope of the hall's roof, centred
    /// on `x`: a small gable of plaster and oak with a leaded window, under its
    /// own roof of slate.
    private mutating func dormer(_ x: Double, on box: (Double, Double, Double, Double), eaves e: Double, rise: Double) {
        typealias I = AlchemyOldBuildingsInk
        let o = 0.07
        let (_, y0, _, y1) = box
        let k = (y1 - y0 + 2 * o) / 2
        // The height of the front slope at y, from its eave at y1 + o.
        func slope(_ y: Double) -> Double { e + rise * (y1 + o - y) / k }
        let w = 0.13, yf = y1 - 0.12, h0 = slope(yf), h1 = h0 + 9
        let yb = y1 + o - (h1 - e) / rise * k
        // Its cheek on the right, running back into the slope.
        colour([iso(x + w, yf, h0), iso(x + w, yf, h1), iso(x + w, yb, h1)], .colour(I.plasterShade))
        line([iso(x + w, yf, h0), iso(x + w, yb, h1)], width: 0.8)
        colour(level(x - w, yf, x + w, yf, h0) + [iso(x + w, yf, h1), iso(x - w, yf, h1)], .colour(I.light))
        wall(.left, from: x - w, yf, at: h0) { p in
            let width = 2 * w * 32
            p.timber(p.uv(0.8, 0), p.uv(0.8, 9), width: 1.4)
            p.timber(p.uv(width - 0.8, 0), p.uv(width - 0.8, 9), width: 1.4)
            p.casement(2.4, 1.6, w: width - 4.8, h: 5.6, lights: 1)
        }
        line([iso(x - w, yf, h0), iso(x + w, yf, h0), iso(x + w, yf, h1), iso(x - w, yf, h1)], closed: true, width: 0.8)
        gableAlongY(x - w, yb, x + w, yf, eave: h1, ridge: h1 + 9, over: 0.03, gableWall: .colour(I.light), finials: false) { p, width, r in
            p.timber(p.uv(width / 2, 0), p.uv(width / 2, r - 1), width: 1.2)
        }
        finial(at: iso(x, yf + 0.03, h1 + 9), size: 0.7)
    }

    /// The belfry before the hall: its shaft of stone with quoins, door,
    /// window and clocks; its open stage for the bell; and its spire.
    private mutating func belfryTower() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.belfry
        let h0 = 3.0, top = Self.towerTop, stage = Self.bellStage
        let w = (x1 - x0) * 32, d = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.14, h0), iso(x1, y1, h0)], opacity: 0.16)
        block(x0, y0, x1, y1, h0, top, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.colour(p.panel(0, 0, w, 3), .colour(I.footing))
            p.line([p.uv(0, 3), p.uv(w, 3)], width: 0.6)
            p.courses(0, w, 3, top - h0, course: 4.2, brick: 8.4)
            p.quoins(at: 0, atStart: true, from: 3, to: top - h0, course: 4.2)
            p.quoins(at: w, atStart: false, from: 3, to: top - h0, course: 4.2)
            p.door(w / 2, 0, w: 9, h: 15)
            p.casement(w / 2 - 3, 24, w: 6, h: 9, lights: 1, frame: I.stoneTop)
            // A string course, and the clock above it.
            p.shape(p.panel(-0.3, 40, w + 0.3, 41.8), .colour(I.stoneTop), width: 0.6)
            p.clock(w / 2, 51.5, radius: 6.6)
            p.paintedBand(0, w, 36.2, 38.4)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.colour(p.panel(0, 0, d, 3), .colour(I.footingShade))
            p.line([p.uv(0, 3), p.uv(d, 3)], width: 0.6)
            p.courses(0, d, 3, top - h0, course: 4.2, brick: 8.4)
            p.quoins(at: 0, atStart: true, from: 3, to: top - h0, course: 4.2)
            p.casement(d / 2 - 2.4, 13, w: 4.8, h: 8, lights: 1, frame: I.stoneTop)
            p.casement(d / 2 - 3, 24, w: 6, h: 9, lights: 1, frame: I.stoneTop)
            p.shape(p.panel(-0.3, 40, d + 0.3, 41.8), .colour(I.stone), width: 0.6)
            p.clock(d / 2, 51.5, radius: 6.6)
            p.paintedBand(0, d, 36.2, 38.4)
        }
        // The cornice under the bell stage.
        block(x0 - 0.03, y0 - 0.03, x1 + 0.03, y1 + 0.03, top, top + 2, top: .colour(I.stoneTop), left: .colour(I.stoneTop),
              right: .colour(I.stone), width: 0.9)
        // The bell stage: four corner piers round open arches, and the bell within.
        let (s0, s1, r0, r1) = (x0 + 0.02, x1 - 0.02, y0 + 0.02, y1 - 0.02)
        let base = top + 2
        colour(level(s0, r0, s1, r1, base), .colour(I.dark))
        colour([iso(s0, r0, base), iso(s1, r0, base), iso(s1, r0, stage), iso(s0, r0, stage)], .colour(I.stoneShade))
        colour([iso(s0, r1, base), iso(s0, r0, base), iso(s0, r0, stage), iso(s0, r1, stage)], .colour(I.footingShade))
        let bell = iso((s0 + s1) / 2, (r0 + r1) / 2, base + 3)
        func outline(_ o: P) -> PathData {
            var path = PathData()
            path.move(bell + P(-4.6, 0) + o)
            path.quad(bell + P(-3.4, -1.6) + o, bell + P(-3.2, -4.6) + o)
            path.quad(bell + P(0, -8.6) + o, bell + P(3.2, -4.6) + o)
            path.quad(bell + P(3.4, -1.6) + o, bell + P(4.6, 0) + o)
            path.close()
            return path
        }
        line([bell + P(0, -8.4), bell + P(0, -(stage - base - 4))], width: 0.8)
        colour(.colour(I.giltShade)) { path, o in path = outline(o) }
        line(width: 0.8) { path in path = outline(P(0, 0)) }
        line([bell + P(-2, -5.4), bell + P(-2.6, -1.2)], width: 0.6, opacity: 0.5)
        for side in [AlchemyOldBuildingsSide.left, .right] {
            let length = side == .left ? (s1 - s0) * 32 : (r1 - r0) * 32
            wall(side, from: side == .left ? s0 : s1, r1, at: base) { p in
                func at(_ u: Double, _ v: Double) -> P { P(u, -v) }
                let paint = side == .left ? I.stone : I.stoneShade
                // The face round the opening: piers at the corners and a round head.
                let r = (length - 7) / 2
                p.colour(.colour(paint)) { path, o in
                    path.move(at(0, 0) + o)
                    path.line(at(3.5, 0) + o)
                    path.line(at(3.5, stage - base - 3 - r) + o)
                    path.quad(at(length / 2, stage - base - 3 + r * 0.3) + o, at(length - 3.5, stage - base - 3 - r) + o)
                    path.line(at(length - 3.5, 0) + o)
                    path.line(at(length, 0) + o)
                    path.line(at(length, stage - base) + o)
                    path.line(at(0, stage - base) + o)
                    path.close()
                }
                p.line(width: 0.8) { path in
                    path.move(at(3.5, 0))
                    path.line(at(3.5, stage - base - 3 - r))
                    path.quad(at(length / 2, stage - base - 3 + r * 0.3), at(length - 3.5, stage - base - 3 - r))
                    path.line(at(length - 3.5, 0))
                }
                // Louvres across the foot of the opening.
                for v in [1.6, 3.6] { p.timber(p.uv(3.5, v), p.uv(length - 3.5, v + 0.8), width: 1, paint: I.oakLight) }
            }
        }
        line([iso(s0, r1, stage), iso(s0, r1, base), iso(s1, r1, base), iso(s1, r0, base), iso(s1, r0, stage)], width: 1.1)
        line([iso(s1, r1, base), iso(s1, r1, stage)], width: 1.1)
        // The cornice over the bell stage, with a gilt finial at each corner, and the spire.
        block(x0 - 0.05, y0 - 0.05, x1 + 0.05, y1 + 0.05, stage, stage + 2.4, top: .colour(I.stoneTop), left: .colour(I.stoneTop),
              right: .colour(I.stone), width: 0.9)
        for (x, y) in [(x0 - 0.02, y0 - 0.02), (x0 - 0.02, y1 + 0.02), (x1 + 0.02, y0 - 0.02)] {
            finial(at: iso(x, y, stage + 2.4), size: 0.9)
        }
        let apex = hippedRoof(x0 + 0.02, y0 + 0.02, x1 - 0.02, y1 - 0.02, eaves: stage + 2.4, rise: 24, overhang: 0.04,
                              finials: false)
        finial(at: iso(x1 + 0.02, y1 + 0.02, stage + 2.4), size: 0.9)
        weathervane(at: iso((x0 + x1) / 2, (y0 + y1) / 2, apex), height: 12)
    }

    /// A well of stone on the court at (x, y): a round curb, two posts of oak,
    /// a little roof of slate, and a bucket on its windlass.
    private mutating func well(at place: (Double, Double)) {
        typealias I = AlchemyOldBuildingsInk
        let (x, y) = place
        let c = iso(x, y, 3)
        let rx = 8.0, ry = 4.0, h = 6.0
        svg.ellipse(c + P(1, 1), rx + 2, ry + 1.4, fill: .colour("#000000"), opacity: 0.14)
        colour([c + P(-rx, 0), c + P(-rx, -h), c + P(rx, -h), c + P(rx, 0)], .colour(I.stone))
        svg.ellipse(c + shift, rx, ry, fill: .colour(I.stone))
        svg.ellipse(c + P(0, -h) + shift, rx, ry, fill: .colour(I.stoneTop))
        svg.ellipse(c + P(0, -h), rx - 1.8, ry - 0.9, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.7)
        svg.ellipse(c + P(0, -h), rx, ry, fill: .none, stroke: .colour(I.line), width: 0.9)
        line(width: 0.9) { d in
            d.move(c + P(-rx, -h)); d.line(c + P(-rx, 0))
            d.move(c + P(rx, -h)); d.line(c + P(rx, 0))
            d.move(c + P(-rx, 0)); d.quad(c + P(0, ry * 2), c + P(rx, 0))
        }
        for k in 0..<5 {
            let u = -rx + 2.6 + Double(k) * 3
            line([c + P(u, -h + ry * 0.9 + abs(u) * -0.1), c + P(u, ry * 0.75 - abs(u) * 0.12)], width: 0.4, opacity: 0.5)
        }
        line([c + P(-rx, -h * 0.5 + 0.8), c + P(rx, -h * 0.5 + 0.8)], width: 0.4, opacity: 0.4)
        for s in [-1.0, 1.0] { pole(c + P(s * (rx - 1.4), -h + 1), c + P(s * (rx - 1.4), -h - 13), width: 1.5, colour: I.oak) }
        pole(c + P(-rx + 1.4, -h - 8), c + P(rx - 1.4, -h - 8), width: 1.6, colour: I.timberLight)
        line([c + P(1.4, -h - 8), c + P(1.4, -h - 3.6)], width: 0.5)
        shape([c + P(-0.2, -h - 3.6), c + P(3, -h - 3.6), c + P(2.6, -h - 0.8), c + P(0.2, -h - 0.8)], .colour(I.timber), width: 0.6)
        let roof = [c + P(-rx - 2.4, -h - 12), c + P(0, -h - 19), c + P(rx + 2.4, -h - 12), c + P(rx + 2.4, -h - 13.6),
                    c + P(0, -h - 20.6), c + P(-rx - 2.4, -h - 13.6)]
        shape([roof[0], roof[1], roof[2], c + P(rx + 2.4, -h - 10.6), c + P(0, -h - 17.6), c + P(-rx - 2.4, -h - 10.6)],
              .colour(I.slate), width: 0.8)
        shape([c + P(-rx - 2.4, -h - 10.6), c + P(0, -h - 17.6), c + P(0, -h - 19), roof[0]], .colour(I.slateLight), width: 0.6)
        finial(at: c + P(0, -h - 19), size: 0.7)
    }

    /// The town hall being built: the arcade of the ground floor raised in
    /// fresh stone, its arches turned on timber centring; the belfry's shaft
    /// half raised inside scaffolding flying the owner's pennant; a treadwheel
    /// crane lifting a block; and stone, oak and slates to hand on the court.
    private mutating func townHallRising() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hall
        let h0 = 3.0, f = Self.upperFloor - 4
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        let (t0, t1) = ((Self.belfry.x0 - x0) * 32, (Self.belfry.x1 - x0) * 32)
        scaffold([(x0 + 0.1, y0 - 0.1), (-0.4, y0 - 0.1), (x1 - 0.1, y0 - 0.1)], from: h0, height: 28, levels: [11, 22])
        shadow([iso(x1, y0, h0), iso(x1 + 0.2, y0 + 0.12, h0), iso(x1 + 0.2, y1 + 0.08, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: f, thickness: 0.1, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.pavingShade)) { p in
            p.blocks(-0.9, -0.9, -0.6, -0.6, from: h0, courses: 2)
            p.basket(at: p.iso(0.2, -0.6, h0), size: 0.9)
            p.timbers(-0.2, -1.0, length: 0.8, on: h0)
            p.treadwheel(0.3, -0.75, on: h0, height: 54, reach: 30, drop: 20)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, front, 0, f - h0, course: 3.9, brick: 9.6, opacity: 0.35)
            p.arcade(1.6, t0 - 1, count: 3, height: 13)
            p.arcade(t1 + 1, front - 1.6, count: 2, height: 13)
            // The timber centring still under the last arch.
            let bay = (front - 1.6 - t1 - 1) / 2, u = t1 + 1 + bay * 1.5
            p.timber(p.uv(u - bay / 2 + 2.3, 0.4), p.uv(u - bay / 2 + 2.3, 9), width: 1.2, paint: I.timberLight)
            p.timber(p.uv(u + bay / 2 - 2.3, 0.4), p.uv(u + bay / 2 - 2.3, 9), width: 1.2, paint: I.timberLight)
            p.timber(p.uv(u - bay / 2 + 2.3, 9), p.uv(u + bay / 2 - 2.3, 9), width: 1.2, paint: I.timberLight)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.courses(0, side, 0, f - h0, course: 3.9, brick: 9.6, opacity: 0.35)
            for u in [9.0, 23.0, 37.0] { p.shape(p.panel(u, 6, u + 7, 15), .colour(I.dark), width: 0.8) }
        }
        blocks(x0, y0, x0 + 0.12, y0 + 1.1, from: f, courses: 1)
        blocks(x0 + 0.12, y0, 0.1, y0 + 0.12, from: f, courses: 1)
        // The belfry's shaft, half raised inside its scaffold.
        let (bx0, by0, bx1, by1) = Self.belfry
        let shaft = 38.0
        scaffold([(bx0 - 0.12, by0 + 0.02), (bx1 + 0.12, by0 + 0.02)], from: h0, height: 50, levels: [14, 28, 42])
        block(bx0, by0, bx1, by1, h0, shaft, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade))
        wall(.left, from: bx0, by1, at: h0) { p in
            let w = (bx1 - bx0) * 32
            p.courses(0, w, 0, shaft - h0, course: 4.2, brick: 8.4)
            p.shape(p.panel(w / 2 - 4.5, 0, w / 2 + 4.5, 13), .colour(I.dark), width: 0.9)
            p.shape(p.panel(w / 2 - 3, 21, w / 2 + 3, 30), .colour(I.dark), width: 0.8)
        }
        wall(.right, from: bx1, by1, at: h0) { p in p.courses(0, (by1 - by0) * 32, 0, shaft - h0, course: 4.2, brick: 8.4) }
        blocks(bx0, by0, bx1, by0 + 0.12, from: shaft, courses: 1)
        scaffold([(bx0 - 0.12, by1 + 0.12), (bx1 + 0.12, by1 + 0.12), (bx1 + 0.12, by0 + 0.02)], from: h0, height: 50,
                 levels: [14, 28, 42], boards: 28, inward: (0, -0.12))
        pennant(at: iso(bx1 + 0.12, by1 + 0.12, h0 + 50), height: 13, length: 15)
        // Materials on the court.
        timbers(0.5, 0.62, length: 0.8, on: h0)
        slates(0.62, 1.0, 0.98, 1.2, from: h0, height: 7)
        blocks(-1.32, 0.62, -1.0, 0.94, from: h0, courses: 2)
        blocks(-1.32, 1.04, -1.12, 1.3, from: h0, courses: 1)
        barrel(at: iso(1.25, 0.6, h0), size: 0.9)
        sack(at: iso(-0.55, 1.3, h0), size: 0.9)
        pennant(at: iso(-1.36, 1.36, 3), height: 30, length: 15)
    }
}
