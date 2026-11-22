// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The jointed figure every person is built on (docs/art-style.md, "Movement"):
// hip, knee and foot; shoulder, elbow and hand; a large head on a simple body.
// It is the approved worker's skeleton (docs/art/worker-animation.gif), so that
// every kind of person moves the same way. Figure units: about 72 from the
// ground to the top of the head; y runs downward.

/// What a kind of person looks like in one age, and how it moves: the
/// skeleton for each frame of each pose, and everything drawn on it.
protocol PersonLook: Sendable {
    /// The skeleton for a frame (0 to 11) of a pose, or nil where the kind has no such pose.
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig?
    /// The figure, drawn into `d` (start with `d.figure { ... }`).
    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int)
}

extension PersonLook {
    /// A frame of a pose drawn as a sprite's picture and mask, grained alike;
    /// nil where the kind has no such pose.
    func render(_ pose: SpritePose, frame: Int, canvas: Canvas = .person, view: SpriteView = .side) -> Rendered? {
        guard let rig = rig(pose, frame) else { return nil }
        return Raster.render(on: canvas) { svg in
            var drawing = Drawing(layer: svg.layer, rig: rig, phase: Double(frame) / 12, view: view)
            draw(&drawing, pose, frame)
            svg = drawing.svg
        }
    }
}

/// The approved worker's movements (docs/art/worker-animation.gif), from which
/// every kind of person starts.
enum Moves {
    /// A frame's place in its cycle of 12, from 0 up to 1.
    static func phase(_ frame: Int) -> Double { Double(frame) / 12 }

    /// Standing: a breath through the cycle, and a blink on its ninth frame.
    static func standing(_ frame: Int) -> Rig {
        let breath = 0.8 * sin(phase(frame) * 2 * .pi)
        var r = Rig()
        r.backLeg = Limb(-4, 4); r.frontLeg = Limb(5, 4)
        r.backArm = Limb(-6, -6); r.frontArm = Limb(8 + breath, -8)
        r.lift = breath * 0.6
        r.eyes = frame == 8 ? .closed : .open
        return r
    }

    /// Walking: a full stride in 12 frames. The knee bends as the leg swings
    /// forward, the foot plants and pushes off, the arms swing opposite the
    /// legs, and the body rises and falls as the lower foot stays on the ground.
    static func walking(_ frame: Int, stride: Double = 24, kneeLift: Double = 46, armSwing: Double = 30) -> Rig {
        let t = phase(frame) * 2 * .pi
        func leg(_ t: Double) -> Limb { Limb(stride * sin(t), 4 + kneeLift * pow(max(0, cos(t)), 1.5)) }
        var r = Rig()
        r.backLeg = leg(t); r.frontLeg = leg(t + .pi)
        r.backArm = Limb(-armSwing * sin(t), -14); r.frontArm = Limb(armSwing * sin(t), -16)
        r.lean = 3
        r.sway = sin(t)
        return r
    }

    /// A blow: the weapon arm is raised over `raiseFrames` frames from `ready`
    /// to `raised` degrees, brought down to `struck` over the next two, and
    /// eased back to `ready`. Returns the arm's angle, and whether this is the
    /// frame on which the blow lands.
    static func blow(_ frame: Int, ready: Double, raised: Double, struck: Double, raiseFrames: Int = 6) -> (angle: Double, landing: Bool) {
        let f = Double(frame), r = Double(raiseFrames)
        if f < r { return (mix(ready, raised, ease(f / r)), false) }
        if f < r + 2 {
            let t = (f - r + 1) / 2.4
            return (mix(raised, struck, t * t), false)
        }
        return (mix(struck, ready, ease((f - r - 2) / (12 - r - 2))), f == r + 2)
    }
}

/// The colours of the Stone age (docs/art-style.md, "Palettes"), and the few
/// shades every age shares: the line, the skin, the eye.
enum Ink {
    static let line = "#2a2420"
    static let ground = "#a79aa6"
    static let hide = "#c08a5a"
    static let moss = "#8a9c58"
    static let light = "#efe0c2"
    /// Darker shades of the hide and the moss, for spots, wood and pattern.
    static let darkHide = "#7a4a2a"
    static let wood = "#8a5a33"
    static let handle = "#6b4a2a"
    static let darkMoss = "#5f6e3a"
    /// Worked stone: an axe's blade, a mallet's head, a tablet.
    static let stone = "#b8b0a0"
    static let skin = "#e2a27c"
    static let cheek = "#d9825f"
    static let eyeWhite = "#f8f1e0"
}

