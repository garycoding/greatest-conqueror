// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The four peaceful sectors in their Bronze-age looks: the herder (worker), the
// scribe (scholar), the mason (engineer) and the trader (merchant). Each wears
// woven and dyed cloth and carries bronze, has a nose of its own (docs/art-style.md,
// "Noses") and something else of its own, and moves on the shared skeleton. The
// team's colour is where the Stone age put it for the same sector: the worker's
// sash, the scholar's stole, the engineer's apron; the trader's is the cloth
// his goods are wrapped in.

// MARK: - The herder (worker)

/// A herder who also works the copper mines: a linen tunic woven with pairs of
/// terracotta stripes and fringed at the hem, the team's sash at the waist with
/// its ends hanging behind, a verdigris headcloth knotted at the nape, a short
/// dark beard; nose A, the approved worker's. A bronze pick rests on his
/// shoulder; at work he swings it two-handed, as the approved worker swings his
/// axe, and green ore flies where it strikes; fighting, he hacks with it.
struct BronzePeopleHerder: PersonLook {
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
            return mine(frame)
        case .fighting:
            return hack(frame)
        default:
            return nil
        }
    }

    /// The front hand at the shoulder, steadying the pick that rests on it.
    static func carry(lift: Double) -> Limb { Limb(30 + lift, 128) }
    /// The pick on the shoulder: its haft runs back and a little up from the hand.
    static let carried = -100.0

    /// The approved chop (docs/art/worker-animation.gif), struck lower, at the ground.
    static func mineAngle(_ frame: Int) -> Double {
        let p = Moves.phase(frame)
        if p < 0.55 { return 70 + (195 - 70) * ease(p / 0.55) }
        if p < 0.72 { return 195 - (195 - 38) * pow((p - 0.55) / 0.17, 2) }
        return 38 + 32 * ease((p - 0.72) / 0.28)
    }

    func mine(_ frame: Int) -> Rig {
        let angle = Self.mineAngle(frame)
        var r = Rig()
        r.backLeg = Limb(-16, 8); r.frontLeg = Limb(18, 10)
        r.frontArm = Limb(angle, -6); r.backArm = Limb(angle - 4, -2)
        r.lean = [-2, -4, -5, -5, -5, -5, -5, 1, 8, 10, 8, 3][frame]
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

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        d.figure { d in
            d.arm(front: false)
            d.legs()
            // The sash's ends, hanging behind the back hip.
            for (dx, length) in [(0.0, 10.5), (2.4, 8.5)] {
                let top = P(-13 + dx * 0.4, -28.4)
                let end = top + P(-2.4 - sway * 2.2 - dx, length)
                d.svg.polygon([top + P(-1.1, 0), top + P(1.1, 0), end + P(0.9, 0), end + P(-0.9, 0)], fill: .team,
                              stroke: .colour(Ink.line), width: 0.9)
            }
            // The tunic: undyed linen woven with pairs of terracotta stripes.
            let top = (P(-8.5, -47), P(8.5, -47)), hem = (P(-15, -14.5), P(13.5, -14.5))
            d.garment(colour: [P(-12.5, -46), P(9, -48), P(14.6, -12.6), P(-16.6, -12.2)],
                      outline: [top.0, top.1, hem.1, hem.0], fill: .colour(BronzePeopleInk.light)) { d in
                for f in [0.2, 0.5, 0.8] {
                    for dx in [-0.9, 0.9] {
                        let a = top.0 + (top.1 - top.0) * f + P(dx, 1.4), b = hem.0 + (hem.1 - hem.0) * f + P(dx * 1.5, -0.6)
                        d.svg.line([d.up(a), b], stroke: .colour(BronzePeopleInk.terracotta), width: 1.1)
                    }
                }
                // The sash, in the team's colour, with a bronze clasp.
                d.band([P(-13.2, -31.8), P(12.4, -32.8), P(13, -26.6), P(-13.8, -25.6)])
                d.svg.line([d.up(P(-13.2, -31.8)), d.up(P(12.4, -32.8))], stroke: .colour(Ink.line), width: 0.9)
                d.svg.line([P(-13.8, -25.6), P(13, -26.6)], stroke: .colour(Ink.line), width: 0.9)
                d.svg.circle(d.up(P(10.6, -29.6)), 1.9, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.9)
            }
            // A fringe at the hem.
            var fringe = PathData()
            for i in 0..<11 {
                let x = -14.2 + Double(i) * 2.6
                fringe.move(P(x, -14.5)); fringe.line(P(x - 0.3, -12))
            }
            d.svg.path(fringe, stroke: .colour(Ink.line), width: 1)
            let hand = d.joints.frontHand
            switch pose {
            case .working:
                let degrees = Self.mineAngle(frame) + 4
                BronzePeopleProps.pick(&d.svg, at: hand, degrees: degrees)
                if frame == 9 || frame == 10 {
                    let point = BronzePeopleProps.pickPoint(at: hand, degrees: degrees)
                    BronzePeopleProps.oreChips(&d.svg, at: point + P(1, -1), spread: frame == 9 ? 0 : 1)
                }
            case .fighting:
                let degrees = d.rig.frontArm.upper - 2
                BronzePeopleProps.pick(&d.svg, at: hand, degrees: degrees, haft: 19)
                if frame == 7 { d.swish(around: d.joints.frontShoulder, radius: 31, from: 158, to: 70) }
                if frame == 8 { d.impact(at: BronzePeopleProps.pickPoint(at: hand, degrees: degrees, haft: 19), size: 1) }
            default:
                BronzePeopleProps.pick(&d.svg, at: hand, degrees: Self.carried, haft: 33, point: -1)
            }
            d.arm(front: true)
            let flutter = pose == .walking ? BronzePeopleKit.wave(frame, times: 2) : 0.4 * BronzePeopleKit.wave(frame)
            d.head(nose: .curve, behind: { d in
                // The ends of the headcloth's knot.
                for (dx, length) in [(0.0, 7.4), (2.0, 5.8)] {
                    let top = P(-12 + dx * 0.3, -61)
                    let end = top + P(-1.8 - dx * 0.6 - flutter * 1.2, length - flutter * 0.6)
                    d.svg.polygon([top + P(-1.2, 0), top + P(1.2, 0), end + P(0.6, 0), end + P(-0.8, 0)],
                                  fill: .colour(BronzePeopleInk.verdigris), stroke: .colour(Ink.line), width: 0.9)
                }
            }, hair: { d in
                // Dark hair at the nape, under the headcloth.
                d.svg.path("M-11,-60 C-12.2,-55.4 -10.6,-51.6 -7.2,-50.4 C-7.4,-53.2 -7.2,-56 -6,-58.6 Z", fill: .colour(Ink.line))
            }, features: { d in
                // A short dark beard along the jaw.
                d.svg.path("M-4.6,-53.6 C-3.6,-48.6 1.8,-46.2 6.8,-46.8 C9,-47.1 10.6,-48.4 10.9,-50.2 "
                           + "C8.6,-49.2 6,-49.5 4,-50.1 C1.4,-50.8 -1.8,-52.2 -4.6,-53.6 Z", fill: .colour(Ink.line))
            }, brow: { d in
                d.svg.path("M1.8,-63 q3.2,-1.3 6.4,-0.3", stroke: .colour(Ink.line), width: 1.4)
            }, over: { d in
                Self.headcloth(&d)
            })
        }
    }

    /// A verdigris headcloth wrapped over the crown, with two light threads
    /// woven along its edge and a knot at the nape.
    static func headcloth(_ d: inout Drawing) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(BronzePeopleInk.verdigris), width: 1.5) { o in
            var p = PathData()
            p.move(P(-12, -58.6) + o)
            p.cubic(P(-13.6, -71.2) + o, P(3, -75.4) + o, P(10.8, -64.8) + o)
            p.line(P(10.6, -62.6) + o)
            p.cubic(P(4.6, -65.6) + o, P(-3.6, -64.6) + o, P(-11, -57.2) + o)
            p.close()
            return p
        }
        var threads = PathData()
        threads.move(P(9.4, -64.6)); threads.cubic(P(3.8, -67.4), P(-4.2, -66.8), P(-11.2, -59.8))
        threads.move(P(8.2, -66.6)); threads.cubic(P(3, -69.2), P(-4.6, -68.8), P(-11.6, -62.2))
        d.svg.path(threads, stroke: .colour(BronzePeopleInk.light), width: 0.9)
        d.svg.ellipse(P(-11.8, -60.6), 2.3, 2.7, fill: .colour(BronzePeopleInk.verdigris), stroke: .colour(Ink.line), width: 1.1)
    }
}

