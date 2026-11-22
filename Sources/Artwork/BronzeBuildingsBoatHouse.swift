// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age boat house (ruled 2026-11-21): a reed-roofed shed on a quay
// of plastered mud brick, as the marsh people still build their reed halls. A
// vault of reed matting stands on arches of bundled reed; its end toward +x is
// open, framed by a thick bundled arch between two tall reed columns with
// tufted heads, bound in the owner's colour; a reed boat lies in it on its
// chocks, its curled bow out under the arch. The quay's two faces carry a band
// of the owner's colour, a pennant flies over the arch, a mooring post with a
// bronze ring stands at the quay's edge, a net hangs to dry on two poles, and
// jars and a stack of reed bundles stand about. The footprint lies on land and
// the water may lie beside any of its edges. Its footprint is two tiles
// square: x and y run from -1 to 1. From the middle of its water edge a short
// jetty (ruled 2026-11-22) runs a tile out over the water: a deck of mud brick
// in a frame of bundled reed, at the quay's height, on bound reed posts
// standing in the water, two taller posts at its head bound in the owner's
// colour; a ring on the water round each post. It is scenery: boats pass it.
//
// Under construction: the quay of bare mud brick, the arches of bundled reed
// planted and tied, one mat laid over them, the columns half raised, and
// bundles of reed stacked ready; the jetty's posts stand in the water, its
// reed stringers laid along them, and its deck laid over the half by the quay.
//
// It is drawn in two views (ruled 2026-11-22): the side view, its open end
// toward +x (the screen's lower right), and the back view, the same building
// turned a quarter so that its open end faces -y (the screen's upper right,
// away from the viewer). The back view shows the shed's landward end: a
// screen of reed lattice with a doorway framed in bundled reed bound in the
// owner's colour, jars of stores beside it. The drawing mirrors each view for
// the other two edges (`FootprintEdge.boatHouseView`).

/// The boat house's measurements, about the centre of its footprint: distances
/// in tiles along the map's axes, heights in points.
private enum ReedShed {
    /// The quay's height.
    static let quay = 6.0
    /// The vault: its length along x, its span along y, and the height of its crown above the quay.
    static let x0 = -0.86, x1 = 0.3, y0 = -0.72, y1 = 0.24, crown = 31.0
    static var yc: Double { (y0 + y1) / 2 }
    /// The inks the shed adds to the Bronze palette: reed in the sun, and the shed's dark inside.
    static let reedLit = "#e2c47e"
    static let inside = "#4a3a2c"
}

/// Which way the shed stands on its footprint: its open end toward +x (the
/// side view) or toward -y (the back view).
private enum ShedTurn {
    case side, back

    /// The place on the map of a point given in the shed's own frame: `along`
    /// toward its open end, `across` toward its flank that faces the viewer.
    func map(_ along: Double, _ across: Double) -> (x: Double, y: Double) {
        self == .side ? (along, across) : (across, -along)
    }
}

extension BronzeBuildingsPainter {
    /// The boat house in the side view.
    mutating func boatHouse(complete: Bool) {
        shedQuay(complete: complete)
        // The jetty lies before the quay, toward the viewer.
        jetty(complete: complete, turn: .side)
        if complete { reedShed() } else { reedShedRising() }
    }

    /// The boat house in the back view: the same building turned so that its
    /// open end faces -y, its landward end toward the viewer.
    mutating func boatHouseFromBehind(complete: Bool) {
        // The jetty lies beyond the quay, away from the viewer.
        jetty(complete: complete, turn: .back)
        shedQuay(complete: complete)
        if complete { reedShedFromBehind() } else { reedShedRisingFromBehind() }
    }

    /// The screen point of a place given in the shed's frame (`ShedTurn.map`), `h` points up.
    private func shed(_ along: Double, _ across: Double, _ h: Double, _ turn: ShedTurn) -> P {
        let (x, y) = turn.map(along, across)
        return iso(x, y, h)
    }

    // MARK: The quay

