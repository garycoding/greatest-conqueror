// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age watch tower: a tall shaft of mud brick laced with timber, on
// a footing of fired brick, with a door at its foot and slits for archers. At
// the top a platform on corbels carries a plastered parapet painted with the
// owner's colour, a bronze gong to raise the alarm, and a roof of reed under
// the owner's pennant. Its footprint is one tile: x and y run from -0.5 to 0.5.

extension BronzeBuildingsPainter {
    mutating func watchTower(complete: Bool) {
        typealias I = BronzeBuildingsInk
        block(-0.5, -0.5, 0.5, 0.5, 0, 3, top: .colour(I.terracottaTop), left: .colour(I.terracotta),
              right: .colour(I.terracottaShade), width: 1)
        if complete { tower() } else { towerRising() }
    }

    private static let shaft = 0.3

    /// The shaft's walls, from the footing up to `top` points: brick courses,
    /// timber lacing, slits, and the door.
    private mutating func shaftWalls(top: Double) {
        typealias I = BronzeBuildingsInk
        let s = Self.shaft, w = 2 * s * 32, height = top - 3
        for side in [BronzeBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -s : s, s, at: 3) { p in
                p.courses(0, w, 0, height, opacity: 0.4)
                for v in [17.0, 37.0] where v + 1.2 < height {
                    p.shape(p.panel(-0.3, v - 1.1, w + 0.3, v + 1.1), .colour(I.timber), width: 0.7)
                }
                for v in [23.0, 43.0] where v + 6 < height {
                    p.shape(p.panel(w / 2 - 0.9, v, w / 2 + 0.9, v + 6), .colour(I.dark), width: 0.7)
                }
                if side == .left {
                    p.arch(w / 2, 0, width: 8, height: 12, .colour(I.timber), line: 1)
                    p.line([p.uv(w / 2, 0.3), p.uv(w / 2, 9.6)], width: 0.5)
                    for v in [3.0, 6.4] {
                        p.svg.circle(p.uv(w / 2 - 2, v), 0.45, fill: .colour(I.bronzeLight))
                        p.svg.circle(p.uv(w / 2 + 2, v), 0.45, fill: .colour(I.bronzeLight))
                    }
                }
            }
        }
    }

    private mutating func tower() {
        typealias I = BronzeBuildingsInk
        let s = Self.shaft, deck = 64.0, rail = 71.0, eaves = 82.0, apex = 94.0, e = 0.42
        shadow([iso(s, -s, 3), iso(s + 0.16, -s + 0.1, 3), iso(s + 0.16, s, 3), iso(s, s, 3)])
        block(-s, -s, s, s, 3, deck, top: nil, left: .colour(I.sand), right: .colour(I.sandShade))
        shaftWalls(top: deck)
        // Corbels under the platform.
        for side in [BronzeBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -s : s, s, at: 3) { p in
                for u in [2.6, 9.6, 16.6] { p.shape(p.panel(u - 1.2, deck - 6.6, u + 1.2, deck - 4), .colour(I.timberLight), width: 0.6) }
            }
        }
        block(-e, -e, e, e, deck, deck + 2.5, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 1)
        let posts: [(Double, Double)] = [(-e + 0.05, -e + 0.05), (e - 0.05, -e + 0.05), (-e + 0.05, e - 0.05), (e - 0.05, e - 0.05)]
        shell(-e, -e, e, e, from: deck + 2.5, floor: deck + 2.5, to: rail, thickness: 0.05, lit: .colour(I.light),
              shade: .colour(I.plasterShade), top: .colour(I.plasterTop), ground: .colour(I.timberLight), width: 1) { p in
            for (x, y) in posts { p.pole(p.iso(x, y, deck + 2.5), p.iso(x, y, eaves), width: 1.3) }
        }
        let w = 2 * e * 32
        for side in [BronzeBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -e : e, e, at: deck + 2.5) { p in
                p.colour(p.panel(0, 1.6, w, 3.8), .team)
                p.line([p.uv(0, 1.6), p.uv(w, 1.6)], width: 0.6)
                p.line([p.uv(0, 3.8), p.uv(w, 3.8)], width: 0.6)
            }
        }
        // The gong, hung from the canopy in front of the parapet's left side.
        let gong = iso(-0.12, e + 0.05, rail + 3.6), hook = iso(-0.12, e + 0.05, eaves - 0.5)
        line([hook + P(-2.2, 0), gong + P(-1.8, -3)], width: 0.6)
        line([hook + P(2.2, 0), gong + P(1.8, -3)], width: 0.6)
        svg.ellipse(gong + P(-0.6, 0.5), 3.4, 4, fill: .colour(I.bronze))
        svg.ellipse(gong, 3.4, 4, fill: .none, stroke: .colour(I.line), width: 0.8)
        svg.ellipse(gong, 1.3, 1.5, fill: .colour(I.bronzeLight), stroke: .colour(I.line), width: 0.5)
        // The roof of reed: its two near slopes, and the pennant at its peak.
        let r = 0.5
        let left = iso(-r, r, eaves), front = iso(r, r, eaves), right = iso(r, -r, eaves), peak = iso(0, 0, apex)
        colour([left, front, front + P(0, 1.8), left + P(0, 1.8)], .colour(I.reedShade))
        colour([front, right, right + P(0, 1.8), front + P(0, 1.8)], .colour(I.reedShade))
        colour([left, front, peak], .colour(I.reed))
        colour([front, right, peak], .colour(I.reedShade))
        for t in stride(from: 0.14, to: 0.95, by: 0.14) {
            line([peak, left + (front - left) * t], width: 0.45, opacity: 0.7)
            line([peak, front + (right - front) * t], width: 0.45, opacity: 0.7)
        }
        line([left, front, right], width: 1)
        line([left + P(0, 1.8), front + P(0, 1.8), right + P(0, 1.8)], width: 0.8)
        line([left, peak, right], width: 1)
        line([front, peak], width: 0.9)
        pennant(at: peak, height: 14, length: 14)
    }

    /// The tower being built: its shaft half raised inside scaffolding.
    private mutating func towerRising() {
        typealias I = BronzeBuildingsInk
        let s = Self.shaft, top = 33.0
        scaffold([(-0.44, -0.44), (0.44, -0.44)], from: 3, height: 46, levels: [14, 28, 40])
        shadow([iso(s, -s, 3), iso(s + 0.12, -s + 0.08, 3), iso(s + 0.12, s, 3), iso(s, s, 3)])
        block(-s, -s, s, s, 3, top, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick), right: .colour(I.rawBrickShade))
        shaftWalls(top: top)
        // The next courses, begun along the back.
        block(-s, -s, s, -0.08, top, top + 2.6, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick),
              right: .colour(I.rawBrickShade), width: 0.9)
        block(-s, -0.08, -0.1, s, top, top + 2.6, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick),
              right: .colour(I.rawBrickShade), width: 0.9)
        scaffold([(-0.44, 0.44), (0.44, 0.44), (0.44, -0.44)], from: 3, height: 46, levels: [14, 28, 40], boards: 14)
        pennant(at: iso(0.44, 0.44, 49), height: 11, length: 14)
        bricks(0.33, -0.3, 0.46, -0.02, from: 3, courses: 2)
        basket(at: iso(0.38, 0.14, 3), size: 0.8)
        log(-0.42, -0.02, 0.4, on: 3, radius: 1.4)
    }
}
