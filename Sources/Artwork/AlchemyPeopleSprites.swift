// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

/// The worker in the Alchemy look, drawn in the Cartoon Modern style of
/// docs/art-style.md on the jointed figure every look shares (Figure.swift).
///
/// A worker takes the look of its owner's age
/// (`SpriteSubject.of(_:ownerAge:)`), so this source supplies
/// `SpriteSubject.unit(.worker, .alchemy)`, the craftsman, in every pose that
/// the artwork's checklist (`SpriteKey.required(through:)`) lists for it:
/// standing, walking, working and fighting. Each pose is a cycle of 12 frames (`SpriteKey.frame` 0 to 11).
/// Every other key returns nil. Each kind is drawn in the five views (ruled
/// 2026-11-21; `SpriteKey.view`), the other three facings mirroring them.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given
/// (`SpriteCache` in MapDrawing), by the whole key, its view included.
public struct AlchemyPeopleSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .cannons, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .alchemy) = key.subject else { return false }
            return AlchemyPeopleLooks.look(kind) != nil
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The kinds drawn in all five views.
    static let viewed: Set<UnitKind> = [.worker]

    public func drawsViews(of subject: SpriteSubject) -> Bool {
        if case .unit(let kind, .alchemy) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject,
              let look = AlchemyPeopleLooks.look(kind) else { return nil }
        return look.render(key.pose, frame: key.frame, canvas: .person, view: key.view)?.sprite(anchor: Canvas.person.anchor)
    }
}

/// Which look draws each kind.
enum AlchemyPeopleLooks {
    static func look(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .worker: AlchemyPeopleCraftsman()
        case .spearman, .swordsman, .horseman, .knight, .musketeer, .cannon, .rifleman, .fieldGun, .car, .boat: nil
        }
    }
}

/// Geometry the Alchemy people and warriors share for the views other than
/// the side (ruled 2026-11-21: five views drawn). It follows the figure kit
/// (FigureViews.swift): the figure's space has x toward its front, y downward
/// and z toward its right side, and a view turns it by its yaw and drops the
/// depth. The arms and legs are found as the kit finds them, so that what a
/// look draws along them meets the kit's own hands and feet.
enum AlchemyViews {
    /// The cosine and sine of the view's turn.
    static func turn(_ view: SpriteView) -> (c: Double, s: Double) {
        let r = view.yaw * .pi / 180
        return (cos(r), sin(r))
    }

    /// A point of a space turned as the figure's is, on the screen, and its depth toward the viewer.
    static func project(_ view: SpriteView, _ x: Double, _ y: Double, _ z: Double) -> (point: P, depth: Double) {
        let (c, s) = turn(view)
        return (P(x * c - z * s, y), x * s + z * c)
    }

    /// The view a figure is seen in when it faces the other way from the unit
    /// it belongs to, drawn mirrored: the view of the opposite turn.
    static func opposite(_ view: SpriteView) -> SpriteView {
        switch view {
        case .side: .side
        case .frontQuarter: .backQuarter
        case .front: .back
        case .back: .front
        case .backQuarter: .frontQuarter
        }
    }

    /// The lean as the view shows it, as `Drawing.figure` turns the body.
    static func lean(_ d: Drawing) -> Double { d.rig.lean * cos(d.yaw * .pi / 180) }

    /// A point of the body where it falls in the picture in this view, after
    /// the lean and the bob (the view's form of `Drawing.world`).
    static func world(_ d: Drawing, _ p: P) -> P { p.rotated(lean(d), about: Drawing.hips) + P(0, d.bob) }

    /// A point of the picture in the body's own units in this view (the inverse of `world`).
    static func body(_ d: Drawing, _ p: P) -> P { (p - P(0, d.bob)).rotated(-lean(d), about: Drawing.hips) }

    /// Draws `content` in the picture's own units from inside `Drawing.figure`,
    /// undoing the view's lean and the bob, as a look draws what stands on
    /// the ground or keeps its own direction whatever the body does.
    static func inPicture(_ d: inout Drawing, _ content: (inout SVG) -> Void) {
        d.svg.raw("<g transform=\"rotate(\(num(-lean(d))) \(num(Drawing.hips.x)) \(num(Drawing.hips.y))) translate(0,\(num(-d.bob)))\">")
        content(&d.svg)
        d.svg.raw("</g>")
    }

