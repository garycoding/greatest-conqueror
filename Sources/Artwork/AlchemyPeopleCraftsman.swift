// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The peaceful sectors in their Alchemy-age looks wear the dress of the late
// Middle Ages and the first modern centuries in the age's colours, each with a
// nose of its own (docs/art-style.md, "Noses") different from his Iron and
// Bronze stages', and move on the shared skeleton. The team's colour is where
// the earlier ages put it for the same sector, and never beside the age's wine
// or gilt, so that Rome's red and Angkor's orange stay distinct from them: the
// craftsman's sash, the alchemist's stole, the gunsmith's cap, and the banker's
// doublet between the fur of his gown.

// MARK: - The craftsman (worker)

/// A joiner in a smock of undyed linen smocked across the chest in teal, the
/// team's sash at his waist, a half apron of teal canvas with a chisel in its
/// pocket, a soft wine-coloured cap, brown sideburns and a carpenter's pencil
/// behind his ear; nose C. He carries his tool-tote, the mallet in it among the
/// saw and the square; at work he sets it down and carves an oak block on his bench,
/// the chisel in one hand and the mallet tapping it home with the other, two
/// blows to the cycle and shavings flying at each; fighting, he swings the mallet.
struct AlchemyPeopleCraftsman: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.frontArm = Limb(12 + r.lift, -4)
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 23, kneeLift: 44, armSwing: 26)
            r.frontArm = Limb(8 + 9 * BronzePeopleKit.wave(frame, 0.5), -5)
            return r
        case .working:
            return carving(frame)
        case .fighting:
            return swing(frame)
        default:
            return nil
        }
    }

    // MARK: Carving

    /// The lean over the bench, rocking a little into each blow; the second
    /// blow of the cycle is the lighter, so that the two halves differ.
    static let carvingLean: [Double] = [26, 25.4, 25, 24.8, 25.6, 27, 25.8, 25.3, 25, 24.9, 25.5, 26.7]
    /// The frames on which the mallet meets the chisel.
    static let strikes: Set<Int> = [5, 11]
    /// The mallet's direction in the picture through the cycle: lifted by the
    /// wrist, brought down, and checked as it strikes.
    static let malletDegrees: [Double] = [102, 106, 109, 111, 106, 98, 101, 104, 107, 108, 104, 98]
    /// How far the mallet hand rises above its striking place.
    static let malletRise: [Double] = [0.8, 1.6, 2.2, 2.6, 1.4, 0, 0.6, 1.3, 1.8, 2.1, 1.1, 0]

    /// The chisel in the picture: its butt, its direction, and its length.
    static let chiselButt = P(30, -36)
    static let chiselDegrees = 20.0
    static let chiselLength = 12.0
    /// The mallet's handle at work, long enough to reach the chisel from the far hand.
    static let malletHaft = 14.0
    /// Its head, smaller than the one he carries, so that it clears his face as it rises.
    static let malletHead = 0.78
    /// Where the front hand grips the chisel: on its handle, below the butt.
    static var chiselGrip: P { chiselButt + P.direction(chiselDegrees) * 3 }
    /// The point that bites the oak, where the block's top lies.
    static var chiselTip: P { AlchemyPeopleProps.chiselTip(butt: chiselButt, degrees: chiselDegrees, length: chiselLength) }
    /// The bench's top above the ground, and its ends.
    static let benchTop = 18.0, benchLeft = 24.0, benchRight = 52.0

    /// Where the back hand holds the mallet in a frame, in the picture: so that
    /// the mallet's face, at its direction, meets the chisel's butt on the strike.
    static func malletHand(_ frame: Int) -> P {
        let strike = chiselButt - AlchemyPeopleProps.malletFace(at: P(0, 0), degrees: malletDegrees[5], haft: malletHaft, head: malletHead)
        return strike + P(-malletRise[frame] * 0.4, -malletRise[frame])
    }

    func carving(_ frame: Int) -> Rig {
        var r = Rig()
        r.backLeg = Limb(-12, 5); r.frontLeg = Limb(14, 8)
        r.lean = Self.carvingLean[frame]
        r.frontArm = AlchemyPeopleKit.reach(front: true, r, to: Self.chiselGrip)
        r.backArm = AlchemyPeopleKit.reach(front: false, r, to: Self.malletHand(frame), elbowUp: true)
        r.eyes = .down
        r.mouth = Self.strikes.contains(frame) ? .firm : .smile
        r.headTilt = -8
        return r
    }

    // MARK: Fighting

    func swing(_ frame: Int) -> Rig {
        let (angle, landing) = Moves.blow(frame, ready: 70, raised: 176, struck: 52)
        var r = Rig()
        r.frontArm = Limb(angle, -12)
        r.backArm = Limb(36 - (angle - 70) * 0.3, 26)
        r.backLeg = Limb(-16, 6)
        r.frontLeg = frame >= 6 && frame <= 9 ? Limb(22, 14) : Limb(13, 8)
        r.lean = frame < 6 ? -4 : (frame <= 9 ? 10 : 3)
        r.mouth = frame >= 6 && frame <= 8 ? .shout : .firm
        r.eyes = landing ? .wide : .open
        return r
    }

    /// Where the tote stands while he works or fights: on the ground behind him.
    static let toteDown = P(-24, -10.6)

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        if pose == .working || pose == .fighting {
            d.svg.ellipse(Self.toteDown + P(0.4, 10.8), 9, 2, fill: .colour("#000000"), opacity: 0.13)
            AlchemyPeopleProps.tote(&d.svg, handle: Self.toteDown, swing: 0)
        }
        if pose == .working {
            AlchemyPeopleProps.bench(&d.svg, left: Self.benchLeft, right: Self.benchRight, top: Self.benchTop)
            AlchemyPeopleProps.block(&d.svg, left: Self.benchLeft + 4, right: Self.benchRight - 3, top: Self.benchTop,
                                     height: -Self.chiselTip.y - Self.benchTop)
        }
        d.figure { d in
            let carving = pose == .working
            if !carving { d.arm(front: false) }
            d.legs()
            Self.smock(&d, sway: sway)
            if carving {
                // The far arm reaches across him to the mallet.
                let hand = d.joints.backHand
                let degrees = AlchemyPeopleKit.bodyDegrees(Self.malletDegrees[frame], d.rig)
                d.arm(front: false)
                AlchemyPeopleProps.mallet(&d.svg, at: hand, degrees: degrees, haft: Self.malletHaft, head: Self.malletHead)
                let butt = AlchemyPeopleKit.body(Self.chiselButt, d.rig)
                AlchemyPeopleProps.chisel(&d.svg, butt: butt, degrees: AlchemyPeopleKit.bodyDegrees(Self.chiselDegrees, d.rig),
                                          length: Self.chiselLength)
                let tip = AlchemyPeopleKit.body(Self.chiselTip, d.rig)
                if Self.strikes.contains(frame) {
                    AlchemyPeopleProps.shavings(&d.svg, at: tip + P(1, -1), spread: 0)
                    d.burst(at: butt + P(0, -1.6), from: 120, to: 240, size: 0.7)
                } else if Self.strikes.contains((frame + 11) % 12) {
                    AlchemyPeopleProps.shavings(&d.svg, at: tip + P(1, -1), spread: 1)
                }
            }
            switch pose {
            case .standing, .walking:
                let hand = d.joints.frontHand
                let swing = pose == .walking ? 7 * BronzePeopleKit.wave(frame, 0.62) : 1.2 * BronzePeopleKit.wave(frame, 0.2)
                AlchemyPeopleProps.tote(&d.svg, handle: hand, swing: swing - d.rig.lean)
            case .fighting:
                let hand = d.joints.frontHand
                let degrees = d.rig.frontArm.upper - 4
                AlchemyPeopleProps.mallet(&d.svg, at: hand, degrees: degrees, haft: 12)
                if frame == 7 { d.swish(around: d.joints.frontShoulder, radius: 26, from: 165, to: 75) }
                if frame == 8 { d.impact(at: AlchemyPeopleProps.malletFace(at: hand, degrees: degrees, haft: 12), size: 0.9) }
            default:
                break
            }
            d.arm(front: true)
            d.head(nose: .hook, hair: { d in
                // Brown hair at the nape, and a sideburn down the cheek.
                d.svg.path("M-11.2,-61.4 C-12.8,-56.6 -11.6,-52 -7.8,-50.4 C-8.6,-52.4 -8.2,-54.2 -7.2,-55.6 C-8.8,-56.6 -8.8,-58.8 -7.6,-60.6 Z",
                           fill: .colour(AlchemyPeopleInk.brownHair))
                d.svg.path("M-7.4,-62.4 C-6.4,-60 -6.2,-57.4 -6.8,-54.6 C-5.4,-55.6 -4.6,-58 -4.8,-61 Z",
                           fill: .colour(AlchemyPeopleInk.brownHair))
                // A carpenter's pencil tucked behind his ear, its point forward.
                d.svg.line([P(-14.6, -55.6), P(-7.6, -63.4)], stroke: .colour(Ink.line), width: 2.4)
                d.svg.line([P(-14.3, -55.9), P(-8.4, -62.5)], stroke: .colour(AlchemyPeopleInk.paleGilt), width: 1.1)
            }, brow: { d in
                d.svg.path("M1.6,-63.4 q3.2,-1.8 6.8,-0.4", stroke: .colour(AlchemyPeopleInk.brownHair), width: 1.9)
            }, over: { d in
                Self.cap(&d)
            })
        }
    }

    /// The smock, the sash, and the half apron over it.
    static func smock(_ d: inout Drawing, sway: Double) {
        let hemBack = P(-15.4 - sway * 1.2, -13), hemFront = P(14 - sway * 1.2, -13)
        d.garment(colour: [P(-10.4, -46.4), P(9.4, -48), hemFront + P(1.4, 1.6), hemBack + P(-1, 1.4)],
                  outline: [P(-8.6, -47), P(8.6, -47), hemFront, hemBack], fill: .colour(AlchemyPeopleInk.light)) { d in
            // A shade down the back, where the linen folds.
            d.svg.polygon([P(-11.6, -40), P(-8, -40), P(-9.6, -14), hemBack + P(0.6, -0.4)].map(d.up),
                          fill: .colour(AlchemyPeopleInk.shadeLight))
            // The smocking: rows of teal stitches gathering the chest.
            var stitching = PathData()
            for (row, y) in [-43.6, -41.4, -39.2].enumerated() {
                var x = -7.6 + (row % 2 == 0 ? 0 : 1)
                var up = true
                stitching.move(d.up(P(x, y)))
                while x + 2 <= 8 {
                    x += 2; up.toggle()
                    stitching.line(d.up(P(x, y + (up ? 0 : 1.1))))
                }
            }
            d.svg.path(stitching, stroke: .colour(AlchemyPeopleInk.teal), width: 0.8)
            // The neck's opening and its tie.
            d.svg.path("M4.6,\(num(-47 - d.rig.lift)) l0.8,4.4", stroke: .colour(Ink.line), width: 0.8)
            // The sash, in the team's colour, edged in the smock's own linen.
            d.band([P(-13, -32.6), P(12.6, -33.4), P(13.2, -27.4), P(-13.6, -26.6)])
            d.svg.line([d.up(P(-13, -32.6)), d.up(P(12.6, -33.4))], stroke: .colour(Ink.line), width: 0.9)
            d.svg.line([P(-13.6, -26.6), P(13.2, -27.4)], stroke: .colour(Ink.line), width: 0.9)
        }
        // The half apron of teal canvas, from the sash to the knee, its pocket holding a chisel.
        let apronHem = (P(-2.6 - sway * 1.2, -6.4), P(16.4 - sway * 1.4, -7.4))
        let apron = [P(-3.4, -27.4), P(13.2, -27.6), apronHem.1, apronHem.0]
        d.svg.polygon(apron.map { $0 + P(-0.7, 0.6) }, fill: .colour(AlchemyPeopleInk.teal))
        d.svg.line([P(-2.2, -25.4), apronHem.0 + P(1, -1.2)], stroke: .colour(AlchemyPeopleInk.darkTeal), width: 0.9)
        d.svg.line([P(5.6, -26.6), (apronHem.0 + apronHem.1) * 0.5 + P(0, -1.4)], stroke: .colour(AlchemyPeopleInk.darkTeal), width: 0.9)
        // The chisel's handle above the pocket, and the pocket.
        d.svg.line([P(11.2, -25.6), P(10.6, -20.4)], stroke: .colour(Ink.line), width: 2.6)
        d.svg.line([P(11.2, -25.6), P(10.6, -20.4)], stroke: .colour(AlchemyPeopleInk.paleGilt), width: 1.3)
        BronzePeopleProps.shape(&d.svg, [P(6.6, -22), P(14, -22.4), P(14.6, -15.6), P(7.2, -15.2)], fill: .colour(AlchemyPeopleInk.darkTeal),
                                width: 0.9)
        var stitch = PathData()
        for i in 0..<5 { let x = 7.6 + Double(i) * 1.5; stitch.move(P(x, -21.2)); stitch.line(P(x + 0.7, -21.3)) }
        d.svg.path(stitch, stroke: .colour(AlchemyPeopleInk.paleTeal), width: 0.7)
        d.svg.polygon(apron, fill: .none, stroke: .colour(Ink.line), width: 1.3)
        // The knot of the sash, and its ends falling at the back hip.
        d.svg.ellipse(d.up(P(-11.8, -29.8)), 2, 2.6, fill: .team, stroke: .colour(Ink.line), width: 0.9)
        for (dx, length) in [(0.0, 8.6), (2.0, 6.8)] {
            let top = P(-12.6 + dx * 0.4, -28)
            let end = top + P(-1.8 - sway * 2 + dx * 0.4, length)
            d.svg.polygon([top + P(-1.1, 0), top + P(1.1, 0), end + P(0.9, 0), end + P(-0.9, 0)], fill: .team,
                          stroke: .colour(Ink.line), width: 0.9)
        }
    }

    /// A soft cap of wine-coloured wool, its crown slouched toward the back, on a rolled band.
    static func cap(_ d: inout Drawing) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyPeopleInk.wine), width: 1.5) { o in
            var p = PathData()
            p.move(P(-11.4, -62) + o)
            p.cubic(P(-17.4, -66) + o, P(-14, -76.4) + o, P(-3, -76) + o)
            p.cubic(P(5.6, -75.6) + o, P(10.8, -71) + o, P(10.4, -65.6) + o)
            p.cubic(P(3, -67.6) + o, P(-5, -66.4) + o, P(-11.4, -62) + o)
            p.close()
            return p
        }
        // The folds of the slouch.
        d.svg.path("M-12.6,-66.6 q3.4,-1.6 6.4,-0.4 M-6,-73.4 q3,1.4 4.2,4", stroke: .colour(AlchemyPeopleInk.darkWine), width: 1)
        // The rolled band.
        d.svg.path("M10.4,-65.2 C3,-67.8 -5,-66.6 -11.6,-62.2", stroke: .colour(Ink.line), width: 3.6)
        d.svg.path("M10.4,-65.2 C3,-67.8 -5,-66.6 -11.6,-62.2", stroke: .colour(AlchemyPeopleInk.paleWine), width: 2)
    }
}

