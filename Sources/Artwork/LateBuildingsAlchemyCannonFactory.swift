// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The cannon factory in the Alchemy look: a gun foundry. Its casting hall
// has a ground storey of dressed sandstone, hung with heater shields of the
// owner's colour, and an upper storey half-timbered in oak with leaded
// windows over a band of the owner's colour, under a steep gabled roof of
// deep-teal slate with gilt finials. Its gable end of stone stands open on
// the yard under a great arch, the furnace glowing within, and a tall stack
// of stone, stepped in at a ledge and capped, rises behind the roof and
// smokes. A banner of the owner's colour hangs over the hall's door and the
// owner's pennant flies at the corner of the yard. In the yard lie new guns
// cast in bronze on timber skids, a pyramid of round shot, kegs of powder,
// and a heap of charcoal for the furnace. Its footprint is three tiles
// square: x and y run from -1.5 to 1.5; it stands where the Industrial
// look's iron works stands, so that the building keeps its shape from one
// age to the next.

extension AlchemyOldBuildingsPainter {
    mutating func gunFoundry(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 2, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        if complete { castingHall() } else { castingHallRising() }
    }

    private static let hall = (x0: -1.36, y0: -1.36, x1: 0.9, y1: -0.12)
    private static let stack = (x0: 0.34, y0: -1.34, x1: 0.66, y1: -1.02)
    private static let hallFloor = 20.0
    private static let hallEaves = 38.0
    private static let stackTop = 80.0

    /// The stone storey's wall drawn with `wall`, `length` long and `height`
    /// tall: a footing, coursed ashlar, and quoins at its corner.
    private mutating func hallStone(_ length: Double, _ height: Double, quoinAtStart: Bool, lit: Bool) {
        typealias I = AlchemyOldBuildingsInk
        colour(panel(0, 0, length, 3), .colour(lit ? I.footing : I.footingShade))
        line([uv(0, 3), uv(length, 3)], width: 0.6)
        courses(0, length, 3, height, course: 3.9, brick: 9.6)
        quoins(at: quoinAtStart ? 0 : length, atStart: quoinAtStart, from: 3, to: height, course: 3.9)
    }

