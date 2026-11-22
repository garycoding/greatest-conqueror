// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age storage pit: the Alchemy age's cellar and crane rebuilt
// as a warehouse of red brick, two storeys and a loft under a gabled roof of slate.
// Its gable faces the street, with a loading door to each floor and the
// loft stacked one over another under the cathead, a beam of timber and iron at the apex from
// which a sack hangs on its chain; a painted board of the owner's colour runs
// across the gable under the cathead. Its side has small windows under brick
// arches, iron shutters and tie-plates, and wide doors at the ground. A cart
// with crates, barrels and sacks wait on the paved yard. Its footprint is two
// tiles square: x and y run from -1 to 1.

extension IndustrialOldBuildingsPainter {
    mutating func storagePit(complete: Bool) {
        cobbles(1, height: 1.5)
        if complete { warehouse() } else { warehouseRising() }
    }

    private static let store = (x0: -0.86, y0: -0.86, x1: 0.42, y1: 0.36)
    private static let storeEaves = 25.0
    private static let storeRidge = 41.0

    /// A loading door of planks painted bottle green on a wall drawn with `wall`,
    /// centred on `u` and standing on `v`, `w` wide and `h` tall, under a
    /// lintel of stone, open at the top storey to show the dark within.
    private mutating func loadingDoor(_ u: Double, _ v: Double, w: Double, h: Double, open: Bool = false) {
        typealias I = IndustrialOldBuildingsInk
        colour(panel(u - w / 2 - 0.8, v - 0.2, u + w / 2 + 0.8, v + h + 0.2), .colour(I.dark), opacity: 0.6)
        if open {
            shape(panel(u - w / 2, v, u + w / 2, v + h), .colour(I.dark), width: 0.8)
            // One leaf swung back against the wall.
            shape(panel(u + w / 2 + 0.6, v, u + w / 2 + 3.4, v + h), .colour(I.green), width: 0.6)
        } else {
            shape(panel(u - w / 2, v, u + w / 2, v + h), .colour(I.green), width: 0.8)
            var planks = PathData()
            var x = u - w / 2 + 1.4
            while x < u + w / 2 - 0.4 { planks.move(uv(x, v + 0.3)); planks.line(uv(x, v + h - 0.3)); x += 1.4 }
            svg.path(planks, stroke: .colour(I.line), width: 0.35, opacity: 0.5)
            line([uv(u - w / 2 + 0.4, v + 0.4), uv(u + w / 2 - 0.4, v + h - 0.4)], width: 0.6)
            line([uv(u, v), uv(u, v + h)], width: 0.6)
        }
        shape(panel(u - w / 2 - 1.2, v + h + 0.2, u + w / 2 + 1.2, v + h + 1.8), .colour(I.stoneTop), width: 0.5)
        shape(panel(u - w / 2 - 0.8, v - 1.1, u + w / 2 + 0.8, v), .colour(I.stoneTop), width: 0.45)
    }

    /// A small window under a brick arch, with an iron shutter folded back,
    /// on a wall drawn with `wall`.
    private mutating func storeWindow(_ u: Double, _ v: Double) {
        typealias I = IndustrialOldBuildingsInk
        casement(u, v, w: 4.4, h: 6, lights: 1, frame: I.brick)
        shape(panel(u + 5.4, v - 0.2, u + 7.6, v + 6.2), .colour(I.iron), width: 0.5)
        for vv in [v + 1.4, v + 4.6] { svg.circle(uv(u + 6.5, vv), 0.35, fill: .colour(I.ironDark)) }
    }

    /// A round tie-plate of iron on a wall drawn with `wall`, at (u, v).
    private mutating func tiePlate(_ u: Double, _ v: Double) {
        typealias I = IndustrialOldBuildingsInk
        svg.circle(uv(u, v), 1.3, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.45)
        svg.circle(uv(u, v), 0.4, fill: .colour(I.ironLight))
    }

