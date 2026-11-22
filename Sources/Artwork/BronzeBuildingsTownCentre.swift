// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age town centre: the stepped temple of the approved scene
// (docs/art/cartoon-modern-scene-1.png) seen from the game's angle. Three
// terraces of brick stand on a paved court, climbed by flights of steps, with
// a plastered shrine at the top under the owner's pennant. Its footprint is
// three tiles square: x and y run from -1.5 to 1.5.

extension BronzeBuildingsPainter {
    mutating func townCentre(complete: Bool) {
        typealias I = BronzeBuildingsInk
        // The paved court.
        block(-1.5, -1.5, 1.5, 1.5, 0, 3, top: .colour(I.paving), left: .colour(I.pavingShade),
              right: .colour(I.pavingShade), width: 1)
        if complete { temple() } else { templeRising() }
    }

    /// The first terrace's walls, up to `top` points above the court: recesses
    /// in the brick, and a zigzag frieze where the wall is tall enough for it.
    private mutating func firstTerraceWalls(top: Double) {
        typealias I = BronzeBuildingsInk
        let frieze = top >= 22
        wall(.left, from: -1.25, 1.25, at: 3) { p in
            for u in [5.0, 11, 66.4, 72.4] { p.niche(u, 2, min(15, top - 2)) }
            if frieze { p.frieze(0, 80, 16.5, to: 21) }
        }
        wall(.right, from: 1.25, 1.25, at: 3) { p in
            for i in 0..<9 { p.niche(6.7 + Double(i) * 8, 2, min(15, top - 2)) }
            if frieze { p.frieze(0, 80, 16.5, to: 21) }
        }
    }

    /// A recess in a brick wall drawn with `wall`, at `u`, from `v0` to `v1`.
    fileprivate mutating func niche(_ u: Double, _ v0: Double, _ v1: Double, width: Double = 2.4,
                                    shade: String = BronzeBuildingsInk.terracottaShade) {
        colour(panel(u, v0, u + width, v1), .colour(shade))
        line([uv(u, v0), uv(u, v1), uv(u + width, v1)], width: 0.6)
    }

    /// A frieze on a wall drawn with `wall`: a line at `v0` and a zigzag above it, up to `v1`.
    fileprivate mutating func frieze(_ u0: Double, _ u1: Double, _ v0: Double, to v1: Double) {
        line([uv(u0, v0), uv(u1, v0)], width: 0.8)
        zigzag(u0 + 1.5, u1 - 1.5, v0 + 1.2, v1 - 0.6, pitch: 4.6, width: 0.8)
    }

    private mutating func temple() {
        typealias I = BronzeBuildingsInk
        // The first terrace, its shadow on the court, and its flight of steps.
        shadow([iso(1.25, -1.25, 3), iso(1.42, -1.1, 3), iso(1.42, 1.32, 3), iso(1.25, 1.25, 3)])
        block(-1.25, -1.25, 1.25, 1.25, 3, 25, top: .colour(I.paving), left: .colour(I.terracotta),
              right: .colour(I.terracottaShade))
        firstTerraceWalls(top: 22)
        wall(.left, from: -1.25, 1.25, at: 3) { p in
            p.hanging(20.8, top: 21.6, width: 8, length: 16)
            p.hanging(59.2, top: 21.6, width: 8, length: 16)
        }
        flight(-0.17, 0.17, foot: 1.5, 3, head: 1.25, 25, steps: 6)

        // The second terrace: paler brick, arched niches, and a band of rosettes.
        shadow([iso(0.92, -0.92, 25), iso(1.06, -0.8, 25), iso(1.06, 1.0, 25), iso(0.92, 0.92, 25)])
        block(-0.92, -0.92, 0.92, 0.92, 25, 44, top: .colour(I.paving), left: .colour(I.clay), right: .colour(I.clayShade))
        for side in [BronzeBuildingsSide.left, .right] {
            let from = side == .left ? (-0.92, 0.92) : (0.92, 0.92)
            let arches: [Double] = side == .left ? [6.5, 14.5, 44.4, 52.4] : [9, 21.5, 37.5, 50]
            wall(side, from: from.0, from.1, at: 25) { p in
                for u in arches { p.arch(u, 2.4, width: 4.6, height: 9.5, .colour(I.dark)) }
                p.line([p.uv(0, 13.4), p.uv(58.9, 13.4)], width: 0.8)
                p.line([p.uv(0, 17.6), p.uv(58.9, 17.6)], width: 0.8)
                for u in stride(from: 3.2, to: 58, by: 4.6) {
                    p.svg.circle(p.uv(u, 15.5), 1.05, fill: .colour(I.light), stroke: .colour(I.line), width: 0.5)
                }
            }
        }
        flight(-0.15, 0.15, foot: 1.25, 25, head: 0.92, 44, steps: 5)

        // The third terrace, with a zigzag band.
        shadow([iso(0.6, -0.6, 44), iso(0.72, -0.5, 44), iso(0.72, 0.66, 44), iso(0.6, 0.6, 44)])
        block(-0.6, -0.6, 0.6, 0.6, 44, 58, top: .colour(I.paving), left: .colour(I.terracotta),
              right: .colour(I.terracottaShade))
        for side in [BronzeBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -0.6 : 0.6, 0.6, at: 44) { p in
                p.line([p.uv(0, 4), p.uv(38.4, 4)], width: 0.8)
                p.line([p.uv(0, 10), p.uv(38.4, 10)], width: 0.8)
                p.zigzag(1.4, 37, 5, 9, pitch: 4.2, width: 0.8)
            }
        }
        flight(-0.13, 0.13, foot: 0.92, 44, head: 0.6, 58, steps: 4)