extension BronzePeopleHerder {
    /// The herder seen from another side: the sash's ends at the small of the
    /// back, the stripes, sash and fringe spread round the tunic, the clasp in
    /// front, the pick in the figure's own plane, and the headcloth, its knot,
    /// the hair at the nape and the beard as the view shows them.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway, view = d.view
        let back = BronzePeopleViews.seesBack(view)
        let flutter = pose == .walking ? BronzePeopleKit.wave(frame, times: 2) : 0.4 * BronzePeopleKit.wave(frame)
        d.figure { d in
            let top = (P(-8.5, -47), P(8.5, -47)), hem = (P(-15, -14.5), P(13.5, -14.5))
            let outline = [top.0, top.1, hem.1, hem.0]
            let pickBehind = d.armBehind(front: true)
            d.arm(front: false)
            d.legs()
            if !back { Self.sashEnds(&d, outline: outline, sway: sway) }
            if pickBehind { Self.pickInView(&d, pose, frame) }
            d.garment(colour: [P(-12.5, -46), P(9, -48), P(14.6, -12.6), P(-16.6, -12.2)],
                      outline: outline, fill: .colour(BronzePeopleInk.light)) { d in
                for f in [0.2, 0.5, 0.8] {
                    for dx in [-0.9, 0.9] {
                        let a = top.0 + (top.1 - top.0) * f + P(dx, 1.4), b = hem.0 + (hem.1 - hem.0) * f + P(dx * 1.5, -0.6)
                        let from = BronzePeopleViews.spread(d, a, on: outline), to = BronzePeopleViews.spread(d, b, on: outline)
                        d.svg.line([d.up(from), to], stroke: .colour(BronzePeopleInk.terracotta), width: 1.1)
                    }
                }
                // The sash, in the team's colour, with a bronze clasp in front.
                let sash = [P(-13.2, -31.8), P(12.4, -32.8), P(13, -26.6), P(-13.8, -25.6)]
                d.band(sash)
                let turned = d.turned(sash), n = turned.count / 2
                d.svg.line([turned[turned.count - 1], turned[0]].map(d.up), stroke: .colour(Ink.line), width: 0.9)
                d.svg.line([turned[n], turned[n - 1]], stroke: .colour(Ink.line), width: 0.9)
                let clasp = BronzePeopleViews.round(d, on: sash, at: -29.4, degrees: 0)
                if clasp.facing > 0.25 {
                    d.svg.circle(d.up(clasp.point), 1.9, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.9)
                }
            }
            // A fringe at the hem.
            var fringe = PathData()
            for i in 0..<11 {
                let p = BronzePeopleViews.spread(d, P(-14.2 + Double(i) * 2.6, -14.6), on: outline)
                fringe.move(P(p.x, -14.5)); fringe.line(P(p.x - 0.3, -12))
            }
            d.svg.path(fringe, stroke: .colour(Ink.line), width: 1)
            if back { Self.sashEnds(&d, outline: outline, sway: sway) }
            if !pickBehind { Self.pickInView(&d, pose, frame) }
            d.arm(front: true)
            d.head(nose: .curve, behind: { d in
                if !BronzePeopleViews.seesBack(d.view) { Self.knotInView(&d, flutter: flutter) }
            }, hair: { d in
                // Dark hair at the nape, under the headcloth.
                for run in BronzePeopleViews.patch(d.view, from: 125, to: 235, out: 0.2, top: Self.clothEdge, bottom: Self.napeHair) {
                    d.svg.polygon(run, fill: .colour(Ink.line))
                }
            }, features: { d in
                Self.beardInView(&d)
            }, brow: { d in
                d.svg.path("M1.8,-63 q3.2,-1.3 6.4,-0.3", stroke: .colour(Ink.line), width: 1.4)
            }, over: { d in
                Self.headclothInView(&d)
                if BronzePeopleViews.seesBack(d.view) { Self.knotInView(&d, flutter: flutter) }
            })
        }
    }

    /// The headcloth's edge round the head: low over the brow, lower at the nape.
    static let clothEdge = BronzePeopleViews.edge(front: -64.2, side: -60.4, back: -57.2)

    /// The lower edge of the hair at the nape: lowest at the middle, rising toward the ears.
    static func napeHair(_ degrees: Double) -> Double {
        let t = min(abs(degrees - 180) / 55, 1)
        return -50.4 - 7 * t * t
    }

    /// The pick in the figure's own plane, in the pose's grip.
    static func pickInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let hand = d.joints.frontHand, map = BronzePeopleViews.held(d, front: true)
        switch pose {
        case .working:
            BronzePeopleProps.pick(&d.svg, at: hand, degrees: mineAngle(frame) + 4, map: map)
        case .fighting:
            let degrees = d.rig.frontArm.upper - 2
            BronzePeopleProps.pick(&d.svg, at: hand, degrees: degrees, haft: 19, map: map)
            if frame == 8 { d.impact(at: map(BronzePeopleProps.pickPoint(at: hand, degrees: degrees, haft: 19)), size: 1) }
        default:
            BronzePeopleProps.pick(&d.svg, at: hand, degrees: carried, haft: 33, point: -1, map: map)
        }
    }

    /// The sash's two ends, hanging from the knot at the small of the back.
    static func sashEnds(_ d: inout Drawing, outline: [P], sway: Double) {
        let knot = BronzePeopleViews.round(d, on: outline, at: -28.4, degrees: 180, out: 0.4).point
        let back = cos(d.yaw * .pi / 180)
        for (i, (dx, length)) in [(0.0, 10.5), (2.4, 8.5)].enumerated() {
            let side = (Double(i) - 0.5) * (BronzePeopleViews.seesBack(d.view) ? 3.2 : 1.6)
            let top = knot + P(side * 0.5, 0)
            let end = top + P((-2.4 - sway * 2.2 - dx) * back + side, length)
            d.svg.polygon([top + P(-1.1, 0), top + P(1.1, 0), end + P(0.9, 0), end + P(-0.9, 0)], fill: .team,
                          stroke: .colour(Ink.line), width: 0.9)
        }
    }

    /// The headcloth over the crown, its two light threads along the edge.
    static func headclothInView(_ d: inout Drawing) {
        let view = d.view
        BronzePeopleProps.shape(&d.svg, BronzePeopleViews.dome(view, out: 0.9, crown: 3.4, rim: clothEdge),
                                fill: .colour(BronzePeopleInk.verdigris), width: 1.5)
        for lift in [1.5, 3.3] {
            let thread = BronzePeopleViews.ring(view, out: 1 + lift * 0.1) { clothEdge($0) - lift }
            d.svg.line(Array(thread.dropFirst(2).dropLast(2)), stroke: .colour(BronzePeopleInk.light), width: 0.9)
        }
    }

    /// The knot of the headcloth at the nape, and its two ends, which hang
    /// behind and flutter: seen from behind it is over the head, from in front under it.
    static func knotInView(_ d: inout Drawing, flutter: Double) {
        let knot = BronzePeopleViews.onHead(d.view, degrees: 180, y: -60.6, out: 0.6).point
        let back = -cos(d.yaw * .pi / 180), spread = BronzePeopleViews.seesBack(d.view) ? 1.6 : 0.6
        for (i, (dx, length)) in [(0.0, 7.4), (2.0, 5.8)].enumerated() {
            let top = knot + P((Double(i) - 0.5) * spread, -0.4)
            let end = top + P((1.8 + dx * 0.6 + flutter * 1.2) * back + (Double(i) - 0.5) * spread * 2, length - flutter * 0.6)
            d.svg.polygon([top + P(-1.2, 0), top + P(1.2, 0), end + P(0.6, 0), end + P(-0.8, 0)],
                          fill: .colour(BronzePeopleInk.verdigris), stroke: .colour(Ink.line), width: 0.9)
        }
        d.svg.ellipse(knot, 2.3, 2.5, fill: .colour(BronzePeopleInk.verdigris), stroke: .colour(Ink.line), width: 1.1)
    }

    /// The short dark beard along the jaw: round the chin where the face shows,
    /// and at the jaw's edges below the ears from behind.
    static func beardInView(_ d: inout Drawing) {
        let view = d.view
        if view == .front || view == .frontQuarter {
            let beard = [P(-9.8, -55.6), P(-9.6, -50.8), P(-7, -46.6), P(-2.8, -44.4), P(2.8, -44.4), P(7, -46.6), P(9.6, -50.8),
                         P(9.8, -55.6), P(7.8, -53.6), P(5.8, -50.2), P(2.6, -48.8), P(-2.6, -48.8), P(-5.8, -50.2), P(-7.8, -53.6)]
            d.svg.polygon(BronzePeopleViews.onFace(view, beard), fill: .colour(Ink.line))
        } else if view == .backQuarter {
            // The beard's edge along the near jaw, under the ear.
            let p = BronzePeopleViews.onHead(view, degrees: 92, y: -51.6, out: 0.4).point
            d.svg.polygon([p + P(-1.2, -2.6), p + P(1, -2.8), p + P(0.6, 1.8), p + P(-1.4, 1.2)], fill: .colour(Ink.line))
        }
    }
}

