// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The caravan trader (merchant)

/// A caravan trader in a long sea-green robe striped with the light, a red
/// sash, a light headcloth bound with a red cord whose end falls to his
/// shoulder, a gold ring in his ear and a black pointed beard; nose A. On his
/// back a bundle of goods wrapped in the team's colour; in his back hand the
/// lead of a laden donkey that walks behind him, its saddle-cloth of the team's
/// colour. At work he tosses a gold coin, watches it turn in the air, and
/// catches it. The drawing's origin is between the trader's feet; the canvas
/// reaches back for the donkey.
struct IronPeopleTrader: PersonLook {
    /// `Canvas.person` with 56 more units behind, for the donkey: 190 by 135 pixels.
    static let canvas = Canvas(minX: -92, minY: -102, width: 152, height: 108, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// Where the donkey stands: behind the trader and a little farther from the viewer.
    static let donkeyAt = P(-62, -3)

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(9.6, -40.4 - r.lift))
            r.backArm = Limb(-24, -16)
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 20, kneeLift: 38, armSwing: 22)
            r.lean = 4
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(10.4, -38.6))
            r.backArm = Limb(-38 + 4 * BronzePeopleKit.wave(frame), -12)
            return r
        case .working:
            var r = Moves.standing(frame)
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), Self.tossHand[frame])
            r.backArm = Limb(-24, -16)
            let coin = Self.coin(frame)
            // He follows the coin with his eyes and his head.
            r.headTilt = coin.flying ? max(-9, (coin.at.y + 50) * 0.5) : 2
            r.eyes = coin.flying ? .wide : (frame == 11 ? .closed : .down)
            r.mouth = frame >= 9 ? .smile : (coin.flying ? .murmur : .smile)
            return r
        default:
            return nil
        }
    }

    // MARK: The toss

    /// The tossing hand: dipped, flicked up on the second frame, and waiting to
    /// catch the coin as it falls back on the ninth.
    static let tossHand: [P] = [P(13.6, -36), P(14.6, -41.6), P(15, -40), P(14.6, -38.4), P(14.6, -38), P(14.8, -38.2),
                                P(15, -38.6), P(15.2, -39.2), P(15.2, -39.4), P(15, -38), P(14.2, -36.4), P(13.8, -35.6)]

    /// Where the coin is in a frame, and whether it is in the air.
    static func coin(_ frame: Int) -> (at: P, flying: Bool) {
        let hand = tossHand[frame]
        guard frame >= 2 && frame <= 8 else { return (hand + P(1.6, -2), false) }
        // Up from the hand on the second frame and back into it on the ninth.
        let t = Double(frame - 1) / 8
        let start = tossHand[1] + P(1.6, -2), end = tossHand[9] + P(1.6, -2)
        let x = mix(start.x, end.x, t) + 2.4 * sin(t * .pi)
        let y = mix(start.y, end.y, t) - 26 * 4 * t * (1 - t)
        return (P(x, y), true)
    }

    // MARK: The donkey

    /// How the donkey stands in a frame of a pose.
    static func donkeyPose(_ pose: SpritePose, _ frame: Int) -> IronPeopleDonkey.Pose {
        let t = Double(frame) / 12
        var p = IronPeopleDonkey.Pose()
        if pose == .walking {
            // A walk: each foot in turn, the hind before the fore on each side.
            func leg(_ shift: Double, fore: Bool) -> Limb {
                let phase = (t + shift).truncatingRemainder(dividingBy: 1)
                let swing = 0.36
                let reach = fore ? 22.0 : 18.0, back = fore ? -18.0 : -24.0
                if phase < swing {
                    let s = phase / swing
                    return Limb(mix(back, reach, ease(s)), (fore ? 64 : 46) * sin(.pi * s))
                }
                let s = (phase - swing) / (1 - swing)
                return Limb(mix(reach, back, s), fore ? 2 : 6)
            }
            p.nearHind = leg(0, fore: false); p.nearFore = leg(0.25, fore: true)
            p.farHind = leg(0.5, fore: false); p.farFore = leg(0.75, fore: true)
            p.neck = 3 * sin(4 * .pi * t)
            p.tail = 0.6 * sin(2 * .pi * t)
            p.lift = 0.5 * sin(4 * .pi * t)
        } else {
            let s = 2 * .pi * t
            p.lift = 0.35 * sin(s)
            p.neck = 2 + 2.6 * pow(max(0, sin(s + 0.8)), 3)
            p.tail = sin(s)
            p.earFlick = frame >= 4 && frame <= 6 ? (frame == 5 ? 1 : 0.6) : 0
            p.blink = frame == 7
        }
        return p
    }

    // MARK: Drawing

    /// The trader's robe: wide at the hem, its back swinging with the stride.
    static func robe(_ d: Drawing, _ o: P, sway: Double) -> PathData {
        func at(_ p: P) -> P { d.up(p) + o }
        var p = PathData()
        p.move(at(P(-8.4, -47)))
        p.line(at(P(8.6, -47)))
        p.cubic(at(P(11.6, -40)), at(P(13.4, -24)), at(P(15.6 - sway * 1.6, -6)))
        p.line(at(P(-16 - sway * 1.6, -6)))
        p.cubic(at(P(-13.4, -24)), at(P(-11.6, -40)), at(P(-8.4, -47)))
        p.close()
        return p
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let donkey = IronPeopleDonkey(at: Self.donkeyAt, pose: Self.donkeyPose(pose, frame))
        donkey.draw(&d.svg)
        // The lead, from his back hand to the donkey's halter.
        let hand = d.world(d.joints.backHand)
        var lead = PathData()
        let slack = pose == .walking ? 2.4 : 5
        lead.move(hand); lead.quad((hand + donkey.halter) * 0.5 + P(0, slack), donkey.halter)
        d.svg.path(lead, stroke: .colour(Ink.line), width: 1.6)
        d.svg.path(lead, stroke: .colour(IronPeopleInk.red), width: 0.7)
        let sway = d.rig.sway
        let bounce = pose == .walking ? 1.2 * BronzePeopleKit.wave(frame, -0.2, times: 2) : 0.3 * BronzePeopleKit.wave(frame)
        d.figure { d in
            // The bundle on his back.
            IronPeopleProps.pack(&d.svg, at: d.up(P(-15.8, -43.6)) + P(0, bounce), width: 11, height: 15, degrees: -6)
            d.arm(front: false)
            d.legs()
            d.svg.path(Self.robe(d, P(-1, 1), sway: sway), fill: .colour(IronPeopleInk.darkSea))
            // Stripes of the light down the robe.
            var stripes = PathData()
            for x in [-9.0, -4.4, 0.2, 4.8, 9.4] {
                let spread = x / 9.4
                stripes.move(d.up(P(x * 0.8, -45))); stripes.line(P(x + spread * 4 - sway * 1.4 * (1 - abs(spread) * 0.2), -7))
            }
            d.svg.path(stripes, stroke: .colour(IronPeopleInk.paleSea), width: 1.2)
            d.svg.path(Self.robe(d, P(0, 0), sway: sway), stroke: .colour(Ink.line), width: 1.8)
            // The red sash, its ends hanging at the front.
            d.svg.polygon([P(-12.4, -32), P(12.2, -32.8), P(12.8, -27.4), P(-13, -26.6)].map(d.up), fill: .colour(IronPeopleInk.red),
                          stroke: .colour(Ink.line), width: 0.9)
            d.svg.polygon([P(9.6, -28), P(11.8, -28), P(13.4 - sway, -18.6), P(11, -18.4)], fill: .colour(IronPeopleInk.red),
                          stroke: .colour(Ink.line), width: 0.8)
            IronPeopleProps.purse(&d.svg, at: d.up(P(4, -27.6)))
            // The bundle's strap, over the shoulder.
            d.svg.line([d.up(P(-11, -50)), d.up(P(-4, -47.4)), d.up(P(4.4, -45)), d.up(P(9.6, -38))],
                       stroke: .colour(IronPeopleInk.leather), width: 1.9)
            if pose == .working {
                let coin = Self.coin(frame)
                let turn = Double(frame) * .pi / 3.4
                IronPeopleProps.coin(&d.svg, at: coin.at, face: coin.flying ? cos(turn) : 1)
                if frame == 9 { d.svg.path("M\(num(coin.at.x - 3.4)),\(num(coin.at.y - 3)) l-1.4,-1.4 M\(num(coin.at.x + 3.6)),\(num(coin.at.y - 3)) l1.4,-1.4",
                                           stroke: .colour(Ink.line), width: 0.9) }
            }
            d.arm(front: true)
            let flutter = pose == .walking ? BronzePeopleKit.wave(frame, times: 2) : 0.3 * BronzePeopleKit.wave(frame)
            d.head(nose: .curve, behind: { d in
                // The headcloth falling to the shoulder behind.
                BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.light), width: 1.3) { o in
                    var p = PathData()
                    p.move(P(-10.4, -62) + o)
                    p.cubic(P(-13.4, -56) + o, P(-14.6 - flutter, -50) + o, P(-13.6 - flutter * 1.4, -44.6) + o)
                    p.line(P(-7.4, -46.4) + o)
                    p.cubic(P(-8.4, -51) + o, P(-7.6, -55) + o, P(-5.6, -58) + o)
                    p.close()
                    return p
                }
                d.svg.path("M\(num(-12.6 - flutter)),-47.6 l4.6,-1", stroke: .colour(IronPeopleInk.red), width: 1)
            }, hair: { d in
                d.svg.path("M-9.4,-58.6 C-10.4,-55.4 -9.6,-52.4 -7.2,-50.6 C-7.6,-53 -7.2,-55.4 -6,-57.4 Z", fill: .colour(Ink.line))
            }, features: { d in
                // A black beard, trimmed to a point, and a moustache.
                d.svg.path("M-5.2,-54.2 C-5.8,-49.4 -3.4,-45.6 1,-43.6 C3.6,-42.4 6.4,-41.2 8.8,-38.6 C8.8,-42 10.6,-45.2 11.2,-49.4 "
                           + "C9,-48.6 6.4,-48.8 4.4,-49.6 C1.2,-50.8 -2,-52.6 -5.2,-54.2 Z", fill: .colour(Ink.line))
                d.svg.path("M4,-52.6 q3.6,-2.2 7.4,-0.4 q-1.2,1.8 -3.6,1 q-2.4,0.8 -3.8,-0.6 Z", fill: .colour(Ink.line))
            }, brow: { d in
                d.svg.path("M1.4,-63.4 q3.4,-2.2 7.2,-0.8", stroke: .colour(Ink.line), width: 1.7)
            }, over: { d in
                // The headcloth over the crown, bound with a doubled red cord.
                BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.light), width: 1.5) { o in
                    var p = PathData()
                    p.move(P(-11.2, -57) + o)
                    p.cubic(P(-13, -70) + o, P(4, -76.4) + o, P(11, -64.4) + o)
                    p.cubic(P(10.4, -63) + o, P(9.4, -62.6) + o, P(8.4, -62.8) + o)
                    p.cubic(P(2, -65) + o, P(-4.6, -63.6) + o, P(-7, -58) + o)
                    p.close()
                    return p
                }
                d.svg.path("M10.2,-66.2 C3.6,-69.4 -4.6,-68.6 -11.2,-63", stroke: .colour(Ink.line), width: 2.8)
                d.svg.path("M10.2,-66.2 C3.6,-69.4 -4.6,-68.6 -11.2,-63", stroke: .colour(IronPeopleInk.red), width: 1.5)
                // A gold ring in the ear.
                d.svg.circle(P(-9.6, -53.6), 1.5, fill: .none, stroke: .colour(Ink.line), width: 1.7)
                d.svg.circle(P(-9.6, -53.6), 1.5, fill: .none, stroke: .colour(IronPeopleInk.gold), width: 0.9)
            })
        }
    }
}

