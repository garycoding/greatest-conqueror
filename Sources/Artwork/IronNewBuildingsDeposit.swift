// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The iron deposit, standing on the centre of its tile in the manner of the
// terrain's sites: an angular crag of rust-red ironstone banded with grey,
// metallic ore, with broken chunks of the grey ore at its foot and rust running
// down its faces. Its angular, banded rock keeps it apart from the pale
// boulders of stone, the green mound of copper, the blue-grey crag and pale
// crystals of tin, and the dark rounded boulder and yellow nuggets of gold.
// Units are points, with the origin on the ground at the tile's centre and y
// running downward; it carries no team colour.

enum IronNewBuildingsDeposit {
    /// How far each colour field lies out of register with its line, as the sites have it.
    private static let register = P(-0.8, 0.6)
    private static let line = Paint.colour(IronNewBuildingsInk.line)

    /// The colours of the ironstone and its ore.
    private static let rockTop = "#b97559"
    private static let rockLit = "#9d5940"
    private static let rockShade = "#733d2b"
    private static let ore = "#6c6a6e"
    private static let oreLight = "#a4a3a8"
    private static let oreShade = "#4c4a4f"
    private static let rust = "#c9773f"

    /// The deposit; without `shadow`, without its shadow on the ground, to rise from the water.
    static func draw(_ svg: inout SVG, shadow: Bool = true) {
        if shadow { svg.ellipse(P(0, 4), 27, 8, fill: .colour("#000000"), opacity: 0.16) }
        // The crag behind: its faces, then the bands of ore across them.
        let outline = [P(-21, 5), P(-23, -6), P(-18, -16), P(-9, -24), P(1, -27), P(9, -22), P(17, -14), P(20, -3), P(17, 6),
                       P(5, 10), P(-9, 10)]
        let top = [P(-18, -16), P(-9, -24), P(1, -27), P(9, -22), P(17, -14), P(5, -12), P(-8, -12)]
        let shade = [P(17, -14), P(20, -3), P(17, 6), P(5, 10), P(6, -1), P(5, -12)]
        svg.polygon(outline.map { $0 + register }, fill: .colour(rockLit))
        svg.polygon(top.map { $0 + register }, fill: .colour(rockTop))
        svg.polygon(shade.map { $0 + register }, fill: .colour(rockShade))
        // Bands of grey ore, tilted, across the lit face and on round the shaded one.
        band(&svg, [P(-22, -4.6), P(-14, -6.4), P(-6, -5.4), P(5.4, -7.4)], width: 2.6)
        band(&svg, [P(5.6, -7.4), P(12, -8.6), P(18.4, -10.6)], width: 2.4)
        band(&svg, [P(-21.4, 1.2), P(-12, -0.4), P(-3, 0.4), P(5.8, -1)], width: 2.2)
        band(&svg, [P(6, -1), P(12.6, -1.8), P(19.4, -3.6)], width: 2)
        band(&svg, [P(-17, 6.4), P(-8, 5.6), P(4.6, 6.4)], width: 1.6)
        // Flecks of ore showing on the crag's top.
        for (x, y, size) in [(-9.0, -19.0, 1.0), (-2.0, -22.4, 0.8), (7.0, -18.6, 0.9), (-12.4, -15.2, 0.7)] {
            let fleck = [P(-1.6, 0.4), P(-0.8, -1), P(1.4, -0.8), P(1.6, 0.6), P(0, 1)].map { P(x, y) + $0 * size }
            svg.polygon(fleck, fill: .colour(ore), stroke: line, width: 0.5)
        }
        // Rust stains below the bands, where water has run over the ore.
        for (x, y, length) in [(-15.0, -3.4, 3.4), (-4.0, -3.8, 2.6), (-9.0, 2.2, 2.8), (11.0, -6.6, 3.4), (15.4, -1.4, 2.4)] {
            var stain = PathData()
            stain.move(P(x - 1.1, y))
            stain.quad(P(x - 0.6, y + length * 0.7), P(x, y + length))
            stain.quad(P(x + 0.6, y + length * 0.7), P(x + 1.1, y))
            stain.close()
            svg.path(stain, fill: .colour(rust), opacity: 0.6)
        }
        svg.polygon(outline, fill: .none, stroke: line, width: 1.25)
        svg.line([P(-16, -13.6), P(-8, -12), P(5, -12), P(17, -14)], stroke: line, width: 0.85)
        svg.line([P(5, -12), P(6, -1), P(5, 10)], stroke: line, width: 0.85)
        // A split across the crag's top.
        svg.line([P(-3, -26), P(-1, -21), P(-3.4, -16.4)], stroke: line, width: 0.8)
        // Chunks of ore broken from it, lying at its foot: angular, grey, glinting.
        chunk(&svg, at: P(-15, 8), size: 1.2)
        chunk(&svg, at: P(10.4, 10.6), size: 1.4)
        chunk(&svg, at: P(-3.4, 12.6), size: 1)
        chunk(&svg, at: P(20.4, 7.6), size: 0.8)
        // A lesser block of ironstone at the left, in front.
        let small = [P(-28, 10), P(-29, 4), P(-25, 0), P(-19.4, 0.8), P(-17.6, 5), P(-20, 10.4)]
        let smallTop = [P(-29, 4), P(-25, 0), P(-19.4, 0.8), P(-23.4, 3.6)]
        let smallShade = [P(-19.4, 0.8), P(-17.6, 5), P(-20, 10.4), P(-22.4, 9.6), P(-23.4, 3.6)]
        svg.polygon(small.map { $0 + register }, fill: .colour(rockLit))
        svg.polygon(smallTop.map { $0 + register }, fill: .colour(rockTop))
        svg.polygon(smallShade.map { $0 + register }, fill: .colour(rockShade))
        band(&svg, [P(-28.6, 6.4), P(-23.4, 5.8), P(-18.4, 6.6)], width: 1.8)
        svg.polygon(small, fill: .none, stroke: line, width: 1.2)
        svg.line([P(-28.6, 4.2), P(-23.4, 3.6), P(-19.6, 1)], stroke: line, width: 0.8)
        // The glint of the ore, as the sites draw a glint.
        glint(&svg, at: P(14, -21.4))
    }

