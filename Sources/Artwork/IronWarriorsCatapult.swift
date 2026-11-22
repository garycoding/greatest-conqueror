// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The catapult

/// A torsion catapult on wheels, with its crew of two drawn on the shared
/// figure (the crew are part of the unit, trained with it; ruled 2026-11-18).
///
/// The engine: a timber frame on four six-spoked wheels shod with iron, its
/// near beam painted in the team's colour with lozenges in the light; a skein of
/// twisted rope at the middle, through which the throwing arm passes, an iron
/// cup at the arm's end; two uprights braced from the front, carrying the
/// leather buffer the arm strikes; and a windlass at the back. The winder, in a
/// linen tunic and a leather cap, with a beard and nose B, works the windlass;
/// the captain, in an iron helmet and a sea-green tunic with a scarf of legion
/// red, nose E, gives the word. Standing, the arm rests against the buffer with
/// a stone in its cup; walking, the winder pushes and the captain hauls on a
/// rope, and the wheels turn; fighting, the winder cranks the arm down, loads
/// it and pulls the trigger at the captain's signal, and the arm swings up,
/// strikes the buffer and throws the stone. The origin is on the ground midway
/// between the wheels.
struct IronWarriorsCatapult: PersonLook {
    static let canvas = Canvas(minX: -86, minY: -116, width: 192, height: 122, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The engine is drawn in its own units and enlarged by this, so that it
    /// stands rightly to its crew; the crew are placed in the picture's units.
    static let scale = 1.3
    /// A point of the engine where it falls in the picture.
    static func placed(_ p: P) -> P { p * scale }

    static let wheelRadius = 9.0
    static let wheels = [P(-20, -9), P(20, -9)]
    /// Where the far side of the engine is drawn, behind and above the near side.
    static let far = P(3.6, -3.4)
    /// The skein, about which the arm turns, and the arm's length to its cup.
    static let pivot = P(-4, -22)
    static let armLength = 40.0
    /// The arm at rest against the buffer, and wound down to the windlass.
    static let rest = 150.0, wound = 268.0
    static let drum = P(-29, -26.6)
    /// Where the winder's hand pulls the trigger's cord to.
    static let pull = winder + P(4, -37)
    static let winder = P(-60, 0), captain = P(62, 0)
    /// The wheels turn this many degrees a frame when moving: under half the 60
    /// degrees between spokes, so that they never seem to turn backward, and
    /// four spokes in the 12 frames, so that the cycle repeats without a jump.
    /// The crew's stride is matched to the ground the wheels cover.
    static let turn = 20.0
    /// The ground the engine covers in a frame of the walking pose.
    static let groundPerFrame = wheelRadius * scale * turn * .pi / 180
    static let pace = 24.5

    // MARK: The engine's arm and the stone

    /// The arm's direction in a frame of a pose.
    static func armDegrees(_ pose: SpritePose, _ frame: Int) -> Double {
        guard pose == .fighting else { return rest }
        switch frame {
        case 0...6: return mix(rest, wound, ease(Double(frame) / 6))
        case 7: return wound
        case 8: return 206
        case 9: return rest - 4
        case 10: return rest + 3
        default: return rest
        }
    }

    /// Whether the cup holds a stone: always at rest, and from the loading until the throw.
    static func loaded(_ pose: SpritePose, _ frame: Int) -> Bool { pose != .fighting || (frame >= 6 && frame <= 8) }

    /// Where the thrown stone is in flight, if it is.
    static func flight(_ frame: Int) -> P? {
        switch frame {
        case 9: P(28, -66)
        case 10: P(39, -76)
        case 11: P(50, -83)
        default: nil
        }
    }

    /// The windlass's handle, at `degrees` about the drum, in the engine's units.
    static func handleLocal(_ degrees: Double) -> P { drum + P.direction(degrees) * 4.2 }
    /// The windlass's handle where it falls in the picture.
    static func handle(_ degrees: Double) -> P { placed(handleLocal(degrees)) }

    /// The handle's turn in a frame: wound round whilst the arm comes down.
    static func crank(_ pose: SpritePose, _ frame: Int) -> Double {
        pose == .fighting && frame <= 6 ? 200 - Double(frame) * 62 : 200
    }

    // MARK: The crew

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? { Self.winderRig(pose, frame) }

    /// How far a rig's figure is raised so that its lower foot rests on the ground.
    static func bob(_ r: Rig) -> Double {
        let j = Joints(r)
        return -max(j.backFoot.y, j.frontFoot.y)
    }

    /// The arm that puts a figure's hand at `target`, a point of the picture.
    static func reach(_ r: Rig, front: Bool, at origin: P, to target: P, elbowUp: Bool = false) -> Limb {
        let local = IronWarriorsKit.local(target, origin: origin, lean: r.lean, bob: bob(r))
        return BronzePeopleKit.reach(front ? IronWarriorsKit.frontShoulder(r) : IronWarriorsKit.backShoulder(r), local, elbowUp: elbowUp)
    }

    static func winderRig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        var r: Rig
        switch pose {
        case .standing:
            r = Moves.standing(frame)
            r.lean = 5
            r.frontArm = reach(r, front: true, at: winder, to: handle(200))
            r.mouth = .smile
        case .walking:
            r = Moves.walking(frame, stride: pace)
            r.lean = 16
            r.frontArm = reach(r, front: true, at: winder, to: placed(drum + P(-1.4, -1.6)))
            r.backArm = reach(r, front: false, at: winder, to: placed(drum + P(-3, 1.2)))
            r.mouth = .firm
        case .fighting:
            r = Moves.standing(0)
            r.backLeg = Limb(-12, 6); r.frontLeg = Limb(10, 6)
            r.mouth = .firm
            switch frame {
            case 0...5:
                r.lean = 12 + 2 * sin(Double(frame) * 1.05)
                let h = handle(crank(pose, frame))
                r.frontArm = reach(r, front: true, at: winder, to: h)
                r.backArm = reach(r, front: false, at: winder, to: h + P(-0.6, 0.6))
            case 6:
                // The stone set in the cup, behind him.
                r.lean = 16
                r.frontArm = reach(r, front: true, at: winder, to: winder + P(9, -28))
                r.backArm = reach(r, front: false, at: winder, to: winder + P(6, -26))
            case 7, 8:
                // The trigger's cord pulled at the captain's word.
                r.lean = frame == 7 ? -6 : -4
                r.frontArm = reach(r, front: true, at: winder, to: Self.pull + P(0, Double(frame - 7) * 2))
                r.backArm = reach(r, front: false, at: winder, to: Self.pull + P(-3, 2))
                r.mouth = .open
                r.eyes = frame == 8 ? .wide : .open
            default:
                r.lean = mix(-2, 12, Double(frame - 8) / 4)
                let h = handle(200)
                let t = Double(frame - 8) / 4
                r.frontArm = reach(r, front: true, at: winder, to: Self.pull + (h - Self.pull) * ease(t))
                r.backArm = reach(r, front: false, at: winder, to: Self.pull + P(-3, 2) + (h - Self.pull - P(-3, 2)) * ease(t))
            }
        default:
            return nil
        }
        return r
    }

