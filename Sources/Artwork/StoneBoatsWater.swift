// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// What the boats gather on the water (ruled 2026-11-21): the fish, one tile
// of a shoal, and the rocks that rise from the water. Units are points, with
// the origin at the tile's centre on the water and y running downward, as
// the terrain's sites have it (`TerrainSprites.siteCanvas`); the tile's
// diamond reaches 32 points to either side and 16 before and behind. The
// water's surface is a plane seen at the map's angle, so a ring on it is an
// ellipse half as deep as it is wide. Nothing here carries a team's colour.

enum StoneBoatsWater {
    private static let line = Paint.colour(Ink.line)
    /// How far each colour field lies out of register with its line, as the sites have it.
    private static let register = P(-0.8, 0.6)

    // MARK: Rings on the water

    /// A ring on the water about `c`, `rx` wide: drawn whole, or only the arcs
    /// between `gaps` (pairs of degrees, 90 nearest the viewer).
    static func ring(_ svg: inout SVG, at c: P, rx: Double, opacity: Double, width: Double = 1,
                     arcs: [(Double, Double)] = [(0, 360)], depth: Double = 0.42) {
        guard opacity > 0.01 else { return }
        let ry = rx * depth
        var d = PathData()
        for (from, to) in arcs {
            let steps = max(3, Int(abs(to - from) / 8))
            for i in 0...steps {
                let a = (from + (to - from) * Double(i) / Double(steps)) * .pi / 180
                let p = P(c.x + rx * cos(a), c.y + ry * sin(a))
                if i == 0 { d.move(p) } else { d.line(p) }
            }
        }
        svg.path(d, stroke: .colour(BoatInk.foam), width: width, opacity: opacity)
    }

    /// Drops of water thrown up from `c`: `t` from 0 (thrown) to 1 (fallen).
    static func splash(_ svg: inout SVG, at c: P, t: Double, size: Double = 1) {
        guard t >= 0, t < 1 else { return }
        let fade = 1 - t * t
        for (i, degrees) in [-150.0, -120, -95, -70, -40].enumerated() {
            let a = degrees * .pi / 180
            let reach = (3 + Double(i % 2) * 1.6) * size * (0.4 + t)
            let lift = 7 * size * t * (1 - t) * (i % 2 == 0 ? 1 : 0.7)
            let p = c + P(cos(a) * reach * 1.3, sin(a) * reach * 0.6 - lift * 2.2)
            svg.circle(p, (0.9 + Double(i % 3) * 0.25) * size, fill: .colour(BoatInk.foam), stroke: line,
                       width: 0.45, opacity: fade)
        }
        // The crown of the splash, while it stands.
        if t < 0.5 {
            var d = PathData()
            let w = 3.4 * size * (0.7 + t)
            d.move(c + P(-w, 0.4))
            d.quad(c + P(-w * 0.6, -4 * size * (1 - t)), c + P(-w * 0.2, -0.6))
            d.quad(c + P(0, -5.5 * size * (1 - t)), c + P(w * 0.2, -0.6))
            d.quad(c + P(w * 0.6, -4 * size * (1 - t)), c + P(w, 0.4))
            d.close()
            svg.path(d, fill: .colour(BoatInk.foam), stroke: line, width: 0.6, opacity: 1 - t)
        }
    }

    // MARK: The fish

    /// Where a leaping fish comes out of the water and goes back in, and how
    /// high it leaps.
    static let leapFrom = P(-9, 3.4), leapTo = P(9.4, 7.4), leapHeight = 17.0
    /// The share of the cycle the fish spends in the air.
    static let leapShare = 5.0 / 12

    /// One frame of the fish: a few fish dark under the water, turning slowly;
    /// one leaping from the water and diving back, with a splash at each end;
    /// and the rings each leaves, spreading and fading through the cycle.
    static func fish(frame: Int) -> SpriteImage? {
        let canvas = TerrainSprites.siteCanvas
        let rendered = Raster.render(on: canvas) { svg in drawFish(&svg, frame: frame) }
        return rendered?.sprite(anchor: canvas.anchor)
    }

