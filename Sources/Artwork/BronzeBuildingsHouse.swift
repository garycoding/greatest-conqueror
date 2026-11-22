// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age house: the whitewashed house of the approved scene
// (docs/art/cartoon-modern-scene-1.png) seen from the game's angle. A house of
// mud brick under lime plaster with a scalloped parapet, a door of verdigris,
// small dark windows, the ends of its roof beams, a band in the owner's colour,
// a ladder to the roof, a shade of reed on the roof, and jars by the door. Its
// footprint is two tiles square: x and y run from -1 to 1.

extension BronzeBuildingsPainter {
    mutating func house(complete: Bool) {
        typealias I = BronzeBuildingsInk
        // The plastered yard the house stands on.
        block(-1, -1, 1, 1, 0, 2, top: .colour(I.paving), left: .colour(I.pavingShade), right: .colour(I.pavingShade),
              width: 1)
        if complete { dwelling() } else { dwellingRising() }
    }

    private mutating func dwelling() {
        typealias I = BronzeBuildingsInk
        let (x0, y0, x1, y1) = (-0.8, -0.8, 0.5, 0.5)
        let h0 = 2.0, h1 = 34.0, roof = 31.0, length = 41.6
        shadow([iso(x1, y0, h0), iso(x1 + 0.24, y0 + 0.14, h0), iso(x1 + 0.24, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: roof, to: h1, thickness: 0.07, lit: .colour(I.light),
              shade: .colour(I.plasterShade), top: .colour(I.plasterTop), ground: .colour(I.sand)) { p in
            // The parapet's scallops at the back, then the shade of reed on the roof with a jar beneath it.
            p.scallops(p.iso(x0, y1, h1), p.iso(x0, y0, h1), count: 6, rise: 1.4, .colour(I.plasterShade))
            p.scallops(p.iso(x0, y0, h1), p.iso(x1, y0, h1), count: 6, rise: 1.4, .colour(I.light))
            let (s0, s1, top) = (x0 + 0.13, x0 + 0.66, roof + 13)
            p.pole(p.iso(s0, s0, roof), p.iso(s0, s0, top), width: 1.1)
            p.pole(p.iso(s1, s0, roof), p.iso(s1, s0, top), width: 1.1)
            p.pole(p.iso(s0, s1, roof), p.iso(s0, s1, top), width: 1.1)
            p.jar(at: p.iso(x0 + 0.42, y0 + 0.3, roof), size: 0.8, paint: I.clay)
            p.thatch(p.level(s0 - 0.09, s0 - 0.09, s1 + 0.09, s1 + 0.09, top), thickness: 2.2)
            p.pole(p.iso(s1, s1, roof), p.iso(s1, s1, top), width: 1.1)
        }
        // The front of the house.
        wall(.left, from: x0, y1, at: h0) { p in
            p.plasterWall(length)
            // The door, under a lintel of timber, and the mark painted beside it.
            p.shape(p.panel(23, 0, 31.4, 15.2), .colour(I.verdigris), width: 1)
            p.line([p.uv(27.2, 0.6), p.uv(27.2, 14.4)], width: 0.6)
            p.svg.circle(p.uv(29.4, 7.4), 0.8, fill: .colour(I.bronzeLight), stroke: .colour(I.line), width: 0.4)
            p.shape(p.panel(21.4, 15.2, 33, 17.2), .colour(I.timber), width: 0.8)
            p.line([p.uv(10, 9), p.uv(12, 12), p.uv(14, 9), p.uv(16, 12), p.uv(18, 9)], width: 0.8)
            p.shape(p.panel(7, 17.6, 11.6, 22.2), .colour(I.dark), width: 0.8)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.plasterWall(length)
            p.shape(p.panel(9, 16.6, 13.6, 21.2), .colour(I.dark), width: 0.8)
            p.shape(p.panel(27.4, 16.6, 32, 21.2), .colour(I.dark), width: 0.8)
            p.line([p.uv(8, 16.6), p.uv(14.6, 16.6)], width: 1)
            p.line([p.uv(26.4, 16.6), p.uv(33, 16.6)], width: 1)
        }
        scallops(iso(x0, y1, h1), iso(x1, y1, h1), count: 6, rise: 1.4, .colour(I.light))
        scallops(iso(x1, y1, h1), iso(x1, y0, h1), count: 6, rise: 1.4, .colour(I.plasterShade))
        // A ladder up to the roof, and jars in the yard.
        ladder(foot: iso(x1 + 0.34, -0.3, h0), iso(x1 + 0.34, -0.1, h0), head: iso(x1 + 0.02, -0.3, h1 + 5),
               iso(x1 + 0.02, -0.1, h1 + 5), rungs: 7)
        jar(at: iso(-0.62, 0.74, h0), size: 1.1)
        jar(at: iso(-0.36, 0.8, h0), size: 0.8, paint: I.clay)
    }

    /// A plastered wall drawn with `wall`, `length` points long: mud showing
    /// along its foot, the band of the owner's colour high on it, and the ends
    /// of the roof's beams above the band.
    private mutating func plasterWall(_ length: Double) {
        typealias I = BronzeBuildingsInk
        colour(panel(0, 0, length, 2.4), .colour(I.sand))
        line([uv(0, 2.4), uv(length, 2.4)], width: 0.6)
        colour(panel(0, 23.4, length, 25.8), .team)
        line([uv(0, 23.4), uv(length, 23.4)], width: 0.7)
        line([uv(0, 25.8), uv(length, 25.8)], width: 0.7)
        var u = 3.4
        while u < length - 2 {
            svg.ellipse(uv(u, 27.6) + P(-0.4, 0.3), 1.2, 1.1, fill: .colour(I.timberLight))
            svg.ellipse(uv(u, 27.6), 1.2, 1.1, fill: .none, stroke: .colour(I.line), width: 0.6)
            u += 5.8
        }
    }

    /// The house being built: walls of bare mud brick half raised round the
    /// opening of the door, scaffolding, a ladder, and bricks and beams to hand.
    private mutating func dwellingRising() {
        typealias I = BronzeBuildingsInk
        let (x0, y0, x1, y1) = (-0.8, -0.8, 0.5, 0.5)
        let h0 = 2.0, top = 17.0, length = 41.6
        // Bricks and the roof's beams waiting at the back of the yard.
        bricks(-0.97, -0.97, -0.83, -0.55, from: h0, courses: 3)
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.04, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.09, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.rawBrickTop), ground: .colour(I.pavingShade)) { p in
            p.basket(at: p.iso(-0.2, -0.3, h0), size: 0.9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, length, 0, top - h0)
            // The doorway, open to the top of the wall so far.
            p.shape(p.panel(23, 0, 31.4, top - h0), .colour(I.dark), width: 1)
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.courses(0, length, 0, top - h0)
        }
        // The next course, laid along part of the back walls.
        bricks(x0, y0, x0 + 0.09, y0 + 0.75, from: top, courses: 2)
        bricks(x0 + 0.09, y0, x1 - 0.35, y0 + 0.09, from: top, courses: 2)
        // Scaffolding along the side, its tallest pole flying the owner's pennant.
        scaffold([(x1 + 0.16, 0.42), (x1 + 0.16, -0.12), (x1 + 0.16, -0.66)], from: h0, height: 27, levels: [11, 21],
                 boards: 11)
        pennant(at: iso(x1 + 0.16, 0.42, h0 + 27), height: 11)
        ladder(foot: iso(-0.62, y1 + 0.3, h0), iso(-0.44, y1 + 0.3, h0), head: iso(-0.62, y1 + 0.02, top + 4),
               iso(-0.44, y1 + 0.02, top + 4), rungs: 5)
        logs(-0.2, 0.42, 0.82, on: h0, radius: 1.5)
        bricks(0.62, 0.62, 0.9, 0.9, from: h0, courses: 3)
    }
}
