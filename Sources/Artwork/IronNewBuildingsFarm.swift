// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age farm: a field of ripe grain standing in rows along its furrows,
// low on its footprint, inside a fence of posts and rails with a gate at the
// front flying the owner's pennants. A small granary of timber on staddle
// stones, roofed with red tile and banded in the owner's colour, stands at the
// back corner, and a scarecrow in a tunic of the owner's colour stands in the
// grain. A farm lasts forever, so it is never drawn spent. Its footprint is
// three tiles square: x and y run from -1.5 to 1.5.

extension IronNewBuildingsPainter {
    mutating func farm(complete: Bool) {
        typealias I = IronNewBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(complete ? I.soil : I.earth), left: .colour(I.earthShade),
              right: .colour(I.earthShade), width: 1)
        if complete { field() } else { fieldMarkedOut() }
    }

    private static let fenceEdge = 1.42
    private static let granaryBox = (x0: -1.3, y0: -1.3, x1: -0.66, y1: -0.66)
    private static let gate = (x0: -0.26, x1: 0.26)
    /// Where the rows of grain run along x, from the back.
    private static let rows: [Double] = (0..<9).map { -1.2 + Double($0) * 0.3 }

    private mutating func field() {
        let e = Self.fenceEdge
        // The fence along the two sides at the back.
        fence(from: (-e, -e), to: (e, -e), posts: 7)
        fence(from: (-e, -e), to: (-e, e), posts: 7)
        // The furrows between the rows, seen where the grain leaves them open.
        furrows(Self.rows, from: -1.32, to: 1.34)
        granary(complete: true)
        for y in Self.rows {
            let start = y - 0.1 < Self.granaryBox.y1 + 0.06 ? Self.granaryBox.x1 + 0.2 : -1.26
            grainRow(from: start, to: 1.26, at: y)
            if abs(y) < 0.01 { scarecrow(at: iso(0.32, 0.16, 1.5)) }
        }
        // The fence along the two sides at the front, with the gate.
        fence(from: (-e, e), to: (Self.gate.x0, e), posts: 4)
        fence(from: (Self.gate.x1, e), to: (e, e), posts: 4)
        gateway(at: e)
        fence(from: (e, -e), to: (e, e), posts: 7)
    }

    /// Dark lines along the furrows between the rows, on the soil.
    private mutating func furrows(_ rows: [Double], from x0: Double, to x1: Double) {
        typealias I = IronNewBuildingsInk
        var d = PathData()
        for y in rows + [rows.last! + 0.3] {
            let f = y - 0.15
            d.move(iso(x0, f, 1.5)); d.line(iso(x1, f, 1.5))
        }
        svg.path(d, stroke: .colour(I.soilDark), width: 1.6)
    }

    /// One row of ripe grain along x from `x0` to `x1` at `y`: a low bank of
    /// stalks, its top lit, its side in the grain's colour, with ears along it.
    private mutating func grainRow(from x0: Double, to x1: Double, at y: Double) {
        typealias I = IronNewBuildingsInk
        let w = 0.085, h0 = 1.5, h1 = 6.5
        let top = level(x0, y - w, x1, y + w, h1)
        colour([iso(x0, y + w, h0), iso(x1, y + w, h0), iso(x1, y + w, h1), iso(x0, y + w, h1)], .colour(I.grain))
        colour([iso(x1, y + w, h0), iso(x1, y - w, h0), iso(x1, y - w, h1), iso(x1, y + w, h1)], .colour(I.grainShade))
        colour(top, .colour(I.grainLight))
        // The stalks: fine strokes down the side.
        var stalks = PathData()
        var x = x0 + 0.05
        while x < x1 - 0.02 {
            stalks.move(iso(x, y + w, h1 - 0.8)); stalks.line(iso(x - 0.01, y + w, h0 + 0.6))
            x += 0.09
        }
        svg.path(stalks, stroke: .colour(I.grainShade), width: 0.6)
        // The ears: a scalloped edge along the top of the row's side, with awns standing from it.
        let a = iso(x0, y + w, h1), b = iso(x1, y + w, h1)
        let count = max(2, Int(((b.x - a.x) / 3.2).rounded()))
        var ears = PathData()
        ears.move(a)
        var awns = PathData()
        for i in 0..<count {
            let s = a + (b - a) * (Double(i) / Double(count)), e = a + (b - a) * (Double(i + 1) / Double(count))
            let crown = (s + e) * 0.5 + P(0, -2.2)
            ears.quad(crown, e)
            awns.move(crown + P(0, 0.9)); awns.line(crown + P(0.6, -1.8))
        }
        colour(.colour(I.grainLight)) { d, o in
            d.move(a + o)
            for i in 0..<count {
                let s = a + (b - a) * (Double(i) / Double(count)), e = a + (b - a) * (Double(i + 1) / Double(count))
                d.quad((s + e) * 0.5 + P(0, -2.2) + o, e + o)
            }
            d.close()
        }
        svg.path(ears, stroke: .colour(I.line), width: 0.6)
        svg.path(awns, stroke: .colour(I.grainShade), width: 0.5)
        line([iso(x0, y - w, h1), iso(x0, y + w, h1), iso(x0, y + w, h0), iso(x1, y + w, h0), iso(x1, y - w, h0),
              iso(x1, y - w, h1), iso(x1, y + w, h1)], width: 0.8)
        line([iso(x1, y + w, h0), iso(x1, y + w, h1)], width: 0.6)
    }

    /// The gate between two taller posts on the front side at `y`, each flying the owner's pennant.
    private mutating func gateway(at y: Double) {
        typealias I = IronNewBuildingsInk
        let (x0, x1) = Self.gate
        // The gate of planks, standing open against the fence.
        wall(.left, from: x0 - 0.42, y + 0.02, at: 1.5) { p in
            let w = 12.0
            p.shape(p.panel(0, 1, w, 9.4), .colour(I.timberLight), width: 0.8)
            for u in [3.0, 6.0, 9.0] { p.line([p.uv(u, 1.2), p.uv(u, 9.2)], width: 0.45) }
            p.line([p.uv(1, 2), p.uv(w - 1, 8.4)], width: 0.8)
        }
        for x in [x0, x1] { pole(iso(x, y, 1.5), iso(x, y, 1.5 + 16), width: 2.2, colour: I.timber) }
        pole(iso(x0, y, 1.5 + 15), iso(x1, y, 1.5 + 15), width: 1.6)
        pennant(at: iso(x0, y, 17.5), height: 12, length: 14)
        pennant(at: iso(x1, y, 17.5), height: 12, length: 14)
    }

    /// The granary at the back corner: a store of timber on staddle stones,
    /// banded in the owner's colour, under a roof of red tile, with a ladder to its door.
    private mutating func granary(complete: Bool) {
        typealias I = IronNewBuildingsInk
        let (x0, y0, x1, y1) = Self.granaryBox
        let h0 = 1.5, floor = 7.0, eave = 22.0, ridge = 33.0
        shadow([iso(x1, y0, h0), iso(x1 + 0.28, y0 + 0.14, h0), iso(x1 + 0.28, y1 + 0.1, h0), iso(x1, y1, h0)])
        for (x, y) in [(x0 + 0.08, y0 + 0.08), (x1 - 0.08, y0 + 0.08), (x0 + 0.08, y1 - 0.08), (x1 - 0.08, y1 - 0.08)] {
            staddle(x, y, from: h0, to: floor - 1.5)
        }
        guard complete else {
            // The frame of its floor, laid on the stones.
            beam(x0, y1 - 0.06, x1, y1 - 0.06, on: floor - 1.5, size: 1.8)
            beam(x0, y0 + 0.08, x1, y0 + 0.08, on: floor - 1.5, size: 1.8)
            return
        }
        block(x0, y0, x1, y1, floor - 1.5, floor, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.9)
        block(x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, floor, eave, top: nil, left: .colour(I.timberLight), right: .colour(I.timber),
              width: 1)
        let width = (x1 - x0 - 0.06) * 32
        wall(.left, from: x0 + 0.03, y1 - 0.03, at: floor) { p in
            for u in stride(from: 3.0, to: width - 1, by: 3.0) { p.line([p.uv(u, 0.4), p.uv(u, eave - floor - 0.4)], width: 0.45, opacity: 0.7) }
            p.paintedBand(0, width, 2.6, 5.2)
            p.shape(p.panel(width / 2 - 3.2, 0, width / 2 + 3.2, 9), .colour(I.dark), width: 0.8)
        }
        wall(.right, from: x1 - 0.03, y1 - 0.03, at: floor) { p in
            for u in stride(from: 3.0, to: width - 1, by: 3.0) { p.line([p.uv(u, 0.4), p.uv(u, eave - floor - 0.4)], width: 0.45, opacity: 0.7) }
            p.paintedBand(0, width, 2.6, 5.2)
        }
        gabledRoof(x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, eave: eave, ridge: ridge, over: 0.07,
                   gableWall: .colour(I.timber)) { p, w, _ in
            p.svg.circle(p.uv(w / 2, 5), 1.6, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.6)
        }
        // A short ladder up to the door.
        let mid = (x0 + x1) / 2
        let feet = (iso(mid - 0.05, y1 + 0.22, h0), iso(mid + 0.05, y1 + 0.22, h0))
        pole(feet.0, iso(mid - 0.05, y1, floor + 0.6), width: 0.9)
        pole(feet.1, iso(mid + 0.05, y1, floor + 0.6), width: 0.9)
        for t in [0.33, 0.66] {
            let a = feet.0 + (iso(mid - 0.05, y1, floor + 0.6) - feet.0) * t, b = feet.1 + (iso(mid + 0.05, y1, floor + 0.6) - feet.1) * t
            svg.line([a, b], stroke: .colour(I.line), width: 0.9)
        }
        // Sheaves bound and stood against the granary.
        sheaf(at: iso(x1 + 0.12, y1 - 0.12, h0))
        sheaf(at: iso(x1 + 0.12, y1 + 0.08, h0))
    }

    /// A staddle stone at (x, y): a short pillar of stone with a wide cap, so that no rat climbs to the grain.
    private mutating func staddle(_ x: Double, _ y: Double, from h0: Double, to h1: Double) {
        typealias I = IronNewBuildingsInk
        block(x - 0.04, y - 0.04, x + 0.04, y + 0.04, h0, h1 - 1.4, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade),
              width: 0.7)
        block(x - 0.08, y - 0.08, x + 0.08, y + 0.08, h1 - 1.4, h1, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.7)
    }

    /// A sheaf of grain standing at `p` on the screen, bound at its waist.
    private mutating func sheaf(at p: P) {
        typealias I = IronNewBuildingsInk
        let outline = [p + P(-3.4, 0), p + P(-1.4, -6), p + P(-3.2, -11), p + P(0, -12.4), p + P(3.2, -11), p + P(1.4, -6), p + P(3.4, 0)]
        shape(outline, .colour(I.grain), width: 0.8)
        line([p + P(-1.6, -6), p + P(1.6, -6)], width: 1)
        line([p + P(-0.8, -1), p + P(-0.4, -5)], width: 0.4, opacity: 0.7)
        line([p + P(0.9, -1), p + P(0.5, -5)], width: 0.4, opacity: 0.7)
        svg.path("M\(num(p.x - 2.4)),\(num(p.y - 11)) l-0.8,-2 M\(num(p.x)),\(num(p.y - 12.4)) l0,-2 M\(num(p.x + 2.4)),\(num(p.y - 11)) l0.8,-2",
                 stroke: .colour(I.grainShade), width: 0.6)
    }

    /// A scarecrow standing in the grain at `p` on the screen: a post and an
    /// arm of timber, a tunic of the owner's colour, a head of sacking under a
    /// hat of straw, and straw at its cuffs.
    private mutating func scarecrow(at p: P) {
        typealias I = IronNewBuildingsInk
        pole(p, p - P(0, 30), width: 1.6, colour: I.timber)
        pole(p - P(9.6, 22), p - P(-9.6, 22), width: 1.3, colour: I.timber)
        let tunic = [p - P(5, 23.4), p - P(-5, 23.4), p - P(-6.4, 11), p - P(-2, 12.4), p - P(0, 10.6), p - P(2, 12.4),
                     p - P(6.4, 11)]
        shape(tunic, .team, width: 0.9)
        // A belt of rope, and the sleeves over the arm.
        line([p - P(5.6, 16.4), p - P(-5.6, 16.4)], width: 0.9)
        shape([p - P(5, 23.4), p - P(9, 22.8), p - P(9, 20.4), p - P(5.4, 20.6)], .team, width: 0.8)
        shape([p - P(-5, 23.4), p - P(-9, 22.8), p - P(-9, 20.4), p - P(-5.4, 20.6)], .team, width: 0.8)
        for side in [-1.0, 1.0] {
            line([p - P(side * 9, 22.6), p - P(side * 11.2, 23.4)], width: 0.6)
            line([p - P(side * 9, 21.4), p - P(side * 11.4, 21.2)], width: 0.6)
        }
        // The head: sacking, two stitched eyes and a mouth.
        let head = p - P(0, 27.4)
        svg.circle(head + P(-0.6, 0.4), 3.6, fill: .colour(I.light))
        svg.circle(head, 3.6, fill: .none, stroke: .colour(I.line), width: 0.8)
        line([head + P(-1.8, -0.8), head + P(-0.8, 0.2)], width: 0.5)
        line([head + P(-0.8, -0.8), head + P(-1.8, 0.2)], width: 0.5)
        line([head + P(0.9, -0.8), head + P(1.9, 0.2)], width: 0.5)
        line([head + P(1.9, -0.8), head + P(0.9, 0.2)], width: 0.5)
        line([head + P(-1.4, 1.8), head + P(1.6, 1.6)], width: 0.5)
        // The hat: a wide brim of straw and a rounded crown.
        let brim = head + P(0, -2.4)
        colour(.colour(I.straw)) { d, o in
            d.move(brim + P(-3, 0) + o)
            d.cubic(brim + P(-3, -4.6) + o, brim + P(3, -4.6) + o, brim + P(3, 0) + o)
            d.close()
        }
        line(width: 0.8) { d in
            d.move(brim + P(-3, 0))
            d.cubic(brim + P(-3, -4.6), brim + P(3, -4.6), brim + P(3, 0))
        }
        svg.ellipse(brim + P(-0.6, 0.5), 6.4, 1.4, fill: .colour(I.straw))
        svg.ellipse(brim, 6.4, 1.4, fill: .none, stroke: .colour(I.line), width: 0.8)
        line([brim + P(-2.8, -1.2), brim + P(2.8, -1.2)], width: 0.5, opacity: 0.8)
    }

    /// The field being marked out: the back of it ploughed in furrows, the
    /// front still beaten earth with pegs and a line stretched along the next
    /// furrow, the plough left at the end of the last, sacks of seed, the
    /// granary's stones set, the fence begun, and the owner's pennant on a stake.
    private mutating func fieldMarkedOut() {
        typealias I = IronNewBuildingsInk
        let e = Self.fenceEdge
        // The ploughed part: soil, ridged along x.
        let (px0, py0, px1, py1) = (-1.32, -1.32, 1.32, -0.1)
        colour(level(px0, py0, px1, py1, 1.5), .colour(I.soil))
        var ridges = PathData()
        for k in 0..<9 {
            let y = py0 + 0.06 + Double(k) * 0.14
            ridges.move(iso(px0 + 0.02, y, 1.5)); ridges.line(iso(k == 8 ? 0.3 : px1 - 0.02, y, 1.5))
        }
        svg.path(ridges, stroke: .colour(I.soilDark), width: 1.4)
        var lights = PathData()
        for k in 0..<8 {
            let y = py0 + 0.13 + Double(k) * 0.14
            lights.move(iso(px0 + 0.04, y, 1.5)); lights.line(iso(px1 - 0.04, y, 1.5))
        }
        svg.path(lights, stroke: .colour(I.earth), width: 0.7, opacity: 0.8)
        line(level(px0, py0, px1, py1, 1.5), closed: true, width: 0.6, opacity: 0.6)
        // The fence begun along the back.
        fence(from: (-e, -e), to: (0.2, -e), posts: 5)
        fence(from: (-e, -e), to: (-e, -0.4), posts: 4)
        granary(complete: false)
        // Pegs and lines marking out the furrows to come.
        for y in [0.2, 0.62, 1.04] {
            let a = iso(-1.2, y, 1.5), b = iso(1.2, y, 1.5)
            svg.line([a - P(0, 5), b - P(0, 5)], stroke: .colour(I.light), width: 0.7)
            for p in [a, b] {
                pole(p, p - P(0, 6.4), width: 1.1, colour: I.timberLight)
            }
        }
        // The plough at the end of the last furrow: an ard of timber with its share of iron.
        plough(at: iso(0.42, -0.18, 1.5))
        // Rails waiting for the fence, sacks of seed, and the owner's pennant.
        for (k, y) in [0.96, 1.06, 1.16].enumerated() { beam(-0.2 + Double(k) * 0.04, y, 1.0, y, on: 1.5, size: 1.6) }
        sack(at: iso(1.1, 0.42, 1.5))
        sack(at: iso(1.22, 0.58, 1.5), size: 0.9)
        sack(at: iso(-1.0, 1.1, 1.5))
        pennant(at: iso(-1.2, 0.2, 1.5), height: 26, length: 15)
    }

    /// An ard lying at `p` on the screen, its beam toward the back left and its share in the soil.
    private mutating func plough(at p: P) {
        typealias I = IronNewBuildingsInk
        pole(p + P(-2, -1), p + P(-22, -9.6), width: 1.8, colour: I.timber)
        // The yoke-pole's end, and the handle standing up from the share.
        pole(p + P(-22, -9.6), p + P(-25, -8.4), width: 1.2, colour: I.timber)
        pole(p + P(0, -1.4), p + P(4.6, -12), width: 1.4, colour: I.timberLight)
        shape([p + P(-1.6, -2.4), p + P(5, -1.2), p + P(8.2, 0.2), p + P(1, 0.6)], .colour(I.ironLight), width: 0.8)
    }
}
