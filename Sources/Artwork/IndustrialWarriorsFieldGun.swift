// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The field gun

/// A breech-loading field gun on its two-wheeled carriage, with its crew of
/// two drawn on the shared figure (the crew are part of the unit, trained
/// with it, as the cannon's are; ruled 2026-11-19), drawn as
/// `AlchemyWarriorsCannon` is, one age on.
///
/// The gun: a long steel barrel with a breech ring and a swinging breech
/// lever, sliding on a cradle over its recoil buffer; a steel shield with a
/// painted panel of the team's colour bordered in the light; a dial sight on
/// its bracket above the shield; a pole trail ending in a spade; twelve-spoked
/// wheels shod with steel; and a box of ready rounds on the ground by the trail.
/// The crew, in the rifleman's dress (bottle-green tunics, brick trousers, puttees and
/// peaked caps with the team's band): the layer, on the gun's far side,
/// clean-shaven with nose E, looks through the sight; the loader, beside the
/// breech, with a bushy moustache and nose B.
/// Standing, the crew wait by the gun; walking, the loader pushes at the
/// breech and the layer hauls on a drag rope ahead, and the
/// wheels turn with their stride; fighting, the gun fires with a flash and a cloud of
/// smoke, its barrel recoils on the cradle and runs out again, the layer lays
/// it again, and the loader swings the breech open (the spent case flying),
/// loads the next round, closes the breech and stoops to the box for another.
///
/// The gun is drawn about its axle (`axle`), and the whole picture is moved
/// by `offset` so that the origin is on the ground at the middle of what
/// stands on it: between the wheels and the trail's spade, with the crew
/// behind the breech (a breech-loader is served from behind its shield).
struct IndustrialWarriorsFieldGun: PersonLook {
    static let canvas = Canvas(minX: -54, minY: -104, width: 178, height: 110, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// How far the gun and its crew are moved so that the origin is at the
    /// middle of the ground they stand on.
    static let offset = P(28, 0)

    static let wheelRadius = 18.0
    static let axle = P(0, -18)
    /// Where the far wheel is drawn, behind and above the near one.
    static let far = P(3.6, -3.4)
    /// The wheels turn this many degrees a frame when moving: under half the 30
    /// degrees between spokes, so that they never seem to turn backward, and
    /// five spokes in the 12 frames, so that the cycle repeats without a jump.
    static let turn = 12.5
    /// The ground the gun covers in a frame of the walking pose, and the
    /// crew's stride that matches it (the approved worker's stride of 24 covers 4).
    static let groundPerFrame = wheelRadius * turn * .pi / 180
    static let pace = 24 * groundPerFrame / 4

    /// The barrel's breech (the back of the breech ring) at rest, its
    /// direction (a little elevated toward the muzzle) and its length.
    static let breech = P(-30, -40)
    static let bore = 92.0
    static let barrel = 70.0

    /// Where the box of ready rounds stands, by the trail behind the wheel.
    static let box = P(-45, 0)

    // MARK: The recoil

    /// How far the barrel has slid back along the cradle in a frame of the fight.
    static func slide(_ pose: SpritePose, _ frame: Int) -> Double {
        guard pose == .fighting else { return 0 }
        return [0, -9, -6, -2.5, -0.6, 0, 0, 0, 0, 0, 0, 0][frame]
    }

    /// How far the whole carriage has been thrown back in a frame of the fight.
    static func jump(_ pose: SpritePose, _ frame: Int) -> Double {
        guard pose == .fighting else { return 0 }
        return [0, -1.4, -1, -0.5, -0.2, 0, 0, 0, 0, 0, 0, 0][frame]
    }

    static func axes() -> (u: P, a: P) {
        let u = P.direction(bore)
        return (u, P(-u.y, u.x))
    }

    /// A point along the barrel's axis (`t` from the breech) and across it (`s`,
    /// toward its belly), with the barrel slid back by `slide` and the
    /// carriage thrown back by `jump`.
    static func onBarrel(_ t: Double, _ s: Double, slide: Double = 0, jump: Double = 0) -> P {
        let (u, a) = axes()
        return breech + u * (t + slide) + a * s + P(jump, 0)
    }

    static func muzzle(_ pose: SpritePose, _ frame: Int) -> P {
        onBarrel(barrel, 0, slide: slide(pose, frame), jump: jump(pose, frame))
    }

    /// The breech lever's handle: down and forward when the breech is closed,
    /// swung up and back when it is open.
    static func lever(open: Bool, slide: Double, jump: Double) -> P {
        open ? onBarrel(-4.6, -6.4, slide: slide, jump: jump) : onBarrel(3.4, 7.6, slide: slide, jump: jump)
    }

    // MARK: The loader's drill

    /// One frame of the loader's work: where he stands, how he leans and
    /// stands, where each hand is (nil for a hand hanging at his side), and
    /// the round he holds (its base and direction), or that he pushes home.
    struct Load {
        var at: Double
        var lean: Double
        var backLeg = Limb(-8, 5), frontLeg = Limb(10, 6)
        var near: P?
        var far: P?
        var round: (base: P, degrees: Double)?
        var open = false
        var eyes = Eyes.open
        var mouth = Mouth.firm
        var headTilt = 0.0
    }

    /// The round held across the chest, ready.
    static let ready = (base: P(-55.4, -34.4), degrees: 94.0)
    static func along(_ r: (base: P, degrees: Double), _ t: Double) -> P { r.base + P.direction(r.degrees) * t }

    static let loads: [Load] = {
        let (u, _) = axes()
        let mouth = onBarrel(0, 0)
        let atBreech = (base: mouth - u * 17, degrees: bore)
        let pushed = (base: mouth - u * 3.4, degrees: bore)
        let hip = (base: P(-50.6, -21), degrees: 150.0)
        var l: [Load] = [
            Load(at: -60, lean: 2, near: along(ready, 11.5), far: along(ready, 3.2), round: ready),
            Load(at: -60, lean: -5, near: along(ready, 11.5) + P(-1.6, 0.4), far: along(ready, 3.2) + P(-1.6, 0.4),
                 round: (base: ready.base + P(-1.6, 0.4), degrees: 96), eyes: .closed, headTilt: -6),
            Load(at: -60, lean: 0, near: along(ready, 11.5), far: along(ready, 3.2), round: ready, eyes: .wide),
            Load(at: -50, lean: 7, near: lever(open: false, slide: -2.5, jump: -0.5), far: along(hip, 5), round: hip),
            Load(at: -50, lean: 5, near: lever(open: true, slide: -0.6, jump: -0.2), far: along(hip, 5), round: hip, open: true),
            Load(at: -51, lean: 8, near: along(atBreech, 11), far: along(atBreech, 3.6), round: atBreech, open: true, headTilt: 4),
            Load(at: -51, lean: 10, near: along(pushed, -0.6), far: along(pushed, -1.4) + P(0, 2.4), round: pushed, open: true,
                 mouth: .murmur, headTilt: 4),
            Load(at: -51, lean: 7, near: lever(open: false, slide: 0, jump: 0), headTilt: 2),
            Load(at: -56, lean: 6, near: P(-46, -26), far: P(-48, -24), eyes: .down, headTilt: 8),
            Load(at: -60, lean: 16, near: P(box.x + 1.2, -18.6), far: P(box.x - 0.2, -14.6), round: (base: P(box.x + 0.6, -4.4), degrees: 178),
                 eyes: .down, headTilt: 10),
            Load(at: -58, lean: 13, near: along((base: P(-53, -27), degrees: 122), 11), far: along((base: P(-53, -27), degrees: 122), 3.4),
                 round: (base: P(-53, -27), degrees: 122), eyes: .down, headTilt: 4),
            Load(at: -60, lean: 4, near: along(ready, 11.5), far: along(ready, 3.2), round: ready),
        ]
        for i in [3, 4] { l[i].backLeg = Limb(-12, 6); l[i].frontLeg = Limb(14, 10) }
        l[5].backLeg = Limb(-16, 8); l[5].frontLeg = Limb(16, 12)
        l[6].backLeg = Limb(-26, 6); l[6].frontLeg = Limb(24, 22)
        l[7].backLeg = Limb(-16, 8); l[7].frontLeg = Limb(16, 12)
        l[9].backLeg = Limb(40, 115); l[9].frontLeg = Limb(72, 128)
        l[10].backLeg = Limb(14, 50); l[10].frontLeg = Limb(36, 70)
        return l
    }()

    // MARK: The crew's places

    static let layerAt = -27.0, walkingLayerAt = 51.0

    /// Where the drag rope is made fast, on the carriage before the axle.
    static let ropeEye = P(8, -24)
    static let walkingLoaderAt = -50.0

    // MARK: The rigs

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? { Self.loaderRig(pose, frame) }

    static func loaderRig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        var r: Rig
        switch pose {
        case .standing:
            r = Moves.standing(frame)
            r.mouth = .firm
            r.lean = 2
            let at = P(loads[0].at, 0)
            r.frontArm = IndustrialWarriorsKit.reach(r, front: true, origin: at, to: along(ready, 11.5) + P(0, -r.lift * 0.5))
            r.backArm = IndustrialWarriorsKit.reach(r, front: false, origin: at, to: along(ready, 3.2) + P(0, -r.lift * 0.5))
        case .walking:
            r = Moves.walking(frame, stride: pace)
            r.lean = 16
            r.mouth = .firm
            let at = P(walkingLoaderAt, 0)
            // Both hands on the breech, pushing.
            r.frontArm = IndustrialWarriorsKit.reach(r, front: true, origin: at, to: onBarrel(1, -1.6))
            r.backArm = IndustrialWarriorsKit.reach(r, front: false, origin: at, to: onBarrel(-0.6, 2.4))
        case .fighting:
            let s = loads[frame]
            r = Moves.standing(frame == 0 || frame == 11 ? frame : 0)
            r.lean = s.lean
            r.backLeg = s.backLeg; r.frontLeg = s.frontLeg
            r.eyes = s.eyes; r.mouth = s.mouth; r.headTilt = s.headTilt
            let at = P(s.at, 0)
            if let near = s.near { r.frontArm = IndustrialWarriorsKit.reach(r, front: true, origin: at, to: near) }
            if let far = s.far { r.backArm = IndustrialWarriorsKit.reach(r, front: false, origin: at, to: far) }
        default:
            return nil
        }
        return r
    }