    static func drawFish(_ svg: inout SVG, frame: Int) {
        let p = Double(frame) / Double(SpriteKey.framesPerPose)
        // The shoal under the water, circling slowly so that it reads as alive between the leaps.
        for (i, base) in [P(-12, -2), P(5, -6), P(13, 3), P(-3, 7)].enumerated() {
            let t = (p + Double(i) / 4) * 2 * .pi
            let at = base + P(2.4 * sin(t), 1.1 * cos(t))
            let heading = (i % 2 == 0 ? 0.0 : 180) + 16 * cos(t)
            underwaterFish(&svg, at: at, degrees: heading, length: 12 + Double(i % 2) * 2)
        }
        // The rings where the fish left the water and where it went back in.
        for (centre, start) in [(leapFrom, 0.0), (leapTo, leapShare)] {
            for lag in [0.0, 0.14] {
                let age = (p - start - lag + 2).truncatingRemainder(dividingBy: 1)
                ring(&svg, at: centre, rx: 3 + 15 * age, opacity: pow(1 - age, 0.9), width: 1.6 - 0.7 * age)
            }
        }
        // The leap: out of the water, over, and back in.
        let s = p / leapShare
        if s <= 1.001 {
            let s = min(s, 1)
            let along = leapTo - leapFrom
            let at = leapFrom + along * s - P(0, leapHeight * 4 * s * (1 - s))
            let slope = P(along.x, along.y - leapHeight * 4 * (1 - 2 * s))
            let degrees = atan2(slope.y, slope.x) * 180 / .pi
            // Under the line from where it left the water to where it goes back in, the fish is under water.
            let surface = [leapFrom + P(-40, -along.y / along.x * 40), leapTo + P(40, along.y / along.x * 40)]
            svg.raw("<defs><clipPath id=\"above-water\"><polygon points=\""
                    + [surface[0], surface[1], P(60, -80), P(-60, -80)].map { "\(num($0.x)),\(num($0.y))" }.joined(separator: " ")
                    + "\"/></clipPath></defs><g clip-path=\"url(#above-water)\">")
            leapingFish(&svg, at: at, degrees: degrees, length: 18)
            svg.raw("</g>")
        }
        splash(&svg, at: leapFrom, t: p * 6, size: 0.9)
        splash(&svg, at: leapTo, t: (p - leapShare + 1 / 12) * 5, size: 1)
    }

    /// A fish seen dark through the water: a slim body and a forked tail.
    private static func underwaterFish(_ svg: inout SVG, at c: P, degrees: Double, length: Double) {
        svg.group(at: c, turned: degrees) { svg in
            let h = length / 2
            var d = PathData()
            d.move(P(h, 0))
            d.quad(P(h * 0.3, -h * 0.42), P(-h * 0.6, -h * 0.12))
            d.line(P(-h, -h * 0.4))
            d.line(P(-h * 0.84, 0))
            d.line(P(-h, h * 0.4))
            d.line(P(-h * 0.6, h * 0.12))
            d.quad(P(h * 0.3, h * 0.42), P(h, 0))
            d.close()
            svg.path(d, fill: .colour(BoatInk.underwater), opacity: 0.6)
        }
    }

    /// The leaping fish, along `degrees`: a pale belly and a slate back, a
    /// forked tail, a fin, an eye, and the line loosely over the colour.
    private static func leapingFish(_ svg: inout SVG, at c: P, degrees: Double, length: Double) {
        svg.group(at: c, turned: degrees) { svg in
            let h = length / 2
            var body = PathData()
            body.move(P(h, 0.2))
            body.quad(P(h * 0.5, -h * 0.56), P(-h * 0.55, -h * 0.18))
            body.line(P(-h * 0.55, h * 0.18))
            body.quad(P(h * 0.5, h * 0.58), P(h, 0.2))
            body.close()
            var tail = PathData()
            tail.move(P(-h * 0.5, 0))
            tail.line(P(-h * 1.05, -h * 0.48))
            tail.quad(P(-h * 0.88, 0), P(-h * 1.05, h * 0.48))
            tail.close()
            svg.group(at: register) { svg in
                svg.path(tail, fill: .colour(BoatInk.fishBack))
                svg.path(body, fill: .colour(BoatInk.fishBelly))
                // The back, darker, above the line of the flank.
                var back = PathData()
                back.move(P(h * 0.92, -0.2))
                back.quad(P(h * 0.5, -h * 0.56), P(-h * 0.55, -h * 0.18))
                back.line(P(-h * 0.55, -0.1))
                back.quad(P(h * 0.2, -h * 0.12), P(h * 0.92, -0.2))
                back.close()
                svg.path(back, fill: .colour(BoatInk.fishBack))
            }
            svg.path(tail, stroke: line, width: 0.7)
            svg.path(body, stroke: line, width: 0.8)
            // The fin on its back, and the gill.
            svg.path("M\(num(h * 0.1)),\(num(-h * 0.36)) L\(num(-h * 0.2)),\(num(-h * 0.72)) L\(num(-h * 0.34)),\(num(-h * 0.26))",
                     fill: .colour(BoatInk.fishBack), stroke: line, width: 0.6)
            svg.path("M\(num(h * 0.48)),\(num(-h * 0.3)) q\(num(-h * 0.14)),\(num(h * 0.3)) 0,\(num(h * 0.6))", stroke: line, width: 0.5)
            svg.circle(P(h * 0.7, -h * 0.08), 0.55, fill: line)
        }
    }

    // MARK: Rocks rising from the water

