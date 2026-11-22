// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age town centre: the Bronze age's stepped temple grown into a
// temple of dressed stone on a high podium, climbed by a broad flight of steps.
// A porch of six columns carries the entablature and a gabled roof of red tile,
// whose pediment bears the owner's colour round a wreath; banners in the
// owner's colour hang between pilasters on the side wall, and the owner's
// standards stand at the corners of the paved court. Its footprint is three
// tiles square: x and y run from -1.5 to 1.5.

extension IronOldBuildingsPainter {
    mutating func townCentre(complete: Bool) {
        typealias I = IronOldBuildingsInk
        // The paved court, its flagstones jointed.
        block(-1.5, -1.5, 1.5, 1.5, 0, 3, top: .colour(I.paving), left: .colour(I.pavingShade),
              right: .colour(I.pavingShade), width: 1)
        var joints = PathData()
        for t in stride(from: -1.25, through: 1.25, by: 0.25) {
            joints.move(iso(t, -1.5, 3)); joints.line(iso(t, 1.5, 3))
            joints.move(iso(-1.5, t, 3)); joints.line(iso(1.5, t, 3))
        }
        svg.path(joints, stroke: .colour(I.line), width: 0.4, opacity: 0.35)
        podium()
        if complete { temple() } else { templeRising() }
    }

    private static let cella = (x0: -0.9, y0: -1.2, x1: 0.9, y1: 0.45)
    private static let podiumTop = 13.0
    private static let capitals = 45.0

