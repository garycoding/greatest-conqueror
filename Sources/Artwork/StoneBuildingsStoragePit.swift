// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The storage pit of the Stone age: a pit dug in the ground and ringed with
// stones, partly covered by a hide painted in the team's colour; behind it a
// shelter of saplings on four posts, open toward the viewer, its back a woven
// screen, sheltering baskets of stone and a stack of wood; the team's pennant
// on a pole at its corner. Under construction: the pit half dug with its earth
// heaped beside it, the shelter's posts standing with its screen begun, and
// saplings piled for its roof.

/// The pit's and the shelter's measurements, in tiles from the centre of the
/// footprint (2 by 2); heights are in points.
private enum Store {
    /// The pit: its centre and radius.
    static let pit = (x: -0.12, y: 0.5, r: 0.46)
    /// The shelter's posts stand on `x0...x1` by `y0...y1`; its roof falls toward the viewer.
    static let x0 = -0.86, x1 = 0.78, y0 = -0.94, y1 = -0.36
    static let back = 36.0, fall = 15.0
    /// The roof's reach beyond the posts, in tiles.
    static let reach = 0.1

    /// The height of the roof at `y`.
    static func roof(_ y: Double) -> Double { back - fall * (y - (y0 - reach)) }

    /// The pit's rim as the projection draws it: its centre and its two radii.
    static var rim: (c: P, rx: Double, ry: Double) {
        (StoneBuildingsSketch.at(pit.x, pit.y, 0), pit.r * Projection.tileWidth / 2 * 2.squareRoot(),
         pit.r * Projection.tileHeight / 2 * 2.squareRoot())
    }
}

private func point(_ x: Double, _ y: Double, _ h: Double = 0) -> P { StoneBuildingsSketch.at(x, y, h) }

extension StoneBuildingsSketch {
    mutating func storagePit(complete: Bool) {
        earth(2)
        if complete {
            shelter()
            pit()
            basket(at: point(0.62, 0.56), radius: 4.6, height: 8.5, stones: true)
        } else {
            shelterFrame()
            pitBegun()
        }
    }

    /// The shelter: its back screen, what it keeps, its posts, and its roof
    /// of saplings; the pennant's pole at its front left corner.
    private mutating func shelter() {
        let (x0, x1, y0, y1) = (Store.x0, Store.x1, Store.y0, Store.y1)
        let ry0 = y0 - Store.reach, ry1 = y1 + 0.16
        shadow(StoneBuildingsOutline([point(x0 - 0.1, ry0), point(x1 + 0.18, ry0), point(x1 + 0.18, ry1 + 0.06),
                                      point(x0 - 0.1, ry1 + 0.06)]), opacity: 0.13)
        // The back posts, and the woven screen between them.
        for x in [x0, x1] { pole(point(x, y0, -0.6), point(x, y0, Store.roof(y0) + 1), width: 3) }
        let screenTop = Store.roof(y0) - 2
        shape([point(x0, y0, 0), point(x1, y0, 0), point(x1, y0, screenTop), point(x0, y0, screenTop)], .colour(Ink.wood),
              line: 1.1)
        for h in stride(from: 3.0, to: screenTop - 1, by: 3.2) {
            zigzag(StoneBuildingsSketch.points(from: point(x0 + 0.02, y0, h), to: point(x1 - 0.02, y0, h), count: 22),
                   tooth: P(0, -1.3), width: 0.8, colour: Ink.handle)
        }
        // What it keeps: a stack of firewood, and baskets of stone and of wood.
        woodpile(at: point(0.46, -0.66))
        basket(at: point(-0.5, -0.66), radius: 5.2, height: 10, stones: true)
        basket(at: point(-0.08, -0.6), radius: 4.8, height: 9, stones: false)
        // The front posts, and the roof of saplings laid side by side, their
        // butts toward the viewer.
        for x in [x0, x1] { pole(point(x, y1, -0.6), point(x, y1, Store.roof(y1) + 1), width: 3) }
        let corners = [point(x0 - 0.06, ry0, Store.back), point(x1 + 0.08, ry0, Store.back),
                       point(x1 + 0.08, ry1, Store.roof(ry1)), point(x0 - 0.06, ry1, Store.roof(ry1))]
        let lip = 3.0
        shape([corners[3], corners[2], corners[2] + P(0, lip), corners[3] + P(0, lip)],
              .colour(StoneBuildingsInk.thatchDeep), line: 1.1)
        // Each sapling a pole of its own, alternately lighter and darker, laid
        // from the back of the roof to its front, where its butt shows.
        colour(corners, .colour(Ink.handle))
        let count = 14
        for i in 0..<count {
            let f0 = (Double(i) + 0.02) / Double(count), f1 = (Double(i) + 0.98) / Double(count)
            let back0 = corners[0] + (corners[1] - corners[0]) * f0, back1 = corners[0] + (corners[1] - corners[0]) * f1
            let front0 = corners[3] + (corners[2] - corners[3]) * f0, front1 = corners[3] + (corners[2] - corners[3]) * f1
            shape([back0, back1, front1, front0], .colour(i % 2 == 0 ? Ink.wood : StoneBuildingsInk.saplingLight), line: 0.7,
                  shift: P(0, 0))
            svg.ellipse((front0 + front1) * 0.5 + P(0, lip * 0.5), 1.45, 1.4, fill: .colour(StoneBuildingsInk.woodEnd),
                        stroke: .colour(Ink.line), width: 0.7)
        }
        stroke(StoneBuildingsOutline(corners), width: 1.2)
        // Lashings over the saplings, front and back.
        for f in [0.18, 0.82] {
            let a = corners[0] + (corners[3] - corners[0]) * f, b = corners[1] + (corners[2] - corners[1]) * f
            stroke([a, b], width: 1.4, colour: Ink.darkHide)
        }
        pennant(at: point(x0 - 0.12, y1 + 0.2), height: 58)
    }

