// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age watch tower: the Alchemy age's stone tower replaced by a
// lookout framed in iron. Four legs of riveted iron rise from a plinth of
// dressed stone, leaning in as they climb, tied by girders at each stage and
// braced crosswise on every face, with a ladder climbing inside. At the top
// a deck of iron plate with railings round it carries a cabin of painted
// board, glazed on every side, a band of the owner's colour under its
// windows, under a pyramid of slate and an iron weathervane; a banner of the
// owner's colour hangs on the frame's face and a bell from the deck. Its
// footprint is one tile: x and y run from -0.5 to 0.5.

extension IndustrialOldBuildingsPainter {
    mutating func watchTower(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        block(-0.5, -0.5, 0.5, 0.5, 0, 3, top: .colour(I.paving), left: .colour(I.footing), right: .colour(I.footingShade), width: 1)
        if complete { lookoutTower() } else { lookoutTowerRising() }
    }

    private static let plinthTop = 7.0
    private static let deck = 64.0
    /// The stages at which girders tie the legs together, in points above the ground.
    private static let stages = [7.0, 26.0, 45.0, 64.0]

    /// How far a leg stands from the tower's axis at `h` points up, in tiles.
    private func legReach(_ h: Double) -> Double {
        0.36 - 0.13 * (h - Self.plinthTop) / (Self.deck - Self.plinthTop)
    }

    /// A girder or leg of iron from `a` to `b` on the screen, `width` thick.
    private mutating func girder(_ a: P, _ b: P, width w: Double = 2) {
        typealias I = IndustrialOldBuildingsInk
        svg.line([a, b], stroke: .colour(I.line), width: w + 1)
        svg.line([a, b], stroke: .colour(I.iron), width: w)
        svg.line([a + P(-w * 0.2, -w * 0.15), b + P(-w * 0.2, -w * 0.15)], stroke: .colour(I.ironLight), width: w * 0.3)
    }

    /// The point of the leg at the corner (`sx`, `sy`), each -1 or 1, at `h`.
    private func leg(_ sx: Double, _ sy: Double, _ h: Double) -> P {
        let r = legReach(h)
        return iso(sx * r, sy * r, h)
    }

    /// One face of the frame between the corners (`ax`, `ay`) and (`bx`, `by`),
    /// up to `top`: its girders at each stage and its cross bracing, and the
    /// legs at its ends when `legs`.
    private mutating func frameFace(_ a: (Double, Double), _ b: (Double, Double), to top: Double, legs: Bool) {
        let stages = Self.stages.filter { $0 <= top + 0.1 }
        for (lo, hi) in zip(stages, stages.dropFirst()) {
            girder(leg(a.0, a.1, lo), leg(b.0, b.1, hi), width: 0.8)
            girder(leg(b.0, b.1, lo), leg(a.0, a.1, hi), width: 0.8)
        }
        for h in stages.dropFirst() { girder(leg(a.0, a.1, h), leg(b.0, b.1, h), width: 1.3) }
        if legs {
            for c in [a, b] { girder(leg(c.0, c.1, Self.plinthTop), leg(c.0, c.1, top), width: 2.2) }
        }
    }

