// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The Iron-age boat house (ruled 2026-11-21): the Stone age's thatched
// shelter grown into a timber boathouse on a quay of dressed stone. Walls of
// overlapping boards stand on a stone footing under a gabled roof of red
// tile, its pediment carrying the owner's colour round a light wreath; a band
// of the owner's colour runs under the eaves of the long wall, where a pair of
// oars and a net hang on pegs between two barred windows. The gable end is
// open: a fishing boat rests on a timber slipway that runs out of it to the
// footprint's edge, its bow with the painted eye and the curled stem out
// under the pediment, and the owner's pennant flies from the gable's peak. An
// iron anchor leans by the door, amphorae stand on the quay, and a stone
// bollard with an iron ring stands at the slip's foot. Under construction:
// the footing in fresh stone, the frame of posts and the roof's trusses with
// the pennant on the ridge pole, a few boards nailed on, and a boat on the
// slip with its keel, stem and ribs set up and its first planks on, boards,
// roof tiles and a ladder to hand. Its footprint is two tiles square: x and y
// run from -1 to 1.
//
// The water may lie beside any of its edges, and the boat house is drawn
// facing it (ruled 2026-11-22) in two views, which the drawing mirrors for the
// other two edges. The side view is drawn with the slip toward +y (the
// screen's lower left), under the gable, and then mirrored on the screen, so
// that in the sprite the slip runs toward +x (the lower right) and the long
// wall with the oars faces +y. The back view is the same building turned a
// quarter: the slip runs out of the far gable toward −y (the upper right),
// away from the viewer, with the bollard and the basket of fish at its foot
// and the pennant at that gable's peak; the long wall with the oars faces +x,
// and the landward gable faces the viewer under its pediment, with a door of
// painted planks, two barred windows, and the anchor and the amphorae stored
// beside it. Under construction it is the same frame turned the same way, the
// footing laid across the landward end with a gap for the door.
//
// From the middle of the water edge a short timber jetty runs a tile out over
// the water (ruled 2026-11-22, scenery only): a deck of planks on piles, each
// pile with a ring of water at its foot, ending in a head of dressed stone
// with an iron mooring ring. In the back view it runs toward the upper right,
// past the shed's far corner. Under construction the piles stand, the first
// planks are laid, and the stone head is rising.

/// The boat house's measurements, about the centre of its footprint.
private enum IronShed {
    /// The shed: its extent on the quay, and the height of its eaves and ridge above the ground.
    static let x0 = -0.58, x1 = 0.34, y0 = -0.9, y1 = 0.3
    static let quay = 2.0, footing = 6.0, eaves = 27.0, rise = 16.0
    /// The slipway: its width along x, and where it ends on the quay's edge.
    static let slipX0 = -0.42, slipX1 = 0.16, slipEnd = 0.97
    /// The boat on the slip: its stern inside the shed, its bow out under the gable.
    static let boatX = -0.13, sternY = -0.42, bowY = 0.74
    /// In the back view the boat is hauled this much farther out, so that its
    /// bow shows past the shed's far corner.
    static let backHaul = 0.2
    /// The jetty: its half-width, where it ends beyond the quay's edge (at 1),
    /// where its stone head begins, and the heights of its deck and its head.
    static let dockHalf = 0.21, dockEnd = 2.0, headStart = 1.72, deckFoot = 2.0, deck = 3.2, head = 4.2
}

extension IronOldBuildingsPainter {
    /// The boat house in the side view (its water side toward +x) or the back
    /// view (its water side toward −y), complete or under construction.
    mutating func boatHouse(complete: Bool, view: SpriteView = .side) {
        if view == .back {
            // The jetty lies behind the quay, toward −y, and is drawn first.
            jetty(toward: -1, complete: complete)
            quay()
            if complete { boatShedBack() } else { boatShedBackRising() }
            return
        }
        // Drawn with the slip toward +y and mirrored about the footprint's centre (the anchor), the jetty last, nearest the viewer.
        svg.raw("<g transform=\"scale(-1 1)\">")
        quay()
        if complete { boatShed() } else { boatShedRising() }
        jetty(toward: 1, complete: complete)
        svg.raw("</g>")
    }

    /// The quay the boat house stands on, its flagstones jointed.
    private mutating func quay() {
        typealias I = IronOldBuildingsInk
        block(-1, -1, 1, 1, 0, IronShed.quay, top: .colour(I.paving), left: .colour(I.pavingShade), right: .colour(I.pavingShade),
              width: 1)
        var joints = PathData()
        for t in stride(from: -0.75, through: 0.75, by: 0.25) {
            joints.move(iso(t, -1, IronShed.quay)); joints.line(iso(t, 1, IronShed.quay))
            joints.move(iso(-1, t, IronShed.quay)); joints.line(iso(1, t, IronShed.quay))
        }
        svg.path(joints, stroke: .colour(I.line), width: 0.4, opacity: 0.3)
    }

    // MARK: The complete boat house