    static func layerRig(_ pose: SpritePose, _ frame: Int) -> (rig: Rig, at: P) {
        var r: Rig
        switch pose {
        case .walking:
            r = Moves.walking(frame, stride: pace)
            r.lean = 11
            r.mouth = .firm
            // Ahead of the gun, hauling on the drag rope over his shoulder.
            r.backArm = BronzePeopleKit.reach(IronWarriorsKit.backShoulder(r), P(2, -42))
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), P(3.4, -40))
            return (r, P(walkingLayerAt, 0))
        case .fighting:
            r = Moves.standing(frame)
            r.backLeg = Limb(-12, 6); r.frontLeg = Limb(12, 8)
            r.lean = frame == 1 ? 7 : 12
            r.headTilt = frame == 1 ? -4 : 2
            r.eyes = frame == 1 ? .closed : .open
            r.mouth = frame == 1 ? .firm : (frame == 10 ? .murmur : .firm)
            let at = P(layerAt, 0)
            // Laying the gun again after the shot: a hand on the sight's drum, turning it.
            let turnHand = frame >= 3 ? P(0.4 * sin(Double(frame) * 1.6), 0.5 * cos(Double(frame) * 1.6)) : P(0, 0)
            r.frontArm = IndustrialWarriorsKit.reach(r, front: true, origin: at, to: P(-8, -60.6) + turnHand)
            r.backArm = IndustrialWarriorsKit.reach(r, front: false, origin: at, to: P(-17, -40))
            return (r, at)
        default:
            r = Moves.standing((frame + 4) % 12)
            r.backLeg = Limb(-6, 4); r.frontLeg = Limb(7, 4)
            r.lean = 6
            r.mouth = .firm
            let at = P(layerAt, 0)
            r.frontArm = IndustrialWarriorsKit.reach(r, front: true, origin: at, to: P(-14, -42 - r.lift * 0.4))
            return (r, at)
        }
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let layer = d.svg.layer, phase = d.phase
        let slide = Self.slide(pose, frame), jump = Self.jump(pose, frame)
        // The wheels roll with the gun: forward as it moves, back as it is thrown.
        let spin = (pose == .walking ? -Double(frame) * Self.turn : 0) - jump / Self.wheelRadius * 180 / .pi
        d.svg.group(at: Self.offset) { svg in
            svg.ellipse(P(-28, 0.2), 50, 4.2, fill: .colour("#000000"), opacity: 0.13)

            // The layer, on the gun's far side: behind it, or ahead of it hauling.
            let (layerRig, layerAt) = Self.layerRig(pose, frame)
            var layerDrawing = Drawing(layer: layer, rig: layerRig, phase: phase)
            Self.drawLayer(&layerDrawing, pose, frame)
            let layerBody = layerDrawing.svg.body
            if pose == .walking {
                // The drag rope, from its eye on the carriage to his hand at his shoulder.
                let hand = layerDrawing.world(layerDrawing.joints.backHand) + layerAt
                var rope = PathData()
                rope.move(Self.ropeEye + P(Self.far.x, 0)); rope.quad(P((Self.ropeEye.x + hand.x) / 2, -27), hand)
                svg.path(rope, stroke: .colour(Ink.line), width: 1.7)
                svg.path(rope, stroke: .colour(IndustrialWarriorsInk.paleBuff), width: 0.8)
            }
            svg.group(at: layerAt) { $0.raw(layerBody) }

            // The gun.
            svg.group(at: P(jump, 0)) { svg in
                Self.wheel(&svg, at: Self.axle + Self.far, degrees: spin + 7, far: true)
                Self.trail(&svg)
            }
            if pose != .walking { Self.ammunition(&svg, taken: pose == .fighting && frame == 9) }
            svg.group(at: P(jump, 0)) { svg in
                Self.cradle(&svg)
                Self.barrel(&svg, slide: slide, open: pose == .fighting && (4...6).contains(frame))
                Self.shield(&svg)
                Self.sight(&svg)
                Self.wheel(&svg, at: Self.axle, degrees: spin, far: false)
            }
            if pose == .fighting {
                Self.shot(&svg, frame: frame)
                if frame == 1 { BronzePeopleProps.dust(&svg, at: P(-70, -1.4), size: 1, opacity: 0.45) }
            }

            // The loader, on the near side by the breech.
            if let r = Self.loaderRig(pose, frame) {
                var crew = Drawing(layer: layer, rig: r, phase: phase)
                let at = pose == .walking ? Self.walkingLoaderAt : (pose == .fighting ? Self.loads[frame].at : Self.loads[0].at)
                Self.drawLoader(&crew, pose, frame, at: P(at, 0))
                let body = crew.svg.body
                svg.group(at: P(at, 0)) { $0.raw(body) }
            }
            if pose == .fighting {
                // The spent case thrown back from the opened breech.
                let mouth = Self.onBarrel(0, 0)
                if frame == 4 { IndustrialWarriorsKit.spentCase(&svg, at: mouth + P(-7, 1.4), degrees: 4, length: 11, width: 3.2) }
                if frame == 5 { IndustrialWarriorsKit.spentCase(&svg, at: mouth + P(-11, 15), degrees: 64, length: 11, width: 3.2) }
            }
        }
    }

    // MARK: The gun's parts

    /// A twelve-spoked wheel of wood shod with steel, turned by `degrees`.
    static func wheel(_ svg: inout SVG, at c: P, degrees: Double, far: Bool) {
        IndustrialWarriorsKit.wheel(&svg, at: c, radius: wheelRadius, degrees: degrees, spokes: 12,
                                    spoke: far ? IndustrialWarriorsInk.darkWood : IndustrialWarriorsInk.wood,
                                    felloe: far ? IndustrialWarriorsInk.darkWood : IndustrialWarriorsInk.wood,
                                    tyre: far ? IndustrialWarriorsInk.steelDark : IndustrialWarriorsInk.steel, tyreWidth: 2.2, far: far)
    }

    /// The pole trail, from the carriage behind the axle down to the spade.
    static func trail(_ svg: inout SVG) {
        let trail = [P(-6, -36), P(4, -28), P(2, -20), P(-62, -3.6), P(-66.6, -5.6), P(-66, -9), P(-12, -33)]
        IndustrialWarriorsKit.shape(&svg, trail, fill: .colour(IndustrialWarriorsInk.plateDark), width: 1.3)
        svg.line([P(-8, -31.6), P(-62, -6.6)], stroke: .colour(IndustrialWarriorsInk.plate), width: 1.1)
        // Rivets along the trail.
        for i in 0..<5 {
            let p = P(-16 - Double(i) * 10.4, -26.4 + Double(i) * 4.6)
            svg.circle(p, 0.55, fill: .colour(IndustrialWarriorsInk.plateLight))
        }
        // The spade, dug into the ground, and the trail's eye.
        IndustrialWarriorsKit.shape(&svg, [P(-69.6, -8.4), P(-64, -7.2), P(-64.4, -0.6), P(-67.6, 0.2), P(-70.4, -1)],
                                    fill: .colour(IndustrialWarriorsInk.steelDark), width: 1.1)
        svg.circle(P(-58.6, -9.6), 1.6, fill: .none, stroke: .colour(Ink.line), width: 1)
    }

    /// The cradle the barrel slides on, the recoil buffer beneath it, the
    /// saddle carrying both on the axle, and the trunnion.
    static func cradle(_ svg: inout SVG) {
        func at(_ t: Double, _ s: Double) -> P { onBarrel(t, s) }
        // The saddle down to the axle.
        IndustrialWarriorsKit.shape(&svg, [P(-14, -36), P(9, -37), P(6, -20), P(-6, -19)], fill: .colour(IndustrialWarriorsInk.plateDark), width: 1.1)
        // The recoil buffer: a long cylinder under the barrel, its front capped.
        IndustrialWarriorsKit.shape(&svg, [at(6, 3.2), at(43, 3.2), at(44, 4.4), at(43, 8.4), at(6, 8.4)], fill: .colour(IndustrialWarriorsInk.steelDark), width: 1.1)
        svg.line([at(7, 4.4), at(42, 4.4)], stroke: .colour(IndustrialWarriorsInk.steel), width: 0.9)
        for t in [14.0, 30.0] { svg.line([at(t, 3.2), at(t, 8.4)], stroke: .colour(Ink.line), width: 0.7) }
        // The trunnion.
        let trunnion = P(-2, -36)
        svg.circle(trunnion + P(-0.4, 0.4), 2.8, fill: .colour(IndustrialWarriorsInk.steel))
        svg.circle(trunnion, 2.8, fill: .none, stroke: .colour(Ink.line), width: 1)
        svg.circle(trunnion, 1, fill: .colour(Ink.line))
    }

    /// The barrel: the breech ring with its lever, and the long tube tapering
    /// to the muzzle, slid back by `slide`; the breech shows its dark mouth when open.
    static func barrel(_ svg: inout SVG, slide: Double, open: Bool) {
        func at(_ t: Double, _ s: Double) -> P { onBarrel(t, s, slide: slide) }
        let profile: [(Double, Double)] = [(0, 4.2), (8, 4.2), (8.6, 3.2), (24, 2.9), (barrel - 2.6, 2.3), (barrel - 2, 2.8), (barrel, 2.8)]
        let outline = profile.map { at($0.0, -$0.1) } + profile.reversed().map { at($0.0, $0.1) }
        IndustrialWarriorsKit.shape(&svg, outline, fill: .colour(IndustrialWarriorsInk.steel), width: 1.4)
        svg.line([at(9, -2), at(barrel - 3, -1.5)], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 1)
        svg.line([at(9, 2), at(barrel - 3, 1.6)], stroke: .colour(Ink.line), width: 0.8, opacity: 0.35)
        // The breech ring's seams and a band forward.
        svg.line([at(8, -4.2), at(8, 4.2)], stroke: .colour(Ink.line), width: 0.9)
        svg.line([at(2.4, -4.2), at(2.4, 4.2)], stroke: .colour(IndustrialWarriorsInk.steelDark), width: 0.7)
        svg.line([at(22, -2.9), at(22, 2.9)], stroke: .colour(Ink.line), width: 0.7)
        // The muzzle's mouth.
        svg.line([at(barrel, -1.4), at(barrel, 1.4)], stroke: .colour(Ink.line), width: 1.6)
        if open {
            // The breech block swung aside: the bore's dark mouth at the breech.
            svg.ellipse(at(0, 0), 1.2, 2.6, fill: .colour(Ink.line))
        }
        // The lever, from its pivot on the ring to its handle.
        let pivot = at(1.6, 2.6)
        let handle = lever(open: open, slide: slide, jump: 0)
        svg.line([pivot, handle], stroke: .colour(Ink.line), width: 2.1)
        svg.line([pivot, handle], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 0.8)
        svg.circle(handle, 1.2, fill: .colour(IndustrialWarriorsInk.darkWood), stroke: .colour(Ink.line), width: 0.6)
        svg.circle(pivot, 1, fill: .colour(IndustrialWarriorsInk.steelDark), stroke: .colour(Ink.line), width: 0.5)
    }

    /// The shield: a plate of grey steel standing across the gun, seen a little
    /// from the front, its edge turned back, with a panel of the team's colour
    /// bordered in the light above the barrel and rivets round its rim.
    static func shield(_ svg: inout SVG) {
        let face = [P(0, -64), P(14, -66), P(15, -23), P(1, -20)]
        // The edge, turned back toward the breech.
        IndustrialWarriorsKit.shape(&svg, [P(-3, -62.6), P(0, -64), P(1, -20), P(-1.8, -20.6)], fill: .colour(IndustrialWarriorsInk.plateDark), width: 1.1)
        IndustrialWarriorsKit.shape(&svg, face, fill: .colour(IndustrialWarriorsInk.plate), width: 1.4)
        // The panel, bordered in the light.
        let border = [P(2.4, -61), P(12.4, -62.6), P(12.7, -48), P(2.7, -46.4)]
        svg.polygon(border, fill: .colour(IndustrialWarriorsInk.light))
        let panel = [P(3.6, -59.7), P(11.2, -61), P(11.4, -49.3), P(3.8, -48)]
        svg.polygon(panel.map { $0 + P(-0.4, 0.4) }, fill: .team)
        svg.polygon(panel, fill: .none, stroke: .colour(Ink.line), width: 0.6)
        svg.polygon(border, fill: .none, stroke: .colour(Ink.line), width: 0.7)
        // Rivets round the rim and the light along the top edge.
        var rivets: [P] = []
        for i in 0..<7 { rivets.append(P(1.6, -61.6) + (P(2.2, -22.4) - P(1.6, -61.6)) * (Double(i) / 6)) }
        for i in 0..<7 { rivets.append(P(13.4, -63.6) + (P(14.2, -25) - P(13.4, -63.6)) * (Double(i) / 6)) }
        for p in rivets { svg.circle(p, 0.5, fill: .colour(IndustrialWarriorsInk.plateDark)) }
        svg.line([P(1, -63), P(13.4, -64.8)], stroke: .colour(IndustrialWarriorsInk.plateLight), width: 0.8)
        // The slot the barrel passes through.
        svg.polygon([P(2.4, -44.8), P(13.4, -45.8), P(13.6, -38.6), P(2.6, -37.6)], fill: .colour(IndustrialWarriorsInk.plateDark), stroke: .colour(Ink.line), width: 0.6)
    }

    /// The dial sight on its bracket, rising from the cradle above the shield's edge.
    static func sight(_ svg: inout SVG) {
        svg.line([P(-14, -42), P(-6.6, -63)], stroke: .colour(Ink.line), width: 2.2)
        svg.line([P(-14, -42), P(-6.6, -63)], stroke: .colour(IndustrialWarriorsInk.steelDark), width: 1)
        IndustrialWarriorsKit.shape(&svg, [P(-10.6, -68.2), P(-0.6, -68.8), P(-0.4, -66), P(-10.4, -65.4)], fill: .colour(IndustrialWarriorsInk.steel), width: 0.8)
        svg.line([P(-10.8, -68.6), P(-10.8, -65)], stroke: .colour(Ink.line), width: 1.2)
        svg.circle(P(-8, -60.6), 1.7, fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.6)
    }

    /// The box of ready rounds, its lid thrown open, by the trail; one round fewer whilst one is taken out.
    static func ammunition(_ svg: inout SVG, taken: Bool) {
        let x = box.x
        // The rounds standing in the box, their noses showing.
        for (i, dx) in [-2.6, 0.6, 3.8].enumerated() where !(taken && i == 1) {
            round(&svg, base: P(x + dx, -4), degrees: 180, visible: 14.6)
        }
        IndustrialWarriorsKit.shape(&svg, [P(x - 5.4, -11), P(x + 6, -11), P(x + 6, 0), P(x - 5.4, 0)], fill: .colour(IndustrialWarriorsInk.wood), width: 1.1)
        svg.line([P(x - 5, -6), P(x + 5.6, -6)], stroke: .colour(IndustrialWarriorsInk.darkWood), width: 0.8)
        svg.polygon([P(x - 1.4, -9), P(x + 2, -9), P(x + 2, -7.6), P(x - 1.4, -7.6)], fill: .colour(IndustrialWarriorsInk.light), stroke: .colour(Ink.line), width: 0.4)
        // The lid, hinged at the back and thrown open.
        IndustrialWarriorsKit.shape(&svg, [P(x - 5.4, -11), P(x - 9.6, -18.6), P(x - 8.4, -19.4), P(x - 4.2, -11.6)], fill: .colour(IndustrialWarriorsInk.darkWood), width: 0.9)
    }

    /// A round: a brass case and a grey shell with a brick driving band and a
    /// brass fuze, from its base along `degrees`; only the first `visible`
    /// units are drawn (the rest is in the breech or the box).
    static func round(_ svg: inout SVG, base: P, degrees: Double, visible: Double = 17) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        func at(_ t: Double, _ s: Double) -> P { base + u * min(t, visible) + a * s }
        let w = 1.7
        if visible > 0.5 {
            IndustrialWarriorsKit.shape(&svg, [at(0, -w - 0.4), at(0.8, -w - 0.4), at(0.8, -w), at(9.4, -w), at(9.4, w), at(0.8, w), at(0.8, w + 0.4), at(0, w + 0.4)],
                                        fill: .colour(IndustrialWarriorsInk.brass), width: 0.7)
        }
        if visible > 9.4 {
            IndustrialWarriorsKit.shape(&svg, [at(9.4, -w), at(13, -w), at(15.6, -0.9), at(17, 0), at(15.6, 0.9), at(13, w), at(9.4, w)],
                                        fill: .colour(IndustrialWarriorsInk.plate), width: 0.7)
            svg.line([at(10.2, -w), at(10.2, w)], stroke: .colour(IndustrialWarriorsInk.brick), width: 0.9)
            if visible >= 15.6 {
                svg.polygon([at(15.4, -0.9), at(17, 0), at(15.4, 0.9)], fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.4)
            }
        }
    }

    // MARK: The shot

    /// The flash at the muzzle, and the cloud of smoke and dust that rolls
    /// forward, rises and thins whilst the crew load.
    static func shot(_ svg: inout SVG, frame: Int) {
        let origin = muzzle(.fighting, 0) + axes().u * 2
        if frame == 1 {
            IndustrialWarriorsKit.flash(&svg, at: muzzle(.fighting, 1) + axes().u * 2.4, degrees: bore, length: 26, girth: 7, points: 14)
        }
        let ages: [Int: (spread: Double, rise: Double, size: Double, opacity: Double)] = [
            1: (0.3, 0, 0.7, 0.95), 2: (0.62, 2, 1.1, 0.92), 3: (0.8, 5, 1.25, 0.82), 4: (0.9, 8.5, 1.32, 0.66),
            5: (0.95, 12, 1.35, 0.48), 6: (0.98, 15, 1.34, 0.32), 7: (1, 17.5, 1.3, 0.18),
        ]
        guard let age = ages[frame] else { return }
        let base: [(P, Double)] = [(P(5, 0), 4.4), (P(12, -2.6), 5.8), (P(20, 0.6), 6.4), (P(28, -4), 6), (P(35, 1), 5), (P(18, -8.6), 5),
                                   (P(27, 4), 4.2), (P(40, -4), 4.4)]
        let puffs = base.map { (p, r) in (P(p.x * age.spread, p.y * (0.7 + age.spread * 0.3) - age.rise * (0.5 + p.x / 50)), r * age.size) }
        IndustrialWarriorsKit.smoke(&svg, at: origin, puffs: puffs, opacity: age.opacity)
    }

    // MARK: The crew

    /// One of the crew in the rifleman's dress, with what he holds drawn by
    /// `held` in the picture's units between his body and his near arm.
    /// In `shirt` sleeves, he has put off his tunic to serve the gun: a linen
    /// shirt with its sleeves rolled to the elbow, and soot braces.
    static func soldier(_ d: inout Drawing, swing: Double, nose: Nose, shirt: Bool = false, held: (inout Drawing) -> Void = { _ in },
                        hair: (inout Drawing) -> Void, features: (inout Drawing) -> Void, brow: (inout Drawing) -> Void) {
        d.figure { d in
            if shirt {
                shirtSleeve(&d, front: false)
            } else {
                IndustrialWarriorsKit.sleeve(&d, front: false, colour: IndustrialWarriorsInk.darkGreen, cuff: IndustrialWarriorsInk.darkBrick)
            }
            IndustrialWarriorsKit.legs(&d, trousers: IndustrialWarriorsInk.brick, darkTrousers: IndustrialWarriorsInk.darkBrick)
            if shirt {
                d.garment(colour: [P(-12.4, -46.4), P(9.6, -48.2), P(12, -36), P(11.4, -26.4), P(-13.4, -26)],
                          outline: [P(-9.2, -47.4), P(9.2, -47.4), P(11.4, -36.4), P(10.8, -27), P(-12.6, -27)],
                          fill: .colour(IndustrialWarriorsInk.linen)) { d in
                    // The folds of the shirt, its placket and buttons.
                    d.svg.line([d.up(P(7.4, -46.6)), d.up(P(8.4, -31))], stroke: .colour(IndustrialWarriorsInk.smokeShade), width: 0.9)
                    d.svg.path("M-6,-40 q2,4 1,9 M2,-38 q1.4,3 0.6,6", stroke: .colour(IndustrialWarriorsInk.smokeShade), width: 0.8)
                    for i in 0..<3 { d.svg.circle(d.up(P(7.8 + Double(i) * 0.2, -44 + Double(i) * 4.4)), 0.5, fill: .colour(IndustrialWarriorsInk.paleSoot)) }
                }
                // The seat of the trousers, from the waist to the legs, and the braces.
                IndustrialWarriorsKit.shape(&d.svg, [d.up(P(-11.6, -28.4)), d.up(P(10.6, -28.6)), P(9.2, -19), P(6.4, -14.6), P(-5.2, -14.6), P(-10.8, -19)],
                                            fill: .colour(IndustrialWarriorsInk.brick), width: 1.1)
                d.svg.line([P(0.6, -27), P(0.4, -15.4)], stroke: .colour(IndustrialWarriorsInk.darkBrick), width: 0.8)
                d.svg.path("M5.4,-26.6 q1.6,3 4.4,3.4", stroke: .colour(IndustrialWarriorsInk.darkBrick), width: 0.8)
                for (top, bottom) in [(P(6, -47.4), P(5.6, -28.4)), (P(-4.6, -47.2), P(-7.4, -28.2))] {
                    let a = d.up(top), b = d.up(bottom)
                    IndustrialWarriorsKit.shape(&d.svg, [a + P(-1, 0), a + P(1, 0), b + P(1, 0), b + P(-1, 0)], fill: .colour(IndustrialWarriorsInk.darkSoot), width: 0.6)
                    d.svg.circle(b + P(0, -0.6), 0.5, fill: .colour(IndustrialWarriorsInk.brass))
                }
                // The collar, open at the throat.
                IndustrialWarriorsKit.shape(&d.svg, [d.up(P(-6, -49.4)), d.up(P(8, -49.6)), d.up(P(9.4, -46)), d.up(P(5.4, -45.6)), d.up(P(3, -47.4)), d.up(P(-6.4, -46.4))],
                                            fill: .colour(IndustrialWarriorsInk.linen), width: 0.9)
                IndustrialWarriorsKit.belt(&d)
            } else {
                IndustrialWarriorsKit.tunic(&d, colour: IndustrialWarriorsInk.green, dark: IndustrialWarriorsInk.darkGreen, pale: IndustrialWarriorsInk.paleGreen,
                                            collar: IndustrialWarriorsInk.brick, swing: swing)
                IndustrialWarriorsKit.belt(&d)
            }
            held(&d)
            if shirt {
                shirtSleeve(&d, front: true)
            } else {
                IndustrialWarriorsKit.sleeve(&d, front: true, colour: IndustrialWarriorsInk.green, cuff: IndustrialWarriorsInk.brick)
            }
            d.head(nose: nose, hair: hair, features: features, brow: brow, over: { d in IndustrialWarriorsKit.peakedCap(&d.svg) })
        }
    }

    /// An arm in a linen sleeve rolled to the elbow, the bare forearm, and the hand.
    static func shirtSleeve(_ d: inout Drawing, front: Bool) {
        let j = d.joints
        let shoulder = front ? j.frontShoulder : j.backShoulder, elbow = front ? j.frontElbow : j.backElbow, hand = front ? j.frontHand : j.backHand
        shirtSleeve(&d, [shoulder, elbow, hand], front: front)
    }

    /// The same sleeve through the shoulder, elbow and hand given on the screen, as an arm in another view has them.
    static func shirtSleeve(_ d: inout Drawing, _ points: [P], front: Bool) {
        let shoulder = points[0], elbow = points[1], hand = points[2]
        let u = P.direction(BronzePeopleKit.degrees(from: elbow, to: hand))
        let roll = elbow + u * 1.2
        d.svg.line([elbow, hand], stroke: .colour(Ink.line), width: 3.1)
        d.svg.line([elbow + u * 0.4, hand - u * 0.4], stroke: .colour(front ? Ink.skin : Ink.cheek), width: 1.6)
        d.svg.line([shoulder, elbow, roll], stroke: .colour(Ink.line), width: 4.8)
        d.svg.line([shoulder, elbow, roll], stroke: .colour(front ? IndustrialWarriorsInk.linen : IndustrialWarriorsInk.smokeShade), width: 3.2)
        let a = P(-u.y, u.x)
        IndustrialWarriorsKit.shape(&d.svg, [roll + a * 2.3 - u * 1.4, roll + a * 2.3 + u * 0.6, roll - a * 2.3 + u * 0.6, roll - a * 2.3 - u * 1.4],
                                    fill: .colour(front ? IndustrialWarriorsInk.linen : IndustrialWarriorsInk.smokeShade), width: 0.8)
        d.hand(hand)
    }

    /// The layer: clean-shaven, nose E, peering through the sight.
    static func drawLayer(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        soldier(&d, swing: pose == .walking ? d.rig.sway : 0, nose: .line, hair: { d in
            d.svg.path("M-11,-61.6 C-11.6,-58 -11.2,-55.4 -10,-53.4 L-8.6,-56 C-8.8,-58.6 -8.6,-60.8 -7.8,-62.8 Z", fill: .colour(IndustrialWarriorsInk.wood))
        }, features: { d in
            // A cleft chin.
            d.svg.path("M8.6,-48.4 q0.6,-0.8 0.2,-1.8", stroke: .colour(Ink.line), width: 0.6, opacity: 0.7)
        }, brow: { d in
            d.svg.path("M2,-63.4 q3,-1.2 6.4,-0.2", stroke: .colour(Ink.line), width: 1.4)
        })
    }

    /// The loader: a bushy moustache, nose B, and the round in his hands.
    static func drawLoader(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at origin: P) {
        let worldOpen = IndustrialWarriorsKit.worldOpen(d)
        let fight = pose == .fighting ? loads[frame] : nil
        let slide = Self.slide(pose, frame)
        func own(_ p: P) -> P { p - origin }
        let farHand = d.world(d.joints.backHand)
        soldier(&d, swing: pose == .walking ? d.rig.sway : 0, nose: .button, shirt: true, held: { d in
            d.svg.raw(worldOpen)
            if pose == .standing {
                round(&d.svg, base: own(ready.base) + P(0, -d.rig.lift * 0.5), degrees: ready.degrees)
                d.hand(farHand)
            } else if let s = fight, let r = s.round {
                // In the breech, only the part outside it shows.
                let mouth = onBarrel(0, 0, slide: slide)
                let inside = frame == 6 ? BronzePeopleKit.length(mouth - r.base) : 17
                round(&d.svg, base: own(r.base), degrees: r.degrees, visible: inside)
                if s.far != nil { d.hand(farHand) }
            }
            d.svg.raw("</g>")
        }, hair: { d in
            d.svg.path("M-11,-61.6 C-11.6,-58 -11.2,-55.4 -10,-53.4 L-8.6,-56 C-8.8,-58.6 -8.6,-60.8 -7.8,-62.8 Z", fill: .colour(IndustrialWarriorsInk.hair))
        }, features: { d in
            d.svg.path("M3.6,-53.8 q3.6,-2.6 8.6,-0.8 q0.6,2.8 -1.4,3.2 q-2.6,-1.4 -4.6,-0.6 q-2,-0.2 -2.6,-1.8 Z",
                       fill: .colour(IndustrialWarriorsInk.hair), stroke: .colour(Ink.line), width: 0.5)
        }, brow: { d in
            d.svg.path("M1.2,-63.6 q3.4,-2 7.4,-0.8", stroke: .colour(Ink.line), width: 1.9)
        })
    }
}