    /// The waterline about a rock: an ellipse on the water, its centre a little
    /// in front of the rock's middle, where the rock's foot meets the water.
    static let waterline = (c: P(0, 3.6), rx: 27.0, ry: 8.0)
    /// How far the rock is sunk below where it stands on land.
    static let sink = 4.0

    /// A rock rising from the water, at frame 0: the site's own rock, sunk a
    /// little and cut at the waterline, the part under the water seen faintly
    /// through it, a ring of foam about its foot, and ripples spreading.
    static func afloat(_ kind: SiteKind) -> SpriteImage? {
        guard StoneBoatSprites.rocks.contains(kind) else { return nil }
        let canvas = TerrainSprites.siteCanvas
        let rendered = Raster.render(on: canvas) { svg in drawAfloat(kind, &svg) }
        return rendered?.sprite(anchor: canvas.anchor)
    }

    /// The outcrop rising from the water: a deposit in the water that the
    /// player's age does not yet reveal, plain bedrock at a waterline.
    static func outcropAfloat() -> SpriteImage? {
        let canvas = TerrainSprites.siteCanvas
        let rendered = Raster.render(on: canvas) { svg in drawAfloat(&svg) { TerrainSprites.drawOutcrop(&$0, shadow: false) } }
        return rendered?.sprite(anchor: canvas.anchor)
    }

    static func drawAfloat(_ kind: SiteKind, _ svg: inout SVG) {
        drawAfloat(&svg) { svg in
            TerrainSprites.drawSite(kind, &svg, shadow: false)
        }
    }

    /// A rock, as it stands on land without its shadow, sunk at the waterline.
    static func drawAfloat(_ svg: inout SVG, _ drawRock: (inout SVG) -> Void) {
        let (c, rx, ry) = waterline
        func rock(_ svg: inout SVG) {
            svg.group(at: P(0, sink)) { svg in drawRock(&svg) }
        }
        // The front of the waterline, from the left round the side nearest the viewer to the right.
        let front = stride(from: 180.0, through: 0, by: -6).map { a in P(c.x + rx * cos(a * .pi / 180), c.y + ry * sin(a * .pi / 180)) }
        func polygon(_ points: [P]) -> String { points.map { "\(num($0.x)),\(num($0.y))" }.joined(separator: " ") }
        let above = [P(-60, c.y)] + front + [P(60, c.y), P(60, -90), P(-60, -90)]
        let below = [P(-60, c.y)] + front + [P(60, c.y), P(60, 40), P(-60, 40)]
        svg.raw("<defs><clipPath id=\"above\"><polygon points=\"\(polygon(above))\"/></clipPath>"
                + "<clipPath id=\"below\"><polygon points=\"\(polygon(below))\"/></clipPath></defs>")
        // The ripples spreading behind and about it, the outer ones broken.
        ring(&svg, at: c, rx: rx + 7, opacity: 0.4, width: 0.9, arcs: [(200, 250), (285, 335)], depth: ry / rx)
        // The water darkened about its foot, and the part under the water seen faintly.
        svg.ellipse(c, rx - 1, ry - 0.6, fill: .colour(BoatInk.underwater), opacity: 0.22)
        svg.raw("<g clip-path=\"url(#below)\" opacity=\"0.3\">")
        rock(&svg)
        svg.raw("</g>")
        // The foam behind the rock, then the rock above the water.
        ring(&svg, at: c, rx: rx, opacity: 0.9, width: 1.3, arcs: [(180, 360)], depth: ry / rx)
        svg.raw("<g clip-path=\"url(#above)\">")
        rock(&svg)
        svg.raw("</g>")
        // The foam along the front of the waterline, broken into lapping curls.
        var curls = PathData()
        for (i, a) in stride(from: 172.0, to: 0, by: -16).enumerated() {
            let r0 = a * .pi / 180, r1 = (a - 13) * .pi / 180
            let p0 = P(c.x + rx * cos(r0), c.y + ry * sin(r0)), p1 = P(c.x + rx * cos(r1), c.y + ry * sin(r1))
            curls.move(p0)
            curls.quad((p0 + p1) * 0.5 + P(0, i % 2 == 0 ? 1.4 : 0.9), p1)
        }
        svg.path(curls, stroke: .colour(BoatInk.foam), width: 1.5)
        svg.path(curls, stroke: line, width: 0.4, opacity: 0.35)
        // The ripples in front, broken.
        ring(&svg, at: c + P(0, 1), rx: rx + 5, opacity: 0.7, width: 1, arcs: [(25, 70), (105, 150)], depth: ry / rx)
        ring(&svg, at: c + P(0, 1.6), rx: rx + 9.5, opacity: 0.4, width: 0.8, arcs: [(50, 82), (98, 128)], depth: ry / rx)
    }
}