// MARK: - The trader and his donkey in the other views

extension IronPeopleTrader {
    /// How far to the trader's left the donkey walks, seen from another side,
    /// so that it neither hides him nor is hidden by him.
    static let donkeyAside = -20.0

    /// The trader seen from the front, from behind, or from a quarter turn,
    /// with his donkey behind him and to his left: drawn before him when it is
    /// the farther, after him when it is the nearer.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view, behind = IronViews.fromBehind(view)
        let placed = IronViews.project(view, P(Self.donkeyAt.x, 0), z: Self.donkeyAside)
        let donkey = IronPeopleDonkey(at: placed.point + P(0, placed.depth < 0 ? Self.donkeyAt.y : 1.5), pose: Self.donkeyPose(pose, frame))
        let halter = donkey.halter(view)
        let hand = IronViews.world(d, d.hand(front: false))
        func lead(_ svg: inout SVG) {
            var lead = PathData()
            let slack = pose == .walking ? 2.4 : 5
            lead.move(hand); lead.quad((hand + halter) * 0.5 + P(0, slack), halter)
            svg.path(lead, stroke: .colour(Ink.line), width: 1.6)
            svg.path(lead, stroke: .colour(IronPeopleInk.red), width: 0.7)
        }
        let nearer = placed.depth > 0
        if !nearer { donkey.draw(&d.svg, view: view); lead(&d.svg) }
        let sway = d.rig.sway * IronViews.turn(view).c
        let bounce = pose == .walking ? 1.2 * BronzePeopleKit.wave(frame, -0.2, times: 2) : 0.3 * BronzePeopleKit.wave(frame)
        d.figure { d in
            // The bundle on his back: as wide as his shoulders, and deeper than it is wide.
            let pack = IronViews.at(view, d.up(P(-15.8, -43.6)), z: 0) + P(0, bounce)
            let packWidth = view == .front || view == .back ? 17.0 : 13.0
            if !behind { IronPeopleProps.pack(&d.svg, at: pack, width: packWidth, height: 15, degrees: 0) }
            let toss = d.hand(front: true)
            let tossBehind = d.armBehind(front: true)
            func coin(_ d: inout Drawing) {
                guard pose == .working else { return }
                let coin = Self.coin(frame)
                let at = toss + IronViews.flat(view, coin.at - Self.tossHand[frame])
                let turn = Double(frame) * .pi / 3.4
                IronPeopleProps.coin(&d.svg, at: at, face: coin.flying ? cos(turn) : 1)
                if frame == 9 { d.svg.path("M\(num(at.x - 3.4)),\(num(at.y - 3)) l-1.4,-1.4 M\(num(at.x + 3.6)),\(num(at.y - 3)) l1.4,-1.4",
                                           stroke: .colour(Ink.line), width: 0.9) }
            }
            if tossBehind { coin(&d) }
            d.arm(front: false)
            d.legs()
            let robe = Self.robeShape(sway: sway)
            d.garment(colour: robe.map { $0 + P(-1, 1) }, outline: robe, fill: .colour(IronPeopleInk.darkSea)) { d in
                // Stripes of the light down the robe, spread across it.
                let top = IronViews.span(d, robe, at: -45), hem = IronViews.span(d, robe, at: -7)
                var stripes = PathData()
                for f in [0.12, 0.31, 0.5, 0.69, 0.88] {
                    stripes.move(d.up(P(top.left + (top.right - top.left) * f, -45)))
                    stripes.line(P(hem.left + (hem.right - hem.left) * f, -7))
                }
                d.svg.path(stripes, stroke: .colour(IronPeopleInk.paleSea), width: 1.2)
            }
            // The red sash, its ends hanging at the front, and the purse at his belt.
            d.svg.polygon(IronViews.around(d, [P(-12.4, -32), P(12.2, -32.8), P(12.8, -27.4), P(-13, -26.6)]), fill: .colour(IronPeopleInk.red),
                          stroke: .colour(Ink.line), width: 0.9)
            if !behind {
                let knot = IronViews.at(view, P(10.6, -28), z: 3)
                let end = knot + IronViews.flat(view, P(2.6 - sway, 9.4))
                d.svg.polygon([knot + P(-1.1, 0), knot + P(1.1, 0), end + P(1.2, 0), end + P(-1.2, 0)], fill: .colour(IronPeopleInk.red),
                              stroke: .colour(Ink.line), width: 0.8)
                IronPeopleProps.purse(&d.svg, at: IronViews.at(view, d.up(P(4, -27.6)), z: -6))
                // The bundle's strap, over his right shoulder and down to the chest.
                let strap = [(P(-11, -50), 6.0), (P(-4, -47.4), 7.4), (P(4.4, -45), 5.6), (P(9.6, -38), 1.0)].map {
                    IronViews.at(view, d.up($0.0), z: $0.1)
                }
                d.svg.line(strap, stroke: .colour(IronPeopleInk.leather), width: 1.9)
            } else {
                IronPeopleProps.pack(&d.svg, at: pack, width: packWidth, height: 15, degrees: 0)
            }
            if !tossBehind { coin(&d) }
            d.arm(front: true)
            let flutter = pose == .walking ? BronzePeopleKit.wave(frame, times: 2) : 0.3 * BronzePeopleKit.wave(frame)
            d.head(nose: .curve, behind: { d in
                if d.view == .frontQuarter { Self.fallingCloth(&d, flutter: flutter) }
                if d.view == .front {
                    // The headcloth falling to both shoulders behind the head.
                    for flip in [1.0, -1.0] {
                        d.svg.raw("<g transform=\"scale(\(num(flip)),1)\">")
                        BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.light), width: 1.3) { o in
                            var p = PathData()
                            p.move(P(-10.6, -62) + o)
                            p.cubic(P(-13.4, -56) + o, P(-14 - flutter * 0.6, -50) + o, P(-13.4 - flutter * 0.8, -45.4) + o)
                            p.line(P(-7.4, -46.4) + o)
                            p.cubic(P(-8.6, -51) + o, P(-8.6, -55) + o, P(-8, -58) + o)
                            p.close()
                            return p
                        }
                        d.svg.raw("</g>")
                    }
                }
            }, hair: { d in
                if d.view == .frontQuarter {
                    d.svg.path("M-9.4,-58.6 C-10.4,-55.4 -9.6,-52.4 -7.2,-50.6 C-7.6,-53 -7.2,-55.4 -6,-57.4 Z", fill: .colour(Ink.line))
                }
            }, features: { d in
                switch d.view {
                case .front:
                    // A black beard trimmed to a point under the mouth, and a moustache.
                    d.svg.path("M-7.8,-54.4 C-8.4,-48 -4.4,-42.6 0,-38.4 C4.4,-42.6 8.4,-48 7.8,-54.4 C5.4,-50.6 2.6,-49.6 0,-49.8 "
                               + "C-2.6,-49.6 -5.4,-50.6 -7.8,-54.4 Z", fill: .colour(Ink.line))
                    d.svg.path("M-4.8,-52.4 q2.4,-2 4.8,-0.8 q2.4,-1.2 4.8,0.8 q-1.6,1.4 -3.4,0.6 q-0.8,0.4 -1.4,0 q-0.6,0.4 -1.4,0 "
                               + "q-1.8,0.8 -3.4,-0.6 Z", fill: .colour(Ink.line))
                case .frontQuarter:
                    d.svg.raw("<g transform=\"translate(-1.6,0)\">")
                    d.svg.path("M-5.2,-54.2 C-5.8,-49.4 -3.4,-45.6 1,-43.6 C3.6,-42.4 6.4,-41.2 8.8,-38.6 C8.8,-42 10.6,-45.2 11.2,-49.4 "
                               + "C9,-48.6 6.4,-48.8 4.4,-49.6 C1.2,-50.8 -2,-52.6 -5.2,-54.2 Z", fill: .colour(Ink.line))
                    d.svg.path("M4,-52.6 q3.6,-2.2 7.4,-0.4 q-1.2,1.8 -3.6,1 q-2.4,0.8 -3.8,-0.6 Z", fill: .colour(Ink.line))
                    d.svg.raw("</g>")
                default:
                    break
                }
            }, brow: { d in
                d.svg.path("M1.4,-63.4 q3.4,-2.2 7.2,-0.8", stroke: .colour(Ink.line), width: 1.7)
            }, over: { d in
                Self.headcloth(&d, flutter: flutter)
            })
        }
        if nearer { lead(&d.svg); donkey.draw(&d.svg, view: view) }
    }

    /// The robe as a shape drawn round the body: wide at the hem, its back swinging with the stride.
    static func robeShape(sway: Double) -> [P] {
        var front: [P] = [], back: [P] = []
        for i in 0...6 {
            let t = Double(i) / 6, m = 1 - t
            func bezier(_ a: P, _ b: P, _ c: P, _ e: P) -> P { a * (m * m * m) + b * (3 * m * m * t) + c * (3 * m * t * t) + e * (t * t * t) }
            front.append(bezier(P(8.6, -47), P(11.6, -40), P(13.4, -24), P(15.6 - sway * 1.6, -6)))
            back.append(bezier(P(-8.4, -47), P(-11.6, -40), P(-13.4, -24), P(-16 - sway * 1.6, -6)))
        }
        return front + back.reversed()
    }

    /// The headcloth falling to the shoulder behind the head, as the side view draws it.
    static func fallingCloth(_ d: inout Drawing, flutter: Double) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.light), width: 1.3) { o in
            var p = PathData()
            p.move(P(-10.4, -62) + o)
            p.cubic(P(-13.4, -56) + o, P(-14.6 - flutter, -50) + o, P(-13.6 - flutter * 1.4, -44.6) + o)
            p.line(P(-7.4, -46.4) + o)
            p.cubic(P(-8.4, -51) + o, P(-7.6, -55) + o, P(-5.6, -58) + o)
            p.close()
            return p
        }
        d.svg.path("M\(num(-12.6 - flutter)),-47.6 l4.6,-1", stroke: .colour(IronPeopleInk.red), width: 1)
    }

    /// The headcloth over the crown, bound with a doubled red cord, and the
    /// gold ring in the ear, seen from each side other than the side. From
    /// behind the cloth covers the head and falls to the shoulders.
    static func headcloth(_ d: inout Drawing, flutter: Double) {
        let light = Paint.colour(IronPeopleInk.light)
        func cord(_ path: String) {
            d.svg.path(path, stroke: .colour(Ink.line), width: 2.8)
            d.svg.path(path, stroke: .colour(IronPeopleInk.red), width: 1.5)
        }
        func ring(_ at: P) {
            d.svg.circle(at, 1.5, fill: .none, stroke: .colour(Ink.line), width: 1.7)
            d.svg.circle(at, 1.5, fill: .none, stroke: .colour(IronPeopleInk.gold), width: 0.9)
        }
        switch d.view {
        case .front:
            BronzePeopleProps.shape(&d.svg, fill: light, width: 1.5) { o in
                var p = PathData()
                p.move(P(-11.8, -57) + o)
                p.cubic(P(-13.4, -70) + o, P(-6, -76.6) + o, P(0, -76.6) + o)
                p.cubic(P(6, -76.6) + o, P(13.4, -70) + o, P(11.8, -57) + o)
                p.cubic(P(10.6, -59) + o, P(9.8, -61.4) + o, P(8.6, -62.8) + o)
                p.cubic(P(4, -64.6) + o, P(-4, -64.6) + o, P(-8.6, -62.8) + o)
                p.cubic(P(-9.8, -61.4) + o, P(-10.6, -59) + o, P(-11.8, -57) + o)
                p.close()
                return p
            }
            cord("M-11.6,-65.6 C-5,-68.8 5,-68.8 11.6,-65.6")
            ring(P(-11.6, -53)); ring(P(11.6, -53))
        case .back:
            BronzePeopleProps.shape(&d.svg, fill: light, width: 1.5) { o in
                var p = PathData()
                p.move(P(-11.8, -60) + o)
                p.cubic(P(-13.4, -75.4) + o, P(13.4, -75.4) + o, P(11.8, -60) + o)
                p.cubic(P(11.2, -55.6) + o, P(10.4, -52.6) + o, P(10.8, -50.4) + o)
                p.cubic(P(11.6, -48.4) + o, P(13 + flutter * 0.6, -46.6) + o, P(13.6 + flutter * 0.8, -45) + o)
                p.cubic(P(5, -46.6) + o, P(-5, -46.6) + o, P(-13.6 - flutter * 0.8, -45) + o)
                p.cubic(P(-13 - flutter * 0.6, -46.6) + o, P(-11.6, -48.4) + o, P(-10.8, -50.4) + o)
                p.cubic(P(-10.4, -52.6) + o, P(-11.2, -55.6) + o, P(-11.8, -60) + o)
                p.close()
                return p
            }
            d.svg.path("M-6,-60 q-0.8,6 -1.4,12.6 M0,-60.6 q0,6.4 0,12.8 M6,-60 q0.8,6 1.4,12.6", stroke: .colour(IronPeopleInk.darkGrey), width: 0.8,
                       opacity: 0.7)
            cord("M-11.8,-65 C-5,-68.4 5,-68.4 11.8,-65")
            d.svg.path("M\(num(-2 - flutter)),-47.8 l4.6,-0.4", stroke: .colour(IronPeopleInk.red), width: 1)
        case .backQuarter:
            fallingCloth(&d, flutter: flutter)
            BronzePeopleProps.shape(&d.svg, fill: light, width: 1.5) { o in
                var p = PathData()
                p.move(P(-11.2, -57) + o)
                p.cubic(P(-13, -70) + o, P(4, -76.4) + o, P(11, -64.4) + o)
                p.cubic(P(10.4, -63) + o, P(9.4, -62.6) + o, P(8.4, -62.8) + o)
                p.cubic(P(4, -62) + o, P(-2, -58) + o, P(-7, -50) + o)
                p.close()
                return p
            }
            cord("M10.2,-66.2 C3.6,-69.4 -4.6,-68.6 -11.2,-63")
            ring(P(7.6, -53))
        default:
            BronzePeopleProps.shape(&d.svg, fill: light, width: 1.5) { o in
                var p = PathData()
                p.move(P(-11.2, -57) + o)
                p.cubic(P(-13, -70) + o, P(4, -76.4) + o, P(11, -64.4) + o)
                p.cubic(P(10.4, -63) + o, P(9.4, -62.6) + o, P(8.4, -62.8) + o)
                p.cubic(P(2, -65) + o, P(-4.6, -63.6) + o, P(-7, -58) + o)
                p.close()
                return p
            }
            cord("M10.2,-66.2 C3.6,-69.4 -4.6,-68.6 -11.2,-63")
            ring(P(-8.6, -53.4))
        }
    }
}