// MARK: - The craftsman in the other views

extension AlchemyPeopleCraftsman {
    /// The smock's outline in profile, on which what he wears over it is placed.
    static func smockShape(sway: Double) -> [P] {
        [P(-8.6, -47), P(8.6, -47), P(14 - sway * 1.2, -13), P(-15.4 - sway * 1.2, -13)]
    }

    /// The chisel at work in this view, held in the near hand: its butt and
    /// direction in the body, its length as the view shows it, and its point in the picture.
    static func chiselInView(_ d: Drawing) -> (butt: P, degrees: Double, length: Double, tip: P) {
        let turned = AlchemyViews.along(d.view, chiselDegrees)
        let degrees = turned.degrees + AlchemyViews.lean(d)
        let length = chiselLength * max(turned.length, 0.4)
        let u = P.direction(degrees)
        let butt = d.hand(front: true) - u * (3 * length / chiselLength)
        return (butt, degrees, length, AlchemyViews.world(d, butt + u * length))
    }

    /// A frame of a pose seen from a view other than the side: the bench and
    /// the tote stand where the view puts them, the tools turn in his own
    /// plane, and the smock, the apron and the cap go round him.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let (c, s) = AlchemyViews.turn(view)
        let sway = d.rig.sway
        // The tote set down behind him, a little to his left.
        let toteZ = -5.0
        let toteAt = P(Self.toteDown.x * c - toteZ * s, Self.toteDown.y)
        let toteDepth = Self.toteDown.x * s + toteZ * c
        func tote(_ svg: inout SVG) {
            svg.ellipse(toteAt + P(0.4, 10.8), 9 * max(abs(c), 0.6), 2, fill: .colour("#000000"), opacity: 0.13)
            AlchemyViews.squeezed(&svg, about: toteAt, by: max(abs(c), 0.55)) { svg in
                AlchemyPeopleProps.tote(&svg, handle: toteAt, swing: 0)
            }
        }
        // The bench before him, placed so that the block's top meets the chisel's point as it strikes.
        let strike = Drawing(layer: d.svg.layer, rig: carving(5), phase: 0, view: view)
        let tip = Self.chiselInView(strike).tip
        let benchZ = (Self.chiselTip.x * c - tip.x) / s
        let benchDepth = (Self.benchLeft + Self.benchRight) / 2 * s + benchZ * c
        let blockHeight = max(-tip.y - Self.benchTop, 4)
        func bench(_ svg: inout SVG) {
            let top = Self.benchTop, left = Self.benchLeft, right = Self.benchRight
            AlchemyViews.solid(&svg, view, from: left, to: right, z: benchZ, half: 6, side: { svg in
                AlchemyPeopleProps.bench(&svg, left: left, right: right, top: top)
                AlchemyPeopleProps.block(&svg, left: left + 4, right: right - 3, top: top, height: blockHeight)
            }, end: { svg, x, half in
                // The trestle end-on: the legs splayed across, the top's end grain, and the block's end on it.
                svg.ellipse(P(x, 0.4), half + 3, 2.2, fill: .colour("#000000"), opacity: 0.13)
                for side in [-1.0, 1.0] {
                    BronzePeopleProps.shape(&svg, [P(x + side * (half - 2.6), -top + 3.6), P(x + side * (half - 0.2), -top + 3.6),
                                                   P(x + side * (half + 1.4), 0), P(x + side * (half - 1.4), 0)],
                                            fill: .colour(AlchemyPeopleInk.wood), width: 1.1)
                }
                svg.line([P(x - half + 1.6, -top * 0.36), P(x + half - 1.6, -top * 0.36)], stroke: .colour(Ink.line), width: 2.4)
                svg.line([P(x - half + 1.6, -top * 0.36), P(x + half - 1.6, -top * 0.36)], stroke: .colour(AlchemyPeopleInk.darkWood), width: 1)
                BronzePeopleProps.shape(&svg, [P(x - half - 0.6, -top), P(x + half + 0.6, -top), P(x + half + 0.6, -top + 3.6),
                                               P(x - half - 0.6, -top + 3.6)], fill: .colour(AlchemyPeopleInk.paleWood), width: 1.2)
                svg.path("M\(num(x - half + 1)),\(num(-top + 1.8)) q\(num(half)),-1.2 \(num(half * 2 - 2)),0", stroke: .colour(AlchemyPeopleInk.wood), width: 0.6)
                let w = half * 0.72
                BronzePeopleProps.shape(&svg, [P(x - w, -top), P(x + w, -top), P(x + w, -top - blockHeight + 1), P(x + w - 1.6, -top - blockHeight),
                                               P(x - w, -top - blockHeight)], fill: .colour(AlchemyPeopleInk.timberOak), width: 1.2)
                svg.circle(P(x - w * 0.2, -top - blockHeight * 0.5), blockHeight * 0.28, fill: .none, stroke: .colour(AlchemyPeopleInk.wood), width: 0.6)
                svg.circle(P(x - w * 0.2, -top - blockHeight * 0.5), blockHeight * 0.12, fill: .none, stroke: .colour(AlchemyPeopleInk.wood), width: 0.6)
            })
        }
        let grounded = pose == .working || pose == .fighting
        if grounded && toteDepth < 0 { tote(&d.svg) }
        if pose == .working && benchDepth < 0 { bench(&d.svg) }

