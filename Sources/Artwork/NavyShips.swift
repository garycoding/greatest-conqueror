// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Dispatch
import GameCore
import Synchronization

/// The navy ship's art (step 8 of the plan), in the Cartoon Modern style of
/// docs/art-style.md. The navy ship is one kind upgraded at each age, so it is
/// drawn in its owner's age's look (`SpriteSubject.of`): from the age of ships
/// in the Iron look, a war galley (`NavyShipIron`); from the age of cannons in
/// the Alchemy look, a galleon (`NavyShipAlchemy`); from the age of hospitals
/// in the Industrial look, an ironclad under steam (`NavyShipIndustrial`).
/// Each is about half as long again as the fishing boat of its look, in the
/// five views, standing (riding at anchor), walking (under way) and fighting
/// (firing its guns ahead, over the bow, since the ship turns to face its
/// target), each a cycle of 12 frames. It has no working pose: a navy ship
/// never works (it is drawn standing whilst it makes units at the shore).
/// Each carries the team's colour on its hull, its flags and its sails or
/// funnels; it sits on the water with a waterline and a ring about it, and
/// casts no shadow. Its anchor is the middle of its hull on the waterline.
/// Every other key gives nil. A pose is drawn whole, its 12 frames together,
/// when its first frame is asked for, and kept.
public final class NavyShipSprites: ViewedSpriteSource {
    /// The looks the navy ship is drawn in.
    static let looks: [Look] = [.iron, .alchemy, .industrial]

    /// The ship's poses the artwork's checklist asks for and the art draws, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>
    private let cache = Mutex<[SpriteKey: SpriteImage]>([:])

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .hospitals, catalogue: catalogue).filter { key in
            guard case .unit(.navyShip, let look) = key.subject, Self.looks.contains(look) else { return false }
            return NavyShip.drawn(key.pose)
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies, in the side view: each of the ship's poses at each of their frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The navy ship is drawn in all five views, in every look it has.
    public func drawsViews(of subject: SpriteSubject) -> Bool {
        guard case .unit(.navyShip, let look) = subject else { return false }
        return Self.looks.contains(look)
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame), case .unit(.navyShip, let look) = key.subject,
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)) else { return nil }
        if let known = cache.withLock({ $0[key] }) { return known }
        let drawn = Self.drawPose(look, key.pose, view: key.view)
        cache.withLock { cache in
            for (frame, sprite) in drawn.enumerated() {
                if let sprite { cache[SpriteKey(key.subject, key.pose, frame: frame, view: key.view)] = sprite }
            }
        }
        return drawn[key.frame]
    }

    /// The 12 frames of one of the ship's poses in a view, drawn side by side on the machine's cores.
    static func drawPose(_ look: Look, _ pose: SpritePose, view: SpriteView) -> [SpriteImage?] {
        let frames = Mutex<[Int: SpriteImage]>([:])
        DispatchQueue.concurrentPerform(iterations: SpriteKey.framesPerPose) { frame in
            guard let drawn = NavyShip.render(look, pose, frame: frame, view: view) else { return }
            let sprite = drawn.sprite(anchor: NavyShip.canvas(look).anchor)
            frames.withLock { $0[frame] = sprite }
        }
        return frames.withLock { drawn in (0..<SpriteKey.framesPerPose).map { drawn[$0] } }
    }
}

/// The navy ship in each of its looks.
enum NavyShip {
    /// Whether the ship has the pose: standing, walking and fighting.
    static func drawn(_ pose: SpritePose) -> Bool { pose == .standing || pose == .walking || pose == .fighting }

    /// The canvas of a look: room for the hull in every view, its masts, the smoke of its guns, the wake and the ring.
    static func canvas(_ look: Look) -> Canvas {
        switch look {
        case .alchemy: NavyShipAlchemy.canvas
        case .industrial: NavyShipIndustrial.canvas
        default: NavyShipIron.canvas
        }
    }

    /// A frame of a pose in a view, as a sprite's picture and mask, grained alike, on the look's canvas or another scale of it.
    static func render(_ look: Look, _ pose: SpritePose, frame: Int, view: SpriteView = .side, canvas: Canvas? = nil) -> Rendered? {
        guard drawn(pose), NavyShipSprites.looks.contains(look) else { return nil }
        return Raster.render(on: canvas ?? Self.canvas(look)) { svg in
            switch look {
            case .alchemy: NavyShipAlchemy.draw(&svg, view, pose, frame)
            case .industrial: NavyShipIndustrial.draw(&svg, view, pose, frame)
            default: NavyShipIron.draw(&svg, view, pose, frame)
            }
        }
    }
}