/// A donkey laden for the road, drawn from the side facing right: a grey coat
/// with a pale muzzle, belly and eye ring, a dark stripe over the shoulder,
/// long ears, a short upright mane and a tufted tail; a red halter; a
/// saddle-cloth of the team's colour with a wicker pannier and a striped roll
/// on it. Its legs are jointed like a horse's and its lower hoof rests on the
/// ground. Its local origin is on the ground under the middle of its body.
struct IronPeopleDonkey {
    struct Pose {
        var nearFore = Limb(3, 2), nearHind = Limb(-3, 4)
        var farFore = Limb(-1, 2), farHind = Limb(2, 4)
        var lift = 0.0
        /// The neck's turn in degrees about its base; positive lowers the head.
        var neck = 0.0
        /// The tail's swing, from -1 to 1.
        var tail = 0.0
        /// How far the near ear is turned back, from 0 to 1.
        var earFlick = 0.0
        var blink = false
    }

    static let foreHip = P(10.4, -26.6), hindHip = P(-11.6, -27.4)
    static let farOffset = P(2.2, -0.8)
    static let upper = 13.6, lower = 13.6
    static let neckBase = P(13, -34)
    static let coat = "#9a948b", shade = "#6d675f", pale = "#e2dbcd", dark = "#4e4943"

