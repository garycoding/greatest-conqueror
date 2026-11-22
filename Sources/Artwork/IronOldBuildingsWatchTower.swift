// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age watch tower: the Bronze age's tower rebuilt in dressed stone on
// a moulded plinth, with a door studded with iron at its foot, slits for
// archers, and a window barred with iron. At the top a platform on stone
// corbels carries a plastered parapet painted with the owner's colour, an
// iron bell to raise the alarm, and a pyramid roof of red tile under the
// owner's pennant. Its footprint is one tile: x and y run from -0.5 to 0.5.

extension IronOldBuildingsPainter {
    mutating func watchTower(complete: Bool) {
        typealias I = IronOldBuildingsInk
        block(-0.5, -0.5, 0.5, 0.5, 0, 3, top: .colour(I.paving), left: .colour(I.footing),
              right: .colour(I.footingShade), width: 1)
        if complete { tower() } else { towerRising() }
    }

    private static let shaft = 0.3

    /// The shaft's walls, from the footing up to `top` points: courses of
    /// dressed stone on a plinth, slits, a barred window, and the door.
    private mutating func shaftWalls(top: Double) {
        typealias I = IronOldBuildingsInk
        let s = Self.shaft, w = 2 * s * 32, height = top - 3
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -s : s, s, at: 3) { p in
                p.colour(p.panel(0, 0, w, 4), .colour(side == .left ? I.footing : I.footingShade))
                p.line([p.uv(0, 4), p.uv(w, 4)], width: 0.7)
                p.courses(0, w, 4, height, course: 4.4, brick: 9.6)
                for v in [24.0, 44.0] where v + 6 < height {
                    p.shape(p.panel(w / 2 - 0.9, v, w / 2 + 0.9, v + 6.4), .colour(I.dark), width: 0.7)
                }
                if side == .left {
                    p.archedDoor(w / 2, 0, w: 8, h: 13, paint: I.timber)
                } else if height > 36 {
                    p.grille(w / 2 - 3, 33, w: 6, h: 7)
                }
            }
        }
    }

    private mutating func tower() {
        typealias I = IronOldBuildingsInk
        let s = Self.shaft, deck = 64.0, rail = 71.0, eaves = 82.0, e = 0.42
        shadow([iso(s, -s, 3), iso(s + 0.16, -s + 0.1, 3), iso(s + 0.16, s, 3), iso(s, s, 3)])
        block(-s, -s, s, s, 3, deck, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        shaftWalls(top: deck)
        // Corbels under the platform.
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -s : s, s, at: 3) { p in
                for u in [2.6, 9.6, 16.6] {
                    p.shape([p.uv(u - 1.4, deck - 3), p.uv(u + 1.4, deck - 3), p.uv(u + 1.4, deck - 6.2), p.uv(u, deck - 8),
                             p.uv(u - 1.4, deck - 6.2)], .colour(I.stoneTop), width: 0.6)
                }
            }
        }
        block(-e, -e, e, e, deck, deck + 2.5, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade),
              width: 1)
        let posts: [(Double, Double)] = [(-e + 0.05, -e + 0.05), (e - 0.05, -e + 0.05), (-e + 0.05, e - 0.05), (e - 0.05, e - 0.05)]
        shell(-e, -e, e, e, from: deck + 2.5, floor: deck + 2.5, to: rail, thickness: 0.05, lit: .colour(I.light),
              shade: .colour(I.plasterShade), top: .colour(I.plasterTop), ground: .colour(I.paving), width: 1) { p in
            for (x, y) in posts { p.pole(p.iso(x, y, deck + 2.5), p.iso(x, y, eaves), width: 1.3) }
        }
        let w = 2 * e * 32
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -e : e, e, at: deck + 2.5) { p in
                p.colour(p.panel(0, 1.6, w, 3.8), .team)
                p.line([p.uv(0, 1.6), p.uv(w, 1.6)], width: 0.6)
                p.line([p.uv(0, 3.8), p.uv(w, 3.8)], width: 0.6)
            }
        }
        // The bell, hung from the canopy in front of the parapet's left side.
        let bell = iso(-0.12, e + 0.05, rail + 2.4), hook = iso(-0.12, e + 0.05, eaves - 0.5)
        line([hook, bell + P(0, -5.4)], width: 0.7)
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
        // The roof of red tile, and the pennant at its peak.
        let peak = hippedRoof(-0.44, -0.44, 0.44, 0.44, eaves: eaves, overhang: 0.06)
        pennant(at: iso(0, 0, peak), height: 14, length: 14)
    }

    /// The tower being built: its shaft half raised in fresh stone inside
    /// scaffolding, with stone and timber to hand.
    private mutating func towerRising() {
        typealias I = IronOldBuildingsInk
        let s = Self.shaft, top = 33.0
        scaffold([(-0.44, -0.44), (0.44, -0.44)], from: 3, height: 46, levels: [14, 28, 40])
        shadow([iso(s, -s, 3), iso(s + 0.12, -s + 0.08, 3), iso(s + 0.12, s, 3), iso(s, s, 3)])
        block(-s, -s, s, s, 3, top, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade))
        shaftWalls(top: top)
        // The next courses, begun along the back.
        blocks(-s, -s, s, -0.08, from: top, courses: 1)
        blocks(-s, -0.08, -0.1, s, from: top, courses: 1)
        scaffold([(-0.44, 0.44), (0.44, 0.44), (0.44, -0.44)], from: 3, height: 46, levels: [14, 28, 40], boards: 14)
        pennant(at: iso(0.44, 0.44, 49), height: 11, length: 14)
        blocks(0.33, -0.3, 0.46, -0.02, from: 3, courses: 1)
        basket(at: iso(0.38, 0.14, 3), size: 0.8)
        log(-0.42, -0.02, 0.4, on: 3, radius: 1.4)
    }
}
