// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The swordsman

/// A swordsman of the legion: an iron helmet with a cheek guard, a neck guard
/// and a brush crest of legion red; banded iron armour over a sea-green tunic,
/// a red scarf at the neck, a studded belt with leather straps hanging before
/// him; a scar across the cheek; nose A. A tall curved shield, painted in the
/// team's colour with wings and thunderbolts in the light and an iron boss, held
/// before him, and a short iron sword. Fighting, he raises the sword and cuts
/// down, draws it back to the hip, and lunges to thrust it home.
struct IronWarriorsSwordsman: PersonLook {
    /// One frame of the fight: the sword hand, the sword's direction, the
    /// body's lean, the front leg, and how far the shield is pushed forward.
    struct Stroke {
        var hand: P
        var degrees: Double
        var lean: Double
        var lunge: Bool
        var push: Double
    }

    static let strokes: [Stroke] = [
        Stroke(hand: P(13, -37), degrees: 78, lean: 2, lunge: false, push: 0),
        Stroke(hand: P(13, -48), degrees: 150, lean: 0, lunge: false, push: -0.4),
        Stroke(hand: P(13, -55), degrees: 172, lean: -3, lunge: false, push: -0.8),
        Stroke(hand: P(12, -57.4), degrees: 186, lean: -4, lunge: false, push: -1),
        Stroke(hand: P(17, -48), degrees: 124, lean: 6, lunge: true, push: 0.6),
        Stroke(hand: P(19, -38), degrees: 62, lean: 9, lunge: true, push: 1.2),
        Stroke(hand: P(7, -33), degrees: 86, lean: 3, lunge: false, push: 0.4),
        Stroke(hand: P(1, -33), degrees: 92, lean: 0, lunge: false, push: 0),
        Stroke(hand: P(17, -37), degrees: 91, lean: 8, lunge: true, push: 1.6),
        Stroke(hand: P(22, -38), degrees: 90, lean: 11, lunge: true, push: 2.4),
        Stroke(hand: P(18, -37.6), degrees: 86, lean: 7, lunge: true, push: 1.4),
        Stroke(hand: P(15, -37), degrees: 80, lean: 4, lunge: false, push: 0.4),
    ]

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.backLeg = Limb(-6, 4); r.frontLeg = Limb(7, 4)
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), P(13, -33 - r.lift * 0.5))
            r.backArm = Limb(30, 50)
            r.mouth = .firm
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 24)
            r.frontArm = Limb(4 + 16 * r.sway, 44)
            r.backArm = Limb(30, 50)
            r.mouth = .firm
            return r
        case .fighting:
            let stroke = Self.strokes[frame]
            var r = Rig()
            r.lean = stroke.lean
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), stroke.hand, elbowUp: stroke.hand.y < -50)
            r.backArm = Limb(36, 46)
            r.backLeg = Limb(-16, 6)
            r.frontLeg = stroke.lunge ? Limb(24, 14) : Limb(13, 8)
            r.mouth = frame == 5 || frame == 9 ? .shout : .firm
            r.eyes = frame == 5 || frame == 9 ? .wide : .open
            return r
        default:
            return nil
        }
    }

    /// The sword's direction from the hand.
    static func swordDegrees(_ pose: SpritePose, _ frame: Int, rig: Rig) -> Double {
        switch pose {
        case .fighting: strokes[frame].degrees
        case .walking: 64 + rig.frontArm.upper * 0.8
        default: 58
        }
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        d.figure { d in
            d.arm(front: false, width: 2.1)
            d.legs()
            // Low boots: the straps of the sandal over the foot.
            for front in [false, true] {
                let foot = front ? d.joints.frontFoot : d.joints.backFoot
                let knee = front ? d.joints.frontKnee : d.joints.backKnee
                let u = P.direction(BronzePeopleKit.degrees(from: knee, to: foot))
                d.svg.group(turned: -d.rig.lean, about: Drawing.hips) { svg in
                    svg.line([foot - u * 3.6, foot, foot + P(4.2, 0.3)], stroke: .colour(Ink.line), width: 3.4)
                    svg.line([foot - u * 3.2, foot + P(0.4, 0)], stroke: .colour(IronWarriorsInk.leather), width: 1.4)
                }
            }
            // The tunic's skirt, sea green, its hem banded in a paler green.
            d.garment(colour: [P(-13.6, -29), P(12.2, -30), P(14.6, -13.2), P(-16.4, -12.6)],
                      outline: [P(-12.2, -28.6), P(11.6, -28.6), P(13.4, -14.6), P(-14.8, -14.6)], fill: .colour(IronWarriorsInk.deepSea)) { d in
                d.svg.line([P(-14.4, -16.2), P(13.2, -16.2)], stroke: .colour(IronWarriorsInk.paleSea), width: 1.4)
            }
            // The banded armour: hoops of iron round the body.
            d.garment(colour: [P(-12.6, -46.4), P(9.4, -48.4), P(12.6, -26.4), P(-14, -26)],
                      outline: [P(-8.6, -47.2), P(9, -47.2), P(12, -27.6), P(-13.2, -27.6)], fill: .colour(IronWarriorsInk.iron)) { d in
                var hoops = PathData(), shine = PathData()
                for i in 0..<5 {
                    let y = -43.6 + Double(i) * 3.4
                    let left = -9.6 - Double(i) * 0.75, right = 9.4 + Double(i) * 0.6
                    hoops.move(d.up(P(left, y))); hoops.quad(d.up(P(0, y + 1.2)), d.up(P(right, y)))
                    shine.move(d.up(P(left + 1.6, y - 1.3))); shine.quad(d.up(P(0, y - 0.3)), d.up(P(right - 2.4, y - 1.4)))
                }
                d.svg.path(shine, stroke: .colour(IronWarriorsInk.ironLight), width: 0.9)
                d.svg.path(hoops, stroke: .colour(IronWarriorsInk.ironDark), width: 1.1)
            }
            // The scarf of legion red at the neck.
            IronWarriorsKit.shape(&d.svg, [d.up(P(-6.4, -48.6)), d.up(P(7.6, -48.8)), d.up(P(8.6, -45.4)), d.up(P(1, -44.2)),
                                           d.up(P(-6.8, -45.4))], fill: .colour(IronWarriorsInk.legion), width: 1.1)
            // The belt, studded, and its leather straps hanging before him.
            d.svg.line([d.up(P(-13.4, -27.4)), d.up(P(12.4, -27.6))], stroke: .colour(Ink.line), width: 3.4)
            d.svg.line([d.up(P(-13, -27.4)), d.up(P(12, -27.6))], stroke: .colour(IronWarriorsInk.leather), width: 2)
            let swing = pose == .walking ? 0.8 * sway : 0
            for x in [3.6, 6.6, 9.6] {
                let top = d.up(P(x, -26.4)), bottom = P(x + 0.4 + swing, -17.4)
                d.svg.line([top, bottom], stroke: .colour(Ink.line), width: 2.4)
                d.svg.line([top, bottom], stroke: .colour(IronWarriorsInk.leather), width: 1.1)
                d.svg.circle(bottom, 0.9, fill: .colour(IronWarriorsInk.ironLight), stroke: .colour(Ink.line), width: 0.5)
            }
            // The shield, held before him.
            let push = pose == .fighting ? Self.strokes[frame].push : 0
            let lift = pose == .walking ? 0.6 * sway : 0
            Self.shield(&d.svg, at: d.up(P(-1.6 + push, -30.4)) + P(0, lift))
            // The sword, and the marks of the cut and the thrust.
            let hand = d.joints.frontHand
            let degrees = Self.swordDegrees(pose, frame, rig: d.rig)
            if pose == .fighting && frame == 4 {
                d.swish(around: d.joints.frontShoulder, radius: 22, from: 186, to: 110)
            }
            if pose == .fighting && frame == 8 {
                let tip = IronWarriorsKit.gladiusPoint(at: hand, degrees: degrees)
                d.svg.path("M\(num(tip.x - 22)),\(num(tip.y - 3)) l11,0.4 M\(num(tip.x - 20)),\(num(tip.y + 3)) l11,-0.3",
                           stroke: .colour(Ink.line), width: 1.1, opacity: 0.6)
            }
            IronWarriorsKit.gladius(&d.svg, at: hand, degrees: degrees)
            if pose == .fighting && (frame == 5 || frame == 9) {
                d.impact(at: IronWarriorsKit.gladiusPoint(at: hand, degrees: degrees) + P.direction(degrees) * 1.6, size: 1)
            }
            d.arm(front: true, width: 2.1)
            // The iron plates over the sword arm's shoulder.
            let s = d.joints.frontShoulder
            IronWarriorsKit.shape(&d.svg, [s + P(-4.4, 0.4), s + P(-2.6, -3), s + P(2.6, -3), s + P(4.6, 0.6), s + P(4, 2.4), s + P(-4, 2.2)],
                                  fill: .colour(IronWarriorsInk.iron), width: 1.1)
            IronWarriorsKit.shape(&d.svg, [s + P(-3.4, 2.2), s + P(3.8, 2.4), s + P(3.6, 4.6), s + P(-3, 4.4)],
                                  fill: .colour(IronWarriorsInk.iron), width: 1)
            d.svg.line([s + P(-2.4, -2), s + P(2.4, -2)], stroke: .colour(IronWarriorsInk.ironLight), width: 0.8)
            d.head(nose: .curve, hair: { _ in }, features: { d in
                // A scar across the cheek, and the shadow of a beard along the jaw.
                d.svg.path("M1.4,-56.6 l3.4,2.6", stroke: .colour(Ink.line), width: 0.8, opacity: 0.7)
                d.svg.path("M2.4,-54.8 l0.8,-1 M3.6,-54 l0.8,-1", stroke: .colour(Ink.line), width: 0.6, opacity: 0.6)
                d.svg.path("M-1,-49.4 C2,-47.6 6.6,-47.6 9.6,-49.6", stroke: .colour(Ink.line), width: 1, opacity: 0.45)
            }, brow: { d in
                d.svg.path("M1.4,-63.4 l7,-0.4", stroke: .colour(Ink.line), width: 2.1)
            }, over: { d in
                IronWarriorsKit.helmet(&d, crest: .brush)
            })
        }
    }

    // MARK: The other views

    /// How far to his left the shield is held, seen from another side: on the
    /// forearm, before the left half of his body.
    static let shieldAside = -7.0

    /// The swordsman seen from the front, from behind, or from a quarter turn.
    /// From the front the shield covers the left of his body; from behind it
    /// shows past his left side, and the strap he slings it by, in the team's
    /// colour, crosses his back.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view, behind = IronViews.fromBehind(view)
        let (c, _) = IronViews.turn(view)
        let sway = d.rig.sway
        d.figure { d in
            let push = pose == .fighting ? Self.strokes[frame].push : 0
            let lift = pose == .walking ? 0.6 * sway : 0
            let shieldAt = IronViews.at(view, d.up(P(9 + push, -30.4)), z: Self.shieldAside) + P(0, lift)
            let hand = d.hand(front: true)
            let sword = IronViews.tool(view, Self.swordDegrees(pose, frame, rig: d.rig))
            let blade = 13 * sword.share
            let swordBehind = d.armBehind(front: true)
            func drawSword(_ d: inout Drawing) {
                IronWarriorsKit.gladius(&d.svg, at: hand, degrees: sword.degrees, blade: blade)
                if pose == .fighting && (frame == 5 || frame == 9) {
                    d.impact(at: IronWarriorsKit.gladiusPoint(at: hand, degrees: sword.degrees, blade: blade) + P.direction(sword.degrees) * 1.6,
                             size: 1)
                }
            }
            if behind { Self.shieldBack(&d.svg, at: shieldAt, width: view == .back ? 15.4 : 11.4) }
            if swordBehind { drawSword(&d) }
            d.arm(front: false, width: 2.1)
            d.legs()
            // Low boots: the straps of the sandal over each foot.
            let legs = [false, true].map { IronViews.leg(d, front: $0) }
            d.svg.group(turned: -d.rig.lean * c, about: Drawing.hips) { svg in
                for leg in legs {
                    let u = P.direction(BronzePeopleKit.degrees(from: leg.knee, to: leg.foot))
                    svg.line([leg.foot - u * 3.6, leg.foot, leg.toe], stroke: .colour(Ink.line), width: 3.4)
                    svg.line([leg.foot - u * 3.2, leg.foot + (leg.toe - leg.foot) * 0.1], stroke: .colour(IronWarriorsInk.leather), width: 1.4)
                }
            }
            let skirt = [P(-12.2, -28.6), P(11.6, -28.6), P(13.4, -14.6), P(-14.8, -14.6)]
            d.garment(colour: [P(-13.6, -29), P(12.2, -30), P(14.6, -13.2), P(-16.4, -12.6)], outline: skirt,
                      fill: .colour(IronWarriorsInk.deepSea)) { d in
                let hem = IronViews.span(d, skirt, at: -16.2)
                d.svg.line([P(hem.left + 0.4, -16.2), P(hem.right - 0.4, -16.2)], stroke: .colour(IronWarriorsInk.paleSea), width: 1.4)
            }
            let armour = [P(-8.6, -47.2), P(9, -47.2), P(12, -27.6), P(-13.2, -27.6)]
            d.garment(colour: [P(-12.6, -46.4), P(9.4, -48.4), P(12.6, -26.4), P(-14, -26)], outline: armour,
                      fill: .colour(IronWarriorsInk.iron)) { d in
                var hoops = PathData(), shine = PathData()
                for i in 0..<5 {
                    let y = -43.6 + Double(i) * 3.4
                    let across = IronViews.span(d, armour, at: y)
                    let left = across.left + 0.6, right = across.right - 0.6, middle = (left + right) / 2
                    hoops.move(d.up(P(left, y))); hoops.quad(d.up(P(middle, y + 1.2)), d.up(P(right, y)))
                    shine.move(d.up(P(left + 1.6, y - 1.3))); shine.quad(d.up(P(middle, y - 0.3)), d.up(P(right - 2.4, y - 1.4)))
                }
                d.svg.path(shine, stroke: .colour(IronWarriorsInk.ironLight), width: 0.9)
                d.svg.path(hoops, stroke: .colour(IronWarriorsInk.ironDark), width: 1.1)
            }
            // The scarf of legion red, round the neck.
            IronWarriorsKit.shape(&d.svg, IronViews.around(d, [P(-6.4, -48.6), P(7.6, -48.8), P(8.6, -45.4), P(1, -44.2), P(-6.8, -45.4)]),
                                  fill: .colour(IronWarriorsInk.legion), width: 1.1)
            // The studded belt, and the leather straps hanging before him.
            let belt = IronViews.span(d, armour, at: -27.6)
            d.svg.line([d.up(P(belt.left - 0.4, -27.4)), d.up(P(belt.right + 0.4, -27.6))], stroke: .colour(Ink.line), width: 3.4)
            d.svg.line([d.up(P(belt.left, -27.4)), d.up(P(belt.right, -27.6))], stroke: .colour(IronWarriorsInk.leather), width: 2)
            if behind {
                // The shield's strap, from the right shoulder across his back to the left hip.
                let strap = [IronViews.at(view, d.up(P(-4, -47.4)), z: 6.4), IronViews.at(view, d.up(P(-4, -46.6)), z: 9.4),
                             IronViews.at(view, d.up(P(-5, -28.6)), z: -9.6), IronViews.at(view, d.up(P(-5, -31.6)), z: -10.6)]
                IronWarriorsKit.shape(&d.svg, strap, fill: .team, width: 1)
            } else {
                let swing = pose == .walking ? 0.8 * sway * c : 0
                for x in [3.6, 6.6, 9.6] {
                    let top = IronViews.at(view, d.up(P(x, -26.4)), z: (6.6 - x) * 1.2)
                    let bottom = IronViews.at(view, P(x + 0.4, -17.4), z: (6.6 - x) * 1.2) + P(swing, 0)
                    d.svg.line([top, bottom], stroke: .colour(Ink.line), width: 2.4)
                    d.svg.line([top, bottom], stroke: .colour(IronWarriorsInk.leather), width: 1.1)
                    d.svg.circle(bottom, 0.9, fill: .colour(IronWarriorsInk.ironLight), stroke: .colour(Ink.line), width: 0.5)
                }
                // The shield, held before him, its face toward his front.
                let k = view == .front ? 1.0 : 0.76
                d.svg.raw("<g transform=\"translate(\(num(shieldAt.x)),0) scale(\(num(k)),1) translate(\(num(-shieldAt.x)),0)\">")
                Self.shield(&d.svg, at: shieldAt)
                d.svg.raw("</g>")
            }
            if !swordBehind { drawSword(&d) }
            d.arm(front: true, width: 2.1)
            // The iron plates over each shoulder.
            for z in [-Drawing.shoulderSpread, Drawing.shoulderSpread] {
                let s = IronViews.at(view, P(0.5, -44 - d.rig.lift), z: z)
                let flip = z < 0 ? -1.0 : 1.0
                IronWarriorsKit.shape(&d.svg, [s + P(-3.6 * flip, 0.6), s + P(-2 * flip, -2.8), s + P(2.4 * flip, -2.6), s + P(3.8 * flip, 0.8),
                                               s + P(3.2 * flip, 2.4), s + P(-3.2 * flip, 2.2)], fill: .colour(IronWarriorsInk.iron), width: 1.1)
                IronWarriorsKit.shape(&d.svg, [s + P(-2.8 * flip, 2.2), s + P(3 * flip, 2.4), s + P(2.8 * flip, 4.6), s + P(-2.4 * flip, 4.4)],
                                      fill: .colour(IronWarriorsInk.iron), width: 1)
            }
            d.head(nose: .curve, hair: { _ in }, features: { d in
                // A scar across the cheek, and the shadow of a beard along the jaw.
                switch d.view {
                case .front:
                    d.svg.path("M-6.8,-56.8 l3.4,2.6", stroke: .colour(Ink.line), width: 0.8, opacity: 0.7)
                    d.svg.path("M-5.8,-55 l0.8,-1 M-4.6,-54.2 l0.8,-1", stroke: .colour(Ink.line), width: 0.6, opacity: 0.6)
                    d.svg.path("M-6.6,-49.8 C-3,-47.4 3,-47.4 6.6,-49.8", stroke: .colour(Ink.line), width: 1, opacity: 0.45)
                case .frontQuarter:
                    d.svg.path("M6.2,-56.8 l3.4,2.6", stroke: .colour(Ink.line), width: 0.8, opacity: 0.7)
                    d.svg.path("M7.2,-55 l0.8,-1 M8.4,-54.2 l0.8,-1", stroke: .colour(Ink.line), width: 0.6, opacity: 0.6)
                    d.svg.path("M-1.4,-49.8 C2,-47.6 6.6,-47.6 10,-49.8", stroke: .colour(Ink.line), width: 1, opacity: 0.45)
                default:
                    break
                }
            }, brow: { d in
                d.svg.path("M1.4,-63.4 l7,-0.4", stroke: .colour(Ink.line), width: 2.1)
            }, over: { d in
                IronWarriorsKit.helmet(&d, crest: .brush)
            })
        }
    }

    /// The back of the shield centred on `c` and `width` across, seen from behind
    /// him: bare timber with a leather grip across, and the edge of its painted
    /// face, in the team's colour, curving round its outer side.
    static func shieldBack(_ svg: inout SVG, at c: P, width w: Double) {
        let h = 27.6
        svg.path(BronzePeopleProps.rounded(c, width: w, height: h, radius: 3.2, degrees: 0, shift: P(-0.8, 0.7)),
                 fill: .colour(IronWarriorsInk.paleWood))
        svg.path(BronzePeopleProps.rounded(c + P(-w / 2 + 1.6, 0), width: 3, height: h - 2, radius: 1.4, degrees: 0, shift: P(0, 0)),
                 fill: .team)
        svg.line([c + P(-w / 2 + 4, -2), c + P(w / 2 - 2, -2)], stroke: .colour(Ink.line), width: 2.6)
        svg.line([c + P(-w / 2 + 4, -2), c + P(w / 2 - 2, -2)], stroke: .colour(IronWarriorsInk.leather), width: 1.4)
        svg.path(BronzePeopleProps.rounded(c, width: w, height: h, radius: 3.2, degrees: 0, shift: P(0, 0)), stroke: .colour(Ink.line), width: 1.6)
    }

    /// A tall curved shield centred on `c`: its face in the team's colour,
    /// iron-bound at the rim, with an iron boss, a spine, wings and thunderbolts
    /// painted in the light.
    static func shield(_ svg: inout SVG, at c: P) {
        let w = 15.4, h = 27.6
        svg.path(BronzePeopleProps.rounded(c, width: w, height: h, radius: 3.2, degrees: 0, shift: P(-0.8, 0.7)), fill: .team)
        // The curve of the shield: a shade down its far edge.
        svg.path(BronzePeopleProps.rounded(c + P(-w / 2 + 1.6, 0), width: 2.4, height: h - 3, radius: 1.2, degrees: 0, shift: P(-0.8, 0.7)),
                 fill: .colour(Ink.line), opacity: 0.18)
        // The painted device: a spine, a pair of wings above and below the boss, and thunderbolts.
        let light = Paint.colour(IronWarriorsInk.light)
        svg.line([c + P(0, -h / 2 + 2.6), c + P(0, h / 2 - 2.6)], stroke: light, width: 1.3)
        for side in [-1.0, 1.0] {
            var wing = PathData()
            let root = c + P(0, side * 5.4)
            wing.move(root)
            wing.quad(root + P(-3, side * -0.6 - 2.4), root + P(-5.4, side * 1.4 - 1.2))
            wing.move(root)
            wing.quad(root + P(3, side * -0.6 - 2.4), root + P(5.4, side * 1.4 - 1.2))
            svg.path(wing, stroke: light, width: 1.3)
            for dir in [-1.0, 1.0] {
                let start = c + P(dir * 3.2, side * 1.6)
                svg.line([start, start + P(dir * 1.6, side * 1.4), start + P(dir * 0.8, side * 2.4), start + P(dir * 2.8, side * 4.2)],
                         stroke: light, width: 0.9)
            }
        }
        // The iron binding along the rim, and the outline.
        svg.path(BronzePeopleProps.rounded(c, width: w - 1.6, height: h - 1.6, radius: 2.6, degrees: 0, shift: P(0, 0)),
                 stroke: .colour(IronWarriorsInk.iron), width: 1.4)
        svg.path(BronzePeopleProps.rounded(c, width: w, height: h, radius: 3.2, degrees: 0, shift: P(0, 0)), stroke: .colour(Ink.line), width: 1.6)
        // The boss.
        svg.circle(c + P(-0.4, 0.4), 3.2, fill: .colour(IronWarriorsInk.iron))
        svg.circle(c, 3.2, fill: .none, stroke: .colour(Ink.line), width: 1.1)
        svg.circle(c + P(-0.8, -0.9), 1.1, fill: .colour(IronWarriorsInk.ironLight))
    }
}
