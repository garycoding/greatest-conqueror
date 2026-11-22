// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import CoreGraphics
import GameCore
import SpriteKit
import Testing
@testable import MapDrawing

@MainActor
@Suite struct SceneTests {
    func scene(_ view: PlayerView, camera: Camera = Camera(centre: MapPosition(x: 10, y: 10), zoom: 1),
               sprites: any SpriteSource = EmptySpriteSource()) -> (MapScene, PlayerSession, OrderLog) {
        let (session, log) = makeSession(view, camera: camera)
        let scene = MapScene(session: session, sprites: sprites, size: screenSize)
        return (scene, session, log)
    }

    func point(_ scene: MapScene, _ x: Double, _ y: Double, lift: Double = 0) -> CGPoint {
        let p = scene.geometry.scenePoint(for: MapPosition(x: x, y: y))
        return CGPoint(x: p.x, y: p.y + lift)
    }

    // MARK: Drawing

    @Test func drawsANodePerEntityAndPerSiteAndRemovesWhatLeavesTheView() {
        let view = Samples.farmsAgeSkirmish()
        let (scene, session, _) = scene(view)
        #expect(scene.entityNodeCount == view.entities.count)
        #expect(scene.siteNodeCount == view.sites.count)

        var next = view
        next.tick += 1
        next.entities.removeLast()
        next.sites.removeFirst()
        session.update(next)
        scene.updateFromSession()
        #expect(scene.entityNodeCount == next.entities.count)
        #expect(scene.siteNodeCount == next.sites.count)
    }

    @Test func entitiesAreDrawnInIncreasingDepth() {
        let view = Samples.farmsAgeSkirmish()
        let (scene, _, _) = scene(view)
        for entity in view.entities {
            let node = scene.entityNodes[entity.id]!
            #expect(abs(node.zPosition - Projection.depth(entity.position)) < 1e-4)
            let s = Projection.screen(entity.position)
            #expect(node.position == CGPoint(x: s.x, y: s.y))
        }
    }

    @Test func theTerrainTileMapLaysTilesAsTheProjectionDoes() throws {
        let view = Samples.townsAgeOpening()
        let (scene, _, _) = scene(view)
        let layer = try #require(scene.terrain)
        for (x, y) in [(0, 0), (5, 7), (31, 31), (12, 3)] {
            let local = layer.node.centerOfTile(atColumn: x, row: view.mapHeight - 1 - y)
            let world = CGPoint(x: layer.node.position.x + local.x, y: layer.node.position.y + local.y)
            let expected = Projection.screen(GridPoint(x, y).centre)
            #expect(abs(world.x - expected.x) < 1e-3 && abs(world.y - expected.y) < 1e-3, "\(world) \(expected) \(x),\(y)")
        }
    }

    @Test func unexploredTilesAreBlackAndExploredOnesDarkened() throws {
        let view = Samples.townsAgeOpening()
        let (scene, _, _) = scene(view)
        let layer = try #require(scene.terrain)
        func definition(_ x: Int, _ y: Int) -> SKTileDefinition? { layer.node.tileDefinition(atColumn: x, row: view.mapHeight - 1 - y) }
        let unexplored = (0..<view.visibility.count).first { view.visibility[$0] == .unexplored }!
        let explored = (0..<view.visibility.count).first { view.visibility[$0] == .explored }!
        let visible = (0..<view.visibility.count).first { view.visibility[$0] == .visible }!
        let textures = [unexplored, explored, visible].map { definition($0 % 32, $0 / 32)?.textures.first }
        #expect(textures.allSatisfy { $0 != nil })
        #expect(textures[0] !== textures[1] && textures[1] !== textures[2] && textures[0] !== textures[2])
    }

    @Test func aChangeInVisibilityRedrawsOnlyThoseTiles() throws {
        var view = Samples.townsAgeOpening()
        let (scene, session, _) = scene(view)
        let layer = try #require(scene.terrain)
        let tile = (0..<view.visibility.count).first { view.visibility[$0] == .unexplored }!
        let before = layer.node.tileDefinition(atColumn: tile % 32, row: 31 - tile / 32)
        view.tick += 1
        view.visibility[tile] = .visible
        session.update(view)
        scene.updateFromSession()
        #expect(layer.node.tileDefinition(atColumn: tile % 32, row: 31 - tile / 32) !== before)
    }

