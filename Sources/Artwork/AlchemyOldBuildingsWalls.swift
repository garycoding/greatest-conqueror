// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age palisade and stone wall, each one tile that joins its
// neighbours. The key names no neighbours, so each fills its tile to the
// edges, is outlined only along the ground and the top, where a row's
// outline runs on unbroken, and repeats its features every tile, so that
// across a joint they keep the same spacing whichever way a row runs.
//
// The palisade is still timber: sharpened stakes of oak, capped with iron
// and bound with two iron bands, set in a footing of dressed stone carrying a
// band of the owner's colour. The stone wall is taller: dressed stone on a
// darker footing, a table of corbels carrying a parapet, a band of the
// owner's colour beneath it, and on the parapet one merlon pierced by a loop,
// standing square in the middle of the tile, so that a row of tiles shows
// merlons and crenels of about equal width. Each footprint is one tile: x
// and y run from -0.5 to 0.5.

extension AlchemyOldBuildingsPainter {
    // MARK: The palisade

    mutating func palisade(complete: Bool) {
        if complete {
            palisadeBank(height: 8)
            for (x, y) in Self.stakeLattice { ironShodStake(x, y, on: 8, height: 26, radius: 3.1) }
        } else {
            palisadeBank(height: 4)
            for (x, y) in Self.stakeLattice.prefix(3) { ironShodStake(x, y, on: 4, height: 26, radius: 3.1) }
            let first = Self.stakeLattice[0]
            pennant(at: iso(first.0, first.1, 30), height: 8, length: 12)
            for (k, y) in [0.14, 0.32].enumerated() { beam(-0.36 + Double(k) * 0.05, y, 0.32 + Double(k) * 0.05, y, on: 4, size: 3.4) }
            blocks(0.2, -0.32, 0.42, -0.06, from: 4, courses: 1)
        }
    }

    /// Where the stakes stand, the farthest first: three rows a third of a
    /// tile apart, each row's stakes a third of a tile apart, each row set
    /// along by a ninth of a tile from the last, so that no stake stands
    /// straight behind another on the screen.
    private static let stakeLattice: [(Double, Double)] = {
        var places: [(Double, Double)] = []
        for j in 0..<3 {
            for i in 0..<3 { places.append((Double(i - 1) / 3 + Double(j - 1) / 9, Double(j - 1) / 3)) }
        }
        return places.sorted { ($0.0 + $0.1, $0.0) < ($1.0 + $1.1, $1.0) }
    }()

