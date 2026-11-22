// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age town centre: the Alchemy age's town hall rebuilt as a
// Victorian one, still the largest building of the town. Two storeys of red
// brick stand on a plinth of stone, with quoins, string courses and a cornice
// of dressed stone: round-headed windows light the ground floor, tall sash
// windows the council chamber above, between brick pilasters. Its hipped roof
// of blue-grey slate carries iron cresting, dormers and chimney stacks with
// pots. Before it rises the clock tower: a shaft of brick with stone quoins,
// entered by a panelled door under a fanlight, with a clock on each face, an
// open belfry of arches, and a spire of slate under an iron weathervane, the
// tallest thing in the town. Banners of the owner's colour hang from the
// chamber, a band of it runs along the string course, pennants fly at the
// court's corners, and gas lamps stand on the paved court. Its footprint is
// three tiles square: x and y run from -1.5 to 1.5.

extension IndustrialOldBuildingsPainter {
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


    private mutating func townHall() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hall
        let h0 = 3.0, f = Self.upperFloor, e = Self.hallEaves
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        let (t0, t1) = ((Self.belfry.x0 - x0) * 32, (Self.belfry.x1 - x0) * 32)
        shadow([iso(x1, y0, h0), iso(x1 + 0.34, y0 + 0.18, h0), iso(x1 + 0.34, y1 + 0.14, h0), iso(x1, y1, h0)])
        // Two storeys of brick on a plinth of stone.
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 3), .colour(I.footing), width: 0.6)
            p.brickwork(0, front, 3, e - h0)
            p.quoins(at: 0, atStart: true, from: 3, to: e - h0 - 2, course: 3.6)
            p.quoins(at: front, atStart: false, from: 3, to: e - h0 - 2, course: 3.6)
            // The ground floor: round-headed windows either side of the tower.
            for u in [7.5, 17.0] { p.archedWindow(u, 4.5, w: 6, h: 12) }
            for u in [t1 + 7.0, t1 + 17.0] where u < front - 4 { p.archedWindow(u, 4.5, w: 6, h: 12) }
            p.stringCourse(0, front, f - h0 - 1.2, f - h0 + 0.6)
            p.paintedBand(0, t0, f - h0 + 1.6, f - h0 + 3.2)
            p.paintedBand(t1, front, f - h0 + 1.6, f - h0 + 3.2)
            // The council chamber: tall sashes between pilasters.
            for u in [12.3, t1 + 12.0] { p.pilaster(u, f - h0 + 4, e - h0 - 2.4) }
            for u in [4.0, 15.0] { p.casement(u, f - h0 + 6, w: 5.4, h: 10.4, lights: 1) }
            for u in [t1 + 4.0, t1 + 15.0] where u < front - 6 { p.casement(u, f - h0 + 6, w: 5.4, h: 10.4, lights: 1) }
            p.drainpipe(front - 2.4, from: e - h0 - 2.2)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 3), .colour(I.footingShade), width: 0.6)
            p.brickwork(0, side, 3, e - h0)
            p.quoins(at: 0, atStart: true, from: 3, to: e - h0 - 2, course: 3.6)
            p.quoins(at: side, atStart: false, from: 3, to: e - h0 - 2, course: 3.6)
            p.door(side / 2, 3, w: 8, h: 14.5)
            for u in [7.5, side - 7.5] { p.archedWindow(u, 4.5, w: 6, h: 12) }
            p.stringCourse(0, side, f - h0 - 1.2, f - h0 + 0.6)
            p.paintedBand(0, side, f - h0 + 1.6, f - h0 + 3.2)
            for u in [16.0, side - 16.0] { p.pilaster(u, f - h0 + 4, e - h0 - 2.4) }
            p.casement(4.4, f - h0 + 6, w: 7.4, h: 10.4, lights: 2)
            p.banner(side / 2, top: e - h0 - 3, width: 7, length: 15)
            p.casement(side - 11.8, f - h0 + 6, w: 7.4, h: 10.4, lights: 2)
        }
        cornice(x0, y0, x1, y1, at: e + 1.6, depth: 2.4)
        shadow([iso(x0, y1, e - 2.4), iso(x1, y1, e - 2.4), iso(x1, y1, e), iso(x0, y1, e)], opacity: 0.12)
        let ridge = hippedRoof(x0, y0, x1, y1, eaves: e + 1.6, rise: 30, overhang: 0.06, finials: true)
        let k = (y1 - y0 + 0.12) / 2
        cresting(iso(x0 - 0.06 + k, y0 - 0.06 + k, ridge), iso(x1 + 0.06 - k, y0 - 0.06 + k, ridge))
        chimneyStack(-1.1, -1.08, -0.86, -0.92, from: e + 10, to: ridge + 3, pots: 2)
        chimneyStack(0.62, -1.08, 0.86, -0.92, from: e + 10, to: ridge + 3, pots: 2)
        dormer(0.58, on: (x0, y0, x1, y1), eaves: e + 1.6, rise: 30)
        clockTower()
        gasLamp(at: iso(1.18, 0.62, 3), height: 26)
        gasLamp(at: iso(-0.85, 1.2, 3), height: 26)
        pennant(at: iso(-1.36, 1.36, 3), height: 38, length: 15)
        pennant(at: iso(1.32, -1.32, 3), height: 38, length: 13)
    }

    /// A dormer window standing on the front slope of the hall's roof,
    /// centred on `x`: a small gable of brick with a sash window, under its
    /// own roof of slate with a bargeboard painted the light colour.
    private mutating func dormer(_ x: Double, on box: (Double, Double, Double, Double), eaves e: Double, rise: Double) {
        typealias I = IndustrialOldBuildingsInk
        let o = 0.06
        let (_, y0, _, y1) = box
        let k = (y1 - y0 + 2 * o) / 2
        func slope(_ y: Double) -> Double { e + rise * (y1 + o - y) / k }
        let w = 0.14, yf = y1 - 0.1, h0 = slope(yf), h1 = h0 + 9
        let yb = y1 + o - (h1 - e) / rise * k
        colour([iso(x + w, yf, h0), iso(x + w, yf, h1), iso(x + w, yb, h1)], .colour(I.brickShade))
        line([iso(x + w, yf, h0), iso(x + w, yb, h1)], width: 0.8)
        colour(level(x - w, yf, x + w, yf, h0) + [iso(x + w, yf, h1), iso(x - w, yf, h1)], .colour(I.brick))
        wall(.left, from: x - w, yf, at: h0) { p in
            let width = 2 * w * 32
            p.brickwork(0, width, 0, 9, course: 2.2, brick: 4.6, burnt: false)
            p.casement(2.6, 1.8, w: width - 5.2, h: 5.6, lights: 1)
        }
        line([iso(x - w, yf, h0), iso(x + w, yf, h0), iso(x + w, yf, h1), iso(x - w, yf, h1)], closed: true, width: 0.8)
        gableAlongY(x - w, yb, x + w, yf, eave: h1, ridge: h1 + 8, over: 0.03, gableWall: .colour(I.brick), finials: false)
        finial(at: iso(x, yf + 0.03, h1 + 8), size: 0.8)
    }

    /// The clock tower before the hall: its shaft of brick with stone quoins,
    /// door, window and clocks; its open belfry; and its spire.
    private mutating func clockTower() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.belfry
        let h0 = 3.0, top = Self.towerTop, stage = Self.bellStage
        let w = (x1 - x0) * 32, d = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.14, h0), iso(x1, y1, h0)], opacity: 0.16)
        block(x0, y0, x1, y1, h0, top, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        for side in [IndustrialOldBuildingsSide.left, .right] {
            let length = side == .left ? w : d
            wall(side, from: side == .left ? x0 : x1, y1, at: h0) { p in
                p.shape(p.panel(0, 0, length, 3), .colour(side == .left ? I.footing : I.footingShade), width: 0.6)
                p.brickwork(0, length, 3, top - h0)
                p.quoins(at: 0, atStart: true, from: 3, to: top - h0, course: 3.6)
                p.quoins(at: length, atStart: false, from: 3, to: top - h0, course: 3.6)
                if side == .left {
                    p.door(length / 2, 3, w: 8, h: 15)
                } else {
                    p.archedWindow(length / 2, 6, w: 5, h: 10)
                }
                p.stringCourse(0, length, 20.4, 22)
                p.paintedBand(0, length, 23.4, 25)
                p.casement(length / 2 - 2.6, 27.5, w: 5.2, h: 8.5, lights: 1)
                p.stringCourse(0, length, 39.4, 41)
                p.clock(length / 2, 50.8, radius: 6.4)
            }
        }
        cornice(x0, y0, x1, y1, at: top + 2, depth: 2)
        // The belfry: four corner piers of brick round open arches, and the bell within.
        let (s0, s1, r0, r1) = (x0 + 0.02, x1 - 0.02, y0 + 0.02, y1 - 0.02)
        let base = top + 2
        colour(level(s0, r0, s1, r1, base), .colour(I.dark))
        colour([iso(s0, r0, base), iso(s1, r0, base), iso(s1, r0, stage), iso(s0, r0, stage)], .colour(I.brickShade))
        colour([iso(s0, r1, base), iso(s0, r0, base), iso(s0, r0, stage), iso(s0, r1, stage)], .colour(I.brickDark))
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
        colour(.colour(I.brassShade)) { path, o in path = outline(o) }
        line(width: 0.8) { path in path = outline(P(0, 0)) }
        line([bell + P(-2, -5.4), bell + P(-2.6, -1.2)], width: 0.6, opacity: 0.5)
        for side in [IndustrialOldBuildingsSide.left, .right] {
            let length = side == .left ? (s1 - s0) * 32 : (r1 - r0) * 32
            wall(side, from: side == .left ? s0 : s1, r1, at: base) { p in
                func at(_ u: Double, _ v: Double) -> P { P(u, -v) }
                let paint = side == .left ? I.brick : I.brickShade
                let r = (length - 7) / 2
                let spring = stage - base - 3 - r
                p.colour(.colour(paint)) { path, o in
                    path.move(at(0, 0) + o)
                    path.line(at(3.5, 0) + o)
                    path.line(at(3.5, spring) + o)
                    path.quad(at(length / 2, spring + r * 1.3) + o, at(length - 3.5, spring) + o)
                    path.line(at(length - 3.5, 0) + o)
                    path.line(at(length, 0) + o)
                    path.line(at(length, stage - base) + o)
                    path.line(at(0, stage - base) + o)
                    path.close()
                }
                // The arch's ring of stone, with its keystone.
                p.line(width: 2.2) { path in
                    path.move(at(3.5, spring)); path.quad(at(length / 2, spring + r * 1.3), at(length - 3.5, spring))
                }
                p.svg.path({ var path = PathData()
                    path.move(at(3.5, spring)); path.quad(at(length / 2, spring + r * 1.3), at(length - 3.5, spring))
                    return path }(), stroke: .colour(I.stoneTop), width: 1.3)
                p.line(width: 0.8) { path in
                    path.move(at(3.5, 0)); path.line(at(3.5, spring))
                    path.move(at(length - 3.5, 0)); path.line(at(length - 3.5, spring))
                }
                p.shape(p.panel(length / 2 - 0.9, stage - base - 3.6 + r * 0.3, length / 2 + 0.9, stage - base - 1.2),
                        .colour(I.stoneTop), width: 0.45)
                // Louvres of painted board across the foot of the opening.
                for v in [1.4, 3.4, 5.4] { p.timber(p.uv(3.5, v), p.uv(length - 3.5, v + 0.8), width: 1, paint: I.greenLight) }
            }
        }
        line([iso(s0, r1, stage), iso(s0, r1, base), iso(s1, r1, base), iso(s1, r0, base), iso(s1, r0, stage)], width: 1.1)
        line([iso(s1, r1, base), iso(s1, r1, stage)], width: 1.1)
        cornice(x0 - 0.02, y0 - 0.02, x1 + 0.02, y1 + 0.02, at: stage + 2.4, depth: 2.4)
        for (x, y) in [(x0 - 0.03, y0 - 0.03), (x0 - 0.03, y1 + 0.03), (x1 + 0.03, y0 - 0.03)] {
            finial(at: iso(x, y, stage + 2.4), size: 0.8)
        }
        let apex = hippedRoof(x0 + 0.01, y0 + 0.01, x1 - 0.01, y1 - 0.01, eaves: stage + 2.4, rise: 26, overhang: 0.04,
                              finials: false)
        finial(at: iso(x1 + 0.03, y1 + 0.03, stage + 2.4), size: 0.8)
        weathervane(at: iso((x0 + x1) / 2, (y0 + y1) / 2, apex), height: 12)
    }

    /// The town hall being built: the ground storey raised in fresh brick on
    /// its plinth of stone, its window heads turned on timber centring; the
    /// tower's shaft half raised inside scaffolding flying the owner's
    /// pennant; a derrick crane lifting a load of bricks; and bricks, stone,
    /// timber and slates to hand on the court.
    private mutating func townHallRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hall
        let h0 = 3.0, f = Self.upperFloor - 4
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        let t1 = (Self.belfry.x1 - x0) * 32
        scaffold([(x0 + 0.1, y0 - 0.1), (-0.4, y0 - 0.1), (x1 - 0.1, y0 - 0.1)], from: h0, height: 28, levels: [11, 22])
        shadow([iso(x1, y0, h0), iso(x1 + 0.2, y0 + 0.12, h0), iso(x1 + 0.2, y1 + 0.08, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: f, thickness: 0.1, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.pavingShade)) { p in
            p.bricks(-0.95, -0.95, -0.65, -0.7, from: h0, height: 5)
            p.basket(at: p.iso(0.2, -0.6, h0), size: 0.9)
            p.timbers(-0.2, -1.0, length: 0.8, on: h0)
            p.derrick(0.3, -0.75, on: h0, height: 54, reach: 30, drop: 20)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 3), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, front, 3, f - h0, opacity: 0.4, burnt: false)
            for u in [7.5, 17.0, t1 + 7.0, t1 + 17.0] where u < front - 4 {
                p.arch(u, 4.5, width: 9, height: 13.5, .colour(I.rawStoneTop), line: 0.6)
                p.arch(u, 4.5, width: 6, height: 12, .colour(I.dark), line: 0.8)
            }
            // The timber centring still under the last head.
            let u = t1 + 17.0
            p.timber(p.uv(u - 3, 4.6), p.uv(u - 3, 13.5), width: 1, paint: I.timberLight)
            p.timber(p.uv(u + 3, 4.6), p.uv(u + 3, 13.5), width: 1, paint: I.timberLight)
            p.timber(p.uv(u - 3, 13.5), p.uv(u + 3, 13.5), width: 1, paint: I.timberLight)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 3), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, side, 3, f - h0, opacity: 0.4, burnt: false)
            p.arch(side / 2, 3, width: 11, height: 16, .colour(I.rawStoneTop), line: 0.6)
            p.arch(side / 2, 3, width: 8, height: 14.5, .colour(I.dark), line: 0.8)
            for u in [7.5, side - 7.5] { p.shape(p.panel(u - 3, 4.5, u + 3, 14), .colour(I.dark), width: 0.8) }
        }
        bricks(x0, y0, x0 + 0.12, y0 + 1.0, from: f, height: 3)
        // The tower's shaft, half raised inside its scaffold.
        let (bx0, by0, bx1, by1) = Self.belfry
        let shaft = 38.0
        scaffold([(bx0 - 0.12, by0 + 0.02), (bx1 + 0.12, by0 + 0.02)], from: h0, height: 50, levels: [14, 28, 42])
        block(bx0, by0, bx1, by1, h0, shaft, top: .colour(I.brickTop), left: .colour(I.rawBrick), right: .colour(I.rawBrickShade))
        for side in [IndustrialOldBuildingsSide.left, .right] {
            let length = side == .left ? (bx1 - bx0) * 32 : (by1 - by0) * 32
            wall(side, from: side == .left ? bx0 : bx1, by1, at: h0) { p in
                p.shape(p.panel(0, 0, length, 3), .colour(I.rawStone), width: 0.6)
                p.brickwork(0, length, 3, shaft - h0, opacity: 0.4, burnt: false)
                p.quoins(at: 0, atStart: true, from: 3, to: shaft - h0, course: 3.6)
                p.quoins(at: length, atStart: false, from: 3, to: shaft - h0, course: 3.6)
                if side == .left {
                    p.arch(length / 2, 3, width: 8, height: 15, .colour(I.dark), line: 0.9)
                    p.shape(p.panel(length / 2 - 2.6, 27.5, length / 2 + 2.6, 34), .colour(I.dark), width: 0.8)
                }
            }
        }
        scaffold([(bx0 - 0.12, by1 + 0.12), (bx1 + 0.12, by1 + 0.12), (bx1 + 0.12, by0 + 0.02)], from: h0, height: 50,
                 levels: [14, 28, 42], boards: 28, inward: (0, -0.12))
        pennant(at: iso(bx1 + 0.12, by1 + 0.12, h0 + 50), height: 13, length: 15)
        // Materials on the court.
        timbers(0.5, 0.62, length: 0.8, on: h0)
        slates(0.62, 1.0, 0.98, 1.2, from: h0, height: 7)
        bricks(-1.32, 0.62, -1.0, 0.94, from: h0, height: 6)
        blocks(-1.32, 1.04, -1.12, 1.3, from: h0, courses: 1)
        barrel(at: iso(1.25, 0.6, h0), size: 0.9)
        sack(at: iso(-0.55, 1.3, h0), size: 0.9)
        pennant(at: iso(-1.36, 1.36, 3), height: 30, length: 15)
    }
}
