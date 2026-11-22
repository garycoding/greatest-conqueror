// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import Artwork
import GameCore
import Observation
import os
import SpriteKit

/// Which parts of the session have changed since the scene last looked.
final class SessionChanges: Sendable {
    struct Parts: OptionSet, Sendable {
        let rawValue: UInt8
        static let view = Parts(rawValue: 1)
        static let selection = Parts(rawValue: 2)
        static let placing = Parts(rawValue: 4)
        static let camera = Parts(rawValue: 8)
        static let all: Parts = [.view, .selection, .placing, .camera]
    }

    private let state = OSAllocatedUnfairLock(initialState: Parts())

    func mark(_ parts: Parts) { state.withLock { $0.formUnion(parts) } }

    func take() -> Parts { state.withLock { let out = $0; $0 = []; return out } }
}

/// The SpriteKit scene that draws a player's view of the map and turns clicks into
/// selections and orders (docs/architecture.md, "Modules"). It is driven by a
/// `PlayerSession`, which it reads and changes (the selection, the camera, a
/// building being placed, groups) and through which it issues every order, and by
/// a `SpriteSource`, whose missing sprites it replaces with placeholders.
///
/// The scene follows the session: when another module changes the view, the
/// selection, the camera or `placing`, the next frame shows it.
@MainActor
public final class MapScene: SKScene {
    public let session: PlayerSession

    let cache: SpriteCache
    let world = SKNode()
    private(set) var terrain: TerrainLayer?
    private(set) var entityNodes: [EntityID: EntityNode] = [:]
    private(set) var siteNodes: [SiteID: SiteNode] = [:]
    private(set) var outcropNodes: [GridPoint: OutcropNode] = [:]
    private var generation = 0
    private var selectedIDs: Set<EntityID> = []

    private let changes = SessionChanges()
    /// The camera as drawn; `session.camera` is brought to it, and it follows the
    /// session when another module changes the session's.
    private(set) var appliedCamera: Camera

    // Placement outline.
    let placementOutline = SKShapeNode()
    /// The footprint outline now shown for `session.placing`, or `nil`.
    public private(set) var placementState: (origin: GridPoint, canPlace: Bool)?
    private struct PlacementKey: Equatable { var kind: BuildingKind; var origin: GridPoint; var tick: Int }
    private var placementChecked: PlacementKey?

    // Pointer, drag and keys.
    /// Where the pointer is, in scene points: read from the window each frame, and
    /// settable (by tests) where there is no window.
    public var pointer: CGPoint?
    var pointerIsLive = false
    let boxOutline = SKShapeNode()
    var dragStart: CGPoint?
    var dragIsBox = false
    var heldArrows: Set<ArrowKey> = []
    private var lastTime: TimeInterval?
    private(set) var animationFrame = 0

    /// Scrolling speed, in points of the screen a second.
    static let scrollSpeed = 900.0
    /// The width of the band at the screen's edges that scrolls the map.
    static let edgeMargin = 6.0
    public init(session: PlayerSession, sprites: any SpriteSource, size: CGSize = CGSize(width: 1280, height: 800)) {
        self.session = session
        cache = SpriteCache(source: sprites, catalogue: session.catalogue)
        appliedCamera = session.camera.clamped(mapWidth: session.view.mapWidth, mapHeight: session.view.mapHeight)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = NSColor(white: 0.03, alpha: 1)
        addChild(world)

        placementOutline.zPosition = 50_000
        placementOutline.lineWidth = 2.5
        placementOutline.isHidden = true
        world.addChild(placementOutline)

        boxOutline.zPosition = 1_000_000
        boxOutline.lineWidth = 1
        boxOutline.strokeColor = NSColor(white: 1, alpha: 0.9)
        boxOutline.fillColor = NSColor(white: 1, alpha: 0.12)
        boxOutline.isHidden = true
        addChild(boxOutline)

        arm(.all)
        applyWorldTransform()
        refresh()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("MapScene is not decoded") }

    // MARK: Geometry

    /// The conversion between map positions and scene points for the camera as drawn.
    public var geometry: MapGeometry { MapGeometry(camera: appliedCamera, viewSize: size) }

    private var mapWidth: Int { session.view.mapWidth }
    private var mapHeight: Int { session.view.mapHeight }

    private func applyWorldTransform() {
        let g = geometry
        world.position = g.worldOrigin
        world.setScale(appliedCamera.zoom)
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        applyWorldTransform()
    }

    /// Draw the camera `camera` (kept over the map and within the zoom limits) and
    /// make `session.camera` the same.
    func setCamera(_ camera: Camera) {
        let clamped = camera.clamped(mapWidth: mapWidth, mapHeight: mapHeight)
        if clamped != appliedCamera {
            appliedCamera = clamped
            applyWorldTransform()
        }
        if session.camera != clamped { session.camera = clamped }
    }

