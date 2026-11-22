// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Dispatch
import GameCore
import Synchronization

/// The game's artwork, drawn in the Cartoon Modern style of docs/art-style.md.
///
/// This first batch holds the people of the Stone age: the worker (a hunter),
/// the scholar (an elder), the engineer (a builder), the clubman, the slinger
/// and the founder, each in its Stone-age look (`SpriteSubject.unit(kind,
/// .stone)`), standing, walking, working and, where the catalogue gives the kind
/// an attack, fighting. Each pose is a cycle of 12 frames (`SpriteKey.frame` 0
/// to 11). Every other key returns `nil`, and the drawing shows its placeholder.
///
/// Each picture is written as SVG, drawn by macOS, and grained by Core Image
/// with the same grain in every frame (docs/decisions.md, "Verifications"). A
/// pose's frames are drawn together when the first of them is asked for, and
/// kept; the source can therefore be called from the main actor during drawing.
public final class CartoonSprites: ViewedSpriteSource {
    /// The frames in each pose's cycle, shown at 12 a second (docs/art-style.md, "Movement").
    public static let framesPerPose = 12

    /// The keys this source supplies, each at frame 0: every person of the
    /// Stone age, in each pose the artwork's checklist asks of it
    /// (`SpriteKey.required(through: .stone)`).
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>
    private let cache = Mutex<[SpriteKey: SpriteImage]>([:])

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .stone, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .stone) = key.subject, StonePeople.person(kind)?.rig(key.pose, 0) != nil else { return false }
            return true
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<Self.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The kinds drawn in all five views (ruled 2026-11-21): every Stone person,
    /// the worker first as the exemplar.
    static let viewed: Set<UnitKind> = [.worker, .scholar, .engineer, .clubman, .slinger, .founder]

    public func drawsViews(of subject: SpriteSubject) -> Bool {
        if case .unit(let kind, .stone) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<Self.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject else { return nil }
        if let known = cache.withLock({ $0[key] }) { return known }
        let drawn = Self.drawPose(kind, key.pose, view: key.view)
        cache.withLock { cache in
            for (frame, sprite) in drawn.enumerated() {
                if let sprite { cache[SpriteKey(key.subject, key.pose, frame: frame, view: key.view)] = sprite }
            }
        }
        return drawn[key.frame]
    }

    /// The 12 frames of a pose, drawn side by side on the machine's cores.
    static func drawPose(_ kind: UnitKind, _ pose: SpritePose, canvas: Canvas = .person,
                         view: SpriteView = .side) -> [SpriteImage?] {
        guard let look = StonePeople.person(kind) else { return Array(repeating: nil, count: framesPerPose) }
        let frames = Mutex<[Int: SpriteImage]>([:])
        DispatchQueue.concurrentPerform(iterations: framesPerPose) { frame in
            guard let drawn = look.render(pose, frame: frame, canvas: canvas, view: view) else { return }
            let sprite = drawn.sprite(anchor: canvas.anchor)
            frames.withLock { $0[frame] = sprite }
        }
        return frames.withLock { drawn in (0..<framesPerPose).map { drawn[$0] } }
    }
}
