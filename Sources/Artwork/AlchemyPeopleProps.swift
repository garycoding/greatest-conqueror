// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// What the peaceful people of the Alchemy age wear and hold: the colours of
// the age (docs/art-style.md, "Palettes") and the things drawn at a hand or on
// the ground. Each is drawn as the Iron age's props are (IronPeopleProps.swift):
// its colour a little out of register with its outline, along a direction in
// degrees from straight down, positive toward the front.

/// The colours of the Alchemy age (gilt, deep teal, wine and the light), with
/// the shades that cloth, fur, glass, brass, iron and wood need. The line, the
/// skin and the eye are the ones every age shares (`Ink`).
enum AlchemyPeopleInk {
    static let gilt = "#d6b25e"
    static let teal = "#2f5a5a"
    static let wine = "#7a3a5a"
    static let light = "#efe0c2"
    static let darkGilt = "#a8863a"
    static let paleGilt = "#ecd79a"
    static let darkTeal = "#1e3d3d"
    static let paleTeal = "#7fa7a2"
    static let mistTeal = "#b4cfc9"
    static let darkWine = "#52243c"
    static let paleWine = "#b77d97"
    /// Linen in shadow: the light's own shade.
    static let shadeLight = "#cfbd98"
    static let leather = "#7a4a2a"
    static let darkLeather = "#55321b"
    static let paleLeather = "#b07a50"
    static let wood = "#8a5a33"
    static let darkWood = "#5e3c20"
    static let paleWood = "#c49a66"
    static let handle = "#6b4a2a"
    /// Iron and steel, with their light and shade.
    static let iron = "#6f7275"
    static let ironDark = "#45474a"
    static let ironLight = "#c9ccce"
    /// Marten fur: brown, with its shade and its tips.
    static let fur = "#8c6646"
    static let darkFur = "#5c402b"
    static let paleFur = "#c29d74"
    /// Glass, and the green tincture in the flask, and the vapour it gives off.
    static let glass = "#d7ebe6"
    static let glassShade = "#93bab3"
    static let tincture = "#79bd63"
    static let darkTincture = "#4b8a3d"
    static let vapour = "#bfe3a8"
    static let vapourShade = "#8fc27c"
    /// Iron at the heat: the glow of a barrel taken from the forge.
    static let glow = "#ee9a3c"
    static let paleGlow = "#ffd77e"
    /// A black velvet bonnet, and its sheen.
    static let velvet = "#3a3034"
    static let velvetSheen = "#6a5a60"
    static let brownHair = "#5a3a24"
    static let greyHair = "#b1aa9c"
    static let blackHair = "#2f2622"
}

/// Geometry the looks share: a point in the picture brought into the leaning
/// body, so that a hand can be sent to something that stands on the ground.
enum AlchemyPeopleKit {
    /// How far the figure is raised for a rig, so that its lower foot rests on the ground (`Drawing.bob`).
    static func bob(_ rig: Rig) -> Double {
        let joints = Joints(rig)
        return -max(joints.backFoot.y, joints.frontFoot.y)
    }

    /// A point of the picture in the body's own units: before the bob and the lean (the inverse of `Drawing.world`).
    static func body(_ world: P, _ rig: Rig) -> P {
        (world - P(0, bob(rig))).rotated(-rig.lean, about: Drawing.hips)
    }

    /// The arm that puts its hand at `world`, a point of the picture.
    static func reach(front: Bool, _ rig: Rig, to world: P, elbowUp: Bool = false) -> Limb {
        let shoulder = front ? BronzePeopleKit.frontShoulder(rig) : BronzePeopleKit.backShoulder(rig)
        return BronzePeopleKit.reach(shoulder, body(world, rig), elbowUp: elbowUp)
    }

    /// A direction in the picture as the leaning body has it: tools drawn inside
    /// the figure turn with the body, so a direction fixed on the ground loses the lean.
    static func bodyDegrees(_ world: Double, _ rig: Rig) -> Double { world + rig.lean }
}

/// The props, each drawn into an `SVG`.
enum AlchemyPeopleProps {
    static let ink = Paint.colour(Ink.line)

    /// A point `along` the direction `u` and `side` across it (along `a`) from `origin`.
    static func at(_ origin: P, _ u: P, _ a: P, _ along: Double, _ side: Double) -> P { origin + u * along + a * side }

    // MARK: The craftsman's

