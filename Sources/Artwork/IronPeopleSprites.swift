// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The worker in the Iron look, drawn in the Cartoon Modern style of
/// docs/art-style.md on the jointed figure every look shares (Figure.swift).
///
/// A worker takes the look of its owner's age
/// (`SpriteSubject.of(_:ownerAge:)`), so this source supplies
/// `SpriteSubject.unit(.worker, .iron)`, the farmer, in every pose that the
/// artwork's checklist (`SpriteKey.required(through:)`) lists for it:
/// standing, walking, working and fighting. Each pose is a cycle of 12 frames (`SpriteKey.frame` 0 to 11).
/// Every other key returns nil. The kinds in `viewed` are drawn in all five
/// views (ruled 2026-11-21); the others in the side view alone.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given
/// (`SpriteCache` in MapDrawing), by the whole key, its view included.
public struct IronPeopleSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .ships, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .iron) = key.subject else { return false }
            return IronPeopleLooks.look(kind) != nil
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The kinds drawn in all five views so far.
    static let viewed: Set<UnitKind> = [.worker]

    public func drawsViews(of subject: SpriteSubject) -> Bool {
        if case .unit(let kind, .iron) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject,
              let look = IronPeopleLooks.look(kind) else { return nil }
        let canvas = IronPeopleLooks.canvas(kind)
        return look.render(key.pose, frame: key.frame, canvas: canvas, view: key.view)?.sprite(anchor: canvas.anchor)
    }
}

/// Which look draws each kind, and on what canvas.
enum IronPeopleLooks {
    static func look(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .worker: IronPeopleFarmer()
        case .soldier1, .soldier2, .knight1, .knight2, .soldier3, .cannon1, .soldier4, .cannon2, .car, .fishingBoat,
             .doctor, .knight3, .navyShip, .founder: nil
        }
    }

    /// The person's canvas.
    static func canvas(_ kind: UnitKind) -> Canvas { .person }
}
