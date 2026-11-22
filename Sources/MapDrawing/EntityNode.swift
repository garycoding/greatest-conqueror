// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import GameCore
import SpriteKit

/// What a node needs to know to draw an entity or a site, gathered once for a view.
struct DrawContext {
    var cache: SpriteCache
    var catalogue: Catalogue
    var players: [PlayerID: PlayerSummary]
    var me: PlayerID
    var myTeam: TeamID?
    /// The frame of animation now, 0 to 11.
    var frame: Int
    /// The map's ground, so that a boat house can face its water (ruled 2026-11-22).
    var terrain: [Terrain] = []
    var mapWidth = 0
    var mapHeight = 0

    /// The view and the mirror a building is drawn in: a boat house faces the
    /// edge of its footprint that touches water (`FootprintEdge.boatHouseView`);
    /// every other building is seen from the side.
    func buildingView(_ kind: BuildingKind, at origin: GridPoint) -> (view: SpriteView, mirrored: Bool) {
        guard kind == .boatHouse, terrain.count == mapWidth * mapHeight, mapWidth > 0 else { return (.side, false) }
        return Placement.waterEdge(kind, at: origin, width: mapWidth, height: mapHeight, terrain: terrain,
                                   catalogue: catalogue).boatHouseView
    }

    func relation(of owner: PlayerID) -> EntityNode.Relation {
        if owner == me { return .own }
        if let myTeam, players[owner]?.team == myTeam { return .ally }
        return .enemy
    }
}

/// A person or a building on the map: its sprite (in the view its facing shows,
/// mirrored for the facings toward the left, with the
/// team colour laid over its mask), and, where needed, a selection ring, a health
/// bar and a construction bar. Everything but the sprite is made when first needed,
/// so that the many people who are neither selected nor hurt cost one sprite each.
@MainActor
final class EntityNode: SKNode {
    enum Relation { case own, ally, enemy }

    private struct Look: Equatable {
        var kind: EntityKind
        var civilization: Civilization
        var age: Age
        var pose: SpritePose
        var frame: Int
        /// The view a person is seen from (`Facing.view`); for a building, `.side`,
        /// or `.back` for a boat house whose water lies behind it.
        var view: SpriteView = .side
    }

    let body = SKSpriteNode()
    private var mask: SKSpriteNode?
    private var ring: SKShapeNode?
    /// A car's kill radius, a glow on the ground (ruled 2026-11-21).
    private(set) var glow: SKShapeNode?
    /// The car's laser beam whilst it fires: a red line with a bright core.
    private(set) var beam: SKShapeNode?
    private var health: Bar?
    private var construction: Bar?

    private(set) var entity: EntityView?
    private var look: Look?
    private var isSelected = false
    private var relation = Relation.own
    private var barHeight = 58.0
    /// How far the artwork's drawing rises above the entity's anchor, in points
    /// at zoom 1; 0 where it is not known (people, placeholders).
    private(set) var drawnHeight = 0.0
    private var barWidth = 30.0
    /// The view number in which this node was last updated; others are removed.
    var generation = 0

    @MainActor private final class Bar {
        let back: SKSpriteNode
        let fill: SKSpriteNode
        init(width: Double) {
            back = SKSpriteNode(color: NSColor(white: 0, alpha: 0.65), size: CGSize(width: width + 2, height: 6))
            fill = SKSpriteNode(color: .green, size: CGSize(width: width, height: 4))
            fill.anchorPoint = CGPoint(x: 0, y: 0.5)
            fill.position = CGPoint(x: -width / 2, y: 0)
            fill.zPosition = 0.1
            back.addChild(fill)
        }
    }

    override init() {
        super.init()
        addChild(body)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("EntityNode is not decoded") }

