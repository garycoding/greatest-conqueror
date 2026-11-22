// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The peaceful sectors in their Industrial-age looks wear the dress of the
// nineteenth century in the age's colours (brick, bottle green and soot on the light),
// each with a nose of its own (docs/art-style.md, "Noses") different from his
// Alchemy, Iron and Bronze stages', and move on the shared skeleton. The
// team's colour is where the earlier ages put it for the same sector, or as
// near to it as the dress allows, and never beside the age's brick or green, so
// that Rome's red, Angkor's orange and the bluer colours stay distinct from
// them: the factory hand's shirt, the scientist's waistcoat (in the opening of
// his coat, where the alchemist wore his stole), the mechanic's cap, and the
// industrialist's waistcoat (at the chest, where the banker's doublet showed).

// MARK: - The factory hand (worker)

/// A factory hand in a collarless shirt of the team's colour with its sleeves
/// rolled to the elbow, braces of black leather, soot-grey trousers, a leather
/// apron from the waist to the knee, a soot-grey neckerchief and a flat cap of
/// bottle-green tweed; brown sideburns and a bushy moustache; nose F. He carries his
/// coal shovel at the trail, leaning on it when he stands; at work he
/// shovels coal: he drives the blade into the heap, lifts the load and pitches
/// it into the skip beyond, the lumps flying; fighting, he swings the shovel.
struct IndustrialPeopleFactoryHand: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            // The near hand on the shovel's grip, the shovel planted before him.
            r.frontArm = IndustrialPeopleKit.reach(front: true, r, to: Self.planted)
            r.mouth = .hidden
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 23, kneeLift: 44, armSwing: 24)
            r.frontArm = IndustrialPeopleKit.reach(front: true, r, to: P(11.4, -30.4 + 0.8 * IndustrialPeopleKit.wave(frame, times: 2)))
            r.mouth = .hidden
            return r
        case .working:
            return shovelling(frame)
        case .fighting:
            let (angle, landing) = Moves.blow(frame, ready: 70, raised: 176, struck: 54)
            var r = Rig()
            r.frontArm = Limb(angle, -10)
            r.backArm = Limb(34 - (angle - 70) * 0.3, 24)
            r.backLeg = Limb(-16, 6)
            r.frontLeg = frame >= 6 && frame <= 9 ? Limb(22, 14) : Limb(13, 8)
            r.lean = frame < 6 ? -4 : (frame <= 9 ? 10 : 3)
            r.mouth = .hidden
            r.eyes = landing ? .wide : .open
            return r
        default:
            return nil
        }
    }

    /// Where the near hand holds the shovel's grip when he stands, in the picture.
    static let planted = P(14.6, -35.6)
    /// The shovel's lean when he stands on it.
    static let plantedDegrees = 5.0
    /// Where along the shaft the near hand holds it when he walks, and the shovel's slope.
    static let trailHold = 13.0, trailDegrees = 56.0

    // MARK: Shovelling

    /// The cycle in the picture: where the far hand holds the grip, where the
    /// near hand holds the shaft, and the lean. He drives the blade in (0 to
    /// 2), levers and lifts (3 to 5), pitches the load forward (6 and 7), and
    /// comes down to the heap again (8 to 11).
    static let grips: [P] = [P(2.8, -31.6), P(4, -30.6), P(3.0, -31.8), P(1, -34), P(-0.4, -36), P(-0.6, -37.6),
                             P(1, -39), P(2.4, -39.6), P(2.6, -37.4), P(2.2, -34.6), P(2.0, -32.8), P(2.4, -31.8)]
    static let holds: [P] = [P(12.2, -23.4), P(13.6, -22.4), P(12.4, -25), P(11.4, -29.6), P(11.2, -33.4), P(12.4, -37.6),
                             P(14.8, -42.6), P(15.8, -45.4), P(14.8, -39.4), P(13.4, -31.6), P(12.6, -26.4), P(12.2, -24)]
    static let leans: [Double] = [24, 25.4, 23.6, 18, 13, 8, 4, 3, 7, 14, 20, 23.4]
    /// The frames on which the load sits on the blade, and the frame on which it leaves it.
    static let loaded: Set<Int> = [2, 3, 4, 5, 6]
    static let release = 7

    func shovelling(_ frame: Int) -> Rig {
        var r = Rig()
        r.backLeg = Limb(-18, 12); r.frontLeg = Limb(30, 42)
        r.lean = Self.leans[frame]
        r.backArm = IndustrialPeopleKit.reach(front: false, r, to: Self.grips[frame])
        r.frontArm = IndustrialPeopleKit.reach(front: true, r, to: Self.holds[frame])
        r.eyes = .down
        r.mouth = .hidden
        r.headTilt = frame == 6 || frame == 7 ? -4 : 2
        return r
    }

    /// The shovel in the picture for a frame of the cycle: its grip and its direction, through both hands.
    static func shovelAt(_ frame: Int) -> (grip: P, degrees: Double) {
        let rig = IndustrialPeopleFactoryHand().shovelling(frame)
        let d = Drawing(layer: .base, rig: rig, phase: 0)
        let back = d.world(d.joints.backHand), front = d.world(d.joints.frontHand)
        return (back, IndustrialPeopleKit.degrees(from: back, to: front))
    }

    /// The edge of the blade where it bites the heap.
    static let bite: P = {
        let s = shovelAt(1)
        return IndustrialPeopleProps.shovelEdge(grip: s.grip, degrees: s.degrees)
    }()

    /// The heap of coal, its peak just beyond the bite.
    static var heapLeft: Double { bite.x - 13 }
    static var heapRight: Double { bite.x + 7.4 }
    static var heapHeight: Double { -bite.y + 1.6 }

    /// The coal skip he pitches the coal into, beyond the heap: its left edge, width and height.
    static var skipLeft: Double { heapRight + 0.8 }
    static let skipWidth = 11.0, skipHeight = 10.0

    /// The lumps of a pitched load in a frame after the release, thrown up
    /// and falling into the skip; nil when none is in the air.
    static func flying(_ frame: Int) -> [(P, Double)]? {
        let k = frame - release
        guard k >= 0, k < 5 else { return nil }
        let s = shovelAt(release)
        let start = IndustrialPeopleProps.shovelEdge(grip: s.grip, degrees: s.degrees) + P(-2, -2)
        let t = Double(k + 1)
        return [(P(3, -3.4), 1.7), (P(2.6, -4), 1.4), (P(3.4, -2.8), 1.2), (P(2.2, -3), 1.5)].map { velocity, size in
            // A lump that has come down lies hidden in the skip.
            (P(start.x + velocity.x * t, min(start.y + velocity.y * t + 3 * t * t, -6)), size)
        }
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        if pose == .working {
            IndustrialPeopleProps.coalHeap(&d.svg, left: Self.heapLeft, right: Self.heapRight, height: Self.heapHeight)
            IndustrialPeopleProps.skipBack(&d.svg, left: Self.skipLeft, width: Self.skipWidth, height: Self.skipHeight)
            if let lumps = Self.flying(frame) {
                for (i, (at, size)) in lumps.enumerated() {
                    IndustrialPeopleProps.coalLump(&d.svg, at: at, size: size, turn: Double(frame * 40 + i * 70))
                }
            }
            IndustrialPeopleProps.skipFront(&d.svg, left: Self.skipLeft, width: Self.skipWidth, height: Self.skipHeight)
            // The dust and the chips flung up as the blade bites.
            if frame == 1 { d.burst(at: Self.bite + P(1, -2), from: 140, to: 220, size: 0.7) }
        }
        d.figure { d in
            let working = pose == .working
            if !working { IndustrialPeopleKit.arm(&d, front: false, fill: .team, width: 4.2, rolled: true) }
            IndustrialPeopleKit.trousers(&d, colour: IndustrialPeopleInk.soot, shade: IndustrialPeopleInk.darkSoot)
            Self.body(&d, sway: sway)
            let hand = d.joints.frontHand
            switch pose {
            case .standing:
                IndustrialPeopleProps.shovel(&d.svg, grip: IndustrialPeopleKit.body(Self.planted, d.rig) + P(0, -0.4),
                                             degrees: Self.plantedDegrees)
            case .walking:
                let degrees = Self.trailDegrees + 3 * IndustrialPeopleKit.wave(frame, 0.2, times: 2)
                IndustrialPeopleProps.shovel(&d.svg, grip: hand - P.direction(degrees) * Self.trailHold, degrees: degrees)
            case .working:
                // The far arm across him to the grip, and the shovel through both hands.
                IndustrialPeopleKit.arm(&d, front: false, fill: .team, width: 4.2, rolled: true)
                let grip = d.joints.backHand
                let degrees = IndustrialPeopleKit.degrees(from: grip, to: hand)
                IndustrialPeopleProps.shovel(&d.svg, grip: grip, degrees: degrees, load: Self.loaded.contains(frame) ? 1 : 0)
                d.hand(grip)
            case .fighting:
                let degrees = d.rig.frontArm.upper - 4
                IndustrialPeopleProps.shovel(&d.svg, grip: hand - P.direction(degrees) * 7, degrees: degrees)
                if frame == 7 { d.swish(around: d.joints.frontShoulder, radius: 30, from: 165, to: 75) }
                if frame == 8 { d.impact(at: IndustrialPeopleProps.shovelEdge(grip: hand - P.direction(degrees) * 7, degrees: degrees), size: 0.9) }
            default:
                break
            }
            IndustrialPeopleKit.arm(&d, front: true, fill: .team, width: 4.4, rolled: true)
            d.head(nose: .bulb, hair: { d in
                // Brown hair at the nape, and a sideburn down the cheek.
                d.svg.path("M-11.2,-61.4 C-12.8,-56.6 -11.6,-52 -7.8,-50.4 C-8.6,-52.4 -8.2,-54.2 -7.2,-55.6 C-8.8,-56.6 -8.8,-58.8 -7.6,-60.6 Z",
                           fill: .colour(IndustrialPeopleInk.brownHair))
                d.svg.path("M-6.6,-63 C-5.8,-59.4 -5.6,-56 -4.4,-52.6 C-3.4,-54.6 -3.2,-58 -3.6,-62.2 Z", fill: .colour(IndustrialPeopleInk.brownHair))
            }, features: { d in
                // Stubble along the jaw.
                var stubble = PathData()
                for (x, y) in [(-1.6, -50.6), (0.6, -49.2), (2.8, -48.4), (5, -48), (7.2, -48.2), (-0.4, -52), (1.8, -50.6), (9.2, -48.8)] {
                    stubble.move(P(x, y)); stubble.line(P(x + 0.3, y + 0.2))
                }
                d.svg.path(stubble, stroke: .colour(IndustrialPeopleInk.brownHair), width: 0.7, opacity: 0.7)
                // A bushy moustache, drooping at its ends.
                d.svg.path("M4.2,-53.8 C6,-55.4 9.4,-55.6 11.6,-53.6 C12.4,-52.4 12,-50.6 11,-49.8 C10.4,-51.4 9,-52 7.6,-51.8 "
                           + "C6,-51.6 5,-50.8 4.2,-49.8 C3.4,-51 3.4,-52.8 4.2,-53.8 Z",
                           fill: .colour(IndustrialPeopleInk.brownHair), stroke: .colour(Ink.line), width: 0.9)
            }, brow: { d in
                d.svg.path("M1.4,-63.4 q3.4,-2 7.2,-0.4", stroke: .colour(IndustrialPeopleInk.brownHair), width: 2)
            }, over: { d in
                Self.cap(&d)
            })
        }
    }

    /// The shirt, the braces and the neckerchief, and the leather apron over the trousers.
    static func body(_ d: inout Drawing, sway: Double) {
        let shirt = [P(-9.4, -47.2), P(9.2, -47.2), P(11.4, -21), P(-11.8, -21)]
        d.svg.polygon(shirt.map { d.up($0) + P(-0.7, 0.6) }, fill: .team)
        // The folds where the shirt is tucked in, and the placket with its buttons.
        d.svg.path("M-8,-24.4 q1.4,-2 2.6,-0.2 M-2.6,-24 q1.2,-2 2.4,0", stroke: .colour(Ink.line), width: 0.7, opacity: 0.55)
        d.svg.line([d.up(P(5.6, -46.6)), d.up(P(6.2, -37))], stroke: .colour(Ink.line), width: 0.8)
        for y in [-44.0, -40.6] { d.svg.circle(d.up(P(6.9, y)), 0.55, fill: .colour(IndustrialPeopleInk.light), stroke: .colour(Ink.line), width: 0.4) }
        d.svg.polygon(shirt.map(d.up), fill: .none, stroke: .colour(Ink.line), width: 1.6)
        // The braces of black leather over the shoulders, buttoned to the trousers at the waist.
        for (top, bottom, width) in [(P(-5, -47.2), P(-5.8, -21.4), 1.9), (P(4, -47.2), P(8.6, -21.4), 2.3)] {
            d.svg.line([d.up(top), bottom], stroke: .colour(Ink.line), width: width + 1.2)
            d.svg.line([d.up(top), bottom], stroke: .colour(IndustrialPeopleInk.darkLeather), width: width)
            d.svg.circle(bottom + P(0, -0.6), 0.6, fill: .colour(IndustrialPeopleInk.paleSoot), stroke: .colour(Ink.line), width: 0.4)
        }
        // The neckerchief, knotted at the throat, its ends falling on the chest.
        d.svg.path("M-2.4,\(num(-47.6 - d.rig.lift)) q5.6,3 11.4,-0.4 l-0.6,2.4 q-5.4,2.4 -10.2,0 Z", fill: .colour(IndustrialPeopleInk.paleSoot),
                   stroke: .colour(Ink.line), width: 0.9)
        d.svg.polygon([P(7.6, -45.8), P(10.2, -46.4), P(10.6, -41.6), P(8.6, -42.4)].map(d.up), fill: .colour(IndustrialPeopleInk.paleSoot),
                      stroke: .colour(Ink.line), width: 0.8)
        d.svg.circle(d.up(P(8.4, -45.2)), 1.2, fill: .colour(IndustrialPeopleInk.soot), stroke: .colour(Ink.line), width: 0.7)
        // The apron of leather from the waist to the knee, its strings round him.
        let hem = (P(-2.4 - sway * 1.2, -7.4), P(16.6 - sway * 1.4, -8))
        let apron = [P(-3.4, -24.8), P(12.8, -24.8), hem.1, hem.0]
        d.svg.polygon(apron.map { $0 + P(-0.7, 0.6) }, fill: .colour(IndustrialPeopleInk.leather))
        d.svg.line([P(1.2, -22.6), hem.0 + P(3, -1.2)], stroke: .colour(IndustrialPeopleInk.darkLeather), width: 0.9)
        d.svg.line([P(8.6, -22.6), (hem.0 + hem.1) * 0.6 + P(0, -1.4)], stroke: .colour(IndustrialPeopleInk.darkLeather), width: 0.9)
        // Scorches and wear on the leather, and its stitched edge.
        d.svg.ellipse(P(10.4, -14.6), 1.6, 1.1, fill: .colour(IndustrialPeopleInk.darkLeather), opacity: 0.7)
        d.svg.ellipse(P(4.4, -11.4), 1.1, 0.8, fill: .colour(IndustrialPeopleInk.darkLeather), opacity: 0.6)
        var stitch = PathData()
        for i in 0..<6 {
            let p = hem.0 + (hem.1 - hem.0) * (Double(i) / 6 + 0.06) + P(0, -1)
            stitch.move(p); stitch.line(p + P(1.1, -0.05))
        }
        d.svg.path(stitch, stroke: .colour(IndustrialPeopleInk.paleLeather), width: 0.6)
        d.svg.polygon(apron, fill: .none, stroke: .colour(Ink.line), width: 1.3)
        d.svg.line([P(-11.6, -24.6), P(12.8, -24.6)], stroke: .colour(Ink.line), width: 1.6)
        d.svg.line([P(-11.6, -24.6), P(12.8, -24.6)], stroke: .colour(IndustrialPeopleInk.paleLeather), width: 0.6)
    }

    /// A flat cap of bottle-green tweed: its crown pulled forward over a short peak, a button on top.
    static func cap(_ d: inout Drawing) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(IndustrialPeopleInk.green), width: 1.5) { o in
            var p = PathData()
            p.move(P(-11.6, -61.8) + o)
            p.cubic(P(-13.4, -67.6) + o, P(-8, -72.4) + o, P(0, -72) + o)
            p.cubic(P(7.6, -71.6) + o, P(13.6, -68.6) + o, P(16.6, -64.6) + o)
            p.cubic(P(13.6, -63.2) + o, P(10, -63.4) + o, P(7.4, -64.2) + o)
            p.cubic(P(1, -65.4) + o, P(-5.6, -64.4) + o, P(-11.6, -61.8) + o)
            p.close()
            return p
        }
        // The peak's shadow under the crown, the tweed's flecks, the seam and the button.
        d.svg.path("M7.6,-64.4 q4.4,-1.4 8.6,-0.2", stroke: .colour(IndustrialPeopleInk.darkGreen), width: 1.1)
        var flecks = PathData()
        for (x, y) in [(-8.0, -66.6), (-4.4, -69.4), (-0.6, -67.2), (3.2, -69.6), (6.6, -67.4), (-6.6, -63.8), (10, -66.4), (0.8, -70.6)] {
            flecks.move(P(x, y)); flecks.line(P(x + 0.7, y - 0.3))
        }
        d.svg.path(flecks, stroke: .colour(IndustrialPeopleInk.paleGreen), width: 0.6)
        d.svg.path("M-1.4,-71.8 q2.6,3.4 7.4,5.6", stroke: .colour(IndustrialPeopleInk.darkGreen), width: 0.8)
        d.svg.ellipse(P(-1.2, -72.2), 1.6, 0.9, fill: .colour(IndustrialPeopleInk.darkGreen), stroke: .colour(Ink.line), width: 0.7)
    }
}