    /// A band of ore along the points, outlined lightly so that it reads as a seam in the rock.
    private static func band(_ svg: inout SVG, _ points: [P], width: Double, colour: String = ore) {
        svg.line(points.map { $0 + register }, stroke: .colour(colour), width: width)
        svg.line(points.map { $0 + P(0, -width * 0.25) }, stroke: .colour(oreLight), width: width * 0.3, opacity: 0.8)
        svg.line(points.map { $0 + P(0, width * 0.55) }, stroke: line, width: 0.45, opacity: 0.6)
    }

    /// An angular chunk of grey ore lying at `p`: a lit top facet, a shaded side, and a glint.
    private static func chunk(_ svg: inout SVG, at p: P, size s: Double) {
        let outline = [P(-4, 1), P(-4.6, -2.4), P(-1.6, -5), P(2.8, -4.4), P(4.6, -1.4), P(3, 1.6)].map { p + $0 * s }
        let top = [P(-4.6, -2.4), P(-1.6, -5), P(2.8, -4.4), P(0.6, -1.8)].map { p + $0 * s }
        let side = [P(2.8, -4.4), P(4.6, -1.4), P(3, 1.6), P(0.6, -1.8)].map { p + $0 * s }
        svg.ellipse(p + P(0.6, 1.2 * s), 5 * s, 1.4 * s, fill: .colour("#000000"), opacity: 0.14)
        svg.polygon(outline.map { $0 + register }, fill: .colour(ore))
        svg.polygon(top.map { $0 + register }, fill: .colour(oreLight))
        svg.polygon(side.map { $0 + register }, fill: .colour(oreShade))
        svg.polygon(outline, fill: .none, stroke: line, width: 0.9)
        svg.line([p + P(-4.4, -2.2) * s, p + P(0.6, -1.8) * s, p + P(2.8, -4.4) * s], stroke: line, width: 0.55)
        svg.line([p + P(0.6, -1.8) * s, p + P(3, 1.4) * s], stroke: line, width: 0.55)
        svg.circle(p + P(-1.2, -3.4) * s, 0.55 * s, fill: .colour(IronNewBuildingsInk.light))
    }

    /// Short strokes about a point.
    private static func glint(_ svg: inout SVG, at p: P) {
        var d = PathData()
        for degrees in [-140.0, -180, 140] {
            let u = P.direction(degrees)
            d.move(p + u * 2.2)
            d.line(p + u * 4.6)
        }
        svg.path(d, stroke: line, width: 0.9)
    }
}
