// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age stone wall: one tile of a wall of dressed stone, taller and
// heavier than the Bronze age's palisade, on a footing of darker stone, with a
// band of the owner's colour under its coping and a merlon on its walkway. The
// key names no neighbours, so the tile joins its neighbours whichever way a row
// runs, as the palisade does: the wall fills the tile to its edges, its courses
// and joints repeat every tile, its corners are left without an upright line,
// and its one merlon stands square in the middle of the tile, so that a row of
// tiles shows merlons and gaps of about equal width along its top, evenly
// spaced across the joints, whichever way it runs. (Merlons at the tile's
// quarters were tried, and a row of them read as a tray of blocks.) Its
// footprint is one tile: x and y run from -0.5 to 0.5.

extension IronNewBuildingsPainter {
    mutating func stoneWall(complete: Bool) {
        if complete {
            wallBody(height: 38, finished: true)
            merlon(0, 0, on: 38)
        } else {
            wallBody(height: 13, finished: false)
            wallRising()
        }
    }


    /// The wall's body, filling the tile from the ground to `height`: dressed
    /// stone in courses on a darker footing, and, when `finished`, a coping and
    /// a band of the owner's colour beneath it.
    private mutating func wallBody(height h: Double, finished: Bool) {
        typealias I = IronNewBuildingsInk
        let e = 0.5
        colour([iso(-e, e, 0), iso(e, e, 0), iso(e, e, h), iso(-e, e, h)], .colour(I.stone))
        colour([iso(e, e, 0), iso(e, -e, 0), iso(e, -e, h), iso(e, e, h)], .colour(I.stoneShade))
        // The walkway along the top, worn darker than the faces of the coping.
        colour(level(-e, -e, e, e, h), .colour(finished ? I.walkway : I.stoneTop))
        let brick = 32.0 / 3
        for side in [IronNewBuildingsSide.left, .right] {
            wall(side, from: side == .left ? -e : e, e, at: 0) { p in
                // The footing: a course of darker, larger stones.
                p.colour(p.panel(0, 0, 32, 5), .colour(side == .left ? I.stoneShade : I.stoneDark))
                p.line([p.uv(0, 5), p.uv(32, 5)], width: 0.6, opacity: 0.8)
                for u in [8.0, 24.0] { p.line([p.uv(u, 0.4), p.uv(u, 4.6)], width: 0.5, opacity: 0.6) }
                p.courses(0, 32, 5, finished ? h - 4 : h, course: 4.6, brick: brick, phase: -brick / 4)
                // Chisel marks on a few faces, the same on every tile.
                for (u, v) in [(4.0, 8.0), (19.0, 12.6), (12.0, 21.8), (27.0, 17.2)] where v < h - 5 {
                    p.line([p.uv(u, v), p.uv(u + 1.6, v + 1.2)], width: 0.4, opacity: 0.5)
                    p.line([p.uv(u + 1.4, v - 0.2), p.uv(u + 3, v + 1)], width: 0.4, opacity: 0.5)
                }
                if finished {
                    // The coping, standing a little proud, and the owner's band beneath it.
                    p.colour(p.panel(0, h - 4, 32, h), .colour(side == .left ? I.stoneTop : I.stone))
                    p.line([p.uv(0, h - 4), p.uv(32, h - 4)], width: 0.7)
                    p.paintedBand(0, 32, h - 9.6, h - 6.4)
                }
            }
        }
        line([iso(-e, e, 0), iso(e, e, 0), iso(e, -e, 0)], width: 1.2)
        line([iso(-e, e, h), iso(e, e, h), iso(e, -e, h)], width: 1)
        line([iso(-e, e, h), iso(-e, -e, h), iso(e, -e, h)], width: 0.6, opacity: 0.6)
    }

    /// A merlon standing on the wall's top at (x, y): a block of dressed stone in courses, with a low pointed cap.
    private mutating func merlon(_ x: Double, _ y: Double, on h: Double) {
        typealias I = IronNewBuildingsInk
        let s = 0.27, rise = 12.0
        shadow([iso(x + s, y - s, h), iso(x + s + 0.16, y - s + 0.06, h), iso(x + s + 0.16, y + s + 0.06, h), iso(x + s, y + s, h)],
               opacity: 0.16)
        block(x - s, y - s, x + s, y + s, h, h + rise, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.9)
        wall(.left, from: x - s, y + s, at: h) { p in p.courses(0, 2 * s * 32, 0, rise, course: 3.7, brick: 32.0 / 3, phase: -8 / 3) }
        wall(.right, from: x + s, y + s, at: h) { p in p.courses(0, 2 * s * 32, 0, rise, course: 3.7, brick: 32.0 / 3, phase: -8 / 3) }
        // A cap cut to a low point, lit on its left.
        let apex = iso(x, y, h + rise + 2.6)
        let (back, right, front, left) = (iso(x - s, y - s, h + rise), iso(x + s, y - s, h + rise), iso(x + s, y + s, h + rise),
                                          iso(x - s, y + s, h + rise))
        colour([left, front, apex], .colour(I.stoneTop))
        colour([front, right, apex], .colour(I.stone))
        colour([back, left, apex], .colour(I.plasterTop))
        line([back, left, front, right, back], closed: true, width: 0.8)
        line([left, apex, right], width: 0.7)
        line([front, apex], width: 0.6)
    }

    /// The wall being built: the next course begun along its back, a stone
    /// waiting on its top, a trough of mortar, and the owner's pennant on a
    /// pole set in the work.
    private mutating func wallRising() {
        typealias I = IronNewBuildingsInk
        let h = 13.0
        ashlar(-0.5, -0.5, 0.1, -0.05, h, h + 4.6, course: 4.6, stone: 32.0 / 3, width: 0.9)
        pennant(at: iso(-0.28, -0.3, h + 4.6), height: 26, length: 14)
        // A trough of mortar.
        block(0.05, 0.1, 0.4, 0.35, h, h + 2.6, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.8)
        colour(level(0.09, 0.14, 0.36, 0.31, h + 2.6), .colour(I.plasterShade))
        line([iso(0.12, 0.24, h + 3), iso(0.3, 0.16, h + 6.6)], width: 1)
        stones(0.18, -0.38, 0.42, -0.12, from: h, courses: 1)
        stones(-0.42, 0.12, -0.16, 0.38, from: h, courses: 1)
    }
}
