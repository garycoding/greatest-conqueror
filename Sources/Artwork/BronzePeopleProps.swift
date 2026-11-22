// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// What the people of the Bronze age wear and hold: the colours of the age
// (docs/art-style.md, "Palettes") and the things drawn at a hand. Each is drawn
// as the Stone age's props are (Props.swift): its colour a little out of
// register with its outline, along a direction in degrees from straight down,
// positive toward the front.

/// The colours of the Bronze age (sand, terracotta, verdigris and the light),
/// with the shades that cloth, metal, leather and clay need. The line, the skin
/// and the eye are the ones every age shares (`Ink`).
enum BronzePeopleInk {
    static let sand = "#d9b46c"
    static let terracotta = "#c2683c"
    static let verdigris = "#2f6b6b"
    static let light = "#efe0c2"
    static let darkTerracotta = "#8c4426"
    static let paleTerracotta = "#e6ad86"
    static let darkVerdigris = "#1f4848"
    static let paleVerdigris = "#7fb0a4"
    /// Cast bronze, with its light and its shade.
    static let bronze = "#c47f37"
    static let bronzeLight = "#efc77c"
    static let bronzeDark = "#7f4c1d"
    static let gold = "#e4b440"
    static let leather = "#7a4a2a"
    static let wood = "#8a5a33"
    static let handle = "#6b4a2a"
    /// Sun-dried clay: the scribe's tablet.
    static let clay = "#cf9c68"
    /// Dressed stone: the mason's block.
    static let stone = "#d6cab0"
    static let stoneShade = "#b3a68a"
}

/// Geometry the looks share.
enum BronzePeopleKit {
    /// The arm that puts its hand at `target` from `shoulder` (body units), the
    /// elbow bent below the line between them, or above it when `elbowUp`. A
    /// target out of reach is reached toward.
    static func reach(_ shoulder: P, _ target: P, elbowUp: Bool = false) -> Limb {
        let d = target - shoulder
        let length = Joints.upperArm + Joints.forearm
        let distance = min(max((d.x * d.x + d.y * d.y).squareRoot(), 0.5), length - 0.01)
        let towards = atan2(d.x, d.y) * 180 / .pi
        let half = acos(distance / length) * 180 / .pi
        return elbowUp ? Limb(towards + half, -2 * half) : Limb(towards - half, 2 * half)
    }

    /// The front shoulder for a rig, where `reach` starts from.
    static func frontShoulder(_ r: Rig) -> P { P(8, -44 - r.lift) }
    /// The back shoulder for a rig.
    static func backShoulder(_ r: Rig) -> P { P(-7, -44 - r.lift) }

    /// The direction, in the figure's degrees, from `a` to `b`.
    static func degrees(from a: P, to b: P) -> Double {
        let d = b - a
        return atan2(d.x, d.y) * 180 / .pi
    }

    /// The length of `p` from the origin.
    static func length(_ p: P) -> Double { (p.x * p.x + p.y * p.y).squareRoot() }

    /// A value through a cycle of 12 frames: `sin` of the frame's phase, offset by `shift` (0 to 1).
    static func wave(_ frame: Int, _ shift: Double = 0, times: Double = 1) -> Double {
        sin((Double(frame) / 12 + shift) * 2 * .pi * times)
    }
}

/// The props, each drawn into an `SVG` so that the figure and the chariot can both use them.
enum BronzePeopleProps {
    static let ink = Paint.colour(Ink.line)

    /// A closed shape: its colour shifted a little out of register, then its outline.
    static func shape(_ svg: inout SVG, _ points: [P], fill: Paint, width: Double = 1.2, shift: P = P(-0.7, 0.6)) {
        svg.polygon(points.map { $0 + shift }, fill: fill)
        svg.polygon(points, fill: .none, stroke: ink, width: width)
    }

    /// A closed path built by `outline` at an offset: its colour shifted, then its line.
    static func shape(_ svg: inout SVG, fill: Paint, width: Double = 1.3, shift: P = P(-0.7, 0.6),
                      _ outline: (P) -> PathData) {
        svg.path(outline(shift), fill: fill)
        svg.path(outline(P(0, 0)), stroke: ink, width: width)
    }