    let origin: P
    let pose: Pose
    private(set) var bob = 0.0

    init(at origin: P, pose: Pose) {
        self.origin = origin; self.pose = pose
        let lowest = [Leg.fore, .hind].flatMap { kind in [false, true].map { Self.leg(self, kind, far: $0, bob: 0).hoof.y } }.max() ?? 0
        bob = origin.y - lowest
    }

    enum Leg { case fore, hind }

    /// A point of the body, from the donkey's local units to the picture.
    func body(_ p: P, bob b: Double? = nil) -> P { origin + p + P(0, -pose.lift + (b ?? bob)) }

    /// A point of the neck or head, turned with the neck.
    func head(_ p: P) -> P { body(p.rotated(pose.neck, about: Self.neckBase)) }

    /// The ring of the halter, where the lead is tied.
    var halter: P { head(P(30.6, -40.4)) }

    static func leg(_ donkey: IronPeopleDonkey, _ kind: Leg, far: Bool, bob: Double) -> (top: P, joint: P, hoof: P) {
        let hip = (kind == .fore ? foreHip : hindHip) + (far ? farOffset : P(0, 0))
        let limb = kind == .fore ? (far ? donkey.pose.farFore : donkey.pose.nearFore) : (far ? donkey.pose.farHind : donkey.pose.nearHind)
        let top = donkey.body(hip, bob: bob)
        let joint = top + P.direction(limb.upper) * upper
        let hoof = joint + P.direction(kind == .fore ? limb.upper - limb.bend : limb.upper + limb.bend) * lower
        return (top, joint, hoof)
    }