// MARK: - The field gun in the other views

extension IndustrialWarriorsFieldGun {
    /// Half the distance between the wheels, across the gun.
    static let track = 13.0
    /// Where the crew stand across the gun in the other views: the loader on
    /// the near side, the layer on the far side, and the layer hauling ahead of
    /// the gun a little out to its far side; seen from straight ahead or
    /// behind, out beside the wheels, so that neither hides the gun.
    static func sides(_ view: SpriteView) -> (loader: Double, layer: Double, hauling: Double) {
        view == .front || view == .back ? (19, -19, -19) : (9, -9, -15)
    }
    /// Where the box of ready rounds stands across the gun.
    static let boxSide = 9.0

    /// A frame in a view other than the side, after `CarViews`: the gun turned
    /// as the figure is turned, the wheels and the shield standing across it,
    /// the barrel and the trail along it (seen end on from straight ahead or
    /// behind), and the crew drawn by the figure kit in the same view, each
    /// part drawn farthest first.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let layer = d.svg.layer, phase = d.phase, view = d.view
        let yaw = view.yaw * .pi / 180, c = cos(yaw), s = sin(yaw)
        let endOn = abs(c) < 0.3
        let ahead = view == .front || view == .frontQuarter
        let slide = Self.slide(pose, frame), jump = Self.jump(pose, frame)
        let spin = (pose == .walking ? -Double(frame) * Self.turn : 0) - jump / Self.wheelRadius * 180 / .pi
        /// A point of the gun's space (x along it as the side drawing has it, before the picture's offset; z across) on the screen.
        func at(_ x: Double, _ y: Double, _ z: Double) -> P { P((x + Self.offset.x) * c - z * s, y) }
        func depth(_ x: Double, _ z: Double) -> Double { (x + Self.offset.x) * s + z * c }
        /// The side drawing of a part that lies along the gun's middle, foreshortened.
        func along(_ svg: inout SVG, shift: Double = 0, z: Double = 0, _ content: (inout SVG) -> Void) {
            svg.raw("<g transform=\"translate(\(num(-z * s)),0) matrix(\(num(c)) 0 0 1 0 0) translate(\(num(Self.offset.x + shift)),0)\">")
            content(&svg)
            svg.raw("</g>")
        }
        let ink = Paint.colour(Ink.line)

