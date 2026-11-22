// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// The fruit bush in each of the five looks (ruled 2026-11-22). Every look keeps
// one silhouette, a rounded mound of leaf about a worker's height with its fruit
// on the side toward the viewer, so that a player knows a bush in any age; the
// plant, its fruit and what people have done about it change with the age, in
// that age's palette (docs/art-style.md, "Palettes").

extension FruitBushPainter {
    /// How much larger the bush is drawn than its parts are written.
    static let enlargement = 1.15

    /// The bush in a look, as SVG.
    static func draw(_ look: Look, _ svg: inout SVG) {
        // Drawn a little larger than its parts are written, about its foot, so as to
        // stand a worker's height; the lines' widths are written smaller to match.
        svg.raw("<g transform=\"scale(\(num(enlargement)))\">")
        defer { svg.raw("</g>") }
        switch look {
        case .stone: bramble(&svg)
        case .bronze: pomegranate(&svg)
        case .iron: cornel(&svg)
        case .alchemy: vine(&svg)
        case .industrial: gooseberry(&svg)
        }
    }

    /// The colour of the ripe fruit in a look: blackberry, the Bronze age's
    /// terracotta, the Iron age's legion red, the Alchemy age's wine, and a
    /// gooseberry's pale green gold.
    static func fruit(_ look: Look) -> String {
        switch look {
        case .stone: "#4a2c48"
        case .bronze: "#c2683c"
        case .iron: "#c8402f"
        case .alchemy: "#7a3a5a"
        case .industrial: "#c9c873"
        }
    }

    // MARK: Stone: a wild bramble

    /// A wild bramble in moss and hide: a ragged mound with canes arching out
    /// of it, and blackberries, ripe and dark or still red, all over its face.
    private static func bramble(_ svg: inout SVG) {
        let lit = Ink.moss, shade = Ink.darkMoss, cane = "#6e4a38"
        shadow(&svg)
        stems(&svg, [[P(-6, 0.6), P(-5, -7)], [P(1, 1), P(0.5, -7)], [P(6.5, 0.4), P(5, -6)]], colour: cane)
        // Canes arching out of the mound, behind it, and down to root again at their tips, with thorns.
        let canes: [[P]] = [[P(-12, -20), P(-25, -27), P(-22, -3)], [P(12, -24), P(26, -30), P(23, -4)]]
        for c in canes {
            let d = "M\(num(c[0].x)),\(num(c[0].y)) Q\(num(c[1].x)),\(num(c[1].y)) \(num(c[2].x)),\(num(c[2].y))"
            svg.path(d, stroke: .colour(cane), width: 1.57)
            svg.path(d, stroke: line, width: 0.61)
            // Thorns pointing back along the cane, outward from its curve.
            for t in [0.45, 0.62, 0.8] {
                let u = 1 - t
                let p = c[0] * (u * u) + c[1] * (2 * u * t) + c[2] * (t * t)
                let out = P(c[2].x < 0 ? -1.4 : 1.4, -0.6)
                svg.line([p, p + out], stroke: line, width: 0.61)
            }
            leaf(&svg, at: c[2] + P(0, -1.5), degrees: c[2].x < 0 ? -40 : 40, length: 4.4, width: 3, colour: lit, veined: true)
        }
        let back = BushMass(centre: P(-4, -27), rx: 15, ry: 12, lobes: 9, bulge: 0.2, phase: 10, ragged: 0.5,
                            lit: lit, shade: shade)
        let front = BushMass(centre: P(2.5, -15.5), rx: 20, ry: 13.5, lobes: 11, bulge: 0.19, phase: 25, ragged: 0.55,
                             lit: lit, shade: shade)
        mass(&svg, back, id: "bramble-back") { svg in
            for (p, a) in [(P(-12, -30), -30.0), (P(-4, -36), 10), (P(4, -31), 40)] {
                leaf(&svg, at: p, degrees: a, length: 4.6, width: 3, colour: shade)
            }
        }
        mass(&svg, front, id: "bramble-front") { svg in
            for (p, a) in [(P(-14, -14), -50.0), (P(-6, -22), -15), (P(8, -21), 30), (P(15, -12), 60), (P(-1, -10), 0)] {
                leaf(&svg, at: p, degrees: a, length: 4.8, width: 3.2, colour: shade)
            }
        }
        // Blackberries: the dark ripe ones each with three pale drupelets, and a few still red.
        let ripe = fruit(.stone), ripeShade = "#2f1d30", red = "#b8434f", redShade = "#8a2e3c"
        let berries: [(P, Bool)] = [(P(-13, -20), true), (P(-7.5, -27.5), true), (P(-1, -33), false), (P(-3, -21), true),
                                    (P(4.5, -26), true), (P(10, -18.5), true), (P(16, -15.5), false), (P(-9.5, -12.5), true),
                                    (P(2.5, -13.5), true), (P(9, -10.5), false), (P(-15.5, -27.5), false)]
        for (p, isRipe) in berries {
            round(&svg, at: p, rx: 2.5, ry: 2.7, colour: isRipe ? ripe : red, shade: isRipe ? ripeShade : redShade,
                  glint: Ink.light)
            if isRipe {
                for d in [P(0.9, -0.2), P(-0.2, 1), P(1, 1.2)] { svg.circle(p + d, 0.38, fill: .colour(Ink.light), opacity: 0.7) }
            }
        }
    }

