// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The foot warfighter of the Bronze look: the spearman. He keeps this look in
// every later age (`SpriteSubject.of(_:ownerAge:)`). He is drawn on a canvas
// wider in front than a person's, for the spear's thrust. The checklist asks a working pose of them; they do not
// work, so it is their standing cycle.

// MARK: - The spearman

/// A spearman of the phalanx: a bronze helmet with a neck guard and a leather
/// chin strap, a leather cloak studded with bronze, a verdigris kilt fringed at
/// the hem, a moustache; nose C. A long spear with a bronze leaf blade, and a
/// round shield painted in the team's colour with a light star, a bronze boss
/// and a studded rim, held before him. Fighting, he draws the spear back and
/// thrusts it home.
struct BronzePeopleSpearman: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing, .working:
            var r = Moves.standing(frame)
            r.backLeg = Limb(-6, 4); r.frontLeg = Limb(7, 4)
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(15.4, -38.6 - r.lift))
            r.backArm = Limb(36, 40)
            r.mouth = .firm
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 24)
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(15.4 + 1.2 * r.sway, -38.6))
            r.backArm = Limb(36, 40)
            r.mouth = .firm
            return r
        case .fighting:
            var r = Rig()
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), Self.thrust[frame], elbowUp: true)
            r.backArm = Limb(40, 40)
            r.backLeg = Limb(-18, 6)
            r.frontLeg = frame >= 6 && frame <= 9 ? Limb(26, 14) : Limb(14, 8)
            r.lean = [0, -1, -2, -3, -4, -4, 4, 10, 10, 7, 3, 1][frame]
            r.mouth = frame == 7 || frame == 8 ? .shout : .firm
            r.eyes = frame == 8 ? .wide : .open
            return r
        default:
            return nil
        }
    }

    /// The spear hand through the thrust: drawn back over six frames, driven
    /// home on the seventh and eighth, and brought back to the ready.
    static let thrust: [P] = [P(10, -46), P(8, -46.4), P(5, -47), P(2, -47.4), P(0, -47.8), P(-1, -48),
                              P(9, -46), P(19, -44.6), P(21, -44.2), P(17.4, -45), P(14, -45.6), P(12, -46)]

    /// The spear's direction from the hand: upright, or level for the thrust, its blade a little down.
    static func spearDegrees(_ pose: SpritePose, _ frame: Int, sway: Double) -> Double {
        switch pose {
        case .fighting: 86
        case .walking: 180 - 6 - 2 * sway
        default: 180 - 3
        }
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        d.figure { d in
            d.arm(front: false, width: 2.1)
            d.legs()
            // The leather cloak, studded with bronze.
            d.garment(colour: [P(-12.4, -46), P(9, -48), P(13.4, -24), P(-14.6, -23.4)],
                      outline: [P(-8.4, -47), P(8.8, -47), P(12.2, -25.4), P(-13.2, -25.4)], fill: .colour(BronzePeopleInk.leather)) { d in
                for row in 0..<4 {
                    for column in 0..<4 {
                        let c = P(-9 + Double(column) * 5.4 + Double(row % 2) * 2.4, -43.6 + Double(row) * 5.2)
                        d.svg.circle(d.up(c), 1, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.5)
                    }
                }
            }
            // The kilt, pleated in the light and fringed at the hem.
            d.garment(colour: [P(-14, -27), P(12.6, -28), P(15.6, -11.6), P(-17, -11)],
                      outline: [P(-12.6, -26.6), P(12, -26.6), P(14.2, -13.4), P(-15.2, -13.4)], fill: .colour(BronzePeopleInk.verdigris)) { d in
                var pleats = PathData()
                for x in stride(from: -9.0, through: 9.0, by: 4.5) {
                    pleats.move(P(x, -25)); pleats.line(P(x * 1.18, -14.6))
                }
                d.svg.path(pleats, stroke: .colour(BronzePeopleInk.paleVerdigris), width: 1)
            }
            var fringe = PathData()
            for i in 0..<12 {
                let x = -14.6 + Double(i) * 2.55
                fringe.move(P(x, -13.4)); fringe.line(P(x - 0.3, -10.8))
            }
            d.svg.path(fringe, stroke: .colour(Ink.line), width: 1)
            d.svg.line([d.up(P(-12.8, -26.8)), d.up(P(12.2, -27.2))], stroke: .colour(BronzePeopleInk.darkVerdigris), width: 2.2)
            // The shield, held before him.
            let push = pose == .fighting ? [0.0, -0.4, -0.8, -1.2, -1.6, -1.6, 0.6, 2.4, 2.4, 1.6, 0.8, 0.2][frame] : 0
            Self.shield(&d.svg, at: d.up(P(-1.6 + push, -33.4)) + P(0, pose == .walking ? 0.6 * sway : 0), radius: 12.4)
            // The spear, through the front hand.
            let hand = d.joints.frontHand
            let degrees = Self.spearDegrees(pose, frame, sway: sway)
            switch pose {
            case .fighting:
                Self.spear(&d.svg, at: hand, degrees: degrees, ahead: 40, behind: 27)
                let tip = hand + P.direction(degrees) * 40
                if frame == 7 { d.svg.path("M\(num(tip.x - 26)),\(num(tip.y - 3.4)) l12,0.6 M\(num(tip.x - 24)),\(num(tip.y + 3.6)) l12,-0.4",
                                           stroke: .colour(Ink.line), width: 1.1, opacity: 0.6) }
                if frame == 8 { d.impact(at: tip + P(2, 0), size: 1.1) }
            default:
                // Upright: its butt rests on the ground beside the front foot, and is
                // carried clear of the ground on the march.
                let below = max(4, -d.bob - hand.y - (pose == .walking ? 7 : 0.6))
                Self.spear(&d.svg, at: hand, degrees: degrees, ahead: 54, behind: below)
            }
            d.arm(front: true, width: 2.1)
            d.head(nose: .hook, hair: { _ in }, features: { d in
                // A moustache.
                d.svg.path("M3.4,-52.8 q3.8,-2 7.6,-0.2 q-1.6,1.4 -3.8,0.8 q-2.2,0.8 -3.8,-0.6 Z", fill: .colour(Ink.line))
            }, brow: { d in
                d.svg.path("M1.6,-63.2 l6.6,0.6", stroke: .colour(Ink.line), width: 2)
            }, over: { d in
                Self.helmet(&d)
            })
        }
    }

    /// A long spear through `hand`: its blade `ahead` along `degrees`, its butt `behind`.
    static func spear(_ svg: inout SVG, at hand: P, degrees: Double, ahead: Double, behind: Double) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let tip = hand + u * ahead, butt = hand - u * behind
        svg.line([butt, tip - u * 7], stroke: .colour(Ink.line), width: 2.8)
        svg.line([butt + u * 0.6, tip - u * 7.2], stroke: .colour(BronzePeopleInk.wood), width: 1.5)
        // The leaf-shaped blade and its socket.
        let base = tip - u * 9
        var blade = PathData()
        blade.move(base)
        blade.quad(base + u * 3.4 + a * 3.4, tip)
        blade.quad(base + u * 3.4 - a * 3.4, base)
        blade.close()
        svg.path(blade, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 1)
        svg.line([base + u * 1, tip - u * 1.4], stroke: .colour(BronzePeopleInk.bronzeLight), width: 0.7)
        svg.line([base - a * 1.3, base + a * 1.3], stroke: .colour(Ink.line), width: 1.2)
        // The bronze butt spike.
        svg.polygon([butt + a * 1.1, butt - a * 1.1, butt - u * 2.6], fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.7)
    }

    /// A round shield face-on, painted in the team's colour with an eight-pointed
    /// star in the light, a bronze boss and a rim studded with bronze.
    static func shield(_ svg: inout SVG, at c: P, radius r: Double) {
        svg.circle(c + P(-0.8, 0.7), r, fill: .team)
        var star = PathData()
        for i in 0..<16 {
            let angle = Double(i) * 22.5
            let p = c + P.direction(angle) * (i % 2 == 0 ? r * 0.62 : r * 0.27)
            if i == 0 { star.move(p) } else { star.line(p) }
        }
        star.close()
        svg.path(star, fill: .colour(BronzePeopleInk.light))
        svg.circle(c, r - 1.2, fill: .none, stroke: .colour(BronzePeopleInk.bronze), width: 2.2)
        svg.circle(c, r, fill: .none, stroke: .colour(Ink.line), width: 1.6)
        svg.circle(c, r - 2.4, fill: .none, stroke: .colour(Ink.line), width: 0.8)
        for i in 0..<10 {
            svg.circle(c + P.direction(Double(i) * 36 + 18) * (r - 1.2), 0.75, fill: .colour(BronzePeopleInk.bronzeLight),
                       stroke: .colour(Ink.line), width: 0.4)
        }
        svg.circle(c, r * 0.22, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 1)
        svg.circle(c + P(-0.6, -0.7), r * 0.08, fill: .colour(BronzePeopleInk.bronzeLight))
    }

    /// A bronze helmet with a neck guard, a rim, a knob at the crown and a
    /// leather strap under the chin.
    static func helmet(_ d: inout Drawing) {
        d.svg.path("M-6.6,-57.4 C-4.6,-52.6 -1.2,-48.4 3.6,-46.8", stroke: .colour(BronzePeopleInk.leather), width: 1.4)
        BronzePeopleProps.shape(&d.svg, fill: .colour(BronzePeopleInk.bronze), width: 1.5) { o in
            var p = PathData()
            p.move(P(-12.2, -56.4) + o)
            p.cubic(P(-13.6, -72.6) + o, P(5.4, -77.4) + o, P(11.4, -63.6) + o)
            p.line(P(11.8, -61.8) + o)
            p.cubic(P(5.4, -64.2) + o, P(-3.4, -63.2) + o, P(-8.8, -58.2) + o)
            p.line(P(-9.8, -52.2) + o)
            p.line(P(-12.8, -53) + o)
            p.close()
            return p
        }
        d.svg.path("M11,-62.4 C5,-64.8 -3.6,-63.8 -9,-58.8", stroke: .colour(BronzePeopleInk.bronzeDark), width: 1.2)
        d.svg.path("M-6.4,-70.4 C-3.4,-73 1.6,-73.4 5.2,-71.4", stroke: .colour(BronzePeopleInk.bronzeLight), width: 1.1)
        d.svg.circle(P(-1.4, -74.6), 1.7, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 1)
    }
}