    func drawLeg(_ svg: inout SVG, _ kind: Leg, far: Bool) {
        let (top, joint, hoof) = Self.leg(self, kind, far: far, bob: bob)
        Self.strokeLeg(&svg, top: top, joint: joint, hoof: hoof, far: far)
    }

    /// A leg from its top through its joint to its hoof, the far ones in the shade.
    static func strokeLeg(_ svg: inout SVG, top: P, joint: P, hoof: P, far: Bool) {
        let colour = far ? Self.shade : Self.coat
        let u = P.direction(BronzePeopleKit.degrees(from: joint, to: hoof)), a = P(-u.y, u.x)
        let fetlock = hoof - u * 2.2
        svg.line([top, joint], stroke: .colour(Ink.line), width: 4.6)
        svg.line([joint, fetlock], stroke: .colour(Ink.line), width: 3.2)
        svg.line([top, joint], stroke: .colour(colour), width: 2.9)
        svg.line([joint, fetlock], stroke: .colour(colour), width: 1.6)
        svg.circle(joint, 1.2, fill: .colour(colour))
        // The pale stocking above a small dark hoof.
        svg.line([fetlock - u * 2.6, fetlock], stroke: .colour(far ? Self.coat : Self.pale), width: 1.6)
        svg.polygon([fetlock - a * 1.2, fetlock + a * 1.4, hoof + a * 2 + u * 0.5, hoof - a * 1.4 + u * 0.5], fill: .colour(Ink.line))
    }

    func draw(_ svg: inout SVG) {
        svg.ellipse(origin + P(2, 0.2), 26, 3.4, fill: .colour("#000000"), opacity: 0.13)
        drawLeg(&svg, .fore, far: true)
        drawLeg(&svg, .hind, far: true)
        drawBody(&svg)
        drawLeg(&svg, .fore, far: false)
        drawLeg(&svg, .hind, far: false)
    }