    // MARK: Bronze: a pomegranate in its basin

    /// A pomegranate shrub in verdigris and terracotta, growing in a basin of
    /// banked earth that holds the water brought to it, with crowned fruit.
    private static func pomegranate(_ svg: inout SVG) {
        let lit = "#5f8f7a", shade = "#2f6b6b", wood = "#7a5236"
        let terracotta = fruit(.bronze), terracottaShade = "#93492c"
        // The basin: a ring of banked sand round darker, watered earth.
        svg.ellipse(P(0.6, 1.6) + register, 23, 7.2, fill: .colour("#c19a58"))
        svg.ellipse(P(0.6, 1.2), 23, 7.2, fill: .none, stroke: line, width: 0.87)
        svg.ellipse(P(0.8, 1.2), 17.5, 4.8, fill: .colour("#8f6e44"))
        svg.ellipse(P(0.8, 1.2), 17.5, 4.8, fill: .none, stroke: line, width: 0.61)
        shadow(&svg, at: P(1.5, 1.2), rx: 14, ry: 3.6)
        // Several thin upright stems.
        stems(&svg, [[P(-5, 1.4), P(-6.5, -9)], [P(-1.4, 1.8), P(-1, -9)], [P(2.4, 1.6), P(3.5, -10)], [P(6, 1), P(8, -8)]],
              colour: wood, width: 1.2)
        let back = BushMass(centre: P(-3, -29), rx: 14, ry: 11.5, lobes: 8, bulge: 0.14, phase: 5, ragged: 0.25,
                            lit: lit, shade: shade)
        let front = BushMass(centre: P(2, -19), rx: 19, ry: 11, lobes: 10, bulge: 0.14, phase: 20, ragged: 0.25,
                             lit: lit, shade: shade)
        let narrow: [(P, Double)] = [(P(-12, -16), -60), (P(-5, -24), -20), (P(6, -23), 25), (P(14, -15), 65), (P(1, -12), 5)]
        mass(&svg, back, id: "pomegranate-back") { svg in
            for (p, a) in [(P(-10, -31), -35.0), (P(-2, -37), 5), (P(6, -32), 40)] {
                leaf(&svg, at: p, degrees: a, length: 5.6, width: 2, colour: shade)
            }
        }
        mass(&svg, front, id: "pomegranate-front") { svg in
            for (p, a) in narrow { leaf(&svg, at: p, degrees: a, length: 5.8, width: 2, colour: shade) }
        }
        // The fruit: round, each with its little crown standing up from it.
        for p in [P(-10.5, -21), P(-1.5, -30), P(7.5, -24.5), P(-3, -15), P(12, -13.5), P(3.5, -11.5)] {
            let crown = [P(-1.6, -2.9), P(-1.4, -4.6), P(-0.5, -3.6), P(0, -5), P(0.5, -3.6), P(1.4, -4.6), P(1.6, -2.9)]
                .map { $0 + p }
            svg.polygon(crown, fill: .colour(terracottaShade), stroke: line, width: 0.52)
            round(&svg, at: p, rx: 3.4, ry: 3.2, colour: terracotta, shade: terracottaShade, glint: Ink.light)
        }
    }

