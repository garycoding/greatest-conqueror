// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// What the peaceful people of the Iron age wear and hold: the colours of the
// age (docs/art-style.md, "Palettes") and the things drawn at a hand. Each is
// drawn as the Bronze age's props are (BronzePeopleProps.swift): its colour a
// little out of register with its outline, along a direction in degrees from
// straight down, positive toward the front.

/// The colours of the Iron age (sea green, iron grey, legion red and the
/// light), with the shades that cloth, iron, wood, straw and earth need. The
/// line, the skin and the eye are the ones every age shares (`Ink`).
enum IronPeopleInk {
    static let sea = "#6fa39a"
    static let grey = "#b8b0a0"
    static let red = "#c8402f"
    static let light = "#efe0c2"
    static let darkSea = "#3f6e66"
    static let deepSea = "#2c514b"
    static let paleSea = "#a9cdc4"
    static let darkGrey = "#857d6f"
    static let paleGrey = "#dcd6ca"
    static let darkRed = "#8c2a1f"
    static let paleRed = "#e3907c"
    /// Wrought iron, with its light and its shade.
    static let iron = "#6f7275"
    static let ironDark = "#45474a"
    static let ironLight = "#c9ccce"
    static let wood = "#8a5a33"
    static let handle = "#6b4a2a"
    static let leather = "#7a4a2a"
    static let darkLeather = "#55321b"
    static let paleLeather = "#b07a50"
    static let straw = "#dcc27e"
    static let darkStraw = "#a8873f"
    /// Ripe ears of grain.
    static let grain = "#e2b64c"
    static let earth = "#6e4c30"
    static let darkEarth = "#4b321e"
    static let hemp = "#d2bd8c"
    static let darkHemp = "#9c8456"
    static let gold = "#e4b440"
    static let timber = "#a57443"
    static let darkTimber = "#76512c"
    static let paleTimber = "#c99a66"
    static let hair = "#5a3a24"
}

/// The props, each drawn into an `SVG`.
enum IronPeopleProps {
    static let ink = Paint.colour(Ink.line)

    /// A point `along` the direction `u` and `side` across it (along `a`) from `origin`.
    static func at(_ origin: P, _ u: P, _ a: P, _ along: Double, _ side: Double) -> P { origin + u * along + a * side }

    // MARK: The farmer's

    /// An iron hoe: a wooden haft running `length` from its blade end `end`
    /// along the unit direction `toward`, and the blade at `end` reaching along
    /// the unit direction `side`, leaning back a little toward the haft, as a
    /// hoe's blade does, and widening to its edge.
    static func hoe(_ svg: inout SVG, end: P, toward u: P, length: Double, side: P) {
        svg.line([end - u * 1.2, end + u * length], stroke: .colour(IronPeopleInk.handle), width: 2.6)
        svg.line([end + side * 0.7, end + u * length + side * 0.7], stroke: ink, width: 0.7, opacity: 0.5)
        let a = hoeBlade(toward: u, side: side), w = P(-a.y, a.x)
        // The socket round the haft's end and the neck that carries the blade.
        svg.line([end - w * 1.6, end + w * 1.6], stroke: ink, width: 3.2)
        svg.line([end - w * 1.2, end + w * 1.2], stroke: .colour(IronPeopleInk.iron), width: 1.6)
        svg.line([end, end + a * 3.2], stroke: ink, width: 2.8)
        svg.line([end, end + a * 3.2], stroke: .colour(IronPeopleInk.iron), width: 1.2)
        // The blade: a broad plate, a little wider at its edge.
        let outline = [end + a * 2.8 + w * 3, end + a * 2.8 - w * 3, end + a * 10.6 - w * 3.6, end + a * 10.6 + w * 3.6]
        BronzePeopleProps.shape(&svg, outline, fill: .colour(IronPeopleInk.iron), width: 1.2)
        svg.line([end - w * 2.9 + a * 9.6, end + w * 2.9 + a * 9.6], stroke: .colour(IronPeopleInk.ironLight), width: 0.9)
    }

    /// The blade's direction: `side`, leaning 20 degrees back toward the haft.
    static func hoeBlade(toward u: P, side: P) -> P { side * 0.94 + u * 0.34 }

    /// The middle of the edge of a hoe drawn by `hoe` with the same arguments: where it bites.
    static func hoeEdge(end: P, toward u: P, side: P) -> P { end + hoeBlade(toward: u, side: side) * 10 }