        d.figure { d in
            // What each hand holds, drawn with its arm: behind the body or before it.
            func held(_ d: inout Drawing, right: Bool) {
                let hand = d.hand(front: right)
                switch (pose, right) {
                case (.working, true):
                    let chisel = Self.chiselInView(d)
                    AlchemyPeopleProps.chisel(&d.svg, butt: chisel.butt, degrees: chisel.degrees, length: chisel.length)
                case (.working, false):
                    // The mallet sent from the far hand to the chisel's butt, lifted between blows.
                    let butt = Self.chiselInView(d).butt
                    let reach = max(BronzePeopleKit.length(butt - hand), 9)
                    let face = 5.8 * Self.malletHead
                    let haft = min(max((reach * reach - face * face).squareRoot(), 8), 18)
                    let aim = BronzePeopleKit.degrees(from: hand, to: butt)
                    let lift = Self.malletRise[frame] * 6 * (aim >= 0 ? 1 : -1)
                    let degrees = aim + atan2(face, haft) * 180 / .pi + lift
                    AlchemyPeopleProps.mallet(&d.svg, at: hand, degrees: degrees, haft: haft, head: Self.malletHead)
                case (.fighting, true):
                    let degrees = d.onScreen(d.rig.frontArm.upper - 4)
                    AlchemyPeopleProps.mallet(&d.svg, at: hand, degrees: degrees, haft: 12)
                    if frame == 8 { d.impact(at: AlchemyPeopleProps.malletFace(at: hand, degrees: degrees, haft: 12), size: 0.9) }
                case (.standing, true), (.walking, true):
                    let swing = pose == .walking ? 7 * BronzePeopleKit.wave(frame, 0.62) : 1.2 * BronzePeopleKit.wave(frame, 0.2)
                    let turn = swing - AlchemyViews.lean(d)
                    AlchemyViews.squeezed(&d.svg, about: hand, by: max(abs(c), 0.55)) { svg in
                        AlchemyPeopleProps.tote(&svg, handle: hand, swing: turn)
                    }
                default:
                    break
                }
            }
            d.arm(front: false)
            for right in [false, true] where d.armBehind(front: right) { held(&d, right: right) }
            d.legs()
            Self.smockInView(&d, sway: sway)
            for right in [false, true] where !d.armBehind(front: right) { held(&d, right: right) }
            if pose == .working {
                let chisel = Self.chiselInView(d)
                let point = chisel.butt + P.direction(chisel.degrees) * chisel.length
                if Self.strikes.contains(frame) {
                    AlchemyPeopleProps.shavings(&d.svg, at: point + P(1, -1), spread: 0)
                } else if Self.strikes.contains((frame + 11) % 12) {
                    AlchemyPeopleProps.shavings(&d.svg, at: point + P(1, -1), spread: 1)
                }
            }
            d.arm(front: true)
            d.head(nose: .hook, hair: { d in Self.hairInView(&d) }, brow: { d in
                d.svg.path("M1.6,-63.4 q3.2,-1.8 6.8,-0.4", stroke: .colour(AlchemyPeopleInk.brownHair), width: 1.9)
            }, over: { d in
                Self.capInView(&d)
            })
        }
        if grounded && toteDepth >= 0 { tote(&d.svg) }
        if pose == .working && benchDepth >= 0 { bench(&d.svg) }
    }

    /// The smock, the sash and the half apron, turned with the view.
    static func smockInView(_ d: inout Drawing, sway: Double) {
        let view = d.view
        let hemBack = P(-15.4 - sway * 1.2, -13), hemFront = P(14 - sway * 1.2, -13)
        let shape = smockShape(sway: sway)
        let line = Paint.colour(Ink.line)
        d.garment(colour: [P(-10.4, -46.4), P(9.4, -48), hemFront + P(1.4, 1.6), hemBack + P(-1, 1.4)],
                  outline: shape, fill: .colour(AlchemyPeopleInk.light)) { d in
            // The smocking: rows of teal stitches gathering the chest, from one side to the other.
            var stitching = PathData()
            for (row, y) in [-43.6, -41.4, -39.2].enumerated() {
                var points: [P] = []
                for side in [1.0, -1.0] {
                    for i in 0...4 {
                        let x = side > 0 ? -1 + Double(i) * 2.2 : 7.8 - Double(i) * 2.2
                        let up = (i + row) % 2 == 0
                        let (q, depth) = AlchemyViews.surface(view, P(x, y + (up ? 0 : 1.1)), on: shape, side: side)
                        if depth > 0 { points.append(d.up(q)) }
                    }
                }
                guard points.count > 1 else { continue }
                stitching.move(points[0])
                for p in points.dropFirst() { stitching.line(p) }
            }
            d.svg.path(stitching, stroke: .colour(AlchemyPeopleInk.teal), width: 0.8)
            // The neck's opening and its tie.
            if let tie = AlchemyViews.worn(d, [P(7.6, -46.6), P(8.4, -42.4)], on: shape) {
                d.svg.line(tie, stroke: line, width: 0.8)
            }
            // The sash, in the team's colour, edged in the line.
            let sash = [P(-13, -32.6), P(12.6, -33.4), P(13.2, -27.4), P(-13.6, -26.6)]
            d.band(sash)
            d.svg.polygon(d.turned(sash).map(d.up), fill: .none, stroke: line, width: 0.9)
        }
        // The half apron of teal canvas, across his front from the sash to the knee.
        let apron = AlchemyViews.panel(view, back: -3.4, front: 13.6, top: { _ in -27.4 }, bottom: { x in -6.4 - (x + 3.4) / 17 - sway * 0.6 },
                                       on: shape)
        if !apron.isEmpty {
            d.svg.polygon(apron.map { $0 + P(-0.6, 0.6) }, fill: .colour(AlchemyPeopleInk.teal))
            // Its pocket on his right, with the chisel's handle standing out of it.
            if let pocket = AlchemyViews.worn(d, [P(6.6, -22), P(14, -22.4), P(14.6, -15.6), P(7.2, -15.2)], on: shape, margin: 0.5) {
                BronzePeopleProps.shape(&d.svg, pocket, fill: .colour(AlchemyPeopleInk.darkTeal), width: 0.9)
                if let handle = AlchemyViews.worn(d, [P(11.2, -25.8), P(10.6, -21)], on: shape, margin: 0.5) {
                    d.svg.line(handle, stroke: line, width: 2.6)
                    d.svg.line(handle, stroke: .colour(AlchemyPeopleInk.paleGilt), width: 1.3)
                }
            }
            d.svg.polygon(apron, fill: .none, stroke: line, width: 1.3)
        }
        // The knot of the sash at the back of his right hip, and its ends.
        let (knot, depth) = AlchemyViews.surface(view, P(-12.4, -29.8), on: shape)
        if depth > -2 {
            for (dx, length) in [(-0.8, 8.6), (0.8, 6.8)] {
                let top = d.up(knot) + P(dx, 1.6)
                let end = top + P(dx * 0.6 - sway, length)
                d.svg.polygon([top + P(-1.1, 0), top + P(1.1, 0), end + P(0.9, 0), end + P(-0.9, 0)], fill: .team, stroke: line, width: 0.9)
            }
            d.svg.ellipse(d.up(knot), 2, 2.6, fill: .team, stroke: line, width: 0.9)
        }
    }

    /// His brown hair at the nape and his sideburns, as the view shows them,
    /// and the carpenter's pencil behind his right ear.
    static func hairInView(_ d: inout Drawing) {
        let hair = Paint.colour(AlchemyPeopleInk.brownHair), line = Paint.colour(Ink.line)
        func pencil(_ d: inout Drawing, at ear: P, leaning: Double) {
            let u = P.direction(180 + leaning)
            d.svg.line([ear - u * 3.6, ear + u * 4.6], stroke: line, width: 2.4)
            d.svg.line([ear - u * 3.3, ear + u * 4.2], stroke: .colour(AlchemyPeopleInk.paleGilt), width: 1.1)
        }
        switch d.view {
        case .front:
            for side in [-1.0, 1.0] {
                d.svg.path("M\(num(side * 9.6)),-62 C\(num(side * 10.4)),-59 \(num(side * 10)),-56.4 \(num(side * 9)),-54.4 "
                           + "C\(num(side * 8)),-56 \(num(side * 7.6)),-59 \(num(side * 7.8)),-62.2 Z", fill: hair)
            }
            pencil(&d, at: P(-11.6, -60), leaning: 28)
        case .frontQuarter:
            d.svg.path("M-10.6,-61 C-12.4,-56.6 -11.6,-52.4 -8.4,-50.6 C-8.6,-53.4 -8,-56 -6.4,-57.6 C-7.6,-59 -7.2,-60.6 -6.2,-62 Z", fill: hair)
            d.svg.path("M10.2,-62 C10.8,-59.6 10.4,-57 9.6,-55.4 C9,-57 8.8,-59.6 9,-62 Z", fill: hair)
            pencil(&d, at: P(-9.4, -60.6), leaning: 34)
        case .back:
            d.svg.path("M-10.8,-60 C-11.6,-55.6 -10.6,-52 -8,-50.2 C-3,-49 3,-49 8,-50.2 C10.6,-52 11.6,-55.6 10.8,-60 "
                       + "C6,-58.2 -6,-58.2 -10.8,-60 Z", fill: hair)
            pencil(&d, at: P(11.4, -60), leaning: -28)
        case .backQuarter:
            d.svg.path("M-10.8,-59.4 C-11.8,-55 -10.6,-51.6 -7.4,-50 C-2,-49 3,-49.4 6.6,-51 C8.4,-53.4 8.6,-56.6 8,-59.6 "
                       + "C3,-57.8 -5,-57.8 -10.8,-59.4 Z", fill: hair)
            pencil(&d, at: P(9.2, -60.6), leaning: -34)
        case .side:
            break
        }
    }

    /// The slouched cap of wine-coloured wool on its rolled band, as the view shows it.
    static func capInView(_ d: inout Drawing) {
        let view = d.view
        let cap = AlchemyViews.dome(view, radius: 11.6, front: -65.4, back: -62, top: -76.4, crest: -3)
        BronzePeopleProps.shape(&d.svg, cap, fill: .colour(AlchemyPeopleInk.wine), width: 1.5)
        // A fold of the slouch, toward the back.
        let fold = AlchemyViews.onRim(view, radius: 9, front: -70, back: -68.6, phi: .pi * 0.85)
        if fold.depth > 0 {
            d.svg.path("M\(num(fold.point.x - 3)),\(num(fold.point.y)) q3,-1.4 6,-0.2", stroke: .colour(AlchemyPeopleInk.darkWine), width: 1)
        }
        let fold2 = AlchemyViews.onRim(view, radius: 9, front: -70, back: -68.6, phi: -.pi * 0.85)
        if fold2.depth > 0 {
            d.svg.path("M\(num(fold2.point.x - 3)),\(num(fold2.point.y)) q3,-1.4 6,-0.2", stroke: .colour(AlchemyPeopleInk.darkWine), width: 1)
        }
        // The rolled band along the rim.
        var band = PathData()
        let rim = AlchemyViews.rim(view, radius: 11.4, front: -65.2, back: -62.2)
        band.move(rim[0])
        for p in rim.dropFirst() { band.line(p) }
        d.svg.path(band, stroke: .colour(Ink.line), width: 3.6)
        d.svg.path(band, stroke: .colour(AlchemyPeopleInk.paleWine), width: 2)
    }
}
