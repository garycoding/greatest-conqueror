// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age barracks: the Bronze age's hall rebuilt in dressed stone under
// a hipped roof of red tile, entered by an arched gateway with doors studded
// with iron between two towers, each under a pyramid of tile. The legion's
// oblong shields in the owner's colour hang along its wall, and the owner's
// standard stands over a yard with a rack of iron-headed spears and a post to
// practise on. Its footprint is three tiles square: x
// and y run from -1.5 to 1.5.

extension IronOldBuildingsPainter {
    mutating func barracks(complete: Bool) {
        typealias I = IronOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 2, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        if complete { hall() } else { hallRising() }
    }

    private static let hallBox = (x0: -1.38, y0: -1.38, x1: 1.02, y1: 0.12)
    private static let towers: [(x0: Double, x1: Double)] = [(-0.64, -0.36), (0.14, 0.42)]
    private static let towerFront = 0.28

    private mutating func hall() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hallBox
        let h0 = 2.0, h1 = 30.0
        let leftLength = (x1 - x0) * 32, rightLength = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.28, y0 + 0.16, h0), iso(x1 + 0.28, y1 + 0.1, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, h1, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.stoneWall(leftLength, h1 - h0)
            // The gateway between the towers, its doors of timber studded with iron.
            let g0 = (Self.towers[0].x1 - x0) * 32, g1 = (Self.towers[1].x0 - x0) * 32
            p.archedDoor((g0 + g1) / 2, 0, w: g1 - g0 - 4.4, h: 19, paint: I.timber)
            for u in [6.6, 15.4] { p.scutum(u, 13, w: 6, h: 10) }
            for u in [leftLength - 22, leftLength - 13.2, leftLength - 4.4] { p.scutum(u, 13, w: 6, h: 10) }
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.stoneWall(rightLength, h1 - h0)
            for u in stride(from: 6.0, to: rightLength - 6, by: 12) { p.grille(u, 12, w: 5, h: 7) }
        }
        shadow([iso(x0, y1, h1 - 2.2), iso(x1, y1, h1 - 2.2), iso(x1, y1, h1), iso(x0, y1, h1)], opacity: 0.12)
        shadow([iso(x1, y1, h1 - 2.2), iso(x1, y0, h1 - 2.2), iso(x1, y0, h1), iso(x1, y1, h1)], opacity: 0.12)
        hippedRoof(x0, y0, x1, y1, eaves: h1, overhang: 0.07)
        // The towers either side of the gateway, standing out from the wall.
        for tower in Self.towers { gateTower(tower.x0, y1, tower.x1, Self.towerFront, from: h0) }
        rackOfSpears(-1.12, 0.92)
        practicePost(at: iso(0.66, 1.0, h0))
        vexillum(at: iso(1.2, 0.78, h0), height: 56, width: 14, length: 17)
    }

    /// A wall of dressed stone drawn with `wall`, `length` points long and
    /// `height` tall: its courses, a plinth, and a band of the owner's colour
    /// under the eaves.
    private mutating func stoneWall(_ length: Double, _ height: Double) {
        typealias I = IronOldBuildingsInk
        colour(panel(0, 0, length, 3), .colour(I.footing))
        line([uv(0, 3), uv(length, 3)], width: 0.6)
        courses(0, length, 3, height - 6.4)
        paintedBand(0, length, height - 5.4, height - 3.4)
    }

    /// A tower from (x0, y0) to (x1, y1) on the map, standing out from the
    /// hall's wall, under a pyramid of tile.
    private mutating func gateTower(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double) {
        typealias I = IronOldBuildingsInk
        let h1 = 40.0
        block(x0, y0, x1, y1, h0, h1, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade), width: 1.1)
        wall(.left, from: x0, y1, at: h0) { p in
            let w = (x1 - x0) * 32
            p.colour(p.panel(0, 0, w, 3), .colour(I.footing))
            p.line([p.uv(0, 3), p.uv(w, 3)], width: 0.6)
            p.courses(0, w, 3, h1 - h0 - 2)
            p.shape(p.panel(w / 2 - 0.9, 22, w / 2 + 0.9, 29), .colour(I.dark), width: 0.7)
            p.shape(p.panel(-0.3, h1 - h0 - 2, w + 0.3, h1 - h0), .colour(I.stoneTop), width: 0.6)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            let w = (y1 - y0) * 32
            p.colour(p.panel(0, 0, w, 3), .colour(I.footingShade))
            p.line([p.uv(0, 3), p.uv(w, 3)], width: 0.6)
            p.courses(0, w, 3, h1 - h0 - 2)
            p.shape(p.panel(-0.3, h1 - h0 - 2, w + 0.3, h1 - h0), .colour(I.stone), width: 0.6)
        }
        hippedRoof(x0, y0, x1, y1, eaves: h1, rise: 10, overhang: 0.04)
    }

    /// A rack of spears with iron heads, its foot at (x, y), along x.
    private mutating func rackOfSpears(_ x: Double, _ y: Double) {
        typealias I = IronOldBuildingsInk
        let h0 = 2.0, length = 0.5
        pole(iso(x, y, h0), iso(x, y, h0 + 12), width: 1.3)
        // The spears stand nearly upright behind the bar, their heads above it.
        for i in 0..<5 {
            let along = x + length * (0.12 + Double(i) * 0.19)
            let foot = iso(along, y - 0.06, h0), head = iso(along + 0.015, y - 0.1, h0 + 27)
            svg.line([foot, head], stroke: .colour(I.line), width: 1.5)
            svg.line([foot, head], stroke: .colour(I.timberLight), width: 0.7)
            shape([head, head + P(1.1, 3.4), head + P(0, 6.4), head + P(-1.1, 3.4)], .colour(I.ironLight), width: 0.6)
        }
        pole(iso(x + length, y, h0), iso(x + length, y, h0 + 12), width: 1.3)
        pole(iso(x - 0.04, y, h0 + 10), iso(x + length + 0.04, y, h0 + 10), width: 1.2)
    }

    /// A post with a crosspiece, bound with straw, for practice with the spear.
    private mutating func practicePost(at p: P) {
        typealias I = IronOldBuildingsInk
        svg.ellipse(p + P(0, 0.4), 5, 1.6, fill: .colour("#000000"), opacity: 0.14)
        pole(p, p - P(0, 22), width: 1.6)
        pole(p - P(5.6, 16.6), p - P(-5.6, 16.6), width: 1.2)
        let body = [p - P(3.6, 21), p - P(-3.6, 21), p - P(-2.8, 8), p - P(2.8, 8)]
        shape(body, .colour(I.reed), width: 0.8)
        line([p - P(3.2, 16.4), p - P(-3.2, 16.4)], width: 0.6)
        line([p - P(3, 12.2), p - P(-3, 12.2)], width: 0.6)
        svg.circle(p - P(0, 24.4), 3, fill: .colour(I.reed), stroke: .colour(I.line), width: 0.8)
    }

    /// The barracks being built: the hall's walls of fresh stone half raised,
    /// the towers begun, scaffolding along the hall, and stone, tile and timber to hand.
    private mutating func hallRising() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hallBox
        let h0 = 2.0, top = 16.0
        let leftLength = (x1 - x0) * 32, rightLength = (y1 - y0) * 32
        logs(-1.3, -0.4, -1.45, on: h0, radius: 1.5)
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.1, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.earth)) { p in
            p.blocks(-0.9, -0.9, -0.6, -0.6, from: h0, courses: 2)
            p.basket(at: p.iso(-0.2, -0.6, h0), size: 0.9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, leftLength, 0, top - h0)
            let g0 = (Self.towers[0].x1 - x0) * 32, g1 = (Self.towers[1].x0 - x0) * 32
            p.shape(p.panel(g0 + 0.5, 0, g1 - 0.5, top - h0), .colour(I.dark), width: 1)
        }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, rightLength, 0, top - h0) }
        blocks(x0, y0, x0 + 0.1, y0 + 0.9, from: top, courses: 1)
        blocks(x0 + 0.1, y0, 0.2, y0 + 0.1, from: top, courses: 1)
        for tower in Self.towers {
            block(tower.x0, y1, tower.x1, Self.towerFront, h0, 10, top: .colour(I.rawStoneTop), left: .colour(I.rawStone),
                  right: .colour(I.rawStoneShade), width: 1)
            wall(.left, from: tower.x0, Self.towerFront, at: h0) { p in p.courses(0, (tower.x1 - tower.x0) * 32, 0, 8) }
        }
        scaffold([(x1 + 0.14, 0.05), (x1 + 0.14, -0.6), (x1 + 0.14, -1.25)], from: h0, height: 28, levels: [10, 20], boards: 10)
        scaffold([(-1.3, 0.5), (-0.8, 0.5)], from: h0, height: 26, levels: [10, 20], boards: 10)
        pennant(at: iso(x1 + 0.14, 0.05, h0 + 28), height: 12)
        blocks(0.55, 0.62, 0.85, 0.92, from: h0, courses: 2)
        roofTiles(0.95, 0.75, 1.2, 1.05, from: h0, height: 6)
        logs(-0.2, 0.6, 1.2, on: h0, radius: 1.6)
        ladder(foot: iso(0.5, 0.5, h0), iso(0.68, 0.5, h0), head: iso(0.5, y1 + 0.02, top + 3), iso(0.68, y1 + 0.02, top + 3),
               rungs: 5)
    }
}
