// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore

// The resource sites and the outcrop, each standing on the centre of its tile.
// Units are points, with the origin on the ground at the tile's centre and y
// running downward, as SVG has it; the tile's diamond reaches 32 points to
// either side and 16 before and behind. Each colour field lies a little out of
// register with the line drawn over it, as the style has it.

extension TerrainSprites {
    /// A rock, an animal or the outcrop: the tile's diamond, with room above it.
    static let siteCanvas = Canvas(minX: -36, minY: -60, width: 72, height: 80, pixelsPerUnit: 2)
    /// A tree: taller.
    static let treeCanvas = Canvas(minX: -36, minY: -104, width: 72, height: 124, pixelsPerUnit: 2)

    /// A site in SVG. Iron and oil fields belong to later batches, and the
    /// fish to the boats' (`StoneBoatSprites`). Without `shadow`, a rock is
    /// drawn without its shadow on the ground, to rise from the water.
    static func drawSite(_ kind: SiteKind, _ svg: inout SVG, shadow: Bool = true) {
        switch kind {
        case .tree: drawTree(&svg)
        case .prey: drawDeer(&svg)
        case .stone: drawStone(&svg, shadow: shadow)
        case .copper: drawCopper(&svg, shadow: shadow)
        case .tin: drawTin(&svg, shadow: shadow)
        case .gold: drawGold(&svg, shadow: shadow)
        case .iron, .oilField, .fish: break
        }
    }

    /// How far each colour field lies out of register with its line.
    private static let register = P(-0.8, 0.6)
    private static let line = Paint.colour(TerrainInk.line)

    /// The soft shadow on the ground under a site.
    private static func groundShadow(_ svg: inout SVG, at c: P, rx: Double, ry: Double) {
        svg.ellipse(c, rx, ry, fill: .colour("#000000"), opacity: 0.16)
    }

    // MARK: The tree

    /// A fir in the manner of the period: three tiers of boughs, each a tall
    /// triangle with a zigzag hem, lit on the left and shaded on the right, on
    /// a short trunk.
    private static func drawTree(_ svg: inout SVG) {
        groundShadow(&svg, at: P(2, 1.5), rx: 17, ry: 5.5)
        let trunk = [P(-2.7, 1.4), P(-1.9, -14), P(1.9, -14), P(2.7, 1.4)]
        svg.polygon(trunk.map { $0 + register }, fill: .colour(TerrainInk.bark))
        svg.polygon(trunk, fill: .none, stroke: line, width: 1.2)
        svg.line([P(-2.7, 1.4), P(-4.8, 2.4)], stroke: line, width: 1)
        svg.line([P(2.7, 1.4), P(4.6, 2.2)], stroke: line, width: 1)
        tier(&svg, top: -60, bottom: -10, half: 21, teeth: 6)
        tier(&svg, top: -79, bottom: -37, half: 16, teeth: 5)
        tier(&svg, top: -97, bottom: -60, half: 11, teeth: 4)
    }