// MARK: - The factory hand in the other views

extension IndustrialPeopleFactoryHand {
    /// The shovel whilst he shovels, in the figure's space for this view: its
    /// grip in the far hand, its direction as a unit vector, and its degrees
    /// and turn about the upright, toward the heap beside him.
    static func shovelInView(_ d: Drawing, _ frame: Int, rig: Rig) -> (grip: IndustrialPoint, direction: IndustrialPoint, degrees: Double, yaw: Double) {
        let grip = IndustrialPeopleKit.body(grips[frame], rig), hold = IndustrialPeopleKit.body(holds[frame], rig)
        let degrees = IndustrialPeopleKit.degrees(from: grip, to: hold)
        let yaw = atan2(IndustrialViews.aside(d), 26) * 180 / .pi
        return (IndustrialPoint(grip.x, grip.y, -3), IndustrialViews.vector(degrees, yaw: yaw), degrees, yaw)
    }

    /// Where the blade's edge is in the picture in a frame of the shovelling, in this view.
    static func edgeInView(_ d: Drawing, _ frame: Int) -> P {
        let rig = IndustrialPeopleFactoryHand().shovelling(frame)
        let at = Drawing(layer: .base, rig: rig, phase: 0, view: d.view)
        let s = shovelInView(at, frame, rig: rig)
        return IndustrialViews.world(at, IndustrialViews.screen(at, s.grip + s.direction * IndustrialPeopleProps.shovelLength))
    }

