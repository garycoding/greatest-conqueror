// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The banker (merchant)

/// A portly banker in a long gown of wine, its collar, its short puffed
/// sleeves, its hem and the edges of its opening faced with marten fur, the
/// doublet beneath in the team's colour, showing at the chest and the forearm, a flat bonnet of black velvet with a gilt brooch, brown
/// hair cut level at the neck, a clean-shaven double chin, and a gilt ring on
/// his finger; nose B. He carries his ledger under his arm, a purse at his
/// belt; at work a strongbox stands open at his feet, the ledger open in his
/// far hand, and he counts coin from his palm into it, one coin falling after
/// another, murmuring the count.
struct AlchemyPeopleBanker: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            // The thumb in his belt, the other arm keeping the ledger.
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(10.6, -27.6))
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(-10, -30.4 - r.lift * 0.5))
            r.mouth = .smile
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 17, kneeLift: 32, armSwing: 18)
            r.lean = -1
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(-10, -30.4))
            r.mouth = .smile
            return r
        case .working:
            return counting(frame)
        default:
            return nil
        }
    }

    // MARK: Counting

    /// The frames on which a coin leaves his hand, and how many frames it falls.
    static let releases = [1, 7]
    static let fall = 4

    /// The counting hand over the box: it tips a coin off with each release and settles again.
    static func countingHand(_ frame: Int) -> P {
        let tip: [Double] = [0, 1.2, 0.4, 0, 0, -0.4, 0, 1.2, 0.4, 0, 0, -0.4]
        return P(17.6 + tip[frame] * 0.6, -31.4 + tip[frame])
    }

    func counting(_ frame: Int) -> Rig {
        var r = Moves.standing(frame)
        r.lean = 6
        r.frontArm = AlchemyPeopleKit.reach(front: true, r, to: Self.countingHand(frame))
        r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(4.6, -33.4))
        r.headTilt = 9
        r.eyes = frame == 11 ? .closed : .down
        r.mouth = [Mouth.murmur, .open, .murmur, .smile, .murmur, .murmur, .murmur, .open, .murmur, .smile, .murmur, .smile][frame]
        return r
    }

    /// The strongbox at his feet: its left edge, width and height.
    static let boxLeft = 12.6, boxWidth = 17.0, boxHeight = 9.0

    /// Where a falling coin is in a frame, and how it is turned; nil when no coin is in the air.
    static func fallingCoin(_ frame: Int) -> (at: P, face: Double)? {
        for release in releases {
            let k = (frame - release + 12) % 12
            guard k < fall else { continue }
            let start = countingHand(release) + P(1.4, 2.4)
            let end = P(boxLeft + boxWidth * 0.5 + 1, -boxHeight - 3.6)
            let t = Double(k + 1) / Double(fall)
            return (P(mix(start.x, end.x, t), mix(start.y, end.y, t * t)), cos(Double(k) * 1.3))
        }
        return nil
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        if pose == .working {
            AlchemyPeopleProps.strongbox(&d.svg, left: Self.boxLeft, width: Self.boxWidth, height: Self.boxHeight)
            if let coin = Self.fallingCoin(frame) {
                AlchemyPeopleProps.coin(&d.svg, at: coin.at, face: coin.face, radius: 2)
            }
            // The chink as a coin lands in the heap.
            if Self.releases.contains((frame - Self.fall + 12) % 12) {
                let heap = P(Self.boxLeft + Self.boxWidth * 0.5 + 1, -Self.boxHeight - 5)
                d.svg.path("M\(num(heap.x - 4)),\(num(heap.y - 1)) l-1.6,-1.6 M\(num(heap.x)),\(num(heap.y - 2.6)) l0,-2.2 "
                           + "M\(num(heap.x + 4)),\(num(heap.y - 1)) l1.6,-1.6", stroke: .colour(Ink.line), width: 1)
            }
        }
        d.figure { d in
            d.arm(front: false)
            d.legs()
            Self.gown(&d, sway: sway, pose: pose, frame: frame)
            // The ledger: under his arm, or open in his far hand while he counts.
            if pose == .working {
                AlchemyPeopleProps.ledger(&d.svg, at: d.joints.backHand + P(1.4, -0.6), degrees: -14, ribbon: 0.3 * BronzePeopleKit.wave(frame))
                d.hand(d.joints.backHand)
            } else {
                AlchemyPeopleProps.book(&d.svg, at: d.up(P(-12.8, -34.6)), degrees: 10, cover: AlchemyPeopleInk.darkWine, width: 8.4, height: 12.4)
                d.hand(d.joints.backHand)
            }
            Self.sleeve(&d)
            let hand = d.joints.frontHand
            if pose == .working {
                // The coins still to be counted, in a short stack on his palm.
                let left = 3 - [0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2][frame]
                for i in 0..<max(left, 1) {
                    AlchemyPeopleProps.coin(&d.svg, at: hand + P(1.6, -1.2 - Double(i) * 1.1), face: 0.35, radius: 2)
                }
            }
            d.hand(hand)
            // The gilt ring.
            d.svg.circle(hand + P(0.8, 0.6), 0.7, fill: .colour(AlchemyPeopleInk.gilt), stroke: .colour(Ink.line), width: 0.5)
            d.head(nose: .button, behind: { d in
                // His hair, cut level at the neck below the bonnet.
                d.svg.path("M-12,-63 C-13.4,-58 -13,-53.2 -11.6,-50 L-6.4,-50.6 C-7.6,-54 -7.4,-58 -6,-62 Z",
                           fill: .colour(AlchemyPeopleInk.brownHair), stroke: .colour(Ink.line), width: 1)
            }, hair: { d in
                d.svg.path("M-10.8,-63.2 C-11.8,-58.6 -11.2,-54.4 -9.6,-51 L-7.4,-51.6 C-8.6,-55 -8.4,-59 -7.2,-62.6 Z",
                           fill: .colour(AlchemyPeopleInk.brownHair))
            }, features: { d in
                // A double chin, and a dimple of the smile.
                d.svg.path("M-1.6,-48.6 q5,3.6 10.6,0.4", stroke: .colour(Ink.line), width: 1.1)
                d.svg.path("M10.6,-52.6 q0.8,0.4 0.8,1.2", stroke: .colour(Ink.line), width: 0.8)
            }, brow: { d in
                d.svg.path("M2.2,-64 q3,-1.6 6.2,-0.6", stroke: .colour(AlchemyPeopleInk.brownHair), width: 1.5)
            }, over: { d in
                Self.bonnet(&d)
            })
        }
    }

    /// The gown, its fur, the doublet between, the belt and the purse.
    static func gown(_ d: inout Drawing, sway: Double, pose: SpritePose, frame: Int) {
        let hemBack = P(-17.6 - sway * 1.4, -7.4), hemFront = P(17 - sway * 1.4, -7.4)
        func gownPath(_ o: P) -> PathData {
            var p = PathData()
            p.move(d.up(P(-9.6, -47.4)) + o)
            p.line(d.up(P(9.4, -47.4)) + o)
            p.cubic(d.up(P(16.4, -41)) + o, P(20.4, -27) + o, hemFront + o)
            p.line(hemBack + o)
            p.cubic(P(-16.4, -24) + o, d.up(P(-14.6, -40)) + o, d.up(P(-9.6, -47.4)) + o)
            p.close()
            return p
        }
        d.svg.path(gownPath(P(-0.8, 0.8)), fill: .colour(AlchemyPeopleInk.wine))
        // The folds of the gown, falling from the belt.
        var folds = PathData()
        for (top, bottom) in [(P(-9, -24), P(-11.6, -8)), (P(-3, -24), P(-4, -8)), (P(11, -24), P(12.4, -8))] {
            folds.move(top); folds.quad((top + bottom) * 0.5 + P(-1 - sway, 0), bottom + P(-sway, 0))
        }
        d.svg.path(folds, stroke: .colour(AlchemyPeopleInk.darkWine), width: 1.1)
        // The doublet in the team's colour, showing between the fur at the chest; its buttons.
        d.band([P(-2, -46.8), P(10.6, -46.8), P(13.4, -26.6), P(-2, -26.6)])
        var buttons = PathData()
        for i in 0..<4 { let y = -43 + Double(i) * 4.2; buttons.move(d.up(P(4.6, y))); buttons.line(d.up(P(4.8, y + 0.2))) }
        d.svg.path(buttons, stroke: .colour(Ink.line), width: 1.5)
        d.svg.line([d.up(P(3.4, -46.4)), P(3.6, -27)], stroke: .colour(Ink.line), width: 0.8)
        // The fur: down the near edge of the opening to the hem, along the front edge, and the collar over the shoulders.
        Self.fur(&d, [P(-5, -46.4), P(-1.6, -46.4), P(-1.8, -26), P(-1.2, -8), P(-5 - sway * 0.6, -8)].map { $0.y < -20 ? d.up($0) : $0 })
        Self.fur(&d, [P(10.8, -46), P(14, -40.6), P(15.8, -26.4), P(13.2, -26.6)].map(d.up))
        Self.fur(&d, [P(-11.4, -48), P(-1.4, -48.8), P(-1.6, -45), P(-12.8, -43.4)].map(d.up))
        // The fur along the hem.
        Self.fur(&d, [hemBack + P(0.4, -3), hemFront + P(-0.4, -3), hemFront, hemBack])
        d.svg.path(gownPath(P(0, 0)), stroke: .colour(Ink.line), width: 1.8)
        // The belt of black leather across him, and the purse hanging from it.
        d.svg.polygon([P(-15, -28.4), P(16.6, -28.4), P(16.8, -25.4), P(-15.2, -25.4)], fill: .colour(AlchemyPeopleInk.velvet),
                      stroke: .colour(Ink.line), width: 0.9)
        d.svg.path(BronzePeopleProps.rounded(P(8.4, -26.9), width: 3, height: 3.4, radius: 0.6, degrees: 0, shift: P(0, 0)),
                   stroke: .colour(AlchemyPeopleInk.gilt), width: 0.9)
        let purseSwing = pose == .walking ? 8 * BronzePeopleKit.wave(frame, 0.3) : 0
        AlchemyPeopleProps.purse(&d.svg, at: P(-6.4, -25.6), swing: purseSwing)
    }

    /// A strip of marten fur along `points`: brown, its tips picked out in short pale strokes.
    static func fur(_ d: inout Drawing, _ points: [P]) {
        d.svg.polygon(points.map { $0 + P(-0.5, 0.5) }, fill: .colour(AlchemyPeopleInk.fur))
        var tips = PathData()
        for (a, b) in zip(points, points.dropFirst() + [points[0]]) {
            let along = b - a
            let length = BronzePeopleKit.length(along)
            guard length > 2 else { continue }
            var s = 1.2
            while s < length - 0.8 {
                let c = a + along * (s / length)
                tips.move(c); tips.line(c + P(0.5, 1.2))
                s += 2.6
            }
        }
        d.svg.path(tips, stroke: .colour(AlchemyPeopleInk.paleFur), width: 0.8)
        d.svg.polygon(points, fill: .none, stroke: .colour(Ink.line), width: 1)
    }

    /// The front arm's sleeves: the gown's short sleeve puffed with fur on
    /// the upper arm, and the doublet's sleeve below it in the team's colour,
    /// ending in a linen cuff.
    static func sleeve(_ d: inout Drawing) {
        let shoulder = d.joints.frontShoulder, elbow = d.joints.frontElbow, hand = d.joints.frontHand
        let along = hand - elbow
        let length = max(BronzePeopleKit.length(along), 0.01)
        let u = along * (1 / length), a = P(-u.y, u.x)
        let wrist = elbow + u * (length - 1.8)
        // The doublet's sleeve, close on the forearm.
        let forearm = [elbow + a * 2.2 - u * 1, elbow - a * 2.2 - u * 1, wrist - a * 1.8, wrist + a * 1.8]
        d.svg.polygon(forearm, fill: .team, stroke: .colour(Ink.line), width: 1.1)
        // The linen cuff.
        d.svg.polygon([wrist + a * 2.2, wrist - a * 2.2, wrist - a * 2 + u * 1.4, wrist + a * 2 + u * 1.4], fill: .colour(AlchemyPeopleInk.light),
                      stroke: .colour(Ink.line), width: 0.8)
        // The puffed upper sleeve of fur.
        let upper = elbow - shoulder
        let ul = max(BronzePeopleKit.length(upper), 0.01)
        let uu = upper * (1 / ul), ua = P(-uu.y, uu.x)
        let middle = shoulder + uu * (ul * 0.5)
        var puff: [P] = []
        for i in 0...10 {
            let t = Double(i) / 10 * .pi
            puff.append(middle + uu * (-cos(t) * (ul * 0.5 + 1.2)) + ua * (sin(t) * 4.2))
        }
        for i in 0...10 {
            let t = Double(i) / 10 * .pi
            puff.append(middle + uu * (cos(t) * (ul * 0.5 + 1.2)) - ua * (sin(t) * 3.8))
        }
        Self.fur(&d, puff)
        d.svg.line([middle - ua * 3.4, middle + ua * 3.8], stroke: .colour(AlchemyPeopleInk.darkFur), width: 0.9)
    }

    /// A flat bonnet of black velvet, its broad brim turned up at the side, a gilt brooch on it.
    static func bonnet(_ d: inout Drawing) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyPeopleInk.velvet), width: 1.5) { o in
            var p = PathData()
            p.move(P(-9.6, -65.6) + o)
            p.cubic(P(-10, -72) + o, P(8.6, -73.6) + o, P(9.4, -66.6) + o)
            p.close()
            return p
        }
        BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyPeopleInk.velvet), width: 1.5) { o in
            var p = PathData()
            p.move(P(-15.4, -63.6) + o)
            p.cubic(P(-12, -68.6) + o, P(10, -70.6) + o, P(16.4, -66.4) + o)
            p.cubic(P(15.4, -63.8) + o, P(10, -64.2) + o, P(1, -64.4) + o)
            p.cubic(P(-7, -64.2) + o, P(-12, -62) + o, P(-15.4, -63.6) + o)
            p.close()
            return p
        }
        // The velvet's sheen, and the brooch.
        d.svg.path("M-11,-65.8 q8,-3.4 22,-1.2", stroke: .colour(AlchemyPeopleInk.velvetSheen), width: 0.9)
        d.svg.path("M-4,-71 q4,-1.4 8,-0.4", stroke: .colour(AlchemyPeopleInk.velvetSheen), width: 0.8)
        d.svg.circle(P(-8.6, -67.4), 1.6, fill: .colour(AlchemyPeopleInk.gilt), stroke: .colour(Ink.line), width: 0.8)
        d.svg.circle(P(-8.6, -67.4), 0.5, fill: .colour(AlchemyPeopleInk.paleGilt))
    }
}