    private mutating func warehouse() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.store
        let h0 = 1.5, e = Self.storeEaves, ridge = Self.storeRidge
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        let storey = (e - h0 - 2) / 2
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 2), .colour(I.footing), width: 0.6)
            p.brickwork(0, front, 2, e - h0)
            p.stringCourse(0, front, 2 + storey - 0.6, 2 + storey + 0.4)
            // The stack of loading doors up the middle of the gable.
            p.loadingDoor(front / 2, 2, w: 8, h: storey - 2.4)
            p.loadingDoor(front / 2, 2 + storey + 0.6, w: 6.4, h: storey - 3)
            for k in 0..<2 {
                let v = 2 + storey * Double(k) + 2.4
                p.storeWindow(4, v)
                p.storeWindow(front - 11.6, v)
            }
            p.drainpipe(1.6, from: e - h0)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 2), .colour(I.footingShade), width: 0.6)
            p.brickwork(0, side, 2, e - h0)
            p.stringCourse(0, side, 2 + storey - 0.6, 2 + storey + 0.4)
            p.paintedBand(14, side, e - h0 - 2.6, e - h0 - 1.2)
            p.archedDoors(12, 2, w: 12, h: storey + 1.6)
            for u in [24.0, 32.0] { p.storeWindow(u, 4.4) }
            for u in [5.0, 15.0, 25.0] { p.storeWindow(u, 2 + storey + 2.4) }
            for u in [2.4, side - 2.4] { p.tiePlate(u, 2 + storey - 2) }
        }
        gableAlongY(x0, y0, x1, y1, eave: e, ridge: ridge, over: 0.05, gableWall: .colour(I.brick), finials: false) { p, w, rise in
            p.gableBrickwork(w, rise)
            // The painted board of the owner's colour across the gable.
            p.colour(p.panel(w / 2 - 12.5, 0.8, w / 2 + 12.5, 4.6), .colour(I.light))
            p.colour(p.panel(w / 2 - 11.5, 1.6, w / 2 + 11.5, 3.8), .team)
            p.line(p.panel(w / 2 - 12.5, 0.8, w / 2 + 12.5, 4.6), closed: true, width: 0.6)
            p.line(p.panel(w / 2 - 11.5, 1.6, w / 2 + 11.5, 3.8), closed: true, width: 0.45)
            p.cog(at: p.uv(w / 2, 2.7), radius: 0.8)
            // The loft's loading door, open, under the cathead.
            p.loadingDoor(w / 2, 6.2, w: 5.6, h: 6.4, open: true)
        }
        // The cathead: a beam at the apex, braced, with a pulley and a sack on its chain.
        let xm = (x0 + x1) / 2
        let c = e + 14.6
        let tip = iso(xm, y1 + 0.36, c)
        shape([iso(xm - 0.04, y1 + 0.05, c + 1.6), iso(xm + 0.04, y1 + 0.05, c + 1.6), iso(xm + 0.04, y1 + 0.36, c + 1.6),
               iso(xm + 0.04, y1 + 0.36, c - 0.8), iso(xm - 0.04, y1 + 0.36, c - 0.8), iso(xm - 0.04, y1 + 0.05, c - 0.8)],
              .colour(I.timber), width: 0.7)
        line([iso(xm, y1 + 0.05, c - 7), iso(xm, y1 + 0.26, c - 0.8)], width: 1.2)
        svg.circle(tip + P(0, 1.6), 1.6, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        let hook = tip + P(0, 20)
        line([tip + P(0, 1.6), hook], width: 0.7)
        line([hook, hook + P(-2, 2)], width: 0.5)
        line([hook, hook + P(2, 2)], width: 0.5)
        sack(at: hook + P(0, 11), size: 0.9)
        // The yard: a cart of crates, barrels, sacks, and the owner's pennant.
        cart(0.72, -0.48, on: h0, length: 0.46, load: .crates)
        barrel(at: iso(0.66, 0.62, h0), size: 0.8)
        barrel(at: iso(0.84, 0.8, h0), size: 0.8)
        crate(-0.3, 0.62, -0.04, 0.88, from: h0, height: 6)
        pennant(at: iso(-0.9, 0.9, h0), height: 34, length: 13)
    }

    /// The warehouse being built: its walls of fresh brick raised a storey
    /// and more, the openings of its doors left, scaffolding up its gable
    /// with the owner's pennant, a derrick crane lifting bricks, and bricks,
    /// timber and slates waiting in the yard.
    private mutating func warehouseRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.store
        let h0 = 1.5, top = 17.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        derrick(-0.6, -0.95, on: h0, height: 28, reach: -20, drop: 8)
        shadow([iso(x1, y0, h0), iso(x1 + 0.18, y0 + 0.1, h0), iso(x1 + 0.18, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.07, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.pavingShade)) { p in
            p.bricks(-0.6, -0.6, -0.3, -0.36, from: h0, height: 5)
            p.basket(at: p.iso(0.0, -0.5, h0), size: 0.9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 2), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, front, 2, top - h0, opacity: 0.4, burnt: false)
            p.shape(p.panel(front / 2 - 4, 2, front / 2 + 4, 10.6), .colour(I.dark), width: 0.9)
            p.timber(p.uv(front / 2 - 5, 11.4), p.uv(front / 2 + 5, 11.4), width: 1.6, paint: I.stoneTop)
            for u in [4.0, front - 11.6] { p.shape(p.panel(u, 4.4, u + 4.4, 10.4), .colour(I.dark), width: 0.7) }
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 2), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, side, 2, top - h0, opacity: 0.4, burnt: false)
            p.arch(12, 2, width: 12, height: 13.6, .colour(I.dark), line: 0.9)
        }
        scaffold([(x0 + 0.05, y1 + 0.16), (-0.22, y1 + 0.16), (x1 - 0.05, y1 + 0.16)], from: h0, height: 30, levels: [12, 24],
                 boards: 12, inward: (0, -0.16))
        pennant(at: iso(x1 - 0.05, y1 + 0.16, h0 + 30), height: 11, length: 13)
        bricks(0.6, 0.55, 0.9, 0.86, from: h0, height: 6)
        bricks(0.62, -0.2, 0.9, 0.08, from: h0, height: 4)
        timbers(-0.9, 0.62, length: 0.5, on: h0)
        slates(0.66, -0.8, 0.84, -0.46, from: h0, height: 6)
    }
}
