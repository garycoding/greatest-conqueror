// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age palisade: one tile of a wall of sharpened stakes, bound with
// bronze, set in a bank of mud brick that carries a band of the owner's colour.
// The key names no neighbours, so the tile joins its neighbours whichever way a
// row runs: the bank fills the tile to its edges and is outlined only along the
// ground, where a row's outline runs on unbroken, and the stakes repeat every
// tile, so that across a joint they keep the same spacing. Its footprint is
// one tile: x and y run from -0.5 to 0.5.

extension BronzeBuildingsPainter {
    mutating func palisade(complete: Bool) {
        if complete {
            bank(height: 7)
            for (x, y) in Self.stakeLattice { stake(x, y, on: 7, height: 25, radius: 3.2, bound: true) }
        } else {
            bank(height: 3.5)
            // Three stakes set, the rest lying ready, and the owner's pennant on the first.
            for (x, y) in Self.stakeLattice.prefix(3) { stake(x, y, on: 3.5, height: 25, radius: 3.2, bound: true) }
            let first = Self.stakeLattice[0]
            pennant(at: iso(first.0, first.1, 28.5), height: 8, length: 13)
            log(-0.36, 0.3, 0.12, on: 3.5, radius: 2.4)
            log(-0.3, 0.36, 0.3, on: 3.5, radius: 2.4)
            basket(at: iso(0.3, -0.12, 3.5), size: 0.8)
        }
    }

    /// Where the stakes stand, the farthest first: three rows a third of a tile
    /// apart, each row's stakes a third of a tile apart, so that the spacing
    /// holds across the joint with the next tile. Each row is set along by a
    /// ninth of a tile from the last, so that no stake stands straight behind
    /// another on the screen, where its point would fall on the nearer stake.
    private static let stakeLattice: [(Double, Double)] = {
        var places: [(Double, Double)] = []
        for j in 0..<3 {
            for i in 0..<3 { places.append((Double(i - 1) / 3 + Double(j - 1) / 9, Double(j - 1) / 3)) }
        }
        return places.sorted { ($0.0 + $0.1, $0.0) < ($1.0 + $1.1, $1.0) }
    }()

    /// The bank of mud brick, filling the tile: plastered faces with brick
    /// showing in courses, a band of the owner's colour, and a beaten top. Only
    /// its foot is outlined, so that tiles in a row show no joints.
    private mutating func bank(height h: Double) {
        typealias I = BronzeBuildingsInk
        let e = 0.5
        colour([iso(-e, e, 0), iso(e, e, 0), iso(e, e, h), iso(-e, e, h)], .colour(I.sand))
        colour([iso(e, e, 0), iso(e, -e, 0), iso(e, -e, h), iso(e, e, h)], .colour(I.sandShade))
        colour(level(-e, -e, e, e, h), .colour(I.earth))
        for side in [BronzeBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -e : e, e, at: 0) { p in
                p.courses(0, 32, 0, h, course: 2.4, brick: 8, opacity: 0.45)
                if h >= 6 { p.paintedBand(0, 32, 2.6, 4.6) }
            }
        }
        line([iso(-e, e, 0), iso(e, e, 0), iso(e, -e, 0)], width: 1.1)
    }

    /// A stake as `stake` draws it, with a band of bronze below its point when `bound`.
    private mutating func stake(_ x: Double, _ y: Double, on h: Double, height: Double, radius r: Double, bound: Bool) {
        typealias I = BronzeBuildingsInk
        stake(x, y, on: h, height: height, radius: r)
        if bound {
            let band = iso(x, y, h + height - r * 1.8 - 3.2)
            shape([band + P(-r, 0), band + P(r, 0), band + P(r, -1.6), band + P(-r, -1.6)], .colour(I.bronzeLight), width: 0.6)
        }
    }
}
