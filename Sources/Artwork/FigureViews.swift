// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The figure seen from its five sides (ruled 2026-11-21: eight facings, five
// views drawn, the other three mirrored). The skeleton of `Rig` lives in the
// figure's own space: X toward its front, Y downward, and Z toward its right
// side, which is the side a viewer sees when it faces right. A view turns
// that space by its yaw about the upright axis and drops the depth: from the
// side nothing turns; from the front a quarter turn brings the figure's front
// toward the viewer, its right side to the screen's left; from behind, the
// other way. The legs and arms swing in the figure's own upright plane, so
// that a stride seen from the front shows the knees lifting and the feet
// coming and going, and the arm nearer the viewer is drawn over the body.
//
// What a kind of person wears is drawn in profile (`garment`, `band`), and
// the kit turns it: each level of a garment is taken as a round section as
// deep as the profile shows it and as wide again, so that from the front the
// garment shows its full width, centred, and from a quarter turn its centre
// shifts toward the figure's front. The head has its own drawing for each
// view; a kind's hair, brow and features follow `Drawing.view` where they must.

extension SpriteView {
    /// The turn about the upright axis that shows the figure this way, in degrees.
    var yaw: Double {
        switch self {
        case .side: 0
        case .frontQuarter: 45
        case .front: 90
        case .back: -90
        case .backQuarter: -45
        }
    }
}

extension Drawing {
    /// The view's turn, in degrees.
    var yaw: Double { view.yaw }

    /// A point of the figure's space on the screen (before the bob and the lean), and its depth toward the viewer.
    func project(_ x: Double, _ y: Double, _ z: Double) -> (point: P, depth: Double) {
        let r = yaw * .pi / 180, c = cos(r), s = sin(r)
        return (P(x * c - z * s, y), x * s + z * c)
    }

    /// The hips and shoulders across the body: the right side's are at +z.
    static let hipSpread = 4.5, shoulderSpread = 9.5

    /// A limb from `root` by `limb`: its middle joint and its end, in the figure's
    /// space (x, y), the knee bending back and the elbow turning by `bend`.
    private func limbPoints(_ root: P, _ limb: Limb, first: Double, second: Double, knee: Bool) -> (P, P) {
        let mid = root + P.direction(limb.upper) * first
        let end = mid + P.direction(knee ? limb.upper - limb.bend : limb.upper + limb.bend) * second
        return (mid, end)
    }

    /// A hand where it falls in this view (before the bob and the lean): the
    /// right (front) hand or the left (back) one. In profile it is the joint itself.
    func hand(front: Bool) -> P {
        if view == .side { return front ? joints.frontHand : joints.backHand }
        let shoulder = P(0.5, -44 - rig.lift)
        let (_, end) = limbPoints(shoulder, front ? rig.frontArm : rig.backArm, first: Joints.upperArm,
                                  second: Joints.forearm, knee: false)
        return project(end.x, end.y, front ? Drawing.shoulderSpread : -Drawing.shoulderSpread).point
    }

    /// Whether an arm hangs behind the body in this view, so that it is drawn
    /// first: its middle deeper than a little behind the body's centre.
    func armBehind(front: Bool) -> Bool {
        let shoulder = P(0.5, -44 - rig.lift)
        let z = front ? Drawing.shoulderSpread : -Drawing.shoulderSpread
        let (elbow, end) = limbPoints(shoulder, front ? rig.frontArm : rig.backArm, first: Joints.upperArm,
                                      second: Joints.forearm, knee: false)
        let depth = (project(elbow.x, elbow.y, z).depth + project(end.x, end.y, z).depth) / 2
        return depth < -2.5
    }

    /// An angle in the figure's upright plane (degrees from straight down,
    /// positive toward the front) as it shows on the screen in this view.
    func onScreen(_ degrees: Double) -> Double {
        let d = P.direction(degrees)
        let x = d.x * cos(yaw * .pi / 180), y = d.y
        guard abs(x) > 1e-6 || abs(y) > 1e-6 else { return degrees }
        return atan2(x, y) * 180 / .pi
    }

    /// Both legs in this view, the farther first, upright whatever the lean.
    mutating func legsInView() {
        let lean = rig.lean * cos(yaw * .pi / 180)
        var legs: [(depth: Double, points: [P], foot: P, toe: P)] = []
        for front in [false, true] {
            let z = front ? Drawing.hipSpread : -Drawing.hipSpread
            let hip = P(0.5, -16)
            let (knee, foot) = limbPoints(hip, front ? rig.frontLeg : rig.backLeg, first: Joints.thigh,
                                          second: Joints.shin, knee: true)
            let toe = foot + P(4.5, 0.3)
            let points = [hip, knee, foot].map { project($0.x, $0.y, z).point }
            legs.append((project(knee.x, knee.y, z).depth, points, project(foot.x, foot.y, z).point,
                         project(toe.x, toe.y, z).point))
        }
        legs.sort { $0.depth < $1.depth }
        svg.group(turned: -lean, about: Drawing.hips) { svg in
            for leg in legs {
                svg.line(leg.points, stroke: .colour(Ink.line), width: 2.1)
                // The foot: its length shows as far as the view turns it aside; seen
                // end on, a short sole.
                let run = leg.toe.x - leg.foot.x
                if abs(run) > 1.2 {
                    svg.line([leg.foot, leg.toe], stroke: .colour(Ink.line), width: 2.1)
                } else {
                    svg.ellipse(leg.foot + P(0, 0.2), 1.9, 1.1, fill: .colour(Ink.line))
                }
            }
        }
    }