        // The shadow, as long as the gun shows and as wide.
        d.svg.ellipse(P(0, 0.2), abs(54 * c) + abs(Self.track * s) + 6, 4.2, fill: .colour("#000000"), opacity: 0.13)

        var items: [(depth: Double, draw: (inout SVG) -> Void)] = []
        // The wheels: the side's wheel foreshortened, or seen end on.
        for z in [-Self.track, Self.track] {
            let far = depth(0, z) < depth(0, -z)
            items.append((depth(Self.axle.x + jump, z), { svg in
                if endOn {
                    let p = at(Self.axle.x + jump, Self.axle.y, z), r = Self.wheelRadius, half = 2.2
                    svg.polygon([p + P(-half, -r), p + P(half, -r), p + P(half, r), p + P(-half, r)], fill: .colour(IndustrialWarriorsInk.steel), stroke: ink, width: 1.2)
                    svg.line([p + P(-half + 0.8, -r + 2), p + P(-half + 0.8, r - 2)], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 0.6, opacity: 0.8)
                    svg.ellipse(p, 3, 3.6, fill: .colour(IndustrialWarriorsInk.wood), stroke: ink, width: 1)
                    svg.circle(p, 1.4, fill: .colour(IndustrialWarriorsInk.brass), stroke: ink, width: 0.6)
                } else {
                    along(&svg, shift: jump, z: z) { svg in Self.wheel(&svg, at: Self.axle, degrees: spin + (z < 0 ? 7 : 0), far: far) }
                }
            }))
        }
        // The axle between them.
        items.append((depth(0, 0) - 0.5, { svg in
            svg.line([at(Self.axle.x + jump, Self.axle.y, -Self.track), at(Self.axle.x + jump, Self.axle.y, Self.track)], stroke: ink, width: 3)
            svg.line([at(Self.axle.x + jump, Self.axle.y, -Self.track), at(Self.axle.x + jump, Self.axle.y, Self.track)],
                     stroke: .colour(IndustrialWarriorsInk.steelDark), width: 1.6)
        }))
        // The trail along the ground behind, to its spade.
        items.append((depth(-36, 0), { svg in
            if endOn {
                let top = at(-6 + jump, -33, 0), foot = at(-64 + jump, -6, 0)
                if !ahead {
                    IndustrialWarriorsKit.shape(&svg, [top + P(-3, 0), top + P(3, 0), P(foot.x + 2.4, -6), P(foot.x - 2.4, -6)], fill: .colour(IndustrialWarriorsInk.plateDark),
                                                width: 1.3)
                    svg.line([top + P(-1, 1), P(foot.x - 1, -7)], stroke: .colour(IndustrialWarriorsInk.plate), width: 1)
                    IndustrialWarriorsKit.shape(&svg, [P(foot.x - 4, -8.4), P(foot.x + 4, -8.4), P(foot.x + 3.6, 0), P(foot.x - 3.6, 0)],
                                                fill: .colour(IndustrialWarriorsInk.steelDark), width: 1.1)
                } else {
                    IndustrialWarriorsKit.shape(&svg, [P(top.x - 2, -22), P(top.x + 2, -22), P(foot.x + 1.6, -4), P(foot.x - 1.6, -4)],
                                                fill: .colour(IndustrialWarriorsInk.plateDark), width: 1.1)
                }
            } else {
                along(&svg, shift: jump) { svg in Self.trail(&svg) }
            }
        }))
        // The box of ready rounds by the trail.
        if pose != .walking {
            items.append((depth(Self.box.x, Self.boxSide), { svg in
                let p = at(Self.box.x, 0, Self.boxSide)
                svg.raw("<g transform=\"translate(\(num(p.x)),0) scale(\(num(max(abs(c), 0.6))),1) translate(\(num(-Self.box.x - Self.offset.x)),0)\">")
                svg.raw("<g transform=\"translate(\(num(Self.offset.x)),0)\">")
                Self.ammunition(&svg, taken: pose == .fighting && frame == 9)
                svg.raw("</g></g>")
            }))
        }
        // The cradle, the barrel behind the shield and the sight.
        items.append((depth(-12, 0), { svg in
            if endOn {
                if ahead {
                    // From ahead only the sight shows, over the shield's top.
                    let p = at(-8, -66.6, -4)
                    IndustrialWarriorsKit.shape(&svg, [p + P(-2.4, -1.6), p + P(2.4, -1.6), p + P(2.4, 1.6), p + P(-2.4, 1.6)],
                                                fill: .colour(IndustrialWarriorsInk.steel), width: 0.8)
                } else {
                    // From behind: the saddle, the buffer under the barrel, the breech ring and its lever, the sight on its bracket.
                    let b = at(jump + slide, Self.breech.y, 0)
                    IndustrialWarriorsKit.shape(&svg, [P(b.x - 5, -37), P(b.x + 5, -37), P(b.x + 4, -20), P(b.x - 4, -20)],
                                                fill: .colour(IndustrialWarriorsInk.plateDark), width: 1.1)
                    svg.circle(b + P(0, 7.4), 3, fill: .colour(IndustrialWarriorsInk.steelDark), stroke: ink, width: 1.1)
                    svg.circle(b + P(-0.4, 0.4), 4.2, fill: .colour(IndustrialWarriorsInk.steel))
                    svg.circle(b, 4.2, fill: .none, stroke: ink, width: 1.4)
                    let open = pose == .fighting && (4...6).contains(frame)
                    svg.circle(b, 1.6, fill: open ? ink : .colour(IndustrialWarriorsInk.steelDark))
                    let handle = b + (open ? P(5.4, -4) : P(-2, 6.6))
                    svg.line([b + P(-1.4, 2.2), handle], stroke: ink, width: 2.1)
                    svg.line([b + P(-1.4, 2.2), handle], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 0.8)
                    svg.circle(handle, 1.2, fill: .colour(IndustrialWarriorsInk.darkWood), stroke: ink, width: 0.6)
                    let sight = at(-8, -60, -4)
                    svg.line([P(sight.x, -42), sight + P(0, -4)], stroke: ink, width: 2.2)
                    svg.line([P(sight.x, -42), sight + P(0, -4)], stroke: .colour(IndustrialWarriorsInk.steelDark), width: 1)
                    IndustrialWarriorsKit.shape(&svg, [sight + P(-2.4, -8.2), sight + P(2.4, -8.2), sight + P(2.4, -5.4), sight + P(-2.4, -5.4)],
                                                fill: .colour(IndustrialWarriorsInk.steel), width: 0.8)
                    svg.circle(sight, 1.7, fill: .colour(IndustrialWarriorsInk.brass), stroke: ink, width: 0.6)
                }
            } else {
                along(&svg, shift: jump) { svg in
                    Self.cradle(&svg)
                    Self.barrelPart(&svg, slide: slide, from: 0, to: 37, open: pose == .fighting && (4...6).contains(frame))
                    Self.sight(&svg)
                }
            }
        }))
        // The shield across the gun: its painted face toward the front, its plain back behind.
        items.append((depth(7, 0), { svg in Self.shieldInView(&svg, view: view, at: { y, z in at(7 + jump, y, z) }, edge: { y, z in at(4 + jump, y, z) }) }))
        // The barrel ahead of the shield, or its muzzle seen end on.
        items.append((depth(24, 0), { svg in
            if endOn {
                guard ahead else { return }
                let m = at(Self.muzzle(pose, frame).x, Self.muzzle(pose, frame).y, 0)
                svg.circle(m + P(-0.3, 0.3), 3.2, fill: .colour(IndustrialWarriorsInk.steel))
                svg.circle(m, 3.2, fill: .none, stroke: ink, width: 1.3)
                svg.circle(m, 1.5, fill: ink)
            } else {
                along(&svg, shift: jump) { svg in Self.barrelPart(&svg, slide: slide, from: 37, to: Self.barrel, open: false) }
            }
        }))
        // The crew.
        let sides = Self.sides(view)
        let loaderAt = pose == .walking ? Self.walkingLoaderAt : (pose == .fighting ? Self.loads[frame].at : Self.loads[0].at)
        if let r = Self.loaderRig(pose, frame) {
            items.append((depth(loaderAt, sides.loader), { svg in
                var crew = Drawing(layer: layer, rig: r, phase: phase, view: view)
                Self.drawLoaderInView(&crew, pose, frame)
                let body = crew.svg.body
                svg.group(at: at(loaderAt, 0, sides.loader)) { $0.raw(body) }
            }))
        }
        let (layerRig, layerAt) = Self.layerRig(pose, frame)
        let layerSide = pose == .walking ? sides.hauling : sides.layer
        items.append((depth(layerAt.x, layerSide), { svg in
            var crew = Drawing(layer: layer, rig: layerRig, phase: phase, view: view)
            Self.drawLayerInView(&crew, pose, frame)
            let place = at(layerAt.x, 0, layerSide)
            if pose == .walking {
                // The drag rope from its eye on the carriage to his hand at his shoulder.
                let hand = IndustrialViews.world(crew, IndustrialViews.arm(crew, front: false).hand) + place
                let eye = at(Self.ropeEye.x, Self.ropeEye.y, -4)
                var rope = PathData()
                rope.move(eye); rope.quad(P((eye.x + hand.x) / 2, -27), hand)
                svg.path(rope, stroke: ink, width: 1.7)
                svg.path(rope, stroke: .colour(IndustrialWarriorsInk.paleBuff), width: 0.8)
            }
            let body = crew.svg.body
            svg.group(at: place) { $0.raw(body) }
        }))
        // From behind, the muzzle and its smoke are beyond the gun and the crew.
        if !ahead { shotInView(&d.svg) }
        for item in items.sorted(by: { $0.depth < $1.depth }) { item.draw(&d.svg) }
        if ahead { shotInView(&d.svg) }