    /// The quay over the whole footprint: plastered brick with the owner's band
    /// along both faces, or bare brick while it is built.
    private mutating func shedQuay(complete: Bool) {
        typealias I = BronzeBuildingsInk
        let h = complete ? ReedShed.quay : ReedShed.quay - 1.5
        if complete {
            block(-1, -1, 1, 1, 0, h, top: .colour(I.paving), left: .colour(I.light), right: .colour(I.plasterShade), width: 1)
            for (side, x, y) in [(BronzeBuildingsSide.left, -1.0, 1.0), (.right, 1.0, 1.0)] {
                wall(side, from: x, y) { p in
                    p.paintedBand(2, 62, 1.6, 4)
                }
            }
            // The paving's joints over the quay's top.
            var d = PathData()
            for k in stride(from: -0.6, through: 0.61, by: 0.4) {
                d.move(iso(k, -0.98, h)); d.line(iso(k, 0.98, h))
                d.move(iso(-0.98, k, h)); d.line(iso(0.98, k, h))
            }
            svg.path(d, stroke: .colour(I.pavingShade), width: 0.6)
        } else {
            block(-1, -1, 1, 1, 0, h, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick), right: .colour(I.rawBrickShade), width: 1)
            for (side, x, y) in [(BronzeBuildingsSide.left, -1.0, 1.0), (.right, 1.0, 1.0)] {
                wall(side, from: x, y) { p in p.courses(0, 64, 0, h) }
            }
        }
    }

    // MARK: The jetty

    /// The jetty from the middle of the water edge out over the water, in the
    /// shed's frame: from `along` 1 to its head at `Jetty.head`, `Jetty.half`
    /// either side of the middle. Complete, its deck of mud brick in a frame of
    /// reed bundles at the quay's height, and the two posts at its head; under
    /// construction, the posts, the reed stringers along them, and the deck laid
    /// over the half nearer the quay.
    private mutating func jetty(complete: Bool, turn: ShedTurn) {
        typealias I = BronzeBuildingsInk
        let top = complete ? ReedShed.quay : ReedShed.quay - 1.5
        let bottom = top - 2.4
        let (head, half) = (2.05, 0.21)
        let rows = [1.32, 1.68, 2.0]
        // The posts in the water, the farther first, each with its ring on the water.
        let posts = rows.flatMap { a in [(a, -half + 0.03), (a, half - 0.03)] }.sorted { p, q in
            let (px, py) = turn.map(p.0, p.1), (qx, qy) = turn.map(q.0, q.1)
            return px + py < qx + qy
        }
        for (a, b) in posts {
            let foot = shed(a, b, 0, turn)
            svg.ellipse(foot + P(0, 0.4), 4, 1.9, fill: .none, stroke: .colour(I.light), width: 0.8, opacity: 0.85)
            svg.ellipse(foot + P(0, 0.4), 6.2, 2.9, fill: .none, stroke: .colour(I.light), width: 0.5, opacity: 0.45)
            reedBundle([foot, shed(a, b, bottom + 0.4, turn)], width: 3.2, binds: [0.5])
        }
        // The deck: over the whole jetty, or over the half by the quay while it is built.
        let end = complete ? head : 1.5
        if !complete {
            // The reed stringers laid along the posts out to the head.
            for b in [-half + 0.03, half - 0.03] {
                reedBundle([shed(1, b, bottom + 1, turn), shed(head, b, bottom + 1, turn)], width: 2.6, binds: [0.4, 0.75])
            }
        }
        let (x0, y0) = turn.map(1, -half), (x1, y1) = turn.map(end, half)
        block(min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1), bottom, top,
              top: .colour(complete ? I.paving : I.rawBrickTop), left: .colour(ReedShed.reedLit), right: .colour(I.reedShade), width: 0.9)
        // The bindings round the reed frame along the side in view, and the joints of the brick over the deck.
        var d = PathData()
        for a in stride(from: 1.15, through: end - 0.05, by: 0.18) {
            d.move(shed(a, half, bottom, turn)); d.line(shed(a, half, top, turn))
        }
        svg.path(d, stroke: .colour(I.terracotta), width: 0.9)
        var joints = PathData()
        for a in stride(from: 1.13, through: end - 0.05, by: 0.13) {
            joints.move(shed(a, -half + 0.02, top, turn)); joints.line(shed(a, half - 0.02, top, turn))
        }
        joints.move(shed(1.02, 0, top, turn)); joints.line(shed(end - 0.02, 0, top, turn))
        svg.path(joints, stroke: .colour(complete ? I.pavingShade : I.rawBrickShade), width: 0.5)
        guard complete else { return }
        // The two taller posts at the head, bound in the owner's colour, the farther first.
        let heads = [(head - 0.06, -half + 0.05), (head - 0.06, half - 0.05)].sorted { p, q in
            let (px, py) = turn.map(p.0, p.1), (qx, qy) = turn.map(q.0, q.1)
            return px + py < qx + qy
        }
        for (a, b) in heads {
            let foot = shed(a, b, top, turn)
            reedBundle([foot, foot - P(0, 11)], width: 3.6, binds: [0.35, 0.75], team: true, colour: ReedShed.reedLit)
            svg.ellipse(foot - P(0, 11), 1.8, 0.9, fill: .colour(I.reedShade), stroke: .colour(I.line), width: 0.6)
        }
    }


    // MARK: Bundles of reed

    /// A bundle of reed along a line on the screen, `width` points thick: its
    /// line, its colour, the reeds' streaks along it, and bindings across it at
    /// the fractions `binds` of its length, in the owner's colour where `team`.
    private mutating func reedBundle(_ points: [P], width: Double, binds: [Double] = [], team: Bool = false,
                                     colour paint: String = BronzeBuildingsInk.reed) {
        typealias I = BronzeBuildingsInk
        guard points.count > 1 else { return }
        svg.line(points, stroke: .colour(I.line), width: width + 1.2)
        svg.line(points, stroke: .colour(paint), width: width)
        // The streaks of the reeds, either side of the middle.
        for k in [-0.26, 0.24] where width > 2.6 {
            svg.line(Self.offset(points, by: width * k), stroke: .colour(I.reedShade), width: 0.5)
        }
        for t in binds {
            let (at, along) = Self.point(points, at: t)
            let across = P(-along.y, along.x) * (width / 2 + 0.3)
            svg.line([at - across, at + across], stroke: .colour(I.line), width: 2.4)
            svg.line([at - across * 0.92, at + across * 0.92], stroke: team ? .team : .colour(I.terracotta), width: 1.3)
        }
    }

    /// A line on the screen moved `by` points to its left as it runs.
    private static func offset(_ points: [P], by k: Double) -> [P] {
        points.indices.map { i in
            let a = points[max(i - 1, 0)], b = points[min(i + 1, points.count - 1)]
            let u = (b - a) * (1 / max(((b - a).x * (b - a).x + (b - a).y * (b - a).y).squareRoot(), 1e-6))
            return points[i] + P(-u.y, u.x) * k
        }
    }

    /// The point a fraction `t` of the way along a line on the screen, and the line's direction there.
    private static func point(_ points: [P], at t: Double) -> (P, P) {
        var lengths: [Double] = []
        for (a, b) in zip(points, points.dropFirst()) { lengths.append(((b - a).x * (b - a).x + (b - a).y * (b - a).y).squareRoot()) }
        var left = lengths.reduce(0, +) * min(max(t, 0), 1)
        for (i, length) in lengths.enumerated() {
            if left <= length || i == lengths.count - 1 {
                let a = points[i], b = points[i + 1]
                let u = (b - a) * (1 / max(length, 1e-6))
                return (a + (b - a) * min(left / max(length, 1e-6), 1), u)
            }
            left -= length
        }
        return (points[0], P(1, 0))
    }

    /// A point of the vault's arch at `x` along the shed: `s` from 0 at its foot
    /// on the far side (toward -y in the side view), over the crown at 0.5, to
    /// 1 at its foot on the near side.
    private func archPoint(_ x: Double, _ s: Double, crown: Double = ReedShed.crown, out: Double = 0, turn: ShedTurn = .side) -> P {
        let a = s * .pi
        let half = (ReedShed.y1 - ReedShed.y0) / 2 + out / 36
        // The marsh arch: fuller at the shoulders than a half circle, a little pointed at the crown.
        let rise = pow(sin(a), 0.62)
        return shed(x, ReedShed.yc - half * cos(a), ReedShed.quay + (crown + out) * rise, turn)
    }

    private func arch(_ x: Double, from s0: Double = 0, to s1: Double = 1, crown: Double = ReedShed.crown, out: Double = 0,
                      turn: ShedTurn = .side) -> [P] {
        (0...24).map { i in archPoint(x, s0 + (s1 - s0) * Double(i) / 24, crown: crown, out: out, turn: turn) }
    }

    /// A tall column of bundled reed standing on the quay at (x, y) in the
    /// shed's frame, `height` points tall, bound at intervals, its head a tuft.
    private mutating func reedColumn(_ x: Double, _ y: Double, height: Double, tuft: Bool = true, turn: ShedTurn = .side) {
        typealias I = BronzeBuildingsInk
        let foot = shed(x, y, ReedShed.quay, turn), top = foot - P(0, height)
        shadow([foot + P(1, 0.5), foot + P(9, -2.5), foot + P(10, 0.5), foot + P(2, 2.2)], opacity: 0.16)
        if tuft {
            // The reeds' heads, spread above the last binding.
            var d = PathData()
            for k in -3...3 {
                let a = Double(k) * 11
                d.move(top + P(0, 2)); d.line(top + P.direction(180 + a) * 7.5 + P(0, 2))
            }
            svg.path(d, stroke: .colour(I.line), width: 2.4)
            svg.path(d, stroke: .colour(I.reedShade), width: 1.2)
        }
        reedBundle([foot, top], width: 6.4, binds: [0.18, 0.42, 0.66, 0.9], team: true, colour: ReedShed.reedLit)
    }

    // MARK: The complete shed

    private mutating func reedShed() {
        typealias I = BronzeBuildingsInk
        let (x0, x1, y0, y1, q) = (ReedShed.x0, ReedShed.x1, ReedShed.y0, ReedShed.y1, ReedShed.quay)
        // The vault's shadow on the quay, to the right.
        shadow([iso(x0 + 0.2, y0, q), iso(x1 + 0.3, y0, q), iso(x1 + 0.3, y1 + 0.06, q), iso(x0 + 0.2, y1 + 0.06, q)], opacity: 0.12)
        // Jars by the far side.
        jar(at: iso(0.55, -0.84, q), size: 1.1)
        jar(at: iso(0.74, -0.8, q), size: 0.8, paint: I.clay)
        // The vault: the matting between the far arch and the open end.
        vault()
        // The open end: the shed's dark inside, the arches seen through it, and the boat on its chocks.
        let opening = arch(x1)
        colour(opening, .colour(ReedShed.inside))
        svg.raw("<defs><clipPath id=\"bronze-boat-house-inside\"><polygon points=\"\(opening.map { "\(num($0.x)),\(num($0.y))" }.joined(separator: " "))\"/></clipPath></defs>")
        svg.raw("<g clip-path=\"url(#bronze-boat-house-inside)\">")
        for (k, x) in [x1 - 0.3, x1 - 0.62, x1 - 0.94].enumerated() {
            svg.line(arch(x), stroke: .colour(I.reedShade), width: 2.6 - Double(k) * 0.5, opacity: 0.55 - Double(k) * 0.12)
        }
        colour([iso(x0, y0, q), iso(x1, y0, q), iso(x1, y1, q), iso(x0, y1, q)], .colour(I.dark), opacity: 0.5)
        shedBoat(from: -0.5, to: x1 + 0.3, y: ReedShed.yc, h: q, within: -1...x1)
        svg.raw("</g>")
        // The arch round the open end, the boat's bow out under it, and the columns either side.
        reedBundle(arch(x1, out: 1.2), width: 4.6, binds: [0.1, 0.3, 0.5, 0.7, 0.9])
        shedBoat(from: -0.5, to: x1 + 0.3, y: ReedShed.yc, h: q, within: x1...1)
        reedColumn(x1 + 0.03, y0 - 0.05, height: ReedShed.crown + 9)
        pennant(at: archPoint(x1, 0.5, out: 3), height: 16)
        reedColumn(x1 + 0.03, y1 + 0.05, height: ReedShed.crown + 9)
        // Before the open end: the mooring post, and reed bundles stacked at the front.
        mooringPost(at: iso(0.86, ReedShed.yc + 0.1, q))
        reedStack(at: (-0.1, 0.72))
        // The net drying on its poles at the front corner.
        dryingNet(from: (-0.93, 0.36), to: (-0.93, 0.92))
    }

    /// The vault's matting: its shape between the arch at the far end and the
    /// one at the open end, its courses running along it, its ribs over the
    /// arches, and the line round it. Its slope toward `across` + (toward +y
    /// in the side view) faces the viewer: in the sun in the side view, and in
    /// the shade in the back view, where it faces +x and the crown's far
    /// slope, toward -x, takes the sun.
    private mutating func vault(turn: ShedTurn = .side) {
        typealias I = BronzeBuildingsInk
        let (x0, x1) = (ReedShed.x0, ReedShed.x1)
        // The vault seen whole: the outline about both end arches (the open end is drawn over it after).
        let band = StoneDugout.outline(arch(x0, turn: turn) + arch(x1, turn: turn))
        colour(band, .colour(turn == .side ? I.reed : ReedShed.reedLit))
        // The near slope.
        let near = arch(x0, from: 0.62, to: 1, turn: turn) + arch(x1, from: 0.62, to: 1, turn: turn).reversed()
        colour(near, .colour(turn == .side ? ReedShed.reedLit : I.reed))
        if turn == .back {
            // The shoulder between the sun and the shade.
            let shoulder = arch(x0, from: 0.5, to: 0.62, turn: turn) + arch(x1, from: 0.5, to: 0.62, turn: turn).reversed()
            colour(shoulder, .colour(I.reed), opacity: 0.5)
        }
        // The courses of the matting along the vault, the lower ones closer as the slope turns toward the viewer.
        var d = PathData()
        for s in stride(from: 0.5, through: 0.97, by: 0.06) {
            d.move(archPoint(x0 + 0.02, s, turn: turn)); d.line(archPoint(x1 - 0.02, s, turn: turn))
        }
        svg.path(d, stroke: .colour(I.reedShade), width: 0.6)
        // The ribs of the arches under the matting, each a ridge with its binding.
        let ribs = 5
        for k in 1..<ribs {
            let x = x0 + (x1 - x0) * Double(k) / Double(ribs)
            let rib = arch(x, from: 0.5, to: 1, out: 0.5, turn: turn)
            svg.line(rib, stroke: .colour(I.reedShade), width: 2.2)
            svg.line(rib, stroke: .colour(I.line), width: 0.7)
        }
        line(band, closed: true, width: 1.1)
        // The matting's ragged foot along the near side.
        var fringe = PathData()
        for k in 0...18 {
            let p = shed(x0 + (x1 - x0) * Double(k) / 18, ReedShed.y1, ReedShed.quay + 0.6, turn)
            fringe.move(p); fringe.line(p + P(k % 2 == 0 ? -0.3 : 0.3, k % 3 == 0 ? 2 : 1.3))
        }
        svg.path(fringe, stroke: .colour(I.line), width: 0.6)
    }

    /// The reed boat resting on two chocks along x at `y`, from `x0` to `x1`
    /// tiles, on `h`: a bundle thickest in its middle, its bow curled up at `x1`
    /// and its stern raised at `x0`, bound along its length. Only what lies
    /// between `within` along x is drawn, so that the part inside the shed can
    /// be drawn through its open end and the part outside over the arch.
    private mutating func shedBoat(from x0: Double, to x1: Double, y: Double, h: Double, within: ClosedRange<Double>,
                                  turn: ShedTurn = .side) {
        typealias I = BronzeBuildingsInk
        for x in [x0 + 0.25, x1 - 0.32] where within.contains(x) {
            let (a, b) = turn.map(x - 0.04, y - 0.12), (c, e) = turn.map(x + 0.04, y + 0.12)
            block(min(a, c), min(b, e), max(a, c), max(b, e), h, h + 2.4, top: .colour(I.timberLight), left: .colour(I.timber),
                  right: .colour(I.timberDark), width: 0.7)
        }
        // The hull: thick stretches along it, each a little thinner toward the ends.
        let steps = 16
        func x(_ t: Double) -> Double { x0 + (x1 - x0) * t }
        func lift(_ t: Double) -> Double { 4.4 + 4 * pow(abs(2 * t - 1), 2.4) }
        func thickness(_ t: Double) -> Double { 2.8 + 3.4 * pow(sin(t * .pi), 0.7) }
        let ts = (0...steps).map { Double($0) / Double(steps) }
        let line = ts.map { shed(x($0), y, h + lift($0), turn) }
        let drawn = (0..<steps).filter { within.contains(x((ts[$0] + ts[$0 + 1]) / 2)) }
        guard let first = drawn.first, let last = drawn.last else { return }
        for paint in [I.line, I.reed] {
            for i in drawn {
                let w = thickness((ts[i] + ts[i + 1]) / 2)
                svg.line([line[i], line[i + 1]], stroke: .colour(paint), width: paint == I.line ? w + 1.2 : w)
            }
        }
        let part = Array(line[first...(last + 1)])
        svg.line(Self.offset(part, by: -1.1), stroke: .colour(I.reedShade), width: 0.5)
        svg.line(Self.offset(part, by: 1), stroke: .colour(ReedShed.reedLit), width: 0.8)
        for t in [0.2, 0.35, 0.5, 0.65, 0.8] where within.contains(x(t)) {
            let (at, along) = Self.point(line, at: t)
            let across = P(-along.y, along.x) * (thickness(t) / 2 + 0.3)
            svg.line([at - across, at + across], stroke: .colour(I.line), width: 2.2)
            svg.line([at - across * 0.9, at + across * 0.9], stroke: .colour(I.terracotta), width: 1.1)
        }
        // The bow, curling up and over, and the stern post.
        if within.contains(x1) {
            let foot = line.last!
            // The curl is drawn for a hull running toward the lower right; one running toward the upper right leans it back.
            let lean = turn == .side ? 0.0 : -0.35
            let bow = [P(0, 0), P(3, -3), P(4.4, -7.5), P(3.6, -11), P(1.4, -12.6), P(0.2, -11.4)].map { foot + P($0.x, $0.y + lean * $0.x) }
            reedBundle(bow, width: 2.8, binds: [0.15, 0.4])
        }
        if within.contains(x0) {
            let foot = line.first!
            reedBundle([foot, foot + P(-2.6, -3), foot + P(-3.4, -8)], width: 2.8, binds: [0.3])
        }
    }

    /// The mooring post: a timber post with a bronze ring at its head and a rope made fast to it.
    private mutating func mooringPost(at foot: P, turn: ShedTurn = .side) {
        typealias I = BronzeBuildingsInk
        pole(foot + P(0, 1), foot - P(0, 15), width: 2.8, colour: I.timber)
        svg.ellipse(foot - P(0, 15), 1.4, 0.7, fill: .colour(I.timberLight), stroke: .colour(I.line), width: 0.6)
        svg.ellipse(foot - P(-1.8, 11.5), 2.2, 2.4, fill: .none, stroke: .colour(I.line), width: 1.8)
        svg.ellipse(foot - P(-1.8, 11.5), 2.2, 2.4, fill: .none, stroke: .colour(I.bronzeLight), width: 0.9)
        var rope = PathData()
        // The rope falls toward the water: the lower right in the side view, the upper right in the back view.
        if turn == .side {
            rope.move(foot - P(0, 6)); rope.quad(foot + P(5, -1), foot + P(9, 3))
        } else {
            rope.move(foot - P(0, 6)); rope.quad(foot + P(5, -6.5), foot + P(10, -3.5))
        }
        svg.path(rope, stroke: .colour(I.line), width: 1.7)
        svg.path(rope, stroke: .colour(I.reedShade), width: 0.8)
    }

    /// A net hung to dry between two poles at (x, y) on the quay: its mesh sagging between them, weights along its foot.
    private mutating func dryingNet(from a: (Double, Double), to b: (Double, Double)) {
        typealias I = BronzeBuildingsInk
        let q = ReedShed.quay, top = 20.0
        let pa = iso(a.0, a.1, q), pb = iso(b.0, b.1, q)
        pole(pa + P(0, 0.5), pa - P(0, top + 2), width: 1.6, colour: I.timber)
        let ta = pa - P(0, top), tb = pb - P(0, top)
        let sag = P(0, 3)
        // The mesh: lines from the bar down to the foot, and across.
        var mesh = PathData()
        for k in 0...8 {
            let t = Double(k) / 8
            let upper = ta + (tb - ta) * t + sag * (4 * t * (1 - t))
            mesh.move(upper); mesh.line(upper + P(0.6, 12))
        }
        for row in [4.0, 8.0, 12.0] {
            for k in 0..<8 {
                let t = Double(k) / 8, u = Double(k + 1) / 8
                let a1 = ta + (tb - ta) * t + sag * (4 * t * (1 - t)) + P(0.2 * row / 4, row)
                let b1 = ta + (tb - ta) * u + sag * (4 * u * (1 - u)) + P(0.2 * row / 4, row)
                mesh.move(a1); mesh.line(b1)
            }
        }
        svg.path(mesh, stroke: .colour(I.line), width: 0.5, opacity: 0.85)
        var bar = PathData()
        bar.move(ta); bar.quad((ta + tb) * 0.5 + sag * 2, tb)
        svg.path(bar, stroke: .colour(I.line), width: 1.2)
        for k in 0...8 {
            let t = Double(k) / 8
            svg.circle(ta + (tb - ta) * t + sag * (4 * t * (1 - t)) + P(0.6, 12.4), 0.8, fill: .colour(I.stone), stroke: .colour(I.line), width: 0.4)
        }
        pole(pb + P(0, 0.5), pb - P(0, top + 2), width: 1.6, colour: I.timber)
    }

    /// Bundles of cut reed stacked on the quay at (x, y), lying along y: three below and two on them.
    private mutating func reedStack(at c: (Double, Double)) {
        let q = ReedShed.quay
        let rows: [[(Double, Double)]] = [[(-0.1, 0), (0, 0), (0.1, 0)], [(-0.05, 3.6), (0.05, 3.6)]]
        shadow([iso(c.0 - 0.18, c.1 - 0.2, q), iso(c.0 + 0.2, c.1 - 0.2, q), iso(c.0 + 0.2, c.1 + 0.24, q), iso(c.0 - 0.18, c.1 + 0.24, q)],
               opacity: 0.12)
        for row in rows {
            for (dx, dh) in row {
                let a = iso(c.0 + dx, c.1 - 0.17, q + 2 + dh), b = iso(c.0 + dx, c.1 + 0.17, q + 2 + dh)
                reedBundle([a, b], width: 4, binds: [0.25, 0.75])
                // The cut ends toward the viewer.
                svg.ellipse(b, 2, 1.8, fill: .colour(ReedShed.reedLit), stroke: .colour(BronzeBuildingsInk.line), width: 0.7)
            }
        }
    }

    // MARK: The complete shed from behind

    /// The shed in the back view, drawn from the far end forward: the open end
    /// and what stands before it (the far column, the mooring post, the boat's
    /// bow, the arch round the opening), the vault, the pennant and the near
    /// column, then the landward end facing the viewer and the stores before it.
    private mutating func reedShedFromBehind() {
        typealias I = BronzeBuildingsInk
        let turn = ShedTurn.back
        let (x0, x1, y0, y1, q) = (ReedShed.x0, ReedShed.x1, ReedShed.y0, ReedShed.y1, ReedShed.quay)
        // The vault's shadow on the quay, to the right.
        shadow(level(y0 + 0.12, -x1 - 0.14, y1 + 0.3, -x0 - 0.1, q), opacity: 0.12)
        // At the open end, beyond the vault: the far column, the mooring post, and the boat's bow under the arch. The
        // post stands a little to the right of where the side view has it, so that the near column does not hide it.
        reedColumn(x1 + 0.03, y0 - 0.05, height: ReedShed.crown + 9, turn: turn)
        mooringPost(at: shed(0.86, ReedShed.y1 + 0.2, q, turn), turn: turn)
        shedBoat(from: -0.5, to: x1 + 0.3, y: ReedShed.yc, h: q, within: x1...1, turn: turn)
        reedBundle(arch(x1, out: 1.2, turn: turn), width: 4.6, binds: [0.1, 0.3, 0.5, 0.7, 0.9])
        vault(turn: turn)
        pennant(at: archPoint(x1, 0.5, out: 3, turn: turn), height: 16)
        reedColumn(x1 + 0.03, y1 + 0.05, height: ReedShed.crown + 9, turn: turn)
        landwardEnd()
        // The stores by the door: jars at the near corner, the reed stacked along the flank, and the net drying at its edge.
        jar(at: iso(-0.88, 0.62, q), size: 0.8, paint: I.clay)
        jar(at: iso(-0.84, 0.86, q), size: 1.1)
        dryingNet(from: (0.93, -0.1), to: (0.93, 0.46))
        reedStack(at: (0.6, 0.62))
    }

    /// The shed's landward end, facing +y in the back view: a screen of reed
    /// lattice filling the end arch, lit by the sun, with an arched doorway in
    /// its middle framed by two bundled posts bound in the owner's colour, a
    /// grille either side of it, and the end arch's bundle round it all.
    private mutating func landwardEnd() {
        typealias I = BronzeBuildingsInk
        let turn = ShedTurn.back
        let (x0, y0, y1, yc, q, crown) = (ReedShed.x0, ReedShed.y0, ReedShed.y1, ReedShed.yc, ReedShed.quay, ReedShed.crown)
        let half = (y1 - y0) / 2
        /// A point of the screen: `b` across the shed, `v` points above the quay.
        func at(_ b: Double, _ v: Double) -> P { shed(x0, b, q + v, turn) }
        /// How high the end arch stands at `b` across the shed.
        func archHeight(_ b: Double) -> Double {
            let c = min(max((yc - b) / half, -1), 1)
            return crown * pow(max(1 - c * c, 0).squareRoot(), 0.62)
        }
        /// How far across the shed the end arch reaches either side of its middle at the height `v`.
        func archHalf(_ v: Double) -> Double {
            let sine = pow(min(max(v / crown, 0), 1), 1 / 0.62)
            return half * max(1 - sine * sine, 0).squareRoot()
        }
        let end = arch(x0, turn: turn)
        colour(end, .colour(ReedShed.reedLit))
        // The lattice: upright bundles, and courses tied across them.
        var d = PathData()
        for k in 1..<8 {
            let b = y0 + (y1 - y0) * Double(k) / 8
            d.move(at(b, 0)); d.line(at(b, archHeight(b) - 0.6))
        }
        for v in stride(from: 5.0, through: crown - 3, by: 5) {
            let w = archHalf(v) - 0.01
            d.move(at(yc - w, v)); d.line(at(yc + w, v))
        }
        svg.path(d, stroke: .colour(I.reed), width: 1.4)
        svg.path(d, stroke: .colour(I.reedShade), width: 0.5)
        // A grille either side of the door, dark between its bars.
        for b in [yc - 0.3, yc + 0.3] {
            let grille = [at(b - 0.07, 10), at(b + 0.07, 10), at(b + 0.07, 18), at(b - 0.07, 18)]
            colour(grille, .colour(ReedShed.inside))
            var bars = PathData()
            for t in [0.25, 0.5, 0.75] {
                bars.move(at(b - 0.07 + 0.14 * t, 10)); bars.line(at(b - 0.07 + 0.14 * t, 18))
            }
            bars.move(at(b - 0.07, 14)); bars.line(at(b + 0.07, 14))
            svg.path(bars, stroke: .colour(I.reedShade), width: 1)
            line(grille, closed: true, width: 0.8)
        }
        // The doorway, dark within, its head a pointed arch of bundled reed.
        let door = 0.12, doorHeight = 17.0
        let head = (0...12).map { i -> P in
            let t = Double(i) / 12, a = t * .pi
            return at(yc - door * cos(a), doorHeight - 5 + 5 * pow(sin(a), 0.7))
        }
        let opening = [at(yc - door, 0)] + head + [at(yc + door, 0)]
        colour(opening, .colour(ReedShed.inside))
        // The inside's floor and a glimpse of the boat's stern within.
        colour([at(yc - door, 0), at(yc + door, 0), at(yc + door, 2), at(yc - door, 2)], .colour(I.dark), opacity: 0.6)
        line(opening, closed: true, width: 0.9)
        // The door posts and the head over them, bound in the owner's colour.
        for b in [yc - door - 0.03, yc + door + 0.03] {
            reedBundle([at(b, 0), at(b, doorHeight - 4)], width: 3.4, binds: [0.25, 0.75], team: true, colour: ReedShed.reedLit)
        }
        let lintel = (0...12).map { i -> P in
            let t = Double(i) / 12, a = t * .pi
            return at(yc - (door + 0.03) * cos(a), doorHeight - 4 + 6.4 * pow(sin(a), 0.7))
        }
        reedBundle(lintel, width: 3, binds: [0.5], team: true, colour: ReedShed.reedLit)
        // The end arch's bundle round the screen.
        reedBundle(arch(x0, out: 0.8, turn: turn), width: 4.2, binds: [0.1, 0.3, 0.5, 0.7, 0.9])
        // The screen's foot on the quay.
        line([at(y0, 0), at(y1, 0)], width: 1)
    }

    // MARK: Under construction

    /// The shed being built: the arches planted and tied at their crowns, one
    /// mat laid over the far end, the columns half raised, and reed to hand.
    private mutating func reedShedRising() {
        typealias I = BronzeBuildingsInk
        let (x0, x1) = (ReedShed.x0, ReedShed.x1)
        let q = ReedShed.quay - 1.5
        let ribs = 4
        let xs = (0...ribs).map { x0 + (x1 - x0) * Double($0) / Double(ribs) }
        // The arches, the farthest first, each tied at its crown.
        for (k, x) in xs.enumerated() {
            let rib = arch(x).map { $0 + P(0, 1.5) }
            reedBundle(rib, width: 3.6, binds: [0.2, 0.5, 0.8])
            if k == 0 {
                // The first mat, laid over the far arches.
                let mat = arch(xs[0]).map { $0 + P(0, 1.5) } + arch(xs[1]).map { $0 + P(0, 1.5) }.reversed()
                colour(mat, .colour(I.reed))
                var d = PathData()
                for s in stride(from: 0.5, through: 0.97, by: 0.08) {
                    d.move(archPoint(xs[0], s) + P(0, 1.5)); d.line(archPoint(xs[1], s) + P(0, 1.5))
                }
                svg.path(d, stroke: .colour(I.reedShade), width: 0.6)
                line(mat, closed: true, width: 1)
            }
        }
        // The ridge pole tying the crowns together.
        pole(archPoint(x0, 0.5) + P(0, 1.5), archPoint(x1, 0.5) + P(0, 1.5), width: 1.6, colour: I.timber)
        pennant(at: archPoint(x1, 0.5, out: 2) + P(0, 1.5), height: 14)
        // The columns, half raised, and the reed waiting for them.
        for y in [ReedShed.y0 - 0.05, ReedShed.y1 + 0.05] {
            let foot = iso(x1 + 0.03, y, q), top = foot - P(0, 16)
            reedBundle([foot, top], width: 6.4, binds: [0.3, 0.75], team: true, colour: ReedShed.reedLit)
            svg.ellipse(top, 3.2, 1.6, fill: .colour(I.reedShade), stroke: .colour(I.line), width: 0.7)
        }
        reedStackRising(at: (0.66, 0.6), h: q)
        reedStackRising(at: (-0.5, 0.74), h: q)
        bricks(0.55, -0.9, 0.85, -0.7, from: q, courses: 2)
        basket(at: iso(0.75, -0.25, q), size: 1)
    }

    /// Loose bundles of reed lying on the bare quay, ready to be bound into the shed.
    private mutating func reedStackRising(at c: (Double, Double), h: Double) {
        for (dy, dh) in [(-0.1, 0.0), (0.05, 0.0), (-0.03, 3.4)] {
            let a = iso(c.0 - 0.2, c.1 + dy, h + 2 + dh), b = iso(c.0 + 0.2, c.1 + dy, h + 2 + dh)
            reedBundle([a, b], width: 4, binds: [0.3, 0.7])
            svg.ellipse(b, 1.8, 2, fill: .colour(ReedShed.reedLit), stroke: .colour(BronzeBuildingsInk.line), width: 0.7)
        }
    }

    // MARK: Under construction, from behind

    /// The shed being built, in the back view: the columns half raised at the
    /// open end beyond, the arches from the far one forward, the first mat over
    /// the landward arches, the ridge pole, the posts of the doorway planted,
    /// and reed and brick to hand about the landward end.
    private mutating func reedShedRisingFromBehind() {
        typealias I = BronzeBuildingsInk
        let turn = ShedTurn.back
        let (x0, x1) = (ReedShed.x0, ReedShed.x1)
        let q = ReedShed.quay - 1.5
        let ribs = 4
        let xs = (0...ribs).map { x0 + (x1 - x0) * Double($0) / Double(ribs) }
        // The columns, half raised, beyond the arches.
        for y in [ReedShed.y0 - 0.05, ReedShed.y1 + 0.05] {
            let foot = shed(x1 + 0.03, y, q, turn), top = foot - P(0, 16)
            reedBundle([foot, top], width: 6.4, binds: [0.3, 0.75], team: true, colour: ReedShed.reedLit)
            svg.ellipse(top, 3.2, 1.6, fill: .colour(I.reedShade), stroke: .colour(I.line), width: 0.7)
        }
        bricks(-0.9, -0.85, -0.7, -0.55, from: q, courses: 2)
        basket(at: iso(-0.25, -0.75, q), size: 1)
        // The arches, the farthest first, each tied at its crown; the first mat is laid over the two nearest.
        func rib(_ x: Double) -> [P] { arch(x, turn: turn).map { $0 + P(0, 1.5) } }
        for x in xs.dropFirst().reversed() {
            reedBundle(rib(x), width: 3.6, binds: [0.2, 0.5, 0.8])
        }
        let mat = rib(xs[0]) + rib(xs[1]).reversed()
        colour(mat, .colour(I.reed))
        var d = PathData()
        for s in stride(from: 0.5, through: 0.97, by: 0.08) {
            d.move(archPoint(xs[0], s, turn: turn) + P(0, 1.5)); d.line(archPoint(xs[1], s, turn: turn) + P(0, 1.5))
        }
        svg.path(d, stroke: .colour(I.reedShade), width: 0.6)
        line(mat, closed: true, width: 1)
        reedBundle(rib(xs[0]), width: 3.6, binds: [0.2, 0.5, 0.8])
        // The ridge pole tying the crowns together.
        pole(archPoint(x0, 0.5, turn: turn) + P(0, 1.5), archPoint(x1, 0.5, turn: turn) + P(0, 1.5), width: 1.6, colour: I.timber)
        pennant(at: archPoint(x1, 0.5, out: 2, turn: turn) + P(0, 1.5), height: 14)
        // The doorway's posts, planted in the landward end and bound in the owner's colour.
        for b in [ReedShed.yc - 0.15, ReedShed.yc + 0.15] {
            let foot = shed(x0, b, q, turn)
            reedBundle([foot, foot - P(0, 13)], width: 3.4, binds: [0.3, 0.75], team: true, colour: ReedShed.reedLit)
        }
        reedStackRising(at: (0.6, -0.4), h: q)
        reedStackRising(at: (0.56, 0.5), h: q)
    }
}