// MARK: - The scribe (scholar)

/// A scribe in a long terracotta robe woven with pale waves and fringed at the
/// hem, a collar of gold beads, the team's stole from shoulder to hip edged in
/// the light; shaven-headed, with a gold earring and a line of kohl; nose E. He
/// carries a clay tablet; at work he holds it up and presses wedges into it with
/// a reed, murmuring, and looks up when the line is done.
struct BronzePeopleScribe: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.lean = 2
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(14.6, -33.6 - r.lift * 0.5))
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 16, kneeLift: 32, armSwing: 16)
            r.lean = 4
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(14.6, -34))
            return r
        case .working:
            return write(frame)
        default:
            return nil
        }
    }

    /// Where the reed's point is in each frame of the writing: three wedges
    /// pressed along a line (frames 1, 4 and 7), then a look up.
    static func point(_ frame: Int) -> P {
        let presses = [P(4.4, -38.6), P(6.6, -38.4), P(8.8, -38.2)]
        if frame < 9 {
            let press = presses[min(frame / 3, 2)]
            let lifted = frame % 3 != 1
            return press + (lifted ? P(0.6, -1.6) : P(0, 0))
        }
        return P(10.4, -41.6)
    }

    /// The tablet's centre when held up to be written on.
    static let tabletHeld = P(6.4, -37.4)

    func write(_ frame: Int) -> Rig {
        var r = Moves.standing(frame)
        r.lean = 4
        r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), Self.tabletHeld + P(-1.2, 3.6))
        r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), Self.point(frame) + P(3.4, -6.2))
        if frame < 9 {
            r.headTilt = frame % 3 == 1 ? 9 : 7
            r.eyes = .down
            r.mouth = frame % 2 == 0 ? .murmur : .hidden
        } else {
            r.headTilt = frame == 9 ? 2 : -2
            r.eyes = frame == 10 ? .closed : .open
            r.mouth = .smile
        }
        return r
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        d.figure { d in
            if pose != .working { d.arm(front: false) }
            d.legs()
            let hemBack = P(-16.5 - sway * 1.5, -4), hemFront = P(15.5 - sway * 1.5, -4)
            d.garment(colour: [P(-11.5, -46), P(8, -48), hemFront + P(1.5, 1.5), hemBack + P(-2, 2)],
                      outline: [P(-8, -47), P(8, -47), hemFront, hemBack], fill: .colour(BronzePeopleInk.terracotta)) { d in
                // Pale waves woven across the robe.
                for y in [-38.0, -30.0, -22.0, -14.0, -7.0] {
                    let share = (y + 47) / 43
                    let left = -8 + (hemBack.x + 8) * share + 2.2, right = 8 + (hemFront.x - 8) * share - 2.2
                    var path = PathData()
                    path.move(d.up(P(left, y)))
                    var x = left
                    var crest = true
                    while x + 3 <= right {
                        path.quad(d.up(P(x + 1.5, y + (crest ? -1.6 : 1.6))), d.up(P(x + 3, y)))
                        x += 3; crest.toggle()
                    }
                    d.svg.path(path, stroke: .colour(BronzePeopleInk.paleTerracotta), width: 1.1)
                }
                // The stole, in the team's colour, edged in the light, from the back shoulder to the front hip.
                let stole = [P(-9.6, -44), P(-4.6, -47.6), P(13.8, -25), P(12.4, -19.6)]
                d.band(stole)
                d.svg.line([d.up(stole[0]), d.up(stole[3])], stroke: .colour(BronzePeopleInk.light), width: 1.1)
                d.svg.line([d.up(stole[1]), d.up(stole[2])], stroke: .colour(BronzePeopleInk.light), width: 1.1)
            }
            // A fringe at the hem.
            var fringe = PathData()
            var x = hemBack.x + 1.2
            while x < hemFront.x - 0.6 {
                fringe.move(P(x, -4)); fringe.line(P(x - 0.4, -1.8))
                x += 2.5
            }
            d.svg.path(fringe, stroke: .colour(Ink.line), width: 1)
            // The collar of gold beads.
            for c in [P(-5.4, -46.2), P(-1.8, -45.2), P(1.8, -45), P(5.2, -45.8)] {
                d.svg.circle(d.up(c), 1.6, fill: .colour(BronzePeopleInk.gold), stroke: .colour(Ink.line), width: 0.7)
            }
            if pose == .working {
                // The tablet held up in the back hand, the reed in the front.
                d.arm(front: false)
                BronzePeopleProps.tablet(&d.svg, at: Self.tabletHeld + d.chest, degrees: -8)
                let point = Self.point(frame) + d.chest
                BronzePeopleProps.stylus(&d.svg, at: d.joints.frontHand,
                                         degrees: BronzePeopleKit.degrees(from: d.joints.frontHand, to: point),
                                         length: BronzePeopleKit.length(d.joints.frontHand - point))
                if frame % 3 == 1 && frame < 9 { d.svg.circle(point, 0.7, fill: .colour(Ink.line)) }
                if frame == 9 || frame == 10 { d.insight() }
            } else {
                BronzePeopleProps.tablet(&d.svg, at: d.joints.frontHand + P(2.2, -4), degrees: 14)
            }
            d.arm(front: true)
            d.head(nose: .line, hair: { d in
                // A shaven head: only a shadow of stubble behind the ear.
                d.svg.path("M-10.8,-61.4 C-11.8,-57 -10.8,-53.4 -8.6,-51.6", stroke: .colour(BronzePeopleInk.darkTerracotta), width: 1.2,
                           opacity: 0.5)
            }, brow: { d in
                d.svg.path("M1.4,-64 q3.4,-1.9 6.8,-0.6", stroke: .colour(Ink.line), width: 1.2)
                // A line of kohl from the eye.
                d.svg.path("M1.8,-60.4 l-3,0.9", stroke: .colour(Ink.line), width: 1.1)
            }, over: { d in
                // A gold ring in the ear.
                d.svg.circle(P(-9.8, -53.4), 1.5, fill: .none, stroke: .colour(Ink.line), width: 1.7)
                d.svg.circle(P(-9.8, -53.4), 1.5, fill: .none, stroke: .colour(BronzePeopleInk.gold), width: 0.9)
            })
        }
    }
}