    /// One tier of a fir's boughs, its sides bowed in and its hem zigzagged.
    private static func tier(_ svg: inout SVG, top: Double, bottom: Double, half: Double, teeth: Int) {
        let mid = (top + bottom) / 2, notch = 3.4
        /// The hem's points from the right corner toward the left, as far as `stop`.
        func hem(to stop: Double) -> [P] {
            var points: [P] = []
            let n = teeth * 2
            for i in 1...n {
                let x = half - 2 * half * Double(i) / Double(n)
                if x < stop - 0.01 { break }
                points.append(P(x, i % 2 == 1 ? bottom - notch : bottom))
            }
            return points
        }
        func outline(_ shift: P) -> PathData {
            var d = PathData()
            d.move(P(0, top) + shift)
            d.quad(P(half * 0.32, mid) + shift, P(half, bottom) + shift)
            for p in hem(to: -half) { d.line(p + shift) }
            d.quad(P(-half * 0.32, mid) + shift, P(0, top) + shift)
            d.close()
            return d
        }
        svg.path(outline(register), fill: .colour(TerrainInk.needlesLit))
        // The shaded half: from the apex down the right side and along the hem to the middle.
        var shade = PathData()
        shade.move(P(0, top) + register)
        shade.quad(P(half * 0.32, mid) + register, P(half, bottom) + register)
        for p in hem(to: 0) { shade.line(p + register) }
        shade.close()
        svg.path(shade, fill: .colour(TerrainInk.needlesShade))
        // Boughs: small chevrons in a row above the hem.
        let row = bottom - (bottom - top) * 0.3
        let across = half * 0.42
        for x in [-across, across] {
            let colour = x < 0 ? TerrainInk.needlesShade : TerrainInk.needlesLit
            svg.path("M\(num(x - 2.2)),\(num(row - 1.6)) L\(num(x)),\(num(row + 0.6)) L\(num(x + 2.2)),\(num(row - 1.6))",
                     stroke: .colour(colour), width: 0.9)
        }
        svg.path(outline(P(0, 0)), stroke: line, width: 1.2)
    }

    // MARK: Prey

    /// A deer standing, facing right: a rounded body dappled with pale spots,
    /// stick legs, a white rump and tail, and branched antlers, after the goats
    /// of the reference scene.
    private static func drawDeer(_ svg: inout SVG) {
        groundShadow(&svg, at: P(0, 0.6), rx: 16, ry: 3.8)
        svg.group(at: P(-3, 0)) { svg in
            // Legs: the far pair, then the near pair, each a single line with a hoof.
            let legs: [[P]] = [
                [P(-9.6, -14), P(-11.6, -7.2), P(-10.6, -0.4)],
                [P(8.4, -14), P(8.8, -7), P(8.4, -0.4)],
                [P(-12.4, -14), P(-14.8, -7.4), P(-13.6, -0.2)],
                [P(10.6, -14), P(11.2, -7), P(11.7, -0.2)],
            ]
            for (i, leg) in legs.enumerated() {
                svg.line(leg, stroke: line, width: i < 2 ? 1.05 : 1.2)
                svg.line([leg[2], leg[2] + P(1.4, 0)], stroke: line, width: 1.5)
            }
            // The far antler, behind the head.
            svg.path("M16.2,-35.6 Q17.2,-42 20.6,-47 M17.4,-40.4 Q19.8,-41 21.8,-42.4", stroke: line, width: 1)
            // The neck and the body.
            let neck = "M5.5,-23 L11.4,-32.6 L16.2,-30.4 L12.6,-20 Z"
            let body = "M-10,-24.2 L7,-24.6 Q12.6,-24.6 12.6,-19.2 Q12.2,-13 6,-13 Q-2,-12.2 -10,-13 "
                + "Q-15.2,-13.4 -15.2,-18.6 Q-15.2,-24.2 -10,-24.2 Z"
            svg.group(at: register) { svg in
                svg.path(neck, fill: .colour(TerrainInk.deerHide))
                svg.path(body, fill: .colour(TerrainInk.deerHide))
                // The pale rump.
                svg.ellipse(P(-12.4, -19.6), 2.4, 4, fill: .colour(TerrainInk.deerSpot))
            }
            // Dapples along the back.
            for (x, y) in [(-8.2, -21.4), (-4.4, -22), (-0.6, -21.4), (3.2, -22), (-6.4, -18.4), (-2.4, -18.6), (1.4, -18.2)] {
                svg.ellipse(P(x, y), 1.15, 0.8, fill: .colour(TerrainInk.deerSpot))
            }
            svg.path(body, stroke: line, width: 1.2)
            svg.path("M5.5,-23 L11.4,-32.6 M16.2,-30.4 L12.6,-20", stroke: line, width: 1.2)
            // The tail, raised.
            let tail = "M-14.6,-22.6 Q-18.2,-25.6 -19.2,-23.4 Q-17.6,-20.8 -14.8,-20.4 Z"
            svg.path(tail, fill: .colour(TerrainInk.deerSpot), stroke: line, width: 1)
            // The ear, behind the head.
            svg.path("M12.6,-34.4 Q8,-38.6 6.4,-37 Q8.4,-33.4 12,-32.6 Z", fill: .colour(TerrainInk.deerHide), stroke: line, width: 1)
            // The head: a wedge with a dark nose, an eye and a mouth.
            let head = "M11,-34 Q14,-37.2 18,-35.6 L23.6,-30.4 Q24.4,-28.2 22,-27.8 L16,-28 Q12,-28.8 11,-34 Z"
            svg.group(at: register) { svg in svg.path(head, fill: .colour(TerrainInk.deerHide)) }
            svg.path(head, stroke: line, width: 1.2)
            svg.circle(P(23.1, -29.2), 0.95, fill: line)
            svg.path("M19.6,-28.4 q1.4,0.5 2.6,0.1", stroke: line, width: 0.7)
            svg.ellipse(P(16.6, -32.3), 1.45, 1.3, fill: .colour(Ink.eyeWhite), stroke: line, width: 0.6)
            svg.circle(P(17.1, -32.2), 0.7, fill: line)
            // The near antler: a beam curving back, with three tines.
            svg.path("M14.2,-36 Q12,-43 8.6,-49 M12.9,-40.4 Q15.6,-41.6 16.8,-44.6 M11.2,-44.2 Q13.2,-46 13.6,-49.2 "
                     + "M13.8,-37.8 Q16,-38.2 17,-39.6", stroke: line, width: 1.15)
        }
    }