    /// Bring the node up to date with the entity. Nothing is touched where nothing changed.
    func apply(_ entity: EntityView, context: DrawContext, selected: Bool, relation: Relation) {
        let previous = self.entity
        if let previous, previous == entity, isSelected == selected, self.relation == relation,
           look?.frame == context.frame {
            return
        }
        self.entity = entity

        if previous?.position != entity.position {
            let s = Projection.screen(entity.position)
            position = CGPoint(x: s.x, y: s.y)
            zPosition = Projection.depth(entity.position)
        }
        if entity.kind == .unit(.car) {
            updateGlow(owner: entity.owner, context: context)
            // No glow while the person has turned the car's kill radius off (ruled 2026-11-21).
            glow?.isHidden = entity.killRadiusOff == true
            updateBeam(entity: entity, context: context)
        }

        let isBuilding: Bool
        if case .building = entity.kind { isBuilding = true } else { isBuilding = false }
        let summary = context.players[entity.owner]
        let pose = SpriteKey.pose(for: entity.activity, isBuilding: isBuilding)
        var buildingView = (view: SpriteView.side, mirrored: false)
        if case .building(let kind) = entity.kind { buildingView = context.buildingView(kind, at: entity.tile) }
        let newLook = Look(kind: entity.kind, civilization: summary?.civilization ?? .sumer, age: summary?.age ?? .towns,
                           pose: pose, frame: context.frame, view: isBuilding ? buildingView.view : entity.facing.view)
        if newLook != look {
            let first = look == nil
            look = newLook
            applyLook(newLook, entity: entity, context: context)
            if first, isBuilding { configureBars(for: entity, context: context) }
        }
        if !isBuilding, previous?.facing != entity.facing || previous == nil {
            body.xScale = entity.facing.mirrored ? -1 : 1
        } else if isBuilding {
            body.xScale = buildingView.mirrored ? -1 : 1
        }

        isSelected = selected
        self.relation = relation
        updateRing(entity: entity, context: context)
        updateBars(entity: entity)
    }

    private func applyLook(_ look: Look, entity: EntityView, context: DrawContext) {
        let subject = SpriteSubject.of(entity, ownerAge: look.age, catalogue: context.catalogue)
        let sprite = context.cache.sprite(for: entity.kind, subject: subject, civilization: look.civilization,
                                          pose: look.pose, frame: look.frame, view: look.view)
        body.texture = sprite.texture
        // A stand-in may be drawn larger than the kind it stands in for (`StandIn.scale`).
        let scale = StandIn.scale(entity.kind)
        let size = CGSize(width: sprite.size.width * scale, height: sprite.size.height * scale)
        body.size = size
        body.anchorPoint = sprite.anchor
        drawnHeight = (sprite.drawnHeight ?? 0) * scale
        if let height = sprite.drawnHeight, case .building(let kind) = entity.kind {
            barHeight = max(height + 8, Stature.building(kind) + 10)
        }
        if let maskTexture = sprite.mask {
            let node: SKSpriteNode
            if let existing = mask { node = existing } else {
                node = SKSpriteNode()
                node.colorBlendFactor = 1
                node.zPosition = 0.01
                body.addChild(node)
                mask = node
            }
            let t = TeamColour.of(look.civilization)
            node.color = NSColor(srgbRed: t.red, green: t.green, blue: t.blue, alpha: 1)
            node.texture = maskTexture
            node.size = size
            node.anchorPoint = sprite.anchor
            node.isHidden = false
        } else {
            mask?.isHidden = true
        }
    }

    private func configureBars(for entity: EntityView, context: DrawContext) {
        guard case .building(let kind) = entity.kind else { return }
        let size = context.cache.footprint(kind)
        let span = Double(size.x + size.y)
        barWidth = max(30, span * 14)
        barHeight = max(barHeight, Stature.building(kind) + span * 6 + 10)
    }