/// The five noses of docs/art-style.md, "Noses", scaled from the style sheet's
/// face to the figure's head. The upturned nose (D) is not used.
enum Nose: CaseIterable, Sendable {
    /// A: a small curve.
    case curve
    /// B: a button.
    case button
    /// C: a small hook.
    case hook
    /// E: a line only.
    case line
    /// F: a bulb.
    case bulb
}

enum Eyes: Sendable { case open, closed, down, wide }
enum Mouth: Sendable { case smile, open, firm, shout, murmur, hidden }

/// A two-segment limb's angles in degrees from straight down, positive toward
/// the front. A knee bends backward by `bend`; an elbow turns by `bend`.
struct Limb: Sendable {
    var upper: Double
    var bend: Double
    init(_ upper: Double, _ bend: Double) { self.upper = upper; self.bend = bend }
}

/// The skeleton's state in one frame.
struct Rig: Sendable {
    /// The body's lean in degrees about the hips, positive toward the front.
    var lean = 0.0
    var backLeg = Limb(-4, 4)
    var frontLeg = Limb(5, 4)
    var backArm = Limb(-6, -6)
    var frontArm = Limb(8, -8)
    /// How far the chest rises with a breath, in figure units; the feet stay planted.
    var lift = 0.0
    /// The head's tilt in degrees about the neck, positive toward the front (a nod).
    var headTilt = 0.0
    var eyes = Eyes.open
    var mouth = Mouth.smile
    /// The cloth's sway with the stride, from -1 (swung back) to 1 (swung forward).
    var sway = 0.0
}

/// Where the joints are in one frame, in body coordinates: before the bob and
/// the lean are applied.
struct Joints: Sendable {
    static let backHip = P(-3, -16), frontHip = P(4, -16)
    static let thigh = 11.0, shin = 11.5, upperArm = 7.5, forearm = 7.5

    var backKnee: P, backFoot: P, frontKnee: P, frontFoot: P
    var backShoulder: P, frontShoulder: P
    var backElbow: P, backHand: P, frontElbow: P, frontHand: P

    init(_ rig: Rig) {
        func leg(_ hip: P, _ limb: Limb) -> (P, P) {
            let knee = hip + P.direction(limb.upper) * Joints.thigh
            return (knee, knee + P.direction(limb.upper - limb.bend) * Joints.shin)
        }
        func arm(_ shoulder: P, _ limb: Limb) -> (P, P) {
            let elbow = shoulder + P.direction(limb.upper) * Joints.upperArm
            return (elbow, elbow + P.direction(limb.upper + limb.bend) * Joints.forearm)
        }
        (backKnee, backFoot) = leg(Joints.backHip, rig.backLeg)
        (frontKnee, frontFoot) = leg(Joints.frontHip, rig.frontLeg)
        backShoulder = P(-7, -44 - rig.lift)
        frontShoulder = P(8, -44 - rig.lift)
        (backElbow, backHand) = arm(backShoulder, rig.backArm)
        (frontElbow, frontHand) = arm(frontShoulder, rig.frontArm)
    }
}

/// One frame of a person being drawn: the SVG so far, the rig and its joints,
/// and where the frame falls in its pose's cycle.
struct Drawing {
    var svg: SVG
    let rig: Rig
    let joints: Joints
    /// The frame's place in its cycle of 12, from 0 up to 1.
    let phase: Double
    /// How far the figure is raised so that its lower foot rests on the ground.
    let bob: Double

    /// The view the figure is seen from (ruled 2026-11-21: five views).
    let view: SpriteView

    /// The pivot of the lean, at the hips.
    static let hips = P(0, -14)

    init(layer: Layer, rig: Rig, phase: Double, view: SpriteView = .side) {
        svg = SVG(layer: layer)
        self.rig = rig
        joints = Joints(rig)
        self.phase = phase
        self.view = view
        // The lower foot rests on the ground. The legs do not lean with the body
        // (`legs()`), so that both feet can stay planted in a lunge.
        bob = -max(joints.backFoot.y, joints.frontFoot.y)
    }