    @Test func peopleWithoutArtworkAreDrawnAsPlaceholdersInTheTeamColour() {
        let view = Samples.townsAgeOpening()
        let (scene, _, _) = scene(view)
        let worker = scene.entityNodes[EntityID(2)]!
        #expect(worker.body.texture != nil)
        #expect(worker.body.size.height > 40 && worker.body.size.height <= 64)
        // Anchored between the feet, near the bottom of the figure.
        #expect(worker.body.anchorPoint.y < 0.2)
        // A building's anchor is the centre of its footprint diamond: on the picture's vertical middle line.
        let townCentre = scene.entityNodes[EntityID(1)]!
        #expect(abs(townCentre.body.anchorPoint.x - 0.5) < 1e-9)
        #expect(townCentre.body.size.width > 90)
    }

    @Test func facingLeftMirrorsPeopleButNotBuildings() {
        var view = Samples.farmsAgeSkirmish()
        view.entities = view.entities.map { var e = $0; e.facing = .left; return e }
        let (scene, _, _) = scene(view)
        for entity in view.entities {
            let node = scene.entityNodes[entity.id]!
            if case .unit = entity.kind { #expect(node.body.xScale == -1) } else { #expect(node.body.xScale == 1) }
        }
    }

    @Test func artworkIsUsedWhereSuppliedAndTintedWithTheTeamColour() {
        let view = Samples.townsAgeOpening()
        let (scene, _, _) = scene(view, sprites: SolidSource())
        let worker = scene.entityNodes[EntityID(2)]!
        #expect(worker.body.size == CGSize(width: 40, height: 80))
        #expect(abs(worker.body.anchorPoint.x - 0.5) < 1e-6 && abs(worker.body.anchorPoint.y - 0.1) < 1e-6)
        let mask = worker.body.children.compactMap { $0 as? SKSpriteNode }.first
        #expect(mask != nil)
        #expect(mask?.colorBlendFactor == 1)
        let team = TeamColour.of(.sumer)
        let colour = mask?.color.usingColorSpace(.sRGB)
        #expect(abs(Double(colour?.redComponent ?? 0) - team.red) < 0.01)
        #expect(abs(Double(colour?.greenComponent ?? 0) - team.green) < 0.01)
        // The town centre has no artwork in this source, so it stays a placeholder.
        #expect(scene.entityNodes[EntityID(1)]!.body.size.width > 90)
    }

    @Test func selectedAndDamagedEntitiesShowRingsAndHealthBars() {
        let view = Samples.farmsAgeSkirmish()
        let (scene, session, _) = scene(view)
        let wounded = view.entities.first { $0.health < $0.maxHealth && $0.owner == PlayerID(0) }!
        let healthy = view.entities.first { $0.health == $0.maxHealth && $0.kind == .unit(.worker) }!
        func shapes(_ id: EntityID) -> [SKShapeNode] { scene.entityNodes[id]!.children.compactMap { $0 as? SKShapeNode }.filter { !$0.isHidden } }
        func bars(_ id: EntityID) -> Int { scene.entityNodes[id]!.children.filter { !($0 is SKShapeNode) && $0 !== scene.entityNodes[id]!.body && !$0.isHidden }.count }
        #expect(shapes(healthy.id).isEmpty && bars(healthy.id) == 0)
        #expect(bars(wounded.id) == 1)
        session.selection = [healthy.id]
        scene.updateFromSession()
        #expect(shapes(healthy.id).count == 1 && bars(healthy.id) == 1)
        session.selection = []
        scene.updateFromSession()
        #expect(shapes(healthy.id).isEmpty && bars(healthy.id) == 0)
    }

    @Test func constructionProgressShowsOnABuildingUnderConstruction() {
        let view = Samples.farmsAgeSkirmish()
        let (scene, _, _) = scene(view)
        let tower = view.entities.first { $0.kind == .building(.watchTower) && $0.activity != .idle }!
        let visibleBars = scene.entityNodes[tower.id]!.children.filter { !($0 is SKShapeNode) && $0 !== scene.entityNodes[tower.id]!.body && !$0.isHidden }
        #expect(visibleBars.count >= 1)
        let bar = visibleBars.first!.children.first as? SKSpriteNode
        #expect(abs((bar?.xScale ?? 0) - 0.6) < 1e-6)
    }

    @Test func animationAlternatesTheFrameAFewTimesASecond() {
        let view = Samples.townsAgeOpening()
        let (scene, _, _) = scene(view)
        let walker = scene.entityNodes[EntityID(6)]!
        scene.step(at: 0.0)
        let first = walker.body.texture
        scene.step(at: 0.3)
        let second = walker.body.texture
        scene.step(at: 0.55)
        let third = walker.body.texture
        #expect(first !== second)
        #expect(first === third)
    }

    // MARK: The camera

    @Test func theSceneFollowsACameraChangedElsewhere() {
        let (scene, session, _) = scene(Samples.townsAgeOpening())
        session.camera = Camera(centre: MapPosition(x: 20, y: 18), zoom: 1.5)
        scene.updateFromSession()
        #expect(scene.appliedCamera == session.camera)
        let p = scene.geometry.scenePoint(for: MapPosition(x: 20, y: 18))
        #expect(abs(p.x - 720) < 1e-9 && abs(p.y - 450) < 1e-9)
        #expect(scene.world.xScale == 1.5)
        #expect(scene.world.position == scene.geometry.worldOrigin)
    }

    @Test func scrollingAndZoomingUpdateTheSessionsCameraWithinLimits() {
        let (scene, session, _) = scene(Samples.townsAgeOpening())
        let start = session.camera
        scene.scroll(contentBy: CGVector(dx: -200, dy: 0))
        #expect(session.camera.centre.x > start.centre.x && session.camera.centre.y < start.centre.y)
        scene.zoom(by: 100, about: CGPoint(x: 700, y: 400))
        #expect(session.camera.zoom == Camera.maximumZoom)
        scene.zoom(by: 0.0001, about: CGPoint(x: 700, y: 400))
        #expect(session.camera.zoom == Camera.minimumZoom)
        scene.scroll(contentBy: CGVector(dx: 1e7, dy: 1e7))
        #expect(session.camera.centre.x >= 0 && session.camera.centre.y >= 0)
    }

    @Test func arrowKeysScrollWhilstHeldAndStopWhenReleased() {
        let (scene, session, _) = scene(Samples.townsAgeOpening())
        scene.step(at: 0)
        let start = session.camera.centre
        scene.handleKeyDown(.arrow(.right))
        scene.step(at: 0.05)
        let moved = session.camera.centre
        // Right on the screen is +x and -y on the map.
        #expect(moved.x > start.x && moved.y < start.y)
        scene.handleKeyUp(.arrow(.right))
        scene.step(at: 0.1)
        #expect(session.camera.centre == moved)
    }

    // MARK: Selecting

    @Test func clickSelectsAndShiftAdds() {
        let view = Samples.townsAgeOpening()
        let (scene, session, _) = scene(view)
        scene.click(at: point(scene, 12, 9, lift: 20))
        #expect(session.selection == [EntityID(2)])
        scene.click(at: point(scene, 5, 6, lift: 20), additive: true)
        #expect(session.selection == [EntityID(2), EntityID(3)])
        scene.click(at: point(scene, 4.5, 20.5))
        #expect(session.selection.isEmpty)
    }

    @Test func draggingABoxSelectsOwnPeople() {
        let view = Samples.townsAgeOpening()
        let (scene, session, _) = scene(view)
        let feet = [EntityID(4), EntityID(5), EntityID(6)].map { scene.geometry.scenePoint(for: view.entity($0)!.position) }
        let a = CGPoint(x: feet.map(\.x).min()! - 15, y: feet.map(\.y).min()! - 10)
        let b = CGPoint(x: feet.map(\.x).max()! + 15, y: feet.map(\.y).max()! + 40)
        scene.mouseDownForTest(at: a)
        scene.mouseDraggedForTest(to: b)
        #expect(!scene.boxOutline.isHidden)
        scene.mouseUpForTest(at: b, additive: false)
        #expect(scene.boxOutline.isHidden)
        #expect(session.selection.contains(EntityID(4)) && session.selection.contains(EntityID(5)) && session.selection.contains(EntityID(6)))
        #expect(!session.selection.contains(EntityID(1)))
        // Shift adds.
        let c = point(scene, 5, 6, lift: -10), d = point(scene, 5, 6, lift: 40)
        scene.mouseDownForTest(at: CGPoint(x: c.x - 20, y: c.y))
        scene.mouseDraggedForTest(to: CGPoint(x: d.x + 20, y: d.y))
        scene.mouseUpForTest(at: CGPoint(x: d.x + 20, y: d.y), additive: true)
        #expect(session.selection.contains(EntityID(3)) && session.selection.contains(EntityID(4)))
    }

    @Test func aShortDragIsAClick() {
        let (scene, session, _) = scene(Samples.townsAgeOpening())
        let p = point(scene, 12, 9, lift: 20)
        scene.mouseDownForTest(at: p)
        scene.mouseDraggedForTest(to: CGPoint(x: p.x + 2, y: p.y))
        scene.mouseUpForTest(at: CGPoint(x: p.x + 2, y: p.y), additive: false)
        #expect(session.selection == [EntityID(2)])
    }

    // MARK: Orders

    @Test func rightClickIssuesTheContextualOrderThroughTheSession() {
        let view = Samples.farmsAgeSkirmish()
        let (scene, session, log) = scene(view)
        let worker = view.entities.first { $0.kind == .unit(.worker) }!
        session.selection = [worker.id]
        scene.updateFromSession()

        scene.rightClick(at: point(scene, 4.5, 20.5))
        #expect(log.orders.last == .move(units: [worker.id], to: MapPosition(x: 4.5, y: 20.5)))

        let gold = view.sites.first { $0.kind == .gold && $0.tile == GridPoint(18, 9) }!
        scene.rightClick(at: point(scene, Double(gold.tile.x) + 0.5, Double(gold.tile.y) + 0.5, lift: 6))
        #expect(log.orders.last == .gather(units: [worker.id], site: gold.id))

        let enemy = view.entities.first { $0.owner == PlayerID(1) && $0.kind == .unit(.spearman) }!
        scene.rightClick(at: point(scene, enemy.position.x, enemy.position.y, lift: 20))
        #expect(log.orders.last == .attack(units: [worker.id], target: enemy.id))
        #expect(log.orders.count == 3)
    }

    @Test func rightClickWithNoOwnPeopleSelectedDoesNothing() {
        let (scene, _, log) = scene(Samples.townsAgeOpening())
        scene.rightClick(at: point(scene, 4.5, 20.5))
        #expect(log.orders.isEmpty)
    }

    @Test func rightClickGroundIsClampedToTheMap() {
        let (scene, session, log) = scene(Samples.townsAgeOpening())
        session.selection = [EntityID(2)]
        scene.rightClick(at: point(scene, -10, 40))
        #expect(log.orders.last == .move(units: [EntityID(2)], to: MapPosition(x: 0, y: 32)))
    }

    // MARK: Placing

    @Test func thePlacementOutlineIsGreenWhereAllowedAndRedWhereNot() {
        let view = Samples.townsAgeOpening()
        let (scene, session, _) = scene(view)
        session.placing = .house
        scene.pointer = point(scene, 16, 18)
        scene.updateFromSession()
        #expect(scene.placementState?.canPlace == true)
        #expect(scene.placementState?.origin == Placement.origin(.house, centre: MapPosition(x: 16, y: 18)))
        #expect(!scene.placementOutline.isHidden)
        #expect(scene.placementOutline.strokeColor.usingColorSpace(.sRGB)!.greenComponent > 0.8)

        scene.pointer = point(scene, 9.5, 9.5)   // on the town centre
        scene.step(at: 1)
        #expect(scene.placementState?.canPlace == false)
        #expect(scene.placementOutline.strokeColor.usingColorSpace(.sRGB)!.redComponent > 0.8)

        scene.pointer = point(scene, 1, 31)   // unexplored
        scene.step(at: 1.1)
        #expect(scene.placementState?.canPlace == false)

        session.placing = nil
        scene.updateFromSession()
        #expect(scene.placementOutline.isHidden && scene.placementState == nil)
    }

    @Test func clickingPlacesTheBuildingWithTheSelectedWorkers() {
        let view = Samples.townsAgeOpening()
        let (scene, session, log) = scene(view)
        session.selection = [EntityID(6), EntityID(2)]
        session.placing = .house
        let target = point(scene, 16, 18)
        scene.click(at: target)
        let origin = Placement.origin(.house, centre: scene.geometry.mapPosition(for: target))
        #expect(log.orders == [.construct(workers: [EntityID(6), EntityID(2)], building: .house, at: origin)])
        #expect(session.placing == nil)
    }

    @Test func shiftClickKeepsPlacing() {
        let (scene, session, log) = scene(Samples.townsAgeOpening())
        session.selection = [EntityID(6)]
        session.placing = .house
        scene.click(at: point(scene, 16, 18), additive: true)
        #expect(log.orders.count == 1 && session.placing == .house)
    }

    @Test func aBlockedPlacementIssuesNothingAndSaysWhy() {
        let (scene, session, log) = scene(Samples.townsAgeOpening())
        session.selection = [EntityID(6)]
        session.placing = .house
        scene.click(at: point(scene, 9.5, 9.5))
        #expect(log.orders.isEmpty && session.lastRefusal == .placementBlocked && session.placing == .house)
    }

    @Test func placingWithoutAWorkerSelectedIssuesNothing() {
        let (scene, session, log) = scene(Samples.townsAgeOpening())
        session.selection = [EntityID(1)]
        session.placing = .house
        scene.click(at: point(scene, 16, 18))
        #expect(log.orders.isEmpty && session.lastRefusal == .notYours)
    }

    @Test func escapeAndRightClickCancelPlacing() {
        let (scene, session, log) = scene(Samples.townsAgeOpening())
        session.placing = .barracks
        scene.handleKeyDown(.escape)
        #expect(session.placing == nil)
        session.placing = .barracks
        session.selection = [EntityID(6)]
        scene.rightClick(at: point(scene, 4.5, 20.5))
        #expect(session.placing == nil && log.orders.isEmpty)
    }

    // MARK: Groups

    @Test func shiftCAsksForTheCarAndACarGlowsOutToItsRadius() {
        var view = Samples.townsAgeOpening()
        let car = EntityID(9200)
        view.entities.append(EntityView(id: car, owner: view.player, kind: .unit(.car), position: MapPosition(x: 12.5, y: 12.5),
                                        tile: GridPoint(12, 12), facing: .right, health: 1, maxHealth: 1, activity: .idle))
        let (scene, _, log) = scene(view)
        scene.handleKeyDown(.summonCar)
        #expect(log.orders == [.summonCar])
        let glow = scene.entityNodes[car]?.glow
        #expect(glow != nil)
        // The glow reaches the kill radius: its outer band spans 2 × 11 tiles across the diamond.
        let outer = glow?.children.first as? SKShapeNode
        let width = outer?.path?.boundingBox.width ?? 0
        #expect(abs(width - 2 * 11 * Projection.tileWidth / 2 * 2.squareRoot()) < Projection.tileWidth)
        // Beneath every person and building.
        #expect((glow?.zPosition ?? 0) + (scene.entityNodes[car]?.zPosition ?? 0) < 0)
        // Nobody else glows.
        #expect(scene.entityNodes[EntityID(2)]?.glow == nil)
    }

    @Test func commandNumberSetsAGroupAndTheNumberAloneRecallsIt() {
        let (scene, session, _) = scene(Samples.townsAgeOpening())
        session.selection = [EntityID(2), EntityID(4)]
        scene.handleKeyDown(.digit(1), command: true)
        #expect(session.groups[1] == [EntityID(2), EntityID(4)])
        session.selection = []
        scene.handleKeyDown(.digit(1))
        #expect(session.selection == [EntityID(2), EntityID(4)])
        scene.handleKeyDown(.digit(7))
        #expect(session.selection == [EntityID(2), EntityID(4)])
    }

    @Test func aGroupRecallDropsEntitiesThatNoLongerExist() {
        let view = Samples.townsAgeOpening()
        let (scene, session, _) = scene(view)
        session.groups[2] = [EntityID(2), EntityID(999)]
        scene.handleKeyDown(.digit(2))
        #expect(session.selection == [EntityID(2)])
    }
}