    /// The glow on the ground out to a car's kill radius, in its owner's team
    /// colour, fading outward: drawn above the ground and beneath every person
    /// and building, wherever the car stands.
    /// The laser from the car to the building it burns (ruled 2026-11-21), drawn
    /// above everything on the ground and flickering with the frame of animation.
    private func updateBeam(entity: EntityView, context: DrawContext) {
        guard let target = entity.laserTarget else {
            beam?.removeFromParent()
            beam = nil
            return
        }
        let node: SKShapeNode
        if let existing = beam { node = existing } else {
            node = SKShapeNode()
            node.lineCap = .round
            node.strokeColor = NSColor(srgbRed: 0.95, green: 0.1, blue: 0.12, alpha: 0.75)
            node.glowWidth = 3
            let core = SKShapeNode()
            core.name = "core"
            core.lineCap = .round
            core.strokeColor = NSColor(srgbRed: 1, green: 0.85, blue: 0.8, alpha: 1)
            core.lineWidth = 1.5
            node.addChild(core)
            addChild(node)
            beam = node
        }
        let from = Projection.screen(entity.position), to = Projection.screen(target)
        let path = CGMutablePath()
        // From the car's roof, a little above its standing point, to the building's middle.
        path.move(to: CGPoint(x: 0, y: 14))
        path.addLine(to: CGPoint(x: to.x - from.x, y: to.y - from.y + 12))
        node.path = path
        (node.childNode(withName: "core") as? SKShapeNode)?.path = path
        let flicker = [1.0, 0.7, 0.9, 0.6][context.frame % 4]
        node.lineWidth = 3 + 2 * flicker
        node.alpha = flicker
        // Above every entity and below the placement outline (50 000).
        node.zPosition = 40_000 - zPosition
    }

    private func updateGlow(owner: PlayerID, context: DrawContext) {
        guard let radius = context.catalogue.car?.killRadius else { return }
        let node: SKShapeNode
        if let existing = glow { node = existing } else {
            node = SKShapeNode()
            for (k, share) in [1.0, 0.8, 0.6, 0.4].enumerated() {
                let path = CGMutablePath()
                let points = (0..<72).map { n -> CGPoint in
                    let a = Double(n) / 72 * 2 * Double.pi
                    let s = Projection.screen(MapPosition(x: cos(a) * radius * share, y: sin(a) * radius * share))
                    return CGPoint(x: s.x, y: s.y)
                }
                path.addLines(between: points)
                path.closeSubpath()
                let band = SKShapeNode(path: path)
                band.lineWidth = k == 0 ? 2 : 0
                band.name = "glow"
                node.addChild(band)
            }
            addChild(node)
            glow = node
        }
        let t = context.players[owner].map { TeamColour.of($0.civilization) } ?? TeamColour(red: 1, green: 1, blue: 1)
        for (k, band) in node.children.enumerated() {
            guard let band = band as? SKShapeNode else { continue }
            band.fillColor = NSColor(srgbRed: t.red, green: t.green, blue: t.blue, alpha: 0.05 + 0.025 * Double(k))
            band.strokeColor = NSColor(srgbRed: t.red, green: t.green, blue: t.blue, alpha: k == 0 ? 0.55 : 0)
        }
        // Above the ground (-10 000) and beneath every entity, whose depth is never negative.
        node.zPosition = -5_000 - zPosition
    }

    private func updateRing(entity: EntityView, context: DrawContext) {
        guard isSelected else { ring?.isHidden = true; return }
        let node: SKShapeNode
        if let existing = ring { node = existing } else {
            let path = CGMutablePath()
            if case .building(let kind) = entity.kind {
                let size = context.cache.footprint(kind)
                let w = Double(size.x), h = Double(size.y)
                let corners = [MapPosition(x: -w / 2, y: -h / 2), MapPosition(x: w / 2, y: -h / 2),
                               MapPosition(x: w / 2, y: h / 2), MapPosition(x: -w / 2, y: h / 2)].map { p -> CGPoint in
                    let s = Projection.screen(MapPosition(x: p.x * 1.04, y: p.y * 1.04))
                    return CGPoint(x: s.x, y: s.y)
                }
                path.addLines(between: corners)
                path.closeSubpath()
            } else {
                path.addEllipse(in: CGRect(x: -16, y: -8, width: 32, height: 16))
            }
            node = SKShapeNode(path: path)
            node.lineWidth = 2.5
            node.fillColor = .clear
            node.zPosition = -0.5
            addChild(node)
            ring = node
        }
        node.isHidden = false
        node.strokeColor = switch relation {
        case .own: NSColor(srgbRed: 0.25, green: 0.95, blue: 0.35, alpha: 1)
        case .ally: NSColor(srgbRed: 0.98, green: 0.90, blue: 0.25, alpha: 1)
        case .enemy: NSColor(srgbRed: 0.95, green: 0.25, blue: 0.2, alpha: 1)
        }
    }