    /// The upper body's offset for a breath.
    var chest: P { P(0, -rig.lift) }

    /// A point of the body (inside `figure`) where it falls in the picture,
    /// after the lean and the bob: for things that stand outside the body, such
    /// as the post a blow lands on.
    func world(_ p: P) -> P { p.rotated(rig.lean, about: Drawing.hips) + P(0, bob) }

    // MARK: Limbs

    func legPath(_ hip: P, _ knee: P, _ foot: P) -> [P] { [hip, knee, foot, foot + P(4.5, 0.3)] }

    /// Both legs, upright whatever the body's lean: their angles are taken from
    /// straight down on the ground, not from the leaning body.
    mutating func legs() {
        if view != .side { legsInView(); return }
        let front = legPath(Joints.frontHip, joints.frontKnee, joints.frontFoot)
        let back = legPath(Joints.backHip, joints.backKnee, joints.backFoot)
        svg.group(turned: -rig.lean, about: Drawing.hips) { svg in
            svg.line(front, stroke: .colour(Ink.line), width: 2.1)
            svg.line(back, stroke: .colour(Ink.line), width: 2.1)
        }
    }

    /// A foot where it falls in the picture: on the ground (y = 0) when it is the lower one.
    func worldFoot(front: Bool) -> P { (front ? joints.frontFoot : joints.backFoot) + P(0, bob) }

    mutating func arm(front: Bool, width: Double = 1.9) {
        if view != .side { armsInView(front: front, width: width); return }
        let points = front ? [joints.frontShoulder, joints.frontElbow, joints.frontHand]
            : [joints.backShoulder, joints.backElbow, joints.backHand]
        svg.line(points, stroke: .colour(Ink.line), width: width)
        hand(front ? joints.frontHand : joints.backHand)
    }

    mutating func hand(_ at: P) {
        svg.circle(at, 1.7, fill: .colour(Ink.skin), stroke: .colour(Ink.line), width: 1)
    }

    // MARK: The head

    /// The neck, about which the head nods.
    var neck: P { P(0, -48) + chest }

    /// The head of every kind: skin, cheek, outline, ear, eye and mouth, with the
    /// kind's hair, nose, brow and features drawn in their places.
    mutating func head(nose: Nose, behind: (inout Drawing) -> Void = { _ in }, hair: (inout Drawing) -> Void,
                       features: (inout Drawing) -> Void = { _ in }, brow: (inout Drawing) -> Void,
                       over: (inout Drawing) -> Void = { _ in }) {
        if view != .side {
            headInView(nose: nose, behind: behind, hair: hair, features: features, brow: brow, over: over)
            return
        }
        let tilt = rig.headTilt
        svg.raw("<g transform=\"translate(0,\(num(chest.y))) rotate(\(num(tilt)) 0 -48)\">")
        behind(&self)
        svg.ellipse(P(0, -58), 10, 9.5, fill: .colour(Ink.skin))
        svg.circle(P(3, -53.5), 2.6, fill: .colour(Ink.cheek))
        hair(&self)
        svg.ellipse(P(0.5, -57.5), 11, 10.2, fill: .none, stroke: .colour(Ink.line), width: 1.8)
        svg.path("M-8.5,-60 q-4,1 -3,5 q1,3 4,1", fill: .colour(Ink.skin), stroke: .colour(Ink.line), width: 1.4)
        self.nose(nose)
        features(&self)
        mouth()
        brow(&self)
        eye()
        over(&self)
        svg.raw("</g>")
    }

    mutating func nose(_ nose: Nose) {
        let line = Paint.colour(Ink.line)
        switch nose {
        case .curve: svg.path("M10.5,-58.5 q4,1.6 1.5,4.4 q-1,0.8 -2.2,0.2", fill: .colour(Ink.skin), stroke: line, width: 1.5)
        case .button: svg.circle(P(12, -56.6), 2.3, fill: .colour(Ink.cheek), stroke: line, width: 1.4)
        case .hook: svg.path("M10.2,-60.8 q3.8,1.1 3.4,4.9 q-0.4,1.5 -2.3,1.1 l-1.1,-0.8", fill: .colour(Ink.skin), stroke: line, width: 1.4)
        case .line: svg.path("M10.8,-60.2 l3.1,3.5 l-3.1,0.8", stroke: line, width: 1.4)
        case .bulb: svg.path("M10.2,-61.6 q4.8,2.2 3.2,6.2 q-1.6,1.2 -3.2,0", fill: .colour(Ink.skin), stroke: line, width: 1.5)
        }
    }