    /// Draws `content`, a long thing drawn from `at` along `degrees` (as it
    /// shows on the screen), shortened along that direction by `k`: a musket
    /// or a lance pointing toward the viewer or away.
    static func foreshortened(_ svg: inout SVG, at a: P, degrees: Double, by k: Double, _ content: (inout SVG) -> Void) {
        let u = P.direction(degrees)
        let angle = atan2(u.y, u.x) * 180 / .pi
        svg.raw("<g transform=\"translate(\(num(a.x)),\(num(a.y))) rotate(\(num(angle))) scale(\(num(k)),1) rotate(\(num(-angle))) "
                + "translate(\(num(-a.x)),\(num(-a.y)))\">")
        content(&svg)
        svg.raw("</g>")
    }

    /// A limb in this view: its root, its joint and its end on the screen
    /// (before the bob and the lean), its depth, and whether it is the
    /// figure's right one, the one nearer the viewer in profile.
    struct Limb {
        var points: [P]
        var depth: Double
        var right: Bool
        /// For a leg, the toe on the screen.
        var toe: P?
        var root: P { points[0] }
        var joint: P { points[1] }
        var end: P { points[2] }
    }

    /// An arm in this view, found as the kit finds it.
    static func arm(_ d: Drawing, right: Bool) -> Limb {
        let shoulder = P(0.5, -44 - d.rig.lift)
        let limb = right ? d.rig.frontArm : d.rig.backArm
        let elbow = shoulder + P.direction(limb.upper) * Joints.upperArm
        let hand = elbow + P.direction(limb.upper + limb.bend) * Joints.forearm
        let z = right ? Drawing.shoulderSpread : -Drawing.shoulderSpread
        let points = [shoulder, elbow, hand].map { d.project($0.x, $0.y, z) }
        return Limb(points: points.map(\.point), depth: (points[1].depth + points[2].depth) / 2, right: right)
    }

    /// The arms that belong behind the body (`behind`) or before it, as the kit sorts them (`Drawing.armBehind`).
    static func arms(_ d: Drawing, behind: Bool) -> [Limb] {
        [false, true].filter { d.armBehind(front: $0) == behind }.map { arm(d, right: $0) }
    }

    /// A leg in this view, found as the kit finds it; drawn inside a group turned by `-lean(d)` about the hips.
    static func leg(_ d: Drawing, right: Bool) -> Limb {
        let hip = P(0.5, -16)
        let limb = right ? d.rig.frontLeg : d.rig.backLeg
        let knee = hip + P.direction(limb.upper) * Joints.thigh
        let foot = knee + P.direction(limb.upper - limb.bend) * Joints.shin
        let z = right ? Drawing.hipSpread : -Drawing.hipSpread
        let points = [hip, knee, foot].map { d.project($0.x, $0.y, z) }
        let toe = d.project(foot.x + 4.5, foot.y + 0.3, z).point
        return Limb(points: points.map(\.point), depth: points[1].depth, right: right, toe: toe)
    }

    /// Both legs, the farther first.
    static func legs(_ d: Drawing) -> [Limb] {
        [leg(d, right: false), leg(d, right: true)].sorted { $0.depth < $1.depth }
    }

    /// A direction in the figure's upright plane (degrees from straight down,
    /// positive toward the front) as it shows on the screen in this view, and
    /// how much of a length along it shows: a tool pointing at the viewer is short.
    static func along(_ view: SpriteView, _ degrees: Double) -> (degrees: Double, length: Double) {
        let u = P.direction(degrees)
        let x = u.x * turn(view).c, y = u.y
        let length = (x * x + y * y).squareRoot()
        // Straight at the viewer or away, it shows as a point; it is drawn upright, as short as it may be.
        guard length > 1e-6 else { return (180, 0) }
        return (atan2(x, y) * 180 / .pi, length)
    }