extension BronzePeopleScribe {
    /// The scribe seen from another side: the waves and fringe spread round the
    /// robe, the stole crossing the chest and the back from shoulder to hip,
    /// the collar of beads in front, the tablet and reed at the hands, the kohl
    /// at the outer corner of each eye, and a gold ring in each ear that shows.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway
        d.figure { d in
            let hemBack = P(-16.5 - sway * 1.5, -4), hemFront = P(15.5 - sway * 1.5, -4)
            let outline = [P(-8, -47), P(8, -47), hemFront, hemBack]
            let backHand = BronzePeopleViews.held(d, front: false), frontHand = BronzePeopleViews.held(d, front: true)
            let tabletBehind = pose == .working ? d.armBehind(front: false) : d.armBehind(front: true)
            if pose != .working { d.arm(front: false) }
            d.legs()
            if tabletBehind { Self.tabletInView(&d, pose, frame, backHand: backHand, frontHand: frontHand) }
            d.garment(colour: [P(-11.5, -46), P(8, -48), hemFront + P(1.5, 1.5), hemBack + P(-2, 2)],
                      outline: outline, fill: .colour(BronzePeopleInk.terracotta)) { d in
                // Pale waves woven across the robe.
                for y in [-38.0, -30.0, -22.0, -14.0, -7.0] {
                    guard let seen = BronzePeopleViews.span(d.turned(outline), at: y) else { continue }
                    let left = seen.low + 2.2, right = seen.high - 2.2
                    var path = PathData()
                    path.move(d.up(P(left, y)))
                    var x = left
                    var crest = true
                    while x + 3 <= right {
                        path.quad(d.up(P(x + 1.5, y + (crest ? -1.6 : 1.6))), d.up(P(x + 3, y)))
                        x += 3; crest.toggle()
                    }
                    d.svg.path(path, stroke: .colour(BronzePeopleInk.paleTerracotta), width: 1.1)
                }
                // The stole, in the team's colour, edged in the light: over the left
                // shoulder, across the chest and the back to the right hip.
                for via in [0.0, 180.0] {
                    for run in BronzePeopleViews.across(d, on: outline, top: (-44.4, 270), bottom: (-23, 90), via: via, width: 5.6) {
                        let band = run.map(d.up)
                        d.svg.polygon(band, fill: .team)
                        let n = band.count / 2
                        d.svg.line(Array(band[0..<n]), stroke: .colour(BronzePeopleInk.light), width: 1.1)
                        d.svg.line(Array(band[n...]), stroke: .colour(BronzePeopleInk.light), width: 1.1)
                    }
                }
            }
            // A fringe at the hem.
            var fringe = PathData()
            if let seen = BronzePeopleViews.span(d.turned(outline), at: -4.2) {
                var x = seen.low + 1.2
                while x < seen.high - 0.6 {
                    fringe.move(P(x, -4)); fringe.line(P(x - 0.4, -1.8))
                    x += 2.5
                }
            }
            d.svg.path(fringe, stroke: .colour(Ink.line), width: 1)
            // The collar of gold beads, round the front of the neck.
            for degrees in [-54.0, -18.0, 18.0, 54.0] {
                let bead = BronzePeopleViews.round(d, on: [P(-6, -47), P(6, -47), P(6, -44), P(-6, -44)], at: -45.6, degrees: degrees)
                guard bead.facing > 0.1 else { continue }
                d.svg.circle(d.up(bead.point), 1.6, fill: .colour(BronzePeopleInk.gold), stroke: .colour(Ink.line), width: 0.7)
            }
            if pose == .working { d.arm(front: false) }
            if !tabletBehind { Self.tabletInView(&d, pose, frame, backHand: backHand, frontHand: frontHand) }
            if pose == .working && (frame == 9 || frame == 10) { d.insight() }
            d.arm(front: true)
            d.head(nose: .line, hair: { d in
                // A shaven head: only a shadow of stubble round the back.
                for run in BronzePeopleViews.patch(d.view, from: 105, to: 255, out: -0.6, top: { _ in -61.4 },
                                                   bottom: { a in -51.6 - 4 * pow(cos(a * .pi / 180), 2) }) {
                    d.svg.polygon(run, fill: .colour(BronzePeopleInk.darkTerracotta), opacity: 0.22)
                }
            }, brow: { d in
                d.svg.path("M1.4,-64 q3.4,-1.9 6.8,-0.6", stroke: .colour(Ink.line), width: 1.2)
                // A line of kohl from the outer corner of the eye.
                d.svg.path("M7.2,-60.4 l3,0.9", stroke: .colour(Ink.line), width: 1.1)
            }, over: { d in
                // A gold ring in each ear that shows.
                let rings: [P] = switch d.view {
                case .front, .back: [P(-11.2, -53.2), P(11.2, -53.2)]
                case .frontQuarter: [P(-8.4, -53.2)]
                case .backQuarter: [P(7, -53.6)]
                case .side: []
                }
                for ring in rings {
                    d.svg.circle(ring, 1.5, fill: .none, stroke: .colour(Ink.line), width: 1.7)
                    d.svg.circle(ring, 1.5, fill: .none, stroke: .colour(BronzePeopleInk.gold), width: 0.9)
                }
            })
        }
    }

    /// The tablet and the reed: held up and written on at work, carried in the front hand otherwise.
    static func tabletInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, backHand: (P) -> P, frontHand: (P) -> P) {
        if pose == .working {
            BronzePeopleProps.tablet(&d.svg, at: backHand(tabletHeld + d.chest), degrees: -8)
            let point = backHand(Self.point(frame) + d.chest), hand = d.hand(front: true)
            BronzePeopleProps.stylus(&d.svg, at: hand, degrees: BronzePeopleKit.degrees(from: hand, to: point),
                                     length: BronzePeopleKit.length(hand - point))
            if frame % 3 == 1 && frame < 9 { d.svg.circle(point, 0.7, fill: .colour(Ink.line)) }
        } else {
            BronzePeopleProps.tablet(&d.svg, at: frontHand(d.joints.frontHand + P(2.2, -4)), degrees: 14)
        }
    }
}

// MARK: - The mason (engineer)

