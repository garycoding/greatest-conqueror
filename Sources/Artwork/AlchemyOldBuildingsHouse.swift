// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age house: the Iron age's house grown into a town house of two
// storeys. Its ground floor is of dressed stone with a door of teal plank and
// a window glazed in leaded panes; its upper floor is half-timbered in dark
// oak over plaster and jettied out over the street, with a band of the
// owner's colour along the jetty's beam. Its gable faces the street under a
// steep roof of slate with gilt finials, and a chimney of stone rises
// through the roof. Barrels and a bench stand in the cobbled yard. Its
// footprint is two tiles square: x and y run from -1 to 1.

extension AlchemyOldBuildingsPainter {
    mutating func house(complete: Bool) {
        cobbles(1, height: 2)
        if complete { townHouse() } else { townHouseRising() }
    }

    private static let ground = (x0: -0.78, y0: -0.86, x1: 0.42, y1: 0.3)
    /// How far the upper floor stands out over the lower, in tiles.
    private static let jetty = 0.07
    private static let floor = 17.0
    private static let eaves = 33.0

    /// The ground floor's wall of stone drawn with `wall`, `length` long and
    /// `height` tall: a plinth, courses, and quoins at the corner.
    private mutating func groundWall(_ length: Double, _ height: Double, quoinAtStart: Bool) {
        typealias I = AlchemyOldBuildingsInk
        colour(panel(0, 0, length, 2.6), .colour(I.footing))
        line([uv(0, 2.6), uv(length, 2.6)], width: 0.6)
        courses(0, length, 2.6, height, course: 3.6, brick: 8.4)
        quoins(at: quoinAtStart ? 0 : length, atStart: quoinAtStart, from: 2.6, to: height, course: 3.6)
    }