// MARK: - The banker in the other views

extension AlchemyPeopleBanker {
    /// The gown's outline in profile, its curves taken as straight steps.
    static func gownShape(sway: Double) -> [P] {
        let hemBack = P(-17.6 - sway * 1.4, -7.4), hemFront = P(17 - sway * 1.4, -7.4)
        return [P(-9.6, -47.4), P(9.4, -47.4)] + AlchemyViews.cubic(P(9.4, -47.4), P(16.4, -41), P(20.4, -27), hemFront)
            + [hemBack] + AlchemyViews.cubic(hemBack, P(-16.4, -24), P(-14.6, -40), P(-9.6, -47.4)).dropLast()
    }

    /// A frame of a pose seen from a view other than the side: the gown, its
    /// fur and the doublet go round him, the strongbox stands where the view
    /// puts it under his counting hand, and his bonnet and hair turn with his head.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let (c, s) = AlchemyViews.turn(view)
        let sway = d.rig.sway
        // The strongbox, placed under where his counting hand is as the cycle begins.
        let still = Drawing(layer: d.svg.layer, rig: counting(0), phase: 0, view: view)
        let palm = AlchemyViews.world(still, still.hand(front: true))
        let boxMiddle = Self.boxLeft + Self.boxWidth / 2
        let boxZ = (boxMiddle * c - palm.x) / s
        let boxAt = P(boxMiddle * c - boxZ * s, -Self.boxHeight - 4)
        let boxDepth = boxMiddle * s + boxZ * c
        func box(_ svg: inout SVG) {
            let h = Self.boxHeight
            AlchemyViews.solid(&svg, view, from: Self.boxLeft, to: Self.boxLeft + Self.boxWidth, z: boxZ, half: 5, side: { svg in
                AlchemyPeopleProps.strongbox(&svg, left: Self.boxLeft, width: Self.boxWidth, height: h)
            }, end: { svg, x, half in
                let ink = Paint.colour(Ink.line)
                svg.ellipse(P(x, 0.4), half + 4, 2.4, fill: .colour("#000000"), opacity: 0.13)
                // The lid thrown back behind, the heap of gold, and the end banded in iron.
                BronzePeopleProps.shape(&svg, [P(x - half + 0.6, -h - 2), P(x + half - 0.6, -h - 2), P(x + half - 1.4, -h - 9), P(x - half + 1.4, -h - 9)],
                                        fill: .colour(AlchemyPeopleInk.darkWood), width: 1.2)
                var heap = PathData()
                heap.move(P(x - half + 0.4, -h)); heap.cubic(P(x - half * 0.5, -h - 6), P(x + half * 0.5, -h - 6), P(x + half - 0.4, -h)); heap.close()
                svg.path(heap, fill: .colour(AlchemyPeopleInk.gilt), stroke: ink, width: 0.9)
                svg.ellipse(P(x - 1, -h - 3.4), 1.6, 0.9, fill: .none, stroke: .colour(AlchemyPeopleInk.darkGilt), width: 0.6)
                BronzePeopleProps.shape(&svg, [P(x - half, 0), P(x + half, 0), P(x + half, -h), P(x - half, -h)], fill: .colour(AlchemyPeopleInk.wood), width: 1.3)
                for bx in [x - half + 2.2, x + half - 2.2] {
                    svg.line([P(bx, -0.4), P(bx, -h + 0.4)], stroke: ink, width: 2.6)
                    svg.line([P(bx, -0.4), P(bx, -h + 0.4)], stroke: .colour(AlchemyPeopleInk.iron), width: 1.3)
                }
                svg.polygon([P(x - 1.6, -h + 1), P(x + 1.6, -h + 1), P(x + 1.6, -h + 4.4), P(x - 1.6, -h + 4.4)], fill: .colour(AlchemyPeopleInk.iron),
                            stroke: ink, width: 0.7)
            })
        }
        if pose == .working && boxDepth < 0 { box(&d.svg) }
        d.figure { d in
            func held(_ d: inout Drawing, right: Bool) {
                let hand = d.hand(front: right)
                if right {
                    if pose == .working {
                        let left = 3 - [0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2][frame]
                        for i in 0..<max(left, 1) {
                            AlchemyPeopleProps.coin(&d.svg, at: hand + P(0.6, -1.2 - Double(i) * 1.1), face: 0.35, radius: 2)
                        }
                    }
                } else {
                    let k = max(abs(c), 0.45)
                    if pose == .working {
                        let at = hand + P(0, -1)
                        let ribbon = 0.3 * BronzePeopleKit.wave(frame)
                        AlchemyViews.squeezed(&d.svg, about: at, by: k) { svg in
                            AlchemyPeopleProps.ledger(&svg, at: at, degrees: -14, ribbon: ribbon)
                        }
                    } else {
                        let at = hand + P(0, -2.4)
                        AlchemyViews.squeezed(&d.svg, about: at, by: k) { svg in
                            AlchemyPeopleProps.book(&svg, at: at, degrees: 10, cover: AlchemyPeopleInk.darkWine, width: 8.4, height: 12.4)
                        }
                    }
                }
            }
            func arms(_ d: inout Drawing, behind: Bool) {
                for limb in AlchemyViews.arms(d, behind: behind) {
                    if !limb.right { held(&d, right: false) }
                    Self.sleeveInView(&d, limb)
                    if limb.right { held(&d, right: true) }
                    d.hand(limb.end)
                    if limb.right {
                        d.svg.circle(limb.end + P(0.6, 0.6), 0.7, fill: .colour(AlchemyPeopleInk.gilt), stroke: .colour(Ink.line), width: 0.5)
                    }
                }
            }
            arms(&d, behind: true)
            d.legs()
            Self.gownInView(&d, sway: sway, pose: pose, frame: frame)
            arms(&d, behind: false)
            d.head(nose: .button, hair: { d in Self.hairInView(&d) }, features: { d in
                // A double chin under the smile.
                switch d.view {
                case .front: d.svg.path("M-5.6,-47.6 q5.6,3.2 11.2,0", stroke: .colour(Ink.line), width: 1.1)
                case .frontQuarter: d.svg.path("M-1.4,-47.8 q5.6,3.2 11,-0.4", stroke: .colour(Ink.line), width: 1.1)
                default: break
                }
            }, brow: { d in
                d.svg.path("M2.2,-64 q3,-1.6 6.2,-0.6", stroke: .colour(AlchemyPeopleInk.brownHair), width: 1.5)
            }, over: { d in
                Self.bonnetInView(&d)
            })
        }
        if pose == .working {
            if boxDepth >= 0 { box(&d.svg) }
            // A coin falling from his palm to the heap, and the chink as it lands.
            let palmNow = AlchemyViews.world(d, d.hand(front: true))
            for release in Self.releases {
                let k = (frame - release + 12) % 12
                guard k < Self.fall else { continue }
                let t = Double(k + 1) / Double(Self.fall)
                let start = palmNow + P(0.6, 2.4)
                AlchemyPeopleProps.coin(&d.svg, at: P(mix(start.x, boxAt.x, t), mix(start.y, boxAt.y, t * t)), face: cos(Double(k) * 1.3), radius: 2)
            }
            if Self.releases.contains((frame - Self.fall + 12) % 12) {
                let heap = boxAt + P(0, -1)
                d.svg.path("M\(num(heap.x - 4)),\(num(heap.y - 1)) l-1.6,-1.6 M\(num(heap.x)),\(num(heap.y - 2.6)) l0,-2.2 "
                           + "M\(num(heap.x + 4)),\(num(heap.y - 1)) l1.6,-1.6", stroke: .colour(Ink.line), width: 1)
            }
        }
    }

    /// The gown, the doublet between its fur, the belt and the purse, turned with the view.
    static func gownInView(_ d: inout Drawing, sway: Double, pose: SpritePose, frame: Int) {
        let view = d.view
        let shape = gownShape(sway: sway)
        let line = Paint.colour(Ink.line)
        d.garment(colour: shape.map { $0 + P(-0.8, 0.8) }, outline: shape, fill: .colour(AlchemyPeopleInk.wine)) { d in
            var folds = PathData()
            for side in [1.0, -1.0] {
                for (top, bottom) in [(P(-9, -24), P(-11.6, -8)), (P(-3, -24), P(-4, -8)), (P(11, -24), P(12.4, -8))] {
                    if let fold = AlchemyViews.worn(d, [top, (top + bottom) * 0.5 + P(-1 - sway, 0), bottom + P(-sway, 0)], on: shape, side: side) {
                        folds.move(fold[0]); folds.quad(fold[1], fold[2])
                    }
                }
            }
            d.svg.path(folds, stroke: .colour(AlchemyPeopleInk.darkWine), width: 1.1)
        }
        // The doublet's stand collar of the team's colour round his neck, above the fur.
        let collar = [P(-7.2, -50.6), P(7.2, -50.6), P(7.8, -47.4), P(-7.8, -47.4)]
        d.band(collar)
        d.svg.polygon(d.turned(collar).map(d.up), fill: .none, stroke: line, width: 0.9)
        // The doublet showing between the fur of the opening, with its buttons.
        func at(_ y: Double, _ angle: Double, _ side: Double) -> (P, Double) {
            let (p, depth) = AlchemyViews.around(view, y, angle: angle, on: shape, side: side)
            return (d.up(p), depth)
        }
        let opening: [(Double, Double)] = [(-46.8, 26), (-26.6, 22)]
        var front: [P] = [], visible = true
        for side in [1.0, -1.0] {
            for (y, angle) in side > 0 ? opening : opening.reversed() {
                let (p, depth) = at(y, angle, side)
                visible = visible && depth > 0
                front.append(p)
            }
        }
        if visible {
            d.svg.polygon(front, fill: .team)
            var buttons = PathData()
            for i in 0..<4 {
                let (p, _) = at(-43 + Double(i) * 4.2, 0, 1)
                buttons.move(p); buttons.line(p + P(0.2, 0.2))
            }
            d.svg.path(buttons, stroke: line, width: 1.5)
        }
        // The fur: the collar over the shoulders, down both edges of the opening to the hem, and along the hem.
        fur(&d, d.turned([P(-12, -48.8), P(12.6, -48.8), P(14, -43.4), P(-13.4, -43.4)]).map(d.up))
        for side in [1.0, -1.0] {
            var edge: [P] = [], hidden = false
            for (y, angle) in [(-46.4, 22.0), (-26, 18), (-8, 22), (-8, 40), (-26, 32), (-46.4, 40)] {
                let (p, depth) = at(y, angle, side)
                hidden = hidden || depth < 0.5
                edge.append(p)
            }
            if !hidden { fur(&d, edge) }
        }
        let hemBack = P(-17.6 - sway * 1.4, -7.4), hemFront = P(17 - sway * 1.4, -7.4)
        fur(&d, d.turned([hemBack + P(0.4, -3), hemFront + P(-0.4, -3), hemFront, hemBack]))
        d.svg.polygon(d.turned(shape).map(d.up), fill: .none, stroke: line, width: 1.8)
        // The belt of black leather, its gilt buckle at the front, and the purse at his right hip.
        let belt = [P(-15, -28.4), P(16.6, -28.4), P(16.8, -25.4), P(-15.2, -25.4)]
        d.band(belt, fill: .colour(AlchemyPeopleInk.velvet))
        d.svg.polygon(d.turned(belt), fill: .none, stroke: line, width: 0.9)
        let (buckle, buckleDepth) = at(-26.9, 12, 1)
        if buckleDepth > 0 {
            d.svg.path(BronzePeopleProps.rounded(buckle, width: 3, height: 3.4, radius: 0.6, degrees: 0, shift: P(0, 0)),
                       stroke: .colour(AlchemyPeopleInk.gilt), width: 0.9)
        }
        let (purse, purseDepth) = at(-25.6, 110, 1)
        if purseDepth > -1 {
            let swing = pose == .walking ? 8 * BronzePeopleKit.wave(frame, 0.3) : 0
            AlchemyPeopleProps.purse(&d.svg, at: purse, swing: swing * AlchemyViews.turn(view).c)
        }
    }

    /// An arm in this view: the doublet's sleeve of the team's colour on the
    /// forearm with its linen cuff, and the gown's short sleeve puffed with fur on the upper arm.
    static func sleeveInView(_ d: inout Drawing, _ limb: AlchemyViews.Limb) {
        let shoulder = limb.root, elbow = limb.joint, hand = limb.end
        let along = hand - elbow
        let length = BronzePeopleKit.length(along)
        if length > 2.4 {
            let u = along * (1 / length), a = P(-u.y, u.x)
            let wrist = elbow + u * (length - 1.8)
            d.svg.polygon([elbow + a * 2.2 - u * 1, elbow - a * 2.2 - u * 1, wrist - a * 1.8, wrist + a * 1.8], fill: .team,
                          stroke: .colour(Ink.line), width: 1.1)
            d.svg.polygon([wrist + a * 2.2, wrist - a * 2.2, wrist - a * 2 + u * 1.4, wrist + a * 2 + u * 1.4], fill: .colour(AlchemyPeopleInk.light),
                          stroke: .colour(Ink.line), width: 0.8)
        }
        let upper = elbow - shoulder
        let ul = max(BronzePeopleKit.length(upper), 0.01)
        let uu = upper * (1 / ul), ua = P(-uu.y, uu.x)
        let middle = shoulder + uu * (ul * 0.5)
        var puff: [P] = []
        for i in 0...10 {
            let t = Double(i) / 10 * .pi
            puff.append(middle + uu * (-cos(t) * (ul * 0.5 + 1.2)) + ua * (sin(t) * 4.2))
        }
        for i in 0...10 {
            let t = Double(i) / 10 * .pi
            puff.append(middle + uu * (cos(t) * (ul * 0.5 + 1.2)) - ua * (sin(t) * 3.8))
        }
        fur(&d, puff)
    }

    /// His brown hair, cut level at the neck below the bonnet, as the view shows it.
    static func hairInView(_ d: inout Drawing) {
        let hair = Paint.colour(AlchemyPeopleInk.brownHair), line = Paint.colour(Ink.line)
        switch d.view {
        case .front:
            d.svg.path("M-11.6,-64 C-12.6,-58 -12.4,-53.6 -11.4,-50.4 L-7.6,-50.6 C-8.6,-54 -8.4,-58.6 -7,-63 Z "
                       + "M11.6,-64 C12.6,-58 12.4,-53.6 11.4,-50.4 L7.6,-50.6 C8.6,-54 8.4,-58.6 7,-63 Z", fill: hair, stroke: line, width: 1)
        case .frontQuarter:
            d.svg.path("M-11.8,-64 C-12.8,-58 -12.6,-53.6 -11.4,-50.2 L-4.8,-50.6 C-6.2,-54 -6,-58.4 -4.6,-63 Z", fill: hair, stroke: line, width: 1)
        case .back:
            d.svg.path("M-11.6,-65 C-12.8,-58 -12.4,-53.4 -11.4,-49.8 L11.4,-49.8 C12.4,-53.4 12.8,-58 11.6,-65 Z", fill: hair, stroke: line, width: 1)
        case .backQuarter:
            d.svg.path("M-11.8,-65 C-13,-58 -12.4,-53.4 -11.4,-49.8 L5,-49.8 C6.6,-53.4 6.8,-58 6,-64.4 Z", fill: hair, stroke: line, width: 1)
        case .side:
            break
        }
    }

    /// The flat bonnet of black velvet: its broad brim seen nearly edge on,
    /// turned up at his left, the crown over it, and the gilt brooch where it faces the viewer.
    static func bonnetInView(_ d: inout Drawing) {
        let view = d.view
        let (c, _) = AlchemyViews.turn(view)
        let velvet = Paint.colour(AlchemyPeopleInk.velvet)
        let crown = AlchemyViews.dome(view, radius: 9.8, front: -65.8, back: -65.4, top: -72.6, crest: -0.4)
        BronzePeopleProps.shape(&d.svg, crown, fill: velvet, width: 1.5)
        // The brim: as wide as the view shows it, its far edge a little higher than its near one.
        let half = 15.8, mid = 0.5 * c
        BronzePeopleProps.shape(&d.svg, fill: velvet, width: 1.5) { o in
            var p = PathData()
            p.move(P(mid - half, -63.8) + o)
            p.cubic(P(mid - half + 4, -68.8) + o, P(mid + half - 5, -70) + o, P(mid + half, -65.6) + o)
            p.cubic(P(mid + half - 1, -63.4) + o, P(mid + 6, -64) + o, P(mid, -64.2) + o)
            p.cubic(P(mid - 6, -64) + o, P(mid - half + 3, -62.4) + o, P(mid - half, -63.8) + o)
            p.close()
            return p
        }
        d.svg.path("M\(num(mid - half + 4.4)),-65.8 q\(num(half - 4)),-3.4 \(num(half * 2 - 9)),-1.4", stroke: .colour(AlchemyPeopleInk.velvetSheen), width: 0.9)
        d.svg.path("M\(num(mid - 4)),-71 q4,-1.4 8,-0.4", stroke: .colour(AlchemyPeopleInk.velvetSheen), width: 0.8)
        let brooch = AlchemyViews.onRim(view, radius: 9.6, front: -67.4, back: -67.4, phi: 2.4)
        if brooch.depth > 1 {
            d.svg.circle(brooch.point, 1.6, fill: .colour(AlchemyPeopleInk.gilt), stroke: .colour(Ink.line), width: 0.8)
            d.svg.circle(brooch.point, 0.5, fill: .colour(AlchemyPeopleInk.paleGilt))
        }
    }
}