/// A stocky mason in a verdigris tunic woven with light dashes, the team's
/// apron trimmed in the light over it, a leather belt with a bronze chisel in
/// it; bald on the crown, with a square black beard and a heavy brow; nose B.
/// He carries a bronze-headed hammer; at work he dresses a block of stone,
/// and chips fly at each blow; fighting, he swings the hammer.
struct BronzePeopleMason: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.mouth = .hidden
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 22)
            r.mouth = .hidden
            return r
        case .working:
            let (angle, landing) = Moves.blow(frame, ready: 62, raised: 165, struck: 34, raiseFrames: 7)
            var r = Rig()
            r.backLeg = Limb(-14, 6); r.frontLeg = Limb(24, 30)
            r.lean = 16
            r.frontArm = Limb(angle, -4)
            r.backArm = Limb(30, 34)
            r.mouth = .hidden
            r.eyes = landing ? .closed : .down
            return r
        case .fighting:
            let (angle, landing) = Moves.blow(frame, ready: 80, raised: 185, struck: 70)
            var r = Rig()
            r.frontArm = Limb(angle, -6)
            r.backArm = Limb(-30 + (angle - 80) * 0.25, -10)
            r.backLeg = Limb(-18, 6)
            r.frontLeg = frame >= 6 && frame <= 9 ? Limb(22, 12) : Limb(12, 8)
            r.lean = frame < 6 ? -4 : (frame <= 9 ? 10 : 2)
            r.mouth = .hidden
            r.eyes = landing ? .wide : .open
            return r
        default:
            return nil
        }
    }

    /// The frame on which the hammer meets the stone.
    static let strike = 9

    /// The hammer's direction from the hand for a pose.
    static func hammerDegrees(_ pose: SpritePose, _ rig: Rig) -> Double {
        switch pose {
        case .working, .fighting: rig.frontArm.upper + 10
        default: rig.frontArm.upper + rig.frontArm.bend + 14
        }
    }

    /// Where the hammer's face meets the block, in the picture: the block's top is set there.
    static let stoneTop: P = {
        let rig = BronzePeopleMason().rig(.working, strike)!
        let d = Drawing(layer: .base, rig: rig, phase: 0)
        return d.world(BronzePeopleProps.hammerFace(at: d.joints.frontHand, degrees: hammerDegrees(.working, rig)))
    }()

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        if pose == .working {
            let top = Self.stoneTop
            BronzePeopleProps.block(&d.svg, left: top.x - 7, width: 17, height: -top.y)
        }
        d.figure { d in
            d.arm(front: false)
            d.legs()
            d.garment(colour: [P(-13, -46), P(9, -48), P(15, -13), P(-17, -12.5)],
                      outline: [P(-9, -47), P(9, -47), P(14, -15), P(-15.5, -15)], fill: .colour(BronzePeopleInk.verdigris)) { d in
                // Light dashes woven in rows.
                var dashes = PathData()
                for (row, y) in [-42.5, -37.5, -21.5].enumerated() {
                    let share = (y + 47) / 32
                    let left = -9 - 6.5 * share + 2, right = 9 + 5 * share - 2
                    var x = left + (row % 2 == 0 ? 0 : 1.5)
                    while x + 1.4 <= right {
                        dashes.move(d.up(P(x, y))); dashes.line(d.up(P(x + 1.4, y)))
                        x += 3
                    }
                }
                d.svg.path(dashes, stroke: .colour(BronzePeopleInk.light), width: 1)
                // The apron, in the team's colour, bordered in the light so that it
                // stands apart from the tunic whatever the team's colour.
                d.svg.polygon([P(0.2, -33.2), P(14.8, -34.2), P(17.6, -11.2), P(2.4, -10.6)].map(d.up), fill: .colour(BronzePeopleInk.light))
                d.band([P(2.4, -31.8), P(12.8, -32.6), P(15.2, -12.6), P(4.4, -12.2)])
            }
            d.svg.polygon([P(0.8, -33), P(14.4, -34), P(17, -11.2), P(2.8, -10.6)].map(d.up), fill: .none,
                          stroke: .colour(Ink.line), width: 1.3)
            // A fringe at the apron's foot.
            var tassels = PathData()
            for i in 0..<6 {
                let x = 4 + Double(i) * 2.4
                tassels.move(P(x, -10.8)); tassels.line(P(x + 0.2, -8.6))
            }
            d.svg.path(tassels, stroke: .colour(Ink.line), width: 1)
            // The belt, its bronze buckle, and a chisel tucked into it.
            BronzePeopleProps.chisel(&d.svg, from: d.up(P(-8.6, -38.4)), degrees: -14, length: 8.5)
            d.svg.line([d.up(P(-11.4, -33.4)), d.up(P(13.6, -34.4))], stroke: .colour(BronzePeopleInk.leather), width: 2.4)
            d.svg.polygon([P(5.6, -35.8), P(8.4, -35.9), P(8.4, -32.9), P(5.6, -32.8)].map(d.up), fill: .colour(BronzePeopleInk.bronze),
                          stroke: .colour(Ink.line), width: 0.8)
            let hand = d.joints.frontHand
            let degrees = Self.hammerDegrees(pose, d.rig)
            BronzePeopleProps.hammer(&d.svg, at: hand, degrees: degrees)
            switch pose {
            case .working:
                if frame == Self.strike || frame == Self.strike + 1 {
                    let face = BronzePeopleProps.hammerFace(at: hand, degrees: degrees)
                    BronzePeopleProps.oreChips(&d.svg, at: face + P(1.5, 0), spread: frame == Self.strike ? 0 : 1)
                }
            case .fighting:
                if frame == 7 { d.swish(around: d.joints.frontShoulder, radius: 24, from: 165, to: 90) }
                if frame == 8 { d.impact(at: BronzePeopleProps.hammerFace(at: hand, degrees: degrees), size: 0.9) }
            default:
                break
            }
            d.arm(front: true, width: 2.2)
            d.head(nose: .button, hair: { d in
                // Black hair round the back of a bald crown.
                d.svg.path("M-10.9,-61.6 C-12.4,-56.6 -10.8,-51.2 -6.8,-49.2 C-6.8,-52.8 -7.4,-56.6 -5.8,-60.4 "
                           + "C-7.6,-60 -9.6,-60.4 -10.9,-61.6 Z", fill: .colour(Ink.line))
            }, features: { d in
                // A square black beard, its waves combed in rows, and a moustache over the mouth.
                d.svg.path("M-5.6,-54.6 C-5.8,-49.6 -4.6,-44.6 -1.4,-42 L10.4,-42.4 C11.6,-45.2 11.6,-48.4 10.8,-51 "
                           + "C8.2,-49.8 5.4,-50 3,-50.8 C0.2,-51.8 -2.8,-53.4 -5.6,-54.6 Z", fill: .colour(Ink.line))
                d.svg.path("M-2,-47.4 q2.2,-1 4.4,0 q2.2,1 4.4,0 M-0.6,-44.6 q2.2,-1 4.4,0 q2.2,1 4.4,0",
                           stroke: .colour("#5a4c44"), width: 0.8)
                d.svg.path("M3.6,-52.6 q3.8,-2.4 7.8,-0.4 q-1.4,1.8 -3.8,1 q-2.4,1 -4,-0.6 Z", fill: .colour(Ink.line))
            }, brow: { d in
                d.svg.path("M1,-64.2 q3.8,-2.2 7.8,-0.6", stroke: .colour(Ink.line), width: 2)
            })
        }
    }
}

