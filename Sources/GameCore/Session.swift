// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Observation

/// What part of the map is shown. The drawing (`MapDrawing`) renders it; a click
/// on the small map (`GameInterface`) moves it.
public struct Camera: Hashable, Codable, Sendable {
    /// The map position at the centre of the view.
    public var centre: MapPosition
    /// 1 is the artwork's own size; larger is closer.
    public var zoom: Double

    public init(centre: MapPosition, zoom: Double = 1) { self.centre = centre; self.zoom = zoom }

    public static let minimumZoom = 0.5
    public static let maximumZoom = 2.0
}

/// The state one human player's screen shares between the map and the panels:
/// the latest view, the selection, the camera, a building being placed, numbered
/// groups, and the last refusal. `MapDrawing` and `GameInterface` both read and
/// change it; the app owns it and passes it to both, and both issue orders
/// through it, never to the simulation directly.
@MainActor
@Observable
public final class PlayerSession {
    public private(set) var view: PlayerView
    public let catalogue: Catalogue
    /// Selected entities, in the order they were selected.
    public var selection: [EntityID] = []
    public var camera: Camera
    /// A building the player has chosen to construct and is placing; the map
    /// shows its footprint under the pointer until a click places it.
    public var placing: BuildingKind?
    /// Numbered groups (requirement "Controls"): number key → entities.
    public var groups: [Int: [EntityID]] = [:]
    /// The most recent refusal, from the latest view's `GameEvent.refused`, for
    /// the interface to show; the interface sets it to `nil` once shown.
    public var lastRefusal: OrderRefusal?

    private let sink: @MainActor (Order) -> Void

    /// - Parameter sink: where orders go: the simulation, through the app, or in a
    ///   later milestone across the LAN. It returns nothing; a refusal arrives in
    ///   a later view, so that the simulation need not run on the main actor.
    public init(view: PlayerView, catalogue: Catalogue, camera: Camera, sink: @escaping @MainActor (Order) -> Void) {
        self.view = view; self.catalogue = catalogue; self.camera = camera; self.sink = sink
    }

    /// Give an order. Whether it was accepted shows in a later view.
    public func issue(_ order: Order) { sink(order) }

    /// Show a newer view. Selected entities that no longer exist are dropped, and
    /// the view's last refusal, if any, becomes `lastRefusal`.
    public func update(_ newView: PlayerView) {
        view = newView
        selection.removeAll { newView.entity($0) == nil }
        for event in newView.events { if case .refused(let why) = event { lastRefusal = why } }
    }

    /// The selected entities that belong to this player.
    public var ownSelection: [EntityView] {
        selection.compactMap { view.entity($0) }.filter { $0.owner == view.player }
    }
}

/// A point on the screen, in points, with y upward as SpriteKit has it.
public struct ScreenPoint: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// The game's projection (docs/architecture.md, "Projection"): an isometric
/// view in which a tile is a diamond `tileWidth` wide and `tileHeight` high.
/// Map +x runs toward the lower right of the screen and +y toward the lower
/// left; the map's origin is at the top. Things farther down the screen are
/// nearer the viewer and drawn in front.
public enum Projection {
    public static let tileWidth = 64.0
    public static let tileHeight = 32.0

    /// The screen point of a map position, at zoom 1, relative to the map's origin.
    public static func screen(_ p: MapPosition) -> ScreenPoint {
        ScreenPoint(x: (p.x - p.y) * tileWidth / 2, y: -(p.x + p.y) * tileHeight / 2)
    }

    /// The map position under a screen point, at zoom 1, relative to the map's origin.
    public static func map(_ s: ScreenPoint) -> MapPosition {
        let a = s.x / (tileWidth / 2), b = -s.y / (tileHeight / 2)
        return MapPosition(x: (a + b) / 2, y: (b - a) / 2)
    }

    /// Larger is nearer the viewer: draw in increasing order of depth.
    public static func depth(_ p: MapPosition) -> Double { p.x + p.y }
}
