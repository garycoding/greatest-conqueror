// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// A person's car (ruled 2026-11-21): a modern electric four-door saloon painted
/// all over in its team's colour, drawn in the Cartoon
/// Modern style of docs/art-style.md (`CarSaloon`).
///
/// The car belongs to no age, and its key is `SpriteSubject.unit(.car, .stone)`
/// (`SpriteSubject.of(_:ownerAge:)`). This source supplies it in the poses that
/// the artwork's checklist (`SpriteKey.required(through:)`) lists for it:
/// standing, walking (driving) and working, which is the car parked, drawn as
/// standing. Each pose is a cycle of 12 frames (`SpriteKey.frame` 0 to 11). The
/// car has no attack, so there is no fighting pose. Every other key returns nil.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given.
public struct CarSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .stone, catalogue: catalogue).filter { key in
            guard case .unit(.car, .stone) = key.subject else { return false }
            return CarSaloon.drawn(key.pose) != nil
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              let pose = CarSaloon.drawn(key.pose) else { return nil }
        return CarSaloon.render(pose, frame: key.frame, view: key.view)?.sprite(anchor: CarSaloon.canvas.anchor)
    }

    /// The car is drawn in all five views (ruled 2026-11-21).
    public func drawsViews(of subject: SpriteSubject) -> Bool { subject == .unit(.car, .stone) }
}