    /// The footing of dressed stone filling the tile, `h` points tall.
    private mutating func palisadeBank(height h: Double) {
        typealias I = AlchemyOldBuildingsInk
        let e = 0.5
        colour([iso(-e, e, 0), iso(e, e, 0), iso(e, e, h), iso(-e, e, h)], .colour(I.stone))
        colour([iso(e, e, 0), iso(e, -e, 0), iso(e, -e, h), iso(e, e, h)], .colour(I.stoneShade))
        colour(level(-e, -e, e, e, h), .colour(I.earth))
        for side in [AlchemyOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -e : e, e, at: 0) { p in
                p.courses(0, 32, 0, h, course: h >= 6 ? h / 3 : h / 2, brick: 32.0 / 3, opacity: 0.45)
                if h >= 6 { p.paintedBand(0, 32, h / 3 + 0.9, 2 * h / 3 - 0.3) }
                p.line([p.uv(0, h - 1), p.uv(32, h - 1)], width: 0.5, opacity: 0.6)
            }
        }
        line([iso(-e, e, 0), iso(e, e, 0), iso(e, -e, 0)], width: 1.1)
    }

    /// A stake of oak at (x, y) on `h`, `height` points to its point and
    /// `radius` thick: lit on its left, its point cut in facets that show the
    /// pale wood, bound with two bands of iron.
    private mutating func ironShodStake(_ x: Double, _ y: Double, on h: Double, height: Double, radius r: Double) {
        typealias I = AlchemyOldBuildingsInk
        let foot = iso(x, y, h), shoulder = foot - P(0, height - r * 2.4), tip = foot - P(0, height)
        colour([foot + P(-r, 0), foot + P(r, 0), shoulder + P(r, 0), tip, shoulder + P(-r, 0)], .colour(I.timber))
        colour([foot + P(-r, 0), foot + P(-r * 0.2, 0), shoulder + P(-r * 0.2, 0), shoulder + P(-r, 0)], .colour(I.timberLight))
        // The facets of the point, cut fresh.
        colour([shoulder + P(-r, 0), shoulder + P(-r * 0.1, r * 0.7), tip], .colour(I.straw))
        colour([shoulder + P(-r * 0.1, r * 0.7), shoulder + P(r, 0), tip], .colour(I.strawShade))
        line([foot + P(-r, 0.4), shoulder + P(-r, 0), tip, shoulder + P(r, 0), foot + P(r, 0.4)], width: 0.9)
        line([shoulder + P(-r, 0), shoulder + P(-r * 0.1, r * 0.7), shoulder + P(r, 0)], width: 0.6)
        line([shoulder + P(-r * 0.1, r * 0.7), tip], width: 0.45, opacity: 0.7)
        for v in [4.0, height - r * 2.4 - 4] {
            let band = foot - P(0, v)
            shape([band + P(-r, 0), band + P(r, 0), band + P(r, -1.5), band + P(-r, -1.5)], .colour(I.iron), width: 0.6)
            svg.circle(band + P(r * 0.3, -0.75), 0.4, fill: .colour(I.ironLight))
        }
    }

    // MARK: The stone wall

    mutating func stoneWall(complete: Bool) {
        if complete {
            curtain(height: 34, finished: true)
            loopedMerlon(on: 38)
        } else {
            curtain(height: 14, finished: false)
            curtainRising(on: 14)
        }
    }

    /// The wall's body, filling the tile from the ground to `height`: dressed
    /// stone in courses on a darker footing and, when `finished`, a table of
    /// corbels, the owner's band, and a parapet four points tall above it.
    private mutating func curtain(height h: Double, finished: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let e = 0.5, top = finished ? h + 4 : h
        colour([iso(-e, e, 0), iso(e, e, 0), iso(e, e, top), iso(-e, e, top)], .colour(I.stone))
        colour([iso(e, e, 0), iso(e, -e, 0), iso(e, -e, top), iso(e, e, top)], .colour(I.stoneShade))
        colour(level(-e, -e, e, e, top), .colour(finished ? I.footing : I.rawStoneTop))
        let brick = 32.0 / 3
        for side in [AlchemyOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -e : e, e, at: 0) { p in
                p.colour(p.panel(0, 0, 32, 5), .colour(side == .left ? I.footing : I.footingShade))
                p.line([p.uv(0, 5), p.uv(32, 5)], width: 0.6, opacity: 0.8)
                for u in [8.0, 24.0] { p.line([p.uv(u, 0.4), p.uv(u, 4.6)], width: 0.5, opacity: 0.6) }
                p.courses(0, 32, 5, finished ? h - 7 : h, course: 4.4, brick: brick, opacity: 0.45, phase: -brick / 4)
                guard finished else { return }
                // The owner's band, then the corbel table, then the parapet.
                p.paintedBand(0, 32, h - 10.4, h - 8)
                let lit = side == .left ? I.stoneTop : I.stone
                for u in stride(from: 32.0 / 8, to: 32, by: 32.0 / 4) {
                    p.shape([p.uv(u - 1.6, h - 1.4), p.uv(u + 1.6, h - 1.4), p.uv(u + 1.6, h - 4.6), p.uv(u, h - 6.6),
                             p.uv(u - 1.6, h - 4.6)], .colour(lit), width: 0.55)
                }
                p.colour(p.panel(0, h - 1.4, 32, h + 4), .colour(lit))
                p.line([p.uv(0, h - 1.4), p.uv(32, h - 1.4)], width: 0.7)
                p.line([p.uv(0, h + 1.4), p.uv(32, h + 1.4)], width: 0.4, opacity: 0.5)
                for u in [5.33, 16, 26.67] { p.line([p.uv(u, h - 1), p.uv(u, h + 1.2)], width: 0.4, opacity: 0.5) }
            }
        }
        line([iso(-e, e, 0), iso(e, e, 0), iso(e, -e, 0)], width: 1.2)
        line([iso(-e, e, top), iso(e, e, top), iso(e, -e, top)], width: 1)
        line([iso(-e, e, top), iso(-e, -e, top), iso(e, -e, top)], width: 0.6, opacity: 0.6)
        if finished {
            // The wall-walk behind the parapet, a little lower: a dark line along its inner edge.
            line([iso(-e, e - 0.12, top), iso(e - 0.12, e - 0.12, top), iso(e - 0.12, -e, top)], width: 0.5, opacity: 0.45)
        }
    }

    /// The merlon standing square in the middle of the parapet, pierced by a
    /// loop for a gun on its two faces, under a low pointed cap.
    private mutating func loopedMerlon(on h: Double) {
        typealias I = AlchemyOldBuildingsInk
        let s = 0.25, rise = 12.0
        shadow([iso(s, -s, h), iso(s + 0.16, -s + 0.06, h), iso(s + 0.16, s + 0.06, h), iso(s, s, h)], opacity: 0.16)
        block(-s, -s, s, s, h, h + rise, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.9)
        for side in [AlchemyOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -s : s, s, at: h) { p in
                let w = 2 * s * 32
                p.courses(0, w, 0, rise, course: 4, brick: 32.0 / 3, opacity: 0.45, phase: -8 / 3)
                // A loop for a gun: a slit ending in a round.
                p.shape(p.panel(w / 2 - 0.6, 4.4, w / 2 + 0.6, rise - 2), .colour(I.dark), width: 0.5)
                p.svg.circle(p.uv(w / 2, 3.6), 1.4, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
            }
        }
        let apex = iso(0, 0, h + rise + 2.8)
        let (back, right, front, left) = (iso(-s, -s, h + rise), iso(s, -s, h + rise), iso(s, s, h + rise), iso(-s, s, h + rise))
        colour([left, front, apex], .colour(I.stoneTop))
        colour([front, right, apex], .colour(I.stone))
        colour([back, left, apex], .colour(I.plasterTop))
        line([back, left, front, right, back], closed: true, width: 0.8)
        line([left, apex, right], width: 0.7)
        line([front, apex], width: 0.6)
    }

    /// The wall being raised: the next course begun along its back, the owner's
    /// pennant on a pole set in the work, a trough of mortar and stone waiting.
    private mutating func curtainRising(on h: Double) {
        typealias I = AlchemyOldBuildingsInk
        blocks(-0.5, -0.5, 0.1, -0.06, from: h, courses: 1)
        pennant(at: iso(-0.28, -0.3, h + 4), height: 26, length: 13)
        block(0.05, 0.1, 0.4, 0.35, h, h + 2.6, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.8)
        colour(level(0.09, 0.14, 0.36, 0.31, h + 2.6), .colour(I.plasterShade))
        line([iso(0.12, 0.24, h + 3), iso(0.3, 0.16, h + 6.6)], width: 1)
        blocks(0.18, -0.38, 0.42, -0.12, from: h, courses: 1)
        blocks(-0.42, 0.12, -0.16, 0.38, from: h, courses: 1)
        // The owner's band, already painted on the finished footing.
        for side in [AlchemyOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -0.5 : 0.5, 0.5, at: 0) { p in p.paintedBand(0, 32, 7, 9.4) }
        }
    }
}
