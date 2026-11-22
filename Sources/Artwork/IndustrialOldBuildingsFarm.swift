// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age farm: the Alchemy age's field of ripe grain standing in
// rows along its furrows, low on its footprint, inside a fence of oak posts
// and rails with a gate at the front flying the owner's pennants. A reaping
// machine stands in the grain where it has cut two rows to stubble: a drive
// wheel of iron, a cutter bar along its platform, a reel of slats above it,
// the driver's seat on its spring, and a grain board of the owner's colour
// along its platform, with sheaves left behind it. At the back corner a granary of
// painted weatherboard stands on staddle stones under a roof of slate, banded
// in the owner's colour, with sheaves stood against it. A farm lasts
// forever, so it is never drawn spent. Its footprint is three tiles square:
// x and y run from -1.5 to 1.5.

/// The colours of the field: ploughed soil, and the ripe grain.
private enum IndustrialOldBuildingsField {
    static let soil = "#8d6243"
    static let soilDark = "#6e4a32"
    static let grain = "#dcb253"
    static let grainLight = "#ecd083"
    static let grainShade = "#b48a36"
}

extension IndustrialOldBuildingsPainter {
    mutating func farm(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(complete ? IndustrialOldBuildingsField.soil : I.earth),
              left: .colour(I.earthShade), right: .colour(I.earthShade), width: 1)
        if complete { grainField() } else { fieldMarkedOut() }
    }

    private static let fieldFence = 1.42
    private static let granaryBox = (x0: -1.3, y0: -1.3, x1: -0.66, y1: -0.66)
    private static let fieldGate = (x0: -0.26, x1: 0.26)
    /// Where the rows of grain run along x, from the back.
    private static let grainRows: [Double] = (0..<9).map { -1.2 + Double($0) * 0.3 }
    /// The rows the reaper has cut, and where the cutting stopped along x.
    private static let cutRows: [Double] = [0.3, 0.6]
    private static let cutFrom = 0.22

    private mutating func grainField() {
        let e = Self.fieldFence
        railFence(from: (-e, -e), to: (e, -e), posts: 7)
        railFence(from: (-e, -e), to: (-e, e), posts: 7)
        furrows(Self.grainRows, from: -1.32, to: 1.34)
        granary(complete: true)
        for y in Self.grainRows {
            let start = y - 0.1 < Self.granaryBox.y1 + 0.06 ? Self.granaryBox.x1 + 0.2 : -1.26
            // The two rows the reaper has cut, from its cutter bar to the fence.
            let cut = Self.cutRows.contains { abs($0 - y) < 0.01 }
            grainRow(from: start, to: cut ? Self.cutFrom : 1.26, at: y)
            if cut { stubble(from: Self.cutFrom, to: 1.3, at: y) }
            if abs(y - Self.cutRows[1]) < 0.01 {
                sheaf(at: iso(1.02, 0.36, 1.5))
                sheaf(at: iso(1.22, 0.56, 1.5))
                reaper(at: (Self.cutFrom + 0.08, 0.42))
            }
        }
        railFence(from: (-e, e), to: (Self.fieldGate.x0, e), posts: 4)
        railFence(from: (Self.fieldGate.x1, e), to: (e, e), posts: 4)
        fieldGateway(at: e)
        railFence(from: (e, -e), to: (e, e), posts: 7)
    }

    /// A fence of oak posts and two rails from one place on the map to another, on `h0`.
    mutating func railFence(from a: (Double, Double), to b: (Double, Double), posts: Int, on h0: Double = 1.5,
                                    height: Double = 10) {
        typealias I = IndustrialOldBuildingsInk
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
        typealias I = IndustrialOldBuildingsInk
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

    /// The granary at the back corner: painted weatherboard on staddle
    /// stones, banded in the owner's colour, its door and corner boards
    /// painted bottle green, under a roof of slate, with a ladder to its door; or,
    /// being built, its stones set and its floor's frame laid on them.
    private mutating func granary(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
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
            p.weatherboard(width, eave - floor)
            p.paintedBand(0, width, 8, 10)
            p.shape(p.panel(width / 2 - 3.4, 0, width / 2 + 3.4, 7.4), .colour(I.green), width: 0.8)
            p.line([p.uv(width / 2 - 2.8, 0.6), p.uv(width / 2 + 2.8, 6.8)], width: 0.5)
            for u in [0.9, width - 0.9] { p.shape(p.panel(u - 0.9, 0, u + 0.9, eave - floor), .colour(I.green), width: 0.45) }
        }
        wall(.right, from: x1 - 0.03, y1 - 0.03, at: floor) { p in
            p.weatherboard(width, eave - floor)
            p.paintedBand(0, width, 8, 10)
            p.shape(p.panel(width - 1.8, 0, width, eave - floor), .colour(I.greenShade), width: 0.45)
        }
        gableAlongX(x0 + 0.03, y0 + 0.03, x1 - 0.03, y1 - 0.03, eave: eave, ridge: ridge, over: 0.07,
                    gableWall: .colour(I.plasterShade)) { p, w, r in
            var boards = PathData()
            var v = 1.6
            while v < r - 1.4 {
                let half = w / 2 * (1 - v / r) - 0.5
                boards.move(p.uv(w / 2 - half, v)); boards.line(p.uv(w / 2 + half, v))
                v += 1.6
            }
            p.svg.path(boards, stroke: .colour(I.line), width: 0.35, opacity: 0.45)
            p.svg.circle(p.uv(w / 2, r * 0.36), 1.6, fill: .colour(I.green), stroke: .colour(I.line), width: 0.5)
        }
        let mid = (x0 + x1) / 2
        let feet = (iso(mid - 0.05, y1 + 0.22, h0), iso(mid + 0.05, y1 + 0.22, h0))
        ladder(foot: feet.0, feet.1, head: iso(mid - 0.05, y1, floor + 0.6), iso(mid + 0.05, y1, floor + 0.6), rungs: 2)
        sheaf(at: iso(x1 + 0.12, y1 - 0.12, h0))
        sheaf(at: iso(x1 + 0.12, y1 + 0.08, h0))
    }

    /// A staddle stone at (x, y): a short pillar of stone with a wide cap, so that no rat climbs to the grain.
    private mutating func staddle(_ x: Double, _ y: Double, from h0: Double, to h1: Double) {
        typealias I = IndustrialOldBuildingsInk
        block(x - 0.04, y - 0.04, x + 0.04, y + 0.04, h0, h1 - 1.4, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade),
              width: 0.7)
        block(x - 0.08, y - 0.08, x + 0.08, y + 0.08, h1 - 1.4, h1, top: .colour(I.stoneTop), left: .colour(I.stone),
              right: .colour(I.stoneShade), width: 0.7)
    }

    /// The field being marked out: the back of it ploughed in furrows, the
    /// front still beaten earth with pegs and lines along the furrows to come,
    /// an iron plough left at the end of the last, a cart of seed in sacks, the granary's
    /// stones set, the fence begun, and the owner's pennant on a stake.
    private mutating func fieldMarkedOut() {
        typealias I = IndustrialOldBuildingsInk
        let e = Self.fieldFence
        let (px0, py0, px1, py1) = (-1.32, -1.32, 1.32, -0.1)
        colour(level(px0, py0, px1, py1, 1.5), .colour(IndustrialOldBuildingsField.soil))
        var ridges = PathData()
        for k in 0..<9 {
            let y = py0 + 0.06 + Double(k) * 0.14
            ridges.move(iso(px0 + 0.02, y, 1.5)); ridges.line(iso(k == 8 ? 0.3 : px1 - 0.02, y, 1.5))
        }
        svg.path(ridges, stroke: .colour(IndustrialOldBuildingsField.soilDark), width: 1.4)
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
        cart(0.62, 0.62, on: 1.5, length: 0.46, load: .sacks)
        for (k, y) in [0.96, 1.06, 1.16].enumerated() { beam(-0.2 + Double(k) * 0.04, y, 1.0, y, on: 1.5, size: 1.6) }
        sack(at: iso(1.18, 0.2, 1.5))
        sack(at: iso(-1.0, 1.1, 1.5))
        pennant(at: iso(-1.2, 0.2, 1.5), height: 26, length: 14)
    }

    /// Dark lines along the furrows between the rows, on the soil.
    private mutating func furrows(_ rows: [Double], from x0: Double, to x1: Double) {
        typealias I = IndustrialOldBuildingsInk
        var d = PathData()
        for y in rows + [rows.last! + 0.3] {
            let f = y - 0.15
            d.move(iso(x0, f, 1.5)); d.line(iso(x1, f, 1.5))
        }
        svg.path(d, stroke: .colour(IndustrialOldBuildingsField.soilDark), width: 1.6)
    }

    /// One row of ripe grain along x from `x0` to `x1` at `y`: a low bank of
    /// stalks, its top lit, its side in the grain's colour, with ears along it.
    private mutating func grainRow(from x0: Double, to x1: Double, at y: Double) {
        typealias I = IndustrialOldBuildingsInk
        let w = 0.085, h0 = 1.5, h1 = 6.5
        let top = level(x0, y - w, x1, y + w, h1)
        colour([iso(x0, y + w, h0), iso(x1, y + w, h0), iso(x1, y + w, h1), iso(x0, y + w, h1)], .colour(IndustrialOldBuildingsField.grain))
        colour([iso(x1, y + w, h0), iso(x1, y - w, h0), iso(x1, y - w, h1), iso(x1, y + w, h1)], .colour(IndustrialOldBuildingsField.grainShade))
        colour(top, .colour(IndustrialOldBuildingsField.grainLight))
        // The stalks: fine strokes down the side.
        var stalks = PathData()
        var x = x0 + 0.05
        while x < x1 - 0.02 {
            stalks.move(iso(x, y + w, h1 - 0.8)); stalks.line(iso(x - 0.01, y + w, h0 + 0.6))
            x += 0.09
        }
        svg.path(stalks, stroke: .colour(IndustrialOldBuildingsField.grainShade), width: 0.6)
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
        colour(.colour(IndustrialOldBuildingsField.grainLight)) { d, o in
            d.move(a + o)
            for i in 0..<count {
                let s = a + (b - a) * (Double(i) / Double(count)), e = a + (b - a) * (Double(i + 1) / Double(count))
                d.quad((s + e) * 0.5 + P(0, -2.2) + o, e + o)
            }
            d.close()
        }
        svg.path(ears, stroke: .colour(I.line), width: 0.6)
        svg.path(awns, stroke: .colour(IndustrialOldBuildingsField.grainShade), width: 0.5)
        line([iso(x0, y - w, h1), iso(x0, y + w, h1), iso(x0, y + w, h0), iso(x1, y + w, h0), iso(x1, y - w, h0),
              iso(x1, y - w, h1), iso(x1, y + w, h1)], width: 0.8)
        line([iso(x1, y + w, h0), iso(x1, y + w, h1)], width: 0.6)
    }

    /// A sheaf of grain standing at `p` on the screen, bound at its waist.
    private mutating func sheaf(at p: P) {
        typealias I = IndustrialOldBuildingsInk
        let outline = [p + P(-3.4, 0), p + P(-1.4, -6), p + P(-3.2, -11), p + P(0, -12.4), p + P(3.2, -11), p + P(1.4, -6), p + P(3.4, 0)]
        shape(outline, .colour(IndustrialOldBuildingsField.grain), width: 0.8)
        line([p + P(-1.6, -6), p + P(1.6, -6)], width: 1)
        line([p + P(-0.8, -1), p + P(-0.4, -5)], width: 0.4, opacity: 0.7)
        line([p + P(0.9, -1), p + P(0.5, -5)], width: 0.4, opacity: 0.7)
        svg.path("M\(num(p.x - 2.4)),\(num(p.y - 11)) l-0.8,-2 M\(num(p.x)),\(num(p.y - 12.4)) l0,-2 M\(num(p.x + 2.4)),\(num(p.y - 11)) l0.8,-2",
                 stroke: .colour(IndustrialOldBuildingsField.grainShade), width: 0.6)
    }

    /// Painted weatherboard on a wall drawn with `wall`, `w` wide and `h`
    /// tall: lapped boards, each with its shadowed lower edge.
    private mutating func weatherboard(_ w: Double, _ h: Double) {
        var v = 1.6
        var edges = PathData()
        while v < h - 0.4 {
            edges.move(uv(0, v)); edges.line(uv(w, v))
            v += 1.6
        }
        svg.path(edges, stroke: .colour(IndustrialOldBuildingsInk.line), width: 0.4, opacity: 0.5)
    }

    /// Stubble left where a row was cut, from x0 to x1 along the row at `y`.
    private mutating func stubble(from x0: Double, to x1: Double, at y: Double) {
        var d = PathData()
        var x = x0 + 0.03
        var k = 0
        while x < x1 {
            for dy in [-0.05, 0.03] {
                let p = iso(x + dy * 0.4, y + dy, 1.5)
                d.move(p); d.line(p - P(0.3 * Double(k % 3 - 1), 1.6 + Double(k % 2)))
            }
            x += 0.06
            k += 1
        }
        svg.path(d, stroke: .colour(IndustrialOldBuildingsField.grainShade), width: 0.6)
    }

    /// A reaping machine standing in the field, its cutter bar at the cut's
    /// end at (x, y) and its platform running back along x: a drive wheel of
    /// iron on the near side, the platform with its cutter bar, a reel of
    /// slats on arms above it, the driver's seat on a spring, a grain board
    /// of the owner's colour along the platform, and the pole for the team reaching forward.
    private mutating func reaper(at place: (Double, Double)) {
        typealias I = IndustrialOldBuildingsInk
        let (x, y) = place
        let h0 = 1.5, deck = h0 + 5.6
        let (px0, px1, py0, py1) = (x, x + 0.34, y - 0.2, y + 0.06)
        shadow(level(px0 - 0.04, py0, px1 + 0.24, py1 + 0.2, h0), opacity: 0.16)
        // The far side of the reel and its far arm.
        let axle = (x: x + 0.12, h: deck + 11.0), rr = 0.15, rh = 6.4
        func reelPoint(_ a: Double, _ yy: Double) -> P { iso(axle.x + rr * cos(a), yy, axle.h + rh * sin(a)) }
        pole(iso(px1 - 0.02, py0 + 0.02, deck), iso(axle.x, py0 + 0.02, axle.h), width: 1.2, colour: I.timberDark)
        // The platform: boards painted bottle green on a frame of iron, its cutter bar along the front edge.
        block(px0, py0, px1, py1, deck - 3.4, deck, top: .colour(I.timberLight), left: .colour(I.light), right: .colour(I.greenShade),
              width: 0.8)

        let bar = [iso(px0 - 0.04, py0 - 0.04, deck - 1.6), iso(px0 - 0.04, py1 + 0.04, deck - 1.6)]
        svg.line(bar, stroke: .colour(I.line), width: 2.2)
        svg.line(bar, stroke: .colour(I.ironLight), width: 1)
        var teeth = PathData()
        for k in 0...6 {
            let t = Double(k) / 6, p = bar[0] + (bar[1] - bar[0]) * t
            teeth.move(p); teeth.line(p + P(-2.2, -0.6))
        }
        svg.path(teeth, stroke: .colour(I.line), width: 0.6)
        // Cut stalks lying on the platform.
        var cut = PathData()
        for k in 0..<5 {
            let yy = py0 + 0.04 + Double(k) * 0.045
            cut.move(iso(px0 + 0.04, yy, deck + 0.4)); cut.line(iso(px1 - 0.06, yy + 0.02, deck + 0.4))
        }
        svg.path(cut, stroke: .colour(IndustrialOldBuildingsField.grainShade), width: 0.9)
        // The grain board standing along the platform's near edge: the owner's
        // colour in a rim of the light colour.
        shape([iso(px0 + 0.02, py1, deck), iso(px1 - 0.1, py1, deck), iso(px1 - 0.1, py1, deck + 5.4),
               iso(px0 + 0.02, py1, deck + 5.4)], .colour(I.light), width: 0.6)
        shape([iso(px0 + 0.05, py1, deck + 0.8), iso(px1 - 0.13, py1, deck + 0.8), iso(px1 - 0.13, py1, deck + 4.6),
               iso(px0 + 0.05, py1, deck + 4.6)], .team, width: 0.45)
        cog(at: iso((px0 + px1 - 0.08) / 2, py1, deck + 2.7), radius: 1)
        // The reel's slats, then its near arm and axle.
        for k in 0..<4 {
            let a = Double(k) * .pi / 2 + 0.4
            let s0 = reelPoint(a, py0 - 0.02), s1 = reelPoint(a, py1 + 0.06)
            svg.line([s0, s1], stroke: .colour(I.line), width: 1.8)
            svg.line([s0, s1], stroke: .colour(I.timberLight), width: 0.8)
            line([iso(axle.x, py1 + 0.06, axle.h), s1], width: 0.7)
        }
        svg.line([iso(axle.x, py0 - 0.02, axle.h), iso(axle.x, py1 + 0.08, axle.h)], stroke: .colour(I.ironDark), width: 1.2)
        pole(iso(px1 - 0.02, py1 + 0.06, deck), iso(axle.x, py1 + 0.06, axle.h), width: 1.2, colour: I.timberDark)
        // The frame of iron beside the drive wheel.
        let fy = py1 + 0.08
        svg.line([iso(px1 - 0.2, fy, deck), iso(px1 + 0.1, fy, deck)], stroke: .colour(I.line), width: 2)
        svg.line([iso(px1 - 0.2, fy, deck), iso(px1 + 0.1, fy, deck)], stroke: .colour(I.iron), width: 1)
        // The seat on its spring.
        let seat = iso(px1 + 0.04, fy - 0.08, deck + 12)
        line([iso(px1 - 0.06, fy - 0.08, deck + 4.6), seat + P(0, 1)], width: 1.1)
        svg.ellipse(seat, 3.2, 1.4, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.6)
        // The pole reaching forward for the team.
        pole(iso(px1 + 0.1, fy - 0.1, deck + 1), iso(px1 + 0.62, fy - 0.1, h0 + 5), width: 1.5, colour: I.timber)
        pole(iso(px1 + 0.62, fy - 0.1, h0), iso(px1 + 0.62, fy - 0.1, h0 + 5), width: 1, colour: I.timberDark)
        // The drive wheel of iron, its rim ribbed for grip.
        wall(.left, from: px1 + 0.16, fy + 0.04, at: h0) { p in
            let r = 6.4, c = p.uv(0, r)
            p.svg.circle(c + p.shift, r, fill: .colour(I.iron), opacity: 0.25)
            p.svg.circle(c, r, fill: .none, stroke: .colour(I.line), width: 2.6)
            p.svg.circle(c, r, fill: .none, stroke: .colour(I.iron), width: 1.4)
            var ribs = PathData()
            for k in 0..<16 {
                let a = Double(k) * .pi / 8
                ribs.move(c + P(cos(a), sin(a)) * (r - 0.6)); ribs.line(c + P(cos(a), sin(a)) * (r + 0.7))
            }
            p.svg.path(ribs, stroke: .colour(I.line), width: 0.5)
            var spokes = PathData()
            for k in 0..<4 {
                let a = Double(k) * .pi / 4 + 0.2
                spokes.move(c + P(cos(a), sin(a)) * (r - 0.8)); spokes.line(c - P(cos(a), sin(a)) * (r - 0.8))
            }
            p.svg.path(spokes, stroke: .colour(I.line), width: 1.1)
            p.svg.path(spokes, stroke: .colour(I.ironLight), width: 0.45)
            p.svg.circle(c, 1.8, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.5)
        }
    }

    /// A plough of iron lying at `p` on the screen: its beam toward the back
    /// left on a small front wheel, its two handles standing up behind, and its
    /// share and mouldboard in the soil.
    private mutating func plough(at p: P) {
        typealias I = IndustrialOldBuildingsInk
        pole(p + P(-1, -2), p + P(-22, -9), width: 1.8, colour: I.iron)
        svg.ellipse(p + P(-21, -6.6), 2.2, 3, fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.7)
        pole(p + P(0, -1.6), p + P(7.6, -12.6), width: 1.2, colour: I.timberLight)
        pole(p + P(2.4, -1.2), p + P(10.2, -11.2), width: 1.2, colour: I.timberLight)
        shape([p + P(-3, -3), p + P(4.4, -4.2), p + P(8.4, 0.2), p + P(1, 0.8)], .colour(I.green), width: 0.8)
        shape([p + P(-3, -1), p + P(1, 0.8), p + P(-4.6, 0.6)], .colour(I.ironLight), width: 0.6)
    }
}