    // MARK: Rocks

    /// A rock's faces and the lines over them.
    private struct TerrainRock {
        var outline: [P]
        var top: [P] = []
        var shade: [P] = []
        var edges: [[P]] = []
    }

    /// The colours of a rock's three faces: the top, catching the light; the
    /// face lit from the left; and the face in shade.
    private struct TerrainFaces {
        var top: String
        var lit: String
        var shade: String
    }

    /// A rock: its faces' colours, the line over them, then whatever lies on its faces.
    private static func rock(_ svg: inout SVG, _ rock: TerrainRock, _ faces: TerrainFaces,
                             ore: (inout SVG) -> Void = { _ in }) {
        svg.polygon(rock.outline.map { $0 + register }, fill: .colour(faces.lit))
        if !rock.top.isEmpty { svg.polygon(rock.top.map { $0 + register }, fill: .colour(faces.top)) }
        if !rock.shade.isEmpty { svg.polygon(rock.shade.map { $0 + register }, fill: .colour(faces.shade)) }
        svg.polygon(rock.outline, fill: .none, stroke: line, width: 1.25)
        for edge in rock.edges { svg.line(edge, stroke: line, width: 0.85) }
        ore(&svg)
    }

    /// Short strokes about a point, as the reference draws a glint.
    private static func glint(_ svg: inout SVG, at p: P, size: Double = 1) {
        var d = PathData()
        for degrees in [-140.0, -180, 140] {
            let u = P.direction(degrees)
            d.move(p + u * (2.2 * size))
            d.line(p + u * (4.6 * size))
        }
        svg.path(d, stroke: line, width: 0.9)
    }

    /// A four-pointed sparkle.
    private static func sparkle(_ svg: inout SVG, at p: P, radius r: Double, colour: String) {
        let k = r * 0.26
        let points = [P(0, -r), P(k, -k), P(r, 0), P(k, k), P(0, r), P(-k, k), P(-r, 0), P(-k, -k)].map { $0 + p }
        svg.polygon(points, fill: .colour(colour), stroke: line, width: 0.6)
    }

    /// A closed curve through the middles of the polygon's sides, rounding each corner.
    private static func blob(_ points: [P], shift: P = P(0, 0)) -> PathData {
        func middle(_ a: P, _ b: P) -> P { (a + b) * 0.5 }
        var d = PathData()
        d.move(middle(points[points.count - 1], points[0]) + shift)
        for i in points.indices { d.quad(points[i] + shift, middle(points[i], points[(i + 1) % points.count]) + shift) }
        d.close()
        return d
    }

