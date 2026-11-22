// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// A site drawn in each of the five looks (`Age.look`). A site has no owner, so
// it is seen in the look of the age of the player who sees it; the look is
// carried in the pose, so that the key keeps its shape and every other site
// keeps its one picture.

extension SiteKind {
    /// Whether the site is drawn in each look, in the look of the age of the
    /// player who sees it: the fruit bush (ruled 2026-11-22). Every other site
    /// has one picture for every age.
    public var isDrawnInEachLook: Bool { self == .fruit }
}

extension SpritePose {
    /// A site drawn in each look (`SiteKind.isDrawnInEachLook`), whole, in one
    /// look. The drawing falls back to `.complete` where it is missing.
    public static func complete(in look: Look) -> SpritePose {
        SpritePose(rawValue: "complete-\(look.name.lowercased())")
    }

    /// The pose in which the drawing asks for a site seen by a player whose
    /// age is drawn in `look`: its picture in that look where it has one, else
    /// `.complete`.
    public static func site(_ kind: SiteKind, in look: Look) -> SpritePose {
        kind.isDrawnInEachLook ? .complete(in: look) : .complete
    }
}