    mutating func mouth() {
        let line = Paint.colour(Ink.line)
        switch rig.mouth {
        case .smile: svg.path("M4,-51 q3,2 6,-0.5", stroke: line, width: 1.4)
        case .firm: svg.path("M4.6,-51 q3,0.4 5.6,-0.6", stroke: line, width: 1.4)
        case .open: svg.ellipse(P(7.4, -51), 1.6, 1.3, fill: line)
        case .murmur: svg.ellipse(P(7.6, -51.2), 1.1, 0.8, fill: line)
        case .shout: svg.ellipse(P(7.6, -51.2), 2.1, 1.9, fill: line)
        case .hidden: break
        }
    }

    mutating func eye() {
        let line = Paint.colour(Ink.line)
        switch rig.eyes {
        case .closed:
            svg.path("M2.5,-60 h4", stroke: line, width: 1.6)
        case .open, .down, .wide:
            let wide = rig.eyes == .wide
            svg.ellipse(P(4.5, -60), wide ? 3.3 : 3, wide ? 3 : 2.6, fill: .colour(Ink.eyeWhite), stroke: line, width: 1)
            let pupil = rig.eyes == .down ? P(5.6, -59) : P(5.5, -59.6)
            svg.circle(pupil, wide ? 1.2 : 1.4, fill: line)
        }
    }

    // MARK: The body

    /// The frame drawn into its place: the ground's shadow, then everything else
    /// raised by the bob and leaned about the hips.
    mutating func figure(_ content: (inout Drawing) -> Void) {
        svg.ellipse(P(0, 0), 13, 3.5, fill: .colour("#000000"), opacity: 0.13)
        // Seen from another side, the lean in the body's own plane turns the figure on the screen by less.
        let lean = rig.lean * cos(yaw * .pi / 180)
        svg.raw("<g transform=\"translate(0,\(num(bob))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        content(&self)
        svg.raw("</g>")
    }

    /// A point of the upper body raised by the breath: fully at the shoulders,
    /// not at all at the hips, so that the cloth stretches rather than the feet lifting.
    func up(_ p: P) -> P {
        let share = min(max((-p.y - 16) / 28, 0), 1)
        return P(p.x, p.y - rig.lift * share)
    }

    /// A tunic or robe: its colour (`colour`, a shape a little out of register
    /// with the outline, as the style has it), then the pattern and the team's
    /// band, then the outline drawn loosely over them.
    mutating func garment(colour: [P], outline: [P], fill: Paint, pattern: (inout Drawing) -> Void = { _ in },
                          width: Double = 1.8) {
        if view != .side {
            svg.polygon(turned(colour).map(up), fill: fill)
            pattern(&self)
            svg.polygon(turned(outline).map(up), fill: .none, stroke: .colour(Ink.line), width: width)
            return
        }
        svg.polygon(colour.map(up), fill: fill)
        pattern(&self)
        svg.polygon(outline.map(up), fill: .none, stroke: .colour(Ink.line), width: width)
    }

    /// A band of cloth across the body, in the team's colour unless another is given.
    mutating func band(_ points: [P], fill: Paint = .team) {
        if view != .side { svg.polygon(turned(points).map(up), fill: fill); return }
        svg.polygon(points.map(up), fill: fill)
    }

    /// A zigzag hem from `from` to `to`, its teeth `depth` deep.
    mutating func zigzag(from: P, to: P, teeth: Int, depth: Double, width: Double = 1.3) {
        let from = onBody(from), to = onBody(to)
        var d = PathData()
        d.move(from)
        for i in 1...(teeth * 2) {
            let t = Double(i) / Double(teeth * 2)
            let p = from + (to - from) * t
            d.line(i % 2 == 1 ? p + P(0, depth) : p)
        }
        svg.path(d, stroke: .colour(Ink.line), width: width)
    }
}

/// Smoothstep: 0 at 0, 1 at 1, with no jolt at either end.
func ease(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}

/// A value moving from `a` to `b` as `t` runs from 0 to 1.
func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