    private func makeBar() -> Bar {
        let bar = Bar(width: barWidth)
        bar.back.zPosition = 1_000
        addChild(bar.back)
        return bar
    }

    private func updateBars(entity: EntityView) {
        let wounded = entity.health < entity.maxHealth && entity.health > 0
        if isSelected || wounded {
            let bar: Bar
            if let existing = health { bar = existing } else { bar = makeBar(); health = bar }
            let fraction = entity.maxHealth > 0 ? min(max(Double(entity.health) / Double(entity.maxHealth), 0), 1) : 0
            bar.back.isHidden = false
            bar.back.position = CGPoint(x: 0, y: barHeight)
            bar.fill.xScale = fraction
            bar.fill.color = fraction > 0.6 ? NSColor(srgbRed: 0.3, green: 0.85, blue: 0.3, alpha: 1)
                : (fraction > 0.3 ? NSColor(srgbRed: 0.95, green: 0.8, blue: 0.2, alpha: 1)
                    : NSColor(srgbRed: 0.9, green: 0.2, blue: 0.15, alpha: 1))
        } else {
            health?.back.isHidden = true
        }
        if case .underConstruction(let progress) = entity.activity {
            let bar: Bar
            if let existing = construction { bar = existing } else {
                bar = makeBar()
                bar.fill.color = NSColor(srgbRed: 0.35, green: 0.65, blue: 1, alpha: 1)
                construction = bar
            }
            bar.back.isHidden = false
            bar.back.position = CGPoint(x: 0, y: barHeight + 8)
            bar.fill.xScale = min(max(progress, 0), 1)
        } else {
            construction?.back.isHidden = true
        }
    }
}

/// A resource site: a sprite on its tile, hidden on a tile never seen and
/// darkened on one not in sight. A site on a water tile shows its `afloat`
/// picture, and a site that moves (the fish) shows the frame of its cycle
/// for its tile, offset from its neighbours' (`frameOffset`).
@MainActor
final class SiteNode: SKSpriteNode {
    var generation = 0
    private var kind: SiteKind?
    private var visibility: TileVisibility?

    /// How many frames a site's cycle runs ahead on its tile, so that
    /// neighbouring tiles do not move in unison: the four tiles of any square
    /// of two by two each take a different offset.
    nonisolated static func frameOffset(_ tile: GridPoint) -> Int {
        let n = 5 * tile.x + 3 * tile.y
        return ((n % SpriteKey.framesPerPose) + SpriteKey.framesPerPose) % SpriteKey.framesPerPose
    }

    func apply(_ site: ResourceSite, afloat: Bool, frame: Int, visibility: TileVisibility, cache: SpriteCache) {
        let shown = (frame + Self.frameOffset(site.tile)) % SpriteKey.framesPerPose
        let sprite = cache.sprite(forSite: site.kind, afloat: afloat, frame: shown)
        if texture !== sprite.texture {
            texture = sprite.texture
            size = sprite.size
            anchorPoint = sprite.anchor
        }
        if kind != site.kind {
            kind = site.kind
            let s = Projection.screen(site.tile.centre)
            position = CGPoint(x: s.x, y: s.y)
            zPosition = Projection.depth(site.tile.centre)
        }
        guard self.visibility != visibility else { return }
        self.visibility = visibility
        isHidden = visibility == .unexplored
        color = .black
        colorBlendFactor = visibility == .explored ? 0.45 : 0
    }
}

/// Plain rock on a deposit's tile that the player's age does not yet reveal.
final class OutcropNode: SKSpriteNode {
    var generation = 0
    private var visibility: TileVisibility?

    func place(at tile: GridPoint, afloat: Bool = false, cache: SpriteCache) {
        let sprite = cache.spriteForOutcrop(afloat: afloat)
        texture = sprite.texture
        size = sprite.size
        anchorPoint = sprite.anchor
        let s = Projection.screen(tile.centre)
        position = CGPoint(x: s.x, y: s.y)
        zPosition = Projection.depth(tile.centre)
    }

    func apply(visibility: TileVisibility) {
        guard self.visibility != visibility else { return }
        self.visibility = visibility
        isHidden = visibility == .unexplored
        color = .black
        colorBlendFactor = visibility == .explored ? 0.45 : 0
    }
}