    /// The plinth of dressed stone the legs stand on.
    private mutating func towerPlinth(raw: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let s = 0.42, h0 = 3.0, h1 = Self.plinthTop
        block(-s, -s, s, s, h0, h1, top: .colour(raw ? I.rawStoneTop : I.stoneTop), left: .colour(raw ? I.rawStone : I.stone),
              right: .colour(raw ? I.rawStoneShade : I.stoneShade), width: 1)
        // The bolts of the legs' feet.
        for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
            let r = legReach(h1), c = iso(sx * r, sy * r, h1)
            svg.ellipse(c, 3, 1.5, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// A ladder of iron up the middle of the frame, from the plinth to `top`.
    private mutating func innerLadder(to top: Double) {
        typealias I = IndustrialOldBuildingsInk
        let a = iso(-0.05, 0.05, Self.plinthTop), b = iso(0.05, -0.05, Self.plinthTop)
        svg.line([a, a - P(0, top - Self.plinthTop)], stroke: .colour(I.ironDark), width: 0.9)
        svg.line([b, b - P(0, top - Self.plinthTop)], stroke: .colour(I.ironDark), width: 0.9)
        var rungs = PathData()
        var v = 3.0
        while v < top - Self.plinthTop { rungs.move(a - P(0, v)); rungs.line(b - P(0, v)); v += 3 }
        svg.path(rungs, stroke: .colour(I.ironDark), width: 0.6)
    }

    private mutating func lookoutTower() {
        typealias I = IndustrialOldBuildingsInk
        let deck = Self.deck, cabin = 0.3, eaves = deck + 17, e = 0.42
        shadow([iso(0.42, -0.42, 3), iso(0.6, -0.3, 3), iso(0.6, 0.42, 3), iso(0.42, 0.42, 3)])
        towerPlinth(raw: false)
        // The far faces, the ladder, then the near faces over them.
        frameFace((-1, -1), (1, -1), to: deck, legs: true)
        frameFace((-1, -1), (-1, 1), to: deck, legs: false)
        innerLadder(to: deck)
        frameFace((-1, 1), (1, 1), to: deck, legs: true)
        frameFace((1, 1), (1, -1), to: deck, legs: false)
        // The banner on the frame's near left face, between the middle stages.
        let r = legReach(40)
        wall(.left, from: -r, r, at: 26) { p in
            p.banner(r * 32, top: 17, width: 9, length: 15)
        }
        // The deck: a plate of iron on a girder rim, with railings round it.
        block(-e, -e, e, e, deck - 2.4, deck, top: .colour(I.ironLight), left: .colour(I.iron), right: .colour(I.ironDark), width: 1)
        railing(-e + 0.03, -e + 0.03, e - 0.03, -e + 0.03, on: deck, height: 6, step: 2.6)
        railing(-e + 0.03, -e + 0.03, -e + 0.03, e - 0.03, on: deck, height: 6, step: 2.6)
        // The cabin of painted board, glazed on each side.
        block(-cabin, -cabin, cabin, cabin, deck, eaves, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        let w = 2 * cabin * 32
        for side in [IndustrialOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -cabin : cabin, cabin, at: deck) { p in
                var boards = PathData()
                for v in stride(from: 1.4, to: 5.4, by: 1.3) { boards.move(p.uv(0, v)); boards.line(p.uv(w, v)) }
                p.svg.path(boards, stroke: .colour(I.line), width: 0.35, opacity: 0.45)
                p.paintedBand(0, w, 5.4, 7)
                for u in [0.9, w - 0.9] { p.shape(p.panel(u - 0.9, 0, u + 0.9, eaves - deck), .colour(I.green), width: 0.5) }
                p.casement(3.2, 8.6, w: w - 6.4, h: 6.4, lights: 2, frame: I.green)
            }
        }
        railing(-e + 0.03, e - 0.03, e - 0.03, e - 0.03, on: deck, height: 6, step: 2.6)
        railing(e - 0.03, -e + 0.03, e - 0.03, e - 0.03, on: deck, height: 6, step: 2.6)
        // The bell, hung from a bracket at the deck's front corner.
        let bracket = iso(e, e, deck + 6)
        line([bracket, bracket + P(0, -4), bracket + P(5, -4)], width: 1)
        let bell = bracket + P(5, 4)
        line([bracket + P(5, -4), bell + P(0, -4.6)], width: 0.6)
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(bell + P(-3, 0) + o)
            d.quad(bell + P(-2.3, -1.2) + o, bell + P(-2.1, -3.2) + o)
            d.quad(bell + P(0, -5.6) + o, bell + P(2.1, -3.2) + o)
            d.quad(bell + P(2.3, -1.2) + o, bell + P(3, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.brass)) { d, o in d = outline(o) }
        line(width: 0.7) { d in d = outline(P(0, 0)) }
        svg.circle(bell + P(0, 0.8), 0.8, fill: .colour(I.brassShade))
        // The roof of slate and the weathervane at its peak.
        let peak = hippedRoof(-cabin - 0.02, -cabin - 0.02, cabin + 0.02, cabin + 0.02, eaves: eaves, rise: 16, overhang: 0.05,
                              finials: false)
        weathervane(at: iso(0, 0, peak), height: 11)
    }

    /// The tower being built: the plinth laid, the legs raised two stages
    /// and girdered, a gin pole lashed to them hoisting the next girder,
    /// scaffolding flying the owner's pennant, and girders and plates to hand.
    private mutating func lookoutTowerRising() {
        typealias I = IndustrialOldBuildingsInk
        let top = Self.stages[2]
        scaffold([(-0.46, -0.46), (0.46, -0.46)], from: 3, height: 52, levels: [16, 32, 46])
        shadow([iso(0.42, -0.42, 3), iso(0.54, -0.34, 3), iso(0.54, 0.42, 3), iso(0.42, 0.42, 3)])
        towerPlinth(raw: true)
        frameFace((-1, -1), (1, -1), to: top, legs: true)
        frameFace((-1, -1), (-1, 1), to: top, legs: false)
        innerLadder(to: top - 4)
        frameFace((-1, 1), (1, 1), to: top, legs: true)
        frameFace((1, 1), (1, -1), to: top, legs: false)
        // The gin pole on the near leg, its tackle lifting a girder.
        let foot = leg(1, 1, Self.plinthTop), head = leg(1, 1, top) - P(0, 22)
        pole(foot, head, width: 1.8, colour: I.timberLight)
        let hook = head + P(-12, 4)
        line([head, hook], width: 0.6)
        line([hook, hook + P(0, 9)], width: 0.6)
        girder(hook + P(-7, 12), hook + P(7, 6), width: 1.8)
        line([hook + P(0, 9), hook + P(-5, 11.2)], width: 0.5)
        line([hook + P(0, 9), hook + P(5, 6.8)], width: 0.5)
        scaffold([(-0.46, 0.46), (0.46, 0.46), (0.46, -0.46)], from: 3, height: 52, levels: [16, 32, 46], boards: 32,
                 inward: (0, -0.12))
        pennant(at: iso(0.46, 0.46, 55), height: 11, length: 12)
        // Girders and plates waiting on the ground.
        for k in 0..<3 {
            let y = 0.18 + Double(k) * 0.07
            girder(iso(-0.44, y, 3.6 + Double(k % 2) * 1.6), iso(-0.06, y, 3.6 + Double(k % 2) * 1.6), width: 1.6)
        }
        block(0.2, -0.4, 0.44, -0.12, 3, 5.4, top: .colour(I.ironLight), left: .colour(I.iron), right: .colour(I.ironDark), width: 0.8)
        barrel(at: iso(0.36, 0.14, 3), size: 0.75)
    }
}
