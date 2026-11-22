// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age house: the Alchemy age's town house rebuilt as a villa
// of red brick, two storeys on a plinth of stone. Its gable faces the street
// under a roof of blue-grey slate, edged with a bargeboard painted the light
// colour and an iron finial; a square bay window stands out from the ground
// floor beside a panelled door under a fanlight; sash windows under arches of
// brick light both floors; a string course of stone carries a band of the
// owner's colour; and a chimney stack of brick with pots of clay rises
// through the roof. Iron railings front the yard, where barrels and a bench
// stand. Its footprint is two tiles square: x and y run from -1 to 1.

extension IndustrialOldBuildingsPainter {
    mutating func house(complete: Bool) {
        cobbles(1, height: 2)
        if complete { villa() } else { villaRising() }
    }

    private static let ground = (x0: -0.78, y0: -0.86, x1: 0.42, y1: 0.3)
    private static let floor = 17.0
    private static let eaves = 33.0

    /// A wall of brick drawn with `wall`, `length` long and `height` tall: a
    /// plinth of stone, the brickwork, quoins at its corners, and the string
    /// course with the owner's band at the first floor.
    private mutating func villaWall(_ length: Double, _ height: Double, floor f: Double, lit: Bool) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(0, 0, length, 2.6), .colour(lit ? I.footing : I.footingShade), width: 0.6)
        brickwork(0, length, 2.6, height)
        quoins(at: 0, atStart: true, from: 2.6, to: height, course: 3.2, reach: 3.6)
        quoins(at: length, atStart: false, from: 2.6, to: height, course: 3.2, reach: 3.6)
        stringCourse(0, length, f - 1.2, f + 0.4)
        paintedBand(0, length, f + 1.3, f + 2.9)
    }

    private mutating func villa() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.ground
        let h0 = 2.0, f = Self.floor, e = Self.eaves
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        // Railings along the front of the yard, behind the house's foot on the right.
        railing(x1 + 0.12, y0 + 0.06, x1 + 0.12, y1 + 0.5, on: h0, height: 7)
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.villaWall(front, e - h0, floor: f - h0, lit: true)
            p.door(29, 2.6, w: 7, h: 12.4)
            p.casement(4, f - h0 + 5, w: 6, h: 8.6, lights: 1, frame: I.brick)
            p.casement(14.4, f - h0 + 5, w: 6, h: 8.6, lights: 1, frame: I.brick)
            p.casement(26.4, f - h0 + 5, w: 5.2, h: 8.6, lights: 1, frame: I.brick)
            p.drainpipe(front - 1.6, from: e - h0)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.villaWall(side, e - h0, floor: f - h0, lit: false)
            p.casement(8, 4.6, w: 7.4, h: 8.6, lights: 2, frame: I.brick)
            p.casement(23, 4.6, w: 5.6, h: 8.6, lights: 1, frame: I.brick)
            p.casement(8, f - h0 + 5, w: 7.4, h: 8.6, lights: 2, frame: I.brick)
            p.casement(23, f - h0 + 5, w: 5.6, h: 8.6, lights: 1, frame: I.brick)
        }
        bayWindow(x0 + 0.08, x0 + 0.56, y1, depth: 0.12, from: h0, to: f - 2)
        // The roof, its gable to the street, with a bargeboard painted the light colour.
        let ridge = e + 24
        gableAlongY(x0, y0, x1, y1, eave: e, ridge: ridge, over: 0.06, gableWall: .colour(I.brick)) { p, w, rise in
            p.gableBrickwork(w, rise)
            p.archedWindow(w / 2, rise * 0.22, w: 5, h: 9)
            p.shape([p.uv(w / 2 - 1.4, rise - 6), p.uv(w / 2, rise - 3.6), p.uv(w / 2 + 1.4, rise - 6), p.uv(w / 2, rise - 8.4)],
                    .colour(I.stoneTop), width: 0.45)
        }
        // The stack of brick rising through the roof's right slope, with three pots.
        let (cx0, cy0, cx1, cy1) = (0.1, -0.62, 0.3, -0.42)
        let foot = e + (ridge - e) * ((x1 + 0.06) - (cx0 + cx1) / 2) / ((x1 + 0.06) - (x0 + x1) / 2) - 2
        chimneyStack(cx0, cy0, cx1, cy1, from: foot, to: ridge + 4, pots: 2)
        // Barrels, a bench and a lamp in the yard.
        barrel(at: iso(-0.88, 0.62, h0), size: 0.85)
        barrel(at: iso(-0.66, 0.8, h0), size: 0.8)
        bench(at: (0.12, 0.66), on: h0)
        gasLamp(at: iso(0.74, 0.74, h0), height: 22)
    }

    /// A square bay window standing out `depth` tiles from the front wall at
    /// `y`, from `xa` to `xb`, from `h0` to `h1`: sashes on its three faces
    /// between brick piers, under a cornice and a roof of lead.
    private mutating func bayWindow(_ xa: Double, _ xb: Double, _ y: Double, depth: Double, from h0: Double, to h1: Double) {
        typealias I = IndustrialOldBuildingsInk
        let y2 = y + depth
        block(xa, y, xb, y2, h0, h1, top: nil, left: .colour(I.brick), right: .colour(I.brickShade), width: 1)
        let w = (xb - xa) * 32, d = depth * 32
        wall(.left, from: xa, y2, at: h0) { p in
            p.shape(p.panel(0, 0, w, 2.6), .colour(I.footing), width: 0.5)
            p.brickwork(0, w, 2.6, h1 - h0, burnt: false)
            p.casement(2, 4.2, w: w - 4, h: 8.6, lights: 2)
        }
        wall(.right, from: xb, y2, at: h0) { p in
            p.shape(p.panel(0, 0, d, 2.6), .colour(I.footingShade), width: 0.5)
            p.casement(0.9, 4.2, w: d - 1.8, h: 8.6, lights: 1)
        }
        block(xa - 0.02, y - 0.01, xb + 0.02, y2 + 0.02, h1, h1 + 1.6, top: .colour(I.stoneTop), left: .colour(I.stoneTop),
              right: .colour(I.stone), width: 0.7)
        let top = [iso(xa - 0.02, y, h1 + 1.6), iso(xb + 0.02, y, h1 + 1.6), iso(xb + 0.02, y2 + 0.02, h1 + 1.6),
                   iso(xa - 0.02, y2 + 0.02, h1 + 1.6)]
        let back = [iso(xa - 0.02, y, h1 + 4.6), iso(xb + 0.02, y, h1 + 4.6)]
        shape([top[3], top[2], back[1], back[0]], .colour(I.slateLight), width: 0.7)
        shape([top[2], top[1], back[1]], .colour(I.slateShade), width: 0.6)
    }

    /// A bench of oak standing along x at (x, y) on `h`.
    private mutating func bench(at place: (Double, Double), on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let (x, y) = place
        for dx in [-0.16, 0.16] { pole(iso(x + dx, y, h), iso(x + dx, y, h + 4), width: 1.1, colour: I.oak) }
        block(x - 0.22, y - 0.05, x + 0.22, y + 0.05, h + 4, h + 5.4, top: .colour(I.timberLight), left: .colour(I.timber),
              right: .colour(I.timberDark), width: 0.7)
    }

    /// The house being built: its ground storey raised in fresh brick on its
    /// plinth, the openings of the door, the bay and the windows left, the
    /// timber of the first floor's joists laid across it; scaffolding with the
    /// owner's pennant; a ladder; and bricks, slates and mortar to hand.
    private mutating func villaRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.ground
        let h0 = 2.0, f = Self.floor + 4
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        slates(-0.96, -0.96, -0.82, -0.6, from: h0, height: 6)
        shadow([iso(x1, y0, h0), iso(x1 + 0.18, y0 + 0.1, h0), iso(x1 + 0.18, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: f, thickness: 0.07, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.pavingShade)) { p in
            p.basket(at: p.iso(-0.3, -0.4, h0), size: 0.9)
            p.bricks(0.0, -0.7, 0.24, -0.5, from: h0, height: 5)
            // The joists of the first floor, laid across from wall to wall.
            for k in 0..<6 {
                let x = x0 + 0.12 + Double(k) * 0.2
                p.pole(p.iso(x, y0 + 0.05, f - 2), p.iso(x, y1 - 0.05, f - 2), width: 1.6, colour: I.timberLight)
            }
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 2.6), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, front, 2.6, f - h0, opacity: 0.4, burnt: false)
            p.arch(29, 2.6, width: 7, height: 12.4, .colour(I.dark), line: 0.9)
            p.shape(p.panel(3, 2.6, 18, 14), .colour(I.dark), width: 0.9)
            p.timber(p.uv(2.4, 14.4), p.uv(18.6, 14.4), width: 1.4, paint: I.timberLight)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 2.6), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, side, 2.6, f - h0, opacity: 0.4, burnt: false)
            p.shape(p.panel(8, 4.6, 15.4, 13.2), .colour(I.dark), width: 0.8)
            p.shape(p.panel(23, 4.6, 28.6, 13.2), .colour(I.dark), width: 0.8)
        }
        scaffold([(x1 + 0.18, 0.26), (x1 + 0.18, -0.3), (x1 + 0.18, -0.8)], from: h0, height: 34, levels: [13, 26], boards: 13)
        pennant(at: iso(x1 + 0.18, 0.26, h0 + 34), height: 11, length: 13)
        ladder(foot: iso(-0.62, y1 + 0.32, h0), iso(-0.46, y1 + 0.32, h0), head: iso(-0.62, y1 + 0.02, f + 3),
               iso(-0.46, y1 + 0.02, f + 3), rungs: 5)
        timbers(-0.3, 0.5, length: 0.66, on: h0)
        bricks(0.62, 0.55, 0.9, 0.86, from: h0, height: 6)
        slates(0.72, -0.5, 0.88, -0.16, from: h0, height: 6)
        basket(at: iso(0.66, 0.3, h0), size: 0.9)
    }
}