    /// A joiner's mallet of beech: a turned handle from the hand along
    /// `degrees`, and a squared head across its end, its striking face on the
    /// side that leads a blow that brings the angle down.
    static func mallet(_ svg: inout SVG, at hand: P, degrees: Double, haft: Double = 11, head size: Double = 1) {
        let u = P.direction(degrees), a = P(-u.y, u.x) * size
        let head = hand + u * haft
        svg.line([hand - u * 2.6, head], stroke: ink, width: 3.2)
        svg.line([hand - u * 2.6, head], stroke: .colour(AlchemyPeopleInk.paleWood), width: 1.8)
        // A collar where the handle meets the head.
        svg.line([head - u * 1.6 - a * 1.4, head - u * 1.6 + a * 1.4], stroke: .colour(AlchemyPeopleInk.darkWood), width: 0.9)
        let corners = [at(head, u * size, a, 3.6, 5.6), at(head, u * size, a, 3.8, -4.6), at(head, u * size, a, -3.2, -4.6), at(head, u * size, a, -3.4, 5.6)]
        BronzePeopleProps.shape(&svg, corners, fill: .colour(AlchemyPeopleInk.paleWood), width: 1.2)
        // The end grain on the face, and the wear of the blows.
        svg.line([at(head, u * size, a, 2.2, 4.6), at(head, u * size, a, -2, 4.6)], stroke: .colour(AlchemyPeopleInk.wood), width: 0.8)
        svg.line([at(head, u * size, a, 2.4, -1), at(head, u * size, a, 2.4, -3.6)], stroke: .colour(Ink.light), width: 0.7, opacity: 0.8)
    }

    /// The middle of the face of a mallet drawn by `mallet` with the same arguments.
    static func malletFace(at hand: P, degrees: Double, haft: Double = 11, head size: Double = 1) -> P {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        return hand + u * haft + a * (5.8 * size)
    }