    /// A rounded lump of ore or metal: its colour, a highlight at its upper left, and its line.
    private static func nugget(_ svg: inout SVG, _ points: [P], colour: String, glint: String) {
        svg.path(blob(points, shift: P(-0.5, 0.4)), fill: .colour(colour))
        let xs = points.map(\.x), ys = points.map(\.y)
        let rx = (xs.max()! - xs.min()!) / 2, ry = (ys.max()! - ys.min()!) / 2
        let centre = P((xs.max()! + xs.min()!) / 2, (ys.max()! + ys.min()!) / 2)
        svg.ellipse(centre + P(-rx * 0.32, -ry * 0.36), rx * 0.36, ry * 0.28, fill: .colour(glint))
        svg.path(blob(points), stroke: line, width: 0.85)
    }

    /// Stone to quarry: a pile of pale boulders, taller than any deposit, one
    /// marked by the wedges that split it, with a broken piece at its foot.
    private static func drawStone(_ svg: inout SVG, shadow: Bool) {
        if shadow { groundShadow(&svg, at: P(0, 4), rx: 27, ry: 8.5) }
        let faces = TerrainFaces(top: TerrainInk.stoneTop, lit: TerrainInk.stoneLit, shade: TerrainInk.stoneShade)
        // The great boulder behind.
        rock(&svg, TerrainRock(
            outline: [P(-18, -1), P(-20, -8), P(-19, -16), P(-14, -24), P(-6, -29), P(3, -30), P(11, -26), P(16, -18),
                      P(17, -9), P(14, -2), P(5, 0)],
            top: [P(-19, -16), P(-14, -24), P(-6, -29), P(3, -30), P(11, -26), P(1, -18), P(-8, -18.4)],
            shade: [P(11, -26), P(16, -18), P(17, -9), P(14, -2), P(5, 0), P(3.4, -9), P(1, -18)],
            edges: [[P(-19, -16), P(-8, -18.4), P(1, -18), P(11, -26)], [P(1, -18), P(3.4, -9), P(5, 0)]]), faces) { svg in
            // The marks of the wedges.
            svg.line([P(-14, -11.6), P(-10, -10.2)], stroke: line, width: 0.8, opacity: 0.7)
            svg.line([P(-13.4, -7), P(-9.4, -5.6)], stroke: line, width: 0.8, opacity: 0.7)
        }
        // The boulder at the left, in front.
        rock(&svg, TerrainRock(
            outline: [P(-22, 6), P(-23.4, 1), P(-21, -4), P(-16, -8), P(-10, -8.4), P(-6, -4.4), P(-5, 1.6), P(-8, 6),
                      P(-15, 8)],
            top: [P(-21, -4), P(-16, -8), P(-10, -8.4), P(-6, -4.4), P(-12.4, -2)],
            shade: [P(-6, -4.4), P(-5, 1.6), P(-8, 6), P(-10.6, 2.4), P(-12.4, -2)],
            edges: [[P(-21, -4), P(-12.4, -2), P(-6, -4.4)], [P(-12.4, -2), P(-10.6, 2.4), P(-8, 6)]]), faces)
        // The boulder at the right, in front.
        rock(&svg, TerrainRock(
            outline: [P(-1, 8.4), P(-3, 3), P(-1, -3), P(5, -7.6), P(12, -8.6), P(18, -5), P(20, 1), P(17, 7), P(9, 10)],
            top: [P(-1, -3), P(5, -7.6), P(12, -8.6), P(18, -5), P(9.4, -1)],
            shade: [P(18, -5), P(20, 1), P(17, 7), P(9, 10), P(10.4, 4), P(9.4, -1)],
            edges: [[P(-1, -3), P(9.4, -1), P(18, -5)], [P(9.4, -1), P(10.4, 4), P(9, 10)]]), faces)
        // A piece broken off, at the front.
        rock(&svg, TerrainRock(
            outline: [P(-8, 12.6), P(-8.8, 10), P(-6, 7.8), P(-1.6, 8), P(0.6, 10.6), P(-1.4, 13.2), P(-5, 13.8)],
            top: [P(-8.8, 10), P(-6, 7.8), P(-1.6, 8), P(0.6, 10.6), P(-4, 10.6)],
            edges: [[P(-8.6, 10.2), P(-4, 10.6), P(0.4, 10.4)]]), faces)
    }

