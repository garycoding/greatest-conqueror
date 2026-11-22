// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Dispatch
import GameCore
import Synchronization

/// The boat's art of the Alchemy age (ruled 2026-11-21), in the Cartoon Modern
/// style of docs/art-style.md: the fishing smack (`SpriteSubject.unit(.boat,
/// .alchemy)`), a small gaff-rigged sailing boat worked by one fisherman, in
/// the five views, standing (hove to, its sail slack), walking (under sail)
/// and working (hauling a net, or working a rock), each a cycle of 12 frames.
/// It has no attack, so no fighting pose. It carries the team's colour on its
/// mainsail, its masthead pennant, the strake along its hull and the
/// fisherman's neckerchief, sits on the water with a waterline and a ring about
/// it, and casts no shadow. Its anchor is the middle of its hull on the
/// waterline (`AlchemySmack`).
///
/// The boat house is drawn with the older buildings in the Alchemy look
/// (`AlchemyOldBuildingSprites`); the fish and the rocks afloat are the same in
/// every age and drawn by the Stone age's batch (`StoneBoatSprites`). Every
/// other key gives nil. A pose is drawn whole, its 12 frames together, when its
/// first frame is asked for, and kept.
public final class AlchemyBoatSprites: ViewedSpriteSource {
    /// The boat's poses the artwork's checklist asks for, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>
    private let cache = Mutex<[SpriteKey: SpriteImage]>([:])

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .cannons, catalogue: catalogue).filter { key in
            guard case .unit(.boat, .alchemy) = key.subject else { return false }
            return AlchemySmack.drawn(key.pose)
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies, in the side view: each of the boat's poses at each of their frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The smack is drawn in all five views (ruled 2026-11-21).
    public func drawsViews(of subject: SpriteSubject) -> Bool { subject == .unit(.boat, .alchemy) }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame), key.subject == .unit(.boat, .alchemy),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)) else { return nil }
        if let known = cache.withLock({ $0[key] }) { return known }
        let drawn = Self.drawPose(key.pose, view: key.view)
        cache.withLock { cache in
            for (frame, sprite) in drawn.enumerated() {
                if let sprite { cache[SpriteKey(key.subject, key.pose, frame: frame, view: key.view)] = sprite }
            }
        }
        return drawn[key.frame]
    }

    /// The 12 frames of one of the boat's poses in a view, drawn side by side on the machine's cores.
    static func drawPose(_ pose: SpritePose, view: SpriteView) -> [SpriteImage?] {
        let frames = Mutex<[Int: SpriteImage]>([:])
        DispatchQueue.concurrentPerform(iterations: SpriteKey.framesPerPose) { frame in
            guard let drawn = AlchemySmack.render(pose, frame: frame, view: view) else { return }
            let sprite = drawn.sprite(anchor: AlchemySmack.canvas.anchor)
            frames.withLock { $0[frame] = sprite }
        }
        return frames.withLock { drawn in (0..<SpriteKey.framesPerPose).map { drawn[$0] } }
    }
}