    /// A firmer chisel: its boxwood handle from `butt` along `degrees`, its
    /// steel blade beyond, `length` in all.
    static func chisel(_ svg: inout SVG, butt: P, degrees: Double, length: Double = 12) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let ferrule = butt + u * (length * 0.48)
        svg.line([butt, ferrule], stroke: ink, width: 3.2)
        svg.line([butt, ferrule], stroke: .colour(AlchemyPeopleInk.paleGilt), width: 1.9)
        svg.line([ferrule - a * 1.3, ferrule + a * 1.3], stroke: ink, width: 1.4)
        let tip = butt + u * length
        BronzePeopleProps.shape(&svg, [ferrule + a * 0.9, ferrule - a * 0.9, tip - a * 1.3, tip + a * 1.3],
                                fill: .colour(AlchemyPeopleInk.ironLight), width: 0.9, shift: P(-0.4, 0.3))
    }

    /// The point of a chisel drawn by `chisel` with the same arguments.
    static func chiselTip(butt: P, degrees: Double, length: Double = 12) -> P { butt + P.direction(degrees) * length }

    /// A joiner's bench seen from the side: a thick top from `left` to `right`
    /// at `top` above the ground on splayed legs with a stretcher, and a block of
    /// oak on it being carved, its near end cut into a moulding.
    static func bench(_ svg: inout SVG, left: Double, right: Double, top: Double) {
        let thick = 3.6
        svg.ellipse(P((left + right) / 2, 0.4), (right - left) / 2 + 3, 2.4, fill: .colour("#000000"), opacity: 0.13)
        // The legs, splayed, and the stretcher between them.
        for (foot, head) in [(left + 0.6, left + 3.6), (right - 0.6, right - 3.6)] {
            BronzePeopleProps.shape(&svg, [P(head - 1.4, -top + thick), P(head + 1.4, -top + thick), P(foot + 1.4, 0), P(foot - 1.4, 0)],
                                    fill: .colour(AlchemyPeopleInk.wood), width: 1.1)
        }
        svg.line([P(left + 2.6, -top * 0.36), P(right - 2.6, -top * 0.36)], stroke: ink, width: 2.6)
        svg.line([P(left + 2.6, -top * 0.36), P(right - 2.6, -top * 0.36)], stroke: .colour(AlchemyPeopleInk.darkWood), width: 1.2)
        // The top, its end grain showing.
        BronzePeopleProps.shape(&svg, [P(left, -top), P(right, -top), P(right, -top + thick), P(left, -top + thick)],
                                fill: .colour(AlchemyPeopleInk.paleWood), width: 1.2)
        svg.line([P(left + 1.6, -top + 1.6), P(right - 4, -top + 1.4)], stroke: .colour(AlchemyPeopleInk.wood), width: 0.7)
        svg.circle(P(right - 1.6, -top + thick / 2), 0.7, fill: .colour(AlchemyPeopleInk.wood))
    }

    /// The block of oak on the bench, from `left` to `right`, `height` high on
    /// the bench top `top`, held by an iron holdfast; `cut` (0 to 1) is how far
    /// the moulding along its top has gone.
    static func block(_ svg: inout SVG, left: Double, right: Double, top: Double, height: Double) {
        let y0 = -top, y1 = -top - height
        BronzePeopleProps.shape(&svg, [P(left, y0), P(right, y0), P(right, y1 + 1.2), P(right - 2.6, y1), P(left, y1)],
                                fill: .colour(AlchemyPeopleInk.timberOak), width: 1.2)
        // The grain, and the moulding cut along its top.
        var grain = PathData()
        grain.move(P(left + 1.4, y1 + height * 0.45)); grain.quad(P((left + right) / 2, y1 + height * 0.3), P(right - 1.2, y1 + height * 0.5))
        grain.move(P(left + 1.4, y1 + height * 0.75)); grain.quad(P((left + right) / 2, y1 + height * 0.9), P(right - 1.2, y1 + height * 0.7))
        svg.path(grain, stroke: .colour(AlchemyPeopleInk.wood), width: 0.7)
        svg.path("M\(num(left + 0.6)),\(num(y1 + 1.6)) q\(num((right - left) * 0.25)),1.4 \(num((right - left) * 0.5)),0",
                 stroke: .colour(AlchemyPeopleInk.darkWood), width: 0.8)
        // The holdfast at the far end, hooked over the block.
        svg.line([P(left + 2.2, y0 + 3), P(left + 2.2, y1 - 1.6), P(left + 5.4, y1 - 1.6), P(left + 5.4, y1 + 0.2)],
                 stroke: ink, width: 2.4)
        svg.line([P(left + 2.2, y0 + 3), P(left + 2.2, y1 - 1.6), P(left + 5.4, y1 - 1.6), P(left + 5.4, y1 + 0.2)],
                 stroke: .colour(AlchemyPeopleInk.iron), width: 1.1)
    }

    /// Shavings and chips of oak flying from the chisel's point at `p`, `spread` from 0 (struck) to 1 (flying apart).
    static func shavings(_ svg: inout SVG, at p: P, spread: Double) {
        let bits: [(P, Double)] = [(P(5, -5), 1.3), (P(1.6, -8.4), 1.0), (P(8.4, -1.2), 1.1), (P(-3.4, -6.4), 0.9)]
        let k = 0.6 + spread * 0.8
        for (offset, size) in bits {
            let c = p + offset * k + P(0, spread * spread * 2.2)
            var curl = PathData()
            curl.move(c + P(-size, 0)); curl.quad(c + P(0, -size * 1.6), c + P(size, 0)); curl.quad(c + P(0, size * 0.6), c + P(-size * 0.4, -size * 0.2))
            svg.path(curl, fill: .colour(AlchemyPeopleInk.paleGilt), stroke: ink, width: 0.6)
        }
        var lines = PathData()
        for offset in [P(5, -5), P(1.6, -8.4), P(8.4, -1.2)] {
            lines.move(p + offset * (0.22 + spread * 0.3)); lines.line(p + offset * (0.42 + spread * 0.45))
        }
        svg.path(lines, stroke: ink, width: 0.9, opacity: 0.8)
    }

    /// A joiner's tool-tote hanging from the hand at `handle`: an open box of
    /// boards with a handle-rail, a saw's handle, a mallet and a square standing out of it.
    /// `swing` turns it about the hand, in degrees.
    static func tote(_ svg: inout SVG, handle: P, swing: Double) {
        svg.group(turned: swing, about: handle) { svg in
            let top = handle.y + 2.6, bottom = handle.y + 10.6, half = 7.4
            // The saw's handle and blade, and the square, behind the near board.
            svg.polygon([P(handle.x - 6, top - 4.2), P(handle.x - 2.4, top - 5), P(handle.x - 1.6, top + 0.6), P(handle.x - 5.6, top + 0.6)],
                        fill: .colour(AlchemyPeopleInk.wood), stroke: ink, width: 0.9)
            svg.circle(P(handle.x - 4, top - 2.6), 0.8, fill: .colour(AlchemyPeopleInk.darkWood))
            svg.line([P(handle.x + 3.4, top + 0.4), P(handle.x + 3.4, top - 5.6), P(handle.x + 6.4, top - 5.6)], stroke: ink, width: 1.9)
            svg.line([P(handle.x + 3.4, top + 0.4), P(handle.x + 3.4, top - 5.6), P(handle.x + 6.4, top - 5.6)],
                     stroke: .colour(AlchemyPeopleInk.ironLight), width: 0.8)
            // The mallet's head among them.
            svg.line([P(handle.x - 0.6, top + 1), P(handle.x - 1.6, top - 3.4)], stroke: ink, width: 2.2)
            svg.line([P(handle.x - 0.6, top + 1), P(handle.x - 1.6, top - 3.4)], stroke: .colour(AlchemyPeopleInk.paleWood), width: 1)
            BronzePeopleProps.shape(&svg, [P(handle.x - 4.4, top - 3), P(handle.x + 1.4, top - 4.2), P(handle.x + 1.8, top - 6.6),
                                           P(handle.x - 4, top - 5.6)], fill: .colour(AlchemyPeopleInk.paleWood), width: 1)
            // The end boards rising to the rail, and the rail in the hand.
            svg.line([P(handle.x - half + 1, top), P(handle.x - 0.4, handle.y - 0.2)], stroke: ink, width: 1.2)
            svg.line([P(handle.x + half - 1, top), P(handle.x + 0.4, handle.y - 0.2)], stroke: ink, width: 1.2)
            svg.line([P(handle.x - 2.6, handle.y), P(handle.x + 2.6, handle.y)], stroke: ink, width: 2.4)
            svg.line([P(handle.x - 2.6, handle.y), P(handle.x + 2.6, handle.y)], stroke: .colour(AlchemyPeopleInk.paleWood), width: 1.1)
            // The near board.
            BronzePeopleProps.shape(&svg, [P(handle.x - half, top), P(handle.x + half, top), P(handle.x + half - 0.8, bottom),
                                           P(handle.x - half + 0.8, bottom)], fill: .colour(AlchemyPeopleInk.paleWood), width: 1.2)
            svg.line([P(handle.x - half + 1.4, top + 4), P(handle.x + half - 1.4, top + 4.2)], stroke: .colour(AlchemyPeopleInk.wood), width: 0.7)
            for x in [handle.x - half + 1.8, handle.x + half - 1.8] {
                svg.circle(P(x, top + 1.6), 0.5, fill: .colour(Ink.line))
                svg.circle(P(x, bottom - 1.6), 0.5, fill: .colour(Ink.line))
            }
        }
    }

    // MARK: The alchemist's

    /// A round-bottomed flask of glass, its bowl's middle at `c`, turned by
    /// `degrees` (0 stands it upright), its green tincture lying level whatever
    /// the turn and slopping by `slop` (from -1 to 1).
    static func flask(_ svg: inout SVG, at c: P, degrees: Double, slop: Double, radius r: Double = 5) {
        // The tincture: the bowl below a level line, seen through the glass.
        let tilt = slop * 16
        svg.group(at: c, turned: 0) { svg in
            let level = -r * 0.05
            let leftAt = P(-r * 0.9, level), rightAt = P(r * 0.9, level)
            // The surface, tilted by the slop.
            let lift = r * 0.9 * sin(tilt * .pi / 180)
            var liquid = PathData()
            liquid.move(leftAt + P(0, lift)); liquid.line(rightAt - P(0, lift))
            liquid.cubic(P(r * 1.02, r * 0.6), P(r * 0.6, r * 1.02), P(0, r))
            liquid.cubic(P(-r * 0.6, r * 1.02), P(-r * 1.02, r * 0.6), leftAt + P(0, lift))
            liquid.close()
            svg.path(liquid, fill: .colour(AlchemyPeopleInk.tincture))
            svg.path("M\(num(-r * 0.6)),\(num(r * 0.55)) q\(num(r * 0.6)),\(num(r * 0.4)) \(num(r * 1.2)),0",
                     stroke: .colour(AlchemyPeopleInk.darkTincture), width: 0.8)
            // Bubbles rising in it.
            svg.circle(P(r * 0.2, r * 0.3 - abs(slop) * 0.8), 0.55, fill: .colour(AlchemyPeopleInk.vapour))
            svg.circle(P(-r * 0.3, r * 0.55), 0.4, fill: .colour(AlchemyPeopleInk.vapour))
        }
        svg.group(at: c, turned: degrees) { svg in
            // The neck, and the lip at its mouth.
            let neck = r * 1.5
            svg.polygon([P(-1.4, -r * 0.8), P(1.4, -r * 0.8), P(1.4, -r - neck), P(-1.4, -r - neck)], fill: .colour(AlchemyPeopleInk.glass),
                        opacity: 0.85)
            svg.line([P(-1.4, -r * 0.86), P(-1.4, -r - neck)], stroke: ink, width: 1)
            svg.line([P(1.4, -r * 0.86), P(1.4, -r - neck)], stroke: ink, width: 1)
            svg.line([P(-2.2, -r - neck), P(2.2, -r - neck)], stroke: ink, width: 1.8)
            svg.line([P(-1.8, -r - neck), P(1.8, -r - neck)], stroke: .colour(AlchemyPeopleInk.glass), width: 0.7)
            // The bowl: the glass, its outline, and the light on it.
            svg.circle(P(0, 0), r, fill: .none, stroke: ink, width: 1.2)
            svg.path("M\(num(-r * 0.62)),\(num(-r * 0.3)) q\(num(r * 0.1)),\(num(-r * 0.4)) \(num(r * 0.5)),\(num(-r * 0.5))",
                     stroke: .colour("#ffffff"), width: 1, opacity: 0.85)
        }
    }

    /// Where the mouth of a flask drawn by `flask` with the same centre, turn and radius is.
    static func flaskMouth(at c: P, degrees: Double, radius r: Double = 5) -> P {
        c + P(0, -r * 2.5).rotated(degrees, about: P(0, 0))
    }

    /// A puff of coloured vapour: round billows about `c`, `size` across, one
    /// outline round them all, thinning to `opacity`.
    static func vapour(_ svg: inout SVG, at c: P, size: Double, opacity: Double = 1) {
        let billows: [(P, Double)] = [(P(0, 0), 0.5), (P(-0.42, 0.22), 0.36), (P(0.44, 0.18), 0.38), (P(-0.12, -0.42), 0.34), (P(0.3, -0.36), 0.28)]
        svg.raw("<g opacity=\"\(num(opacity))\">")
        // The outline: every billow stroked, then every billow filled over the strokes, so that only the outer edge shows.
        for (offset, r) in billows {
            svg.circle(c + offset * size, r * size, fill: .colour(Ink.line), stroke: .colour(Ink.line), width: 1.6)
        }
        for (offset, r) in billows {
            svg.circle(c + offset * size + P(-0.3, 0.3), r * size, fill: .colour(AlchemyPeopleInk.vapour))
        }
        // The billows' inner shade, and a curl of each.
        svg.path("M\(num(c.x - size * 0.34)),\(num(c.y + size * 0.36)) q\(num(size * 0.34)),\(num(size * 0.2)) \(num(size * 0.7)),0",
                 stroke: .colour(AlchemyPeopleInk.vapourShade), width: 0.9)
        svg.path("M\(num(c.x - size * 0.1)),\(num(c.y - size * 0.3)) q\(num(size * 0.16)),\(num(-size * 0.16)) \(num(size * 0.3)),0",
                 stroke: .colour(AlchemyPeopleInk.vapourShade), width: 0.8)
        svg.raw("</g>")
    }

    /// A small book bound in `cover` with gilt tooling, shut, centred on `c` and turned by `degrees`.
    static func book(_ svg: inout SVG, at c: P, degrees: Double, cover: String = AlchemyPeopleInk.teal, width w: Double = 9,
                     height h: Double = 11.6) {
        svg.group(at: c, turned: degrees) { svg in
            // The edges of the leaves, then the cover over them.
            svg.polygon([P(-w / 2 + 1, -h / 2 + 1), P(w / 2 + 1.2, -h / 2 + 1), P(w / 2 + 1.2, h / 2 + 0.6), P(-w / 2 + 1, h / 2 + 0.6)],
                        fill: .colour(AlchemyPeopleInk.light), stroke: ink, width: 0.8)
            svg.path(BronzePeopleProps.rounded(P(0, 0), width: w, height: h, radius: 0.9, degrees: 0, shift: P(-0.5, 0.4)),
                     fill: .colour(cover))
            svg.path(BronzePeopleProps.rounded(P(0, 0), width: w, height: h, radius: 0.9, degrees: 0, shift: P(0, 0)), stroke: ink, width: 1.1)
            svg.path(BronzePeopleProps.rounded(P(0.2, 0), width: w - 3.2, height: h - 3.4, radius: 0.5, degrees: 0, shift: P(0, 0)),
                     stroke: .colour(AlchemyPeopleInk.gilt), width: 0.6)
            svg.circle(P(0.2, 0), 1.1, fill: .none, stroke: .colour(AlchemyPeopleInk.gilt), width: 0.6)
            svg.line([P(-w / 2 + 0.9, -h / 2 + 0.4), P(-w / 2 + 0.9, h / 2 - 0.4)], stroke: .colour(Ink.line), width: 1.2, opacity: 0.5)
        }
    }

    // MARK: The gunsmith's

    /// A smith's cross-peen hammer: a haft from the hand along `degrees`, an
    /// iron head across its end, its flat face leading a blow that brings the
    /// angle down and its narrow peen behind.
    static func hammer(_ svg: inout SVG, at hand: P, degrees: Double, haft: Double = 13) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let head = hand + u * haft
        svg.line([hand - u * 2.6, head + u * 1.4], stroke: .colour(AlchemyPeopleInk.handle), width: 2.4)
        svg.line([hand - u * 2.6 + a * 0.7, head + a * 0.7], stroke: ink, width: 0.6, opacity: 0.5)
        let corners = [at(head, u, a, 2.7, 6), at(head, u, a, 2.4, 1.2), at(head, u, a, 1.2, -5.4), at(head, u, a, -1.2, -5.4),
                       at(head, u, a, -2.4, 1.2), at(head, u, a, -2.7, 6)]
        BronzePeopleProps.shape(&svg, corners, fill: .colour(AlchemyPeopleInk.iron), width: 1.2)
        svg.line([at(head, u, a, 1.8, 5.4), at(head, u, a, 1.6, -1.6)], stroke: .colour(AlchemyPeopleInk.ironLight), width: 0.9)
        svg.line([at(head, u, a, 2.7, 4.4), at(head, u, a, -2.7, 4.4)], stroke: ink, width: 0.7, opacity: 0.7)
    }

    /// The face of a hammer drawn by `hammer` with the same arguments.
    static func hammerFace(at hand: P, degrees: Double, haft: Double = 13) -> P {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        return hand + u * haft + a * 6.1
    }

    /// A musket's barrel of iron from `breech` to `muzzle`: tapering, banded
    /// at the breech, its muzzle open; glowing toward the breech by `heat` (0 to 1).
    static func barrel(_ svg: inout SVG, breech: P, muzzle: P, heat: Double = 0) {
        let along = muzzle - breech
        let length = BronzePeopleKit.length(along)
        let u = along * (1 / max(length, 0.01)), a = P(-u.y, u.x)
        let outline = [breech + a * 1.9, muzzle + a * 1.3, muzzle - a * 1.3, breech - a * 1.9]
        BronzePeopleProps.shape(&svg, outline, fill: .colour(AlchemyPeopleInk.iron), width: 1.1, shift: P(-0.4, 0.4))
        if heat > 0 {
            // The heat, white-gold at its hottest and dulling to orange along the barrel.
            svg.polygon([breech + u * (length * 0.18) + a * 1.75, breech + u * (length * 0.62) + a * 1.45,
                         breech + u * (length * 0.62) - a * 1.45, breech + u * (length * 0.18) - a * 1.75], fill: .colour(AlchemyPeopleInk.glow),
                        opacity: heat)
            svg.polygon([breech + u * (length * 0.28) + a * 1.2, breech + u * (length * 0.48) + a * 1.1,
                         breech + u * (length * 0.48) - a * 1.1, breech + u * (length * 0.28) - a * 1.2], fill: .colour(AlchemyPeopleInk.paleGlow),
                        opacity: heat)
        }
        svg.line([breech + a * 0.9 + u * 2, muzzle + a * 0.6 - u * 1], stroke: .colour(AlchemyPeopleInk.ironLight), width: 0.7, opacity: 0.9)
        // The flats of the breech, and the touch-hole.
        for t in [2.4, 4.4] {
            svg.line([breech + u * t + a * 1.9, breech + u * t - a * 1.9], stroke: ink, width: 0.8)
        }
        svg.circle(breech + u * 3.4 + a * 1.1, 0.4, fill: .colour(Ink.line))
        svg.ellipse(muzzle, 0.6, 1.2, fill: .colour(Ink.line))
    }

    /// An anvil on its stump of elm: the stump from the ground, the anvil's
    /// face from `left` to `right` at `top` above the ground, with its horn to the front.
    static func anvil(_ svg: inout SVG, left: Double, right: Double, top: Double) {
        let middle = (left + right) / 2, stump = top - 6.4
        svg.ellipse(P(middle, 0.4), (right - left) / 2 + 4, 2.4, fill: .colour("#000000"), opacity: 0.13)
        // The stump, ringed, with an iron band.
        BronzePeopleProps.shape(&svg, [P(middle - 6, -stump), P(middle + 6, -stump), P(middle + 7, 0), P(middle - 7, 0)],
                                fill: .colour(AlchemyPeopleInk.wood), width: 1.2)
        var bark = PathData()
        for x in [-3.6, 0.4, 4.0] {
            bark.move(P(middle + x, -stump + 1.4)); bark.quad(P(middle + x * 1.1 + 0.6, -stump / 2), P(middle + x * 1.16, -1))
        }
        svg.path(bark, stroke: .colour(AlchemyPeopleInk.darkWood), width: 0.7)
        svg.line([P(middle - 6.4, -stump * 0.4), P(middle + 6.4, -stump * 0.4)], stroke: ink, width: 2.4)
        svg.line([P(middle - 6.4, -stump * 0.4), P(middle + 6.4, -stump * 0.4)], stroke: .colour(AlchemyPeopleInk.iron), width: 1.1)
        // The anvil: a waisted body, the face across the top, the horn to the front and the heel behind.
        var body = PathData()
        body.move(P(left, -top))
        body.line(P(right, -top))
        body.cubic(P(right + 4, -top), P(right + 8, -top + 1), P(right + 10.6, -top + 1.4))
        body.cubic(P(right + 7, -top + 2.8), P(right + 3, -top + 3.4), P(right - 1.6, -top + 3.4))
        body.cubic(P(right - 3.6, -top + 4.2), P(right - 4, -top + 5.2), P(right - 2.4, -stump))
        body.line(P(left + 1.4, -stump))
        body.cubic(P(left + 3, -top + 5.2), P(left + 2.6, -top + 4.2), P(left, -top + 3.2))
        body.line(P(left - 2.6, -top + 3))
        body.line(P(left - 2.6, -top))
        body.close()
        svg.path(body, fill: .colour(AlchemyPeopleInk.ironDark))
        svg.line([P(left - 2, -top + 0.8), P(right + 2, -top + 0.8)], stroke: .colour(AlchemyPeopleInk.ironLight), width: 1)
        svg.path(body, stroke: ink, width: 1.3)
    }

    /// Sparks flying from hot iron struck at `p`, `spread` from 0 (struck) to 1 (flying apart).
    static func sparks(_ svg: inout SVG, at p: P, spread: Double) {
        var lines = PathData()
        for angle in stride(from: 95.0, through: 265.0, by: 34.0) {
            let u = P.direction(angle)
            lines.move(p + u * (2 + spread * 4)); lines.line(p + u * (5.4 + spread * 5))
        }
        svg.path(lines, stroke: ink, width: 1.1)
        for (offset, r) in [(P(6.4, -5), 1.0), (P(-4.4, -7), 0.8), (P(9.4, -1.4), 0.7), (P(1.4, -9.6), 0.75), (P(-8, -3), 0.6)] {
            let c = p + offset * (0.6 + spread * 0.9) + P(0, spread * spread * 3)
            svg.circle(c, r, fill: .colour(AlchemyPeopleInk.paleGlow), stroke: ink, width: 0.5)
        }
    }

    /// Smith's tongs from the hand at `hand` along `degrees`, their jaws closed at `length`.
    static func tongs(_ svg: inout SVG, at hand: P, degrees: Double, length: Double = 13) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let pivot = hand + u * (length * 0.62), jaws = hand + u * length
        for side in [-1.0, 1.0] {
            svg.line([hand - u * 2 + a * (0.9 * side), pivot + a * (0.3 * side), jaws + a * (0.8 * side)], stroke: ink, width: 2)
            svg.line([hand - u * 2 + a * (0.9 * side), pivot + a * (0.3 * side), jaws + a * (0.8 * side)],
                     stroke: .colour(AlchemyPeopleInk.iron), width: 0.8)
        }
        svg.circle(pivot, 0.8, fill: .colour(AlchemyPeopleInk.ironLight), stroke: ink, width: 0.6)
    }

    /// A powder flask of horn hanging from a cord at `p`, capped in brass.
    static func powderHorn(_ svg: inout SVG, at p: P) {
        BronzePeopleProps.shape(&svg, fill: .colour(AlchemyPeopleInk.paleLeather), width: 1.1) { o in
            var d = PathData()
            d.move(p + P(-4.4, -1) + o)
            d.cubic(p + P(-4, 3.4) + o, p + P(1.4, 5) + o, p + P(5.4, 3.2) + o)
            d.line(p + P(5, 1.4) + o)
            d.cubic(p + P(1.4, 2.4) + o, p + P(-1.6, 1) + o, p + P(-1.4, -1.6) + o)
            d.close()
            return d
        }
        svg.line([p + P(-4.2, -1.2), p + P(-1.6, -1.8)], stroke: ink, width: 2.2)
        svg.line([p + P(-4.2, -1.2), p + P(-1.6, -1.8)], stroke: .colour(AlchemyPeopleInk.darkGilt), width: 1)
        svg.line([p + P(4.4, 1.6), p + P(5.6, 3.4)], stroke: .colour(AlchemyPeopleInk.darkGilt), width: 1.2)
    }

    // MARK: The banker's

    /// A gold coin at `p`, turned so that its face shows `face` wide (1 full, 0 edge on).
    static func coin(_ svg: inout SVG, at p: P, face: Double, radius r: Double = 2.4) {
        let rx = max(0.5, r * abs(face))
        svg.ellipse(p + P(-0.3, 0.3), rx, r, fill: .colour(AlchemyPeopleInk.paleGilt))
        svg.ellipse(p, rx, r, fill: .none, stroke: ink, width: 0.8)
        if abs(face) > 0.5 { svg.ellipse(p, rx * 0.5, r * 0.5, fill: .none, stroke: .colour(AlchemyPeopleInk.darkGilt), width: 0.5) }
    }

    /// An iron-bound strongbox of oak on the ground from `left`, `width` wide
    /// and `height` high, its lid thrown back, heaped with gold; the near face
    /// banded with iron and studded, a lock-plate at its middle.
    static func strongbox(_ svg: inout SVG, left: Double, width w: Double, height h: Double) {
        let right = left + w, depth = 4.0
        svg.ellipse(P(left + w / 2 + 1.4, 0.4), w / 2 + 4, 2.4, fill: .colour("#000000"), opacity: 0.13)
        // The lid, open and leaning back from the far edge.
        let hinge = P(left + depth * 0.6, -h - depth)
        BronzePeopleProps.shape(&svg, [hinge, hinge + P(w - 1, 0), hinge + P(w - 4, -6.4), hinge + P(-2, -7.6)],
                                fill: .colour(AlchemyPeopleInk.darkWood), width: 1.2)
        svg.line([hinge + P(2, -0.6), hinge + P(0.4, -7)], stroke: ink, width: 2.2)
        svg.line([hinge + P(w - 4, -0.6), hinge + P(w - 6, -6)], stroke: ink, width: 2.2)
        // The heap of gold inside, and a coin or two upright in it.
        var heap = PathData()
        heap.move(P(left + 0.6, -h)); heap.cubic(P(left + w * 0.2, -h - 6.4), P(left + w * 0.8, -h - 6), P(right + depth - 0.6, -h - depth * 0.6))
        heap.line(P(right, -h)); heap.close()
        svg.path(heap, fill: .colour(AlchemyPeopleInk.gilt), stroke: ink, width: 0.9)
        for (x, y) in [(0.3, -3.6), (0.55, -4.6), (0.74, -3.2)] {
            svg.ellipse(P(left + w * x, -h + y), 1.6, 0.9, fill: .none, stroke: .colour(AlchemyPeopleInk.darkGilt), width: 0.6)
        }
        // The top edge seen beyond the heap, and the end.
        BronzePeopleProps.shape(&svg, [P(right, 0), P(right + depth, -depth), P(right + depth, -h - depth), P(right, -h)],
                                fill: .colour(AlchemyPeopleInk.darkWood), width: 1.1)
        // The near face.
        BronzePeopleProps.shape(&svg, [P(left, 0), P(right, 0), P(right, -h), P(left, -h)], fill: .colour(AlchemyPeopleInk.wood), width: 1.3)
        svg.line([P(left + 1.4, -h * 0.5), P(right - 1.4, -h * 0.5)], stroke: .colour(AlchemyPeopleInk.darkWood), width: 0.6)
        // The iron bands, their studs, and the lock-plate.
        for x in [left + 2.4, right - 2.4] {
            svg.line([P(x, -0.4), P(x, -h + 0.4)], stroke: ink, width: 2.6)
            svg.line([P(x, -0.4), P(x, -h + 0.4)], stroke: .colour(AlchemyPeopleInk.iron), width: 1.3)
            for y in stride(from: 1.8, through: h - 1.6, by: 2.6) {
                svg.circle(P(x, -y), 0.45, fill: .colour(AlchemyPeopleInk.ironLight))
            }
        }
        svg.line([P(left + 0.4, -h + 1), P(right - 0.4, -h + 1)], stroke: ink, width: 2.2)
        svg.line([P(left + 0.4, -h + 1), P(right - 0.4, -h + 1)], stroke: .colour(AlchemyPeopleInk.iron), width: 1)
        let lock = P(left + w / 2, -h * 0.56)
        svg.path(BronzePeopleProps.rounded(lock, width: 3.6, height: 4.4, radius: 0.8, degrees: 0, shift: P(-0.3, 0.3)),
                 fill: .colour(AlchemyPeopleInk.darkGilt))
        svg.path(BronzePeopleProps.rounded(lock, width: 3.6, height: 4.4, radius: 0.8, degrees: 0, shift: P(0, 0)), stroke: ink, width: 0.8)
        svg.path("M\(num(lock.x)),\(num(lock.y - 0.9)) l0,1.8", stroke: .colour(Ink.line), width: 0.9)
    }

    /// A ledger bound in wine-red calf, open in the hand at `c` and turned by
    /// `degrees`: two pages of figures in columns, a ribbon hanging from it.
    static func ledger(_ svg: inout SVG, at c: P, degrees: Double, ribbon: Double = 0) {
        svg.group(at: c, turned: degrees) { svg in
            // The binding beneath the pages.
            svg.polygon([P(-8.4, -1.4), P(8.4, -1.4), P(8.8, 1.8), P(0, 2.6), P(-8.8, 1.8)], fill: .colour(AlchemyPeopleInk.darkWine),
                        stroke: ink, width: 1)
            // The pages, curving from the spine.
            for side in [-1.0, 1.0] {
                var page = PathData()
                page.move(P(0, 1.2)); page.quad(P(side * 4, -1.2), P(side * 8, -0.6))
                page.line(P(side * 7.8, -5.8)); page.quad(P(side * 4, -6.4), P(0, -4.6)); page.close()
                svg.path(page, fill: .colour(AlchemyPeopleInk.light), stroke: ink, width: 0.9)
                // Columns of figures.
                var figures = PathData()
                for row in 0..<3 {
                    let y = -4.4 + Double(row) * 1.3
                    figures.move(P(side * 1.6, y + 0.2)); figures.line(P(side * 5.6, y - 0.2 * side))
                }
                svg.path(figures, stroke: .colour(AlchemyPeopleInk.darkWine), width: 0.5, opacity: 0.9)
            }
            svg.line([P(0, 1.2), P(0, -4.6)], stroke: ink, width: 0.8)
            // The ribbon.
            svg.path("M0.4,1.6 q\(num(0.8 + ribbon)),2.6 \(num(0.2 + ribbon * 1.4)),4.8", stroke: .colour(AlchemyPeopleInk.gilt), width: 0.9)
        }
    }

    /// A purse of soft leather hanging from the belt at `p`, its mouth drawn shut with a gilt cord.
    static func purse(_ svg: inout SVG, at p: P, swing: Double = 0) {
        svg.group(turned: swing, about: p) { svg in
            BronzePeopleProps.shape(&svg, fill: .colour(AlchemyPeopleInk.paleLeather), width: 1.1) { o in
                var d = PathData()
                d.move(p + P(-1.6, 0.4) + o)
                d.cubic(p + P(-5, 3) + o, p + P(-4, 8.6) + o, p + P(0, 8.6) + o)
                d.cubic(p + P(4, 8.6) + o, p + P(5, 3) + o, p + P(1.6, 0.4) + o)
                d.close()
                return d
            }
            svg.path("M\(num(p.x - 2)),\(num(p.y + 1.2)) h4", stroke: .colour(AlchemyPeopleInk.gilt), width: 1)
            svg.line([p + P(-0.6, 1.4), p + P(-1.4, 4.2)], stroke: .colour(AlchemyPeopleInk.gilt), width: 0.7)
            svg.circle(p + P(-1.4, 4.4), 0.7, fill: .colour(AlchemyPeopleInk.gilt))
        }
    }
}

extension AlchemyPeopleInk {
    /// Oak for the craftsman's block, paler than the bench.
    static let timberOak = "#b5864f"
}
