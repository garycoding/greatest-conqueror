// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age barracks: the Alchemy age's garrison rebuilt as a
// drill hall of red brick. One tall storey on a plinth of stone holds the
// hall where the soldiers drill, lit by tall round-headed windows between
// pilasters, under a hipped roof of slate with iron cresting and a ventilator
// on its ridge. Its front is castellated in the manner of the age: an arched
// doorway with doors of bottle-green plank between two towers of brick with stone
// battlements and slits for rifles, a great banner of the owner's colour
// hung between them, and shields of the owner's colour along the wall. In
// the yard stand a rack of rifles, a target on its frame, and the owner's
// flag on an iron staff. Its footprint is three tiles square: x and y run
// from -1.5 to 1.5.

extension IndustrialOldBuildingsPainter {
    mutating func barracks(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 2, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        if complete { garrison() } else { garrisonRising() }
    }

    private static let garrisonBox = (x0: -1.38, y0: -1.38, x1: 1.02, y1: 0.12)
    private static let gateTowers: [(x0: Double, x1: Double)] = [(-0.68, -0.36), (0.14, 0.46)]
    private static let gateTowerFront = 0.4

    /// The hall's wall of brick drawn with `wall`, `length` long and `height`
    /// tall: a plinth of stone, the brickwork, and quoins at its corner.
    private mutating func garrisonStone(_ length: Double, _ height: Double, quoinAtStart: Bool) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(0, 0, length, 3), .colour(I.footing), width: 0.6)
        brickwork(0, length, 3, height)
        quoins(at: quoinAtStart ? 0 : length, atStart: quoinAtStart, from: 3, to: height, course: 3.4, reach: 3.6)
    }

    /// A slit for a rifle on a wall drawn with `wall`, in a dressing of stone, at (`u`, `v`).
    private mutating func gunLoop(_ u: Double, _ v: Double) {
        typealias I = IndustrialOldBuildingsInk
        shape(panel(u - 1.6, v - 0.4, u + 1.6, v + 8), .colour(I.stoneTop), width: 0.5)
        shape(panel(u - 0.55, v + 0.6, u + 0.55, v + 7), .colour(I.dark), width: 0.45)
    }

    private mutating func garrison() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.garrisonBox
        let h0 = 2.0, f = 20.0, e = 34.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        let g0 = (Self.gateTowers[0].x1 - x0) * 32, g1 = (Self.gateTowers[1].x0 - x0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.garrisonStone(front, e - h0, quoinAtStart: false)
            p.archedDoors((g0 + g1) / 2, 2.4, w: g1 - g0 - 6, h: 17)
            for u in [7.0, 17.5] { p.shield(u, 8.4, w: 6, h: 7.4) }
            for u in [front - 19.5, front - 9] { p.shield(u, 8.4, w: 6, h: 7.4) }
            for u in [12.25, front - 14.25] { p.gunLoop(u, 4.2) }
            for u in [2.0, 23.0, front - 24.5, front - 3.5] { p.pilaster(u, 3, e - h0 - 2.6, w: 2.6) }
            for u in [7.0, 17.5, front - 19.5, front - 9] { p.archedWindow(u, 15.4, w: 5.4, h: 12) }
            p.paintedBand(0, front, e - h0 - 2.4, e - h0 - 0.9)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.garrisonStone(side, e - h0, quoinAtStart: true)
            for u in stride(from: 7.0, to: side - 4, by: 11) { p.gunLoop(u, 4.2) }
            for u in stride(from: 1.6, through: side - 1.4, by: 11) { p.pilaster(u, 3, e - h0 - 2.6, w: 2.6) }
            for u in stride(from: 7.0, to: side - 4, by: 11) { p.archedWindow(u, 15.4, w: 5.4, h: 12) }
            p.paintedBand(0, side, e - h0 - 2.4, e - h0 - 0.9)
        }
        cornice(x0, y0, x1, y1, at: e + 1.4, depth: 1.8)
        let ridge = hippedRoof(x0, y0, x1, y1, eaves: e + 1.4, rise: 26, overhang: 0.06)
        let k = (y1 - y0 + 0.12) / 2
        cresting(iso(x0 - 0.06 + k, y0 - 0.06 + k, ridge), iso(-0.4, y0 - 0.06 + k, ridge))
        cresting(iso(0.1, y0 - 0.06 + k, ridge), iso(x1 + 0.06 - k, y0 - 0.06 + k, ridge))
        ventilator(-0.15, y0 - 0.06 + k, on: ridge)
        // The towers either side of the gate, and the banner hung between them.
        for tower in Self.gateTowers { gateTower(tower.x0, y1, tower.x1, Self.gateTowerFront, from: h0, complete: true) }
        wall(.left, from: x0, y1 + 0.01, at: h0) { p in p.banner((g0 + g1) / 2, top: f + 13, width: 11, length: 13) }
        pikeRack(-1.15, 0.95)
        archeryButt(at: iso(0.72, 0.98, h0))
        standard(at: iso(1.22, 0.62, h0), height: 56)
    }

    /// A tower from (x0, y0) to (x1, y1), standing out before the hall's wall,
    /// of brick with quoins and rifle slits, crenellated in stone at its top.
    private mutating func gateTower(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double, complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let h1 = complete ? 44.0 : 14.0
        block(x0, y0, x1, y1, h0, h1, top: complete ? nil : .colour(I.brickTop), left: .colour(complete ? I.brick : I.rawBrick),
              right: .colour(complete ? I.brickShade : I.rawBrickShade), width: 1.1)
        let w = (x1 - x0) * 32, d = (y1 - y0) * 32
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, w, 3), .colour(complete ? I.footing : I.rawStone), width: 0.6)
            p.brickwork(0, w, 3, h1 - h0, burnt: complete)
            guard complete else { return }
            p.quoins(at: 0, atStart: true, from: 3, to: h1 - h0 - 2, course: 3.4, reach: 3.4)
            p.quoins(at: w, atStart: false, from: 3, to: h1 - h0 - 2, course: 3.4, reach: 3.4)
            p.gunLoop(w / 2, 8)
            p.gunLoop(w / 2, 24)
            p.stringCourse(0, w, 19.6, 21)
            p.shape(p.panel(-0.3, h1 - h0 - 2, w + 0.3, h1 - h0), .colour(I.stoneTop), width: 0.6)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, d, 3), .colour(complete ? I.footingShade : I.rawStoneShade), width: 0.6)
            p.brickwork(0, d, 3, h1 - h0, burnt: complete)
            guard complete else { return }
            p.quoins(at: d, atStart: false, from: 3, to: h1 - h0 - 2, course: 3.4, reach: 3.4)
            p.gunLoop(d / 2, 16)
            p.stringCourse(0, d, 19.6, 21)
            p.shape(p.panel(-0.3, h1 - h0 - 2, d + 0.3, h1 - h0), .colour(I.stone), width: 0.6)
        }
        guard complete else { return }
        colour(level(x0, y0, x1, y1, h1), .colour(I.slateShade))
        line(level(x0, y0, x1, y1, h1), closed: true, width: 0.9)
        battlements(x0, y0, x1, y1, on: h1, count: 2, height: 5, front: false)
        battlements(x0, y0, x1, y1, on: h1, count: 2, height: 5, front: true)
    }

    /// A rack of rifles, their foot at (x, y), along x: two posts and a bar
    /// of timber, the rifles leaning on it, butts down, with iron barrels.
    private mutating func pikeRack(_ x: Double, _ y: Double) {
        typealias I = IndustrialOldBuildingsInk
        let h0 = 2.0, length = 0.55
        pole(iso(x, y, h0), iso(x, y, h0 + 13), width: 1.3, colour: I.oak)
        for i in 0..<7 {
            let along = x + length * (0.08 + Double(i) * 0.14)
            let foot = iso(along, y - 0.06, h0), head = iso(along + 0.02, y - 0.1, h0 + 20)
            let grip = foot + (head - foot) * 0.36
            // The butt, the stock to the grip, then the barrel.
            shape([foot + P(-1.4, 0), foot + P(1.2, 0), grip + P(0.6, 0), grip + P(-0.6, 0)], .colour(I.timber), width: 0.5)
            svg.line([grip, head], stroke: .colour(I.line), width: 1.3)
            svg.line([grip, head], stroke: .colour(I.ironLight), width: 0.5)
            svg.line([grip + (head - grip) * 0.1, grip + (head - grip) * 0.7], stroke: .colour(I.timberLight), width: 0.7)
        }
        pole(iso(x + length, y, h0), iso(x + length, y, h0 + 13), width: 1.3, colour: I.oak)
        pole(iso(x - 0.04, y, h0 + 12), iso(x + length + 0.04, y, h0 + 12), width: 1.3, colour: I.oakLight)
    }

    /// A target standing at `p` on the screen: a square board painted in
    /// rings on a frame of two legs, holed by shot.
    private mutating func archeryButt(at p: P) {
        typealias I = IndustrialOldBuildingsInk
        svg.ellipse(p + P(0, 0.6), 7, 2, fill: .colour("#000000"), opacity: 0.14)
        pole(p + P(-4, 0), p + P(-3, -18), width: 1.2, colour: I.oak)
        pole(p + P(4, 0), p + P(3, -18), width: 1.2, colour: I.oak)
        let c = p - P(0, 13)
        shape([c + P(-6.4, -6.4), c + P(6.4, -6.4), c + P(6.4, 6.4), c + P(-6.4, 6.4)], .colour(I.plasterTop), width: 0.8)
        svg.circle(c, 5.2, fill: .none, stroke: .colour(I.line), width: 0.6)
        svg.circle(c, 3.6, fill: .colour(I.light), stroke: .colour(I.line), width: 0.5)
        svg.circle(c, 2.2, fill: .colour(I.ironDark))
        for (dx, dy) in [(1.2, -0.6), (-2.6, 1.8), (3.6, 2.8), (-0.4, -4.2)] {
            svg.circle(c + P(dx, dy), 0.45, fill: .colour(I.dark))
        }
    }

    /// A ventilator on the ridge at (x, y) on `h`: a little louvred box of
    /// painted board under its own hipped cap of slate, with an iron finial.
    private mutating func ventilator(_ x: Double, _ y: Double, on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let s = 0.12
        block(x - s, y - s, x + s, y + s, h - 3, h + 6, top: nil, left: .colour(I.light), right: .colour(I.plasterShade), width: 0.8)
        for side in [IndustrialOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x - s : x + s, y + s, at: h - 3) { p in
                for v in stride(from: 4.0, to: 8.6, by: 1.4) { p.line([p.uv(0.8, v), p.uv(2 * s * 32 - 0.8, v - 0.6)], width: 0.45) }
            }
        }
        hippedRoof(x - s, y - s, x + s, y + s, eaves: h + 6, rise: 6, overhang: 0.03, finials: true)
    }

    /// The owner's standard standing at `p` on the screen: a tall iron staff
    /// under a spearhead, a crossbar, and from it a long banner of the
    /// owner's colour edged in the light colour.
    private mutating func standard(at p: P, height: Double) {
        typealias I = IndustrialOldBuildingsInk
        let top = p - P(0, height)
        svg.ellipse(p + P(0, 0.4), 4, 1.4, fill: .colour("#000000"), opacity: 0.14)
        svg.line([p, top], stroke: .colour(I.line), width: 2.5)
        svg.line([p, top], stroke: .colour(I.ironLight), width: 1.2)
        let bar = top + P(0, 6)
        let (w, l) = (13.0, 20.0)
        let cloth = [bar + P(-w / 2, 0), bar + P(w / 2, 0), bar + P(w / 2, l), bar + P(w / 4, l - 3), bar + P(0, l),
                     bar + P(-w / 4, l - 3), bar + P(-w / 2, l)]
        let rim = [bar + P(-w / 2 - 1, 0), bar + P(w / 2 + 1, 0), bar + P(w / 2 + 1, l + 1.2), bar + P(w / 4, l - 1.8),
                   bar + P(0, l + 1.2), bar + P(-w / 4, l - 1.8), bar + P(-w / 2 - 1, l + 1.2)]
        shape(rim, .colour(I.light), width: 0.6)
        shape(cloth, .team, width: 0.8)
        cog(at: bar + P(0, l * 0.42), radius: w * 0.16)
        pole(bar + P(-w / 2 - 1.6, 0), bar + P(w / 2 + 1.6, 0), width: 1.2, colour: I.oak)
        for s in [-1.0, 1.0] { svg.circle(bar + P(s * (w / 2 + 1.6), 0), 0.9, fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.4) }
        shape([top + P(-1.5, 0.4), top + P(0, -5.4), top + P(1.5, 0.4)], .colour(I.ironLight), width: 0.7)
    }

    /// The barracks being built: the hall's walls of fresh brick half raised
    /// round the doorway's opening, the towers begun, scaffolding with the
    /// owner's pennant, and bricks, timber and slates to hand.
    private mutating func garrisonRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.garrisonBox
        let h0 = 2.0, top = 15.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.1, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.earth)) { p in
            p.bricks(-0.9, -0.9, -0.6, -0.6, from: h0, height: 5)
            p.basket(at: p.iso(-0.2, -0.6, h0), size: 0.9)
            p.timbers(0.0, -1.2, length: 0.8, on: h0)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, 3), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, front, 3, top - h0, opacity: 0.4, burnt: false)
            let g0 = (Self.gateTowers[0].x1 - x0) * 32, g1 = (Self.gateTowers[1].x0 - x0) * 32
            p.shape(p.panel(g0 + 2, 0, g1 - 2, top - h0), .colour(I.dark), width: 1)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, side, 3), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, side, 3, top - h0, opacity: 0.4, burnt: false)
        }
        bricks(x0, y0, x0 + 0.1, y0 + 0.9, from: top, height: 3)
        for tower in Self.gateTowers { gateTower(tower.x0, y1, tower.x1, Self.gateTowerFront, from: h0, complete: false) }
        scaffold([(x1 + 0.14, 0.05), (x1 + 0.14, -0.6), (x1 + 0.14, -1.25)], from: h0, height: 28, levels: [10, 20], boards: 10)
        pennant(at: iso(x1 + 0.14, 0.05, h0 + 28), height: 12, length: 13)
        bricks(0.55, 0.72, 0.85, 1.0, from: h0, height: 6)
        slates(0.95, 0.75, 1.2, 1.05, from: h0, height: 6)
        timbers(-0.3, 1.05, length: 0.8, on: h0)
        ladder(foot: iso(-1.0, 0.62, h0), iso(-0.84, 0.62, h0), head: iso(-1.0, y1 + 0.02, top + 3), iso(-0.84, y1 + 0.02, top + 3),
               rungs: 5)
        barrel(at: iso(-1.2, 1.2, h0), size: 0.9)
    }
}