    /// The tail, the barrel and its load, the neck and the head, as the side view draws them.
    func drawBody(_ svg: inout SVG) {
        let line = Paint.colour(Ink.line)
        svg.raw("<g transform=\"translate(\(num(origin.x)),\(num(origin.y + bob - pose.lift)))\">")
        // The tail: a thin rope of hair ending in a dark tuft, swinging.
        let swing = pose.tail * 3
        var tail = PathData()
        tail.move(P(-17.4, -36.6)); tail.cubic(P(-21, -34), P(-21 - swing * 0.4, -28), P(-20.4 - swing, -21.6))
        svg.path(tail, stroke: line, width: 2.6)
        svg.path(tail, stroke: .colour(Self.coat), width: 1.2)
        svg.group(turned: swing * 4, about: P(-20.4 - swing, -21.6)) { svg in
            svg.ellipse(P(-20.6 - swing, -18.6), 2, 3.6, fill: .colour(Self.dark), stroke: line, width: 0.9)
        }
        // The barrel.
        func barrel(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(-18, -35.6) + o)
            p.cubic(P(-18.6, -41) + o, P(-12, -42.2) + o, P(-4, -40.6) + o)
            p.cubic(P(4, -39.6) + o, P(10, -42.2) + o, P(15, -39.4) + o)
            p.cubic(P(19.2, -36.4) + o, P(18.4, -28.4) + o, P(13.4, -25.6) + o)
            p.cubic(P(6, -23.4) + o, P(-6, -23.8) + o, P(-12.2, -25.6) + o)
            p.cubic(P(-16.4, -27) + o, P(-18.6, -30.6) + o, P(-18, -35.6) + o)
            p.close()
            return p
        }
        svg.path(barrel(P(-0.8, 0.7)), fill: .colour(Self.coat))
        // The pale belly.
        svg.path("M-11.4,-26.4 C-5,-24.4 6,-24.2 12.4,-26.4 C8,-23.6 -6,-23.2 -11.4,-26.4 Z", fill: .colour(Self.pale))
        svg.path("M-16.4,-34 C-15.6,-38.6 -12,-40 -8.6,-39.2", stroke: .colour(Self.shade), width: 1.1)
        svg.path(barrel(P(0, 0)), stroke: line, width: 1.6)
        // The load: a saddle-cloth of the team's colour, fringed, bordered in the light.
        let cloth = [P(-12.6, -41.6), P(7, -41.4), P(8.8, -28.4), P(-12.8, -28.6)]
        svg.polygon([P(-13.2, -40.8), P(6.4, -40.6), P(8.2, -27.8), P(-13.4, -27.8)], fill: .team)
        svg.line([P(-12.6, -30.6), P(8.4, -30.4)], stroke: .colour(IronPeopleInk.light), width: 1.2)
        svg.polygon(cloth, fill: .none, stroke: line, width: 1.2)
        var fringe = PathData()
        var x = -12
        while x <= 8 {
            fringe.move(P(Double(x), -28.4)); fringe.line(P(Double(x) - 0.3, -26.2))
            x += 2
        }
        svg.path(fringe, stroke: line, width: 0.9)
        // The girth, under the belly.
        svg.line([P(-1.6, -41), P(-1.2, -24.6)], stroke: .colour(IronPeopleInk.leather), width: 1.8)
        // A wicker pannier on the near side, an amphora's neck standing out of it.
        let amphora = P(-1.6, -44.4)
        BronzePeopleProps.shape(&svg, [amphora + P(-1.4, 0), amphora + P(1.4, 0), amphora + P(1.8, 5), amphora + P(-1.8, 5)],
                                fill: .colour(IronPeopleInk.paleRed), width: 1)
        svg.ellipse(amphora, 2.2, 0.9, fill: .colour(IronPeopleInk.paleRed), stroke: line, width: 0.9)
        IronPeopleProps.basket(&svg, rim: P(-3, -38.6), width: 14, height: 10, handle: false)
        // A striped roll across the back, behind the pannier.
        svg.path(BronzePeopleProps.rounded(P(-11, -43.4), width: 9, height: 5, radius: 2.4, degrees: -4, shift: P(-0.6, 0.5)),
                 fill: .colour(IronPeopleInk.light))
        svg.line([P(-13.2, -45.6), P(-13.4, -41.2)], stroke: .colour(IronPeopleInk.red), width: 1.3)
        svg.line([P(-9.2, -45.8), P(-9.4, -41.4)], stroke: .colour(IronPeopleInk.red), width: 1.3)
        svg.path(BronzePeopleProps.rounded(P(-11, -43.4), width: 9, height: 5, radius: 2.4, degrees: -4, shift: P(0, 0)),
                 stroke: line, width: 1)
        // The neck and head, turned together about the neck's base.
        svg.raw("<g transform=\"rotate(\(num(pose.neck)) \(num(Self.neckBase.x)) \(num(Self.neckBase.y)))\">")
        // The far ear, behind the head.
        Self.ear(&svg, base: P(20.6, -52.4), degrees: -14, colour: Self.shade)
        func neck(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(8, -40.6) + o)
            p.cubic(P(12, -46) + o, P(16.4, -50.6) + o, P(21, -53) + o)
            p.line(P(25.4, -45.4) + o)
            p.cubic(P(22.6, -40) + o, P(20.4, -33.6) + o, P(17.6, -28.6) + o)
            p.close()
            return p
        }
        svg.path(neck(P(-0.8, 0.7)), fill: .colour(Self.coat))
        // The stripe down the shoulder.
        svg.path("M10.6,-41.4 C12.6,-38 13.6,-35 14,-31", stroke: .colour(Self.dark), width: 1.6)
        svg.path(neck(P(0, 0)), stroke: line, width: 1.5)
        // The mane: a short upright brush along the crest.
        var mane = PathData()
        mane.move(P(8.6, -41.2))
        for i in 1...7 {
            let t = Double(i) / 7
            let base = P(8.6, -41.2) + (P(21, -53.4) - P(8.6, -41.2)) * t
            let tip = base + P(-1.8, -2.6)
            mane.line(base + (P(-1.2, -1.8) - P(0, 0)) * 0.3)
            mane.line(tip)
        }
        mane.line(P(21, -53.4))
        mane.close()
        svg.path(mane, fill: .colour(Self.dark), stroke: line, width: 0.8)
        // The head: long, with a heavy jaw and a pale muzzle.
        func skull(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(20.4, -53.4) + o)
            p.cubic(P(25.4, -55.8) + o, P(31.2, -50.6) + o, P(34.8, -45.6) + o)
            p.cubic(P(37.2, -42.4) + o, P(36.4, -38.6) + o, P(33.2, -38.4) + o)
            p.cubic(P(30.4, -38.2) + o, P(27.4, -39.4) + o, P(25, -41.8) + o)
            p.cubic(P(22, -44.4) + o, P(19.8, -48.4) + o, P(20.4, -53.4) + o)
            p.close()
            return p
        }
        svg.path(skull(P(-0.6, 0.6)), fill: .colour(Self.coat))
        svg.path("M30.6,-46.6 C33.6,-46.6 36.4,-44 36.4,-41.2 C36.2,-38.8 34.4,-38.4 32.6,-38.6 C30,-39 29,-41.6 29.2,-43.6 "
                 + "C29.4,-45.2 29.8,-46.4 30.6,-46.6 Z", fill: .colour(Self.pale))
        svg.path("M23.4,-47.4 C24.4,-44.6 26.6,-43 28.4,-43", stroke: .colour(Self.shade), width: 1)
        svg.path(skull(P(0, 0)), stroke: line, width: 1.5)
        svg.circle(P(35.2, -42.6), 0.6, fill: line)
        svg.path("M33.8,-39.6 q1.2,0.2 2,-0.6", stroke: line, width: 0.8)
        // The near ear, flicked back now and then.
        Self.ear(&svg, base: P(22.4, -53), degrees: -4 - 40 * pose.earFlick, colour: Self.coat)
        // The halter of red rope, with a ring for the lead.
        svg.path("M23.6,-51.2 L30.4,-41.2 M32.6,-47 L29,-40", stroke: line, width: 1.8)
        svg.path("M23.6,-51.2 L30.4,-41.2 M32.6,-47 L29,-40", stroke: .colour(IronPeopleInk.red), width: 0.9)
        svg.circle(P(30.6, -40.4), 1.1, fill: .none, stroke: .colour(IronPeopleInk.iron), width: 0.8)
        // The eye in its pale ring.
        svg.circle(P(26.2, -49.8), 2.4, fill: .colour(Self.pale))
        if pose.blink {
            svg.path("M24.8,-49.8 h2.8", stroke: line, width: 1)
        } else {
            svg.circle(P(26.4, -49.8), 1.4, fill: .colour(Ink.eyeWhite), stroke: line, width: 0.7)
            svg.circle(P(26.8, -49.7), 0.7, fill: line)
        }
        svg.raw("</g>")
        svg.raw("</g>")
    }

    /// A long ear standing from `base`, turned by `degrees` (negative leans it back).
    static func ear(_ svg: inout SVG, base: P, degrees: Double, colour: String) {
        svg.group(turned: degrees, about: base) { svg in
            func leaf(_ o: P) -> PathData {
                var p = PathData()
                p.move(base + P(-1.8, 0.6) + o)
                p.quad(base + P(-3.4, -8) + o, base + P(-0.6, -14) + o)
                p.quad(base + P(2.8, -8) + o, base + P(2, 0.4) + o)
                p.close()
                return p
            }
            svg.path(leaf(P(-0.5, 0.5)), fill: .colour(colour))
            svg.path(leaf(P(0, 0)), stroke: .colour(Ink.line), width: 1.2)
            svg.path("M\(num(base.x - 0.4)),\(num(base.y - 2)) q-0.8,-5 0,-9", stroke: .colour(Self.dark), width: 1)
        }
    }
}