        // The shrine: plastered walls under a band of the owner's colour, a door
        // of verdigris facing the steps, braziers either side of it.
        shadow([iso(0.34, -0.34, 58), iso(0.46, -0.24, 58), iso(0.46, 0.4, 58), iso(0.34, 0.34, 58)])
        block(-0.34, -0.34, 0.34, 0.34, 58, 72, top: .colour(I.plasterTop), left: .colour(I.light),
              right: .colour(I.plasterShade))
        wall(.left, from: -0.34, 0.34, at: 58) { p in
            p.colour(p.panel(0, 10.6, 21.8, 12.8), .team)
            p.line([p.uv(0, 10.6), p.uv(21.8, 10.6)], width: 0.7)
            p.line([p.uv(0, 12.8), p.uv(21.8, 12.8)], width: 0.7)
            p.arch(10.9, 0, width: 6.6, height: 9.4, .colour(I.verdigris), line: 1)
            p.line([p.uv(10.9, 0.4), p.uv(10.9, 7.2)], width: 0.6)
        }
        wall(.right, from: 0.34, 0.34, at: 58) { p in
            p.colour(p.panel(0, 10.6, 21.8, 12.8), .team)
            p.line([p.uv(0, 10.6), p.uv(21.8, 10.6)], width: 0.7)
            p.line([p.uv(0, 12.8), p.uv(21.8, 12.8)], width: 0.7)
            p.shape(p.panel(8.6, 4.2, 13.2, 8.4), .colour(I.dark), width: 0.8)
        }
        // The roof: a slab, with stepped merlons at its corners.
        block(-0.38, -0.38, 0.38, 0.38, 72, 74.5, top: .colour(I.plasterTop), left: .colour(I.plasterShade),
              right: .colour(I.plasterShade), width: 1)
        for (x, y) in [(-0.38, -0.38), (0.38, -0.38), (-0.38, 0.38), (0.38, 0.38)] {
            let e = 0.07
            block(x - e, y - e, x + e, y + e, 74.5, 78, top: .colour(I.plasterTop), left: .colour(I.light),
                  right: .colour(I.plasterShade), width: 0.8)
        }
        pennant(at: iso(-0.05, -0.05, 74.5), height: 30, length: 17)
        brazier(at: iso(-0.24, 0.5, 58))
        brazier(at: iso(0.24, 0.5, 58))
    }

    /// The temple being built: the first terrace standing with its steps, the
    /// second rising in fresh brick inside scaffolding, and brick, timber and
    /// mud to hand on the terrace and the court.
    private mutating func templeRising() {
        typealias I = BronzeBuildingsInk
        let base = 25.0, top = 34.0
        // Bricks waiting on the court behind the work.
        bricks(-1.46, -1.46, -1.3, -1.3, from: 3, courses: 3)
        shadow([iso(1.25, -1.25, 3), iso(1.42, -1.1, 3), iso(1.42, 1.32, 3), iso(1.25, 1.25, 3)])
        block(-1.25, -1.25, 1.25, 1.25, 3, base, top: .colour(I.paving), left: .colour(I.terracotta),
              right: .colour(I.terracottaShade))
        firstTerraceWalls(top: 22)
        flight(-0.17, 0.17, foot: 1.5, 3, head: 1.25, base, steps: 6)
        // Scaffolding at the back of the second terrace, behind the work.
        scaffold([(-1.08, -1.08), (0.0, -1.08), (1.08, -1.08)], from: base, height: 24, levels: [10, 20])
        // The second terrace, half raised in fresh brick, its next courses begun at the back.
        block(-0.92, -0.92, 0.92, 0.92, base, top, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick),
              right: .colour(I.rawBrickShade))
        for side in [BronzeBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -0.92 : 0.92, 0.92, at: base) { p in p.courses(0, 58.9, 0, top - base) }
        }
        block(-0.92, -0.92, 0.92, -0.3, top, top + 2.6, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick),
              right: .colour(I.rawBrickShade), width: 1)
        block(-0.92, -0.3, -0.35, 0.92, top, top + 2.6, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick),
              right: .colour(I.rawBrickShade), width: 1)
        bricks(0.1, 0.1, 0.45, 0.4, from: top, courses: 2)
        basket(at: iso(0.55, -0.1, top), size: 0.9)
        // On the first terrace: bricks to lay, and mud; scaffolding along the near walls.
        bricks(-0.75, 1.0, -0.42, 1.18, from: base, courses: 3)
        basket(at: iso(0.55, 1.08, base), size: 1)
        scaffold([(-0.8, 1.06), (-0.3, 1.06), (0.3, 1.06), (0.8, 1.06), (1.06, 1.06), (1.06, 0.4), (1.06, -0.3), (1.06, -0.9)],
                 from: base, height: 22, levels: [10, 20], boards: 10)
        pennant(at: iso(1.06, 1.06, base + 22), height: 12, length: 15)
        ladder(foot: iso(-1.0, 1.42, 3), iso(-0.84, 1.42, 3), head: iso(-1.0, 1.24, base + 4), iso(-0.84, 1.24, base + 4),
               rungs: 6)
        // Timber and bricks to hand at the front of the court.
        logs(0.42, 1.0, 1.39, on: 3, radius: 1.7)
        bricks(1.3, 0.4, 1.46, 0.75, from: 3, courses: 2)
    }
}