    /// The outcrop: plain bedrock, low, dark and rounded, with no edge split or
    /// squared and nothing showing in it, so that it reads neither as stone to
    /// quarry nor as ore (requirement 19).
    static func drawOutcrop(_ svg: inout SVG, shadow: Bool = true) {
        if shadow { groundShadow(&svg, at: P(0, 3), rx: 28, ry: 8) }
        let faces = TerrainFaces(top: TerrainInk.outcropTop, lit: TerrainInk.outcropLit, shade: TerrainInk.outcropShade)
        rock(&svg, TerrainRock(
            outline: [P(-26, 4), P(-27, -1), P(-21, -6), P(-9, -10), P(5, -10), P(17, -7), P(25, -2), P(24, 4), P(13, 9),
                      P(-3, 10), P(-17, 8)],
            top: [P(-27, -1), P(-21, -6), P(-9, -10), P(5, -10), P(17, -7), P(25, -2), P(8, -2), P(-10, -1)],
            shade: [P(8, -2), P(25, -2), P(24, 4), P(13, 9), P(6, 9.6)],
            edges: [[P(-18, -0.8), P(-10, -1), P(8, -2)], [P(8, -2), P(6, 9.4)]]), faces) { svg in
            // Lichen on its back, and a crack.
            svg.ellipse(P(-12, -5.6), 2.8, 1.2, fill: .colour(TerrainInk.moss), opacity: 0.85)
            svg.ellipse(P(7, -6.6), 1.9, 0.9, fill: .colour(TerrainInk.moss), opacity: 0.85)
            svg.circle(P(-4, -7.4), 0.7, fill: .colour(TerrainInk.light), opacity: 0.6)
            svg.line([P(-5, -9.6), P(-3.4, -6.6), P(-5.4, -3.4)], stroke: line, width: 0.8)
        }
        rock(&svg, TerrainRock(
            outline: [P(14, 11.6), P(13.6, 8.6), P(16.6, 6.4), P(21, 6), P(25.4, 7.4), P(26.6, 10.2), P(24, 12.6), P(19, 13.4)],
            top: [P(13.6, 8.6), P(16.6, 6.4), P(21, 6), P(25.4, 7.4), P(20, 9.2)],
            edges: [[P(14, 8.8), P(20, 9.2), P(25.6, 7.8)]]), faces)
    }