    /// The pit: dark within, its far wall showing, a ring of stones on its
    /// rim, and a hide in the team's colour laid over its near part and
    /// pegged down.
    private mutating func pit() {
        let rim = Store.rim, nudge = StoneBuildingsSketch.nudge
        let depth = 9.0
        svg.ellipse(rim.c, rim.rx, rim.ry, fill: .colour(StoneBuildingsInk.hollow))
        // The far wall, seen across the pit, and what is stored at its foot.
        let far = StoneBuildingsSketch.arc(rim.c, rim.rx, rim.ry, from: 180, to: 360)
        colour(far + far.reversed().map { p in
            let k = 1 - pow((p.x - rim.c.x) / rim.rx, 2)
            return p + P(0, depth * max(k, 0).squareRoot())
        }, .colour(StoneBuildingsInk.earthDark), shift: P(0, 0))
        for (c, turn) in [(P(-6, 3.5), 1), (P(0.5, 4.2), 3)] {
            shape(StoneBuildingsSketch.lump(rim.c + c, 3.4, 2.2, turn: turn), .colour(StoneBuildingsInk.stoneShade), line: 0.9,
                  shift: nudge)
        }
        stroke(StoneBuildingsSketch.arc(rim.c, rim.rx, rim.ry, from: 0, to: 360), width: 1.2)
        // The stones of the rim.
        for (i, a) in stride(from: 0.0, to: 360, by: 22.5).enumerated() {
            let p = StoneBuildingsSketch.arc(rim.c, rim.rx + 1.4, rim.ry + 0.9, from: a, to: a)[0]
            shape(StoneBuildingsSketch.lump(p, 3.5, 2.3, turn: i), .colour(Ink.stone), line: 0.9, shift: nudge)
        }
        // The hide, laid flat over the near half of the pit and pegged at its
        // corners; its edge across the pit rolled back, showing its raw side.
        func on(_ dx: Double, _ dy: Double) -> P { point(Store.pit.x + dx, Store.pit.y + dy, 2) }
        let (a, b) = (0.1, 0.58), (c, d) = (-0.5, 0.5)
        var hide = StoneBuildingsOutline()
        hide.move(on(a, c))
        hide.quad(on(b * 0.55, c - 0.05), on(b, c))
        hide.quad(on(b + 0.04, 0), on(b, d))
        hide.quad(on(b * 0.5, d + 0.05), on(a, d))
        hide.close()
        colour(hide, .team, shift: nudge)
        zigzag(StoneBuildingsSketch.points(from: on(0.28, c + 0.14), to: on(0.28, d - 0.14), count: 7),
               tooth: on(0.42, 0) - on(0.28, 0), width: 1.1, colour: Ink.light)
        stroke(hide, width: 1.1)
        pole(on(a - 0.02, c - 0.02), on(a - 0.02, d + 0.02), width: 3.6, colour: Ink.hide, line: 1)
        for (corner, out) in [(on(b, c), on(b + 0.16, c - 0.1)), (on(b, d), on(b + 0.12, d + 0.14)),
                              (on(a, c), on(a - 0.06, c - 0.16))] {
            stroke([corner, out], width: 0.9)
            pole(out + P(0, 1.6), out + P(0, -2.4), width: 1.7, colour: Ink.handle, line: 0.8)
        }
    }

