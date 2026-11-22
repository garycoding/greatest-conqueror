// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The cannon factory in the Industrial look: the Alchemy age's gun foundry
// rebuilt as an iron works of red brick. Its casting shop is one tall storey
// on a plinth of stone, lit along its length by round-headed windows between
// pilasters, under a gabled roof of slate with a louvred ventilator running
// along the ridge to let out the heat. Its gable end stands open on the
// yard: great doors under an arch of stone, the furnace glowing within. A
// square chimney of brick, banded in stone and capped in iron, rises behind
// the roof and smokes. The owner's colour runs in a band under the eaves,
// hangs as a banner over the shop's door and flies as a pennant at the
// corner of the yard. In the yard lie new guns of iron on timber skids, a
// pyramid of round shot, a cart of crates for the army, and a heap of coal
// for the furnace. Its footprint is three tiles square: x and y run from -1.5
// to 1.5.

extension IndustrialOldBuildingsPainter {
    mutating func gunWorks(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 2, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        if complete { castingShop() } else { castingShopRising() }
    }

    private static let shop = (x0: -1.36, y0: -1.36, x1: 0.9, y1: -0.12)
    private static let chimney = (x0: 0.36, y0: -1.32, x1: 0.64, y1: -1.04)
    private static let shopEaves = 34.0
    private static let chimneyTop = 80.0

