// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore

/// The conversion between map positions and points of the scene, for one camera
/// and one size of view. Scene points have their origin at the bottom left and y
/// upward, as SpriteKit has them; the camera's centre lies at the middle of the
/// view, and `Camera.zoom` scales the projection of `GameCore.Projection`.
public struct MapGeometry: Equatable, Sendable {
    public var camera: Camera
    public var viewSize: CGSize

    public init(camera: Camera, viewSize: CGSize) {
        self.camera = camera
        self.viewSize = viewSize
    }

    /// The middle of the view, where the camera's centre is drawn.
    public var viewCentre: CGPoint { CGPoint(x: viewSize.width / 2, y: viewSize.height / 2) }

    /// The scene point of a map position.
    public func scenePoint(for position: MapPosition) -> CGPoint {
        let s = Projection.screen(position), c = Projection.screen(camera.centre)
        return CGPoint(x: viewCentre.x + (s.x - c.x) * camera.zoom, y: viewCentre.y + (s.y - c.y) * camera.zoom)
    }

    /// The map position under a scene point (on the ground plane).
    public func mapPosition(for point: CGPoint) -> MapPosition {
        let c = Projection.screen(camera.centre)
        return Projection.map(ScreenPoint(x: c.x + (point.x - viewCentre.x) / camera.zoom,
                                          y: c.y + (point.y - viewCentre.y) / camera.zoom))
    }

    /// Where the map's origin lies in the scene: the position of the world node.
    public var worldOrigin: CGPoint { scenePoint(for: MapPosition(x: 0, y: 0)) }

    /// The camera moved so that what is drawn shifts by `delta` scene points
    /// (the camera itself moves the other way), and kept over the map.
    public func panned(contentBy delta: CGVector, mapWidth: Int, mapHeight: Int) -> Camera {
        let c = Projection.screen(camera.centre)
        let moved = Projection.map(ScreenPoint(x: c.x - delta.dx / camera.zoom, y: c.y - delta.dy / camera.zoom))
        return Camera(centre: moved, zoom: camera.zoom).clamped(mapWidth: mapWidth, mapHeight: mapHeight)
    }

    /// The camera with its zoom multiplied by `factor` (within the limits of
    /// `Camera`), keeping the map position under `anchor` where it is.
    public func zoomed(by factor: Double, about anchor: CGPoint, mapWidth: Int, mapHeight: Int) -> Camera {
        let zoom = min(max(camera.zoom * factor, Camera.minimumZoom), Camera.maximumZoom)
        let held = Projection.screen(mapPosition(for: anchor))
        let centre = Projection.map(ScreenPoint(x: held.x - (anchor.x - viewCentre.x) / zoom,
                                                y: held.y - (anchor.y - viewCentre.y) / zoom))
        return Camera(centre: centre, zoom: zoom).clamped(mapWidth: mapWidth, mapHeight: mapHeight)
    }
}

extension Camera {
    /// The camera with its zoom within the limits and its centre over the map.
    public func clamped(mapWidth: Int, mapHeight: Int) -> Camera {
        Camera(centre: MapPosition(x: min(max(centre.x, 0), Double(mapWidth)),
                                   y: min(max(centre.y, 0), Double(mapHeight))),
               zoom: min(max(zoom, Camera.minimumZoom), Camera.maximumZoom))
    }
}

/// What is under a point of the map.
public enum MapTarget: Equatable, Sendable {
    case entity(EntityView)
    case site(ResourceSite)
    case ground(MapPosition)
}

/// How tall things are drawn, in points at zoom 1, for the placeholders and for
/// hit-testing (artwork follows the same proportions: docs/architecture.md,
/// "Sprites").
enum Stature {
    /// A person's height above the feet.
    static let person = 48.0
    /// Half the width a person is hit across.
    static func personHalfWidth(_ kind: UnitKind) -> Double { kind == .chariot ? 26 : 14 }
    static func personHeight(_ kind: UnitKind) -> Double { kind == .chariot ? 40 : person + 4 }