        func shotInView(_ svg: inout SVG) {
            guard pose == .fighting else { return }
            // The flash and the smoke along the barrel as it shows, and the spent case from the breech.
            let (u, k) = { () -> (P, Double) in
                let a = at(Self.breech.x, Self.breech.y, 0), b = at(Self.muzzle(pose, 0).x, Self.muzzle(pose, 0).y, 0)
                let v = b - a, l = BronzePeopleKit.length(v)
                return (l > 0.01 ? v * (1 / l) : P(0, -1), l / Self.barrel)
            }()
            let degrees = atan2(u.x, u.y) * 180 / .pi
            let shown = ahead || !endOn
            if frame == 1 && shown {
                let m = at(Self.muzzle(pose, 1).x, Self.muzzle(pose, 1).y, 0)
                IndustrialWarriorsKit.flash(&svg, at: m + u * 2.4, degrees: degrees, length: 26 * max(k, 0.3), girth: 7, points: 14)
            }
            let ages: [Int: (spread: Double, rise: Double, size: Double, opacity: Double)] = [
                1: (0.3, 0, 0.7, 0.95), 2: (0.62, 2, 1.1, 0.92), 3: (0.8, 5, 1.25, 0.82), 4: (0.9, 8.5, 1.32, 0.66),
                5: (0.95, 12, 1.35, 0.48), 6: (0.98, 15, 1.34, 0.32), 7: (1, 17.5, 1.3, 0.18),
            ]
            if let age = ages[frame] {
                let origin = at(Self.muzzle(pose, 0).x, Self.muzzle(pose, 0).y, 0) + u * 2
                let base: [(P, Double)] = [(P(5, 0), 4.4), (P(12, -2.6), 5.8), (P(20, 0.6), 6.4), (P(28, -4), 6), (P(35, 1), 5), (P(18, -8.6), 5),
                                           (P(27, 4), 4.2), (P(40, -4), 4.4)]
                let across = P(1, 0) * (endOn ? 0.6 : 0)
                let puffs = base.map { (p, r) in
                    (u * (p.x * age.spread * max(k, 0.35)) + across * (p.y * 1.4) + P(0, p.y * (0.7 + age.spread * 0.3) * (endOn ? 0.5 : 1) - age.rise * (0.5 + p.x / 50)),
                     r * age.size)
                }
                IndustrialWarriorsKit.smoke(&svg, at: origin, puffs: puffs, opacity: age.opacity)
            }
            if frame == 1 { BronzePeopleProps.dust(&svg, at: at(-70, -1.4, 0), size: 1, opacity: 0.45) }
            let breech = at(Self.breech.x, Self.breech.y, 0)
            if frame == 4 { IndustrialWarriorsKit.spentCase(&svg, at: breech + P(-7 * c, 1.4), degrees: 4, length: 11 * max(abs(c), 0.35), width: 3.2) }
            if frame == 5 { IndustrialWarriorsKit.spentCase(&svg, at: breech + P(-11 * c + 3 * s, 15), degrees: 64, length: 11 * max(abs(c), 0.35), width: 3.2) }
        }
    }

    /// A length of the barrel from `from` to `to` along it (the breech ring,
    /// its seams and the lever with the part from 0), slid back by `slide`.
    static func barrelPart(_ svg: inout SVG, slide: Double, from: Double, to: Double, open: Bool) {
        func at(_ t: Double, _ s: Double) -> P { onBarrel(t, s, slide: slide) }
        let profile: [(Double, Double)] = [(0, 4.2), (8, 4.2), (8.6, 3.2), (24, 2.9), (barrel - 2.6, 2.3), (barrel - 2, 2.8), (barrel, 2.8)]
        func radius(_ t: Double) -> Double {
            for i in 1..<profile.count where t <= profile[i].0 {
                let (t0, r0) = profile[i - 1], (t1, r1) = profile[i]
                return r0 + (r1 - r0) * (t - t0) / max(t1 - t0, 0.01)
            }
            return profile.last!.1
        }
        let inner = profile.filter { $0.0 > from && $0.0 < to }
        let part = [(from, radius(from))] + inner + [(to, radius(to))]
        let outline = part.map { at($0.0, -$0.1) } + part.reversed().map { at($0.0, $0.1) }
        IndustrialWarriorsKit.shape(&svg, outline, fill: .colour(IndustrialWarriorsInk.steel), width: 1.4)
        svg.line([at(max(from, 9), -2), at(min(to, barrel - 3), -1.5)], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 1)
        if from < 8 {
            svg.line([at(8, -4.2), at(8, 4.2)], stroke: .colour(Ink.line), width: 0.9)
            svg.line([at(2.4, -4.2), at(2.4, 4.2)], stroke: .colour(IndustrialWarriorsInk.steelDark), width: 0.7)
            svg.line([at(22, -2.9), at(22, 2.9)], stroke: .colour(Ink.line), width: 0.7)
            if open { svg.ellipse(at(0, 0), 1.2, 2.6, fill: .colour(Ink.line)) }
            let pivot = at(1.6, 2.6), handle = lever(open: open, slide: slide, jump: 0)
            svg.line([pivot, handle], stroke: .colour(Ink.line), width: 2.1)
            svg.line([pivot, handle], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 0.8)
            svg.circle(handle, 1.2, fill: .colour(IndustrialWarriorsInk.darkWood), stroke: .colour(Ink.line), width: 0.6)
        }
        if to >= barrel { svg.line([at(barrel, -1.4), at(barrel, 1.4)], stroke: .colour(Ink.line), width: 1.6) }
    }

    /// The shield standing across the gun, a plate `2 × 15` wide from its foot
    /// to its top: from the front its painted face, the panel of the team's
    /// colour bordered in the light and the slot for the barrel; from behind
    /// its plain back; its edge turned back where it shows. `at` places a
    /// point of the face (height, across); `edge` a point of the turned edge.
    static func shieldInView(_ svg: inout SVG, view: SpriteView, at: (Double, Double) -> P, edge: (Double, Double) -> P) {
        let ink = Paint.colour(Ink.line), w = 15.0
        let front = view == .front || view == .frontQuarter
        func quad(_ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double) -> [P] { [at(y0, z0), at(y0, z1), at(y1, z1), at(y1, z0)] }
        // The edges turned back, at whichever side shows.
        if view == .frontQuarter || view == .backQuarter {
            for z in [-w, w] {
                IndustrialWarriorsKit.shape(&svg, [at(-64, z), edge(-62.6, z), edge(-20.6, z), at(-20, z)], fill: .colour(IndustrialWarriorsInk.plateDark), width: 1.1)
            }
        }
        IndustrialWarriorsKit.shape(&svg, [at(-63, -w), at(-66, -w * 0.3), at(-66, w * 0.3), at(-63, w), at(-20, w), at(-20, -w)],
                                    fill: .colour(front ? IndustrialWarriorsInk.plate : IndustrialWarriorsInk.plateDark), width: 1.4)
        if front {
            let border = quad(-62, -46.6, -6.8, 6.8), panel = quad(-60.8, -47.8, -5.6, 5.6)
            svg.polygon(border, fill: .colour(IndustrialWarriorsInk.light))
            svg.polygon(panel.map { $0 + P(-0.4, 0.4) }, fill: .team)
            svg.polygon(panel, fill: .none, stroke: ink, width: 0.6)
            svg.polygon(border, fill: .none, stroke: ink, width: 0.7)
            svg.polygon(quad(-45.8, -37.6, -5, 5), fill: .colour(IndustrialWarriorsInk.plateDark), stroke: ink, width: 0.6)
            svg.line([at(-63.6, -w + 1), at(-65.4, 0), at(-63.6, w - 1)], stroke: .colour(IndustrialWarriorsInk.plateLight), width: 0.8)
        } else {
            // The back's stays.
            for z in [-8.0, 8.0] { svg.line([at(-60, z), at(-22, z)], stroke: .colour(IndustrialWarriorsInk.plate), width: 1.2) }
        }
        for z in [-w + 1.4, w - 1.4] {
            for i in 0..<7 { svg.circle(at(-61.6 + Double(i) * 6.4, z), 0.5, fill: .colour(front ? IndustrialWarriorsInk.plateDark : IndustrialWarriorsInk.plate)) }
        }
    }

    // MARK: The crew in the other views

    /// One of the crew in the rifleman's dress or in shirt sleeves, seen from
    /// this side, with the round held between his hands when `round` gives it
    /// (how much of it shows), and the head's hair, features and brow.
    static func soldierInView(_ d: inout Drawing, swing: Double, nose: Nose, shirt: Bool, round: Double? = nil,
                              hair: @escaping (inout Drawing) -> Void, features: @escaping (inout Drawing) -> Void, brow: @escaping (inout Drawing) -> Void) {
        d.figure { d in
            let arms = [(false, IndustrialViews.arm(d, front: false)), (true, IndustrialViews.arm(d, front: true))]
            func sleeve(_ d: inout Drawing, _ front: Bool, _ a: IndustrialViews.Arm) {
                if shirt {
                    shirtSleeve(&d, a.points, front: front)
                } else {
                    IndustrialWarriorsKit.sleeve(&d, a.points, colour: front ? IndustrialWarriorsInk.green : IndustrialWarriorsInk.darkGreen,
                                                 cuff: front ? IndustrialWarriorsInk.brick : IndustrialWarriorsInk.darkBrick)
                }
            }
            for (front, a) in arms where a.behind { sleeve(&d, front, a) }
            IndustrialWarriorsViews.legs(&d, trousers: IndustrialWarriorsInk.brick, darkTrousers: IndustrialWarriorsInk.darkBrick)
            if shirt {
                shirtInView(&d)
            } else {
                IndustrialWarriorsViews.tunic(&d, colour: IndustrialWarriorsInk.green, dark: IndustrialWarriorsInk.darkGreen, pale: IndustrialWarriorsInk.paleGreen,
                                              collar: IndustrialWarriorsInk.brick, swing: swing)
                IndustrialWarriorsViews.belt(&d)
            }
            if let visible = round {
                // The round across his hands, from the far hand toward the near.
                let far = arms[0].1.held, near = arms[1].1.held
                let v = near - far, l = max(v.length, 0.01), u = v * (1 / l)
                let base = far - u * 3.2, tip = base + u * 17
                let a = IndustrialViews.screen(d, base), b = IndustrialViews.screen(d, tip)
                let shown = b - a, k = BronzePeopleKit.length(shown) / 17
                let degrees = k > 0.02 ? atan2(shown.x, shown.y) * 180 / .pi : 180
                IndustrialViews.foreshortened(&d.svg, at: a, degrees: degrees, scale: max(k, 0.2)) { svg in
                    Self.round(&svg, base: a, degrees: degrees, visible: visible)
                }
                if arms[0].1.behind { d.hand(arms[0].1.hand) }
            }
            for (front, a) in arms where !a.behind { sleeve(&d, front, a) }
            d.head(nose: nose, behind: { d in IndustrialWarriorsViews.capPeakBehind(&d) }, hair: hair, features: features, brow: brow,
                   over: { d in IndustrialWarriorsViews.peakedCap(&d) })
        }
    }

    /// The linen shirt in a view other than the side: turned, its placket and
    /// buttons at the front, the seat of the trousers, the braces over the
    /// shoulders, the open collar and the belt.
    static func shirtInView(_ d: inout Drawing) {
        let lift = d.rig.lift, ink = Paint.colour(Ink.line)
        d.garment(colour: [P(-12.4, -46.4), P(9.6, -48.2), P(12, -36), P(11.4, -26.4), P(-13.4, -26)],
                  outline: [P(-9.2, -47.4), P(9.2, -47.4), P(11.4, -36.4), P(10.8, -27), P(-12.6, -27)],
                  fill: .colour(IndustrialWarriorsInk.linen)) { d in
            if IndustrialViews.seesFront(d), let top = IndustrialViews.front(d, -46.6 - lift, 0), let bottom = IndustrialViews.front(d, -31, 0) {
                d.svg.line([top, bottom], stroke: .colour(IndustrialWarriorsInk.smokeShade), width: 0.9)
                for i in 0..<3 {
                    if let b = IndustrialViews.front(d, -44 + Double(i) * 4.4 - lift, 0) { d.svg.circle(b + P(0.8, 0), 0.5, fill: .colour(IndustrialWarriorsInk.paleSoot)) }
                }
            }
        }
        let seat = d.turned([d.up(P(-11.6, -28.4)), d.up(P(10.6, -28.6)), P(9.2, -19), P(6.4, -14.6), P(-5.2, -14.6), P(-10.8, -19)])
        IndustrialWarriorsKit.shape(&d.svg, seat, fill: .colour(IndustrialWarriorsInk.brick), width: 1.1)
        for z in [-5.0, 5.0] {
            let ends = IndustrialViews.seesFront(d)
                ? (IndustrialViews.front(d, -47.4 - lift, z), IndustrialViews.front(d, -28.4, z * 1.1))
                : (IndustrialViews.back(d, -47.4 - lift, z * 0.8), IndustrialViews.back(d, -28.4, z * 0.4))
            guard let a = ends.0, let b = ends.1 else { continue }
            IndustrialWarriorsKit.shape(&d.svg, [a + P(-1, 0), a + P(1, 0), b + P(1, 0), b + P(-1, 0)], fill: .colour(IndustrialWarriorsInk.darkSoot), width: 0.6)
            d.svg.circle(b + P(0, -0.6), 0.5, fill: .colour(IndustrialWarriorsInk.brass))
        }
        IndustrialWarriorsKit.shape(&d.svg, [P(-6, -49.4 - lift), P(6, -49.4 - lift), P(6.6, -46.4 - lift), P(-6.6, -46.4 - lift)],
                                    fill: .colour(IndustrialWarriorsInk.linen), width: 0.9)
        if IndustrialViews.seesFront(d), let v = IndustrialViews.front(d, -46.6 - lift, 0, half: 7) {
            d.svg.polygon([v + P(-2.2, -2.4), v + P(2.2, -2.4), v + P(0, 1.6)], fill: .colour(Ink.skin), stroke: ink, width: 0.7)
        }
        IndustrialWarriorsViews.belt(&d)
    }

    /// The layer in a view other than the side: clean-shaven, nose E, a cleft chin.
    static func drawLayerInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        soldierInView(&d, swing: pose == .walking ? d.rig.sway : 0, nose: .line, shirt: false, hair: { d in
            IndustrialWarriorsViews.shortHair(&d, colour: .colour(IndustrialWarriorsInk.wood))
        }, features: { d in
            guard IndustrialViews.seesFront(d) else { return }
            let x = IndustrialViews.face(d).x
            d.svg.path("M\(num(x)),-48.2 l0,-1.6", stroke: .colour(Ink.line), width: 0.6, opacity: 0.7)
        }, brow: { d in
            d.svg.path("M2,-63.4 q3,-1.2 6.4,-0.2", stroke: .colour(Ink.line), width: 1.4)
        })
    }

    /// The loader in a view other than the side: a bushy moustache, nose B, in
    /// shirt sleeves, the round in his hands.
    static func drawLoaderInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        var visible: Double?
        if pose == .standing {
            visible = 17
        } else if pose == .fighting, let r = loads[frame].round, loads[frame].far != nil {
            visible = frame == 6 ? BronzePeopleKit.length(onBarrel(0, 0) - r.base) : 17
        }
        soldierInView(&d, swing: pose == .walking ? d.rig.sway : 0, nose: .button, shirt: true, round: visible, hair: { d in
            IndustrialWarriorsViews.shortHair(&d, colour: .colour(IndustrialWarriorsInk.hair))
        }, features: { d in
            guard IndustrialViews.seesFront(d) else { return }
            let half = [P(0, -54), P(2.8, -54.8), P(5, -53.8), P(5.6, -51.6), P(3.4, -51.8), P(0, -51.4)]
            d.svg.polygon(IndustrialViews.symmetric(d, half), fill: .colour(IndustrialWarriorsInk.hair), stroke: .colour(Ink.line), width: 0.5)
        }, brow: { d in
            d.svg.path("M1.2,-63.6 q3.4,-2 7.4,-0.8", stroke: .colour(Ink.line), width: 1.9)
        })
    }
}