    // MARK: Iron: a cornel cherry, kerbed

    /// A cornelian cherry clipped to a tidy round, in a deeper sea green, with
    /// its red cherries hanging in pairs and dressed stones laid round its foot.
    private static func cornel(_ svg: inout SVG) {
        let lit = "#5e9068", shade = "#3f6a4c", wood = "#6e4c34"
        let red = fruit(.iron), redShade = "#93302a", stone = "#b8b0a0", stoneShade = "#8f887a"
        shadow(&svg)
        stems(&svg, [[P(-3, 1), P(-4, -8)], [P(2.5, 1.2), P(3, -8)]], colour: wood, width: 2)
        let back = BushMass(centre: P(-3, -28), rx: 14.5, ry: 12, lobes: 11, bulge: 0.1, phase: 0, ragged: 0.15,
                            lit: lit, shade: shade)
        let front = BushMass(centre: P(2, -17), rx: 19.5, ry: 12.5, lobes: 13, bulge: 0.1, phase: 15, ragged: 0.15,
                             lit: lit, shade: shade)
        mass(&svg, back, id: "cornel-back") { svg in
            for (p, a) in [(P(-11, -30), -40.0), (P(-3, -36), 0), (P(5, -31), 35)] {
                leaf(&svg, at: p, degrees: a, length: 4.4, width: 3, colour: shade, veined: true)
            }
        }
        mass(&svg, front, id: "cornel-front") { svg in
            for (p, a) in [(P(-14, -15), -55.0), (P(-6, -22), -20), (P(7, -22), 25), (P(15, -14), 60), (P(0, -11), 0)] {
                leaf(&svg, at: p, degrees: a, length: 4.6, width: 3.2, colour: shade, veined: true)
            }
        }
        // Dressed stones round the foot of the bush, in front: low, rounded, lit on top.
        for (c, w) in [(P(-16, 1.4), 5.6), (P(-8, 3.4), 6), (P(1, 4.2), 6), (P(10, 3.4), 6), (P(17.5, 1.2), 5.4)] {
            svg.ellipse(c + register, w / 2, 2.2, fill: .colour(stoneShade))
            svg.ellipse(c + register + P(0, -0.7), w / 2 - 0.4, 1.4, fill: .colour(stone))
            svg.ellipse(c, w / 2, 2.2, fill: .none, stroke: line, width: 0.7)
        }
        // Cherries in pairs, their stalks meeting above them.
        for joint in [P(-11, -26), P(-1, -35.5), P(8, -29), P(-5, -19), P(13, -19), P(3, -15.5), P(-13, -14)] {
            let left = joint + P(-1.9, 4.4), right = joint + P(2, 5)
            stalk(&svg, from: joint, to: left + P(0, -1.6), bend: -0.6)
            stalk(&svg, from: joint, to: right + P(0, -1.6), bend: 0.6)
            round(&svg, at: left, rx: 2.4, colour: red, shade: redShade, glint: Ink.light)
            round(&svg, at: right, rx: 2.4, colour: red, shade: redShade, glint: Ink.light)
        }
    }

    // MARK: Alchemy: a bush vine