    /// The shop's wall of brick drawn with `wall`, `length` long and `height`
    /// tall: a plinth of stone, the brickwork, and quoins at both corners.
    private mutating func shopWall(_ length: Double, _ height: Double, lit: Bool) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(0, 0, length, 3), .colour(lit ? I.footing : I.footingShade), width: 0.6)
        brickwork(0, length, 3, height)
        quoins(at: 0, atStart: true, from: 3, to: height, course: 3.4, reach: 3.6)
        quoins(at: length, atStart: false, from: 3, to: height, course: 3.4, reach: 3.6)
    }

    private mutating func castingShop() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.shop
        let h0 = 2.0, e = Self.shopEaves
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.shopWall(front, e - h0, lit: true)
            let mid = front / 2
            for u in [1.6, 13.6, 25.6, front - 25.6, front - 13.6, front - 1.6] { p.pilaster(u, 3, e - h0 - 4.6, w: 2.6) }
            for u in [7.6, 19.6, front - 19.6, front - 7.6] { p.archedWindow(u, 5.6, w: 5.6, h: 14) }
            p.door(mid, 3, w: 6.4, h: 10.4)
            p.paintedBand(0, front, 22.6, 24.2)
            p.banner(mid, top: 21.6, width: 8.4, length: 7.6)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shopWall(side, e - h0, lit: false)
            p.archedDoors(side / 2, 3, w: 17, h: 23, open: true)
            p.furnaceGlow(at: p.uv(side / 2, 3.6), width: 13, height: 15)
            p.paintedBand(0, side, 22.6 + 2, 24.2 + 2)
        }
        // The chimney behind the roof, then the roof, its ventilator, and the smoke.
        tallChimney(complete: true)
        let ym = (y0 + y1) / 2, ridge = e + 20
        gableAlongX(x0, y0, x1, y1, eave: e, ridge: ridge, over: 0.07, gableWall: .colour(I.brickShade)) { p, w, rise in
            p.gableBrickwork(w, rise)
            p.archedWindow(w / 2, rise * 0.18, w: 6, h: 8.4)
        }
        ventilator(from: -0.95, to: 0.2, at: ym, on: ridge)
        smoke(at: iso((Self.chimney.x0 + Self.chimney.x1) / 2, (Self.chimney.y0 + Self.chimney.y1) / 2, Self.chimneyTop + 4),
              puffs: 3, size: 0.85)
        // The yard: coal for the furnace, new guns on their skids, round shot, a cart, and the owner's pennant.
        heap(at: iso(1.2, 0.18, h0), width: 18, height: 8, paint: I.soot, shade: I.sootDark)
        heap(at: iso(1.3, 0.46, h0), width: 11, height: 5, paint: I.sootDark, shade: I.ironDark)
        beam(-1.24, 0.3, -1.24, 1.02, on: h0, size: 2.4)
        beam(-0.5, 0.3, -0.5, 1.02, on: h0, size: 2.4)
        for y in [0.44, 0.66, 0.88] {
            gunBarrel(from: iso(-1.36, y, h0 + 5.4), to: iso(-0.36, y, h0 + 5.4), radius: 2.8, metal: .iron)
        }
        shotPile(at: iso(0.06, 0.82, h0), rows: 4, radius: 1.7)
        cart(0.78, 0.98, on: h0, length: 0.5, load: .crates)
        pennant(at: iso(1.3, -1.28, h0), height: 46, length: 14)
    }

    /// The square chimney rising behind the shop's roof: brick banded in
    /// stone, under a flared cap of iron sooted at its mouth; begun, it is a
    /// stump of fresh brick.
    private mutating func tallChimney(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.chimney
        let h0 = complete ? Self.shopEaves - 6 : 2.0, h1 = complete ? Self.chimneyTop : 30.0
        let w = (x1 - x0) * 32, d = (y1 - y0) * 32
        block(x0, y0, x1, y1, h0, h1, top: complete ? nil : .colour(I.brickTop), left: .colour(complete ? I.brick : I.rawBrick),
              right: .colour(complete ? I.brickShade : I.rawBrickShade), width: 1)
        for (side, length) in [(IndustrialOldBuildingsSide.left, w), (.right, d)] {
            wall(side, from: side == .left ? x0 : x1, y1, at: h0) { p in
                p.brickwork(0, length, 0, h1 - h0, course: 2.2, brick: 4.6, burnt: complete)
                guard complete else { return }
                for v in [h1 - h0 - 22, h1 - h0 - 7] { p.stringCourse(0, length, v, v + 1.6) }
            }
        }
        guard complete else { return }
        let o = 0.04
        block(x0 - o, y0 - o, x1 + o, y1 + o, h1, h1 + 3, top: .colour(I.soot), left: .colour(I.iron), right: .colour(I.ironDark),
              width: 0.8)
        colour(level(x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, h1 + 3), .colour(I.dark))
        line(level(x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, h1 + 3), closed: true, width: 0.5)
    }

    /// A ventilator along the ridge at `y` on `h`, from `xa` to `xb`: a long
    /// low box of louvred board under its own gabled roof of slate.
    private mutating func ventilator(from xa: Double, to xb: Double, at y: Double, on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let s = 0.1, top = h + 5
        block(xa, y - s, xb, y + s, h - 2, top, top: nil, left: .colour(I.light), right: .colour(I.plasterShade), width: 0.8)
        wall(.left, from: xa, y + s, at: h - 2) { p in
            let length = (xb - xa) * 32
            for v in stride(from: 2.6, to: 6.6, by: 1.3) { p.line([p.uv(1, v), p.uv(length - 1, v)], width: 0.4) }
        }
        gableAlongX(xa, y - s, xb, y + s, eave: top, ridge: top + 4.5, over: 0.04, gableWall: .colour(I.plasterShade), finials: false)
    }

    /// The cannon factory being built: the shop's walls of fresh brick half
    /// raised round the opening of its great doors, the chimney's stump
    /// behind, scaffolding with the owner's pennant, a derrick lifting
    /// bricks, and bricks, timber and slates to hand.
    private mutating func castingShopRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.shop
        let h0 = 2.0, top = 15.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        tallChimney(complete: false)
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.1, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.earth)) { p in
            p.bricks(-1.0, -1.0, -0.7, -0.7, from: h0, height: 5)
            p.basket(at: p.iso(-0.3, -0.7, h0), size: 0.9)
            p.timbers(-0.1, -1.1, length: 0.7, on: h0)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 3), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, front, 3, top - h0, opacity: 0.4, burnt: false)
            p.shape(p.panel(front / 2 - 3.5, 3, front / 2 + 3.5, top - h0), .colour(I.dark), width: 0.8)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 3), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, side, 3, top - h0, opacity: 0.4, burnt: false)
            p.shape(p.panel(side / 2 - 8.5, 3, side / 2 + 8.5, top - h0), .colour(I.dark), width: 1)
        }
        scaffold([(x1 + 0.14, -0.14), (x1 + 0.14, -0.74), (x1 + 0.14, -1.34)], from: h0, height: 28, levels: [10, 20], boards: 10)
        pennant(at: iso(x1 + 0.14, -0.14, h0 + 28), height: 12, length: 13)
        derrick(-0.1, 0.62, on: h0, height: 34, reach: 22, drop: 12)
        ladder(foot: iso(-1.1, 0.3, h0), iso(-0.94, 0.3, h0), head: iso(-1.1, y1 + 0.02, top + 3), iso(-0.94, y1 + 0.02, top + 3),
               rungs: 5)
        bricks(0.5, 0.7, 0.8, 1.0, from: h0, height: 6)
        slates(0.95, 0.6, 1.2, 0.9, from: h0, height: 6)
        timbers(-1.2, 1.0, length: 0.8, on: h0)
        barrel(at: iso(1.2, 1.2, h0), size: 0.9)
    }
}