    /// Copper: a mound of green ore, its lumps the colour of the metal.
    private static func drawCopper(_ svg: inout SVG, shadow: Bool) {
        if shadow { groundShadow(&svg, at: P(-1, 4), rx: 27, ry: 8) }
        let faces = TerrainFaces(top: TerrainInk.copperTop, lit: TerrainInk.copperLit, shade: TerrainInk.copperShade)
        rock(&svg, TerrainRock(
            outline: [P(-21, 6), P(-24, -4), P(-18, -15), P(-7, -22), P(5, -23), P(15, -16), P(20, -5), P(17, 5), P(5, 10),
                      P(-10, 10)],
            top: [P(-18, -15), P(-7, -22), P(5, -23), P(15, -16), P(4, -12), P(-8, -11)],
            shade: [P(15, -16), P(20, -5), P(17, 5), P(5, 10), P(6, -2), P(4, -12)],
            edges: [[P(-16, -13.4), P(-8, -11), P(4, -12)], [P(4, -12), P(6, -2), P(5, 10)]]), faces) { svg in
            nugget(&svg, [P(-11.4, -4.6), P(-9.4, -9.6), P(-5.6, -10.6), P(-2.2, -8), P(-2.8, -4.4), P(-5.6, -2.2),
                          P(-9.4, -2.4)], colour: TerrainInk.copper, glint: TerrainInk.copperGlint)
            nugget(&svg, [P(5.6, -9.4), P(8.6, -12.4), P(12.6, -11.4), P(13, -8.6), P(10.6, -6.4), P(7.4, -6.8)],
                   colour: TerrainInk.copper, glint: TerrainInk.copperGlint)
            nugget(&svg, [P(-16, -11.6), P(-14.4, -14.6), P(-11, -14.2), P(-10.4, -11.6), P(-13, -10.2)],
                   colour: TerrainInk.copper, glint: TerrainInk.copperGlint)
            nugget(&svg, [P(8.6, 2.2), P(10, -1.2), P(13.8, -0.8), P(14.6, 2.6), P(12, 4.6), P(9.8, 4.4)],
                   colour: TerrainInk.copper, glint: TerrainInk.copperGlint)
            nugget(&svg, [P(-1.6, 3.4), P(0, 1.6), P(2.4, 2.4), P(1.8, 4.6), P(-0.4, 5)],
                   colour: TerrainInk.copper, glint: TerrainInk.copperGlint)
            glint(&svg, at: P(15, -21), size: 1.1)
        }
        rock(&svg, TerrainRock(
            outline: [P(-28, 9), P(-29.4, 5.4), P(-27, 1.6), P(-22, 0), P(-17.6, 1.4), P(-15.6, 5), P(-17.4, 8.6), P(-22, 10.4)],
            top: [P(-29.4, 5.4), P(-27, 1.6), P(-22, 0), P(-17.6, 1.4), P(-21.6, 4.6)],
            shade: [P(-17.6, 1.4), P(-15.6, 5), P(-17.4, 8.6), P(-20.6, 8), P(-21.6, 4.6)],
            edges: [[P(-29, 5.2), P(-21.6, 4.6), P(-17.6, 1.4)]]), faces) { svg in
            nugget(&svg, [P(-26, 6.4), P(-25, 4.4), P(-22.6, 4.8), P(-22, 7), P(-24.4, 8.2)],
                   colour: TerrainInk.copper, glint: TerrainInk.copperGlint)
        }
    }

    /// A crystal of tin ore: a pale prism with a pointed end, standing from `base` at `angle` degrees.
    private static func crystal(_ svg: inout SVG, base: P, angle: Double, length: Double, width: Double) {
        svg.group(at: base, turned: angle) { svg in
            let w = width / 2
            let body = [P(-w, 0.6), P(-w, -length + w * 1.5), P(0, -length), P(w, -length + w * 1.5), P(w, 0.6)]
            let shift = P(-0.5, 0.4)
            svg.polygon(body.map { $0 + shift }, fill: .colour(TerrainInk.tinCrystal))
            svg.polygon([P(0, -length), P(w, -length + w * 1.5), P(w, 0.6), P(0, 0.6)].map { $0 + shift },
                        fill: .colour(TerrainInk.tinCrystalShade))
            svg.polygon(body, fill: .none, stroke: line, width: 0.85)
            svg.line([P(0, -length + 0.4), P(0, 0.2)], stroke: line, width: 0.5, opacity: 0.6)
        }
    }