    /// A vine trained low as a bush, on a gnarled trunk, in deep teal with a few
    /// leaves already turned gilt, its wine-dark grapes hanging in bunches.
    private static func vine(_ svg: inout SVG) {
        let lit = "#3f6f66", shade = "#2f5a5a", gilt = "#d6b25e", wood = "#6b4a2a"
        let wine = fruit(.alchemy), wineShade = "#552540", bloom = "#b98aa0"
        shadow(&svg)
        // The gnarled trunk, forking into three arms under the leaves.
        let trunk = "M-2.8,1.2 Q-4.2,-4 -1.6,-7.6 Q-3.6,-10 -7,-13 L-5,-14.4 Q-1.6,-11.6 0,-10.4 Q1.4,-12.8 0.6,-15.6 "
            + "L2.8,-15.8 Q3.6,-12 2.4,-9.4 Q5,-11.6 8.2,-12.6 L8.8,-10.6 Q4.6,-9 3,-6 Q2.2,-2.4 3.4,1.2 Z"
        svg.group(at: register) { svg in svg.path(trunk, fill: .colour(wood)) }
        svg.path(trunk, stroke: line, width: 0.87)
        svg.path("M-1,-3 Q0.2,-5 -0.4,-7 M1.6,-1 Q2.4,-3 1.6,-4.6", stroke: line, width: 0.52)
        let back = BushMass(centre: P(-2, -30), rx: 16, ry: 10.5, lobes: 9, bulge: 0.22, phase: 0, ragged: 0.4,
                            lit: lit, shade: shade)
        let front = BushMass(centre: P(2, -22), rx: 19, ry: 9.5, lobes: 10, bulge: 0.22, phase: 18, ragged: 0.4,
                             lit: lit, shade: shade)
        mass(&svg, back, id: "vine-back") { svg in
            for (p, a, c) in [(P(-11, -32), -30.0, shade), (P(-2, -37), 0, gilt), (P(7, -32), 30, shade)] {
                lobedLeaf(&svg, at: p, degrees: a, size: 4.6, colour: c)
            }
        }
        mass(&svg, front, id: "vine-front") { svg in
            for (p, a, c) in [(P(-14, -20), -45.0, shade), (P(-5, -26), -10, shade), (P(6, -25), 20, gilt),
                              (P(15, -19), 50, shade), (P(0, -17), 0, shade)] {
                lobedLeaf(&svg, at: p, degrees: a, size: 4.8, colour: c)
            }
        }
        // A tendril curling out at the top.
        svg.path("M9,-36 Q13,-40 12,-43 Q11,-45 9.6,-43.6", stroke: line, width: 0.61)
        // Bunches of grapes hanging from the leaves: rows of three, three, two and one.
        for top in [P(-11, -22), P(-2, -27.5), P(8.5, -21.5), P(1, -15.5), P(14.5, -15)] {
            svg.line([top + P(0, -2.6), top], stroke: line, width: 0.7)
            let rows: [[Double]] = [[-2.8, 0, 2.8], [-1.4, 1.4, 4.0], [-0.6, 2.2], [0.8]]
            for (r, xs) in rows.enumerated() {
                for x in xs {
                    round(&svg, at: top + P(x - 0.4, 1.6 + Double(r) * 2.5), rx: 1.6, colour: wine, shade: wineShade,
                          glint: bloom)
                }
            }
        }
    }

    // MARK: Industrial: a gooseberry, staked in its bed

