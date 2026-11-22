// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The people new to Greatest Conqueror in the age of hospitals, drawn in the
/// Industrial look in the Cartoon Modern style of docs/art-style.md on the
/// jointed figure every look shares (Figure.swift): the doctor, and knight 3,
/// the cavalryman who follows the Alchemy knight (`AlchemyWarriorsKnight`).
///
/// Both kinds first appear in the age of hospitals, and each is drawn only in
/// the look of that age (`SpriteSubject.of(_:ownerAge:)`), so this source
/// supplies `SpriteSubject.unit(.doctor, .industrial)` standing, walking and
/// working (healing; the doctor does not attack, so he has no fighting pose),
/// and `SpriteSubject.unit(.knight3, .industrial)` standing, walking and
/// fighting (a warfighter never works, and the drawing falls back to standing
/// where a pose is missing). Each pose is a cycle of 12 frames
/// (`SpriteKey.frame` 0 to 11), and each kind is drawn in the five views
/// (ruled 2026-11-21; `SpriteKey.view`), the other three facings mirroring
/// them. Every other key returns nil.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given.
public struct IndustrialNewPeopleSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .hospitals, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .industrial) = key.subject, IndustrialNewPeopleLooks.look(kind) != nil else { return false }
            return !(kind.isWarfighter && key.pose == .working)
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The kinds drawn in all five views.
    static let viewed: Set<UnitKind> = [.doctor, .knight3]

    public func drawsViews(of subject: SpriteSubject) -> Bool {
        if case .unit(let kind, .industrial) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject,
              let look = IndustrialNewPeopleLooks.look(kind) else { return nil }
        let canvas = IndustrialNewPeopleLooks.canvas(kind)
        return look.render(key.pose, frame: key.frame, canvas: canvas, view: key.view)?.sprite(anchor: canvas.anchor)
    }
}

/// Which look draws each kind, and on what canvas.
enum IndustrialNewPeopleLooks {
    static func look(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .doctor: IndustrialNewPeopleDoctor()
        case .knight3: IndustrialNewPeopleCavalryman()
        default: nil
        }
    }

    static func canvas(_ kind: UnitKind) -> Canvas {
        switch kind {
        case .knight3: IndustrialNewPeopleCavalryman.canvas
        default: .person
        }
    }
}

/// The few colours the new people need beyond the Industrial look's
/// (`IndustrialPeopleInk`, `IndustrialWarriorsInk`).
enum IndustrialNewPeopleInk {
    /// The cavalryman's dapple-grey charger, with its shade and its dapples: a
    /// coat unlike the horseman's bay and the knight's dark bay, so that the
    /// three tiers are told apart, and darker than the cuirass, so that the
    /// rider stands out against it.
    static let grey = "#938c83"
    static let greyShade = "#6a645c"
    static let dapple = "#b6afa3"
    /// The bandage's linen, and its shade.
    static let linen = "#f6f0e2"
    static let linenShade = "#d9cfba"
    /// The brown glass of a medicine bottle.
    static let bottle = "#7a4a22"
}
