// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The beasts about the older buildings in their Alchemy-age look: an ox and
// sheep in the stock pen, and horses looking out of the stable, drawn as the
// Iron age's pen and stable draw them, so that the beasts stay the same from
// one age to the next.

/// The colours of the beasts' coats.
private enum AlchemyOldBuildingsAnimal {
    static let hide = "#b9623a"
    static let horse = "#a9643a"
    static let horseShade = "#7c4528"
}

extension AlchemyOldBuildingsPainter {
    /// An ox standing at `p` on the screen, facing right: the approved scene's ox, small.
    mutating func ox(at p: P) {
        typealias I = AlchemyOldBuildingsInk
        svg.ellipse(p + P(0, 0.6), 12, 3, fill: .colour("#000000"), opacity: 0.14)
        // The legs, then the body over them.
        for x in [-8.2, -5, 5.2, 8.4] {
            line([p + P(x, -6), p + P(x, -0.2), p + P(x + 1.4, -0.2)], width: 1)
        }
        let body = [p + P(-11, -14), p + P(9, -14), p + P(10.6, -12.4), p + P(10.6, -7.4), p + P(9, -5.8), p + P(-11, -5.8),
                    p + P(-12.6, -7.4), p + P(-12.6, -12.4)]
        shape(body, .colour(AlchemyOldBuildingsAnimal.hide), width: 1)
        // A tail, and the pattern on the hide.
        line([p + P(-12.4, -12), p + P(-14.4, -9), p + P(-14, -5)], width: 0.8)
        line(width: 0.6) { d in
            d.move(p + P(-6, -10.6)); d.quad(p + P(-3, -13.4), p + P(0, -10.6)); d.quad(p + P(-3, -8), p + P(-6, -10.6))
            d.move(p + P(2.4, -9.6)); d.quad(p + P(4.4, -11.4), p + P(6.4, -9.6))
        }
        // The head, its horns, and an eye.
        let head = [p + P(9, -15.6), p + P(15.6, -18), p + P(17.4, -12), p + P(12.4, -9.8)]
        shape(head, .colour(AlchemyOldBuildingsAnimal.hide), width: 1)
        line(width: 0.9) { d in
            d.move(p + P(12.4, -16.8)); d.quad(p + P(10.6, -21.4), p + P(14.6, -22.8))
            d.move(p + P(14.6, -17.4)); d.quad(p + P(17.4, -20.6), p + P(20.6, -19.4))
        }
        svg.circle(p + P(14.6, -14.6), 0.7, fill: .colour(I.line))
    }

    /// A sheep standing at `p` on the screen, facing right (1) or left (-1).
    mutating func sheep(at p: P, facing f: Double) {
        typealias I = AlchemyOldBuildingsInk
        svg.ellipse(p + P(0, 0.5), 7, 2, fill: .colour("#000000"), opacity: 0.14)
        for x in [-3.6, -1.6, 2, 4] { line([p + P(x * f, -3.4), p + P(x * f, 0)], width: 0.9) }
        // The fleece: a body of scallops.
        func fleece(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-6, -4) + o)
            d.quad(p + P(-8.2, -7) + o, p + P(-5.4, -9.4) + o)
            d.quad(p + P(-3, -12) + o, p + P(0, -10.2) + o)
            d.quad(p + P(3, -12) + o, p + P(5.4, -9.4) + o)
            d.quad(p + P(8.2, -7) + o, p + P(6, -4) + o)
            d.quad(p + P(0, -1.6) + o, p + P(-6, -4) + o)
            d.close()
            return d
        }
        colour(.colour(I.light)) { d, o in d = fleece(o) }
        line(width: 0.9) { d in d = fleece(P(0, 0)) }
        let head = p + P(6.8 * f, -9)
        svg.ellipse(head, 2.4, 1.9, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.6)
        line([head + P(-0.6 * f, -1.4), head + P(-2.2 * f, -0.4)], width: 0.8)
        svg.circle(head + P(0.9 * f, -0.4), 0.45, fill: .colour(I.light))
    }

    /// A horse's head and neck reaching out over a stall's door from `q` on
    /// the screen, facing left (-1) or right (1): a chestnut coat with a white
    /// blaze, a dark mane, pricked ears, an eye and a nostril, and a halter.
    mutating func horseHead(at q: P, facing f: Double) {
        typealias I = AlchemyOldBuildingsInk
        let s = 0.86
        func at(_ x: Double, _ y: Double) -> P { q + P(x * f * s, y * s) }
        // The far ear, then the neck, the head, the near ear.
        shape([at(0.4, -14.4), at(-0.2, -18.6), at(2, -15)], .colour(AlchemyOldBuildingsAnimal.horseShade), width: 0.7)
        func neck(_ o: P) -> PathData {
            var d = PathData()
            d.move(at(-3.6, 1) + o)
            d.quad(at(-4, -8) + o, at(-1.4, -13) + o)
            d.line(at(3.4, -9) + o)
            d.quad(at(3, -3) + o, at(4, 1) + o)
            d.close()
            return d
        }
        colour(.colour(AlchemyOldBuildingsAnimal.horse)) { d, o in d = neck(o) }
        line(width: 0.9) { d in d = neck(P(0, 0)) }
        func head(_ o: P) -> PathData {
            var d = PathData()
            d.move(at(-1.4, -13) + o)
            d.quad(at(1.6, -16.2) + o, at(5, -13.6) + o)
            d.line(at(11.6, -7.2) + o)
            d.quad(at(13, -4.6) + o, at(10.6, -3.6) + o)
            d.quad(at(8, -3) + o, at(6.4, -4.4) + o)
            d.quad(at(3, -5.2) + o, at(1.6, -8.4) + o)
            d.close()
            return d
        }
        colour(.colour(AlchemyOldBuildingsAnimal.horse)) { d, o in d = head(o) }
        // The blaze down the face.
        colour(.colour(I.light)) { d, o in
            d.move(at(3.6, -14) + o)
            d.line(at(5.2, -13.2) + o)
            d.line(at(11, -7) + o)
            d.line(at(10, -6.4) + o)
            d.close()
        }
        line(width: 0.9) { d in d = head(P(0, 0)) }
        // The mane along the neck's crest, and a forelock.
        colour(.colour(I.dark)) { d, o in
            d.move(at(-1.4, -13.4) + o)
            d.quad(at(-4.8, -8.6) + o, at(-4.4, 0.6) + o)
            d.line(at(-6.2, -2.4) + o)
            d.line(at(-5.6, -5.6) + o)
            d.line(at(-6.6, -8) + o)
            d.line(at(-4.6, -11) + o)
            d.line(at(-3.8, -14.4) + o)
            d.close()
        }
        line([at(1.2, -15), at(3.4, -12.6), at(2.2, -12)], width: 0.6)
        shape([at(1.6, -14.6), at(1.8, -19), at(3.8, -15.2)], .colour(AlchemyOldBuildingsAnimal.horse), width: 0.7)
        // The halter of rope, the eye, the nostril and the mouth.
        line([at(2.6, -12.2), at(1.8, -7.8)], width: 0.7)
        line([at(1.8, -9.6), at(9.4, -6.4)], width: 0.7)
        svg.ellipse(at(3.4, -11.4), 1.1 * s, 0.9 * s, fill: .colour(I.light), stroke: .colour(I.line), width: 0.5)
        svg.circle(at(3.7, -11.3), 0.5 * s, fill: .colour(I.line))
        svg.circle(at(11.2, -5.4), 0.5 * s, fill: .colour(I.line))
        line([at(9.6, -3.8), at(11.2, -4)], width: 0.5)
    }
}
