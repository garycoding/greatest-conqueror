// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The worker in the Industrial look, drawn in the Cartoon Modern style of
/// docs/art-style.md on the jointed figure every look shares (Figure.swift).
///
/// A worker takes the look of its owner's age
/// (`SpriteSubject.of(_:ownerAge:)`), so this source supplies
/// `SpriteSubject.unit(.worker, .industrial)`, the factory hand, in every pose
/// that the artwork's checklist (`SpriteKey.required(through:)`) lists for it:
/// standing, walking, working and fighting. Each pose is a cycle of 12
/// frames (`SpriteKey.frame` 0 to 11). Every other key returns nil.
///
/// Each kind it has finished is drawn in all five views (ruled 2026-11-21),
/// the key's view passed to the drawing (`viewed`); for the rest it answers
/// the side alone.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given
/// (`SpriteCache` in MapDrawing).
public struct IndustrialPeopleSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .hospitals, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .industrial) = key.subject else { return false }
            return IndustrialPeopleLooks.look(kind) != nil
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
        if case .unit(let kind, .industrial) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject,
              let look = IndustrialPeopleLooks.look(kind) else { return nil }
        return look.render(key.pose, frame: key.frame, canvas: .person, view: key.view)?.sprite(anchor: Canvas.person.anchor)
    }
}

/// Which look draws each kind.
enum IndustrialPeopleLooks {
    static func look(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .worker: IndustrialPeopleFactoryHand()
        case .soldier1, .soldier2, .knight1, .knight2, .soldier3, .cannon1,
             .soldier4, .cannon2, .car, .fishingBoat,
             .doctor, .knight3, .navyShip, .founder: nil
        }
    }
}
