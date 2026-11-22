// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The worker in the Bronze look: the herder, in woven and dyed cloth and
// carrying bronze, with a nose of his own (docs/art-style.md, "Noses"), moving
// on the shared skeleton. The team's colour is where the Stone look put it:
// the sash.

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
