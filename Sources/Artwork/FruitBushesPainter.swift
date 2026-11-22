// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The parts every fruit bush is drawn from: a shadow, stems, a crown of
// scalloped masses of leaf, leaves marked on it, and the fruit. Units are
// points, with the origin on the ground at the tile's centre and y running
// downward, as SVG has it, as the other sites are drawn (`TerrainSites.swift`).
// Each colour field lies a little out of register with the line drawn over it.

/// One mass of a bush's leaves: a scalloped oval, lit on the upper left and in
/// shade on the lower right.
struct BushMass {
    var centre: P
    var rx: Double
    var ry: Double
    /// The number of scallops round its edge.
    var lobes: Int
    /// How far each scallop bulges beyond the oval, as a share of its radius.
    var bulge: Double
    /// Where round the oval the first scallop starts, in degrees.
    var phase: Double = 0
    /// How far the scallops differ from one another, from 0 (all alike) up.
    var ragged: Double = 0
    var lit: String
    var shade: String
}

enum FruitBushPainter {
    /// The canvas of every bush, the size of the other sites' (`TerrainSprites.siteCanvas`).
    static let canvas = Canvas(minX: -36, minY: -60, width: 72, height: 80, pixelsPerUnit: 2)

    static let register = P(-0.8, 0.6)
    static let line = Paint.colour(Ink.line)

    /// The soft shadow on the ground under the bush.
    static func shadow(_ svg: inout SVG, at c: P = P(1.5, 1.2), rx: Double = 21, ry: Double = 6) {
        svg.ellipse(c, rx, ry, fill: .colour("#000000"), opacity: 0.16)
    }

    /// Stems from the ground up into the crown: each a tapering woody line.
    static func stems(_ svg: inout SVG, _ stems: [[P]], colour: String, width: Double = 1.6) {
        for stem in stems {
            svg.line(stem.map { $0 + register }, stroke: .colour(colour), width: width + 0.8)
            svg.line(stem, stroke: line, width: 0.78)
        }
    }

    /// The mass's outline: scallops round the oval, each a curve bulging outward.
    static func outline(_ mass: BushMass, shift: P = P(0, 0)) -> PathData {
        let n = max(mass.lobes, 3)
        func point(_ degrees: Double, _ k: Double) -> P {
            let a = degrees * .pi / 180
            return mass.centre + P(mass.rx * cos(a) * k, mass.ry * sin(a) * k) + shift
        }
        var d = PathData()
        d.move(point(mass.phase, 1))
        for i in 0..<n {
            let a0 = mass.phase + 360 * Double(i) / Double(n)
            let a1 = mass.phase + 360 * Double(i + 1) / Double(n)
            // A fixed wobble, so that the scallops differ but the same bush is drawn every time.
            let wobble = 1 + mass.ragged * sin(Double(i) * 2.39 + mass.phase)
            d.quad(point((a0 + a1) / 2, 1 + mass.bulge * 2 * wobble), point(a1, 1))
        }
        d.close()
        return d
    }

    /// A mass of leaves: the lit field, the shade on its lower right within it,
    /// `marks` drawn on it (leaves), then its line.
    static func mass(_ svg: inout SVG, _ mass: BushMass, id: String, marks: (inout SVG) -> Void = { _ in }) {
        let field = outline(mass, shift: register)
        svg.path(field, fill: .colour(mass.lit))
        svg.raw("<clipPath id=\"\(id)\"><path d=\"\(field.text)\"/></clipPath>")
        svg.raw("<g clip-path=\"url(#\(id))\">")
        svg.ellipse(mass.centre + P(mass.rx * 0.55, mass.ry * 0.5), mass.rx * 1.05, mass.ry * 0.95, fill: .colour(mass.shade))
        marks(&svg)
        svg.raw("</g>")
        svg.path(outline(mass), stroke: line, width: 1.04)
    }

    /// A leaf: an almond from its stalk end `at`, pointing `degrees` from
    /// straight up, with its midrib where `veined`.
    static func leaf(_ svg: inout SVG, at p: P, degrees: Double, length: Double, width: Double, colour: String,
                     veined: Bool = false) {
        svg.group(turned: degrees, about: p) { svg in
            let tip = p + P(0, -length), half = width / 2
            var d = PathData()
            d.move(p)
            d.quad(p + P(half * 1.6, -length * 0.5), tip)
            d.quad(p + P(-half * 1.6, -length * 0.5), p)
            d.close()
            svg.path(d, fill: .colour(colour))
            if veined { svg.line([p, p + P(0, -length * 0.8)], stroke: line, width: 0.39, opacity: 0.6) }
        }
    }

    /// A vine leaf or a currant's: three to five pointed lobes about a centre.
    static func lobedLeaf(_ svg: inout SVG, at p: P, degrees: Double, size: Double, colour: String, lobes: Int = 5) {
        svg.group(turned: degrees, about: p) { svg in
            var d = PathData()
            let spread = lobes == 3 ? [-55.0, 0, 55] : [-100.0, -50, 0, 50, 100]
            d.move(p)
            for (i, angle) in spread.enumerated() {
                let reach = size * (i == spread.count / 2 ? 1 : 0.78)
                let tip = p + P.direction(180 + angle) * reach
                let left = p + P.direction(180 + angle - 16) * (reach * 0.62)
                let right = p + P.direction(180 + angle + 16) * (reach * 0.62)
                d.line(left)
                d.line(tip)
                d.line(right)
            }
            d.close()
            svg.path(d, fill: .colour(colour))
            svg.line([p, p + P(0, -size * 0.8)], stroke: line, width: 0.35, opacity: 0.55)
        }
    }

    /// A round fruit: its colour, the shade on its lower right, a glint on its
    /// upper left, and its line.
    static func round(_ svg: inout SVG, at c: P, rx: Double, ry: Double? = nil, colour: String, shade: String, glint: String) {
        let ry = ry ?? rx
        svg.ellipse(c + register * 0.6, rx, ry, fill: .colour(colour))
        svg.raw("<clipPath id=\"fruit-\(num(c.x))-\(num(c.y))\"><ellipse cx=\"\(num(c.x + register.x * 0.6))\" "
                + "cy=\"\(num(c.y + register.y * 0.6))\" rx=\"\(num(rx))\" ry=\"\(num(ry))\"/></clipPath>")
        svg.raw("<g clip-path=\"url(#fruit-\(num(c.x))-\(num(c.y)))\">")
        svg.ellipse(c + P(rx * 0.8, ry * 0.85), rx * 0.95, ry * 0.85, fill: .colour(shade))
        svg.raw("</g>")
        svg.ellipse(c + P(-rx * 0.38, -ry * 0.4), rx * 0.3, ry * 0.24, fill: .colour(glint))
        svg.ellipse(c, rx, ry, fill: .none, stroke: line, width: 0.7)
    }

    /// A short curved stalk from `from` to `to`.
    static func stalk(_ svg: inout SVG, from: P, to: P, bend: Double = 1) {
        let mid = (from + to) * 0.5 + P(bend, 0)
        svg.path("M\(num(from.x)),\(num(from.y)) Q\(num(mid.x)),\(num(mid.y)) \(num(to.x)),\(num(to.y))", stroke: line, width: 0.65)
    }
}
