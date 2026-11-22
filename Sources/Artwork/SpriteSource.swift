// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore

/// The point of an image at which it stands, as a fraction of the image with
/// (0, 0) at the bottom left, as SpriteKit's anchor point has it.
public struct SpriteAnchor: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// One sprite, ready to draw (docs/architecture.md, "Sprites").
///
/// This file is the seam between `Artwork` and `MapDrawing`; whilst the modules
/// are built in parallel, only the coordinating session changes it.
public struct SpriteImage: @unchecked Sendable {
    /// The picture, drawn facing right, at twice its size in points (for Retina).
    public var base: CGImage
    /// White where the civilization's colour goes, transparent elsewhere; the
    /// drawing tints it with `TeamColour` and lays it over `base`. `nil` where
    /// the subject carries no team colour (sites, terrain).
    public var teamMask: CGImage?
    /// The point placed on the entity's map position: for a person, between
    /// its feet; for a building, the centre of its footprint at ground level
    /// (`EntityView.position`), which on screen is the centre of the
    /// footprint's diamond.
    public var anchor: SpriteAnchor

    public init(base: CGImage, teamMask: CGImage?, anchor: SpriteAnchor) {
        self.base = base; self.teamMask = teamMask; self.anchor = anchor
    }
}

/// Supplies sprites by key. `MapDrawing` asks; `Artwork` answers. A missing
/// sprite returns `nil`, and the drawing then shows a placeholder shape, so that
/// neither waits for the other. It is called from the main actor during
/// drawing; an implementation that caches must be safe for that (a `Mutex`, or
/// everything rendered in `init`).
public protocol SpriteSource: Sendable {
    func sprite(_ key: SpriteKey) -> SpriteImage?
}

/// A source that draws people in the five views (ruled 2026-11-21) for some
/// subjects. A source that is not one draws the side alone, and `GameSprites`
/// asks it for nothing else; a key in another view then falls back to the side.
public protocol ViewedSpriteSource: SpriteSource {
    /// Whether the source draws this subject in every view.
    func drawsViews(of subject: SpriteSubject) -> Bool
}

/// A source with no sprites at all: everything is drawn as a placeholder.
public struct EmptySpriteSource: SpriteSource {
    public init() {}
    public func sprite(_ key: SpriteKey) -> SpriteImage? { nil }
}