    /// Tin: a crag of blue-grey rock with clusters of pale crystals.
    private static func drawTin(_ svg: inout SVG, shadow: Bool) {
        if shadow { groundShadow(&svg, at: P(0, 4), rx: 26, ry: 8) }
        let faces = TerrainFaces(top: TerrainInk.tinTop, lit: TerrainInk.tinLit, shade: TerrainInk.tinShade)
        rock(&svg, TerrainRock(
            outline: [P(-19, 7), P(-23, -2), P(-19, -12), P(-10, -17), P(-3, -15), P(3, -21), P(12, -19), P(19, -10),
                      P(20, 1), P(11, 9), P(-4, 10)],
            top: [P(-19, -12), P(-10, -17), P(-3, -15), P(3, -21), P(12, -19), P(7, -11), P(-6, -8)],
            shade: [P(12, -19), P(19, -10), P(20, 1), P(11, 9), P(8, -2), P(7, -11)],
            edges: [[P(-16, -10), P(-6, -8), P(7, -11), P(12, -19)], [P(7, -11), P(8, -2), P(11, 9)]]), faces) { svg in
            crystal(&svg, base: P(-9, -9), angle: -24, length: 9, width: 3.2)
            crystal(&svg, base: P(-7, -9.6), angle: 4, length: 12, width: 3.6)
            crystal(&svg, base: P(-5, -9), angle: 30, length: 8, width: 3)
            crystal(&svg, base: P(11, -6), angle: 10, length: 9, width: 3.2)
            crystal(&svg, base: P(13, -5.4), angle: 38, length: 6.5, width: 2.8)
            crystal(&svg, base: P(-15, 3), angle: -16, length: 6, width: 2.6)
            crystal(&svg, base: P(-13, 3.4), angle: 18, length: 7, width: 2.8)
            glint(&svg, at: P(-6.4, -24.4), size: 0.9)
        }
    }

    /// Gold: a dark boulder seamed with yellow, with nuggets and sparkles.
    private static func drawGold(_ svg: inout SVG, shadow: Bool) {
        if shadow { groundShadow(&svg, at: P(0, 4), rx: 27, ry: 8) }
        let faces = TerrainFaces(top: TerrainInk.goldTop, lit: TerrainInk.goldLit, shade: TerrainInk.goldShade)
        rock(&svg, TerrainRock(
            outline: [P(-22, 6), P(-23, -5), P(-15, -16), P(-3, -21), P(10, -19), P(19, -9), P(21, 2), P(12, 9), P(-6, 11)],
            top: [P(-15, -16), P(-3, -21), P(10, -19), P(4, -11), P(-9, -10)],
            shade: [P(10, -19), P(19, -9), P(21, 2), P(12, 9), P(5, 1), P(4, -11)],
            edges: [[P(-13, -12.6), P(-9, -10), P(4, -11)], [P(4, -11), P(5, 1), P(12, 9)]]), faces) { svg in
            // Seams of gold across both faces.
            svg.line([P(-21, -1), P(-15, -4), P(-10, 0), P(-4, -3.4), P(3, 0.4)], stroke: .colour(TerrainInk.gold), width: 1.9)
            svg.line([P(7, -5), P(11, -2.4), P(15, -5.6), P(19.4, -2.6)], stroke: .colour(TerrainInk.gold), width: 1.7)
            svg.line([P(-16, 5), P(-10, 3), P(-5, 6.4)], stroke: .colour(TerrainInk.gold), width: 1.5)
            nugget(&svg, [P(-9, -14), P(-7, -17.4), P(-3, -16.6), P(-2, -13), P(-5.4, -11.4)],
                   colour: TerrainInk.gold, glint: TerrainInk.goldGlint)
            nugget(&svg, [P(7, -12), P(9, -15.4), P(13, -14), P(13, -10.4), P(10, -9.4)],
                   colour: TerrainInk.gold, glint: TerrainInk.goldGlint)
            nugget(&svg, [P(-1, 4), P(1, 1.6), P(4, 2.6), P(3.4, 5.6), P(0.4, 6.2)],
                   colour: TerrainInk.gold, glint: TerrainInk.goldGlint)
            sparkle(&svg, at: P(1, -25.6), radius: 3.2, colour: TerrainInk.goldGlint)
            sparkle(&svg, at: P(18.6, -15.4), radius: 2.3, colour: TerrainInk.goldGlint)
            sparkle(&svg, at: P(-19, -12.4), radius: 1.8, colour: TerrainInk.goldGlint)
        }
    }
}