    /// A gooseberry bush in bottle green, in a bed of turned soil, tied to a
    /// stake that carries its label, heavy with pale, veined berries.
    private static func gooseberry(_ svg: inout SVG) {
        let lit = "#4a7a5a", shade = "#2f5a46", wood = "#7a5a3a", soot = "#6b6258"
        let berry = fruit(.industrial), berryShade = "#9d9c4f"
        // The bed: dug earth, with clods on it.
        svg.ellipse(P(0.6, 1.8) + register, 22, 6.6, fill: .colour("#7a5a44"))
        svg.ellipse(P(0.6, 1.8), 22, 6.6, fill: .none, stroke: line, width: 0.78)
        for (p, r) in [(P(-15, 2.6), 1.3), (P(-9, 4.6), 1.1), (P(13, 4), 1.2), (P(17.5, 1), 1)] {
            svg.ellipse(p, r * 1.4, r, fill: .colour("#5e4433"))
        }
        shadow(&svg, at: P(1.5, 1.2), rx: 15, ry: 4)
        stems(&svg, [[P(-4.5, 1.2), P(-7, -9)], [P(-0.6, 1.4), P(-1, -9)], [P(3.6, 1.2), P(5.5, -9)]], colour: wood, width: 1.4)
        // The stake, behind the bush, standing clear of its top.
        let stake = [P(9.6, 2), P(10.8, -45), P(12.6, -45), P(11.6, 2)]
        svg.polygon(stake.map { $0 + register }, fill: .colour(wood))
        svg.polygon(stake, fill: .none, stroke: line, width: 0.78)
        let back = BushMass(centre: P(-3, -28), rx: 15, ry: 11.5, lobes: 9, bulge: 0.18, phase: 8, ragged: 0.3,
                            lit: lit, shade: shade)
        let front = BushMass(centre: P(1.5, -18.5), rx: 19.5, ry: 11.5, lobes: 11, bulge: 0.18, phase: 22, ragged: 0.3,
                             lit: lit, shade: shade)
        mass(&svg, back, id: "gooseberry-back") { svg in
            for (p, a) in [(P(-11, -30), -35.0), (P(-3, -36), 0), (P(5, -31), 35)] {
                lobedLeaf(&svg, at: p, degrees: a, size: 4.4, colour: shade, lobes: 3)
            }
        }
        mass(&svg, front, id: "gooseberry-front") { svg in
            for (p, a) in [(P(-14, -15), -50.0), (P(-6, -22), -15), (P(6, -22), 20), (P(15, -14), 55), (P(0, -12), 0)] {
                lobedLeaf(&svg, at: p, degrees: a, size: 4.6, colour: shade, lobes: 3)
            }
        }
        // The twine round the stake, and the label hanging from it.
        svg.line([P(10.4, -40.6), P(13.2, -39.6)], stroke: .colour(soot), width: 0.87)
        svg.line([P(13, -39.8), P(15.2, -36.4)], stroke: .colour(soot), width: 0.52)
        let label = [P(13.4, -37), P(19.4, -35.6), P(18.6, -32), P(12.6, -33.4)]
        svg.polygon(label.map { $0 + register }, fill: .colour(Ink.light))
        svg.polygon(label, fill: .none, stroke: line, width: 0.61)
        svg.line([P(14.2, -35), P(17.8, -34.2)], stroke: .colour(soot), width: 0.43)
        // The berries: oval, pale, each with the lines of its veins.
        for p in [P(-12, -21), P(-5, -29), P(3, -27.5), P(-4, -20), P(6, -19), P(13.5, -16.5), P(-11, -12.5), P(0.5, -12),
                  P(9, -10.5)] {
            svg.line([p + P(0, -2.9), p + P(0.4, -4.4)], stroke: line, width: 0.52)
            round(&svg, at: p, rx: 2.5, ry: 2.9, colour: berry, shade: berryShade, glint: Ink.light)
            svg.path("M\(num(p.x - 1.2)),\(num(p.y - 2.2)) Q\(num(p.x - 1.9)),\(num(p.y)) \(num(p.x - 1.1)),\(num(p.y + 2.2)) "
                     + "M\(num(p.x + 0.9)),\(num(p.y - 2.4)) Q\(num(p.x + 1.6)),\(num(p.y)) \(num(p.x + 0.9)),\(num(p.y + 2.4))",
                     stroke: .colour(berryShade), width: 0.39)
        }
    }
}