extension BronzePeopleMason {
    /// The mason seen from another side: the block before him (or beyond him,
    /// from behind), the dashes and belt spread round the tunic, the apron on
    /// his front and its ties at his back, the chisel in the belt behind, the
    /// hammer in the figure's own plane, the hair round the back of the crown
    /// and the square beard as the view shows them.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let back = BronzePeopleViews.seesBack(d.view)
        if pose == .working && back { Self.blockInView(&d) }
        d.figure { d in
            let outline = [P(-9, -47), P(9, -47), P(14, -15), P(-15.5, -15)]
            let hammerBehind = d.armBehind(front: true)
            d.arm(front: false)
            d.legs()
            if hammerBehind { Self.hammerInView(&d, pose, frame) }
            d.garment(colour: [P(-13, -46), P(9, -48), P(15, -13), P(-17, -12.5)],
                      outline: outline, fill: .colour(BronzePeopleInk.verdigris)) { d in
                // Light dashes woven in rows.
                var dashes = PathData()
                for (row, y) in [-42.5, -37.5, -21.5].enumerated() {
                    guard let seen = BronzePeopleViews.span(d.turned(outline), at: y) else { continue }
                    var x = seen.low + 2 + (row % 2 == 0 ? 0 : 1.5)
                    while x + 1.4 <= seen.high - 2 {
                        dashes.move(d.up(P(x, y))); dashes.line(d.up(P(x + 1.4, y)))
                        x += 3
                    }
                }
                d.svg.path(dashes, stroke: .colour(BronzePeopleInk.light), width: 1)
            }
            // The belt round the waist, the chisel tucked into it behind.
            let belt = BronzePeopleViews.span(d.turned(outline), at: -33.9) ?? (-10, 10)
            let chisel = BronzePeopleViews.round(d, on: outline, at: -38.4, degrees: 205, out: 0.6)
            if chisel.facing > 0.2 {
                BronzePeopleProps.chisel(&d.svg, from: d.up(chisel.point), degrees: -14 * BronzePeopleViews.across(d.view), length: 8.5)
            }
            d.svg.line([d.up(P(belt.low, -33.4)), d.up(P(belt.high, -34.4))], stroke: .colour(BronzePeopleInk.leather), width: 2.4)
            if back {
                Self.apronTies(&d, outline: outline)
            } else {
                Self.apronInView(&d, outline: outline)
            }
            if !hammerBehind { Self.hammerInView(&d, pose, frame) }
            d.arm(front: true, width: 2.2)
            d.head(nose: .button, hair: { d in
                // Black hair round the back of a bald crown.
                for run in BronzePeopleViews.patch(d.view, from: 112, to: 248, out: 0.1, top: { _ in -60.4 },
                                                   bottom: { a in -51.4 - 7 * pow(min(abs(a - 180) / 68, 1), 2) }) {
                    d.svg.polygon(run, fill: .colour(Ink.line))
                }
            }, features: { d in
                Self.beardInView(&d)
            }, brow: { d in
                d.svg.path("M1,-64.2 q3.8,-2.2 7.8,-0.6", stroke: .colour(Ink.line), width: 2)
            })
        }
        if pose == .working && !back { Self.blockInView(&d) }
    }

    /// The hammer in the figure's own plane, and where it lands.
    static func hammerInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let hand = d.joints.frontHand, map = BronzePeopleViews.held(d, front: true)
        let degrees = hammerDegrees(pose, d.rig)
        BronzePeopleProps.hammer(&d.svg, at: hand, degrees: degrees, map: map)
        if pose == .fighting && frame == 8 { d.impact(at: map(BronzePeopleProps.hammerFace(at: hand, degrees: degrees)), size: 0.9) }
    }

    /// The block of stone on the ground before him, as wide as the view shows it, its top where the hammer lands.
    static func blockInView(_ d: inout Drawing) {
        let top = stoneTop, yaw = d.yaw * .pi / 180
        let centre = (top.x + 1.5) * BronzePeopleViews.across(d.view)
        let width = 17 * abs(cos(yaw)) + 13 * abs(sin(yaw))
        BronzePeopleProps.block(&d.svg, left: centre - width / 2, width: width, height: -top.y)
    }

    /// The apron on his front: the light border, the team's colour within, and the fringe at its foot.
    static func apronInView(_ d: inout Drawing, outline: [P]) {
        func at(_ y: Double, _ half: Double) -> [P] {
            let front = BronzePeopleViews.round(d, on: outline, at: y, degrees: 0)
            let k = max(front.facing, 0.35)
            return [front.point + P(-half * k, 0), front.point + P(half * k, 0)]
        }
        let top = at(-33.4, 7.2), foot = at(-10.8, 8)
        let border = [top[0], top[1], foot[1], foot[0]].map(d.up)
        d.svg.polygon(border.map { $0 + P(-0.6, 0.5) }, fill: .colour(BronzePeopleInk.light))
        let inTop = at(-31.8, 5.4), inFoot = at(-12.4, 6.2)
        d.svg.polygon([inTop[0], inTop[1], inFoot[1], inFoot[0]].map(d.up), fill: .team)
        d.svg.polygon(border, fill: .none, stroke: .colour(Ink.line), width: 1.3)
        var tassels = PathData()
        for i in 0..<6 {
            let p = foot[0] + (foot[1] - foot[0]) * ((Double(i) + 0.5) / 6)
            tassels.move(P(p.x, -10.8)); tassels.line(P(p.x + 0.2, -8.6))
        }
        d.svg.path(tassels, stroke: .colour(Ink.line), width: 1)
        let buckle = BronzePeopleViews.round(d, on: outline, at: -34.4, degrees: 0)
        if buckle.facing > 0.2 {
            let c = d.up(buckle.point)
            d.svg.polygon([c + P(-1.4, -1.5), c + P(1.4, -1.5), c + P(1.4, 1.5), c + P(-1.4, 1.5)], fill: .colour(BronzePeopleInk.bronze),
                          stroke: .colour(Ink.line), width: 0.8)
        }
    }

    /// The apron's ties, in the team's colour, knotted at the small of his back.
    static func apronTies(_ d: inout Drawing, outline: [P]) {
        let knot = d.up(BronzePeopleViews.round(d, on: outline, at: -33.6, degrees: 180, out: 0.4).point)
        for (dx, length) in [(-1.6, 7.6), (1.6, 6.2)] {
            let end = knot + P(dx * 1.4, length)
            d.svg.polygon([knot + P(-1, 0), knot + P(1, 0), end + P(0.9, 0), end + P(-0.9, 0)], fill: .team,
                          stroke: .colour(Ink.line), width: 0.9)
        }
        for dx in [-1.0, 1.0] {
            d.svg.ellipse(knot + P(dx * 2.4, -0.4), 2.4, 1.5, fill: .team, stroke: .colour(Ink.line), width: 0.9)
        }
        d.svg.circle(knot, 1.2, fill: .team, stroke: .colour(Ink.line), width: 0.9)
    }

    /// The square black beard and the moustache over the mouth, where the face
    /// shows; from behind, the beard's edges beside the jaw.
    static func beardInView(_ d: inout Drawing) {
        let view = d.view
        if view == .front || view == .frontQuarter {
            let beard = [P(-10, -55.4), P(-10.2, -47.4), P(-7.6, -42), P(7.6, -42), P(10.2, -47.4), P(10, -55.4),
                         P(7.8, -53.6), P(4.6, -51.8), P(0, -51.6), P(-4.6, -51.8), P(-7.8, -53.6)]
            d.svg.polygon(BronzePeopleViews.onFace(view, beard), fill: .colour(Ink.line))
            d.svg.line(BronzePeopleViews.onFace(view, [P(-5, -47.4), P(-2.5, -48.2), P(0, -47.4), P(2.5, -46.6), P(5, -47.4)]),
                       stroke: .colour("#5a4c44"), width: 0.8)
            d.svg.line(BronzePeopleViews.onFace(view, [P(-5, -44.6), P(-2.5, -45.4), P(0, -44.6), P(2.5, -43.8), P(5, -44.6)]),
                       stroke: .colour("#5a4c44"), width: 0.8)
            let moustache = [P(-5.4, -51.4), P(-2.4, -53.4), P(0, -52.6), P(2.4, -53.4), P(5.4, -51.4), P(2.4, -50.6), P(0, -51.2),
                             P(-2.4, -50.6)]
            d.svg.polygon(BronzePeopleViews.onFace(view, moustache.map { $0 + P(view == .frontQuarter ? 0.8 : 0, 0) }), fill: .colour(Ink.line))
        } else {
            for side in [-96.0, 96.0] {
                let jaw = BronzePeopleViews.onHead(view, degrees: side, y: -49, out: 0.6)
                guard jaw.facing > 0.15 else { continue }
                let p = jaw.point, outward = p.x > 0 ? 1.0 : -1.0
                d.svg.polygon([p + P(-1.6 * outward, -4), p + P(1.2 * outward, -3.6), p + P(1.6 * outward, 3), p + P(-1.4 * outward, 3.4)],
                              fill: .colour(Ink.line))
            }
        }
    }
}

// MARK: - The trader (merchant)