    static func captainRig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        var r: Rig
        switch pose {
        case .standing:
            r = Moves.standing((frame + 5) % 12)
            r.eyes = frame == 2 ? .closed : .open
            r.frontArm = Limb(20 + r.lift, 60)
            r.mouth = .firm
        case .walking:
            r = Moves.walking(frame, stride: pace)
            r.lean = 11
            // The rope over his shoulder, held in the back hand at the chest.
            r.backArm = BronzePeopleKit.reach(IronWarriorsKit.backShoulder(r), P(2, -42), elbowUp: false)
            r.mouth = .firm
        case .fighting:
            r = Moves.standing(0)
            r.backLeg = Limb(-8, 4); r.frontLeg = Limb(9, 4)
            // The staff raised for the word, brought down to loose, and raised again.
            let raised: [Double] = [140, 142, 140, 142, 140, 142, 146, 92, 88, 108, 124, 136]
            r.frontArm = Limb(raised[frame], frame == 7 || frame == 8 ? 0 : 22)
            r.lean = frame == 7 || frame == 8 ? 6 : -1
            r.mouth = frame == 7 || frame == 8 ? .shout : (frame >= 9 ? .smile : .firm)
            r.eyes = frame == 9 || frame == 10 ? .wide : .open
            r.headTilt = frame >= 9 && frame <= 10 ? -6 : 0
        default:
            return nil
        }
        return r
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let layer = d.svg.layer
        let phase = d.phase
        let spin = pose == .walking ? -Double(frame) * Self.turn : 0
        let arm = Self.armDegrees(pose, frame)
        d.svg.ellipse(P(0, 0.2), 52, 4.2, fill: .colour("#000000"), opacity: 0.13)
        d.svg.raw("<g transform=\"scale(\(num(Self.scale)))\">")
        // The far side: wheels, beam and upright, darker.
        for c in Self.wheels { Self.wheel(&d.svg, at: c + Self.far, degrees: spin + 12, far: true) }
        Self.beam(&d.svg, offset: Self.far, far: true)
        Self.upright(&d.svg, offset: Self.far, far: true)
        // The arm, between the sides, and the rope that winds it down.
        if pose == .fighting && frame >= 1 && frame <= 7 {
            let hook = Self.pivot + P.direction(arm) * 28
            d.svg.line([Self.drum + P(0, 3.2), hook], stroke: .colour(Ink.line), width: 1.6)
            d.svg.line([Self.drum + P(0, 3.2), hook], stroke: .colour(IronWarriorsInk.rope), width: 0.8)
        }
        if pose == .fighting && frame == 8 {
            d.swish(around: Self.pivot, radius: Self.armLength + 3, from: 252, to: 214)
        }
        Self.arm(&d.svg, degrees: arm, loaded: Self.loaded(pose, frame))
        Self.skein(&d.svg)
        Self.beam(&d.svg, offset: P(0, 0), far: false)
        Self.upright(&d.svg, offset: P(0, 0), far: false)
        if pose == .fighting && frame == 9 {
            d.burst(at: Self.pivot + P.direction(Self.rest) * 34 + P(2.6, -0.6), from: 20, to: 150, size: 0.9)
        }
        Self.windlass(&d.svg, handle: Self.crank(pose, frame))
        for c in Self.wheels { Self.wheel(&d.svg, at: c, degrees: spin, far: false) }
        if let stone = Self.flight(frame), pose == .fighting {
            Self.stone(&d.svg, at: stone)
            if frame == 9 {
                d.svg.path("M\(num(stone.x - 9)),\(num(stone.y + 6)) l5,-3.6 M\(num(stone.x - 7)),\(num(stone.y + 10)) l5,-3.6",
                           stroke: .colour(Ink.line), width: 1, opacity: 0.6)
            }
        }
        d.svg.raw("</g>")
        // The crew.
        if let r = Self.winderRig(pose, frame) {
            var crew = Drawing(layer: layer, rig: r, phase: phase)
            Self.drawWinder(&crew, pose, frame)
            if pose == .fighting && (frame == 7 || frame == 8) {
                // The trigger's cord, from the catch at the frame's end to his hand.
                let hand = crew.world(crew.joints.frontHand) + Self.winder
                d.svg.line([Self.placed(P(-33, -21)), hand], stroke: .colour(Ink.line), width: 0.9)
            }
            let body = crew.svg.body
            d.svg.group(at: Self.winder) { $0.raw(body) }
        }
        if let r = Self.captainRig(pose, frame) {
            var crew = Drawing(layer: layer, rig: r, phase: phase)
            Self.drawCaptain(&crew, pose, frame)
            if pose == .walking {
                // The hauling rope, from the frame's front to his hand.
                let hand = crew.world(crew.joints.backHand) + Self.captain
                var rope = PathData()
                rope.move(Self.placed(P(31, -18))); rope.quad(Self.placed(P(40, -21)), hand)
                d.svg.path(rope, stroke: .colour(Ink.line), width: 1.7)
                d.svg.path(rope, stroke: .colour(IronWarriorsInk.rope), width: 0.8)
            }
            let body = crew.svg.body
            d.svg.group(at: Self.captain) { $0.raw(body) }
        }
    }

    // MARK: The engine's parts

    /// A side beam of the frame: the near one painted in the team's colour with
    /// lozenges in the light and capped in iron; the far one bare and darker.
    static func beam(_ svg: inout SVG, offset o: P, far: Bool) {
        let corners = [P(-34, -21.4), P(31, -21.4), P(31, -14), P(-34, -14)].map { $0 + o }
        if far {
            IronWarriorsKit.shape(&svg, corners, fill: .colour(IronWarriorsInk.darkWood), width: 1.3)
            return
        }
        svg.polygon(corners.map { $0 + P(-0.7, 0.6) }, fill: .team)
        var lozenges = PathData()
        for x in stride(from: -26.0, through: 24.0, by: 7.2) {
            let c = P(x, -17.6)
            lozenges.move(c + P(0, -2.2)); lozenges.line(c + P(2.4, 0)); lozenges.line(c + P(0, 2.2)); lozenges.line(c + P(-2.4, 0))
            lozenges.close()
        }
        svg.path(lozenges, fill: .colour(IronWarriorsInk.light))
        svg.line([P(-33, -20.2), P(30, -20.2)], stroke: .colour(IronWarriorsInk.light), width: 0.7, opacity: 0.8)
        svg.polygon(corners, fill: .none, stroke: .colour(Ink.line), width: 1.5)
        // Iron caps on the beam's ends, riveted.
        for x in [-34.0, 27.4] {
            IronWarriorsKit.shape(&svg, [P(x, -21.8), P(x + 3.6, -21.8), P(x + 3.6, -13.6), P(x, -13.6)], fill: .colour(IronWarriorsInk.iron), width: 1.1)
            svg.circle(P(x + 1.8, -19.2), 0.6, fill: .colour(Ink.line))
            svg.circle(P(x + 1.8, -16.2), 0.6, fill: .colour(Ink.line))
        }
    }

    /// An upright carrying the buffer, braced by a strut to the frame's front.
    static func upright(_ svg: inout SVG, offset o: P, far: Bool) {
        let wood = far ? IronWarriorsInk.darkWood : IronWarriorsInk.wood
        IronWarriorsKit.shape(&svg, [P(14.4, -53.4), P(18, -53.4), P(18, -21), P(14.4, -21)].map { $0 + o }, fill: .colour(wood), width: 1.3)
        IronWarriorsKit.shape(&svg, [P(28.6, -21), P(31, -22.6), P(18.6, -47.6), P(17, -45)].map { $0 + o }, fill: .colour(wood), width: 1.2)
        if far { return }
        // The crossbar's end, and the leather buffer on its back, stitched.
        svg.circle(P(16.2, -50.6) + P(-0.5, 0.5), 2.4, fill: .colour(IronWarriorsInk.paleWood))
        svg.circle(P(16.2, -50.6), 2.4, fill: .none, stroke: .colour(Ink.line), width: 1.1)
        IronWarriorsKit.shape(&svg, [P(10.8, -54.6), P(14.6, -55), P(15, -45.2), P(11.4, -44.8), P(10.2, -49.6)], fill: .colour(IronWarriorsInk.leather),
                              width: 1.2)
        svg.path("M12.2,-53 l0.6,1 M11.6,-50 l0.8,0.6 M12,-47 l0.8,0.6", stroke: .colour(IronWarriorsInk.rope), width: 0.7)
        // Iron bands on the upright.
        for y in [-38.0, -27.0] {
            svg.line([P(14.2, y), P(18.2, y)], stroke: .colour(Ink.line), width: 2.2)
            svg.line([P(14.4, y), P(18, y)], stroke: .colour(IronWarriorsInk.iron), width: 1)
        }
    }

    /// The throwing arm along `degrees` from the skein: a tapering timber bound
    /// with iron, with an iron cup at its end, a stone in it when `loaded`.
    static func arm(_ svg: inout SVG, degrees: Double, loaded: Bool) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let start = pivot - u * 5, end = pivot + u * armLength
        IronWarriorsKit.shape(&svg, [start + a * 2.6, end + a * 1.7, end - a * 1.7, start - a * 2.6], fill: .colour(IronWarriorsInk.paleWood), width: 1.3)
        svg.line([start + a * 1.2 + u * 6, end + a * 0.6 - u * 3], stroke: .colour(IronWarriorsInk.wood), width: 0.8)
        for t in [0.45, 0.8] {
            let c = pivot + u * (armLength * t)
            svg.line([c + a * 2.4, c - a * 2.4], stroke: .colour(Ink.line), width: 2)
            svg.line([c + a * 2, c - a * 2], stroke: .colour(IronWarriorsInk.iron), width: 0.9)
        }
        // The cup, opening toward the arm's swing.
        let cup = end + a * 1
        var bowl = PathData()
        bowl.move(cup - u * 3.4); bowl.quad(cup + a * 4.6, cup + u * 3.4); bowl.close()
        if loaded { stone(&svg, at: cup + a * 2.6) }
        svg.path(bowl, fill: .colour(IronWarriorsInk.iron), stroke: .colour(Ink.line), width: 1.1)
        svg.line([cup - u * 3.4, cup + u * 3.4], stroke: .colour(Ink.line), width: 1.4)
    }

    /// The skein of twisted rope at the pivot, held in an iron washer.
    static func skein(_ svg: inout SVG) {
        svg.circle(pivot + P(-0.5, 0.5), 4.8, fill: .colour(IronWarriorsInk.rope))
        var twist = PathData()
        for i in 0..<4 {
            let angle = Double(i) * 45 + 20
            let u = P.direction(angle)
            twist.move(pivot - u * 4.2); twist.quad(pivot + P(-u.y, u.x) * 1.4, pivot + u * 4.2)
        }
        svg.path(twist, stroke: .colour(IronWarriorsInk.wood), width: 0.7)
        svg.circle(pivot, 4.8, fill: .none, stroke: .colour(IronWarriorsInk.iron), width: 1.4)
        svg.circle(pivot, 5.6, fill: .none, stroke: .colour(Ink.line), width: 1.2)
        svg.circle(pivot, 1.3, fill: .colour(Ink.line))
    }

    /// The windlass at the frame's back: a drum on a post, and a crank whose handle is at `handle` degrees.
    static func windlass(_ svg: inout SVG, handle degrees: Double) {
        IronWarriorsKit.shape(&svg, [P(-31.2, -26.6), P(-27, -26.6), P(-27.6, -21), P(-30.8, -21)], fill: .colour(IronWarriorsInk.wood), width: 1.1)
        svg.circle(drum + P(-0.4, 0.4), 3.4, fill: .colour(IronWarriorsInk.rope))
        svg.circle(drum, 3.4, fill: .none, stroke: .colour(Ink.line), width: 1.2)
        svg.path("M\(num(drum.x - 2.6)),\(num(drum.y - 1.2)) h5.2 M\(num(drum.x - 2.8)),\(num(drum.y + 0.6)) h5.6",
                 stroke: .colour(IronWarriorsInk.wood), width: 0.6)
        let h = handle(degrees)
        svg.line([drum, h], stroke: .colour(Ink.line), width: 2.4)
        svg.line([drum, h], stroke: .colour(IronWarriorsInk.iron), width: 1)
        svg.circle(h, 1.3, fill: .colour(IronWarriorsInk.darkWood), stroke: .colour(Ink.line), width: 0.7)
        svg.circle(drum, 0.9, fill: .colour(IronWarriorsInk.ironDark))
    }

    /// A six-spoked wheel shod with iron, turned by `degrees`.
    static func wheel(_ svg: inout SVG, at c: P, degrees: Double, far: Bool) {
        let r = wheelRadius
        let wood = far ? IronWarriorsInk.darkWood : IronWarriorsInk.wood
        for i in 0..<6 {
            let u = P.direction(degrees + Double(i) * 60)
            svg.line([c + u * 2.2, c + u * (r - 2.2)], stroke: .colour(Ink.line), width: 2.4)
            svg.line([c + u * 2.4, c + u * (r - 2.4)], stroke: .colour(wood), width: 1.1)
        }
        svg.circle(c, r - 1.6, fill: .none, stroke: .colour(wood), width: 2.4)
        svg.circle(c, r - 0.4, fill: .none, stroke: .colour(far ? IronWarriorsInk.ironDark : IronWarriorsInk.iron), width: 1.2)
        svg.circle(c, r, fill: .none, stroke: .colour(Ink.line), width: 1.6)
        svg.circle(c, r - 2.8, fill: .none, stroke: .colour(Ink.line), width: 0.8)
        svg.circle(c, 2.4, fill: .colour(far ? IronWarriorsInk.ironDark : IronWarriorsInk.iron), stroke: .colour(Ink.line), width: 1)
        svg.circle(c, 0.8, fill: .colour(Ink.line))
    }

    static func stone(_ svg: inout SVG, at c: P) {
        svg.circle(c + P(-0.4, 0.4), 2.7, fill: .colour(IronWarriorsInk.stone))
        svg.circle(c, 2.7, fill: .none, stroke: .colour(Ink.line), width: 1.1)
        svg.path("M\(num(c.x - 1.2)),\(num(c.y - 0.6)) l1.2,0.8", stroke: .colour(Ink.line), width: 0.7, opacity: 0.7)
    }

    // MARK: The crew's figures

    /// A linen tunic hemmed in sea green, drawn on a crewman.
    static func tunic(_ d: inout Drawing, fill: String, hem: String) {
        let outline = [P(-8, -47), P(8.4, -47), P(11.6, -17), P(-12.2, -17)]
        if d.view != .side {
            // Seen from another side, the hem and the belt run across the tunic's width as the view turns it.
            d.garment(colour: [P(-11.6, -46), P(8.6, -48), P(12.6, -15.6), P(-13.6, -15)], outline: outline, fill: .colour(fill)) { d in
                let across = IronViews.span(d, outline, at: -19)
                d.svg.line([P(across.left + 0.4, -19), P(across.right - 0.4, -19)], stroke: .colour(hem), width: 1.6)
            }
            let belt = IronViews.span(d, outline, at: -29.6)
            d.svg.line([d.up(P(belt.left, -29.6)), d.up(P(belt.right, -29.8))], stroke: .colour(Ink.line), width: 2.8)
            d.svg.line([d.up(P(belt.left + 0.4, -29.6)), d.up(P(belt.right - 0.4, -29.8))], stroke: .colour(IronWarriorsInk.leather), width: 1.4)
            return
        }
        d.garment(colour: [P(-11.6, -46), P(8.6, -48), P(12.6, -15.6), P(-13.6, -15)],
                  outline: outline, fill: .colour(fill)) { d in
            d.svg.line([P(-11.8, -19), P(11.4, -19)], stroke: .colour(hem), width: 1.6)
        }
        d.svg.line([d.up(P(-11.6, -29.6)), d.up(P(10.6, -29.8))], stroke: .colour(Ink.line), width: 2.8)
        d.svg.line([d.up(P(-11.2, -29.6)), d.up(P(10.2, -29.8))], stroke: .colour(IronWarriorsInk.leather), width: 1.4)
    }

    static func drawWinder(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        d.figure { d in
            d.arm(front: false)
            d.legs()
            tunic(&d, fill: IronWarriorsInk.light, hem: IronWarriorsInk.deepSea)
            d.arm(front: true)
            d.head(nose: .button, hair: { d in
                if d.view != .side { IronPeopleFarmer.curls(&d, colour: IronPeopleInk.hair, curl: IronPeopleInk.paleLeather); return }
                d.svg.path("M-10.6,-56 C-11.6,-59 -11,-61.6 -9.4,-63.4 L-7.2,-58.6 Z", fill: .colour(Ink.line))
            }, features: { d in
                // A short full beard.
                switch d.view {
                case .side:
                    d.svg.path("M-1.6,-52 C-0.4,-46.6 4.4,-44.4 8.6,-46.2 C10,-47.6 10.6,-49.4 10.4,-50.6 C7.6,-49.2 4.6,-49.4 2.4,-51.2 Z",
                               fill: .colour(Ink.line))
                case .front:
                    d.svg.path("M-7.4,-53.6 C-7,-48 -3.4,-45 0,-45 C3.4,-45 7,-48 7.4,-53.6 C4.6,-50.2 2,-49.4 0,-49.6 "
                               + "C-2,-49.4 -4.6,-50.2 -7.4,-53.6 Z", fill: .colour(Ink.line))
                case .frontQuarter:
                    d.svg.path("M-3.6,-52.8 C-2.4,-46.8 2.4,-44.4 6.6,-46 C9.4,-47.4 10.6,-49.4 10.4,-50.8 C7.6,-49.2 4.6,-49 2.4,-50.4 "
                               + "C0.4,-50.8 -1.6,-51.6 -3.6,-52.8 Z", fill: .colour(Ink.line))
                default:
                    break
                }
            }, brow: { d in
                d.svg.path("M1.8,-63.6 q3,-1 6.2,0", stroke: .colour(Ink.line), width: 1.6)
            }, over: { d in
                if d.view == .front || d.view == .back {
                    // The felt cap seen from straight ahead or behind.
                    BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.leather), width: 1.4) { o in
                        var p = PathData()
                        p.move(P(-11.6, -61.4) + o)
                        p.cubic(P(-12.4, -74.6) + o, P(12.4, -74.6) + o, P(11.6, -61.4) + o)
                        p.cubic(P(5, -64.4) + o, P(-5, -64.4) + o, P(-11.6, -61.4) + o)
                        p.close()
                        return p
                    }
                    d.svg.path("M-10.4,-63.6 C-4,-66.8 4,-66.8 10.4,-63.6", stroke: .colour(IronWarriorsInk.darkLeather), width: 1)
                    return
                }
                // A felt cap.
                BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.leather), width: 1.4) { o in
                    var p = PathData()
                    p.move(P(-11.4, -60.4) + o)
                    p.cubic(P(-11.8, -72.8) + o, P(4.2, -76.4) + o, P(10.2, -64.8) + o)
                    p.cubic(P(3.4, -66.8) + o, P(-4.6, -65.4) + o, P(-11.4, -60.4) + o)
                    p.close()
                    return p
                }
                d.svg.path("M-9.6,-62.6 C-4.6,-66 2.4,-67 8.6,-65.4", stroke: .colour(IronWarriorsInk.darkLeather), width: 1)
            })
        }
    }

    static func drawCaptain(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        d.figure { d in
            d.arm(front: false)
            d.legs()
            tunic(&d, fill: IronWarriorsInk.deepSea, hem: IronWarriorsInk.paleSea)
            let scarf = [P(-6.4, -48.6), P(7.6, -48.8), P(8.6, -45.4), P(1, -44.2), P(-6.8, -45.4)]
            IronWarriorsKit.shape(&d.svg, d.view == .side ? scarf.map(d.up) : IronViews.around(d, scarf),
                                  fill: .colour(IronWarriorsInk.legion), width: 1.1)
            // His staff of office, a knotted vine stick.
            let hand = d.view == .side ? d.joints.frontHand : d.hand(front: true)
            let degrees = pose == .fighting ? d.rig.frontArm.upper + d.rig.frontArm.bend + 14 : 168.0
            let along = d.view == .side ? (degrees: degrees, share: 1.0) : IronViews.tool(d.view, degrees)
            let u = P.direction(along.degrees), k = along.share
            d.svg.line([hand - u * (4 * k), hand + u * (15 * k)], stroke: .colour(Ink.line), width: 2.8)
            d.svg.line([hand - u * (3.6 * k), hand + u * (14.6 * k)], stroke: .colour(IronWarriorsInk.paleWood), width: 1.4)
            for t in [5.0, 10.0] {
                d.svg.circle(hand + u * (t * k) + P(-u.y, u.x) * 0.9, 0.7, fill: .colour(Ink.line))
            }
            d.arm(front: true)
            d.head(nose: .line, hair: { _ in }, features: { d in
                if d.view == .side { d.svg.path("M4.2,-52.8 q3.2,-1.2 6.4,-0.2", stroke: .colour(Ink.line), width: 1.2) }
            }, brow: { d in
                d.svg.path("M1.6,-64 l6.4,1", stroke: .colour(Ink.line), width: 1.8)
            }, over: { d in
                IronWarriorsKit.helmet(&d, crest: .none)
            })
        }
    }
}