    // MARK: Following the session

    private func arm(_ parts: SessionChanges.Parts) {
        let changes = self.changes
        if parts.contains(.view) {
            withObservationTracking { _ = session.view } onChange: { changes.mark(.view) }
        }
        if parts.contains(.selection) {
            withObservationTracking { _ = session.selection } onChange: { changes.mark(.selection) }
        }
        if parts.contains(.placing) {
            withObservationTracking { _ = session.placing } onChange: { changes.mark(.placing) }
        }
        if parts.contains(.camera) {
            withObservationTracking { _ = session.camera } onChange: { changes.mark(.camera) }
        }
    }

    /// Look at what the session now holds and bring the scene to it: the camera,
    /// the nodes of a new view, the rings of a new selection, the placement outline.
    public func updateFromSession() {
        let dirty = changes.take()
        arm(dirty)
        if dirty.contains(.camera), session.camera != appliedCamera { setCamera(session.camera) }
        if dirty.contains(.view) {
            applyView()
        } else if dirty.contains(.selection) {
            applySelection()
        }
        if !dirty.isDisjoint(with: [.view, .placing]) { updatePlacementOutline(force: true) }
    }

    /// Draw everything from the session at once, whatever has or has not changed.
    public func refresh() {
        _ = changes.take()
        arm(.all)
        if session.camera != appliedCamera { setCamera(session.camera) }
        applyView()
        updatePlacementOutline(force: true)
    }

    private func makeContext(_ view: PlayerView) -> DrawContext {
        var players: [PlayerID: PlayerSummary] = [:]
        for summary in view.players { players[summary.id] = summary }
        return DrawContext(cache: cache, catalogue: session.catalogue, players: players, me: view.player,
                           myTeam: players[view.player]?.team, frame: animationFrame,
                           terrain: view.terrain, mapWidth: view.mapWidth, mapHeight: view.mapHeight)
    }

    /// Build and update the nodes from the session's view: the only per-view work.
    func applyView() {
        let view = session.view
        generation += 1

        if terrain == nil || terrain?.width != view.mapWidth || terrain?.height != view.mapHeight {
            terrain?.node.removeFromParent()
            let layer = TerrainLayer(width: view.mapWidth, height: view.mapHeight, cache: cache)
            world.addChild(layer.node)
            terrain = layer
            applyWorldTransform()
        }
        terrain?.update(with: view)

        var seenSites = 0
        for site in view.sites where site.remaining > 0 {
            let node: SiteNode
            if let existing = siteNodes[site.id] { node = existing } else {
                node = SiteNode()
                world.addChild(node)
                siteNodes[site.id] = node
            }
            node.generation = generation
            node.apply(site, afloat: view.terrain(at: site.tile).isWater, look: view.age.look, frame: animationFrame,
                       visibility: view.visibility(at: site.tile), cache: cache)
            seenSites += 1
        }
        if siteNodes.count != seenSites {
            for (id, node) in siteNodes where node.generation != generation {
                node.removeFromParent()
                siteNodes[id] = nil
            }
        }

        for tile in view.outcrops {
            let node: OutcropNode
            if let existing = outcropNodes[tile] { node = existing } else {
                node = OutcropNode()
                node.place(at: tile, afloat: view.terrain(at: tile).isWater, cache: cache)
                world.addChild(node)
                outcropNodes[tile] = node
            }
            node.generation = generation
            node.apply(visibility: view.visibility(at: tile))
        }
        if outcropNodes.count != view.outcrops.count {
            for (tile, node) in outcropNodes where node.generation != generation {
                node.removeFromParent()
                outcropNodes[tile] = nil
            }
        }

        let context = makeContext(view)
        selectedIDs = Set(session.selection)
        for entity in view.entities {
            let node: EntityNode
            if let existing = entityNodes[entity.id] { node = existing } else {
                node = EntityNode()
                world.addChild(node)
                entityNodes[entity.id] = node
            }
            node.generation = generation
            node.apply(entity, context: context, selected: selectedIDs.contains(entity.id),
                       relation: context.relation(of: entity.owner))
        }
        if entityNodes.count != view.entities.count {
            for (id, node) in entityNodes where node.generation != generation {
                node.removeFromParent()
                entityNodes[id] = nil
            }
        }
    }

    private func applySelection() {
        let view = session.view
        let now = Set(session.selection)
        let context = makeContext(view)
        for id in now.symmetricDifference(selectedIDs) {
            guard let node = entityNodes[id], let entity = view.entity(id) else { continue }
            node.apply(entity, context: context, selected: now.contains(id), relation: context.relation(of: entity.owner))
        }
        selectedIDs = now
    }