    /// The height of a building's block.
    static func building(_ kind: BuildingKind) -> Double {
        switch kind {
        case .townCentre: 40
        case .house: 26
        case .storagePit: 4
        case .stockPen: 12
        case .barracks: 32
        case .watchTower: 58
        case .palisade: 20
        case .farm: 3
        case .stable: 28
        case .siegeWorkshop: 32
        case .stoneWall: 24
        case .castle: 60
        case .alchemistsWorkshop: 30
        case .factory: 40
        case .railwayDepot: 28
        case .oilWell: 34
        case .bridge: 6
        case .boatHouse: 30
        }
    }

    /// The height of a site above its tile.
    static func site(_ kind: SiteKind) -> Double {
        switch kind {
        case .tree: 52
        case .prey: 22
        case .stone, .copper, .tin, .gold, .iron: 26
        case .oilField: 8
        case .fish: 6
        }
    }
}

/// Which entity, site or ground is under a point, and which people lie in a box.
/// Pure functions of a view and a geometry, so that they are tested without a scene.
public enum MapHitTesting {
    /// The corners of the footprint of a building, in scene points: top, right,
    /// bottom, left.
    static func footprintCorners(origin: GridPoint, size: GridPoint, geometry: MapGeometry) -> [CGPoint] {
        let x = Double(origin.x), y = Double(origin.y), w = Double(size.x), h = Double(size.y)
        return [MapPosition(x: x, y: y), MapPosition(x: x + w, y: y), MapPosition(x: x + w, y: y + h), MapPosition(x: x, y: y + h)]
            .map { geometry.scenePoint(for: $0) }
    }

    /// Whether `point` lies inside the solid made by lifting a convex quadrilateral
    /// straight up by `height` (a block standing on its footprint).
    static func contains(_ quad: [CGPoint], liftedBy height: Double, _ point: CGPoint) -> Bool {
        var low = Double.infinity, high = -Double.infinity
        for i in 0..<quad.count {
            let a = quad[i], b = quad[(i + 1) % quad.count]
            let lo = min(a.x, b.x), hi = max(a.x, b.x)
            guard point.x >= lo, point.x <= hi else { continue }
            let y = hi == lo ? a.y : a.y + (b.y - a.y) * (point.x - a.x) / (b.x - a.x)
            low = min(low, y); high = max(high, y)
            if hi == lo { low = min(low, b.y); high = max(high, b.y) }
        }
        return low <= high && point.y >= low && point.y <= high + height
    }

    /// Whether `point` lies above the bottom edge of a convex quadrilateral, within
    /// its width, and no higher than `top`.
    static func contains(_ quad: [CGPoint], upTo top: Double, _ point: CGPoint) -> Bool {
        var low = Double.infinity
        for i in 0..<quad.count {
            let a = quad[i], b = quad[(i + 1) % quad.count]
            let lo = min(a.x, b.x), hi = max(a.x, b.x)
            guard point.x >= lo, point.x <= hi, hi > lo else { continue }
            low = min(low, a.y + (b.y - a.y) * (point.x - a.x) / (b.x - a.x))
        }
        return low.isFinite && point.y >= low && point.y <= top
    }