    /// An iron sickle: a short wooden handle from `hand` along `degrees`, and a
    /// crescent blade curving from its end toward the side `point`.
    static func sickle(_ svg: inout SVG, at hand: P, degrees: Double, point: Double = 1, size: Double = 1) {
        let u = P.direction(degrees) * size, a = P(-u.y, u.x) * point
        svg.line([hand - u * 2.4, hand + u * 4.2], stroke: .colour(IronPeopleInk.handle), width: 2.4)
        let base = hand + u * 4
        func blade(_ o: P) -> PathData {
            var p = PathData()
            p.move(at(base, u, a, 0, -0.9) + o)
            p.cubic(at(base, u, a, 7.4, -2.8) + o, at(base, u, a, 13.6, 2.6) + o, at(base, u, a, 9.6, 9.4) + o)
            p.cubic(at(base, u, a, 10.2, 4.2) + o, at(base, u, a, 6, 1) + o, at(base, u, a, 0, 1) + o)
            p.close()
            return p
        }
        svg.path(blade(P(-0.6, 0.5)), fill: .colour(IronPeopleInk.iron))
        svg.path(blade(P(0, 0)), stroke: ink, width: 1)
        var edge = PathData()
        edge.move(at(base, u, a, 1, 0.6)); edge.cubic(at(base, u, a, 6.4, 1.2), at(base, u, a, 9.6, 4), at(base, u, a, 9.4, 7.6))
        svg.path(edge, stroke: .colour(IronPeopleInk.ironLight), width: 0.7)
    }

    /// A wicker basket heaped with ears of grain, its rim's middle at `rim`,
    /// `width` across the rim and `height` deep, with a handle arching over it.
    /// `stir` moves the ears a little (from -1 to 1).
    static func basket(_ svg: inout SVG, rim: P, width w: Double, height h: Double, handle: Bool = true, stir: Double = 0) {
        let left = rim + P(-w / 2, 0), right = rim + P(w / 2, 0)
        let bottomLeft = rim + P(-w * 0.38, h), bottomRight = rim + P(w * 0.38, h)
        // The handle, behind the grain.
        if handle {
            var arch = PathData()
            arch.move(left + P(1.4, 0)); arch.cubic(left + P(1, -h * 1.15), right + P(-1, -h * 1.15), right + P(-1.4, 0))
            svg.path(arch, stroke: ink, width: 2.6)
            svg.path(arch, stroke: .colour(IronPeopleInk.straw), width: 1.3)
        }
        // The ears of grain heaped above the rim, each on its stalk.
        let ears: [(Double, Double, Double)] = [(-0.34, -14, 5.8), (-0.12, -4, 7), (0.1, 6, 6.6), (0.3, 16, 5.6), (0.0, 0, 4.4)]
        for (fx, lean, length) in ears {
            let foot = rim + P(w * fx, 0.4)
            let u = P.direction(180 + lean + stir * 4)
            let tip = foot + u * length
            svg.line([foot, tip], stroke: .colour(IronPeopleInk.darkStraw), width: 0.8)
            svg.group(at: tip - u * 1.8, turned: -(180 + lean + stir * 4)) { svg in
                svg.ellipse(P(-0.4, 0.3), 1.5, 3.2, fill: .colour(IronPeopleInk.grain))
                svg.ellipse(P(0, 0), 1.5, 3.2, fill: .none, stroke: ink, width: 0.8)
                svg.path("M0,-2.2 l-1.6,-1.8 M0,0 l1.6,-1.8", stroke: ink, width: 0.5, opacity: 0.8)
            }
        }
        // The heap at the rim.
        var heap = PathData()
        heap.move(left + P(0.6, 0.2)); heap.quad(rim + P(0, -4.6), right + P(-0.6, 0.2)); heap.close()
        svg.path(heap, fill: .colour(IronPeopleInk.grain), stroke: ink, width: 0.9)
        // The body, woven in rows.
        func body(_ o: P) -> PathData {
            var p = PathData()
            p.move(left + o); p.line(right + o)
            p.quad(rim + P(w * 0.47, h * 0.8) + o, bottomRight + o)
            p.quad(rim + P(0, h + 1.4) + o, bottomLeft + o)
            p.quad(rim + P(-w * 0.47, h * 0.8) + o, left + o)
            p.close()
            return p
        }
        svg.path(body(P(-0.7, 0.6)), fill: .colour(IronPeopleInk.straw))
        var weave = PathData()
        let rows = max(2, Int(h / 2.6))
        for row in 1..<rows {
            let t = Double(row) / Double(rows)
            let half = w / 2 * (1 - 0.24 * t) - 0.8
            let y = rim.y + h * t
            var x = rim.x - half
            var up = row % 2 == 0
            weave.move(P(x, y))
            while x + 2.2 <= rim.x + half {
                weave.quad(P(x + 1.1, y + (up ? -0.9 : 0.9)), P(x + 2.2, y))
                x += 2.2; up.toggle()
            }
        }
        svg.path(weave, stroke: .colour(IronPeopleInk.darkStraw), width: 0.8)
        svg.path(body(P(0, 0)), stroke: ink, width: 1.3)
        // The rim, a thicker band.
        svg.line([left + P(-0.2, 0.4), right + P(0.2, 0.4)], stroke: ink, width: 2.6)
        svg.line([left + P(0.2, 0.4), right + P(-0.2, 0.4)], stroke: .colour(IronPeopleInk.straw), width: 1.2)
    }