    /// The arms in this view that belong to this call: those behind the body
    /// when `front` is false, the rest when it is true. Every arm is drawn by
    /// exactly one of the two calls.
    mutating func armsInView(front: Bool, width: Double) {
        let shoulder = P(0.5, -44 - rig.lift)
        for right in [false, true] where armBehind(front: right) != front {
            let z = right ? Drawing.shoulderSpread : -Drawing.shoulderSpread
            let (elbow, end) = limbPoints(shoulder, right ? rig.frontArm : rig.backArm, first: Joints.upperArm,
                                          second: Joints.forearm, knee: false)
            let points = [shoulder, elbow, end].map { project($0.x, $0.y, z).point }
            svg.line(points, stroke: .colour(Ink.line), width: width)
            hand(points[2])
        }
    }

    /// A point drawn on the body in profile, where it falls on the body in this
    /// view: its offset from the body's middle taken across the body's width.
    func onBody(_ p: P) -> P {
        if view == .side { return p }
        return P(p.x * 0.92, p.y)
    }

    /// A shape drawn in profile around the body (a garment, a band), as it shows
    /// in this view: each level of it taken as a round section as deep as the
    /// profile shows and as wide, turned by the view.
    func turned(_ shape: [P]) -> [P] {
        if view == .side || shape.count < 3 { return shape }
        let r = yaw * .pi / 180, c = cos(r), s = sin(r)
        let top = shape.map(\.y).min()!, bottom = shape.map(\.y).max()!
        let steps = 12
        var right: [P] = [], left: [P] = []
        for i in 0...steps {
            // Just inside the top and bottom, so that the level meets the shape's sides.
            let y = top + (bottom - top) * (0.002 + 0.996 * Double(i) / Double(steps))
            var xs: [Double] = []
            for k in shape.indices {
                let a = shape[k], b = shape[(k + 1) % shape.count]
                if (a.y - y) * (b.y - y) <= 0, a.y != b.y {
                    xs.append(a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y))
                }
            }
            guard let low = xs.min(), let high = xs.max() else { continue }
            let centre = (low + high) / 2, half = (high - low) / 2, width = half * 0.95
            let extent = ((half * c) * (half * c) + (width * s) * (width * s)).squareRoot()
            right.append(P(centre * c + extent, y))
            left.append(P(centre * c - extent, y))
        }
        return right + left.reversed()
    }

    /// The head in a view other than the side: skin, cheeks, the kind's hair,
    /// outline, ears, and (where the face shows) nose, mouth, brows and eyes.
    mutating func headInView(nose: Nose, behind: (inout Drawing) -> Void, hair: (inout Drawing) -> Void,
                             features: (inout Drawing) -> Void, brow: (inout Drawing) -> Void,
                             over: (inout Drawing) -> Void) {
        let tilt = rig.headTilt * cos(yaw * .pi / 180)
        let line = Paint.colour(Ink.line), skin = Paint.colour(Ink.skin)
        svg.raw("<g transform=\"translate(0,\(num(chest.y))) rotate(\(num(tilt)) 0 -48)\">")
        behind(&self)
        // The face's centre turns toward the screen's right as the head turns toward the viewer.
        let face: Double
        switch view {
        case .front, .back: face = 0
        case .frontQuarter: face = 4.5
        case .backQuarter: face = -4.5
        case .side: face = 0
        }
        let seesFace = view == .front || view == .frontQuarter
        svg.ellipse(P(0, -58), 10.2, 9.5, fill: skin)
        if seesFace {
            if view == .front {
                for x in [-5.8, 5.8] { svg.circle(P(x, -53.6), 2.2, fill: .colour(Ink.cheek)) }
            } else {
                svg.circle(P(face + 1.5, -53.5), 2.4, fill: .colour(Ink.cheek))
                svg.circle(P(face - 7.5, -53.6), 1.6, fill: .colour(Ink.cheek))
            }
        }
        hair(&self)
        svg.ellipse(P(0, -57.5), 11, 10.2, fill: .none, stroke: line, width: 1.8)
        // The ears: both from the front or behind; from a quarter, the one on the side away from the face.
        let leftEar = "M-9.8,-60 q-4,1 -3,5 q1,3 4,1", rightEar = "M9.8,-60 q4,1 3,5 q-1,3 -4,1"
        switch view {
        case .front, .back:
            svg.path(leftEar, fill: skin, stroke: line, width: 1.4)
            svg.path(rightEar, fill: skin, stroke: line, width: 1.4)
        case .frontQuarter:
            svg.path("M-7,-60 q-4,1 -3,5 q1,3 4,1", fill: skin, stroke: line, width: 1.4)
        case .backQuarter:
            svg.path("M5.6,-60.5 q4,1 3,5 q-1,3 -4,1", fill: skin, stroke: line, width: 1.4)
        case .side:
            break
        }
        if seesFace {
            frontNose(nose, at: face)
            features(&self)
            frontMouth(at: face)
            // The brow over each eye: the kind's own, drawn for the eye on the
            // screen's right, and mirrored about the face's centre for the other.
            svg.raw("<g transform=\"translate(\(num(face - 4.5 + (view == .front ? 4.3 : 1.4))),0)\">")
            brow(&self)
            svg.raw("</g>")
            let farX = view == .front ? -4.3 : face - 6
            svg.raw("<g transform=\"translate(\(num(farX + 4.5)),0) scale(-1,1)\">")
            brow(&self)
            svg.raw("</g>")
            frontEyes(at: face)
        } else {
            features(&self)
        }
        over(&self)
        svg.raw("</g>")
    }

    /// The nose seen from the front or a quarter turn, at the face's centre `x`.
    private mutating func frontNose(_ nose: Nose, at x: Double) {
        let line = Paint.colour(Ink.line), skin = Paint.colour(Ink.skin)
        // From a quarter, the nose stands out toward the screen's right.
        let quarter = view == .frontQuarter
        let at = P(x + (quarter ? 1.6 : 0), -56)
        switch nose {
        case .curve:
            var d = PathData()
            d.move(at + P(-0.6, -2.6))
            d.quad(at + P(quarter ? 3.4 : 2.2, 0.6), at + P(-0.2, 1.6))
            svg.path(d, fill: skin, stroke: line, width: 1.3)
        case .button:
            svg.circle(at + P(0.2, 0.4), 2.1, fill: .colour(Ink.cheek), stroke: line, width: 1.3)
        case .hook:
            var d = PathData()
            d.move(at + P(-0.4, -3.6))
            d.quad(at + P(quarter ? 3.6 : 2.4, 0.2), at + P(0.4, 1.6))
            d.line(at + P(-1.2, 1))
            svg.path(d, fill: skin, stroke: line, width: 1.3)
        case .line:
            svg.line([at + P(0, -3), at + P(quarter ? 1.8 : 1.2, 0.8), at + P(-1, 1)], stroke: line, width: 1.3)
        case .bulb:
            svg.ellipse(at + P(quarter ? 0.8 : 0, 0.2), 2.6, 2.3, fill: skin, stroke: line, width: 1.3)
        }
    }

    /// The mouth from the front or a quarter turn, under the face's centre `x`.
    private mutating func frontMouth(at x: Double) {
        let line = Paint.colour(Ink.line)
        let c = P(x + (view == .frontQuarter ? 0.8 : 0), -51)
        switch rig.mouth {
        case .smile:
            var d = PathData()
            d.move(c + P(-3, 0)); d.quad(c + P(0, 2.2), c + P(3, -0.2))
            svg.path(d, stroke: line, width: 1.4)
        case .firm:
            svg.line([c + P(-2.6, 0), c + P(2.6, -0.1)], stroke: line, width: 1.4)
        case .open: svg.ellipse(c, 1.6, 1.3, fill: line)
        case .murmur: svg.ellipse(c, 1.1, 0.8, fill: line)
        case .shout: svg.ellipse(c, 2.1, 1.9, fill: line)
        case .hidden: break
        }
    }

    /// Both eyes from the front or a quarter turn, about the face's centre `x`;
    /// from a quarter, the eye toward the way the head turns (the screen's
    /// right) is turned away from the viewer, and so narrower.
    private mutating func frontEyes(at x: Double) {
        let line = Paint.colour(Ink.line)
        let eyes: [(P, Double)] = view == .front
            ? [(P(-4.3, -60), 1), (P(4.3, -60), 1)]
            : [(P(x - 6, -60), 1), (P(x + 1.4, -60), 0.72)]
        for (c, narrow) in eyes {
            switch rig.eyes {
            case .closed:
                svg.line([c + P(-2 * narrow, 0), c + P(2 * narrow, 0)], stroke: line, width: 1.5)
            case .open, .down, .wide:
                let wide = rig.eyes == .wide
                svg.ellipse(c, (wide ? 3 : 2.7) * narrow, wide ? 3 : 2.6, fill: .colour(Ink.eyeWhite), stroke: line,
                            width: 1)
                let look = view == .frontQuarter ? 0.8 * narrow : 0
                svg.circle(c + P(look, rig.eyes == .down ? 0.8 : 0.3), wide ? 1.2 : 1.3, fill: line)
            }
        }
    }
}