    /// A basket of woven withies, its rim heaped with stones or with chips of wood.
    private mutating func basket(at foot: P, radius r: Double, height h: Double, stones: Bool) {
        moved(to: foot) { s in
            let nudge = StoneBuildingsSketch.nudge, ry = r * 0.5
            s.shadow(StoneBuildingsSketch.lump(P(2, 0.4), r + 2.6, ry + 1.2))
            let body = StoneBuildingsSketch.arc(P(0, 0), r, ry, from: 0, to: 180)
                + StoneBuildingsSketch.arc(P(0, -h), r * 1.1, ry * 1.1, from: 180, to: 360)
            s.shape(body, .colour(StoneBuildingsInk.straw), line: 1, shift: nudge)
            for k in stride(from: 2.2, to: h - 1, by: 2.4) {
                let w = r * (1 + 0.1 * k / h)
                s.stroke(StoneBuildingsSketch.arc(P(0, -k), w, ry * (1 + 0.1 * k / h), from: 8, to: 172), width: 0.6,
                         colour: StoneBuildingsInk.thatchShade)
            }
            for a in stride(from: 20.0, to: 170, by: 26) {
                let low = StoneBuildingsSketch.arc(P(0, 0), r, ry, from: a, to: a)[0]
                let high = StoneBuildingsSketch.arc(P(0, -h), r * 1.1, ry * 1.1, from: a, to: a)[0]
                s.stroke([low, high], width: 0.6, colour: StoneBuildingsInk.thatchShade)
            }
            s.svg.ellipse(P(0, -h), r * 1.1, ry * 1.1, fill: .colour(StoneBuildingsInk.thatchShade), stroke: .colour(Ink.line),
                          width: 1)
            if stones {
                for (c, turn) in [(P(-1.8, -h - 0.6), 0), (P(2, -h - 0.2), 2), (P(0.2, -h - 2.4), 4)] {
                    s.shape(StoneBuildingsSketch.lump(c, 2.2, 1.6, turn: turn), .colour(Ink.stone), line: 0.8, shift: nudge)
                }
            } else {
                for (a, b) in [(P(-3, -h - 0.4), P(2.4, -h - 3)), (P(-1, -h + 0.8), P(3.4, -h - 1.4)),
                               (P(-3.4, -h - 2.6), P(1.4, -h - 0.4))] {
                    s.pole(a, b, width: 1.8, line: 0.8)
                }
            }
        }
    }