    private mutating func castingHall() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hall
        let h0 = 2.0, f = Self.hallFloor, e = Self.hallEaves
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        let mid = front / 2
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        // The ground storey of stone, all round.
        block(x0, y0, x1, y1, h0, f, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.hallStone(front, f - h0, quoinAtStart: false, lit: true)
            p.door(mid, 0, w: 8, h: 14, paint: I.oakLight)
            for u in [8.0, 20.0, front - 20.0, front - 8.0] { p.casement(u - 3, 5, w: 6, h: 7, lights: 2, frame: I.stoneTop) }
            for u in [mid - 12.0, mid + 12.0] { p.shield(u, 10, w: 6, h: 7.4) }
        }
        // The upper storey of the hall's long side, half-timbered.
        block(x0, y0, x1, y1, f, e, top: nil, left: .colour(I.light), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: f) { p in
            let posts = stride(from: 1.0, through: front - 1, by: (front - 2) / 8).map { $0 }
            p.framing(front, from: 0, to: e - f, posts: posts, rail: 6, braces: [(0, true), (3, false), (4, true), (7, false)])
            for k in [1, 6] { p.casement(posts[k] + 1.6, 6.6, w: posts[k + 1] - posts[k] - 3.2, h: 6.4, lights: 2) }
            p.paintedBand(0, front, 0.6, 2.6)
        }
        // The gable end of stone, open on the yard under its arch, the furnace within.
        wall(.right, from: x1, y1, at: h0) { p in
            p.hallStone(side, e - h0, quoinAtStart: true, lit: false)
            p.arch(side / 2, 0, width: 20, height: 25, .colour(I.stoneTop), line: 0.8)
            p.arch(side / 2, 0, width: 16.4, height: 23, .colour(I.dark), line: 1)
            p.furnaceGlow(at: p.uv(side / 2, 1.2), width: 12, height: 15)
            for u in [side / 2 - 6.6, side / 2 + 6.6] { p.line([p.uv(u, 0), p.uv(u, 14)], width: 0.4, opacity: 0.5) }
        }
        shadow([iso(x0, y1, e - 2.2), iso(x1, y1, e - 2.2), iso(x1, y1, e), iso(x0, y1, e)], opacity: 0.12)
        stoneStack(complete: true)
        let ridge = e + 22
        gableAlongX(x0, y0, x1, y1, eave: e, ridge: ridge, over: 0.07, gableWall: .colour(I.stoneShade)) { p, w, rise in
            p.casement(w / 2 - 3.4, rise * 0.16, w: 6.8, h: 7, lights: 2, frame: I.stoneTop)
        }
        wall(.left, from: x0, y1 + 0.01, at: h0) { p in p.banner(mid, top: f + 10, width: 10, length: 13) }
        smoke(at: iso((Self.stack.x0 + Self.stack.x1) / 2, (Self.stack.y0 + Self.stack.y1) / 2, Self.stackTop + 4), puffs: 3,
              size: 0.85)
        // The yard: charcoal for the furnace, new guns of bronze on their skids, shot, powder and the owner's pennant.
        heap(at: iso(1.2, 0.18, h0), width: 18, height: 8, paint: I.ironDark, shade: I.dark)
        beam(-1.24, 0.3, -1.24, 1.02, on: h0, size: 2.4)
        beam(-0.5, 0.3, -0.5, 1.02, on: h0, size: 2.4)
        for y in [0.44, 0.66, 0.88] {
            gunBarrel(from: iso(-1.36, y, h0 + 5.4), to: iso(-0.36, y, h0 + 5.4), radius: 2.8, metal: .bronze)
        }
        shotPile(at: iso(0.06, 0.82, h0), rows: 4, radius: 1.7)
        for (x, y) in [(0.62, 0.86), (0.84, 0.92), (0.72, 1.12)] { barrel(at: iso(x, y, h0), size: 0.85) }
        pennant(at: iso(1.3, -1.28, h0), height: 46, length: 14)
    }

    /// The furnace's stack behind the hall's roof: coursed stone stepped in at
    /// a ledge, under a cap of stone sooted at its mouth; begun, it is a stump
    /// of fresh stone.
    private mutating func stoneStack(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.stack
        if !complete {
            block(x0, y0, x1, y1, 2, 28, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade),
                  width: 1)
            for (side, length) in [(AlchemyOldBuildingsSide.left, (x1 - x0) * 32), (.right, (y1 - y0) * 32)] {
                wall(side, from: side == .left ? x0 : x1, y1, at: 2) { p in p.courses(0, length, 0, 26, course: 3.9, brick: 6) }
            }
            return
        }
        let ledge = 60.0, top = Self.stackTop, inset = 0.05
        let tiers: [(Double, Double, Double)] = [(Self.hallEaves - 6, ledge, 0), (ledge + 2, top, inset)]
        for (h0, h1, i) in tiers {
            let (a0, b0, a1, b1) = (x0 + i, y0 + i, x1 - i, y1 - i)
            block(a0, b0, a1, b1, h0, h1, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade), width: 1)
            for (side, length) in [(AlchemyOldBuildingsSide.left, (a1 - a0) * 32), (.right, (b1 - b0) * 32)] {
                wall(side, from: side == .left ? a0 : a1, b1, at: h0) { p in p.courses(0, length, 0, h1 - h0, course: 3.9, brick: 6) }
            }
            if i == 0 {
                // The ledge where the stack steps in, weathered to shed the rain.
                block(a0 - 0.02, b0 - 0.02, a1 + 0.02, b1 + 0.02, h1, h1 + 2, top: .colour(I.stoneTop), left: .colour(I.stoneTop),
                      right: .colour(I.stone), width: 0.7)
            }
        }
        let o = 0.025
        block(x0 + inset - o, y0 + inset - o, x1 - inset + o, y1 - inset + o, top, top + 3, top: .colour(I.footing),
              left: .colour(I.stoneTop), right: .colour(I.stone), width: 0.8)
        let mouth = level(x0 + inset + 0.03, y0 + inset + 0.03, x1 - inset - 0.03, y1 - inset - 0.03, top + 3)
        colour(mouth, .colour(I.dark))
        line(mouth, closed: true, width: 0.5)
    }

    /// The cannon factory being built: the hall's stone walls half raised
    /// round the openings of its door and its arch, the stack's stump behind,
    /// scaffolding with the owner's pennant, a treadwheel crane lifting
    /// stone, and stone, timber and slates to hand.
    private mutating func castingHallRising() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.hall
        let h0 = 2.0, top = 15.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        stoneStack(complete: false)
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.1, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.earth)) { p in
            p.blocks(-1.0, -1.0, -0.7, -0.7, from: h0, courses: 2)
            p.basket(at: p.iso(-0.3, -0.7, h0), size: 0.9)
            p.timbers(-0.1, -1.1, length: 0.7, on: h0)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, front, 0, top - h0, course: 3.9, brick: 9.6)
            p.shape(p.panel(front / 2 - 4, 0, front / 2 + 4, top - h0), .colour(I.dark), width: 0.8)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.courses(0, side, 0, top - h0, course: 3.9, brick: 9.6)
            p.shape(p.panel(side / 2 - 8.2, 0, side / 2 + 8.2, top - h0), .colour(I.dark), width: 1)
        }
        blocks(x0, y0, x0 + 0.1, y0 + 0.8, from: top, courses: 1)
        scaffold([(x1 + 0.14, -0.14), (x1 + 0.14, -0.74), (x1 + 0.14, -1.34)], from: h0, height: 28, levels: [10, 20], boards: 10)
        pennant(at: iso(x1 + 0.14, -0.14, h0 + 28), height: 12, length: 13)
        treadwheel(-0.1, 0.62, on: h0, height: 34, reach: 22, drop: 12)
        ladder(foot: iso(-1.1, 0.3, h0), iso(-0.94, 0.3, h0), head: iso(-1.1, y1 + 0.02, top + 3), iso(-0.94, y1 + 0.02, top + 3),
               rungs: 5)
        blocks(0.5, 0.7, 0.8, 1.0, from: h0, courses: 2)
        slates(0.95, 0.6, 1.2, 0.9, from: h0, height: 6)
        timbers(-1.2, 1.0, length: 0.8, on: h0)
        barrel(at: iso(1.2, 1.2, h0), size: 0.9)
    }
}
