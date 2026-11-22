// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Dispatch
import GameCore
import Synchronization

/// The boats' art of the Stone age (ruled 2026-11-21), in the Cartoon Modern
/// style of docs/art-style.md:
///
/// - The boat in its Stone-age look, the dugout (`SpriteSubject.unit(.fishingBoat,
///   .stone)`): a canoe hollowed from a log, paddled by one person, in the
///   five views, standing, walking (paddling) and working (spearing fish),
///   each a cycle of 12 frames. It has no attack, so no fighting pose. It
///   carries the team's colour on its hull and on its paddler, sits on the
///   water with a waterline and a ring about it, and casts no shadow. Its
///   anchor is the middle of its hull on the waterline (`StoneDugout`).
/// - The fish (`SpriteSubject.site(.fish)`, `complete`): one water tile of a
///   shoal, fish under the water and one leaping from rings, a cycle of 12
///   frames which the drawing runs ahead tile by tile.
/// - The rock that rises from the water (`SpritePose.afloat`): gold, the rock
///   of its site cut at a waterline, with ripples about it and no shadow, at frame 0.
///
/// The boat house is drawn with the Stone age's buildings
/// (`StoneBuildingSprites`). Every other key gives nil. A boat's pose is drawn
/// whole, its 12 frames together, when its first frame is asked for, and kept.
public final class StoneBoatSprites: ViewedSpriteSource {
    /// The boat's poses the artwork's checklist asks for, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>
    private let cache = Mutex<[SpriteKey: SpriteImage]>([:])

    /// The rocks drawn rising from the water.
    public static let rocks: [SiteKind] = [.gold]

    public init(catalogue: Catalogue = .standard) {
        // The fishing boat belongs to the age of farms now (requirement 17), so
        // the checklist no longer asks for the dugout; it is still drawn.
        poses = [SpritePose.standing, .walking, .working, .fighting].filter(StoneDugout.drawn)
            .map { SpriteKey(.unit(.fishingBoat, .stone), $0) }
        supplied = Set(poses)
    }

    /// Every key this source supplies, in the side view: each of the boat's
    /// poses and the fish at each of their frames, and each rock afloat.
    public var keys: [SpriteKey] {
        let frames = 0..<SpriteKey.framesPerPose
        return poses.flatMap { pose in frames.map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
            + frames.map { SpriteKey(.site(.fish), .complete, frame: $0) }
            + Self.rocks.map { SpriteKey(.site($0), .afloat) } + [SpriteKey(.outcrop, .afloat)]
    }

    /// The dugout is drawn in all five views (ruled 2026-11-21).
    public func drawsViews(of subject: SpriteSubject) -> Bool { subject == .unit(.fishingBoat, .stone) }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame) else { return nil }
        if let known = cache.withLock({ $0[key] }) { return known }
        switch key.subject {
        case .unit(.fishingBoat, .stone):
            guard supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)) else { return nil }
            let drawn = Self.drawPose(key.pose, view: key.view)
            cache.withLock { cache in
                for (frame, sprite) in drawn.enumerated() {
                    if let sprite { cache[SpriteKey(key.subject, key.pose, frame: frame, view: key.view)] = sprite }
                }
            }
            return drawn[key.frame]
        case .site(.fish):
            guard key.pose == .complete, key.view == .side else { return nil }
            return keep(key, StoneBoatsWater.fish(frame: key.frame))
        case .outcrop:
            guard key.pose == .afloat, key.frame == 0, key.view == .side else { return nil }
            return keep(key, StoneBoatsWater.outcropAfloat())
        case .site(let kind):
            guard key.pose == .afloat, key.frame == 0, key.view == .side, Self.rocks.contains(kind) else { return nil }
            return keep(key, StoneBoatsWater.afloat(kind))
        default:
            return nil
        }
    }

    private func keep(_ key: SpriteKey, _ made: SpriteImage?) -> SpriteImage? {
        guard let made else { return nil }
        return cache.withLock { cache in
            if let known = cache[key] { return known }
            cache[key] = made
            return made
        }
    }

    /// The 12 frames of one of the boat's poses in a view, drawn side by side on the machine's cores.
    static func drawPose(_ pose: SpritePose, view: SpriteView) -> [SpriteImage?] {
        let frames = Mutex<[Int: SpriteImage]>([:])
        DispatchQueue.concurrentPerform(iterations: SpriteKey.framesPerPose) { frame in
            guard let drawn = StoneDugout.render(pose, frame: frame, view: view) else { return }
            let sprite = drawn.sprite(anchor: StoneDugout.canvas.anchor)
            frames.withLock { $0[frame] = sprite }
        }
        return frames.withLock { drawn in (0..<SpriteKey.framesPerPose).map { drawn[$0] } }
    }
}

/// The colours of the water's marks and of the boats: shades of the Stone
/// age's palette (docs/art-style.md, "Palettes") and of the water's ground.
enum BoatInk {
    /// Foam, ripples and splashes: the palette's light, warm against the cool
    /// water and its own pale marks, so that they read as something happening.
    static let foam = Ink.light
    /// Fish seen under the water, and the water's darkness about a rock.
    static let underwater = "#2f3754"
    /// A fish's back, and its belly.
    static let fishBack = "#6c7895"
    static let fishBelly = "#e9e4da"
    /// The dugout's hollow: its far inner wall, and the deeper floor.
    static let hollowWall = Ink.handle
    static let hollowFloor = "#3b2d27"
    /// The dugout's outer side in shade, and the light along its gunwale.
    static let hullShade = "#704826"
    static let gunwaleLight = "#b98a58"
}