    // MARK: Placement outline

    /// Show, move or hide the footprint outline. Unless `force`, nothing is done
    /// whilst the pointer stays over the same origin tile of the same view.
    private func updatePlacementOutline(force: Bool = false) {
        guard let kind = session.placing, let pointer else {
            placementOutline.isHidden = true
            placementState = nil
            placementChecked = nil
            return
        }
        let catalogue = session.catalogue
        let origin = Placement.origin(kind, centre: geometry.mapPosition(for: pointer), catalogue: catalogue)
        let key = PlacementKey(kind: kind, origin: origin, tick: session.view.tick)
        if !force, placementChecked == key, !placementOutline.isHidden { return }
        placementChecked = key
        let allowed = Placement.canPlace(kind, at: origin, in: session.view, catalogue: catalogue)
        if placementState?.origin != origin || placementState?.canPlace != allowed || placementOutline.isHidden {
            let size = cache.footprint(kind)
            let x = Double(origin.x), y = Double(origin.y), w = Double(size.x), h = Double(size.y)
            let path = CGMutablePath()
            path.addLines(between: [MapPosition(x: x, y: y), MapPosition(x: x + w, y: y), MapPosition(x: x + w, y: y + h),
                                    MapPosition(x: x, y: y + h)].map { p -> CGPoint in
                let s = Projection.screen(p)
                return CGPoint(x: s.x, y: s.y)
            })
            path.closeSubpath()
            placementOutline.path = path
            let colour = allowed ? NSColor(srgbRed: 0.2, green: 0.9, blue: 0.3, alpha: 1) : NSColor(srgbRed: 0.95, green: 0.2, blue: 0.2, alpha: 1)
            placementOutline.strokeColor = colour
            placementOutline.fillColor = colour.withAlphaComponent(0.3)
            placementOutline.isHidden = false
        }
        placementState = (origin, allowed)
    }

    // MARK: The frame

    public override func update(_ currentTime: TimeInterval) {
        step(at: currentTime)
    }

    /// One frame: the pointer, scrolling, the frame of animation, and the session.
    func step(at now: TimeInterval) {
        let elapsed = lastTime.map { min(max(now - $0, 0), 0.1) } ?? 0
        lastTime = now
        pollPointer()
        scrollFromInput(elapsed: elapsed)
        let frame = Int((now * SpriteKey.frameRate).rounded(.down)) % SpriteKey.framesPerPose
        if frame != animationFrame {
            animationFrame = frame
            changes.mark(.view)
        }
        updateFromSession()
        updatePlacementOutline()
    }

    private func pollPointer() {
        guard let view, let window = view.window, window.isKeyWindow else {
            pointerIsLive = false
            // A window that has lost focus gets no key-up, so nothing may stay held.
            if view?.window != nil { heldArrows.removeAll() }
            return
        }
        let local = view.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard view.bounds.contains(local) else { pointer = nil; pointerIsLive = false; return }
        pointer = convertPoint(fromView: local)
        pointerIsLive = true
    }

    private func scrollFromInput(elapsed: TimeInterval) {
        guard elapsed > 0 else { return }
        var dx = 0.0, dy = 0.0
        if heldArrows.contains(.left) { dx -= 1 }
        if heldArrows.contains(.right) { dx += 1 }
        if heldArrows.contains(.down) { dy -= 1 }
        if heldArrows.contains(.up) { dy += 1 }
        if pointerIsLive, let pointer {
            let edge = Self.edgeDirection(of: pointer, in: size)
            dx += edge.dx
            dy += edge.dy
        }
        guard dx != 0 || dy != 0 else { return }
        let length = (dx * dx + dy * dy).squareRoot()
        let step = Self.scrollSpeed * elapsed / length
        scroll(contentBy: CGVector(dx: -dx * step, dy: -dy * step))
    }

    /// Which way the screen's edges scroll for a pointer at `point`: each axis is
    /// -1, 0 or 1 (the direction the camera moves).
    static func edgeDirection(of point: CGPoint, in size: CGSize) -> CGVector {
        var dx = 0.0, dy = 0.0
        if point.x <= edgeMargin { dx = -1 } else if point.x >= size.width - edgeMargin { dx = 1 }
        if point.y <= edgeMargin { dy = -1 } else if point.y >= size.height - edgeMargin { dy = 1 }
        return CGVector(dx: dx, dy: dy)
    }

    // MARK: Test access

    var entityNodeCount: Int { entityNodes.count }
    var siteNodeCount: Int { siteNodes.count }
    var outcropNodeCount: Int { outcropNodes.count }
}