// MARK: - The donkey in the other views

extension IronPeopleDonkey {
    /// Half the donkey's width across its barrel, and half its length.
    static let halfWidth = 7.0, halfLength = 18.0
    /// How far apart its legs stand across the body.
    static let foreSpread = 4.0, hindSpread = 4.4

    /// The share of its length the body shows in a view: the length
    /// foreshortened, with the width seen across it.
    static func share(_ view: SpriteView) -> Double {
        let (c, s) = IronViews.turn(view)
        let w = halfWidth / halfLength
        return (c * c + w * w * s * s).squareRoot()
    }

    /// How far the head is lowered by the neck's turn, seen end on.
    var drop: Double { 0.35 * pose.neck }

    /// A point of the donkey seen end on, from its local units: x across the body, y as in the side view.
    func endOn(_ p: P) -> P { origin + p + P(0, -pose.lift + bob) }

    /// The ring of the halter, where the lead is tied, in a view.
    func halter(_ view: SpriteView) -> P {
        switch view {
        case .side: return halter
        case .front, .back: return endOn(P(0, -38.6 + drop))
        default:
            let h = halter
            return P(origin.x + (h.x - origin.x) * Self.share(view), h.y)
        }
    }

    /// The donkey in a view, facing the way its master faces.
    func draw(_ svg: inout SVG, view: SpriteView) {
        switch view {
        case .side: draw(&svg)
        case .front, .back: drawEndOn(&svg, front: view == .front)
        default: drawQuarter(&svg, view: view)
        }
    }

    /// From a quarter turn: the side drawing foreshortened, its far legs a body's width aside.
    func drawQuarter(_ svg: inout SVG, view: SpriteView) {
        let (c, s) = IronViews.turn(view)
        let k = Self.share(view), w = Self.halfWidth
        svg.ellipse(origin + P(2 * k, 0.2), 26 * k + w * abs(s), 3.4, fill: .colour("#000000"), opacity: 0.13)
        func leg(_ kind: Leg, far: Bool) {
            let (top, joint, hoof) = Self.leg(self, kind, far: far, bob: bob)
            let back = far ? Self.farOffset : P(0, 0)
            let z = far ? -w * 0.6 : w * 0.6
            func map(_ p: P) -> P { let q = p - back; return P(origin.x + (q.x - origin.x) * c - z * s, q.y) }
            Self.strokeLeg(&svg, top: map(top), joint: map(joint), hoof: map(hoof), far: far)
        }
        leg(.fore, far: true)
        leg(.hind, far: true)
        svg.raw("<g transform=\"translate(\(num(origin.x)),0) scale(\(num(k)),1) translate(\(num(-origin.x)),0)\">")
        drawBody(&svg)
        svg.raw("</g>")
        leg(.fore, far: false)
        leg(.hind, far: false)
    }

    /// Seen end on, from straight ahead (its long face toward the viewer, the
    /// chest behind it) or from behind (its rump, the tail down the middle, the
    /// ears beyond). The saddle-cloth hangs down both its sides.
    func drawEndOn(_ svg: inout SVG, front: Bool) {
        let line = Paint.colour(Ink.line)
        svg.ellipse(origin + P(0, 0.2), 11, 3.4, fill: .colour("#000000"), opacity: 0.13)
        // The legs seen end on: their tops apart across the body, their joints and hooves as the side view moves them.
        func leg(_ kind: Leg, right: Bool) {
            let far = right == front ? false : true
            let (top, joint, hoof) = Self.leg(self, kind, far: !right, bob: bob)
            let back = right ? P(0, 0) : Self.farOffset
            let spread = kind == .fore ? Self.foreSpread : Self.hindSpread
            // The right side is on the screen's left from the front, on its right from behind.
            let x = origin.x + (right == front ? -spread : spread)
            Self.strokeLeg(&svg, top: P(x, top.y - back.y), joint: P(x + (right == front ? -0.3 : 0.3), joint.y - back.y),
                           hoof: P(x, hoof.y - back.y), far: far)
        }
        let farKind: Leg = front ? .hind : .fore, nearKind: Leg = front ? .fore : .hind
        leg(farKind, right: true); leg(farKind, right: false)
        if !front { backOfHead(&svg) }
        // The barrel: the chest or the rump, round.
        let middle = endOn(P(0, -32.8))
        svg.ellipse(middle + P(-0.6, 0.6), 8.8, 9, fill: .colour(Self.coat))
        svg.ellipse(middle + P(0, 5.6), 5.6, 2.4, fill: .colour(Self.pale))
        svg.ellipse(middle, 8.8, 9, fill: .none, stroke: line, width: 1.6)
        // The saddle-cloth over the back, down both sides, fringed at its hems.
        func at(_ x: Double, _ y: Double) -> P { endOn(P(x, y)) }
        var cloth = PathData()
        cloth.move(at(-9.8, -28.4)); cloth.line(at(-9.8, -35))
        cloth.cubic(at(-9.8, -41.4), at(-5, -43.4), at(0, -43.4))
        cloth.cubic(at(5, -43.4), at(9.8, -41.4), at(9.8, -35))
        cloth.line(at(9.8, -28.4)); cloth.line(at(7.2, -28.4)); cloth.line(at(7.2, -35))
        cloth.cubic(at(7.2, -38.8), at(4, -40.4), at(0, -40.4))
        cloth.cubic(at(-4, -40.4), at(-7.2, -38.8), at(-7.2, -35))
        cloth.line(at(-7.2, -28.4)); cloth.close()
        svg.path(cloth, fill: .team)
        svg.line([at(-9.6, -30.6), at(-7.4, -30.6)], stroke: .colour(IronPeopleInk.light), width: 1.2)
        svg.line([at(7.4, -30.6), at(9.6, -30.6)], stroke: .colour(IronPeopleInk.light), width: 1.2)
        svg.path(cloth, stroke: line, width: 1.2)
        svg.path("M\(num(at(-9.4, -28.4).x)),\(num(at(0, -28.4).y)) l-0.3,2.2 M\(num(at(-7.6, -28.4).x)),\(num(at(0, -28.4).y)) l-0.3,2.2 "
                 + "M\(num(at(7.6, -28.4).x)),\(num(at(0, -28.4).y)) l0.3,2.2 M\(num(at(9.4, -28.4).x)),\(num(at(0, -28.4).y)) l0.3,2.2",
                 stroke: line, width: 0.9)
        // The striped roll along the back, end on, and the pannier on the near side with its amphora.
        let roll = at(0, -45)
        svg.circle(roll + P(-0.5, 0.5), 2.8, fill: .colour(IronPeopleInk.light))
        svg.circle(roll, 1.4, fill: .none, stroke: .colour(IronPeopleInk.red), width: 0.9)
        svg.circle(roll, 2.8, fill: .none, stroke: line, width: 1)
        let side = front ? -1.0 : 1.0
        let amphora = at(side * 11, -42.6)
        BronzePeopleProps.shape(&svg, [amphora + P(-1.4, 0), amphora + P(1.4, 0), amphora + P(1.8, 5), amphora + P(-1.8, 5)],
                                fill: .colour(IronPeopleInk.paleRed), width: 1)
        svg.ellipse(amphora, 2.2, 0.9, fill: .colour(IronPeopleInk.paleRed), stroke: line, width: 0.9)
        IronPeopleProps.basket(&svg, rim: at(side * 11, -38.6), width: 7, height: 10, handle: false)
        leg(nearKind, right: true); leg(nearKind, right: false)
        if front { face(&svg) } else { tail(&svg) }
    }