    /// The podium: a platform of dressed stone with a moulded cornice.
    private mutating func podium() {
        typealias I = IronOldBuildingsInk
        let h1 = Self.podiumTop
        shadow([iso(1.3, -1.3, 3), iso(1.44, -1.18, 3), iso(1.44, 1.36, 3), iso(1.3, 1.3, 3)])
        block(-1.3, -1.3, 1.3, 1.3, 3, h1, top: .colour(I.paving), left: .colour(I.stone), right: .colour(I.stoneShade))
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -1.3 : 1.3, 1.3, at: 3) { p in
                p.courses(0, 83.2, 0, h1 - 5, course: 3.5, brick: 12)
                // The cornice, and the moulding at the foot.
                p.shape(p.panel(-0.2, h1 - 5, 83.4, h1 - 3), .colour(I.stoneTop), width: 0.6)
                p.line([p.uv(0, 1.4), p.uv(83.2, 1.4)], width: 0.6, opacity: 0.8)
            }
        }
    }

    /// The temple's six columns at the front and one at the side, the farther first.
    private static let columns: [(Double, Double)] = {
        var places: [(Double, Double)] = [(0.8, 0.8)]
        for i in 0..<6 { places.append((-0.8 + Double(i) * 0.32, 1.12)) }
        return places.sorted { ($0.0 + $0.1, $0.0) < ($1.0 + $1.1, $1.0) }
    }()

    private mutating func temple() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Self.cella
        let h0 = Self.podiumTop, h1 = Self.capitals
        // The cella: walls of dressed stone.
        shadow([iso(x1, y0, h0), iso(x1 + 0.22, y0 + 0.14, h0), iso(x1 + 0.22, 1.22, h0), iso(x1, 1.22, h0)])
        block(x0, y0, x1, y1, h0, h1, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        let side = (y1 - y0) * 32, front = (x1 - x0) * 32
        wall(.right, from: x1, y1, at: h0) { p in
            p.courses(0, side, 0, h1 - h0)
            // Pilasters dividing the wall in three bays: a banner, a window, a banner.
            let bay = (side - 3) / 3
            for i in 0...3 {
                let u = Double(i) * bay
                p.shape(p.panel(u, 0, u + 3, h1 - h0), .colour(I.light), width: 0.7)
                p.shape(p.panel(u - 0.5, h1 - h0 - 2.2, u + 3.5, h1 - h0), .colour(I.plasterTop), width: 0.6)
            }
            p.hanging(3 + bay * 0.5 - 1.5, top: h1 - h0 - 4, width: 8, length: 19)
            p.hanging(3 + bay * 2.5 - 1.5, top: h1 - h0 - 4, width: 8, length: 19)
            p.grille(3 + bay * 1.5 - 4.5, 16, w: 6, h: 9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, front, 0, h1 - h0)
            p.archedDoor(front / 2, 0, w: 12, h: 21)
            p.grille(8, 17, w: 5, h: 8)
            p.grille(front - 13, 17, w: 5, h: 8)
        }
        // The porch's ceiling throws the front wall into shade.
        shadow([iso(x0, y1, h0), iso(x1, y1, h0), iso(x1, y1, h1), iso(x0, y1, h1)], opacity: 0.16)
        // The porch's floor, a shade on it, and the columns.
        shadow([iso(x0, y1, h0), iso(x1, y1, h0), iso(x1, y1 + 0.3, h0), iso(x0, y1 + 0.3, h0)], opacity: 0.1)
        for (x, y) in Self.columns { column(at: iso(x, y, h0), height: h1 - h0, radius: 2.4) }
        // The entablature: architrave, a frieze of triglyphs, and the cornice.
        let (e0, e1, f0, f1) = (-0.92, 0.92, -1.22, 1.22)
        block(e0, f0, e1, f1, h1, h1 + 6, top: nil, left: .colour(I.light), right: .colour(I.plasterShade), width: 1.1)
        for wallSide in [IronOldBuildingsSide.left, .right] {
            let length = wallSide == .left ? (e1 - e0) * 32 : (f1 - f0) * 32
            wall(wallSide, from: wallSide == .left ? e0 : e1, f1, at: h1) { p in
                p.line([p.uv(0, 2.6), p.uv(length, 2.6)], width: 0.6)
                var u = 2.0
                while u < length - 2 {
                    for k in 0..<3 { p.line([p.uv(u + Double(k) * 0.8, 3.1), p.uv(u + Double(k) * 0.8, 5.4)], width: 0.4) }
                    u += 5.2
                }
            }
        }
        gabledRoof(e0, f0, e1, f1, eaves: h1 + 6, rise: 21, overhang: 0.05)
        // The flight of steps to the porch, and the court's furniture.
        flight(-0.82, 0.82, foot: 1.5, 3, head: 1.3, h0, steps: 5)
        brazier(at: iso(-1.0, 1.44, 3))
        brazier(at: iso(1.0, 1.42, 3))
        vexillum(at: iso(-1.36, 1.36, 3), height: 46)
        vexillum(at: iso(1.36, -1.36, 3), height: 46)
    }

    /// A column being raised: the first drums of its shaft set on its base.
    private mutating func stump(at foot: P, height: Double, radius r: Double) {
        typealias I = IronOldBuildingsInk
        let top = foot - P(0, height)
        shape([foot + P(-r * 1.4, 0), foot + P(r * 1.4, 0), foot + P(r * 1.15, -1.8), foot + P(-r * 1.15, -1.8)],
              .colour(I.rawStone), width: 0.7)
        colour([foot + P(-r, -1.8), foot + P(r, -1.8), top + P(r, 0), top + P(-r, 0)], .colour(I.rawStone))
        colour([foot + P(r * 0.3, -1.8), foot + P(r, -1.8), top + P(r, 0), top + P(r * 0.3, 0)], .colour(I.rawStoneShade))
        line([foot + P(-r, -1.8), top + P(-r, 0)], width: 0.8)
        line([foot + P(r, -1.8), top + P(r, 0)], width: 0.8)
        var joints = PathData()
        var v = 1.8 + 6.5
        while v < height - 1 { joints.move(foot + P(-r, -v)); joints.line(foot + P(r, -v)); v += 6.5 }
        svg.path(joints, stroke: .colour(I.line), width: 0.5, opacity: 0.8)
        svg.ellipse(top, r, r * 0.42, fill: .colour(I.rawStoneTop), stroke: .colour(I.line), width: 0.7)
    }

    /// The temple being built: the podium and its steps finished, the cella's
    /// walls half raised in fresh stone inside scaffolding, the first columns
    /// standing and the rest begun, and a hoist lifting a block; stone, column
    /// drums and roof tiles to hand on the court.
    private mutating func templeRising() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Self.cella
        let h0 = Self.podiumTop, top = 29.0
        // Scaffolding at the back, behind the walls.
        scaffold([(x0 - 0.12, y0 - 0.1), (0, y0 - 0.1), (x1 + 0.12, y0 - 0.1)], from: h0, height: 30, levels: [12, 24])
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.08, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.paving)) { p in
            p.blocks(-0.5, -0.9, -0.2, -0.6, from: h0, courses: 2)
            p.basket(at: p.iso(0.3, -0.5, h0), size: 0.9)
        }
        let side = (y1 - y0) * 32, front = (x1 - x0) * 32
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, side, 0, top - h0) }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, front, 0, top - h0)
            p.shape(p.panel(front / 2 - 6, 0, front / 2 + 6, top - h0), .colour(I.dark), width: 1)
        }
        // The next course, begun along the back.
        blocks(x0, y0, x0 + 0.1, y0 + 0.8, from: top, courses: 1)
        blocks(x0 + 0.1, y0, 0.1, y0 + 0.1, from: top, courses: 1)
        // Scaffolding along the side wall, flying the owner's pennant.
        scaffold([(x1 + 0.14, 0.4), (x1 + 0.14, -0.4), (x1 + 0.14, -1.15)], from: h0, height: 30, levels: [12, 24], boards: 12)
        pennant(at: iso(x1 + 0.14, 0.4, h0 + 30), height: 12, length: 15)
        // The columns: two standing whole, the rest begun.
        let heights: [Double] = [32, 14, 8, 0, 32, 20, 6]
        for ((x, y), height) in zip(Self.columns, heights) {
            if height >= 32 {
                column(at: iso(x, y, h0), height: Self.capitals - h0, radius: 2.4)
            } else if height > 0 {
                stump(at: iso(x, y, h0), height: height, radius: 2.4)
            }
        }
        // The hoist on the porch, lifting a block to the wall.
        shearLegs(iso(-0.62, 1.22, h0), iso(-0.3, 1.0, h0), head: iso(-0.5, 0.78, h0 + 40), drop: 14)
        flight(-0.82, 0.82, foot: 1.5, 3, head: 1.3, h0, steps: 5)
        // Stone, drums and tiles on the court.
        roofTiles(1.33, -1.0, 1.47, -0.55, from: 3, height: 7)
        drum(1.0, 1.32, 1.4, on: 3, radius: 2.6)
        drum(-1.45, -1.12, 1.4, on: 3, radius: 2.6)
        blocks(1.33, 0.2, 1.47, 0.6, from: 3, courses: 2)
    }
}