    /// Where a point drawn on the surface of a garment in profile falls in
    /// this view, and its depth toward the viewer (negative where the body
    /// hides it). The garment's level through the point is taken as a round
    /// section, as `Drawing.turned` takes it; the point lies on the side the
    /// profile shows (`side` 1), or on the other side, mirrored (`side` -1).
    /// A point above or below the garment takes the section of its top or its hem.
    static func surface(_ view: SpriteView, _ p: P, on shape: [P], side: Double = 1) -> (point: P, depth: Double) {
        let top = shape.map(\.y).min()!, bottom = shape.map(\.y).max()!
        let level = min(max(p.y, top + (bottom - top) * 0.002), bottom - (bottom - top) * 0.002)
        var xs: [Double] = []
        for k in shape.indices {
            let a = shape[k], b = shape[(k + 1) % shape.count]
            if (a.y - level) * (b.y - level) <= 0, a.y != b.y {
                xs.append(a.x + (b.x - a.x) * (level - a.y) / (b.y - a.y))
            }
        }
        guard let low = xs.min(), let high = xs.max(), high - low > 0.01 else {
            return project(view, p.x, p.y, 0)
        }
        let centre = (low + high) / 2, half = (high - low) / 2
        let cosine = min(max((p.x - centre) / half, -1), 1)
        let sine = (1 - cosine * cosine).squareRoot()
        return project(view, centre + half * cosine, p.y, side * half * 0.95 * sine)
    }

    /// The point of a garment's level `y` (see `surface`) at `angle` degrees
    /// round from its front toward the figure's right (`side` 1) or its left
    /// (`side` -1), on the screen, and its depth.
    static func around(_ view: SpriteView, _ y: Double, angle: Double, on shape: [P], side: Double = 1) -> (point: P, depth: Double) {
        var xs: [Double] = []
        let top = shape.map(\.y).min()!, bottom = shape.map(\.y).max()!
        let l = min(max(y, top + (bottom - top) * 0.002), bottom - (bottom - top) * 0.002)
        for k in shape.indices {
            let a = shape[k], b = shape[(k + 1) % shape.count]
            if (a.y - l) * (b.y - l) <= 0, a.y != b.y { xs.append(a.x + (b.x - a.x) * (l - a.y) / (b.y - a.y)) }
        }
        let low = xs.min() ?? 0, high = xs.max() ?? 0
        let centre = (low + high) / 2, half = (high - low) / 2, r = angle * .pi / 180
        return project(view, centre + half * cos(r), y, side * half * 0.95 * sin(r))
    }

    /// A panel worn over the front of a garment (an apron, a stole, the
    /// front of a doublet), drawn in profile from `back` to `front` along the
    /// body between `top` and `bottom`: in this view it wraps the front from
    /// the figure's right side to its left, as much of it as faces the viewer.
    /// Empty where none of it does.
    static func panel(_ view: SpriteView, back: Double, front: Double, top: (Double) -> Double, bottom: (Double) -> Double,
                      on shape: [P], steps: Int = 8, wraps: Bool = true) -> [P] {
        // The columns across it, each kept where it faces the viewer; the longest unbroken run is drawn.
        var runs: [[(P, P)]] = [[]]
        let sides: [Double] = wraps ? [1, -1] : [1]
        for side in sides {
            for i in 0...steps {
                if side < 0 && i == 0 { continue }
                let t = Double(side > 0 ? i : steps - i) / Double(steps)
                let x = mix(back, front, t)
                let a = surface(view, P(x, top(x)), on: shape, side: side)
                let b = surface(view, P(x, bottom(x)), on: shape, side: side)
                if a.depth > -0.6 && b.depth > -0.6 {
                    runs[runs.count - 1].append((a.point, b.point))
                } else if !runs[runs.count - 1].isEmpty {
                    runs.append([])
                }
            }
        }
        let columns = runs.max { $0.count < $1.count } ?? []
        guard columns.count > 1 else { return [] }
        return columns.map(\.0) + columns.reversed().map(\.1)
    }

    /// Points drawn on a garment in profile (see `surface`), where they fall
    /// on it in this view and raised with the breath; nil where any of them is
    /// hidden by the body.
    static func worn(_ d: Drawing, _ points: [P], on shape: [P], side: Double = 1, margin: Double = 0) -> [P]? {
        var out: [P] = []
        for p in points {
            let (q, depth) = surface(d.view, p, on: shape, side: side)
            guard depth > -margin else { return nil }
            out.append(d.up(q))
        }
        return out
    }