    /// The shelter being built: its four posts, a beam across the front, the
    /// screen woven along the foot of its back, and saplings piled for its roof.
    private mutating func shelterFrame() {
        let (x0, x1, y0, y1) = (Store.x0, Store.x1, Store.y0, Store.y1)
        for x in [x0, x1] { pole(point(x, y0, -0.6), point(x, y0, Store.roof(y0) + 1), width: 3) }
        shape([point(x0, y0, 0), point(x1, y0, 0), point(x1, y0, 10), point(x0 + 0.5, y0, 13), point(x0, y0, 12)],
              .colour(Ink.wood), line: 1.1)
        for h in stride(from: 3.0, through: 10, by: 3.2) {
            zigzag(StoneBuildingsSketch.points(from: point(x0 + 0.02, y0, h), to: point(x1 - 0.02, y0, h), count: 22),
                   tooth: P(0, -1.3), width: 0.8, colour: Ink.handle)
        }
        pole(point(x0 - 0.06, y0, Store.roof(y0)), point(x1 + 0.06, y0, Store.roof(y0)), width: 2.6)
        for x in [x0, x1] { pole(point(x, y1, -0.6), point(x, y1, Store.roof(y1) + 1), width: 3) }
        pole(point(x0 - 0.06, y1, Store.roof(y1)), point(x1 + 0.06, y1, Store.roof(y1)), width: 2.6)
        // Saplings for the roof, piled crosswise beside the shelter.
        let along = StoneBuildingsSketch.unit(P(32, 16))
        moved(to: point(0.58, 0.42)) { s in
            s.shadow(StoneBuildingsSketch.lump(P(0, 0.5), 15, 4.2))
            for (c, k) in [(P(-2, 0.6), 0.0), (P(1, -1.2), 1.0), (P(-1, -3), 2.0), (P(2, -4.6), 3.0)] {
                let tilt = StoneBuildingsSketch.unit(along + P(0, k.truncatingRemainder(dividingBy: 2) * 0.08))
                s.pole(c - tilt * 13, c + tilt * 13, width: 2, line: 0.9)
            }
        }
        pennant(at: point(x0 - 0.12, y1 + 0.2), height: 50)
    }

    /// The pit begun: a shallow hole, the earth dug from it heaped beside,
    /// a digging stick standing in the heap, and a basket of the stones dug out.
    private mutating func pitBegun() {
        let rim = Store.rim, nudge = StoneBuildingsSketch.nudge
        let rx = rim.rx * 0.72, ry = rim.ry * 0.72
        svg.ellipse(rim.c + P(-2, 0), rx, ry, fill: .colour(StoneBuildingsInk.earthDark))
        let far = StoneBuildingsSketch.arc(rim.c + P(-2, 0), rx, ry, from: 180, to: 360)
        colour(far + far.reversed().map { p in
            let k = 1 - pow((p.x - rim.c.x + 2) / rx, 2)
            return p + P(0, 4.5 * max(k, 0).squareRoot())
        }, .colour(StoneBuildingsInk.hollow), shift: P(0, 0), opacity: 0.55)
        stroke(StoneBuildingsSketch.arc(rim.c + P(-2, 0), rx, ry, from: 0, to: 360), width: 1.1)
        // The heap of dug earth, and the digging stick in it.
        let heap = point(-0.72, 0.78)
        shadow(StoneBuildingsSketch.lump(heap + P(3, 1), 13, 4.4))
        var mound = StoneBuildingsOutline()
        mound.move(heap + P(-12, 1.5))
        mound.quad(heap + P(-9, -4), heap + P(-4, -6.5))
        mound.quad(heap + P(0, -10.5), heap + P(4.5, -7))
        mound.quad(heap + P(10, -4.5), heap + P(12, 1.5))
        mound.quad(heap + P(0, 4.6), heap + P(-12, 1.5))
        mound.close()
        shape(mound, .colour(StoneBuildingsInk.earthDark), line: 1.1, shift: nudge)
        for (c, turn) in [(P(-5, -2.4), 1), (P(3, -1.2), 4), (P(-1, -5.6), 2)] {
            shape(StoneBuildingsSketch.lump(heap + c, 1.6, 1.1, turn: turn), .colour(StoneBuildingsInk.stoneShade), line: 0.7,
                  shift: P(0, 0))
        }
        pole(heap + P(6, -5), heap + P(10.5, -26), width: 2.2, colour: Ink.handle)
        basket(at: point(0.5, 0.74), radius: 4.8, height: 8, stones: true)
    }
}