    /// The entity drawn under `point`. A person wins over a building where both
    /// are under it; among people, the one whose feet are nearest the point; among
    /// buildings, the nearest to the viewer.
    /// `drawnHeight` gives how far an entity's drawing rises above its anchor,
    /// where the scene knows it; a building is then hit up to the top of its
    /// drawing rather than the height in `Stature`.
    public static func entity(at point: CGPoint, in view: PlayerView, geometry: MapGeometry,
                              catalogue: Catalogue = .standard,
                              drawnHeight: (EntityView) -> Double? = { _ in nil }) -> EntityView? {
        let zoom = geometry.camera.zoom
        var person: EntityView?, personDistance = Double.infinity
        var building: EntityView?, buildingDepth = -Double.infinity
        for entity in view.entities {
            switch entity.kind {
            case .unit(let kind):
                let foot = geometry.scenePoint(for: entity.position)
                let dx = point.x - foot.x, dy = point.y - foot.y
                guard abs(dx) <= Stature.personHalfWidth(kind) * zoom,
                      dy >= -4 * zoom, dy <= Stature.personHeight(kind) * zoom else { continue }
                let distance = dx * dx + (dy - 20 * zoom) * (dy - 20 * zoom)
                if distance < personDistance { person = entity; personDistance = distance }
            case .building(let kind):
                let size = catalogue.stats(kind).footprint
                let quad = footprintCorners(origin: entity.tile, size: size, geometry: geometry)
                // The block of `Stature`, or else up to the drawing's top, which is
                // measured from the anchor (the footprint's centre), not from its back edge.
                let anchor = geometry.scenePoint(for: entity.position)
                let top = drawnHeight(entity).map { anchor.y + $0 * zoom }
                guard contains(quad, liftedBy: Stature.building(kind) * zoom, point)
                        || (top.map { contains(quad, upTo: $0, point) } ?? false) else { continue }
                let depth = Projection.depth(entity.position)
                if depth > buildingDepth { building = entity; buildingDepth = depth }
            }
        }
        return person ?? building
    }

    /// The tiles under a building that stands on its site, an oil well over
    /// its field: the site there is hidden by the building and is not drawn.
    public static func coveredSiteTiles(in view: PlayerView) -> Set<GridPoint> {
        var tiles = Set<GridPoint>()
        for e in view.entities {
            guard case .building(let kind) = e.kind, Placement.site(for: kind) != nil else { continue }
            for t in Placement.footprint(kind, at: e.tile) { tiles.insert(t) }
        }
        return tiles
    }

    /// The site drawn under `point`, among those on explored tiles.
    public static func site(at point: CGPoint, in view: PlayerView, geometry: MapGeometry) -> ResourceSite? {
        let zoom = geometry.camera.zoom
        var best: ResourceSite?, bestDepth = -Double.infinity
        let covered = coveredSiteTiles(in: view)
        for site in view.sites where site.remaining > 0 && !covered.contains(site.tile) {
            guard view.visibility(at: site.tile) != .unexplored else { continue }
            let quad = footprintCorners(origin: site.tile, size: GridPoint(1, 1), geometry: geometry)
            guard contains(quad, liftedBy: Stature.site(site.kind) * zoom, point) else { continue }
            let depth = Projection.depth(site.tile.centre)
            if depth > bestDepth { best = site; bestDepth = depth }
        }
        return best
    }

    /// What is under `point`: an entity, else a site, else the ground.
    public static func target(at point: CGPoint, in view: PlayerView, geometry: MapGeometry,
                              catalogue: Catalogue = .standard,
                              drawnHeight: (EntityView) -> Double? = { _ in nil }) -> MapTarget {
        if let entity = entity(at: point, in: view, geometry: geometry, catalogue: catalogue,
                               drawnHeight: drawnHeight) { return .entity(entity) }
        if let site = site(at: point, in: view, geometry: geometry) { return .site(site) }
        return .ground(geometry.mapPosition(for: point))
    }

    /// The player's own people whose bodies lie in the box, in the order of the view.
    public static func ownPeople(in box: CGRect, view: PlayerView, geometry: MapGeometry) -> [EntityID] {
        view.entities.compactMap { entity in
            guard entity.owner == view.player, case .unit = entity.kind else { return nil }
            let foot = geometry.scenePoint(for: entity.position)
            let body = CGPoint(x: foot.x, y: foot.y + 20 * geometry.camera.zoom)
            return box.contains(body) ? entity.id : nil
        }
    }
}