    /// Earth turned by the hoe: a low ridge of dark soil on the ground from
    /// `x0` to `x1`, rising to `height` at `peak`.
    static func soil(_ svg: inout SVG, from x0: Double, to x1: Double, peak: Double, height: Double) {
        var p = PathData()
        p.move(P(x0, 0.6))
        p.cubic(P(x0 + (peak - x0) * 0.5, 0.4), P(peak - 3, -height), P(peak, -height))
        p.cubic(P(peak + 2.4, -height), P(x1 - (x1 - peak) * 0.4, 0.2), P(x1, 0.6))
        p.close()
        svg.path(p, fill: .colour(IronPeopleInk.earth), stroke: ink, width: 1.1)
        // Crumbs of earth on the ridge, and the furrow behind it.
        for (dx, dy, r) in [(-4.2, -0.9, 0.9), (-1.6, -height * 0.7, 0.8), (2.4, -height * 0.5, 0.9), (5, -0.6, 0.7)] {
            svg.circle(P(peak + dx, min(dy, -0.2)), r, fill: .colour(IronPeopleInk.darkEarth))
        }
        svg.path("M\(num(x0 - 4)),0.9 q\(num((x1 - x0) * 0.5 + 4)),1.6 \(num(x1 - x0 + 8)),0", stroke: .colour(IronPeopleInk.darkEarth), width: 1)
    }

    /// Clods of earth flying from a blow at `p`, `spread` from 0 (struck) to 1 (flying apart).
    static func clods(_ svg: inout SVG, at p: P, spread: Double) {
        let bits: [(P, Double)] = [(P(-7, -6), 1.6), (P(-2.6, -9.6), 1.2), (P(4.6, -7.4), 1.4), (P(8, -2.4), 1), (P(-9.4, -1.6), 1)]
        let k = 0.55 + spread * 0.8
        for (offset, size) in bits {
            let c = p + offset * k + P(0, spread * spread * 2)
            svg.polygon([c + P(-size, -size * 0.4), c + P(size * 0.2, -size), c + P(size, size * 0.2), c + P(-size * 0.3, size * 0.9)],
                        fill: .colour(IronPeopleInk.earth), stroke: ink, width: 0.6)
        }
        var lines = PathData()
        for offset in [P(-7, -6), P(4.6, -7.4), P(-2.6, -9.6)] {
            lines.move(p + offset * (0.25 + spread * 0.3)); lines.line(p + offset * (0.45 + spread * 0.5))
        }
        svg.path(lines, stroke: ink, width: 1, opacity: 0.8)
    }

    // MARK: The philosopher's