    /// A rectangle with rounded corners, centred on `c`, turned by `degrees`.
    static func rounded(_ c: P, width w: Double, height h: Double, radius r: Double, degrees: Double, shift: P) -> PathData {
        let corners = [P(-w / 2, -h / 2), P(w / 2, -h / 2), P(w / 2, h / 2), P(-w / 2, h / 2)]
        func at(_ p: P) -> P { c + p.rotated(degrees, about: P(0, 0)) + shift }
        var d = PathData()
        for i in 0..<4 {
            let p = corners[i], next = corners[(i + 1) % 4], previous = corners[(i + 3) % 4]
            let toNext = (next - p) * (r / max(abs(next.x - p.x), abs(next.y - p.y)))
            let toPrevious = (previous - p) * (r / max(abs(previous.x - p.x), abs(previous.y - p.y)))
            if i == 0 { d.move(at(p + toPrevious)) } else { d.line(at(p + toPrevious)) }
            d.quad(at(p), at(p + toNext))
        }
        d.close()
        return d
    }

    // MARK: Tools

    /// A bronze pick on a wooden haft: the haft from the hand along `degrees`,
    /// the head across its far end with its long point on the side `point`
    /// (1 leads a blow that brings the angle down; -1 the other side). Drawn in
    /// profile, then carried by `map` to where a view shows it (`BronzePeopleViews.held`).
    static func pick(_ svg: inout SVG, at hand: P, degrees: Double, haft: Double = 22, point: Double = 1,
                     map: (P) -> P = { $0 }) {
        let u = P.direction(degrees), a = P(-u.y, u.x) * point
        let end = hand + u * haft
        svg.line([hand - u * 4, end + u * 1.2].map(map), stroke: .colour(BronzePeopleInk.handle), width: 2.7)
        svg.line([hand - u * 4 + a * 0.7, end + a * 0.7].map(map), stroke: ink, width: 0.7, opacity: 0.5)
        // The head: a long point curving back toward the hand, a short blunt end, a socket between.
        let head = [end + a * 11.6 - u * 5, end + a * 7.4 - u * 0.6, end + a * 3.6 + u * 1.6, end + a * 0.6 + u * 2.3,
                    end - a * 2.6 + u * 2.2, end - a * 4.8 + u * 1.6, end - a * 5.2 - u * 1.0, end - a * 2.6 - u * 2.1,
                    end + a * 0.8 - u * 2.1, end + a * 4.4 - u * 2.2, end + a * 8.6 - u * 3.4]
        shape(&svg, head.map(map), fill: .colour(BronzePeopleInk.bronze), width: 1.2)
        svg.line([end + a * 10 - u * 3.6, end + a * 6.4 + u * 0.2, end + a * 2.6 + u * 1.6].map(map), stroke: .colour(BronzePeopleInk.bronzeLight),
                 width: 0.8)
    }

    /// The far tip of a pick drawn by `pick` with the same arguments: where its blow lands.
    static func pickPoint(at hand: P, degrees: Double, haft: Double = 22, point: Double = 1) -> P {
        let u = P.direction(degrees), a = P(-u.y, u.x) * point
        return hand + u * haft + a * 11.6 - u * 5
    }