/// A well-fed trader in a skirt of tiered fleece (the kaunakes), a light
/// tunic, a fringed terracotta shawl over one shoulder and a belt; a full curly
/// beard, a terracotta cap with a light band, a heavy brow; nose F. On his back
/// he carries a bale of goods wrapped in the team's colour; at work he weighs
/// gold against bronze on a hand balance and watches the pans settle.
struct BronzePeopleTrader: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(10.4, -38.6 - r.lift))
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 18, kneeLift: 34, armSwing: 18)
            r.lean = 4
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(10.4, -38.6))
            return r
        case .working:
            var r = Moves.standing(frame)
            r.lean = -2
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(21.2, -46.2 - r.lift))
            r.backArm = Limb(18, 26)
            r.headTilt = 3 + 2 * BronzePeopleKit.wave(frame)
            r.eyes = frame == 8 ? .closed : .down
            r.mouth = frame >= 9 ? .smile : .murmur
            return r
        default:
            return nil
        }
    }

    /// The balance's beam in each frame of the weighing: a swing that dies away
    /// toward the end of the cycle and is set going again.
    static func tilt(_ frame: Int) -> Double { 11 * sin(Double(frame) / 12 * 2 * .pi) * (1 - Double(frame) / 16) }

    /// The trader's outline: a round belly over a long skirt.
    static func body(_ d: Drawing, _ o: P) -> PathData {
        func at(_ p: P) -> P { d.up(p) + o }
        var p = PathData()
        p.move(at(P(-8, -47)))
        p.line(at(P(8.6, -47)))
        p.cubic(at(P(13.6, -43)), at(P(17.6, -35)), at(P(16.8, -27.6)))
        p.cubic(at(P(16.2, -21)), at(P(15.8, -13)), at(P(16.8, -5.6)))
        p.line(at(P(-16.6, -5.6)))
        p.cubic(at(P(-14.8, -15)), at(P(-13.4, -27)), at(P(-12.4, -35.6)))
        p.cubic(at(P(-11.6, -41.6)), at(P(-10.2, -45.2)), at(P(-8, -47)))
        p.close()
        return p
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let bounce = pose == .walking ? 1.3 * BronzePeopleKit.wave(frame, -0.2, times: 2) : 0.4 * BronzePeopleKit.wave(frame)
        d.figure { d in
            // The bale on his back.
            BronzePeopleProps.bale(&d.svg, at: d.up(P(-19.4, -46)) + P(0, bounce), width: 17, height: 24, degrees: -8)
            d.arm(front: false)
            d.legs()
            d.svg.path(Self.body(d, P(-1.1, 1)), fill: .colour(BronzePeopleInk.light))
            // The tiers of fleece, each a row of tufts.
            var tufts = PathData()
            for y in [-24.0, -17.0, -10.0] {
                let share = (y + 35.6) / 30
                let left = -12.4 - 4.2 * share + 0.8, right = 16.2
                var x = left
                tufts.move(P(x, y))
                while x + 2.6 <= right {
                    tufts.quad(P(x + 1.3, y + 2.4), P(x + 2.6, y))
                    x += 2.6
                }
            }
            d.svg.path(tufts, stroke: .colour(BronzePeopleInk.terracotta), width: 1.1)
            var hairs = PathData()
            for y in [-27.4, -20.4, -13.4] {
                var x = -11.6
                while x < 15 {
                    hairs.move(P(x, y)); hairs.line(P(x + 0.3, y + 2))
                    x += 2.6
                }
            }
            d.svg.path(hairs, stroke: .colour(BronzePeopleInk.paleTerracotta), width: 0.8)
            // The shawl over the front shoulder, fringed along its edge.
            let shawl = [P(-9.4, -46.6), P(-2.6, -47.4), P(16.4, -31.2), P(15.6, -26), P(10.6, -26.6)]
            d.svg.polygon(shawl.map { d.up($0) + P(-0.8, 0.7) }, fill: .colour(BronzePeopleInk.terracotta))
            var edge = PathData()
            for i in 0...6 {
                let t = Double(i) / 6
                let p = d.up(P(-9.4, -46.6) + (P(10.6, -26.6) - P(-9.4, -46.6)) * t)
                edge.move(p); edge.line(p + P(-1.6, 1.4))
            }
            d.svg.path(edge, stroke: .colour(Ink.line), width: 0.9)
            d.svg.polygon(shawl.map(d.up), fill: .none, stroke: .colour(Ink.line), width: 1.3)
            d.svg.line([d.up(P(-12.6, -30.6)), d.up(P(16.6, -30.4))], stroke: .colour(BronzePeopleInk.leather), width: 2.2)
            d.svg.path(Self.body(d, P(0, 0)), stroke: .colour(Ink.line), width: 1.8)
            // The strap of the bale, over the shoulder.
            d.svg.line([d.up(P(-12.2, -52)), d.up(P(-5, -47.6)), d.up(P(3.6, -46.4)), d.up(P(10.4, -40))],
                       stroke: .colour(BronzePeopleInk.leather), width: 1.9)
            if pose == .working {
                BronzePeopleProps.balance(&d.svg, from: d.joints.frontHand, tilt: Self.tilt(frame))
            }
            d.arm(front: true)
            d.head(nose: .bulb, hair: { d in
                // Dark curls at the back, under the cap.
                d.svg.path("M-11,-61 C-12.6,-56 -11,-51.6 -7.4,-50.4 C-7.6,-53.6 -7.6,-56.4 -6.2,-59.4 Z", fill: .colour(Ink.line))
            }, features: { d in
                // A full, curly beard and a moustache.
                d.svg.path("M-6.4,-55.4 C-7.4,-48.6 -3.6,-42.8 3.4,-42.2 C8.4,-41.8 11.8,-44.8 11.6,-49.6 "
                           + "C9.2,-48.6 6.6,-48.6 4.6,-49.4 C1.4,-50.6 -2.6,-52.8 -6.4,-55.4 Z", fill: .colour(Ink.line))
                d.svg.path("M-3,-48.6 q1,-1.4 2,0 M0.6,-45.6 q1,-1.4 2,0 M4.4,-44.8 q1,-1.4 2,0 M7.6,-46.6 q1,-1.4 2,0 M-4,-51.6 q1,-1.4 2,0",
                           stroke: .colour("#5a4c44"), width: 0.8)
                d.svg.path("M4.2,-52.6 q3.6,-2.2 7.4,-0.4 q-1.2,1.8 -3.6,1 q-2.4,0.8 -3.8,-0.6 Z", fill: .colour(Ink.line))
            }, brow: { d in
                d.svg.path("M1,-64.4 q4,-2.6 8,-0.8", stroke: .colour(Ink.line), width: 2)
            }, over: { d in
                // A terracotta cap with a light band.
                BronzePeopleProps.shape(&d.svg, fill: .colour(BronzePeopleInk.terracotta), width: 1.5) { o in
                    var p = PathData()
                    p.move(P(-10.4, -62) + o)
                    p.cubic(P(-12.2, -76.2) + o, P(7, -78.2) + o, P(9.8, -64) + o)
                    p.cubic(P(3.8, -66.4) + o, P(-3.6, -65.6) + o, P(-10.4, -62) + o)
                    p.close()
                    return p
                }
                d.svg.path("M9.2,-65.8 C3.4,-68 -3.6,-67.4 -10.4,-64", stroke: .colour(BronzePeopleInk.light), width: 1.4)
            })
        }
    }
}

extension BronzePeopleTrader {
    /// The trader's outline in profile, as points: the belly over the skirt, for the kit to turn.
    static let outline: [P] = {
        var points: [P] = [P(-8, -47), P(8.6, -47)]
        func cubic(_ a: P, _ b: P, _ c: P, _ e: P) {
            for i in 1...8 {
                let t = Double(i) / 8, m = 1 - t
                points.append(a * (m * m * m) + b * (3 * m * m * t) + c * (3 * m * t * t) + e * (t * t * t))
            }
        }
        cubic(P(8.6, -47), P(13.6, -43), P(17.6, -35), P(16.8, -27.6))
        cubic(P(16.8, -27.6), P(16.2, -21), P(15.8, -13), P(16.8, -5.6))
        points.append(P(-16.6, -5.6))
        cubic(P(-16.6, -5.6), P(-14.8, -15), P(-13.4, -27), P(-12.4, -35.6))
        cubic(P(-12.4, -35.6), P(-11.6, -41.6), P(-10.2, -45.2), P(-8, -47))
        points.removeLast()
        return points
    }()