    private mutating func boatShed() {
        typealias I = IronOldBuildingsInk
        typealias S = IronShed
        let (x0, x1, y0, y1, h0, h1) = (S.x0, S.x1, S.y0, S.y1, S.quay, S.quay + S.eaves)
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.28, y0 + 0.16, h0), iso(x1 + 0.28, y1 + 0.12, h0), iso(x1, y1, h0)])
        // The long wall facing +x: boards over the footing, the band under the eaves, the windows, and the oars and net on it.
        wall(.right, from: x1, y1, at: h0) { p in
            p.boardedWall(side, S.eaves)
            p.grille(5, 11, w: 5, h: 6)
            p.grille(side - 10, 11, w: 5, h: 6)
            p.hungOars(side * 0.5, top: 23)
            p.hungNet(side * 0.5 - 6.5, side * 0.5 + 6.5, top: 21.4, drop: 10)
        }
        line([iso(x1, y1, h0), iso(x1, y1, h1)], width: 1.2)
        line([iso(x1, y0, h0), iso(x1, y0, h1)], width: 1.2)
        line([iso(x1, y1, h0), iso(x1, y0, h0)], width: 1.2)
        // The open gable end: the dark inside, the far wall's boards dimly, the footing either side of the opening.
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, front, S.eaves), .colour(I.dark), width: 1.2)
            var boards = PathData()
            for v in stride(from: S.footing + 3.4, to: S.eaves - 1, by: 3.4) { boards.move(p.uv(2, v)); boards.line(p.uv(front - 2, v)) }
            p.svg.path(boards, stroke: .colour(I.timberDark), width: 0.6, opacity: 0.6)
        }
        withinOpening("slip") { $0.slipway(from: S.y1 - 0.5, to: S.slipEnd) }
        // The far post of the opening and the lintel; the boat's bow, out on the slip, lies over them, and the near post over the boat.
        wall(.left, from: x0, y1, at: h0) { p in
            p.openingPost(0, 3.4)
            p.shape(p.panel(-0.6, S.eaves - 2.8, front + 0.6, S.eaves), .colour(I.timber), width: 0.9)
            for u in stride(from: 3.0, to: front, by: 6) { p.svg.circle(p.uv(u, S.eaves - 1.4), 0.45, fill: .colour(I.ironDark)) }
        }
        withinOpening("boat") { $0.restingBoat(planked: true, stern: S.sternY, bow: S.bowY) }
        wall(.left, from: x0, y1, at: h0) { p in p.openingPost(front - 3.4, front) }
        gabledRoof(x0, y0, x1, y1, eaves: h1, rise: S.rise)
        // The pennant at the gable's peak.
        pennant(at: iso((x0 + x1) / 2 - 0.06, y1 + 0.02, h1 + S.rise + 1), height: 17, length: 14)
        anchor(at: iso(x1 + 0.4, -0.18, h0))
        amphora(at: iso(-0.86, 0.5, h0), size: 0.9)
        amphora(at: iso(-0.7, 0.66, h0), size: 0.8, paint: I.clayShade)
        fishBasket(at: iso(0.66, 0.62, h0))
        bollard(at: iso(0.36, 0.88, h0))
    }

    /// A corner post of the open gable, from `u0` to `u1` along it: the end of the stone footing, and the timber post on it.
    private mutating func openingPost(_ u0: Double, _ u1: Double) {
        typealias I = IronOldBuildingsInk
        shape(panel(u0, 0, u1, IronShed.footing), .colour(I.stone), width: 0.8)
        shape(panel(u0 + 0.4, IronShed.footing, u1 - 0.4, IronShed.eaves - 2.8), .colour(I.timberLight), width: 0.9)
        line([uv(u0 + 1.4, IronShed.footing + 1), uv(u0 + 1.4, IronShed.eaves - 3.6)], width: 0.4, opacity: 0.5)
    }

    /// A wall of overlapping boards on a footing of dressed stone, `length`
    /// points long and `height` tall, with the owner's band under the eaves.
    private mutating func boardedWall(_ length: Double, _ height: Double) {
        typealias I = IronOldBuildingsInk
        let footing = IronShed.footing
        colour(panel(0, 0, length, footing), .colour(I.stone))
        courses(0, length, 0, footing, course: 3, brick: 9)
        colour(panel(0, footing, length, height), .colour(I.timber))
        // Each board's lower edge lit where it laps over the one below, and the line under it.
        var lit = PathData(), laps = PathData()
        for v in stride(from: footing, to: height - 6, by: 3.2) {
            lit.move(uv(0, v + 0.7)); lit.line(uv(length, v + 0.7))
            laps.move(uv(0, v)); laps.line(uv(length, v))
        }
        svg.path(lit, stroke: .colour(I.timberLight), width: 1, opacity: 0.85)
        svg.path(laps, stroke: .colour(I.line), width: 0.5, opacity: 0.7)
        // The nail heads of the studs behind.
        for u in stride(from: length / 6, to: length, by: length / 3) {
            for v in stride(from: footing + 1.6, to: height - 6, by: 3.2) { svg.circle(uv(u, v), 0.35, fill: .colour(I.ironDark)) }
        }
        line([uv(0, footing), uv(length, footing)], width: 0.7)
        paintedBand(0, length, height - 5.6, height - 3.4)
    }

    /// A pair of oars hung crossed on pegs on a wall drawn with `wall`, centred on `u`, their grips at `top`.
    private mutating func hungOars(_ u: Double, top: Double) {
        typealias I = IronOldBuildingsInk
        for s in [-1.0, 1.0] {
            let grip = uv(u - s * 7, top), neck = uv(u + s * 4.5, top - 13), tip = uv(u + s * 7.5, top - 18)
            svg.line([grip, neck], stroke: .colour(I.line), width: 2.2)
            svg.line([grip, neck], stroke: .colour(I.timberLight), width: 1.1)
            let across = P(s * 1.3, 0.4)
            shape([neck + across * 0.5, neck - across * 0.5, tip - across * 1.1, tip + across * 1.1], .colour(I.timberLight), width: 0.6)
        }
        for s in [-1.0, 1.0] { svg.circle(uv(u + s * 3.6, top - 4.4), 0.6, fill: .colour(I.ironDark)) }
    }

    /// A net hung from pegs on a wall drawn with `wall`, from `u0` to `u1`,
    /// sagging `drop` points below `top`, its mesh drawn in diamonds, floats of cork along its top.
    private mutating func hungNet(_ u0: Double, _ u1: Double, top: Double, drop: Double) {
        typealias I = IronOldBuildingsInk
        let mid = (u0 + u1) / 2
        var outline = PathData()
        outline.move(uv(u0, top))
        outline.quad(uv(mid, top - 2.2), uv(u1, top))
        outline.line(uv(u1 - 1.4, top - drop * 0.8))
        outline.quad(uv(mid, top - drop - 1.6), uv(u0 + 1.4, top - drop * 0.8))
        outline.close()
        svg.path(outline, fill: .colour(I.reed), opacity: 0.3)
        var mesh = PathData()
        for k in stride(from: -drop, to: u1 - u0 + drop, by: 2.2) {
            mesh.move(uv(u0 + k, top)); mesh.line(uv(u0 + k + drop, top - drop))
            mesh.move(uv(u0 + k, top)); mesh.line(uv(u0 + k - drop, top - drop))
        }
        svg.raw("<defs><clipPath id=\"hung-net\"><path d=\"\(outline.text)\"/></clipPath></defs><g clip-path=\"url(#hung-net)\">")
        svg.path(mesh, stroke: .colour(I.reedShade), width: 0.45)
        svg.raw("</g>")
        svg.path(outline, stroke: .colour(I.line), width: 0.6, opacity: 0.8)
        for k in 0..<4 {
            let t = (Double(k) + 0.5) / 4
            let c = uv(u0 + (u1 - u0) * t, top - 2.2 * 4 * t * (1 - t) * 0.5 - 0.3)
            svg.ellipse(c, 1, 0.7, fill: .colour(I.clay), stroke: .colour(I.line), width: 0.4)
        }
        for u in [u0, u1] { svg.circle(uv(u, top + 0.4), 0.6, fill: .colour(I.ironDark)) }
    }

    /// Draws what `content` draws only to the left of the shed's near corner on
    /// the screen, so that the part of it inside the shed is hidden behind the long wall.
    private mutating func withinOpening(_ name: String, _ content: (inout IronOldBuildingsPainter) -> Void) {
        let edge = iso(IronShed.x1, IronShed.y1).x - 0.6
        svg.raw("<defs><clipPath id=\"boat-house-\(name)\"><rect x=\"-200\" y=\"-200\" width=\"\(num(edge + 200))\" height=\"400\"/>"
                + "</clipPath></defs><g clip-path=\"url(#boat-house-\(name))\">")
        content(&self)
        svg.raw("</g>")
    }

    /// The slipway: two timber rails on sleepers, sloping from the shed's
    /// floor at `y0` down to the quay's edge at `y1`, toward +y or −y.
    private mutating func slipway(from y0: Double, to y1: Double) {
        typealias I = IronOldBuildingsInk
        typealias S = IronShed
        let (a, b) = (S.slipX0, S.slipX1)
        let d = y1 > y0 ? 1.0 : -1.0
        func h(_ y: Double) -> Double { S.quay + 1.6 - 1.4 * max(0, (y - y0) / (y1 - y0)) }
        shadow([iso(a, y0, S.quay), iso(b + 0.04, y0, S.quay), iso(b + 0.04, y1, S.quay), iso(a, y1, S.quay)], opacity: 0.1)
        // The sleepers, the farthest first.
        var sleepers = Array(stride(from: 0.04, through: abs(y1 - y0) - 0.03, by: 0.1)).map { y0 + d * $0 }
        if d < 0 { sleepers.reverse() }
        for y in sleepers {
            let top = h(y)
            shape([iso(a, y - 0.025, top), iso(b, y - 0.025, top), iso(b, y + 0.025, top), iso(a, y + 0.025, top)],
                  .colour(I.timberDark), width: 0.6)
        }
        for x in [a + 0.08, b - 0.08] {
            let rail = [iso(x - 0.03, y0, h(y0) + 1.4), iso(x + 0.03, y0, h(y0) + 1.4), iso(x + 0.03, y1, h(y1) + 1.4), iso(x - 0.03, y1, h(y1) + 1.4)]
            shape(rail, .colour(I.timberLight), width: 0.7)
            // The rail's end, where it faces the viewer.
            if d > 0 {
                colour([iso(x + 0.03, y1, h(y1)), iso(x + 0.03, y1, h(y1) + 1.4), iso(x - 0.03, y1, h(y1) + 1.4), iso(x - 0.03, y1, h(y1))],
                       .colour(I.timber))
            }
        }
    }

    /// The fishing boat resting on the slip, along y from its stern at `stern`
    /// to its bow at `bow`, toward +y or −y: the near (+x) side of its hull,
    /// its hollow over the near gunwale, the band of the owner's colour, the
    /// painted eye and the curled stem. Under construction (`planked` false)
    /// only its keel, stem, sternpost, ribs and lowest planks stand.
    private mutating func restingBoat(planked: Bool, stern: Double, bow: Double) {
        typealias I = IronOldBuildingsInk
        typealias S = IronShed
        let steps = 14
        let ts = (0...steps).map { Double($0) / Double(steps) }
        let d = bow > stern ? 1.0 : -1.0
        func y(_ t: Double) -> Double { stern + (bow - stern) * t }
        func floor(_ t: Double) -> Double { S.quay + 2.8 - 0.8 * t }
        func beam(_ t: Double) -> Double { 0.17 * pow(sin(t * .pi), 0.5) }
        func gunwale(_ t: Double) -> Double { floor(t) + 9 + 4 * pow(abs(2 * t - 1), 2.6) }
        func keel(_ t: Double) -> Double { floor(t) + (1 - pow(sin(t * .pi), 0.6)) * 5 }
        let x = S.boatX
        let nearRim = ts.map { iso(x + beam($0), y($0), gunwale($0)) }
        let farRim = ts.map { iso(x - beam($0), y($0), gunwale($0)) }
        let keelLine = ts.map { iso(x + beam($0) * 0.45, y($0), keel($0)) }
        // The chocks under the hull.
        for t in [0.3, 0.7] {
            shape([iso(x - 0.12, y(t), floor(t) - 1), iso(x + 0.14, y(t), floor(t) - 1), iso(x + 0.14, y(t), floor(t) + 1.8),
                   iso(x - 0.12, y(t), floor(t) + 1.8)], .colour(I.timberDark), width: 0.6)
        }
        if !planked {
            // The ribs standing up from the keel, the far ones first, and the first strakes along their feet.
            for t in stride(from: 0.16, through: 0.84, by: 0.1) {
                let rib = [iso(x - beam(t), y(t), gunwale(t)), iso(x - beam(t) * 0.7, y(t), keel(t) + 2), iso(x, y(t), keel(t)),
                           iso(x + beam(t) * 0.7, y(t), keel(t) + 2), iso(x + beam(t), y(t), gunwale(t))]
                svg.line(rib, stroke: .colour(I.line), width: 1.9)
                svg.line(rib, stroke: .colour(I.timberLight), width: 0.9)
            }
            pole(keelLine.first!, keelLine.last!, width: 1.8, colour: I.timber)
            // The clamps along the ribs' heads, which give the boat its shape.
            svg.line(farRim, stroke: .colour(I.line), width: 2.2)
            svg.line(farRim, stroke: .colour(I.timberLight), width: 1.1)
            let strake = ts.filter { $0 > 0.08 && $0 < 0.92 }
            let lower = strake.map { iso(x + beam($0) * 0.7, y($0), keel($0) + 2.4) }
            let upper = strake.map { iso(x + beam($0) * 0.86, y($0), keel($0) + 4.6) }
            shape(lower + upper.reversed(), .colour(I.timberLight), width: 0.8)
            svg.line(nearRim, stroke: .colour(I.line), width: 2.2)
            svg.line(nearRim, stroke: .colour(I.timberLight), width: 1.1)
            stem(x: x, y: y(1), toward: d, from: gunwale(1) - 9, keel: keel(1))
            // The sternpost.
            pole(iso(x, y(0), keel(0)), iso(x, y(0) - d * 0.03, gunwale(0) + 4), width: 1.8, colour: I.timber)
            return
        }
        // The hollow between the gunwales, the far inner side lit, a thwart across.
        shape(farRim + nearRim.reversed(), .colour(I.dark), width: 1)
        colour(farRim + farRim.reversed().map { $0 + P(0, 2.6) }, .colour(I.timberDark))
        for t in [0.32, 0.62] {
            line([iso(x - beam(t), y(t), gunwale(t) - 1.4), iso(x + beam(t), y(t), gunwale(t) - 1.4)], width: 2.4)
            svg.line([iso(x - beam(t), y(t), gunwale(t) - 1.4), iso(x + beam(t), y(t), gunwale(t) - 1.4)],
                     stroke: .colour(I.timberLight), width: 1.2)
        }
        // The near side, from the gunwale down to the keel: tarred below, planked, the band, the eye.
        shape(nearRim + keelLine.reversed(), .colour(I.timber), width: 1.1)
        let band = nearRim.map { $0 + P(0, 1.2) } + nearRim.reversed().map { $0 + P(0, 3.6) }
        colour(band, .team)
        svg.polygon(band, fill: .none, stroke: .colour(I.line), width: 0.5)
        var seams = PathData()
        for k in [5.6, 7.6] {
            let row = ts.filter { $0 > 0.06 && $0 < 0.94 }.map { iso(x + beam($0) * 0.9, y($0), gunwale($0) - k) }
            seams.move(row[0]); for p in row.dropFirst() { seams.line(p) }
        }
        svg.path(seams, stroke: .colour(I.line), width: 0.45, opacity: 0.7)
        colour(keelLine + keelLine.reversed().map { $0 + P(0, -2.2) }, .colour(I.timberDark))
        eye(at: iso(x + beam(0.86) * 0.9, y(0.86), gunwale(0.86) - 5.2))
        stem(x: x, y: y(1), toward: d, from: gunwale(1), keel: keel(1))
        // The sternpost, a little raised.
        pole(iso(x, y(0), gunwale(0) - 2), iso(x, y(0) - d * 0.04, gunwale(0) + 4), width: 1.8, colour: I.timber)
        line(nearRim, width: 1.2)
        svg.line(nearRim.map { $0 + P(0, 0.8) }, stroke: .colour(I.timberLight), width: 0.6)
    }

    /// The stem at the bow, from the keel up past the gunwale to a curl
    /// turned forward; the bow points toward +y (`toward` 1) or −y (−1).
    private mutating func stem(x: Double, y: Double, toward s: Double, from top: Double, keel: Double) {
        typealias I = IronOldBuildingsInk
        let foot = iso(x, y, keel), head = iso(x, y + s * 0.035, top + 6)
        var d = PathData()
        d.move(foot)
        d.quad(iso(x, y + s * 0.04, top), head)
        d.quad(head + P(-0.4 * s, -3.4), head + P(-2.6 * s, -2.4))
        d.quad(head + P(-3.2 * s, -0.6), head + P(-1.6 * s, 0))
        svg.path(d, stroke: .colour(I.line), width: 2.9)
        svg.path(d, stroke: .colour(I.timber), width: 1.6)
    }

    /// The eye painted on the bow: a white almond rimmed in red, with a dark pupil.
    private mutating func eye(at c: P) {
        typealias I = IronOldBuildingsInk
        var d = PathData()
        d.move(c + P(-2.4, 0.6))
        d.quad(c + P(0, -1.9), c + P(2.4, -0.6))
        d.quad(c + P(0, 1.9), c + P(-2.4, 0.6))
        d.close()
        svg.path(d, fill: .colour(I.light), stroke: .colour(I.tile), width: 0.7)
        svg.circle(c, 0.75, fill: .colour(I.dark))
    }

    /// An iron anchor leaning against the wall: a shank with a ring at its head, two curved arms, and a stock of timber.
    private mutating func anchor(at foot: P) {
        typealias I = IronOldBuildingsInk
        let crown = foot + P(-1, -1), head = foot + P(3.4, -17)
        svg.ellipse(foot + P(1.6, 0.2), 5, 1.4, fill: .colour("#000000"), opacity: 0.14)
        svg.line([crown, head], stroke: .colour(I.line), width: 2.4)
        svg.line([crown, head], stroke: .colour(I.iron), width: 1.2)
        var arms = PathData()
        arms.move(crown + P(-5, -3.6))
        arms.quad(crown + P(-2.6, 1.6), crown)
        arms.quad(crown + P(3, 1.2), crown + P(5.2, -3.4))
        svg.path(arms, stroke: .colour(I.line), width: 2.4)
        svg.path(arms, stroke: .colour(I.iron), width: 1.2)
        for tip in [crown + P(-5, -3.6), crown + P(5.2, -3.4)] {
            svg.path("M\(num(tip.x - 1.2)),\(num(tip.y + 0.2)) L\(num(tip.x)),\(num(tip.y - 1.8)) L\(num(tip.x + 1.2)),\(num(tip.y + 0.2)) Z",
                     fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.5)
        }
        pole(head + P(-4.4, 2.6), head + P(4.6, 1.6), width: 1.5, colour: I.timber)
        svg.circle(head + P(0.4, -1.6), 1.4, fill: .none, stroke: .colour(I.line), width: 1.6)
        svg.circle(head + P(0.4, -1.6), 1.4, fill: .none, stroke: .colour(I.ironLight), width: 0.6)
    }

    /// A wicker basket of fish, their tails over its rim.
    private mutating func fishBasket(at p: P) {
        typealias I = IronOldBuildingsInk
        svg.ellipse(p + P(0.8, 0.4), 5.2, 1.6, fill: .colour("#000000"), opacity: 0.14)
        shape([p + P(-4, -5), p + P(4, -5), p + P(3.2, 0), p + P(-3.2, 0)], .colour(I.reed), width: 0.8)
        var weave = PathData()
        for v in [-1.6, -3.2] { weave.move(p + P(-3.6, v)); weave.line(p + P(3.6, v)) }
        svg.path(weave, stroke: .colour(I.reedShade), width: 0.6)
        for (dx, a) in [(-1.6, -0.5), (0.6, 0.3), (2.2, -0.2)] {
            let base = p + P(dx, -5.2)
            let tip = base + P(a * 3, -3.2)
            shape([base + P(-0.6, 0), tip + P(-1.3, -0.4), tip + P(0, 0.6), tip + P(1.3, -0.4), base + P(0.6, 0)], .colour(I.ironLight),
                  width: 0.5)
        }
        svg.ellipse(p + P(0, -5), 4, 1.2, fill: .none, stroke: .colour(I.line), width: 0.7)
    }

    /// A stone bollard with an iron ring, a rope made fast to it.
    private mutating func bollard(at foot: P) {
        typealias I = IronOldBuildingsInk
        svg.ellipse(foot + P(0.8, 0.4), 4, 1.3, fill: .colour("#000000"), opacity: 0.14)
        shape([foot + P(-2.6, 0), foot + P(2.6, 0), foot + P(2.2, -6), foot + P(-2.2, -6)], .colour(I.stone), width: 0.8)
        colour([foot + P(0.6, 0), foot + P(2.6, 0), foot + P(2.2, -6), foot + P(0.6, -6)], .colour(I.stoneShade))
        svg.ellipse(foot + P(0, -6.6), 2.9, 1.2, fill: .colour(I.stoneTop), stroke: .colour(I.line), width: 0.7)
        svg.ellipse(foot + P(0, -3.4), 1.6, 1.3, fill: .none, stroke: .colour(I.line), width: 1.4)
        svg.ellipse(foot + P(0, -3.4), 1.6, 1.3, fill: .none, stroke: .colour(I.ironLight), width: 0.5)
        var rope = PathData()
        rope.move(foot + P(-1.4, -2.2))
        rope.quad(foot + P(-6, 1.6), foot + P(-11, 0.8))
        svg.path(rope, stroke: .colour(I.line), width: 1.5)
        svg.path(rope, stroke: .colour(I.reed), width: 0.7)
    }

    // MARK: Under construction

    /// The boat house being built: the footing laid in fresh stone, the posts
    /// and trusses of the frame with the pennant on the ridge pole, a few boards
    /// on, and a boat on the slip with its keel and ribs set up.
    private mutating func boatShedRising() {
        typealias I = IronOldBuildingsInk
        typealias S = IronShed
        let (x0, x1, y0, y1, h0) = (S.x0, S.x1, S.y0, S.y1, S.quay)
        let h1 = h0 + S.eaves, ridge = h1 + S.rise, mid = (x0 + x1) / 2
        shadow([iso(x1, y0, h0), iso(x1 + 0.18, y0 + 0.1, h0), iso(x1 + 0.18, y1 + 0.06, h0), iso(x1, y1, h0)], opacity: 0.1)
        // The footing along the back and the long side, in fresh stone.
        for (a, b, c, d) in [(x0, y0, x1, y0 + 0.08), (x0, y0, x0 + 0.08, y1), (x1 - 0.08, y0, x1, y1)] {
            block(a, b, c, d, h0, h0 + S.footing, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade),
                  width: 0.8)
        }
        // The far posts and trusses first.
        let ys = [y0 + 0.04, (y0 + y1) / 2, y1 - 0.04]
        for y in ys { pole(iso(x0 + 0.04, y, h0 + S.footing), iso(x0 + 0.04, y, h1), width: 2, colour: I.timber) }
        pole(iso(x0 + 0.04, y0, h1), iso(x0 + 0.04, y1, h1), width: 1.8, colour: I.timber)
        for y in ys.dropLast() {
            pole(iso(x0 + 0.04, y, h1), iso(mid, y, ridge), width: 1.8, colour: I.timber)
        }
        pole(iso(mid, y0 - 0.04, ridge), iso(mid, y1 + 0.04, ridge), width: 2.2)
        withinOpening("slip") { $0.slipway(from: S.y1 - 0.5, to: S.slipEnd) }
        withinOpening("boat") { $0.restingBoat(planked: false, stern: S.sternY, bow: S.bowY) }
        // The near posts, the wall plate, the boards nailed on below, and the gable's truss.
        wall(.right, from: x1, y1, at: h0 + S.footing) { p in
            let length = (y1 - y0) * 32
            p.colour(p.panel(0, 0, length * 0.55, 9.6), .colour(I.timber))
            var laps = PathData()
            for v in stride(from: 0.0, through: 9.6, by: 3.2) { laps.move(p.uv(0, v)); laps.line(p.uv(length * 0.55, v)) }
            p.svg.path(laps, stroke: .colour(I.line), width: 0.5, opacity: 0.8)
            p.line([p.uv(0, 0), p.uv(0, 9.6), p.uv(length * 0.55, 9.6), p.uv(length * 0.55, 0)], width: 0.8)
        }
        for y in ys { pole(iso(x1 - 0.04, y, h0 + S.footing), iso(x1 - 0.04, y, h1), width: 2, colour: I.timberLight) }
        pole(iso(x1 - 0.04, y0, h1), iso(x1 - 0.04, y1, h1), width: 1.8)
        for y in ys.dropLast() { pole(iso(x1 - 0.04, y, h1), iso(mid, y, ridge), width: 1.8) }
        let gable = y1 - 0.04
        pole(iso(x0 + 0.04, gable, h1), iso(mid, gable, ridge + 0.8), width: 2)
        pole(iso(x1 - 0.04, gable, h1), iso(mid, gable, ridge + 0.8), width: 2)
        pole(iso(x0 - 0.02, gable, h1), iso(x1 + 0.02, gable, h1), width: 2)
        // The owner's colour already on the tie beam of the gable.
        let beam = [iso(x0 + 0.08, gable + 0.005, h1 - 2.6), iso(x1 - 0.08, gable + 0.005, h1 - 2.6),
                    iso(x1 - 0.08, gable + 0.005, h1 - 0.6), iso(x0 + 0.08, gable + 0.005, h1 - 0.6)]
        shape(beam, .team, width: 0.7)
        pennant(at: iso(mid, gable, ridge + 0.8), height: 16, length: 14)
        ladder(foot: iso(x1 + 0.2, -0.36, h0), iso(x1 + 0.2, -0.2, h0), head: iso(x1 + 0.02, -0.36, h1 + 2),
               iso(x1 + 0.02, -0.2, h1 + 2), rungs: 6)
        // Boards and tiles to hand.
        planks(0.48, 0.86, 0.5, on: h0)
        roofTiles(-0.94, 0.42, -0.74, 0.66, from: h0, height: 6)
        roofTiles(0.62, -0.86, 0.86, -0.68, from: h0, height: 6)
        bollard(at: iso(0.36, 0.88, h0))
    }

    // MARK: The jetty

    /// The timber jetty with its stone head, running from the middle of the
    /// quay's edge toward +y (`d` 1) or −y (−1) over the water: piles with a
    /// ring of water at each foot, a deck of planks, and the head of dressed
    /// stone with an iron ring on its +x face. Under construction the piles
    /// stand on their bearers, a few planks are down and the head is half raised.
    private mutating func jetty(toward d: Double, complete: Bool) {
        typealias I = IronOldBuildingsInk
        typealias S = IronShed
        let w = S.dockHalf
        func span(_ a: Double, _ b: Double) -> (Double, Double) { (min(d * a, d * b), max(d * a, d * b)) }
        let headTop = complete ? S.head : S.deck - 0.8
        let (h0, h1) = span(S.headStart, S.dockEnd)
        func ripple(around points: [P]) {
            svg.polygon(points, fill: .none, stroke: .colour(I.light), width: 0.7, opacity: 0.75)
        }
        func head() {
            let o = 0.05
            ripple(around: level(-w - 0.05 - o, h0 - o, w + 0.05 + o, h1 + o))
            block(-w - 0.05, h0, w + 0.05, h1, -0.6, headTop, top: .colour(complete ? I.stoneTop : I.rawStoneTop),
                  left: .colour(complete ? I.stone : I.rawStone), right: .colour(complete ? I.stoneShade : I.rawStoneShade), width: 0.9)
            // The courses on its +x face, and the iron ring.
            wall(.right, from: w + 0.05, h1, at: -0.6) { p in
                let length = (h1 - h0) * 32
                p.courses(0, length, 0, headTop + 0.6, course: 2.4, brick: 5)
                if complete {
                    p.svg.ellipse(p.uv(length / 2, 2.6), 1.3, 1.1, fill: .none, stroke: .colour(I.line), width: 1.3)
                    p.svg.ellipse(p.uv(length / 2, 2.6), 1.3, 1.1, fill: .none, stroke: .colour(I.ironLight), width: 0.5)
                    p.svg.circle(p.uv(length / 2, 3.8), 0.5, fill: .colour(I.ironDark))
                }
            }
        }
        if d < 0 { head() }
        // The piles, two to a bent along the deck's sides, the farthest first,
        // each with its ring of water; they stand above the deck as posts.
        var piles: [(Double, Double)] = []
        for t in [1.1, 1.4, S.headStart - 0.04] { for x in [-w - 0.01, w + 0.01] { piles.append((x, d * t)) } }
        piles.sort { $0.0 + $0.1 < $1.0 + $1.1 }
        for (x, y) in piles {
            let foot = iso(x, y, 0)
            svg.ellipse(foot + P(0, 0.4), 3.4, 1.4, fill: .none, stroke: .colour(I.light), width: 0.7, opacity: 0.85)
        }
        func pile(_ x: Double, _ y: Double) {
            pole(iso(x, y, -0.4), iso(x, y, S.deck + 2.4), width: 2.2, colour: I.timberDark)
            svg.ellipse(iso(x, y, S.deck + 2.4), 1.1, 0.55, fill: .colour(I.timberLight), stroke: .colour(I.line), width: 0.4)
        }
        for (x, y) in piles where x < 0 { pile(x, y) }
        // The deck: planks across it on two bearers. Under construction, the bearers bare beyond the first planks.
        let (y0, y1) = span(1, S.headStart)
        if complete {
            block(-w, y0, w, y1, S.deckFoot, S.deck, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
                  width: 0.9)
            var seams = PathData()
            for t in stride(from: 1.07, to: S.headStart - 0.02, by: 0.07) { seams.move(iso(-w, d * t, S.deck)); seams.line(iso(w, d * t, S.deck)) }
            svg.path(seams, stroke: .colour(I.line), width: 0.4, opacity: 0.55)
        } else {
            for x in [-w + 0.04, w - 0.04] { pole(iso(x, y0, S.deckFoot + 0.6), iso(x, y1, S.deckFoot + 0.6), width: 1.8, colour: I.timber) }
            let (p0, p1) = span(1, 1.34)
            block(-w, p0, w, p1, S.deckFoot, S.deck, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
                  width: 0.9)
            var seams = PathData()
            for t in stride(from: 1.07, to: 1.33, by: 0.07) { seams.move(iso(-w, d * t, S.deck)); seams.line(iso(w, d * t, S.deck)) }
            svg.path(seams, stroke: .colour(I.line), width: 0.4, opacity: 0.55)
        }
        for (x, y) in piles where x > 0 { pile(x, y) }
        if d > 0 { head() }
    }

    // MARK: The back view

    /// The boat house from behind, complete: the same shed turned a quarter,
    /// its y measurements reflected, so that the slip runs out of the far
    /// gable toward −y and the landward gable, closed, faces the viewer.
    private mutating func boatShedBack() {
        typealias I = IronOldBuildingsInk
        typealias S = IronShed
        let (x0, x1, y0, y1, h0, h1) = (S.x0, S.x1, -S.y1, -S.y0, S.quay, S.quay + S.eaves)
        let front = (x1 - x0) * 32, side = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.28, y0 + 0.16, h0), iso(x1 + 0.28, 0.98, h0), iso(x1, y1, h0)])
        // The water end, behind the shed: the slip, the boat's bow out on it, the bollard and the basket at its foot.
        slipway(from: y0 + 0.5, to: -S.slipEnd)
        restingBoat(planked: true, stern: -S.sternY - S.backHaul, bow: -S.bowY - S.backHaul)
        bollard(at: iso(0.36, -0.88, h0))
        fishBasket(at: iso(0.66, -0.62, h0))
        // The long wall facing +x, as in the side view: boards over the footing, the band, the windows, the oars and the net.
        wall(.right, from: x1, y1, at: h0) { p in
            p.boardedWall(side, S.eaves)
            p.grille(5, 11, w: 5, h: 6)
            p.grille(side - 10, 11, w: 5, h: 6)
            p.hungOars(side * 0.5, top: 23)
            p.hungNet(side * 0.5 - 6.5, side * 0.5 + 6.5, top: 21.4, drop: 10)
        }
        // The landward gable: boards over the footing, the band, the door of painted planks between two barred windows.
        wall(.left, from: x0, y1, at: h0) { p in
            p.boardedWall(front, S.eaves)
            p.grille(2.6, 11, w: 4, h: 6)
            p.grille(front - 6.6, 11, w: 4, h: 6)
            p.plankDoor(front / 2, w: 9, h: 15)
        }
        line([iso(x0, y1, h0), iso(x0, y1, h1)], width: 1.2)
        line([iso(x1, y1, h0), iso(x1, y1, h1)], width: 1.2)
        line([iso(x1, y0, h0), iso(x1, y0, h1)], width: 1.2)
        line([iso(x0, y1, h0), iso(x1, y1, h0), iso(x1, y0, h0)], width: 1.2)
        gabledRoof(x0, y0, x1, y1, eaves: h1, rise: S.rise)
        // The pennant at the peak of the far gable, over the water.
        pennant(at: iso((x0 + x1) / 2 - 0.06, y0 - 0.04, h1 + S.rise + 1), height: 17, length: 14)
        // Stores by the landward end: the anchor against the long wall, and amphorae.
        anchor(at: iso(x1 + 0.4, 0.18, h0))
        amphora(at: iso(0.78, 0.62, h0), size: 0.8, paint: I.clayShade)
        amphora(at: iso(0.58, 0.8, h0), size: 0.9)
    }

    /// A door of painted planks in a timber frame on a wall drawn with `wall`,
    /// centred on `u`, `w` wide and `h` tall, with iron straps and a ring, on a step of stone.
    private mutating func plankDoor(_ u: Double, w: Double, h: Double) {
        typealias I = IronOldBuildingsInk
        let r = w / 2
        shape(panel(u - r - 1.4, 0, u + r + 1.4, h + 1.6), .colour(I.timberLight), width: 0.8)
        shape(panel(u - r, 0.4, u + r, h), .colour(I.sea), width: 0.8)
        var seams = PathData()
        for k in 1..<4 {
            let x = u - r + w * Double(k) / 4
            seams.move(uv(x, 0.8)); seams.line(uv(x, h - 0.4))
        }
        svg.path(seams, stroke: .colour(I.seaShade), width: 0.6)
        for v in [3.0, h - 3.4] {
            shape(panel(u - r + 0.3, v - 0.55, u + r - 0.3, v + 0.55), .colour(I.ironDark), width: 0.3)
            for x in stride(from: u - r + 1.2, to: u + r, by: 2.2) { svg.circle(uv(x, v), 0.3, fill: .colour(I.ironLight)) }
        }
        svg.circle(uv(u + r * 0.55, h * 0.5), 1, fill: .none, stroke: .colour(I.line), width: 0.9)
        svg.circle(uv(u + r * 0.55, h * 0.5), 1, fill: .none, stroke: .colour(I.ironLight), width: 0.4)
        shape(panel(u - r - 2.2, -0.8, u + r + 2.2, 0.4), .colour(I.stoneTop), width: 0.6)
    }

    /// The boat house from behind, under construction: the frame turned as in
    /// `boatShedBack`, the footing laid across the landward end either side of
    /// the door, and the boat on the slip running out toward −y.
    private mutating func boatShedBackRising() {
        typealias I = IronOldBuildingsInk
        typealias S = IronShed
        let (x0, x1, y0, y1, h0) = (S.x0, S.x1, -S.y1, -S.y0, S.quay)
        let h1 = h0 + S.eaves, ridge = h1 + S.rise, mid = (x0 + x1) / 2
        func footing(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
            block(a, b, c, d, h0, h0 + S.footing, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade),
                  width: 0.8)
        }
        shadow([iso(x1, y0, h0), iso(x1 + 0.18, y0 + 0.1, h0), iso(x1 + 0.18, 0.96, h0), iso(x1, y1, h0)], opacity: 0.1)
        // The tiles stacked at the water end, and the bollard at the slip's foot.
        roofTiles(0.62, -0.86, 0.86, -0.68, from: h0, height: 6)
        bollard(at: iso(0.36, -0.88, h0))
        // The footing along the far long side, then the far posts and trusses.
        footing(x0, y0, x0 + 0.08, y1)
        let ys = [y0 + 0.04, (y0 + y1) / 2, y1 - 0.04]
        for y in ys { pole(iso(x0 + 0.04, y, h0 + S.footing), iso(x0 + 0.04, y, h1), width: 2, colour: I.timber) }
        pole(iso(x0 + 0.04, y0, h1), iso(x0 + 0.04, y1, h1), width: 1.8, colour: I.timber)
        for y in ys.dropLast() { pole(iso(x0 + 0.04, y, h1), iso(mid, y, ridge), width: 1.8, colour: I.timber) }
        pole(iso(mid, y0 - 0.04, ridge), iso(mid, y1 + 0.04, ridge), width: 2.2)
        slipway(from: y0 + 0.5, to: -S.slipEnd)
        restingBoat(planked: false, stern: -S.sternY - S.backHaul, bow: -S.bowY - S.backHaul)
        // The footing along the near long side, and across the landward end either side of the door.
        let door0 = mid - 0.14, door1 = mid + 0.14
        footing(x1 - 0.08, y0, x1, y1)
        footing(x0, y1 - 0.08, door0, y1)
        footing(door1, y1 - 0.08, x1, y1)
        // The door's posts and lintel, set up in the gap.
        for x in [door0 + 0.02, door1 - 0.02] { pole(iso(x, y1 - 0.04, h0), iso(x, y1 - 0.04, h0 + 16.6), width: 1.8, colour: I.timberLight) }
        pole(iso(door0 - 0.03, y1 - 0.04, h0 + 16.6), iso(door1 + 0.03, y1 - 0.04, h0 + 16.6), width: 1.8, colour: I.timberLight)
        // The near posts, the wall plate, the boards nailed on below, and the landward gable's truss.
        wall(.right, from: x1, y1, at: h0 + S.footing) { p in
            let length = (y1 - y0) * 32
            p.colour(p.panel(0, 0, length * 0.55, 9.6), .colour(I.timber))
            var laps = PathData()
            for v in stride(from: 0.0, through: 9.6, by: 3.2) { laps.move(p.uv(0, v)); laps.line(p.uv(length * 0.55, v)) }
            p.svg.path(laps, stroke: .colour(I.line), width: 0.5, opacity: 0.8)
            p.line([p.uv(0, 0), p.uv(0, 9.6), p.uv(length * 0.55, 9.6), p.uv(length * 0.55, 0)], width: 0.8)
        }
        for y in ys { pole(iso(x1 - 0.04, y, h0 + S.footing), iso(x1 - 0.04, y, h1), width: 2, colour: I.timberLight) }
        pole(iso(x1 - 0.04, y0, h1), iso(x1 - 0.04, y1, h1), width: 1.8)
        for y in ys.dropLast() { pole(iso(x1 - 0.04, y, h1), iso(mid, y, ridge), width: 1.8) }
        let gable = y1 - 0.04
        pole(iso(x0 + 0.04, gable, h1), iso(mid, gable, ridge + 0.8), width: 2)
        pole(iso(x1 - 0.04, gable, h1), iso(mid, gable, ridge + 0.8), width: 2)
        pole(iso(x0 - 0.02, gable, h1), iso(x1 + 0.02, gable, h1), width: 2)
        // The owner's colour already on the tie beam of the landward gable.
        let beam = [iso(x0 + 0.08, gable + 0.005, h1 - 2.6), iso(x1 - 0.08, gable + 0.005, h1 - 2.6),
                    iso(x1 - 0.08, gable + 0.005, h1 - 0.6), iso(x0 + 0.08, gable + 0.005, h1 - 0.6)]
        shape(beam, .team, width: 0.7)
        // The pennant on the ridge pole's end over the water.
        pennant(at: iso(mid, y0 - 0.04, ridge), height: 16, length: 14)
        ladder(foot: iso(x1 + 0.2, 0.2, h0), iso(x1 + 0.2, 0.36, h0), head: iso(x1 + 0.02, 0.2, h1 + 2),
               iso(x1 + 0.02, 0.36, h1 + 2), rungs: 6)
        planks(0.48, 0.86, 0.72, on: h0)
    }

    /// A stack of sawn boards lying along x from `x0` to `x1` at `y`.
    private mutating func planks(_ x0: Double, _ x1: Double, _ y: Double, on h: Double) {
        typealias I = IronOldBuildingsInk
        for k in 0..<4 {
            let base = h + Double(k) * 1.5, dx = Double(k % 2) * 0.02
            block(x0 + dx, y - 0.08, x1 + dx, y + 0.08, base, base + 1.5, top: .colour(I.timberLight), left: .colour(I.timber),
                  right: .colour(I.timberDark), width: 0.6)
        }
    }
}