// MARK: - The catapult in the other views

extension IronWarriorsCatapult {
    /// Where the beams, the wheels and the uprights stand across the engine, in its own units.
    static let beamZ = 12.0, wheelZ = 16.0, uprightZ = 10.0
    /// Where the crew stand across the engine, in the picture's units: the
    /// winder at the windlass's crank on its right, the captain off to its left.
    static let winderZ = 12.0, captainZ = -30.0

    /// The catapult seen from the front, from behind, or from a quarter turn,
    /// with the crew before or after it as they are nearer or farther.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view, layer = d.svg.layer, phase = d.phase
        let (c, s) = IronViews.turn(view)
        let endOn = abs(c) < 0.01
        // The crew, each drawn on his own and placed where the view puts him.
        func crew(_ rig: Rig?, at x: Double, z: Double, draw: (inout Drawing) -> Void) -> (body: String, at: P, depth: Double, drawing: Drawing)? {
            guard let rig else { return nil }
            var figure = Drawing(layer: layer, rig: rig, phase: phase, view: view)
            draw(&figure)
            let placed = IronViews.project(view, P(x, 0), z: z)
            return (figure.svg.body, placed.point, placed.depth, figure)
        }
        let winder = crew(Self.winderRig(pose, frame), at: Self.winder.x, z: Self.winderZ) { Self.drawWinder(&$0, pose, frame) }
        let captain = crew(Self.captainRig(pose, frame), at: Self.captain.x, z: Self.captainZ) { Self.drawCaptain(&$0, pose, frame) }
        func place(_ man: (body: String, at: P, depth: Double, drawing: Drawing)?, near: Bool) {
            guard let man, (man.depth > 0) == near else { return }
            d.svg.group(at: man.at) { $0.raw(man.body) }
        }
        let reach = endOn ? Self.wheelZ * Self.scale + 4 : 52 * c + Self.wheelZ * Self.scale * abs(s)
        d.svg.ellipse(P(0, 0.2), reach, 4.2, fill: .colour("#000000"), opacity: 0.13)
        place(winder, near: false); place(captain, near: false)
        d.svg.raw("<g transform=\"scale(\(num(Self.scale)))\">")
        if endOn {
            Self.engineEndOn(&d.svg, view: view, pose: pose, frame: frame)
        } else {
            Self.engineQuarter(&d.svg, view: view, pose: pose, frame: frame)
        }
        if let stone = Self.flight(frame), pose == .fighting {
            Self.stone(&d.svg, at: P(stone.x * c, stone.y))
        }
        d.svg.raw("</g>")
        if let winder, pose == .fighting && (frame == 7 || frame == 8) {
            // The trigger's cord, from the catch at the frame's end to his hand.
            let hand = IronViews.world(winder.drawing, winder.drawing.hand(front: true)) + winder.at
            d.svg.line([Self.placed(IronViews.at(view, P(-33, -21), z: 0)), hand], stroke: .colour(Ink.line), width: 0.9)
        }
        if let captain, pose == .walking {
            // The hauling rope, from the frame's front to his hand.
            let hand = IronViews.world(captain.drawing, captain.drawing.hand(front: false)) + captain.at
            let start = Self.placed(IronViews.at(view, P(31, -18), z: -Self.beamZ))
            var rope = PathData()
            rope.move(start); rope.quad((start + hand) * 0.5 + P(0, 3), hand)
            d.svg.path(rope, stroke: .colour(Ink.line), width: 1.7)
            d.svg.path(rope, stroke: .colour(IronWarriorsInk.rope), width: 0.8)
        }
        place(winder, near: true); place(captain, near: true)
    }

    /// A timber across the engine at `x`, from `top` to `bottom`, painted in the team's colour with lozenges in the light.
    static func crossbeam(_ svg: inout SVG, view: SpriteView, x: Double, top: Double, bottom: Double) {
        let corners = [IronViews.at(view, P(x, top), z: -beamZ - 1.6), IronViews.at(view, P(x, top), z: beamZ + 1.6),
                       IronViews.at(view, P(x, bottom), z: beamZ + 1.6), IronViews.at(view, P(x, bottom), z: -beamZ - 1.6)]
        svg.polygon(corners.map { $0 + P(-0.7, 0.6) }, fill: .team)
        let left = min(corners[0].x, corners[1].x), right = max(corners[0].x, corners[1].x)
        var lozenges = PathData()
        let middle = (top + bottom) / 2, half = (bottom - top) / 2 - 1.4
        var at = left + 4
        while at <= right - 4 {
            let c = P(at, middle)
            lozenges.move(c + P(0, -half)); lozenges.line(c + P(half * 0.9, 0)); lozenges.line(c + P(0, half)); lozenges.line(c + P(-half * 0.9, 0))
            lozenges.close()
            at += 6.4
        }
        svg.path(lozenges, fill: .colour(IronWarriorsInk.light))
        svg.polygon(corners, fill: .none, stroke: .colour(Ink.line), width: 1.4)
    }

    /// The rope skein across the engine at the pivot, between the side beams.
    static func skeinAcross(_ svg: inout SVG, view: SpriteView) {
        let a = IronViews.at(view, pivot, z: -beamZ), b = IronViews.at(view, pivot, z: beamZ)
        svg.line([a, b], stroke: .colour(Ink.line), width: 6.4)
        svg.line([a, b], stroke: .colour(IronWarriorsInk.rope), width: 4.2)
        var twist = PathData()
        for i in 1..<8 {
            let p = a + (b - a) * (Double(i) / 8)
            twist.move(p + P(-0.8, -1.8)); twist.line(p + P(0.8, 1.8))
        }
        svg.path(twist, stroke: .colour(IronWarriorsInk.wood), width: 0.7)
    }

    /// The windlass across the engine's back: its drum between the beams, and its crank on the right end.
    static func windlassAcross(_ svg: inout SVG, view: SpriteView, handle degrees: Double) {
        let (c, _) = IronViews.turn(view)
        let a = IronViews.at(view, drum, z: -beamZ), b = IronViews.at(view, drum, z: beamZ)
        svg.line([a, b], stroke: .colour(Ink.line), width: 8)
        svg.line([a, b], stroke: .colour(IronWarriorsInk.rope), width: 5.6)
        var turns = PathData()
        for i in 1..<9 {
            let p = a + (b - a) * (Double(i) / 9)
            turns.move(p + P(-0.6, -2.6)); turns.line(p + P(0.6, 2.6))
        }
        svg.path(turns, stroke: .colour(IronWarriorsInk.wood), width: 0.6)
        // The crank turns in the engine's own upright plane, at the right end.
        let end = IronViews.at(view, drum, z: beamZ + 2)
        let h = end + IronViews.flat(view, P.direction(degrees) * 4.2) + P(c == 0 ? 0 : 0, 0)
        svg.line([end, h], stroke: .colour(Ink.line), width: 2.4)
        svg.line([end, h], stroke: .colour(IronWarriorsInk.iron), width: 1)
        svg.circle(h, 1.3, fill: .colour(IronWarriorsInk.darkWood), stroke: .colour(Ink.line), width: 0.7)
        svg.circle(end, 1, fill: .colour(IronWarriorsInk.ironDark))
    }

    /// The crossbar between the uprights' tops, with the leather buffer in its middle.
    static func crossbar(_ svg: inout SVG, view: SpriteView) {
        let a = IronViews.at(view, P(16.2, -50.6), z: -uprightZ), b = IronViews.at(view, P(16.2, -50.6), z: uprightZ)
        svg.line([a, b], stroke: .colour(Ink.line), width: 5.2)
        svg.line([a, b], stroke: .colour(IronWarriorsInk.paleWood), width: 3.2)
        let m = (a + b) * 0.5 + IronViews.flat(view, P(-3.4, 0))
        IronWarriorsKit.shape(&svg, [m + P(-3, -4), m + P(3, -4), m + P(3.2, 4.4), m + P(-3.2, 4.4)], fill: .colour(IronWarriorsInk.leather), width: 1.1)
        svg.path("M\(num(m.x - 1.6)),\(num(m.y - 2)) l1,0.4 M\(num(m.x - 1.6)),\(num(m.y + 1)) l1,0.4 M\(num(m.x + 0.6)),\(num(m.y - 0.6)) l1,0.4",
                 stroke: .colour(IronWarriorsInk.rope), width: 0.7)
    }

    /// From a quarter turn: each side of the frame is the side drawing
    /// foreshortened and set aside by the engine's width, the far side first;
    /// the arm, the skein and the windlass between them; and the end nearer
    /// the viewer, its crossbeam painted in the team's colour.
    static func engineQuarter(_ svg: inout SVG, view: SpriteView, pose: SpritePose, frame: Int) {
        let (c, s) = IronViews.turn(view)
        let spin = pose == .walking ? -Double(frame) * turn : 0
        let arm = armDegrees(pose, frame)
        func aside(_ z: Double, _ content: (inout SVG) -> Void) {
            svg.raw("<g transform=\"translate(\(num(-z * s)),0) scale(\(num(c)),1)\">")
            content(&svg)
            svg.raw("</g>")
        }
        let frontEnd = s > 0
        if !frontEnd { crossbeam(&svg, view: view, x: 29.2, top: -21.4, bottom: -14) }
        aside(-wheelZ) { svg in for w in wheels { wheel(&svg, at: w, degrees: spin + 12, far: true) } }
        aside(-beamZ) { svg in beam(&svg, offset: P(0, 0), far: true) }
        aside(-uprightZ) { svg in upright(&svg, offset: P(0, 0), far: true) }
        if frontEnd { crossbeam(&svg, view: view, x: -32.2, top: -21.4, bottom: -14) }
        windlassAcross(&svg, view: view, handle: crank(pose, frame))
        if pose == .fighting && frame >= 1 && frame <= 7 {
            let hook = pivot + P.direction(arm) * 28
            let from = IronViews.at(view, drum + P(0, 3.2)), to = IronViews.at(view, hook)
            svg.line([from, to], stroke: .colour(Ink.line), width: 1.6)
            svg.line([from, to], stroke: .colour(IronWarriorsInk.rope), width: 0.8)
        }
        aside(0) { svg in Self.arm(&svg, degrees: arm, loaded: loaded(pose, frame)) }
        skeinAcross(&svg, view: view)
        crossbar(&svg, view: view)
        aside(uprightZ) { svg in upright(&svg, offset: P(0, 0), far: false) }
        aside(beamZ) { svg in beam(&svg, offset: P(0, 0), far: false) }
        if pose == .fighting && frame == 9 {
            let hit = pivot + P.direction(rest) * 34 + P(2.6, -0.6)
            svg.raw("<g transform=\"translate(\(num(hit.x * c)),\(num(hit.y)))\">")
            var burst = Drawing(layer: svg.layer, rig: Rig(), phase: 0)
            burst.burst(at: P(0, 0), from: 20, to: 150, size: 0.9)
            svg.raw(burst.svg.body)
            svg.raw("</g>")
        }
        if frontEnd { crossbeam(&svg, view: view, x: 29.2, top: -21.4, bottom: -14) } else { crossbeam(&svg, view: view, x: -32.2, top: -21.4, bottom: -14) }
        aside(wheelZ) { svg in for w in wheels { wheel(&svg, at: w, degrees: spin, far: false) } }
    }

    /// A wheel seen edge on: the iron-shod tyre as an upright band, and the hub standing out from it.
    static func wheelEdgeOn(_ svg: inout SVG, at c: P, outward: Double) {
        let r = wheelRadius, half = 2.2
        IronWarriorsKit.shape(&svg, [c + P(-half, -r), c + P(half, -r), c + P(half, r), c + P(-half, r)], fill: .colour(IronWarriorsInk.wood), width: 1.2)
        svg.line([c + P(-half + 0.6, -r + 0.6), c + P(-half + 0.6, r - 0.6)], stroke: .colour(IronWarriorsInk.iron), width: 0.9)
        svg.line([c + P(half - 0.6, -r + 0.6), c + P(half - 0.6, r - 0.6)], stroke: .colour(IronWarriorsInk.iron), width: 0.9)
        IronWarriorsKit.shape(&svg, [c + P(0, -2.4), c + P(outward * 3.4, -2), c + P(outward * 3.4, 2), c + P(0, 2.4)],
                              fill: .colour(IronWarriorsInk.iron), width: 1)
    }

    /// Seen end on, from straight ahead or from behind: the wheels edge on at
    /// each side, the uprights and their crossbar with the buffer, the arm
    /// rising and falling in its own plane, the skein and the windlass across,
    /// and the crossbeam at the nearer end painted in the team's colour.
    static func engineEndOn(_ svg: inout SVG, view: SpriteView, pose: SpritePose, frame: Int) {
        let front = view == .front
        let arm = armDegrees(pose, frame)
        let line = Paint.colour(Ink.line)
        func uprights() {
            for z in [-uprightZ, uprightZ] {
                let x = IronViews.at(view, P(16, 0), z: z).x
                IronWarriorsKit.shape(&svg, [P(x - 1.8, -53.4), P(x + 1.8, -53.4), P(x + 1.8, -21), P(x - 1.8, -21)],
                                      fill: .colour(IronWarriorsInk.wood), width: 1.3)
                for y in [-38.0, -27.0] {
                    svg.line([P(x - 2, y), P(x + 2, y)], stroke: line, width: 2.2)
                    svg.line([P(x - 1.8, y), P(x + 1.8, y)], stroke: .colour(IronWarriorsInk.iron), width: 1)
                }
            }
            crossbar(&svg, view: view)
        }
        func beams() {
            // The side beams' iron-capped ends.
            for z in [-beamZ, beamZ] {
                let x = IronViews.at(view, P(0, 0), z: z).x
                IronWarriorsKit.shape(&svg, [P(x - 1.9, -21.8), P(x + 1.9, -21.8), P(x + 1.9, -13.6), P(x - 1.9, -13.6)],
                                      fill: .colour(IronWarriorsInk.iron), width: 1.1)
                svg.circle(P(x, -19.2), 0.6, fill: line)
                svg.circle(P(x, -16.2), 0.6, fill: line)
            }
        }
        func armEndOn() {
            let u = P.direction(arm)
            let start = P(0, pivot.y - u.y * 5), end = P(0, pivot.y + u.y * armLength)
            IronWarriorsKit.shape(&svg, [start + P(-2.6, 0), end + P(-1.7, 0), end + P(1.7, 0), start + P(2.6, 0)],
                                  fill: .colour(IronWarriorsInk.paleWood), width: 1.3)
            for t in [0.45, 0.8] {
                let y = pivot.y + u.y * armLength * t
                svg.line([P(-2.4, y), P(2.4, y)], stroke: line, width: 2)
                svg.line([P(-2, y), P(2, y)], stroke: .colour(IronWarriorsInk.iron), width: 0.9)
            }
            // The cup at its end, seen across: a bowl, a stone in it when loaded.
            if loaded(pose, frame) { stone(&svg, at: end + P(0, u.y < 0 ? -2.6 : 2.6)) }
            svg.ellipse(end, 4, 1.8, fill: .colour(IronWarriorsInk.iron), stroke: line, width: 1.1)
        }
        if front {
            crossbeam(&svg, view: view, x: -32.2, top: -21.4, bottom: -14)
            windlassAcross(&svg, view: view, handle: crank(pose, frame))
            armEndOn()
            skeinAcross(&svg, view: view)
            uprights()
            beams()
            crossbeam(&svg, view: view, x: 29.2, top: -21.4, bottom: -14)
        } else {
            crossbeam(&svg, view: view, x: 29.2, top: -21.4, bottom: -14)
            uprights()
            skeinAcross(&svg, view: view)
            armEndOn()
            beams()
            windlassAcross(&svg, view: view, handle: crank(pose, frame))
            crossbeam(&svg, view: view, x: -32.2, top: -21.4, bottom: -14)
        }
        // The wheels, edge on at each side: the axle's ends turn, so nothing shows of the turning.
        for z in [-wheelZ, wheelZ] {
            let x = IronViews.at(view, P(0, 0), z: z).x
            wheelEdgeOn(&svg, at: P(x, -9), outward: x < 0 ? -1 : 1)
        }
        if pose == .fighting && frame == 9 {
            var burst = Drawing(layer: svg.layer, rig: Rig(), phase: 0)
            burst.burst(at: P(0, -52), from: 20, to: 150, size: 0.9)
            svg.raw(burst.svg.body)
        }
    }
}