    /// A mason's hammer: a wooden haft and a bronze head, its face leading a
    /// blow that brings the angle down. Drawn in profile, then carried by `map`
    /// to where a view shows it.
    static func hammer(_ svg: inout SVG, at hand: P, degrees: Double, haft: Double = 12, map: (P) -> P = { $0 }) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let head = hand + u * haft
        svg.line([hand - u * 2.6, head + u * 1.4].map(map), stroke: .colour(BronzePeopleInk.handle), width: 2.4)
        let corners = [head + a * 5.2 + u * 2.4, head - a * 3.4 + u * 1.9, head - a * 3.4 - u * 1.9, head + a * 5.2 - u * 2.4]
        shape(&svg, corners.map(map), fill: .colour(BronzePeopleInk.bronze))
        svg.line([head + a * 4.6 + u * 1.5, head - a * 2.6 + u * 1.2].map(map), stroke: .colour(BronzePeopleInk.bronzeLight), width: 0.8)
        svg.line([head - a * 0.6 + u * 2, head - a * 0.6 - u * 2].map(map), stroke: ink, width: 0.9)
    }

    /// The face of a hammer drawn by `hammer` with the same arguments.
    static func hammerFace(at hand: P, degrees: Double, haft: Double = 12) -> P {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        return hand + u * haft + a * 5.2
    }

    /// A bronze chisel, `length` long from `butt` along `degrees`.
    static func chisel(_ svg: inout SVG, from butt: P, degrees: Double, length: Double = 7) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let tip = butt + u * length
        shape(&svg, [butt + a * 0.9, tip + a * 0.6, tip - a * 0.6, butt - a * 0.9], fill: .colour(BronzePeopleInk.bronze), width: 0.9)
    }

    /// A block of dressed stone on the ground, its front face from `left` to
    /// `left + width` and `height` high, with its top seen from above.
    static func block(_ svg: inout SVG, left: Double, width: Double, height: Double) {
        let depth = 3.4
        let front = [P(left, 0), P(left + width, 0), P(left + width, -height), P(left, -height)]
        let top = [P(left, -height), P(left + width, -height), P(left + width + depth, -height - depth), P(left + depth, -height - depth)]
        let side = [P(left + width, 0), P(left + width + depth, -depth), P(left + width + depth, -height - depth), P(left + width, -height)]
        svg.ellipse(P(left + width / 2 + 1.5, 0.4), width / 2 + 4, 2.6, fill: .colour("#000000"), opacity: 0.13)
        svg.polygon(front.map { $0 + P(-0.7, 0.6) }, fill: .colour(BronzePeopleInk.stone))
        svg.polygon(side.map { $0 + P(-0.7, 0.6) }, fill: .colour(BronzePeopleInk.stoneShade))
        svg.polygon(top.map { $0 + P(-0.7, 0.6) }, fill: .colour(BronzePeopleInk.light))
        for outline in [front, top, side] { svg.polygon(outline, fill: .none, stroke: ink, width: 1.3) }
        // The marks of the chisel on its face.
        var marks = PathData()
        for (x, y) in [(0.22, 0.3), (0.5, 0.55), (0.74, 0.28), (0.3, 0.78)] {
            let p = P(left + width * x, -height * y)
            marks.move(p); marks.line(p + P(1.6, 1.2))
        }
        svg.path(marks, stroke: ink, width: 0.8, opacity: 0.6)
    }

    // MARK: Writing and trade

    /// A clay tablet centred on `c` and turned by `degrees`, with rows of wedges pressed into it.
    static func tablet(_ svg: inout SVG, at c: P, degrees: Double) {
        svg.path(rounded(c, width: 8.6, height: 10.6, radius: 1.8, degrees: degrees, shift: P(-0.6, 0.6)),
                 fill: .colour(BronzePeopleInk.clay))
        svg.path(rounded(c, width: 8.6, height: 10.6, radius: 1.8, degrees: degrees, shift: P(0, 0)), stroke: ink, width: 1.1)
        var wedges = PathData()
        for row in 0..<4 {
            let y = -3.2 + Double(row) * 2.2
            for column in 0..<(row == 3 ? 2 : 3) {
                let p = P(-2.6 + Double(column) * 2.3, y)
                wedges.move(c + p.rotated(degrees, about: P(0, 0)))
                wedges.line(c + (p + P(1.3, 0.5)).rotated(degrees, about: P(0, 0)))
            }
        }
        svg.path(wedges, stroke: ink, width: 0.8, opacity: 0.75)
    }

    /// A reed stylus held at `hand`, its point `length` along `degrees`.
    static func stylus(_ svg: inout SVG, at hand: P, degrees: Double, length: Double = 8) {
        let u = P.direction(degrees)
        svg.line([hand - u * 2.5, hand + u * length], stroke: .colour(BronzePeopleInk.light), width: 1.6)
        svg.line([hand - u * 2.5, hand + u * length], stroke: ink, width: 0.5, opacity: 0.8)
        svg.line([hand + u * (length - 1.4), hand + u * length], stroke: ink, width: 1.1)
    }

    /// A hand balance hanging from `hand`, its beam turned by `tilt` degrees
    /// (positive lowers the front pan): gold rings in the back pan, a bronze
    /// ingot in the front one. The beam is drawn in profile, then carried by
    /// `map` to where a view shows it; the pans hang plumb from its ends.
    static func balance(_ svg: inout SVG, from hand: P, tilt: Double, map: (P) -> P = { $0 }) {
        let r = tilt * .pi / 180, along = P(cos(r), sin(r))
        let back = map(hand + P(0, 3.4) - along * 7.6), front = map(hand + P(0, 3.4) + along * 7.6)
        let pivot = map(hand + P(0, 3.4)), hand = map(hand)
        svg.line([hand, pivot], stroke: ink, width: 0.8)
        for end in [back, front] {
            let pan = end + P(0, 7.2)
            svg.line([end, pan + P(-3, 0)], stroke: ink, width: 0.7)
            svg.line([end, pan + P(3, 0)], stroke: ink, width: 0.7)
            var bowl = PathData()
            bowl.move(pan + P(-3.4, 0)); bowl.quad(pan + P(0, 3.8), pan + P(3.4, 0)); bowl.close()
            svg.path(bowl, fill: .colour(BronzePeopleInk.bronze), stroke: ink, width: 0.9)
        }
        svg.line([back, front], stroke: .colour(BronzePeopleInk.wood), width: 1.8)
        svg.line([back, front], stroke: ink, width: 0.6, opacity: 0.6)
        svg.circle(pivot, 0.9, fill: .colour(BronzePeopleInk.bronze), stroke: ink, width: 0.6)
        // What is weighed.
        let rings = back + P(0, 6.2)
        for dx in [-1.4, 1.2] { svg.circle(rings + P(dx, -0.4), 1.2, fill: .none, stroke: .colour(BronzePeopleInk.gold), width: 0.9) }
        let ingot = front + P(0, 6)
        svg.path("M\(num(ingot.x - 2.4)),\(num(ingot.y - 1.6)) l1.4,0.6 h2 l1.4,-0.6 l-0.5,1.6 l0.5,1.6 l-1.4,-0.6 h-2 l-1.4,0.6 l0.5,-1.6 Z",
                 fill: .colour(BronzePeopleInk.bronzeDark), stroke: ink, width: 0.6)
    }

    /// A bale of goods centred on `c`, wrapped in cloth of the team's colour
    /// patterned in the light and roped across.
    static func bale(_ svg: inout SVG, at c: P, width: Double, height: Double, degrees: Double) {
        svg.path(rounded(c, width: width, height: height, radius: 4.5, degrees: degrees, shift: P(-0.8, 0.7)), fill: .team)
        // A pattern of diamonds woven into the cloth.
        var pattern = PathData()
        for row in stride(from: -height / 2 + 4.5, through: height / 2 - 3.5, by: 6.0) {
            for column in stride(from: -width / 2 + 4, through: width / 2 - 3, by: 6.0) {
                let p = P(column, row)
                let points = [p + P(0, -2), p + P(2, 0), p + P(0, 2), p + P(-2, 0)]
                for (i, q) in points.enumerated() {
                    let at = c + q.rotated(degrees, about: P(0, 0))
                    if i == 0 { pattern.move(at) } else { pattern.line(at) }
                }
                pattern.close()
            }
        }
        svg.path(pattern, stroke: .colour(BronzePeopleInk.light), width: 0.9)
        svg.path(rounded(c, width: width, height: height, radius: 4.5, degrees: degrees, shift: P(0, 0)), stroke: ink, width: 1.4)
        // The rope: twice round the bale and once along it.
        func turn(_ p: P) -> P { c + p.rotated(degrees, about: P(0, 0)) }
        for x in [-width * 0.22, width * 0.24] {
            svg.line([turn(P(x, -height / 2 - 0.4)), turn(P(x + 0.8, height / 2 + 0.4))], stroke: .colour(BronzePeopleInk.leather), width: 1.6)
        }
        svg.line([turn(P(-width / 2 - 0.3, 0.6)), turn(P(width / 2 + 0.3, -0.2))], stroke: .colour(BronzePeopleInk.leather), width: 1.6)
        svg.circle(turn(P(width * 0.24, 0)), 1.3, fill: .colour(BronzePeopleInk.leather), stroke: ink, width: 0.7)
    }

    // MARK: Marks

    /// Bits of rock and green copper ore flying from a blow at `p`, `spread` from 0 (struck) to 1 (flying apart).
    static func oreChips(_ svg: inout SVG, at p: P, spread: Double) {
        let bits: [(P, Double, String)] = [(P(5, -6), 1.5, BronzePeopleInk.paleVerdigris), (P(-2.6, -8.4), 1.2, BronzePeopleInk.stone),
                                           (P(8.6, -1.4), 1.1, BronzePeopleInk.verdigris), (P(1.4, -10.6), 0.9, BronzePeopleInk.paleVerdigris)]
        let k = 0.55 + spread * 0.8
        for (offset, size, colour) in bits {
            let c = p + offset * k
            svg.polygon([c + P(0, -size), c + P(size, 0), c + P(0, size * 0.8), c + P(-size, 0)], fill: .colour(colour),
                        stroke: ink, width: 0.6)
        }
        var lines = PathData()
        for offset in [P(5, -6), P(8.6, -1.4), P(-2.6, -8.4)] {
            lines.move(p + offset * (0.25 + spread * 0.3)); lines.line(p + offset * (0.45 + spread * 0.55))
        }
        svg.path(lines, stroke: ink, width: 1, opacity: 0.8)
    }

    /// A small cloud of dust kicked up at `p`.
    static func dust(_ svg: inout SVG, at p: P, size: Double, opacity: Double = 0.55) {
        for (offset, r) in [(P(-2.4, -0.6), 2.0), (P(0.6, -1.6), 2.5), (P(3.2, -0.4), 1.8)] {
            svg.circle(p + offset * size, r * size, fill: .colour(BronzePeopleInk.light), stroke: ink, width: 0.6, opacity: opacity)
        }
    }
}
