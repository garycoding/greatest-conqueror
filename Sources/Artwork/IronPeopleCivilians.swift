// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The worker in the Iron look: the farmer, in wool and linen of the look's
// colours and carrying iron, with a nose of his own (docs/art-style.md,
// "Noses") different from his Bronze look's, moving on the shared skeleton.
// The team's colour is where the earlier looks put it: the sash.

// MARK: - The farmer (worker)

/// A farmer in a short tunic of iron-grey wool with a red hem patterned in
/// the light, the team's sash knotted at the waist, a sickle tucked in at the
/// back, a broad straw hat with a red band, and a stalk of grain between his
/// teeth; nose B. He carries his hoe on his shoulder with a basket of grain
/// hanging from its haft behind him; at work he sets the basket down and
/// breaks the soil with the hoe in the approved two-handed chop, clods flying
/// where it bites; fighting, he hacks with it.
struct IronPeopleFarmer: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.frontArm = Self.carry(lift: r.lift)
            return r
        case .walking:
            var r = Moves.walking(frame)
            r.frontArm = Self.carry(lift: BronzePeopleKit.wave(frame, times: 2))
            return r
        case .working:
            return hoeing(frame)
        case .fighting:
            return hack(frame)
        default:
            return nil
        }
    }

    /// The front hand at the shoulder, steadying the hoe that rests on it.
    static func carry(lift: Double) -> Limb { Limb(30 + lift, 128) }
    /// The hoe on the shoulder: its haft runs back and a little up from the hand.
    static let carried = -97.0
    /// How far behind the hand the basket hangs from the haft.
    static let hangs = 33.0
    static let workingHaft = 32.0

    /// The approved chop (docs/art/worker-animation.gif), brought down to the ground.
    static func hoeAngle(_ frame: Int) -> Double {
        let p = Moves.phase(frame)
        if p < 0.55 { return 70 + (195 - 70) * ease(p / 0.55) }
        if p < 0.72 { return 195 - (195 - 30) * pow((p - 0.55) / 0.17, 2) }
        return 30 + 40 * ease((p - 0.72) / 0.28)
    }

    /// The frame on which the hoe bites.
    static let strike = 9

    func hoeing(_ frame: Int) -> Rig {
        let angle = Self.hoeAngle(frame)
        var r = Rig()
        r.backLeg = Limb(-16, 8); r.frontLeg = Limb(20, 12)
        r.frontArm = Limb(angle, -6); r.backArm = Limb(angle - 6, -2)
        r.lean = [-2, -4, -5, -5, -5, -5, -5, 2, 10, 14, 11, 4][frame]
        r.mouth = frame >= 8 && frame <= 10 ? .firm : .smile
        r.eyes = frame == 9 ? .wide : .open
        return r
    }

    func hack(_ frame: Int) -> Rig {
        let (angle, landing) = Moves.blow(frame, ready: 85, raised: 172, struck: 48)
        var r = Rig()
        r.frontArm = Limb(angle, -10)
        r.backArm = Limb(42 - (angle - 85) * 0.35, 24)
        r.backLeg = Limb(-16, 6)
        r.frontLeg = frame >= 6 && frame <= 9 ? Limb(22, 14) : Limb(14, 8)
        r.lean = frame < 6 ? -3 : (frame <= 9 ? 9 : 3)
        r.mouth = frame >= 6 && frame <= 8 ? .shout : .firm
        r.eyes = landing ? .wide : .open
        return r
    }

    /// The hoe while working: its blade end, its haft's direction from there, and its blade's side.
    static func workingHoe(_ hand: P, _ frame: Int) -> (end: P, toward: P, side: P) {
        let u = P.direction(hoeAngle(frame) + 4)
        return (hand + u * workingHaft, u * -1, P(-u.y, u.x))
    }

    /// Where the hoe's edge bites the ground, in the picture: the turned earth lies there.
    static let bite: P = {
        let rig = IronPeopleFarmer().hoeing(strike)
        let d = Drawing(layer: .base, rig: rig, phase: 0)
        let hoe = workingHoe(d.joints.frontHand, strike)
        return d.world(IronPeopleProps.hoeEdge(end: hoe.end, toward: hoe.toward, side: hoe.side))
    }()

    /// Where the basket stands while he works or fights.
    static let basketDown = P(-27, -9)

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        if pose == .working || pose == .fighting {
            d.svg.ellipse(Self.basketDown + P(0.6, 9), 8, 2, fill: .colour("#000000"), opacity: 0.13)
            IronPeopleProps.basket(&d.svg, rim: Self.basketDown, width: 13, height: 9)
        }
        if pose == .working {
            IronPeopleProps.soil(&d.svg, from: Self.bite.x - 9, to: Self.bite.x + 7, peak: Self.bite.x - 1, height: max(2.4, -Self.bite.y + 1))
        }
        d.figure { d in
            let hand = d.joints.frontHand
            let carrying = pose == .standing || pose == .walking
            let carryU = P.direction(Self.carried)
            if carrying {
                // The basket hanging from the haft behind him, swinging with his stride.
                let hook = hand + carryU * Self.hangs
                let swing = pose == .walking ? 9 * BronzePeopleKit.wave(frame, 0.15) : 1.6 * BronzePeopleKit.wave(frame, 0.2)
                d.svg.group(turned: swing, about: hook) { svg in
                    svg.line([hook, hook + P(0, 4)], stroke: .colour(Ink.line), width: 0.9)
                    IronPeopleProps.basket(&svg, rim: hook + P(0, 11.6), width: 13, height: 9, stir: swing / 9)
                }
            }
            d.arm(front: false)
            d.legs()
            // The ends of the sash, hanging at the front hip.
            for (dx, length) in [(0.0, 9.5), (2.2, 7.5)] {
                let top = P(9.4 + dx * 0.4, -27)
                let end = top + P(1.6 - sway * 2 + dx * 0.5, length)
                d.svg.polygon([top + P(-1.1, 0), top + P(1.1, 0), end + P(0.9, 0), end + P(-0.9, 0)], fill: .team,
                              stroke: .colour(Ink.line), width: 0.9)
            }
            // The tunic: iron-grey wool, a red hem with a light zigzag woven in it.
            let top = (P(-8.5, -47), P(8.5, -47)), hem = (P(-15, -14.5), P(13.5, -14.5))
            d.garment(colour: [P(-12.5, -46), P(9, -48), P(14.6, -12.6), P(-16.6, -12.2)],
                      outline: [top.0, top.1, hem.1, hem.0], fill: .colour(IronPeopleInk.grey)) { d in
                d.svg.polygon([P(-14.4, -19.6), P(13, -19.6), P(14.1, -13), P(-16.1, -12.8)], fill: .colour(IronPeopleInk.red))
                var zig = PathData()
                var x = -13.6, up = true
                zig.move(P(x, -17.2))
                while x + 2 <= 12.6 {
                    x += 2; up.toggle()
                    zig.line(P(x, up ? -18.4 : -15.4))
                }
                d.svg.path(zig, stroke: .colour(IronPeopleInk.light), width: 0.9)
                // Flecks in the wool.
                var flecks = PathData()
                for (x, y) in [(-6.0, -42.0), (2.0, -40.0), (-9.0, -36.0), (5.5, -36.5), (-2.0, -23.0), (6.0, -22.4), (-10.0, -22.8)] {
                    flecks.move(d.up(P(x, y))); flecks.line(d.up(P(x + 1.2, y + 0.4)))
                }
                d.svg.path(flecks, stroke: .colour(IronPeopleInk.darkGrey), width: 0.9)
                // The sash, in the team's colour.
                d.band([P(-13.2, -31.8), P(12.4, -32.8), P(13, -26.6), P(-13.8, -25.6)])
                d.svg.line([d.up(P(-13.2, -31.8)), d.up(P(12.4, -32.8))], stroke: .colour(Ink.line), width: 0.9)
                d.svg.line([P(-13.8, -25.6), P(13, -26.6)], stroke: .colour(Ink.line), width: 0.9)
            }
            // The knot of the sash.
            d.svg.ellipse(P(10.4, -29.2), 2, 2.6, fill: .team, stroke: .colour(Ink.line), width: 0.9)
            // The sickle, tucked into the sash at the back, its blade curling down behind.
            IronPeopleProps.sickle(&d.svg, at: d.up(P(-11, -33.4)), degrees: 10, point: -1, size: 0.72)
            switch pose {
            case .working:
                let hoe = Self.workingHoe(hand, frame)
                IronPeopleProps.hoe(&d.svg, end: hoe.end, toward: hoe.toward, length: Self.workingHaft + 4, side: hoe.side)
                if frame == Self.strike || frame == Self.strike + 1 {
                    IronPeopleProps.clods(&d.svg, at: IronPeopleProps.hoeEdge(end: hoe.end, toward: hoe.toward, side: hoe.side) + P(-1, -1),
                                          spread: frame == Self.strike ? 0 : 1)
                }
            case .fighting:
                let u = P.direction(d.rig.frontArm.upper - 2)
                let end = hand + u * 22
                IronPeopleProps.hoe(&d.svg, end: end, toward: u * -1, length: 26, side: P(-u.y, u.x))
                if frame == 7 { d.swish(around: d.joints.frontShoulder, radius: 33, from: 160, to: 70) }
                if frame == 8 { d.impact(at: IronPeopleProps.hoeEdge(end: end, toward: u * -1, side: P(-u.y, u.x)), size: 1) }
            default:
                // On the shoulder: the blade just before the hand, hanging down, the haft running back over the shoulder.
                let end = hand - carryU * 3.4
                IronPeopleProps.hoe(&d.svg, end: end, toward: carryU, length: 40, side: P(carryU.y, -carryU.x))
            }
            d.arm(front: true)
            d.head(nose: .button, hair: { d in
                // Brown curls at the nape, under the hat.
                d.svg.path("M-11.2,-61 C-12.8,-56.4 -11.4,-51.8 -7.6,-50.2 C-8.4,-52.2 -8,-54 -7,-55.4 C-8.6,-56.4 -8.6,-58.6 -7.4,-60.4 Z",
                           fill: .colour(IronPeopleInk.hair))
            }, features: { d in
                // A stalk of grain between his teeth.
                d.svg.line([P(8.2, -50.6), P(17.6, -54.4)], stroke: .colour(IronPeopleInk.darkStraw), width: 0.8)
                d.svg.group(at: P(17.4, -54.6), turned: -112) { svg in
                    svg.ellipse(P(-0.3, 0.3), 1, 2.4, fill: .colour(IronPeopleInk.grain))
                    svg.ellipse(P(0, 0), 1, 2.4, fill: .none, stroke: .colour(Ink.line), width: 0.6)
                }
            }, brow: { d in
                d.svg.path("M1.8,-63.2 q3.2,-1.2 6.2,0", stroke: .colour(Ink.line), width: 1.6)
            }, over: { d in
                Self.hat(&d)
            })
        }
    }

    // MARK: The other views

    /// Where the basket stands on the ground whilst he works or fights: behind him and to his left.
    static let basketAside = -16.0

    /// The hoe in a view other than the side, from the hand that holds it: its
    /// blade end, its haft's direction and length as they show, and its blade's side.
    static func hoeInView(_ d: Drawing, _ pose: SpritePose, _ frame: Int) -> (end: P, toward: P, length: Double, side: P) {
        let view = d.view, hand = d.hand(front: true)
        func held(_ degrees: Double, reach: Double, length: Double, back: Bool) -> (P, P, Double, P) {
            let along = IronViews.tool(view, degrees), u0 = P.direction(degrees)
            let u = P.direction(along.degrees)
            let side = IronViews.flat(view, back ? P(u0.y, -u0.x) : P(-u0.y, u0.x))
            return back ? (hand - u * (3.4 * along.share), u, length * along.share, side)
                : (hand + u * (reach * along.share), u * -1, length * along.share, side)
        }
        switch pose {
        case .working: return held(hoeAngle(frame) + 4, reach: workingHaft, length: workingHaft + 4, back: false)
        case .fighting: return held(d.rig.frontArm.upper - 2, reach: 22, length: 26, back: false)
        default: return held(carried, reach: 0, length: 40, back: true)
        }
    }

    /// The farmer seen from the front, from behind, or from a quarter turn.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view, behind = IronViews.fromBehind(view)
        let sway = d.rig.sway
        let basket = IronViews.project(view, P(Self.basketDown.x, 0), z: Self.basketAside)
        // Where the hoe bites, as this view draws it on the strike.
        let strike = Drawing(layer: .mask, rig: hoeing(Self.strike), phase: 0, view: view)
        let bitten = Self.hoeInView(strike, .working, Self.strike)
        let bite = IronViews.world(strike, IronPeopleProps.hoeEdge(end: bitten.end, toward: bitten.toward, side: bitten.side))
        // The ground's things, the far ones before the figure and the near ones after it.
        func ground(_ svg: inout SVG, near: Bool) {
            if (pose == .working || pose == .fighting) && (basket.depth > 0) == near {
                let rim = basket.point + P(0, Self.basketDown.y)
                svg.ellipse(rim + P(0.6, 9), 8, 2, fill: .colour("#000000"), opacity: 0.13)
                IronPeopleProps.basket(&svg, rim: rim, width: 13, height: 9)
            }
            if pose == .working && near != behind {
                IronPeopleProps.soil(&svg, from: bite.x - 8, to: bite.x + 8, peak: bite.x, height: max(2.4, -bite.y + 1))
            }
        }
        ground(&d.svg, near: false)
        d.figure { d in
            let hand = d.hand(front: true)
            let carrying = pose == .standing || pose == .walking
            let hoe = Self.hoeInView(d, pose, frame)
            func hanging(_ d: inout Drawing) {
                // The basket hanging from the haft behind him, swinging with his stride.
                let hook = hand + hoe.toward * (Self.hangs * IronViews.tool(view, Self.carried).share)
                let swing = pose == .walking ? 9 * BronzePeopleKit.wave(frame, 0.15) : 1.6 * BronzePeopleKit.wave(frame, 0.2)
                let shown = swing * IronViews.turn(view).c
                d.svg.group(turned: shown, about: hook) { svg in
                    svg.line([hook, hook + P(0, 4)], stroke: .colour(Ink.line), width: 0.9)
                    IronPeopleProps.basket(&svg, rim: hook + P(0, 11.6), width: 13, height: 9, stir: swing / 9)
                }
            }
            func sickle(_ d: inout Drawing) {
                let at = IronViews.at(view, d.up(P(-11, -33.4)), z: -3)
                let turned = IronViews.tool(view, 10)
                IronPeopleProps.sickle(&d.svg, at: at, degrees: turned.degrees, point: view == .back ? 1 : -1, size: 0.72)
            }
            func tool(_ d: inout Drawing) {
                IronPeopleProps.hoe(&d.svg, end: hoe.end, toward: hoe.toward, length: hoe.length, side: hoe.side)
                if pose == .working && (frame == Self.strike || frame == Self.strike + 1) {
                    IronPeopleProps.clods(&d.svg, at: IronPeopleProps.hoeEdge(end: hoe.end, toward: hoe.toward, side: hoe.side) + P(-1, -1),
                                          spread: frame == Self.strike ? 0 : 1)
                }
                if pose == .fighting && frame == 8 {
                    d.impact(at: IronPeopleProps.hoeEdge(end: hoe.end, toward: hoe.toward, side: hoe.side), size: 1)
                }
            }
            if carrying && !behind { hanging(&d) }
            if !behind { sickle(&d) }
            // A tool in a hand behind the body is hidden by it.
            let toolBehind = !carrying && d.armBehind(front: true)
            if toolBehind { tool(&d) }
            d.arm(front: false)
            d.legs()
            if !behind {
                // The ends of the sash, hanging at the front hip.
                for (dx, length) in [(0.0, 9.5), (2.2, 7.5)] {
                    let top = IronViews.at(view, P(9.4 + dx * 0.4, -27), z: 3 - dx)
                    let end = top + IronViews.flat(view, P(1.6 - sway * 2 + dx * 0.5, length))
                    d.svg.polygon([top + P(-1.1, 0), top + P(1.1, 0), end + P(0.9, 0), end + P(-0.9, 0)], fill: .team,
                                  stroke: .colour(Ink.line), width: 0.9)
                }
            }
            d.garment(colour: [P(-12.5, -46), P(9, -48), P(14.6, -12.6), P(-16.6, -12.2)],
                      outline: [P(-8.5, -47), P(8.5, -47), P(13.5, -14.5), P(-15, -14.5)], fill: .colour(IronPeopleInk.grey)) { d in
                let hem = IronViews.around(d, [P(-14.4, -19.6), P(13, -19.6), P(14.1, -13), P(-16.1, -12.8)])
                d.svg.polygon(hem, fill: .colour(IronPeopleInk.red))
                // The light zigzag woven in the hem, across its width.
                let left = hem[hem.count - 7].x + 0.8, right = hem[6].x - 0.8
                var zig = PathData()
                var x = left, up = true
                zig.move(P(x, -17.2))
                while x + 2 <= right {
                    x += 2; up.toggle()
                    zig.line(P(x, up ? -18.4 : -15.4))
                }
                d.svg.path(zig, stroke: .colour(IronPeopleInk.light), width: 0.9)
                var flecks = PathData()
                for (x, y) in [(-6.0, -42.0), (2.0, -40.0), (-9.0, -36.0), (5.5, -36.5), (-2.0, -23.0), (6.0, -22.4), (-10.0, -22.8)] {
                    let p = d.onBody(d.up(P(x, y)))
                    flecks.move(p); flecks.line(p + P(1.2, 0.4))
                }
                d.svg.path(flecks, stroke: .colour(IronPeopleInk.darkGrey), width: 0.9)
                let sash = [P(-13.2, -31.8), P(12.4, -32.8), P(13, -26.6), P(-13.8, -25.6)]
                d.band(sash)
                let edges = IronViews.edges(d, sash)
                d.svg.line(edges.top, stroke: .colour(Ink.line), width: 0.9)
                d.svg.line(edges.bottom, stroke: .colour(Ink.line), width: 0.9)
            }
            if !behind {
                d.svg.ellipse(IronViews.at(view, P(10.4, -29.2), z: 3), 2, 2.6, fill: .team, stroke: .colour(Ink.line), width: 0.9)
            } else {
                sickle(&d)
            }
            if !toolBehind { tool(&d) }
            d.arm(front: true)
            if carrying && behind { hanging(&d) }
            d.head(nose: .button, hair: { d in
                Self.curls(&d, colour: IronPeopleInk.hair, curl: IronPeopleInk.paleLeather)
            }, features: { d in
                // A stalk of grain between his teeth, standing out toward the screen's right.
                guard IronViews.seesFace(d.view) else { return }
                let mouth = P(IronViews.face(d.view) + (d.view == .front ? 1.6 : 1.4), -50.8)
                let tip = d.view == .front ? mouth + P(6.4, -3.2) : mouth + P(6.8, -3.4)
                d.svg.line([mouth, tip], stroke: .colour(IronPeopleInk.darkStraw), width: 0.8)
                d.svg.group(at: tip, turned: -116) { svg in
                    svg.ellipse(P(-0.3, 0.3), 1, 2.4, fill: .colour(IronPeopleInk.grain))
                    svg.ellipse(P(0, 0), 1, 2.4, fill: .none, stroke: .colour(Ink.line), width: 0.6)
                }
            }, brow: { d in
                d.svg.path("M1.8,-63.2 q3.2,-1.2 6.2,0", stroke: .colour(Ink.line), width: 1.6)
            }, over: { d in
                if d.view == .front || d.view == .back { Self.hatAhead(&d) } else { Self.hat(&d) }
            })
        }
        ground(&d.svg, near: true)
    }

    /// Curls under a hat or a cap, seen from each side other than the side: from
    /// the front, a tuft at each temple; from behind, the back of the head,
    /// curled in a lighter shade; from a front quarter, at the nape.
    static func curls(_ d: inout Drawing, colour: String, curl: String) {
        switch d.view {
        case .front:
            for flip in [1.0, -1.0] {
                d.svg.raw("<g transform=\"scale(\(num(flip)),1)\">")
                d.svg.path("M-11,-62.6 C-12.4,-59.4 -11.8,-56.4 -9.8,-55.2 C-10,-57.4 -9.6,-59.6 -8.2,-61.6 Z", fill: .colour(colour))
                d.svg.raw("</g>")
            }
        case .back, .backQuarter:
            let back = d.view == .back
            d.svg.path(back ? "M-10.8,-61 C-12.2,-55.6 -9.4,-49.4 -4.6,-48.2 C-1.6,-48 1.6,-48 4.6,-48.2 C9.4,-49.4 12.2,-55.6 10.8,-61 Z"
                            : "M-11,-60.6 C-12.4,-55 -9.6,-49.2 -4.6,-48.2 C-0.6,-48 3.4,-49.4 7.4,-51.6 C9.6,-55.4 10,-58.4 9.4,-61 Z",
                       fill: .colour(colour))
            let shift = back ? 0 : -1.6
            d.svg.raw("<g transform=\"translate(\(num(shift)),0)\">")
            // Locks falling to the nape.
            d.svg.path("M-8.4,-60.4 q-1.4,3.4 -0.2,6.6 M-5,-61.6 q-1.2,4 0.2,8.4 M-1.4,-62 q-1,4.4 0.4,9.6 M2.2,-62 q-0.8,4.4 0.6,9.4 "
                       + "M5.8,-61.6 q-0.6,4 0.8,8.2 M8.8,-60.4 q-0.4,3.4 0.8,6.4", stroke: .colour(curl), width: 0.8)
            d.svg.raw("</g>")
        default:
            d.svg.path("M-11.2,-61 C-12.8,-56.4 -11.4,-51.8 -7.6,-50.2 C-8.4,-52.2 -8,-54 -7,-55.4 C-8.6,-56.4 -8.6,-58.6 -7.4,-60.4 Z",
                       fill: .colour(colour))
        }
    }

    /// The straw hat seen from straight ahead or behind: the crown and its red
    /// band over the middle of the head, the brim's full width across.
    static func hatAhead(_ d: inout Drawing) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.straw), width: 1.4) { o in
            var p = PathData()
            p.move(P(-9.2, -65) + o)
            p.cubic(P(-9.8, -73.6) + o, P(9.8, -73.6) + o, P(9.2, -65) + o)
            p.close()
            return p
        }
        d.svg.path("M-9.3,-66.8 C-3,-68.2 3,-68.2 9.3,-66.8 L9.2,-64.8 C3,-66 -3,-66 -9.2,-64.8 Z", fill: .colour(IronPeopleInk.red),
                   stroke: .colour(Ink.line), width: 0.8)
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.straw), width: 1.4) { o in
            var p = PathData()
            p.move(P(-19, -62.4) + o)
            p.cubic(P(-12, -66.8) + o, P(12, -66.8) + o, P(19, -62.4) + o)
            p.cubic(P(14, -61.2) + o, P(8, -62.6) + o, P(0, -62.8) + o)
            p.cubic(P(-8, -62.6) + o, P(-14, -61.2) + o, P(-19, -62.4) + o)
            p.close()
            return p
        }
        d.svg.path("M-14.6,-63.6 l1.6,1 M-9.6,-64.4 l1.6,1 M-4.6,-64.8 l1.6,1 M0.4,-64.9 l1.6,1 M5.4,-64.8 l1.6,1 M10.4,-64.3 l1.6,1 "
                   + "M-6,-70 l1.2,1.2 M-1,-71.2 l1.2,1.2 M4,-70.6 l1.2,1.2", stroke: .colour(IronPeopleInk.darkStraw), width: 0.8)
    }

    /// A broad straw hat: a low crown with a red band, and a wide brim that dips at the front and back.
    static func hat(_ d: inout Drawing) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.straw), width: 1.4) { o in
            var p = PathData()
            p.move(P(-8.8, -65) + o)
            p.cubic(P(-9.6, -73) + o, P(7.6, -74.6) + o, P(8.6, -65.6) + o)
            p.close()
            return p
        }
        // The band.
        d.svg.path("M-8.9,-66.6 C-3,-68 3.6,-68.2 8.7,-67.2 L8.6,-65.2 C3.6,-66.2 -3,-66 -8.8,-64.6 Z", fill: .colour(IronPeopleInk.red),
                   stroke: .colour(Ink.line), width: 0.8)
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronPeopleInk.straw), width: 1.4) { o in
            var p = PathData()
            p.move(P(-18.2, -62.2) + o)
            p.cubic(P(-12, -66.6) + o, P(9, -67.6) + o, P(19, -63.2) + o)
            p.cubic(P(16.4, -61.6) + o, P(10, -62.6) + o, P(1, -63) + o)
            p.cubic(P(-8, -63) + o, P(-14, -61) + o, P(-18.2, -62.2) + o)
            p.close()
            return p
        }
        // The weave of the straw.
        d.svg.path("M-14,-63.4 l1.6,1 M-9,-64.4 l1.6,1 M-4,-64.8 l1.6,1 M1,-65 l1.6,1 M6,-64.8 l1.6,1 M11,-64.2 l1.6,1 "
                   + "M-6,-70 l1.2,1.2 M-1,-71.4 l1.2,1.2 M4,-70.6 l1.2,1.2", stroke: .colour(IronPeopleInk.darkStraw), width: 0.8)
    }
}