    /// Draws `content` squeezed across by `k` about the point `about`: a small
    /// thing drawn in profile, seen turned aside.
    static func squeezed(_ svg: inout SVG, about p: P, by k: Double, _ content: (inout SVG) -> Void) {
        svg.raw("<g transform=\"translate(\(num(p.x)),\(num(p.y))) scale(\(num(k)),1) translate(\(num(-p.x)),\(num(-p.y)))\">")
        content(&svg)
        svg.raw("</g>")
    }

    /// A thing standing on the ground, drawn in profile from `x0` to `x1`
    /// along the figure's space with its near face at `z + half`, seen in this
    /// view: the profile squeezed as far as the view turns it aside (`side`),
    /// and its end toward the viewer (`end`, given the end's middle on the
    /// screen and its half width there), as the car's near side and its nose are.
    static func solid(_ svg: inout SVG, _ view: SpriteView, from x0: Double, to x1: Double, z: Double, half: Double,
                      side: (inout SVG) -> Void, end: (inout SVG, Double, Double) -> Void) {
        let (c, s) = turn(view)
        let endX = s > 0 ? x1 : x0
        if c > 0.01 {
            svg.raw("<g transform=\"translate(\(num(-(z + half) * s)),0) scale(\(num(c)),1)\">")
            side(&svg)
            svg.raw("</g>")
        }
        if abs(s) > 0.01 { end(&svg, endX * c - z * s, half * abs(s)) }
    }

    /// A cubic curve's points after its start, for building a shape of straight segments.
    static func cubic(_ a: P, _ b: P, _ c: P, _ e: P, steps: Int = 6) -> [P] {
        (1...steps).map { i in
            let t = Double(i) / Double(steps), m = 1 - t
            return a * (m * m * m) + b * (3 * m * m * t) + c * (3 * m * t * t) + e * (t * t * t)
        }
    }

    /// A quadratic curve's points after its start.
    static func quad(_ a: P, _ b: P, _ e: P, steps: Int = 5) -> [P] {
        (1...steps).map { i in
            let t = Double(i) / Double(steps), m = 1 - t
            return a * (m * m) + b * (2 * m * t) + e * (t * t)
        }
    }

    /// The outline of a cap or a helm over the head in this view, in the
    /// head's units: its rim runs round the head `radius` out from the head's
    /// upright axis, at `front` over the brow and `back` at the nape, and its
    /// crown rises to `top`, highest over `crest` (where the crown's top is in
    /// profile, along the head). The visible rim runs from the screen's right
    /// to its left, then the crown back over the top.
    static func dome(_ view: SpriteView, radius r: Double, front: Double, back: Double, top: Double, crest: Double = 0,
                     steps: Int = 10) -> [P] {
        let rim = rim(view, radius: r, front: front, back: back, steps: steps)
        let (c, _) = turn(view)
        let left = rim.last!, right = rim.first!
        let apex = crest * c
        var crown: [P] = []
        for i in 1..<steps {
            let t = Double(i) / Double(steps)
            let x = t < 0.5 ? mix(left.x, apex, t * 2) : mix(apex, right.x, t * 2 - 1)
            let base = mix(left.y, right.y, t)
            // A round crown: full height over the apex, falling to the rim at the sides.
            let k = t < 0.5 ? t * 2 : (1 - t) * 2
            crown.append(P(x, base - (base - top) * (1 - pow(1 - k, 2.2))))
        }
        return rim + crown
    }

    /// The part of a rim round the head that faces the viewer, from the
    /// screen's right to its left (see `dome`).
    static func rim(_ view: SpriteView, radius r: Double, front: Double, back: Double, steps: Int = 10) -> [P] {
        let yaw = view.yaw * .pi / 180
        let mid = (front + back) / 2, half = (front - back) / 2
        return (0...steps).map { i in
            let phi = -yaw + .pi * Double(i) / Double(steps)
            return P(r * cos(phi + yaw), mid + half * cos(phi))
        }
    }

    /// The point of a rim round the head (see `dome`) at `phi` radians from
    /// the front toward the figure's right, on the screen, and its depth.
    static func onRim(_ view: SpriteView, radius r: Double, front: Double, back: Double, phi: Double) -> (point: P, depth: Double) {
        let mid = (front + back) / 2, half = (front - back) / 2
        return project(view, r * cos(phi), mid + half * cos(phi), r * sin(phi))
    }
}
