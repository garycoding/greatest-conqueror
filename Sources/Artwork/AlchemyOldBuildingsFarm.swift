// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age farm: the Iron age's field of ripe grain standing in rows
// along its furrows, low on its footprint, inside a fence of oak posts and
// rails with a gate at the front flying the owner's pennants. At the back
// corner a granary half-timbered in oak stands on staddle stones under a
// steep roof of slate with a gilt finial, banded in the owner's colour, with
// sheaves stood against it; a scarecrow in a tunic of the owner's colour
// stands in the grain. A farm lasts forever, so it is never drawn spent. Its
// footprint is three tiles square: x and y run from -1.5 to 1.5.

/// The colours of the field: ploughed soil, and the ripe grain.
private enum AlchemyOldBuildingsField {
    static let soil = "#8d6243"
    static let soilDark = "#6e4a32"
    static let grain = "#dcb253"
    static let grainLight = "#ecd083"
    static let grainShade = "#b48a36"
}

extension AlchemyOldBuildingsPainter {
    mutating func farm(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(complete ? AlchemyOldBuildingsField.soil : I.earth),
              left: .colour(I.earthShade), right: .colour(I.earthShade), width: 1)
        if complete { grainField() } else { fieldMarkedOut() }
    }

    private static let fieldFence = 1.42
    private static let granaryBox = (x0: -1.3, y0: -1.3, x1: -0.66, y1: -0.66)
    private static let fieldGate = (x0: -0.26, x1: 0.26)
    /// Where the rows of grain run along x, from the back.
    private static let grainRows: [Double] = (0..<9).map { -1.2 + Double($0) * 0.3 }

    private mutating func grainField() {
        let e = Self.fieldFence
        railFence(from: (-e, -e), to: (e, -e), posts: 7)
        railFence(from: (-e, -e), to: (-e, e), posts: 7)
        furrows(Self.grainRows, from: -1.32, to: 1.34)
        granary(complete: true)
        for y in Self.grainRows {
            let start = y - 0.1 < Self.granaryBox.y1 + 0.06 ? Self.granaryBox.x1 + 0.2 : -1.26
            grainRow(from: start, to: 1.26, at: y)
            if abs(y) < 0.01 { scarecrow(at: iso(0.32, 0.16, 1.5)) }
        }
        railFence(from: (-e, e), to: (Self.fieldGate.x0, e), posts: 4)
        railFence(from: (Self.fieldGate.x1, e), to: (e, e), posts: 4)
        fieldGateway(at: e)
        railFence(from: (e, -e), to: (e, e), posts: 7)
    }

    /// A fence of oak posts and two rails from one place on the map to another, on `h0`.
    mutating func railFence(from a: (Double, Double), to b: (Double, Double), posts: Int, on h0: Double = 1.5,
                                    height: Double = 10) {
        typealias I = AlchemyOldBuildingsInk
        for rail in [height * 0.4, height * 0.84] { pole(iso(a.0, a.1, h0 + rail), iso(b.0, b.1, h0 + rail), width: 1.2, colour: I.oakLight) }
        for k in 0..<posts {
            let t = Double(k) / Double(posts - 1)
            let x = a.0 + (b.0 - a.0) * t, y = a.1 + (b.1 - a.1) * t
            pole(iso(x, y, h0), iso(x, y, h0 + height), width: 1.8, colour: I.oak)
            svg.circle(iso(x, y, h0 + height) + P(0, -0.4), 0.9, fill: .colour(I.oakLight), stroke: .colour(I.line), width: 0.4)
        }
    }

    /// The gate between two taller posts of the front fence at `y`, each
    /// flying the owner's pennant.
    private mutating func fieldGateway(at y: Double) {
        typealias I = AlchemyOldBuildingsInk
        let (x0, x1) = Self.fieldGate
        wall(.left, from: x0 - 0.42, y + 0.02, at: 1.5) { p in
            let w = 12.0
            p.shape(p.panel(0, 1, w, 9.4), .colour(I.timberLight), width: 0.8)
            for u in [3.0, 6.0, 9.0] { p.line([p.uv(u, 1.2), p.uv(u, 9.2)], width: 0.45) }
            p.line([p.uv(1, 2), p.uv(w - 1, 8.4)], width: 0.8)
            p.shape(p.panel(w - 2.6, 2.2, w - 0.6, 3.2), .colour(I.iron), width: 0.4)
            p.shape(p.panel(w - 2.6, 7.2, w - 0.6, 8.2), .colour(I.iron), width: 0.4)
        }
        for x in [x0, x1] { pole(iso(x, y, 1.5), iso(x, y, 1.5 + 16), width: 2.4, colour: I.oak) }
        pole(iso(x0, y, 1.5 + 15), iso(x1, y, 1.5 + 15), width: 1.7, colour: I.oakLight)
        pennant(at: iso(x0, y, 17.5), height: 12, length: 13)
        pennant(at: iso(x1, y, 17.5), height: 12, length: 13)
    }

    /// The granary at the back corner: half-timbered on staddle stones, banded
    /// in the owner's colour, under a roof of slate, with a ladder to its
    /// door; or, being built, its stones set and its floor's frame laid on them.
    private mutating func granary(complete: Bool) {
        typealias I = AlchemyOldBuildingsInk
        let (x0, y0, x1, y1) = Self.granaryBox
        let h0 = 1.5, floor = 7.0, eave = 20.0, ridge = 30.0
        shadow([iso(x1, y0, h0), iso(x1 + 0.28, y0 + 0.14, h0), iso(x1 + 0.28, y1 + 0.1, h0), iso(x1, y1, h0)])
        for (x, y) in [(x0 + 0.08, y0 + 0.08), (x1 - 0.08, y0 + 0.08), (x0 + 0.08, y1 - 0.08), (x1 - 0.08, y1 - 0.08)] {
            staddle(x, y, from: h0, to: floor - 1.5)
        }
        guard complete else {
            beam(x0, y1 - 0.06, x1, y1 - 0.06, on: floor - 1.5, size: 1.8)
            beam(x0, y0 + 0.08, x1, y0 + 0.08, on: floor - 1.5, size: 1.8)
            return
        }
        block(x0, y0, x1, y1, floor - 1.5, floor, top: .colour(I.oakLight), left: .colour(I.oakLight), right: .colour(I.oak), width: 0.9)
        block(x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, floor, eave, top: nil, left: .colour(I.light), right: .colour(I.plasterShade),
              width: 1)
        let width = (x1 - x0 - 0.06) * 32
        wall(.left, from: x0 + 0.03, y1 - 0.03, at: floor) { p in
            p.framing(width, from: 0, to: eave - floor, posts: [1, width - 1], rail: 7.4, braces: [(0, true)])
            p.paintedBand(0, width, 7.4, 9.6)
            p.shape(p.panel(width / 2 - 3.2, 0, width / 2 + 3.2, 7.4), .colour(I.dark), width: 0.8)
        }
        wall(.right, from: x1 - 0.03, y1 - 0.03, at: floor) { p in
            p.framing(width, from: 0, to: eave - floor, posts: [1, width - 1], rail: 7.4, braces: [(0, false)])
            p.paintedBand(0, width, 7.4, 9.6)
        }
        gableAlongX(x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, eave: eave, ridge: ridge, over: 0.07, gableWall: .colour(I.light)) { p, w, r in
            p.timber(p.uv(w / 2, 0), p.uv(w / 2, r - 1), width: 1.4)
            p.svg.circle(p.uv(w / 2 + 4, r * 0.32), 1.5, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
        }
        let mid = (x0 + x1) / 2
        let feet = (iso(mid - 0.05, y1 + 0.22, h0), iso(mid + 0.05, y1 + 0.22, h0))
        ladder(foot: feet.0, feet.1, head: iso(mid - 0.05, y1, floor + 0.6), iso(mid + 0.05, y1, floor + 0.6), rungs: 2)
        sheaf(at: iso(x1 + 0.12, y1 - 0.12, h0))
        sheaf(at: iso(x1 + 0.12, y1 + 0.08, h0))
    }

    /// A staddle stone at (x, y): a short pillar of stone with a wide cap, so that no rat climbs to the grain.
    private mutating func staddle(_ x: Double, _ y: Double, from h0: Double, to h1: Double) {
        typealias I = AlchemyOldBuildingsInk
        block(x - 0.04, y - 0.04, x + 0.04, y + 0.04, h0, h1 - 1.4, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade),
              width: 0.7)
        block(x - 0.08, y - 0.08, x + 0.08, y + 0.08, h1 - 1.4, h1, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.7)
    }

    /// The field being marked out: the back of it ploughed in furrows, the
    /// front still beaten earth with pegs and lines along the furrows to come,
    /// the plough left at the end of the last, sacks of seed, the granary's
    /// stones set, the fence begun, and the owner's pennant on a stake.
    private mutating func fieldMarkedOut() {
        typealias I = AlchemyOldBuildingsInk
        let e = Self.fieldFence
        let (px0, py0, px1, py1) = (-1.32, -1.32, 1.32, -0.1)
        colour(level(px0, py0, px1, py1, 1.5), .colour(AlchemyOldBuildingsField.soil))
        var ridges = PathData()
        for k in 0..<9 {
            let y = py0 + 0.06 + Double(k) * 0.14
            ridges.move(iso(px0 + 0.02, y, 1.5)); ridges.line(iso(k == 8 ? 0.3 : px1 - 0.02, y, 1.5))
        }
        svg.path(ridges, stroke: .colour(AlchemyOldBuildingsField.soilDark), width: 1.4)
        var lights = PathData()
        for k in 0..<8 {
            let y = py0 + 0.13 + Double(k) * 0.14
            lights.move(iso(px0 + 0.04, y, 1.5)); lights.line(iso(px1 - 0.04, y, 1.5))
        }
        svg.path(lights, stroke: .colour(I.earth), width: 0.7, opacity: 0.8)
        line(level(px0, py0, px1, py1, 1.5), closed: true, width: 0.6, opacity: 0.6)
        railFence(from: (-e, -e), to: (0.2, -e), posts: 5)
        railFence(from: (-e, -e), to: (-e, -0.4), posts: 4)
        granary(complete: false)
        for y in [0.2, 0.62, 1.04] {
            let a = iso(-1.2, y, 1.5), b = iso(1.2, y, 1.5)
            svg.line([a - P(0, 5), b - P(0, 5)], stroke: .colour(I.light), width: 0.7)
            for p in [a, b] { pole(p, p - P(0, 6.4), width: 1.1, colour: I.timberLight) }
        }
        plough(at: iso(0.42, -0.18, 1.5))
        for (k, y) in [0.96, 1.06, 1.16].enumerated() { beam(-0.2 + Double(k) * 0.04, y, 1.0, y, on: 1.5, size: 1.6) }
        sack(at: iso(1.1, 0.42, 1.5))
        sack(at: iso(1.22, 0.58, 1.5), size: 0.9)
        sack(at: iso(-1.0, 1.1, 1.5))
        pennant(at: iso(-1.2, 0.2, 1.5), height: 26, length: 14)
    }

    /// Dark lines along the furrows between the rows, on the soil.
    private mutating func furrows(_ rows: [Double], from x0: Double, to x1: Double) {
        typealias I = AlchemyOldBuildingsInk
        var d = PathData()
        for y in rows + [rows.last! + 0.3] {
            let f = y - 0.15
            d.move(iso(x0, f, 1.5)); d.line(iso(x1, f, 1.5))
        }
        svg.path(d, stroke: .colour(AlchemyOldBuildingsField.soilDark), width: 1.6)
    }

    /// One row of ripe grain along x from `x0` to `x1` at `y`: a low bank of
    /// stalks, its top lit, its side in the grain's colour, with ears along it.
    private mutating func grainRow(from x0: Double, to x1: Double, at y: Double) {
        typealias I = AlchemyOldBuildingsInk
        let w = 0.085, h0 = 1.5, h1 = 6.5
        let top = level(x0, y - w, x1, y + w, h1)
        colour([iso(x0, y + w, h0), iso(x1, y + w, h0), iso(x1, y + w, h1), iso(x0, y + w, h1)], .colour(AlchemyOldBuildingsField.grain))
        colour([iso(x1, y + w, h0), iso(x1, y - w, h0), iso(x1, y - w, h1), iso(x1, y + w, h1)], .colour(AlchemyOldBuildingsField.grainShade))
        colour(top, .colour(AlchemyOldBuildingsField.grainLight))
        // The stalks: fine strokes down the side.
        var stalks = PathData()
        var x = x0 + 0.05
        while x < x1 - 0.02 {
            stalks.move(iso(x, y + w, h1 - 0.8)); stalks.line(iso(x - 0.01, y + w, h0 + 0.6))
            x += 0.09
        }
        svg.path(stalks, stroke: .colour(AlchemyOldBuildingsField.grainShade), width: 0.6)
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
        colour(.colour(AlchemyOldBuildingsField.grainLight)) { d, o in
            d.move(a + o)
            for i in 0..<count {
                let s = a + (b - a) * (Double(i) / Double(count)), e = a + (b - a) * (Double(i + 1) / Double(count))
                d.quad((s + e) * 0.5 + P(0, -2.2) + o, e + o)
            }
            d.close()
        }
        svg.path(ears, stroke: .colour(I.line), width: 0.6)
        svg.path(awns, stroke: .colour(AlchemyOldBuildingsField.grainShade), width: 0.5)
        line([iso(x0, y - w, h1), iso(x0, y + w, h1), iso(x0, y + w, h0), iso(x1, y + w, h0), iso(x1, y - w, h0),
              iso(x1, y - w, h1), iso(x1, y + w, h1)], width: 0.8)
        line([iso(x1, y + w, h0), iso(x1, y + w, h1)], width: 0.6)
    }

    /// A sheaf of grain standing at `p` on the screen, bound at its waist.
    private mutating func sheaf(at p: P) {
        typealias I = AlchemyOldBuildingsInk
        let outline = [p + P(-3.4, 0), p + P(-1.4, -6), p + P(-3.2, -11), p + P(0, -12.4), p + P(3.2, -11), p + P(1.4, -6), p + P(3.4, 0)]
        shape(outline, .colour(AlchemyOldBuildingsField.grain), width: 0.8)
        line([p + P(-1.6, -6), p + P(1.6, -6)], width: 1)
        line([p + P(-0.8, -1), p + P(-0.4, -5)], width: 0.4, opacity: 0.7)
        line([p + P(0.9, -1), p + P(0.5, -5)], width: 0.4, opacity: 0.7)
        svg.path("M\(num(p.x - 2.4)),\(num(p.y - 11)) l-0.8,-2 M\(num(p.x)),\(num(p.y - 12.4)) l0,-2 M\(num(p.x + 2.4)),\(num(p.y - 11)) l0.8,-2",
                 stroke: .colour(AlchemyOldBuildingsField.grainShade), width: 0.6)
    }

    /// A scarecrow standing in the grain at `p` on the screen: a post and an
    /// arm of timber, a tunic of the owner's colour, a head of sacking under a
    /// hat of straw, and straw at its cuffs.
    private mutating func scarecrow(at p: P) {
        typealias I = AlchemyOldBuildingsInk
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

    /// An ard lying at `p` on the screen, its beam toward the back left and its share in the soil.
    private mutating func plough(at p: P) {
        typealias I = AlchemyOldBuildingsInk
        pole(p + P(-2, -1), p + P(-22, -9.6), width: 1.8, colour: I.timber)
        // The yoke-pole's end, and the handle standing up from the share.
        pole(p + P(-22, -9.6), p + P(-25, -8.4), width: 1.2, colour: I.timber)
        pole(p + P(0, -1.4), p + P(4.6, -12), width: 1.4, colour: I.timberLight)
        shape([p + P(-1.6, -2.4), p + P(5, -1.2), p + P(8.2, 0.2), p + P(1, 0.6)], .colour(I.ironLight), width: 0.8)
    }
}
