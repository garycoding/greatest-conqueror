// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age watch tower: the Iron age's tower raised in dressed stone
// with quoins, on a moulded plinth, with a door of teal plank at its foot and
// loops for guns and bows up its shaft. At the top a lookout of oak and
// plaster, glazed on every side, stands out on corbels over the shaft, a band
// of the owner's colour along its sill and a bell hung before it; over it a
// steep pyramid of slate carries a gilt weathervane, and a banner of the
// owner's colour hangs on the shaft below the corbels. Its footprint is one
// tile: x and y run from -0.5 to 0.5.

extension AlchemyOldBuildingsPainter {
    mutating func watchTower(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        block(-0.5, -0.5, 0.5, 0.5, 0, 3, top: .colour(I.paving), left: .colour(I.footing), right: .colour(I.footingShade), width: 1)
        if complete { lookoutTower() } else { lookoutTowerRising() }
    }

    private static let towerShaft = 0.3

    /// The shaft's walls, from the plinth up to `top` points.
    private mutating func towerWalls(top: Double, raw: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let s = Self.towerShaft, w = 2 * s * 32, height = top - 3
        for side in [AlchemyOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -s : s, s, at: 3) { p in
                p.colour(p.panel(0, 0, w, 4), .colour(side == .left ? I.footing : I.footingShade))
                p.line([p.uv(0, 4), p.uv(w, 4)], width: 0.7)
                p.courses(0, w, 4, height, course: 4.4, brick: 9.6)
                if !raw {
                    p.quoins(at: side == .left ? 0 : w, atStart: side == .left, from: 4, to: height, course: 4.4)
                }
                // Loops: a cross for the bow, a round for the gun.
                for v in side == .left ? [26.0] : [26.0, 46.0] where v + 8 < height {
                    p.shape(p.panel(w / 2 - 0.8, v, w / 2 + 0.8, v + 8), .colour(I.dark), width: 0.6)
                    p.shape(p.panel(w / 2 - 2.6, v + 4.6, w / 2 + 2.6, v + 5.6), .colour(I.dark), width: 0.5)
                    p.svg.circle(p.uv(w / 2, v - 0.2), 1.2, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
                }
                if side == .left {
                    p.door(w / 2, 0, w: 8, h: 13)
                    if !raw { p.banner(w / 2, top: height - 8, width: 9, length: 17) }
                } else if height > 36 {
                    p.casement(w / 2 - 3, 34, w: 6, h: 7, lights: 1, frame: I.stoneTop)
                }
            }
        }
    }

    private mutating func lookoutTower() {
        typealias I = AlchemyOldBuildingsInk
        let s = Self.towerShaft, deck = 62.0, eaves = 80.0, e = 0.43
        shadow([iso(s, -s, 3), iso(s + 0.16, -s + 0.1, 3), iso(s + 0.16, s, 3), iso(s, s, 3)])
        block(-s, -s, s, s, 3, deck, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        towerWalls(top: deck, raw: false)
        // Corbels of stone carrying the lookout.
        for side in [AlchemyOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -s : s, s, at: 3) { p in
                for u in [2.6, 9.6, 16.6] {
                    p.shape([p.uv(u - 1.5, deck - 3), p.uv(u + 1.5, deck - 3), p.uv(u + 1.5, deck - 6.6), p.uv(u, deck - 8.6),
                             p.uv(u - 1.5, deck - 6.6)], .colour(I.stoneTop), width: 0.6)
                }
            }
        }
        // The lookout: a floor of oak, walls of plaster framed in oak, a window on each side.
        block(-e, -e, e, e, deck - 3, deck, top: nil, left: .colour(I.oakLight), right: .colour(I.oak), width: 1)
        block(-e, -e, e, e, deck, eaves, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        let w = 2 * e * 32
        for side in [AlchemyOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -e : e, e, at: deck) { p in
                p.framing(w, from: 0, to: eaves - deck, posts: [1, w - 1], rail: 4.6, braces: [])
                p.casement(4.4, 6, w: w - 8.8, h: 8.6, lights: 3)
                p.paintedBand(0, w, 1.2, 3.6)
            }
        }
        // The bell, hung from a bracket before the lookout's left side.
        let bracket = iso(-0.1, e, eaves - 2)
        pole(bracket, bracket + P(-7, 3.5), width: 1.2, colour: I.oak)
        let bell = bracket + P(-7, 12)
        line([bracket + P(-7, 3.5), bell + P(0, -5.4)], width: 0.7)
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(bell + P(-3.4, 0) + o)
            d.quad(bell + P(-2.6, -1.4) + o, bell + P(-2.4, -3.6) + o)
            d.quad(bell + P(0, -6.4) + o, bell + P(2.4, -3.6) + o)
            d.quad(bell + P(2.6, -1.4) + o, bell + P(3.4, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.iron)) { d, o in d = outline(o) }
        line(width: 0.8) { d in d = outline(P(0, 0)) }
        line([bell + P(-1.6, -4.2), bell + P(-2, -1)], width: 0.6, opacity: 0.6)
        svg.circle(bell + P(0, 0.9), 0.9, fill: .colour(I.ironDark))
        // The roof of slate, the weathervane at its peak, and the pennant at its corner.
        let peak = hippedRoof(-0.46, -0.46, 0.46, 0.46, eaves: eaves, rise: 21, overhang: 0.05, finials: false)
        weathervane(at: iso(0, 0, peak), height: 11)
    }

    /// The tower being built: its shaft half raised in fresh stone inside
    /// scaffolding flying the owner's pennant, with stone, oak and mortar to hand.
    private mutating func lookoutTowerRising() {
        typealias I = AlchemyOldBuildingsInk
        let s = Self.towerShaft, top = 36.0
        scaffold([(-0.44, -0.44), (0.44, -0.44)], from: 3, height: 50, levels: [15, 30, 44])
        shadow([iso(s, -s, 3), iso(s + 0.12, -s + 0.08, 3), iso(s + 0.12, s, 3), iso(s, s, 3)])
        block(-s, -s, s, s, 3, top, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade))
        towerWalls(top: top, raw: true)
        blocks(-s, -s, s, -0.08, from: top, courses: 1)
        blocks(-s, -0.08, -0.1, s, from: top, courses: 1)
        scaffold([(-0.44, 0.44), (0.44, 0.44), (0.44, -0.44)], from: 3, height: 50, levels: [15, 30, 44], boards: 30,
                 inward: (0, -0.12))
        pennant(at: iso(0.44, 0.44, 53), height: 11, length: 12)
        blocks(0.33, -0.3, 0.46, -0.02, from: 3, courses: 1)
        basket(at: iso(0.38, 0.16, 3), size: 0.8)
        beam(-0.42, 0.42, -0.02, 0.42, on: 3, size: 2.4)
    }
}