    /// The tail seen from behind: down the middle of the rump, swinging aside.
    private func tail(_ svg: inout SVG) {
        let swing = pose.tail * 2.4
        let root = endOn(P(0, -38.4)), end = endOn(P(swing, -21.6))
        var tail = PathData()
        tail.move(root); tail.cubic(root + P(0, 4), end + P(-swing * 0.6, -6), end)
        svg.path(tail, stroke: .colour(Ink.line), width: 2.6)
        svg.path(tail, stroke: .colour(Self.coat), width: 1.2)
        svg.ellipse(end + P(0, 3), 2, 3.6, fill: .colour(Self.dark), stroke: .colour(Ink.line), width: 0.9)
    }

    /// The back of the head and the ears, standing beyond the rump, and the mane down the neck.
    private func backOfHead(_ svg: inout SVG) {
        let line = Paint.colour(Ink.line)
        let head = endOn(P(0, -50 + drop))
        Self.ear(&svg, base: head + P(-2.6, -3.6), degrees: -22, colour: Self.coat)
        Self.ear(&svg, base: head + P(2.6, -3.6), degrees: 22 + 40 * pose.earFlick, colour: Self.coat)
        let neck = [endOn(P(-4.6, -37)), endOn(P(4.6, -37)), head + P(3.6, 2), head + P(-3.6, 2)]
        svg.polygon(neck.map { $0 + P(-0.6, 0.6) }, fill: .colour(Self.coat))
        svg.polygon(neck, fill: .none, stroke: line, width: 1.4)
        svg.ellipse(head + P(-0.5, 0.5), 4.8, 4.6, fill: .colour(Self.coat))
        svg.ellipse(head, 4.8, 4.6, fill: .none, stroke: line, width: 1.4)
        svg.line([head + P(0, -3.4), endOn(P(0, -40))], stroke: line, width: 2.8)
        svg.line([head + P(0, -3.4), endOn(P(0, -40))], stroke: .colour(Self.dark), width: 1.6)
    }

    /// The long face toward the viewer: the forelock, the eyes in their pale rings
    /// at its sides, the pale muzzle, the halter of red rope, and the long ears.
    private func face(_ svg: inout SVG) {
        let line = Paint.colour(Ink.line)
        func at(_ x: Double, _ y: Double) -> P { endOn(P(x, y + drop)) }
        let neck = [endOn(P(-4.6, -37)), endOn(P(4.6, -37)), at(3.8, -52), at(-3.8, -52)]
        svg.polygon(neck.map { $0 + P(-0.6, 0.6) }, fill: .colour(Self.coat))
        svg.polygon(neck, fill: .none, stroke: line, width: 1.4)
        // The near ear is the one on the screen's left; it flicks back now and then.
        Self.ear(&svg, base: at(-2.8, -55.4), degrees: -22 - 30 * pose.earFlick, colour: Self.coat)
        Self.ear(&svg, base: at(2.8, -55.4), degrees: 22, colour: Self.shade)
        func skull(_ o: P) -> PathData {
            var p = PathData()
            p.move(at(-4.6, -55) + o)
            p.cubic(at(-5.8, -50) + o, at(-4.8, -44) + o, at(-3.8, -40) + o)
            p.cubic(at(-3.2, -37.4) + o, at(3.2, -37.4) + o, at(3.8, -40) + o)
            p.cubic(at(4.8, -44) + o, at(5.8, -50) + o, at(4.6, -55) + o)
            p.cubic(at(3, -57.2) + o, at(-3, -57.2) + o, at(-4.6, -55) + o)
            p.close()
            return p
        }
        svg.path(skull(P(-0.6, 0.6)), fill: .colour(Self.coat))
        svg.ellipse(at(0, -40.6), 3.8, 2.8, fill: .colour(Self.pale))
        svg.path(skull(P(0, 0)), stroke: line, width: 1.5)
        for x in [-1.4, 1.4] { svg.ellipse(at(x, -40.2), 0.6, 0.8, fill: line) }
        // The forelock, a short dark tuft.
        svg.path("M\(num(at(-2, -56).x)),\(num(at(0, -56).y)) l1,-2.4 l1,1.6 l1,-2 l1,2.4 Z", fill: .colour(Self.dark), stroke: line, width: 0.6)
        // The halter: a noseband and the cheek straps, with a ring under the chin for the lead.
        let strap = "M\(num(at(-4.2, -43).x)),\(num(at(0, -43).y)) L\(num(at(4.2, -43).x)),\(num(at(0, -43).y)) "
            + "M\(num(at(-4.2, -43).x)),\(num(at(0, -43).y)) L\(num(at(-5, -53).x)),\(num(at(0, -53).y)) "
            + "M\(num(at(4.2, -43).x)),\(num(at(0, -43).y)) L\(num(at(5, -53).x)),\(num(at(0, -53).y))"
        svg.path(strap, stroke: line, width: 1.8)
        svg.path(strap, stroke: .colour(IronPeopleInk.red), width: 0.9)
        svg.circle(at(0, -38.6), 1.1, fill: .none, stroke: .colour(IronPeopleInk.iron), width: 0.8)
        for x in [-4.6, 4.6] {
            let eye = at(x, -50.4)
            svg.circle(eye, 2, fill: .colour(Self.pale))
            if pose.blink {
                svg.path("M\(num(eye.x - 1.2)),\(num(eye.y)) h2.4", stroke: line, width: 1)
            } else {
                svg.circle(eye, 1.2, fill: .colour(Ink.eyeWhite), stroke: line, width: 0.7)
                svg.circle(eye + P(x < 0 ? 0.3 : -0.3, 0.1), 0.6, fill: line)
            }
        }
    }
}