    /// A rolled scroll of papyrus centred on `c` and turned by `degrees` (0 lies
    /// across, ends to the left and right), its rod's knobs at both ends and a
    /// red tie round its middle.
    static func scroll(_ svg: inout SVG, at c: P, degrees: Double, length: Double = 12) {
        svg.group(at: c, turned: degrees) { svg in
            let h = length / 2
            for x in [-h - 1.2, h + 1.2] {
                svg.ellipse(P(x, 0), 1.3, 1.1, fill: .colour(IronPeopleInk.darkTimber), stroke: ink, width: 0.7)
            }
            svg.path(BronzePeopleProps.rounded(P(0, 0), width: length, height: 3.8, radius: 1.6, degrees: 0, shift: P(-0.5, 0.5)),
                     fill: .colour(IronPeopleInk.light))
            svg.path(BronzePeopleProps.rounded(P(0, 0), width: length, height: 3.8, radius: 1.6, degrees: 0, shift: P(0, 0)),
                     stroke: ink, width: 1)
            // The edge of the sheet wound round it.
            svg.path("M\(num(h - 2.4)),-1.9 q-1.2,1.9 0,3.8", stroke: ink, width: 0.6, opacity: 0.7)
            svg.line([P(-0.9, -2.1), P(-0.9, 2.1)], stroke: .colour(IronPeopleInk.red), width: 1.5)
            svg.line([P(0.7, -2.1), P(0.7, 2.1)], stroke: .colour(IronPeopleInk.red), width: 1.5)
        }
    }

    // MARK: The engineer's

