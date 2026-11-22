// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age house: the Bronze age's whitewashed house grown into a house of
// plaster over a footing of dressed stone, under a hipped roof of red tile. A
// porch on two columns shelters a door of painted wood studded with iron; the
// windows have painted shutters or iron bars, a band in the owner's colour
// runs under the eaves, and amphorae stand in the paved yard. Its footprint is
// two tiles square: x and y run from -1 to 1.

extension IronOldBuildingsPainter {
    mutating func house(complete: Bool) {
        typealias I = IronOldBuildingsInk
        // The paved yard the house stands on.
        block(-1, -1, 1, 1, 0, 2, top: .colour(I.paving), left: .colour(I.pavingShade), right: .colour(I.pavingShade),
              width: 1)
        var joints = PathData()
        for t in stride(from: -0.75, through: 0.75, by: 0.25) {
            joints.move(iso(t, -1, 2)); joints.line(iso(t, 1, 2))
            joints.move(iso(-1, t, 2)); joints.line(iso(1, t, 2))
        }
        svg.path(joints, stroke: .colour(I.line), width: 0.4, opacity: 0.3)
        if complete { dwelling() } else { dwellingRising() }
    }

    private static let body = (x0: -0.85, y0: -0.82, x1: 0.55, y1: 0.3)
    private static let footing = 6.0

    /// A wall of the house drawn with `wall`, `length` points long and
    /// `height` tall: the stone footing, plaster above it, and the band of the
    /// owner's colour under the eaves.
    private mutating func houseWall(_ length: Double, _ height: Double) {
        typealias I = IronOldBuildingsInk
        colour(panel(0, 0, length, Self.footing), .colour(I.stone))
        courses(0, length, 0, Self.footing, course: 3, brick: 9)
        line([uv(0, Self.footing), uv(length, Self.footing)], width: 0.7)
        paintedBand(0, length, height - 5.6, height - 3.4)
    }

    private mutating func dwelling() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Self.body
        let h0 = 2.0, h1 = 30.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.26, y0 + 0.16, h0), iso(x1 + 0.26, y1 + 0.1, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, h1, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        wall(.left, from: x0, y1, at: h0) { p in
            p.houseWall(front, h1 - h0)
            // The door, under the porch, and a shuttered window either side.
            p.archedDoor(19, 0, w: 8, h: 15, paint: I.sea)
            p.shuttered(5.5, 11, w: 4.4, h: 6.4)
            p.shuttered(33.5, 11, w: 4.4, h: 6.4)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.houseWall(side, h1 - h0)
            p.grille(6, 9, w: 5, h: 7)
            p.shuttered(22.5, 11, w: 4.4, h: 6.4)
        }
        // The shade under the eaves.
        shadow([iso(x0, y1, h1 - 2.2), iso(x1, y1, h1 - 2.2), iso(x1, y1, h1), iso(x0, y1, h1)], opacity: 0.12)
        shadow([iso(x1, y1, h1 - 2.2), iso(x1, y0, h1 - 2.2), iso(x1, y0, h1), iso(x1, y1, h1)], opacity: 0.12)
        hippedRoof(x0, y0, x1, y1, eaves: h1, overhang: 0.07)
        // The porch: two columns and a roof of its own over the door.
        let (p0, p1, depth) = (-0.48, -0.1, y1 + 0.26)
        shadow([iso(p0, y1, h0), iso(p1, y1, h0), iso(p1, depth, h0), iso(p0, depth, h0)], opacity: 0.1)
        for x in [p0, p1] { column(at: iso(x, depth - 0.03, h0), height: 18.5, radius: 1.7) }
        block(p0 - 0.04, y1, p1 + 0.04, depth + 0.01, h0 + 18.5, h0 + 21, top: nil, left: .colour(I.light),
              right: .colour(I.plasterShade), width: 0.9)
        hippedRoof(p0 - 0.04, y1 + 0.02, p1 + 0.04, depth + 0.01, eaves: h0 + 21, overhang: 0.03)
        // Amphorae and a jar in the yard.
        amphora(at: iso(-0.75, 0.72, h0), size: 0.95)
        amphora(at: iso(-0.55, 0.82, h0), size: 0.85, paint: I.clayShade)
        jar(at: iso(0.72, 0.62, h0), size: 0.8)
    }

    /// The house being built: its footing laid and its walls half raised in
    /// fresh stone round the opening of the door, scaffolding, a ladder, and
    /// stone, roof tiles and timber to hand.
    private mutating func dwellingRising() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Self.body
        let h0 = 2.0, top = 17.0
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        roofTiles(-0.97, -0.97, -0.85, -0.6, from: h0, height: 6)
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.04, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.08, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.pavingShade)) { p in
            p.basket(at: p.iso(-0.3, -0.4, h0), size: 0.9)
        }
        for (side, length) in [(IronOldBuildingsSide.left, front), (.right, side)] {
            wall(side, from: side == .left ? x0 : x1, y1, at: h0) { p in
                p.colour(p.panel(0, 0, length, Self.footing), .colour(I.stone))
                p.courses(0, length, 0, Self.footing, course: 3, brick: 9)
                p.courses(0, length, Self.footing, top - h0)
                p.line([p.uv(0, Self.footing), p.uv(length, Self.footing)], width: 0.7)
                if side == .left { p.shape(p.panel(15, 0, 23, top - h0), .colour(I.dark), width: 1) }
            }
        }
        // The next course, laid along part of the back walls.
        blocks(x0, y0, x0 + 0.08, y0 + 0.7, from: top, courses: 1)
        blocks(x0 + 0.08, y0, x1 - 0.4, y0 + 0.08, from: top, courses: 1)
        // Scaffolding along the side, its tallest pole flying the owner's pennant.
        scaffold([(x1 + 0.16, 0.24), (x1 + 0.16, -0.3), (x1 + 0.16, -0.8)], from: h0, height: 27, levels: [11, 21], boards: 11)
        pennant(at: iso(x1 + 0.16, 0.24, h0 + 27), height: 11)
        ladder(foot: iso(-0.68, y1 + 0.3, h0), iso(-0.5, y1 + 0.3, h0), head: iso(-0.68, y1 + 0.02, top + 4),
               iso(-0.5, y1 + 0.02, top + 4), rungs: 5)
        logs(-0.2, 0.42, 0.75, on: h0, radius: 1.5)
        blocks(0.62, 0.55, 0.9, 0.9, from: h0, courses: 2)
        roofTiles(0.8, -0.6, 0.95, -0.2, from: h0, height: 6)
    }
}