    /// The trader seen from another side: the bale on his back, wider than he
    /// is, the fleece's tiers and the belt round the body, the shawl from the
    /// left shoulder across to the right hip, the straps of the bale, the
    /// balance in the figure's own plane, and the cap, curls and beard as the
    /// view shows them.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let bounce = pose == .walking ? 1.3 * BronzePeopleKit.wave(frame, -0.2, times: 2) : 0.4 * BronzePeopleKit.wave(frame)
        let back = BronzePeopleViews.seesBack(d.view)
        d.figure { d in
            let outline = Self.outline
            if !back { Self.baleInView(&d, bounce: bounce) }
            d.arm(front: false)
            d.legs()
            let body = d.turned(outline).map(d.up)
            d.svg.polygon(body.map { $0 + P(-1.1, 1) }, fill: .colour(BronzePeopleInk.light))
            // The tiers of fleece, each a row of tufts, round the skirt.
            var tufts = PathData(), hairs = PathData()
            for y in [-24.0, -17.0, -10.0] {
                guard let seen = BronzePeopleViews.span(body, at: y) else { continue }
                var x = seen.low + 0.8
                tufts.move(P(x, y))
                while x + 2.6 <= seen.high - 0.6 {
                    tufts.quad(P(x + 1.3, y + 2.4), P(x + 2.6, y))
                    hairs.move(P(x + 0.4, y - 3.4)); hairs.line(P(x + 0.7, y - 1.4))
                    x += 2.6
                }
            }
            d.svg.path(tufts, stroke: .colour(BronzePeopleInk.terracotta), width: 1.1)
            d.svg.path(hairs, stroke: .colour(BronzePeopleInk.paleTerracotta), width: 0.8)
            // The shawl over the left shoulder, across the chest and the back to the right hip, fringed along its lower edge.
            for via in [0.0, 180.0] {
                for run in BronzePeopleViews.across(d, on: outline, top: (-43, 270), bottom: (-29, 90), via: via, width: 8) {
                    let shawl = run.map(d.up)
                    d.svg.polygon(shawl.map { $0 + P(-0.8, 0.7) }, fill: .colour(BronzePeopleInk.terracotta))
                    var edge = PathData()
                    for p in shawl[(shawl.count / 2)...] { edge.move(p); edge.line(p + P(-0.6, 1.8)) }
                    d.svg.path(edge, stroke: .colour(Ink.line), width: 0.9)
                    d.svg.polygon(shawl, fill: .none, stroke: .colour(Ink.line), width: 1.3)
                }
            }
            if let belt = BronzePeopleViews.span(d.turned(outline), at: -30.5) {
                d.svg.line([d.up(P(belt.low + 0.2, -30.6)), d.up(P(belt.high - 0.2, -30.4))], stroke: .colour(BronzePeopleInk.leather), width: 2.2)
            }
            d.svg.polygon(body, fill: .none, stroke: .colour(Ink.line), width: 1.8)
            // The straps of the bale, over both shoulders.
            if !back {
                for side in [-1.0, 1.0] {
                    let top = BronzePeopleViews.round(d, on: outline, at: -46.6, degrees: 90 * side, out: -1.6).point
                    let low = BronzePeopleViews.round(d, on: outline, at: -38, degrees: 60 * side, out: 0.2)
                    guard low.facing > 0 else { continue }
                    d.svg.line([d.up(top), d.up(low.point)], stroke: .colour(BronzePeopleInk.leather), width: 1.9)
                }
            }
            if pose == .working {
                BronzePeopleProps.balance(&d.svg, from: d.joints.frontHand, tilt: Self.tilt(frame), map: BronzePeopleViews.held(d, front: true))
            }
            d.arm(front: true)
            d.head(nose: .bulb, hair: { d in
                // Dark curls at the back, under the cap.
                for run in BronzePeopleViews.patch(d.view, from: 115, to: 245, out: 0.2, top: Self.capEdge,
                                                   bottom: { a in -50.6 - 7 * pow(min(abs(a - 180) / 65, 1), 2) }) {
                    d.svg.polygon(run, fill: .colour(Ink.line))
                }
            }, features: { d in
                Self.beardInView(&d)
            }, brow: { d in
                d.svg.path("M1,-64.4 q4,-2.6 8,-0.8", stroke: .colour(Ink.line), width: 2)
            }, over: { d in
                // A terracotta cap with a light band.
                BronzePeopleProps.shape(&d.svg, BronzePeopleViews.dome(d.view, out: 0.9, crown: 6, rim: Self.capEdge),
                                        fill: .colour(BronzePeopleInk.terracotta), width: 1.5)
                d.svg.line(Array(BronzePeopleViews.ring(d.view, out: 1.1) { Self.capEdge($0) - 1.8 }.dropFirst(1).dropLast(1)),
                           stroke: .colour(BronzePeopleInk.light), width: 1.4)
            })
            if back { Self.baleInView(&d, bounce: bounce) }
        }
    }

    /// The cap's edge round the head.
    static let capEdge = BronzePeopleViews.edge(front: -64.6, side: -63, back: -61.6)

    /// The bale on his back: seen across its breadth from behind or in front, its depth from the side.
    static func baleInView(_ d: inout Drawing, bounce: Double) {
        let yaw = d.yaw * .pi / 180
        let at = BronzePeopleViews.round(d, on: outline, at: -46, degrees: 180, out: 8.4).point
        let width = 17 * abs(cos(yaw)) + 28 * abs(sin(yaw))
        BronzePeopleProps.bale(&d.svg, at: d.up(at) + P(0, bounce), width: width, height: 24, degrees: -8 * cos(yaw))
    }

    /// The full, curly beard and the moustache where the face shows; from behind, the beard's edges beside the jaw.
    static func beardInView(_ d: inout Drawing) {
        let view = d.view
        if view == .front || view == .frontQuarter {
            let beard = [P(-10.4, -55.6), P(-10.6, -48.6), P(-7.4, -43.4), P(-2.6, -41.2), P(2.6, -41.2), P(7.4, -43.4), P(10.6, -48.6),
                         P(10.4, -55.6), P(8, -53.4), P(4.8, -50.2), P(0, -49.6), P(-4.8, -50.2), P(-8, -53.4)]
            d.svg.polygon(BronzePeopleViews.onFace(view, beard), fill: .colour(Ink.line))
            var curls = PathData()
            for c in [P(-6, -47.6), P(-2, -45.4), P(2, -45.4), P(6, -47.6), P(-4, -43.2), P(0, -42.6), P(4, -43.2)] {
                let p = BronzePeopleViews.onFace(view, [c])[0]
                curls.move(p); curls.quad(p + P(1, -1.4), p + P(2, 0))
            }
            d.svg.path(curls, stroke: .colour("#5a4c44"), width: 0.8)
            let moustache = [P(-5.6, -50.8), P(-2.4, -53.2), P(0, -52.4), P(2.4, -53.2), P(5.6, -50.8), P(2.4, -50.4), P(0, -50.8),
                             P(-2.4, -50.4)]
            d.svg.polygon(BronzePeopleViews.onFace(view, moustache.map { $0 + P(view == .frontQuarter ? 0.8 : 0, 0) }), fill: .colour(Ink.line))
        } else {
            for side in [-96.0, 96.0] {
                let jaw = BronzePeopleViews.onHead(view, degrees: side, y: -49, out: 0.8)
                guard jaw.facing > 0.15 else { continue }
                let p = jaw.point, outward = p.x > 0 ? 1.0 : -1.0
                d.svg.polygon([p + P(-1.6 * outward, -4), p + P(1.4 * outward, -3.6), p + P(1.8 * outward, 3.4), p + P(-1.4 * outward, 3.8)],
                              fill: .colour(Ink.line))
            }
        }
    }
}