    private mutating func townHouse() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.ground
        let h0 = 2.0, f = Self.floor, e = Self.eaves, j = Self.jetty
        let (u1, v1) = (x1 + j, y1 + j)
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        // The ground floor, of stone.
        block(x0, y0, x1, y1, h0, f, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        wall(.left, from: x0, y1, at: h0) { p in
            p.groundWall(front, f - h0, quoinAtStart: false)
            p.door(11, 0, w: 8, h: 13)
            p.casement(22, 4.4, w: 10, h: 7, lights: 2, frame: I.stoneTop)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.groundWall(side, f - h0, quoinAtStart: true)
            p.casement(12, 4.4, w: 10, h: 7, lights: 2, frame: I.stoneTop)
        }
        // The jetty's shadow on the stone below it.
        shadow([iso(x0, y1, f - 3), iso(x1, y1, f - 3), iso(x1, y0, f - 3), iso(x1, y0, f), iso(x1, y1, f), iso(x0, y1, f)],
               opacity: 0.16)
        // The upper floor, half-timbered, standing out over the lower on the two sides that face the street.
        block(x0, y0, u1, v1, f, e, top: nil, left: .colour(I.light), right: .colour(I.plasterShade))
        let upperFront = (u1 - x0) * 32, upperSide = (v1 - y0) * 32
        wall(.left, from: x0, v1, at: f) { p in
            p.framing(upperFront, from: 0, to: e - f, posts: [1, 10, 20.5, 31, upperFront - 1], rail: 9,
                      braces: [(0, true), (3, false)])
            p.casement(12.4, 5, w: 6.4, h: 7, lights: 1)
            p.casement(22.9, 5, w: 6.4, h: 7, lights: 1)
            p.paintedBand(0, upperFront, 0.4, 2.6)
        }
        wall(.right, from: u1, v1, at: f) { p in
            p.framing(upperSide, from: 0, to: e - f, posts: [1, 13, 27, upperSide - 1], rail: 9, braces: [(0, true), (2, false)])
            p.casement(16, 5, w: 8, h: 7, lights: 2)
            p.paintedBand(0, upperSide, 0.4, 2.6)
        }
        // The jetty's beam ends showing under the upper floor.
        for k in 0..<5 {
            let x = x0 + 0.06 + Double(k) * (u1 - x0 - 0.12) / 4
            shape([iso(x - 0.02, v1, f), iso(x + 0.02, v1, f), iso(x + 0.02, v1, f - 1.6), iso(x - 0.02, v1, f - 1.6)], .colour(I.oak),
                  width: 0.5)
        }
        // The roof, its gable to the street.
        let ridge = e + 26
        gableAlongY(x0, y0, u1, v1, eave: e, ridge: ridge, over: 0.06, gableWall: .colour(I.light)) { p, w, rise in
            // King post, collar and braces, and a small window in the apex.
            p.timber(p.uv(w / 2, 0), p.uv(w / 2, rise - 1.5), width: 2)
            p.timber(p.uv(w * 0.22, rise * 0.4), p.uv(w * 0.78, rise * 0.4), width: 1.8)
            p.timber(p.uv(w * 0.1, 0.6), p.uv(w * 0.44, rise * 0.4 - 0.8), width: 1.6)
            p.timber(p.uv(w * 0.9, 0.6), p.uv(w * 0.56, rise * 0.4 - 0.8), width: 1.6)
            p.casement(w / 2 - 3, rise * 0.4 + 2.4, w: 6, h: 6, lights: 1)
            p.timber(p.uv(0, 1), p.uv(w, 1), width: 2)
        }
        // The chimney of stone, rising through the roof's lit slope, with two pots.
        let (cx0, cy0, cx1, cy1) = (0.2, -0.62, 0.36, -0.46)
        let foot = e + (ridge - e) * ((u1 + 0.06) - (cx0 + cx1) / 2) / ((u1 + 0.06) - (x0 + u1) / 2) - 2
        block(cx0, cy0, cx1, cy1, foot, ridge + 1, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade),
              width: 0.9)
        wall(.left, from: cx0, cy1, at: foot) { p in p.courses(0, 5.1, 0, ridge + 1 - foot, course: 3.2, brick: 5.1, opacity: 0.5) }
        block(cx0 - 0.02, cy0 - 0.02, cx1 + 0.02, cy1 + 0.02, ridge + 1, ridge + 2.6, top: .colour(I.stoneTop),
              left: .colour(I.stoneTop), right: .colour(I.stone), width: 0.8)
        for (x, y) in [(cx0 + 0.04, cy0 + 0.05), (cx1 - 0.04, cy1 - 0.04)] {
            let p = iso(x, y, ridge + 2.6)
            shape([p + P(-1.5, 0), p + P(1.5, 0), p + P(1.1, -3.4), p + P(-1.1, -3.4)], .colour(I.clay), width: 0.6)
        }
        // Barrels and a bench in the yard.
        barrel(at: iso(-0.88, 0.62, h0), size: 0.85)
        barrel(at: iso(-0.66, 0.8, h0), size: 0.8)
        bench(at: (0.12, 0.62), on: h0)
        sack(at: iso(0.78, 0.5, h0), size: 0.8)
    }

    /// A bench of oak standing along x at (x, y) on `h`.
    private mutating func bench(at place: (Double, Double), on h: Double) {
        typealias I = AlchemyOldBuildingsInk
        let (x, y) = place
        for dx in [-0.16, 0.16] { pole(iso(x + dx, y, h), iso(x + dx, y, h + 4), width: 1.1, colour: I.oak) }
        block(x - 0.22, y - 0.05, x + 0.22, y + 0.05, h + 4, h + 5.4, top: .colour(I.timberLight), left: .colour(I.timber),
              right: .colour(I.timberDark), width: 0.7)
    }

    /// The house being built: its ground floor raised in fresh stone round the
    /// door's opening, the oak frame of the upper floor standing on it with
    /// its posts, plates and braces but no plaster yet, scaffolding with the
    /// owner's pennant, a ladder, and slates, timber and mortar to hand.
    private mutating func townHouseRising() {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.ground
        let h0 = 2.0, f = Self.floor, e = Self.eaves
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        slates(-0.96, -0.96, -0.82, -0.6, from: h0, height: 6)
        // The frame's posts and plate at the back, behind the stone.
        for x in [x0 + 0.04, -0.18, x1 - 0.04] { pole(iso(x, y0 + 0.04, f), iso(x, y0 + 0.04, e), width: 2, colour: I.oak) }
        pole(iso(x0 + 0.04, y0 + 0.04, e), iso(x1 - 0.04, y0 + 0.04, e), width: 2, colour: I.oak)
        pole(iso(x0 + 0.04, y0 + 0.04, e), iso(x0 + 0.04, y1 - 0.04, e), width: 2, colour: I.oak)
        shadow([iso(x1, y0, h0), iso(x1 + 0.18, y0 + 0.1, h0), iso(x1 + 0.18, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: f, thickness: 0.08, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.pavingShade)) { p in
            p.basket(at: p.iso(-0.3, -0.4, h0), size: 0.9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, front, 0, f - h0, course: 3.6, brick: 8.4)
            p.shape(p.panel(7, 0, 15, f - h0), .colour(I.dark), width: 1)
            p.shape(p.panel(6, f - h0 - 2, 16, f - h0), .colour(I.oak), width: 0.7)
        }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, side, 0, f - h0, course: 3.6, brick: 8.4) }
        // The frame of the upper floor at the front: sill, posts, a brace, and part of its plate.
        pole(iso(x0, y1 - 0.02, f), iso(x1, y1 - 0.02, f), width: 2.2, colour: I.oak)
        pole(iso(x1 - 0.02, y1, f), iso(x1 - 0.02, y0, f), width: 2.2, colour: I.oak)
        for x in [x0 + 0.04, -0.4, -0.08, x1 - 0.04] { pole(iso(x, y1 - 0.04, f), iso(x, y1 - 0.04, e), width: 2, colour: I.oak) }
        for y in [-0.3] { pole(iso(x1 - 0.04, y, f), iso(x1 - 0.04, y, e), width: 2, colour: I.oak) }
        pole(iso(x0 + 0.04, y1 - 0.04, e), iso(-0.08, y1 - 0.04, e), width: 2, colour: I.oak)
        pole(iso(x1 - 0.04, y1 - 0.04, e), iso(x1 - 0.04, -0.3, e), width: 2, colour: I.oak)
        pole(iso(x0 + 0.06, y1 - 0.04, f + 1), iso(-0.4, y1 - 0.04, e - 2), width: 1.5, colour: I.oak)
        pole(iso(x1 - 0.04, y1 - 0.06, f + 1), iso(x1 - 0.04, -0.3, e - 2), width: 1.5, colour: I.oak)
        // Scaffolding along the side, its tallest pole flying the owner's pennant.
        scaffold([(x1 + 0.18, 0.26), (x1 + 0.18, -0.3), (x1 + 0.18, -0.8)], from: h0, height: 34, levels: [13, 26], boards: 13)
        pennant(at: iso(x1 + 0.18, 0.26, h0 + 34), height: 11, length: 13)
        ladder(foot: iso(-0.62, y1 + 0.32, h0), iso(-0.46, y1 + 0.32, h0), head: iso(-0.62, y1 + 0.02, f + 5),
               iso(-0.46, y1 + 0.02, f + 5), rungs: 5)
        timbers(-0.3, 0.5, length: 0.66, on: h0)
        blocks(0.62, 0.55, 0.9, 0.86, from: h0, courses: 2)
        slates(0.72, -0.5, 0.88, -0.16, from: h0, height: 6)
        basket(at: iso(0.66, 0.3, h0), size: 0.9)
    }
}