    /// A frame in a view other than the side: the same dress and the same work,
    /// the heap and the skip standing beside him.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway
        var ground = SVG(layer: d.svg.layer)
        var nearer = false
        if pose == .working {
            // The heap and the skip, moved so that the bite falls under the blade's edge.
            let bite = Self.edgeInView(d, 1)
            let rig1 = shovelling(1)
            let at1 = Drawing(layer: .base, rig: rig1, phase: 0, view: d.view)
            let s1 = Self.shovelInView(at1, 1, rig: rig1)
            nearer = IndustrialViews.depth(at1, s1.grip + s1.direction * IndustrialPeopleProps.shovelLength) > 0
            IndustrialViews.placed(&ground, d, pivot: Self.bite, to: bite) { svg in
                IndustrialPeopleProps.coalHeap(&svg, left: Self.heapLeft, right: Self.heapRight, height: Self.heapHeight)
                IndustrialPeopleProps.skipBack(&svg, left: Self.skipLeft, width: Self.skipWidth, height: Self.skipHeight)
            }
            // The pitched lumps, from the blade's edge at the release to the skip.
            if frame >= Self.release && frame < Self.release + 5 {
                let k = max(abs(cos(d.yaw * .pi / 180)), 0.6)
                let skip = bite + P((Self.skipLeft + Self.skipWidth / 2 - Self.bite.x) * k, -Self.skipHeight - 1 - Self.bite.y)
                let start = Self.edgeInView(d, Self.release) + P(0, -2)
                let t = Double(frame - Self.release + 1) / 5
                for (i, (offset, size)) in [(P(0, 0), 1.7), (P(1.6, -1), 1.4), (P(-1.2, 0.8), 1.2), (P(0.8, 1.2), 1.5)].enumerated() {
                    let p = start + (skip - start) * t + offset * (1 - t * 0.5) + P(0, -16 * t * (1 - t))
                    if t < 0.95 { IndustrialPeopleProps.coalLump(&ground, at: p, size: size, turn: Double(frame * 40 + i * 70)) }
                }
            }
            IndustrialViews.placed(&ground, d, pivot: Self.bite, to: bite) { svg in
                IndustrialPeopleProps.skipFront(&svg, left: Self.skipLeft, width: Self.skipWidth, height: Self.skipHeight)
            }
            if !nearer { d.svg.raw(ground.body) }
        }
        d.figure { d in
            // The arms as the pose has them, or reaching the shovel whilst he shovels.
            var arms: [(front: Bool, arm: IndustrialViews.Arm)] = []
            var shovel: (anchor: P, degrees: Double, yaw: Double, load: Double, depth: Double)?
            switch pose {
            case .working:
                let s = Self.shovelInView(d, frame, rig: d.rig)
                let near = IndustrialViews.hold(d, front: true, origin: s.grip, direction: s.direction,
                                                along: (IndustrialPeopleKit.body(Self.holds[frame], d.rig) - IndustrialPeopleKit.body(Self.grips[frame], d.rig)).x
                                                    / max(abs(sin(s.degrees * .pi / 180)), 0.2))
                arms = [(false, IndustrialViews.reach(d, front: false, to: s.grip)), (true, IndustrialViews.reach(d, front: true, to: near))]
                let mid = s.grip + s.direction * 18
                shovel = (IndustrialViews.screen(d, s.grip), s.degrees, s.yaw, Self.loaded.contains(frame) ? 1 : 0, IndustrialViews.depth(d, mid))
            default:
                let near = IndustrialViews.arm(d, front: true)
                arms = [(false, IndustrialViews.arm(d, front: false)), (true, near)]
                let degrees: Double, back: Double
                switch pose {
                case .standing: degrees = Self.plantedDegrees; back = 0.4
                case .walking: degrees = Self.trailDegrees + 3 * IndustrialPeopleKit.wave(frame, 0.2, times: 2); back = Self.trailHold
                default: degrees = d.rig.frontArm.upper - 4; back = 7
                }
                let grip = near.held - IndustrialViews.vector(degrees) * back
                shovel = (IndustrialViews.screen(d, grip), degrees, 0, 0, IndustrialViews.depth(d, grip + IndustrialViews.vector(degrees) * 18))
            }
            func drawShovel(_ d: inout Drawing) {
                guard let s = shovel else { return }
                IndustrialViews.prop(&d, at: s.anchor, degrees: s.degrees, yaw: s.yaw) { svg, at, degrees in
                    IndustrialPeopleProps.shovel(&svg, grip: at, degrees: degrees, load: s.load)
                }
            }
            func drawArm(_ d: inout Drawing, _ a: IndustrialViews.Arm, front: Bool) {
                IndustrialPeopleKit.arm(&d, shoulder: a.shoulder, elbow: a.elbow, hand: a.hand, fill: .team, width: front ? 4.4 : 4.2, rolled: true)
            }
            let shovelBehind = (shovel?.depth ?? 0) < -3
            if shovelBehind { drawShovel(&d) }
            for (front, a) in arms where a.behind { drawArm(&d, a, front: front) }
            IndustrialViews.trousers(&d, colour: IndustrialPeopleInk.soot, shade: IndustrialPeopleInk.darkSoot)
            Self.bodyInView(&d, sway: sway)
            if !shovelBehind { drawShovel(&d) }
            for (front, a) in arms where !a.behind { drawArm(&d, a, front: front) }
            Self.headInView(&d)
        }
        if nearer { d.svg.raw(ground.body) }
    }

    /// The shirt, the braces and the neckerchief, the apron before him and its
    /// strings round him, in a view other than the side.
    static func bodyInView(_ d: inout Drawing, sway: Double) {
        let ink = Paint.colour(Ink.line)
        let shirt = d.turned([P(-9.4, -47.2), P(9.2, -47.2), P(11.4, -21), P(-11.8, -21)]).map(d.up)
        d.svg.polygon(shirt.map { $0 + P(-0.7, 0.6) }, fill: .team)
        if IndustrialViews.seesFront(d) {
            // The placket and its buttons down the middle of the chest.
            if let top = IndustrialViews.front(d, -46.6 - d.rig.lift, 0), let bottom = IndustrialViews.front(d, -37 - d.rig.lift, 0) {
                d.svg.line([top, bottom], stroke: ink, width: 0.8)
                for y in [-44.0, -40.6] {
                    if let b = IndustrialViews.front(d, y - d.rig.lift, 0) { d.svg.circle(b + P(0.9, 0), 0.55, fill: .colour(IndustrialPeopleInk.light), stroke: ink, width: 0.4) }
                }
            }
        }
        d.svg.polygon(shirt, fill: .none, stroke: ink, width: 1.6)
        // The braces over the shoulders, front and back, buttoned at the waist.
        for z in [-5.2, 5.2] {
            for side in [true, false] {
                let top = side ? IndustrialViews.front(d, -47.2 - d.rig.lift, z) : IndustrialViews.back(d, -47.2 - d.rig.lift, z * 0.8)
                let bottom = side ? IndustrialViews.front(d, -21.4, z * 1.1) : IndustrialViews.back(d, -21.4, z * 0.4)
                guard let top, let bottom else { continue }
                d.svg.line([top, bottom], stroke: ink, width: 3.3)
                d.svg.line([top, bottom], stroke: .colour(IndustrialPeopleInk.darkLeather), width: 2.1)
                d.svg.circle(bottom + P(0, -0.6), 0.6, fill: .colour(IndustrialPeopleInk.paleSoot), stroke: ink, width: 0.4)
            }
        }
        // The neckerchief round the neck, knotted at the throat.
        let lift = d.rig.lift
        d.svg.polygon([P(-5.8, -48 - lift), P(5.8, -48 - lift), P(5.4, -45.2 - lift), P(-5.4, -45.2 - lift)], fill: .colour(IndustrialPeopleInk.paleSoot),
                      stroke: ink, width: 0.9)
        if let knot = IndustrialViews.front(d, -45.4 - lift, 0, half: 6) {
            d.svg.polygon([knot + P(-0.4, -0.4), knot + P(1.6, -0.6), knot + P(2.2, 4.2), knot + P(0.4, 3.6)], fill: .colour(IndustrialPeopleInk.paleSoot),
                          stroke: ink, width: 0.8)
            d.svg.circle(knot, 1.2, fill: .colour(IndustrialPeopleInk.soot), stroke: ink, width: 0.7)
        }
        // The apron's strings round the waist, and the apron itself before him.
        let strings = d.turned([P(-11.6, -25.2), P(12.8, -25.2), P(12.8, -24), P(-11.6, -24)])
        d.svg.polygon(strings, fill: .colour(IndustrialPeopleInk.paleLeather), stroke: ink, width: 0.6)
        if IndustrialViews.seesFront(d) {
            let top = [IndustrialPoint(10, -24.8, -8.6), IndustrialPoint(10, -24.8, 8.6)]
            let hem = [IndustrialPoint(13 - sway * 1.3, -7.6, 9.4), IndustrialPoint(13 - sway * 1.3, -7.6, -9.4)]
            let apron = (top + hem).map { IndustrialViews.screen(d, $0) }
            d.svg.polygon(apron.map { $0 + P(-0.7, 0.6) }, fill: .colour(IndustrialPeopleInk.leather))
            d.svg.ellipse(apron[0] + (apron[2] - apron[0]) * 0.55, 1.6, 1.1, fill: .colour(IndustrialPeopleInk.darkLeather), opacity: 0.7)
            d.svg.ellipse(apron[1] + (apron[3] - apron[1]) * 0.7, 1.1, 0.8, fill: .colour(IndustrialPeopleInk.darkLeather), opacity: 0.6)
            var stitch = PathData()
            for i in 0..<6 {
                let p = apron[3] + (apron[2] - apron[3]) * (Double(i) / 6 + 0.06) + P(0, -1)
                stitch.move(p); stitch.line(p + P(1.1, -0.05))
            }
            d.svg.path(stitch, stroke: .colour(IndustrialPeopleInk.paleLeather), width: 0.6)
            d.svg.polygon(apron, fill: .none, stroke: ink, width: 1.3)
        } else if let knot = IndustrialViews.back(d, -24.6, 0) {
            // The strings tied in a bow at his back.
            d.svg.path("M\(num(knot.x)),\(num(knot.y)) q-3,-2.4 -3.4,0.4 q0.6,1.8 3.4,-0.4 q3,-2.4 3.4,0.4 q-0.6,1.8 -3.4,-0.4 "
                       + "l-1.4,4.4 M\(num(knot.x)),\(num(knot.y)) l1.2,4.6", fill: .none, stroke: .colour(IndustrialPeopleInk.paleLeather), width: 1)
        }
    }

    /// The head in a view other than the side: the sideburns and the hair at
    /// the nape, the stubble and the moustache where the face shows, and the flat cap.
    static func headInView(_ d: inout Drawing) {
        let hair = Paint.colour(IndustrialPeopleInk.brownHair), ink = Paint.colour(Ink.line)
        d.head(nose: .bulb, behind: { d in
            if let p = IndustrialViews.peak(d, rim: -64.6, reach: 7, drop: 2.2, half: 9.4), !IndustrialViews.seesFront(d) {
                d.svg.path(p, fill: .colour(IndustrialPeopleInk.green), stroke: ink, width: 1.2)
            }
        }, hair: { d in
            switch d.view {
            case .front:
                for s in [-1.0, 1.0] {
                    d.svg.polygon([P(9.8 * s, -62.6), P(7.4 * s, -62.6), P(7.8 * s, -55.6), P(9 * s, -52.6), P(10.4 * s, -55)], fill: hair)
                }
            case .frontQuarter:
                d.svg.path("M-11.2,-61.4 C-12.4,-57 -11.6,-53 -9.4,-51.4 L-9.6,-60.6 Z", fill: hair)
                d.svg.polygon([P(-5.4, -63), P(-3.6, -62.6), P(-3.2, -55), P(-4.6, -53), P(-5.8, -57)], fill: hair)
                d.svg.polygon([P(9.4, -62.6), P(10.6, -60), P(10.2, -55), P(9.2, -56)], fill: hair)
            case .back:
                d.svg.path(IndustrialViews.backHair(d, rim: -62.4), fill: hair)
            case .backQuarter:
                d.svg.path(IndustrialViews.backHair(d, rim: -62.4, right: 5.4), fill: hair)
                d.svg.polygon([P(8.6, -62.4), P(10.4, -62), P(9.8, -55.6), P(8.4, -56.8)], fill: hair)
            case .side:
                break
            }
        }, features: { d in
            guard IndustrialViews.seesFront(d) else { return }
            // Stubble along the jaw, and the bushy moustache drooping at its ends.
            var stubble = PathData()
            for p in IndustrialViews.symmetric(d, [P(1.4, -48), P(3.8, -48.8), P(6, -50.2), P(7.8, -52.2)]) {
                stubble.move(p); stubble.line(p + P(0.3, 0.2))
            }
            d.svg.path(stubble, stroke: hair, width: 0.7, opacity: 0.7)
            let half = [P(0, -54.8), P(2.6, -55.4), P(5, -54.4), P(6.4, -52.2), P(6, -49.8), P(4.6, -51.2), P(2.4, -52.2), P(0, -51.8)]
            d.svg.polygon(IndustrialViews.symmetric(d, half), fill: hair, stroke: ink, width: 0.9)
        }, brow: { d in
            d.svg.path("M1.4,-63.4 q3.4,-2 7.2,-0.4", stroke: hair, width: 2)
        }, over: { d in
            Self.capInView(&d)
        })
    }

    /// The flat cap of bottle-green tweed seen from this side: its crown pulled
    /// forward, the short peak, the flecks and the button.
    static func capInView(_ d: inout Drawing) {
        let ink = Paint.colour(Ink.line), green = Paint.colour(IndustrialPeopleInk.green)
        let rim = d.view == .back ? -61.6 : -63.4
        let view = d
        BronzePeopleProps.shape(&d.svg, fill: green, width: 1.5) { o in
            IndustrialViews.crown(view, rim: rim, top: -72.6, half: 12.2, forward: 2.4, flare: 1.4, offset: o)
        }
        if IndustrialViews.seesFront(d), let p = IndustrialViews.peak(d, rim: -64.6, reach: 7, drop: 2.2, half: 9.4) {
            d.svg.path(p, fill: green, stroke: ink, width: 1.2)
            if let shade = IndustrialViews.capFront(d, y: -64.2) {
                d.svg.path("M\(num(shade.x - 6)),\(num(shade.y)) q6,-1.2 12,0", stroke: .colour(IndustrialPeopleInk.darkGreen), width: 1)
            }
        }
        let c = 2.4 * IndustrialViews.ahead(d)
        var flecks = PathData()
        for (x, y) in [(-8.0, -66.6), (-4.4, -69.4), (-0.6, -67.2), (3.2, -69.6), (6.6, -67.4), (-6.6, -64.6), (8.8, -65.4), (0.8, -70.8)] {
            flecks.move(P(x + c, y)); flecks.line(P(x + c + 0.7, y - 0.3))
        }
        d.svg.path(flecks, stroke: .colour(IndustrialPeopleInk.paleGreen), width: 0.6)
        d.svg.ellipse(P(c, -72.4), 1.6, 0.9, fill: .colour(IndustrialPeopleInk.darkGreen), stroke: ink, width: 0.7)
    }
}