    /// A smith's iron hammer: a wooden haft from the hand along `degrees`, and
    /// a heavy iron head across its end, its broad face leading a blow that
    /// brings the angle down and a wedge-shaped peen behind.
    static func hammer(_ svg: inout SVG, at hand: P, degrees: Double, haft: Double = 14) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let head = hand + u * haft
        svg.line([hand - u * 2.8, head + u * 1.6], stroke: .colour(IronPeopleInk.handle), width: 2.5)
        svg.line([hand - u * 2.8 + a * 0.7, head + a * 0.7], stroke: ink, width: 0.6, opacity: 0.5)
        let corners = [at(head, u, a, 2.9, 6.2), at(head, u, a, 2.6, 1.4), at(head, u, a, 1.6, -4.6), at(head, u, a, 0, -5.6),
                       at(head, u, a, -1.6, -4.6), at(head, u, a, -2.6, 1.4), at(head, u, a, -2.9, 6.2)]
        BronzePeopleProps.shape(&svg, corners, fill: .colour(IronPeopleInk.iron), width: 1.2)
        svg.line([at(head, u, a, 1.9, 5.6), at(head, u, a, 1.9, 0)], stroke: .colour(IronPeopleInk.ironLight), width: 0.9)
        svg.line([at(head, u, a, 2.9, 4.6), at(head, u, a, -2.9, 4.6)], stroke: ink, width: 0.7, opacity: 0.7)
    }

    /// The face of a hammer drawn by `hammer` with the same arguments.
    static func hammerFace(at hand: P, degrees: Double, haft: Double = 14) -> P {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        return hand + u * haft + a * 6.3
    }

    /// A measuring rod from `from` to `to`, painted in bands of red and the light.
    static func rod(_ svg: inout SVG, from: P, to: P, width: Double = 2.4) {
        svg.line([from, to], stroke: ink, width: width + 1.2)
        let length = BronzePeopleKit.length(to - from)
        let bands = max(2, Int(length / 3.4))
        for i in 0..<bands {
            let s = from + (to - from) * (Double(i) / Double(bands)), e = from + (to - from) * (Double(i + 1) / Double(bands))
            svg.line([s, e], stroke: .colour(i % 2 == 0 ? IronPeopleInk.light : IronPeopleInk.red), width: width)
        }
    }

    /// A rope along `points`, its strands twisted.
    static func rope(_ svg: inout SVG, _ points: [P], width: Double = 2.6) {
        var d = PathData()
        d.move(points[0])
        for p in points.dropFirst() { d.line(p) }
        svg.path(d, stroke: ink, width: width + 1.3)
        svg.path(d, stroke: .colour(IronPeopleInk.hemp), width: width)
        // The twist: short slanting strokes along it.
        var twist = PathData()
        for (a, b) in zip(points, points.dropFirst()) {
            let along = b - a
            let length = BronzePeopleKit.length(along)
            guard length > 0.1 else { continue }
            let u = along * (1 / length), n = P(-u.y, u.x)
            var s = 1.0
            while s < length - 0.6 {
                let c = a + u * s
                twist.move(c + n * (width * 0.42) - u * 0.6); twist.line(c - n * (width * 0.42) + u * 0.6)
                s += 2
            }
        }
        svg.path(twist, stroke: .colour(IronPeopleInk.darkHemp), width: 0.6)
    }

    /// A coil of rope seen from the side, centred on `c`: two loops `rx` by
    /// `ry`, turned by `degrees`, bound at the top, with its end hanging free.
    static func coil(_ svg: inout SVG, at c: P, rx: Double, ry: Double, degrees: Double) {
        for dx in [-1.4, 1.2] {
            let loop = (0...16).map { i -> P in
                let t = Double(i) / 16 * 2 * .pi
                return c + P(dx + rx * sin(t), -ry * cos(t)).rotated(degrees, about: P(0, 0))
            }
            rope(&svg, loop, width: 2)
        }
        let top = c + P(0, -ry).rotated(degrees, about: P(0, 0))
        svg.line([top + P(-2.6, 0.4), top + P(2.6, -0.4)], stroke: .colour(IronPeopleInk.leather), width: 2.4)
        let bottom = c + P(1, ry).rotated(degrees, about: P(0, 0))
        rope(&svg, [bottom, bottom + P(-1.4, 3.4), bottom + P(-0.6, 6)], width: 1.8)
    }

    /// A squared timber lying on the ground, its front face from `left` to
    /// `left + width` and `height` high, the grain running along it and the
    /// tree's rings on its end.
    static func timber(_ svg: inout SVG, left: Double, width: Double, height: Double) {
        let depth = 4.2
        let front = [P(left, 0), P(left + width, 0), P(left + width, -height), P(left, -height)]
        let top = [P(left, -height), P(left + width, -height), P(left + width + depth, -height - depth), P(left + depth, -height - depth)]
        let end = [P(left + width, 0), P(left + width + depth, -depth), P(left + width + depth, -height - depth), P(left + width, -height)]
        svg.ellipse(P(left + width / 2 + 1.5, 0.4), width / 2 + 5, 2.6, fill: .colour("#000000"), opacity: 0.13)
        svg.polygon(front.map { $0 + P(-0.7, 0.6) }, fill: .colour(IronPeopleInk.timber))
        svg.polygon(top.map { $0 + P(-0.7, 0.6) }, fill: .colour(IronPeopleInk.paleTimber))
        svg.polygon(end.map { $0 + P(-0.7, 0.6) }, fill: .colour(IronPeopleInk.paleTimber))
        // The grain along the face and the top, with a knot.
        var grain = PathData()
        for (f, wobble) in [(0.28, 0.8), (0.55, -0.9), (0.8, 0.6)] {
            let y = -height * f
            grain.move(P(left + 1.4, y)); grain.cubic(P(left + width * 0.3, y + wobble), P(left + width * 0.6, y - wobble), P(left + width - 1.2, y))
        }
        grain.move(P(left + 3, -height - 1.4)); grain.line(P(left + width - 2, -height - 1.4))
        svg.path(grain, stroke: .colour(IronPeopleInk.darkTimber), width: 0.8)
        svg.ellipse(P(left + width * 0.3, -height * 0.42), 1.6, 1, fill: .colour(IronPeopleInk.darkTimber))
        // The rings on the end, and a check split across them.
        let middle = P(left + width + depth / 2, -height / 2 - depth / 2)
        for k in [0.62, 0.32] {
            svg.ellipse(middle, depth / 2 * k + 0.4, height / 2 * k, fill: .none, stroke: .colour(IronPeopleInk.darkTimber), width: 0.6)
        }
        svg.circle(middle, 0.5, fill: .colour(IronPeopleInk.darkTimber))
        svg.line([middle, middle + P(1.4, -height * 0.4)], stroke: .colour(IronPeopleInk.darkTimber), width: 0.7)
        for outline in [front, top, end] { svg.polygon(outline, fill: .none, stroke: ink, width: 1.3) }
    }

    /// An iron spike driven into wood, its head's middle at `head`, `length` showing.
    static func spike(_ svg: inout SVG, head: P, length: Double) {
        svg.line([head, head + P(0, length)], stroke: ink, width: 2.4)
        svg.line([head, head + P(0, length)], stroke: .colour(IronPeopleInk.iron), width: 1.2)
        svg.ellipse(head + P(-0.4, 0.4), 2.6, 1.1, fill: .colour(IronPeopleInk.iron))
        svg.ellipse(head, 2.6, 1.1, fill: .none, stroke: ink, width: 0.9)
    }

    /// Sparks flying from iron struck on iron at `p`, `spread` from 0 (struck) to 1 (flying apart).
    static func sparks(_ svg: inout SVG, at p: P, spread: Double) {
        var lines = PathData()
        for angle in stride(from: 100.0, through: 250.0, by: 30.0) {
            let u = P.direction(angle)
            lines.move(p + u * (2 + spread * 4)); lines.line(p + u * (5 + spread * 5))
        }
        svg.path(lines, stroke: ink, width: 1.1)
        for (offset, r) in [(P(6, -5), 1.0), (P(-4, -7), 0.8), (P(9, -1), 0.7), (P(1, -9.4), 0.7)] {
            let c = p + offset * (0.6 + spread * 0.9) + P(0, spread * spread * 3)
            svg.circle(c, r, fill: .colour(IronPeopleInk.gold), stroke: ink, width: 0.5)
        }
    }

    // MARK: The trader's

    /// A gold coin at `p`, turned so that its face shows `face` wide (1 full, 0 edge on).
    static func coin(_ svg: inout SVG, at p: P, face: Double) {
        let rx = max(0.6, 2.9 * abs(face))
        svg.ellipse(p + P(-0.4, 0.4), rx, 2.9, fill: .colour(IronPeopleInk.gold))
        svg.ellipse(p, rx, 2.9, fill: .none, stroke: ink, width: 0.9)
        if abs(face) > 0.5 { svg.ellipse(p, rx * 0.45, 1.3, fill: .none, stroke: .colour(IronPeopleInk.darkStraw), width: 0.6) }
    }

    /// A leather purse hanging from the belt at `p`, its mouth drawn shut.
    static func purse(_ svg: inout SVG, at p: P) {
        BronzePeopleProps.shape(&svg, fill: .colour(IronPeopleInk.leather), width: 1.1) { o in
            var d = PathData()
            d.move(p + P(-1.6, 0) + o)
            d.cubic(p + P(-4.4, 2.6) + o, p + P(-3.6, 7.6) + o, p + P(0, 7.6) + o)
            d.cubic(p + P(3.6, 7.6) + o, p + P(4.4, 2.6) + o, p + P(1.6, 0) + o)
            d.close()
            return d
        }
        svg.path("M\(num(p.x - 1.8)),\(num(p.y + 0.4)) h3.6", stroke: .colour(IronPeopleInk.gold), width: 0.9)
        svg.circle(p + P(0.6, 4.2), 0.7, fill: .colour(IronPeopleInk.gold))
    }

    /// A bundle of goods centred on `c`, wrapped in cloth of the team's colour
    /// with stripes of the light, roped across, and a striped blanket rolled on top.
    static func pack(_ svg: inout SVG, at c: P, width: Double, height: Double, degrees: Double) {
        func turn(_ p: P) -> P { c + p.rotated(degrees, about: P(0, 0)) }
        svg.path(BronzePeopleProps.rounded(c, width: width, height: height, radius: 3.6, degrees: degrees, shift: P(-0.8, 0.7)), fill: .team)
        var stripes = PathData()
        for y in stride(from: -height / 2 + 3.4, through: height / 2 - 2.4, by: 4.2) {
            stripes.move(turn(P(-width / 2 + 1, y))); stripes.line(turn(P(width / 2 - 1, y)))
        }
        svg.path(stripes, stroke: .colour(IronPeopleInk.light), width: 0.9)
        svg.path(BronzePeopleProps.rounded(c, width: width, height: height, radius: 3.6, degrees: degrees, shift: P(0, 0)), stroke: ink, width: 1.3)
        svg.line([turn(P(0.4, -height / 2 - 0.3)), turn(P(-0.4, height / 2 + 0.3))], stroke: .colour(IronPeopleInk.leather), width: 1.6)
        // The rolled blanket on top: light, banded in red.
        let roll = turn(P(0, -height / 2 - 2.2))
        svg.group(at: roll, turned: degrees) { svg in
            svg.path(BronzePeopleProps.rounded(P(0, 0), width: width + 3, height: 4.6, radius: 2.2, degrees: 0, shift: P(-0.6, 0.5)),
                     fill: .colour(IronPeopleInk.light))
            for x in [-width / 2 + 1.4, width / 2 - 2.4] {
                svg.line([P(x, -2.2), P(x, 2.2)], stroke: .colour(IronPeopleInk.red), width: 1.4)
            }
            svg.path(BronzePeopleProps.rounded(P(0, 0), width: width + 3, height: 4.6, radius: 2.2, degrees: 0, shift: P(0, 0)),
                     stroke: ink, width: 1.1)
            svg.ellipse(P(width / 2 + 0.6, 0), 1, 2, fill: .none, stroke: ink, width: 0.6, opacity: 0.8)
        }
    }
}