extension BronzePeopleSpearman {
    /// The spearman seen from another side: the studs, pleats, fringe and belt
    /// spread round the cloak and kilt, the shield on his left arm before him
    /// (its painted face toward the viewer from in front, its back and rim from
    /// behind), the spear in the figure's own plane, and the helmet, chin strap
    /// and moustache as the view shows them.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway
        let back = BronzePeopleViews.seesBack(d.view)
        d.figure { d in
            let cloak = [P(-8.4, -47), P(8.8, -47), P(12.2, -25.4), P(-13.2, -25.4)]
            let kilt = [P(-12.6, -26.6), P(12, -26.6), P(14.2, -13.4), P(-15.2, -13.4)]
            let spearBehind = d.armBehind(front: true)
            let push = pose == .fighting ? [0.0, -0.4, -0.8, -1.2, -1.6, -1.6, 0.6, 2.4, 2.4, 1.6, 0.8, 0.2][frame] : 0
            if back { Self.shieldInView(&d, push: push, sway: pose == .walking ? sway : 0) }
            d.arm(front: false, width: 2.1)
            d.legs()
            if spearBehind { Self.spearInView(&d, pose, frame) }
            d.garment(colour: [P(-12.4, -46), P(9, -48), P(13.4, -24), P(-14.6, -23.4)],
                      outline: cloak, fill: .colour(BronzePeopleInk.leather)) { d in
                for row in 0..<4 {
                    let y = -43.6 + Double(row) * 5.2
                    guard let seen = BronzePeopleViews.span(d.turned(cloak), at: y) else { continue }
                    for column in 0..<4 {
                        let t = (Double(column) + 0.5 + Double(row % 2) * 0.4) / 4.4
                        let c = P(seen.low + 1.6 + (seen.high - seen.low - 3.2) * t, y)
                        d.svg.circle(d.up(c), 1, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.5)
                    }
                }
            }
            d.garment(colour: [P(-14, -27), P(12.6, -28), P(15.6, -11.6), P(-17, -11)],
                      outline: kilt, fill: .colour(BronzePeopleInk.verdigris)) { d in
                var pleats = PathData()
                for x in stride(from: -9.0, through: 9.0, by: 4.5) {
                    pleats.move(BronzePeopleViews.spread(d, P(x, -25), on: kilt))
                    pleats.line(BronzePeopleViews.spread(d, P(x * 1.18, -14.6), on: kilt))
                }
                d.svg.path(pleats, stroke: .colour(BronzePeopleInk.paleVerdigris), width: 1)
            }
            var fringe = PathData()
            for i in 0..<12 {
                let p = BronzePeopleViews.spread(d, P(-14.6 + Double(i) * 2.55, -13.6), on: kilt)
                fringe.move(P(p.x, -13.4)); fringe.line(P(p.x - 0.3, -10.8))
            }
            d.svg.path(fringe, stroke: .colour(Ink.line), width: 1)
            if let belt = BronzePeopleViews.span(d.turned(kilt), at: -26.4) {
                d.svg.line([d.up(P(belt.low - 0.2, -26.8)), d.up(P(belt.high + 0.2, -27.2))], stroke: .colour(BronzePeopleInk.darkVerdigris), width: 2.2)
            }
            if !back { Self.shieldInView(&d, push: push, sway: pose == .walking ? sway : 0) }
            if !spearBehind { Self.spearInView(&d, pose, frame) }
            d.arm(front: true, width: 2.1)
            d.head(nose: .hook, hair: { _ in }, features: { d in
                guard d.view == .front || d.view == .frontQuarter else { return }
                let moustache = [P(-5.4, -51.2), P(-2.4, -53.2), P(0, -52.4), P(2.4, -53.2), P(5.4, -51.2), P(2.4, -50.6), P(0, -51),
                                 P(-2.4, -50.6)]
                d.svg.polygon(BronzePeopleViews.onFace(d.view, moustache.map { $0 + P(d.view == .frontQuarter ? 0.8 : 0, 0) }),
                              fill: .colour(Ink.line))
            }, brow: { d in
                d.svg.path("M1.6,-63.2 l6.6,0.6", stroke: .colour(Ink.line), width: 2)
            }, over: { d in
                Self.helmetInView(&d)
            })
        }
    }

    /// The helmet's edge round the head: over the brow in front, down to the neck guard behind.
    static let helmetEdge = BronzePeopleViews.edge(front: -62.4, side: -59.6, back: -52.6)

    /// The bronze helmet: its dome with the neck guard, the dark line along its
    /// edge, a highlight, the knob at the crown, and the chin strap where it shows.
    static func helmetInView(_ d: inout Drawing) {
        let view = d.view
        // The chin strap, from under the helmet at each side to under the chin.
        if view == .front || view == .frontQuarter {
            let ends = view == .front ? [P(-9.6, -57.4), P(9.6, -57.4)] : [P(-6.4, -57.4)]
            let chin = BronzePeopleViews.onFace(view, [P(0, -46.9)])[0]
            for end in ends {
                var strap = PathData()
                strap.move(end); strap.quad(P(end.x * 0.8 + chin.x * 0.2, -48.4), chin)
                d.svg.path(strap, stroke: .colour(BronzePeopleInk.leather), width: 1.4)
            }
        }
        let dome = BronzePeopleViews.dome(view, out: 1, crown: 3.6, rim: helmetEdge)
        BronzePeopleProps.shape(&d.svg, dome, fill: .colour(BronzePeopleInk.bronze), width: 1.5)
        let rim = BronzePeopleViews.ring(view, out: 1.2) { helmetEdge($0) - 1 }
        d.svg.line(Array(rim.dropFirst(1).dropLast(1)), stroke: .colour(BronzePeopleInk.bronzeDark), width: 1.2)
        let shine = BronzePeopleViews.ring(view, out: 2.4) { _ in -71.4 }
        d.svg.line(Array(shine[5...16]), stroke: .colour(BronzePeopleInk.bronzeLight), width: 1.1)
        let top = dome.map(\.y).min() ?? -74
        d.svg.circle(P(dome.first { $0.y == top }?.x ?? 0, top - 0.4), 1.7, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 1)
    }

    /// The spear in the figure's own plane: upright with its butt on the ground,
    /// or level for the thrust, foreshortened as the view turns it.
    static func spearInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let hand = d.hand(front: true)
        let (degrees, reach) = BronzePeopleViews.onScreen(d.view, spearDegrees(pose, frame, sway: d.rig.sway))
        switch pose {
        case .fighting:
            spear(&d.svg, at: hand, degrees: degrees, ahead: max(40 * reach, 12), behind: max(27 * reach, 6))
            if frame == 8 { d.impact(at: hand + P.direction(degrees) * max(40 * reach, 12) + P(0, -1), size: 1.1) }
        default:
            let below = max(4, -d.bob - hand.y - (pose == .walking ? 7 : 0.6))
            spear(&d.svg, at: hand, degrees: degrees, ahead: 54, behind: below)
        }
    }

    /// The round shield on his left arm before him: its painted face from in
    /// front, its back from behind, as wide as the view shows it, with a rim
    /// of the team's colour round its back.
    static func shieldInView(_ d: inout Drawing, push: Double, sway: Double) {
        let yaw = d.yaw * .pi / 180
        let x = 15 + push, z = -4.0
        let c = d.up(P(x * cos(yaw) - z * sin(yaw), -33.4)) + P(0, 0.6 * sway)
        let facing = sin(yaw)
        let squash = max(abs(facing), 0.3)
        d.svg.raw("<g transform=\"translate(\(num(c.x)),\(num(c.y))) scale(\(num(squash)),1) translate(\(num(-c.x)),\(num(-c.y)))\">")
        if facing > 0 {
            shield(&d.svg, at: c, radius: 12.4)
        } else {
            // The back: leather over wood, a rim of the team's colour, and the grip across.
            d.svg.circle(c + P(-0.8, 0.7), 12.4, fill: .team)
            d.svg.circle(c, 8.2, fill: .colour(BronzePeopleInk.leather))
            d.svg.circle(c, 12.4, fill: .none, stroke: .colour(Ink.line), width: 1.6)
            d.svg.circle(c, 8.2, fill: .none, stroke: .colour(Ink.line), width: 0.8)
            d.svg.line([c + P(-5.4, 0), c + P(5.4, 0)], stroke: .colour(Ink.line), width: 2.6)
            d.svg.line([c + P(-5.4, 0), c + P(5.4, 0)], stroke: .colour(BronzePeopleInk.wood), width: 1.3)
        }
        d.svg.raw("</g>")
    }
}
