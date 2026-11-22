// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore
import Testing
@testable import MapDrawing

@Suite struct HitTestingTests {
    let view = Samples.bronzeAgeSkirmish()

    func entity(_ id: Int) -> EntityView { view.entity(EntityID(id))! }

    @Test func aPersonIsFoundUnderItsBodyAtAnyZoom() {
        let worker = entity(2)
        for zoom in [0.5, 1.0, 2.0] {
            let g = geometry(10, 10, zoom: zoom)
            let foot = g.scenePoint(for: worker.position)
            for dy in [0.0, 20, 44] {
                let hit = MapHitTesting.entity(at: CGPoint(x: foot.x, y: foot.y + dy * zoom), in: view, geometry: g)
                #expect(hit?.id == worker.id)
            }
            #expect(MapHitTesting.entity(at: CGPoint(x: foot.x + 40 * zoom, y: foot.y + 20 * zoom), in: view, geometry: g)?.id != worker.id)
        }
    }

    @Test func aBuildingIsFoundOverItsFootprintAndBlock() {
        let townCentre = entity(1)
        let g = geometry(10, 10)
        let centre = g.scenePoint(for: townCentre.position)
        #expect(MapHitTesting.entity(at: centre, in: view, geometry: g)?.id == townCentre.id)
        // On the block above the footprint's top corner.
        let top = g.scenePoint(for: MapPosition(x: 9.5, y: 8.2))
        #expect(MapHitTesting.entity(at: CGPoint(x: top.x, y: top.y + 30), in: view, geometry: g)?.id == townCentre.id)
        // Well above the block, and beside the footprint, there is nothing.
        #expect(MapHitTesting.entity(at: CGPoint(x: top.x, y: top.y + 120), in: view, geometry: g) == nil)
        let beside = g.scenePoint(for: MapPosition(x: 14.9, y: 4.0))
        #expect(MapHitTesting.entity(at: beside, in: view, geometry: g) == nil)
    }

    @Test func aPersonStandingBeforeABuildingIsPreferred() {
        var crowded = view
        let townCentre = crowded.entity(EntityID(1))!
        crowded.entities.append(EntityView(id: EntityID(900), owner: PlayerID(0), kind: .unit(.worker),
                                           position: townCentre.position, tile: townCentre.position.tile, facing: .right,
                                           health: 25, maxHealth: 25, activity: .idle))
        let g = geometry(10, 10)
        let foot = g.scenePoint(for: townCentre.position)
        #expect(MapHitTesting.entity(at: CGPoint(x: foot.x, y: foot.y + 10), in: crowded, geometry: g)?.id == EntityID(900))
    }

    @Test func ofTwoBuildingsTheNearerToTheViewerWins() {
        // The tower at (15.5, 13.5) is nearer the viewer than the barracks at (13.5, 6.5); a point on both blocks picks the tower.
        let g = geometry(14, 10)
        let tower = entity(Int(view.entities.first { $0.kind == .building(.watchTower) }!.id.rawValue))
        let point = g.scenePoint(for: tower.position)
        #expect(MapHitTesting.entity(at: CGPoint(x: point.x, y: point.y + 20), in: view, geometry: g)?.id == tower.id)
    }

    @Test func aSiteIsFoundOnItsTileOnlyOnceExplored() {
        let g = geometry(10, 10)
        let tree = view.sites.first { $0.kind == .tin }!
        let p = g.scenePoint(for: tree.tile.centre)
        #expect(MapHitTesting.site(at: CGPoint(x: p.x, y: p.y + 10), in: view, geometry: g)?.id == tree.id)
        var hidden = view
        hidden.visibility = Array(repeating: .unexplored, count: hidden.visibility.count)
        #expect(MapHitTesting.site(at: CGPoint(x: p.x, y: p.y + 10), in: hidden, geometry: g) == nil)
    }

    @Test func anOilFieldUnderAWellIsHiddenByIt() {
        let g = geometry(10, 10)
        var oily = view
        let field = ResourceSite(id: SiteID(9999), kind: .oilField, tile: GridPoint(10, 10), remaining: 2000)
        oily.sites.append(field)
        let p = g.scenePoint(for: field.tile.centre)
        #expect(MapHitTesting.site(at: CGPoint(x: p.x, y: p.y + 4), in: oily, geometry: g)?.id == field.id)
        oily.entities.append(EntityView(id: EntityID(9999), owner: oily.player, kind: .building(.oilWell),
                                        position: MapPosition(x: 11, y: 11), tile: GridPoint(10, 10), facing: .right,
                                        health: 300, maxHealth: 300, activity: .idle))
        #expect(MapHitTesting.coveredSiteTiles(in: oily).contains(field.tile))
        #expect(MapHitTesting.site(at: CGPoint(x: p.x, y: p.y + 4), in: oily, geometry: g) == nil)
    }

    @Test func targetIsEntityThenSiteThenGround() {
        let g = geometry(10, 10)
        let worker = entity(2)
        let foot = g.scenePoint(for: worker.position)
        if case .entity(let hit) = MapHitTesting.target(at: CGPoint(x: foot.x, y: foot.y + 10), in: view, geometry: g) {
            #expect(hit.id == worker.id)
        } else { Issue.record("expected an entity") }
        let tin = view.sites.first { $0.kind == .tin }!
        let siteTop = g.scenePoint(for: tin.tile.centre)
        if case .site(let hit) = MapHitTesting.target(at: CGPoint(x: siteTop.x, y: siteTop.y + 6), in: view, geometry: g) {
            #expect(hit.id == tin.id)
        } else { Issue.record("expected a site") }
        let ground = g.scenePoint(for: MapPosition(x: 4.5, y: 20.5))
        if case .ground(let position) = MapHitTesting.target(at: ground, in: view, geometry: g) {
            #expect(abs(position.x - 4.5) < 1e-9 && abs(position.y - 20.5) < 1e-9)
        } else { Issue.record("expected ground") }
    }

    @Test func aBoxHoldsOnlyTheOwnPeopleWhoseBodiesLieInIt() {
        let g = geometry(14, 11)
        // A box round the player's fighters (own) and the opponent's spearman (not own).
        let a = g.scenePoint(for: MapPosition(x: 14.5, y: 10.5)), b = g.scenePoint(for: MapPosition(x: 19.5, y: 14.5))
        let box = CGRect(x: min(a.x, b.x) - 60, y: min(a.y, b.y) - 60, width: abs(a.x - b.x) + 120, height: abs(a.y - b.y) + 120)
        let ids = MapHitTesting.ownPeople(in: box, view: view, geometry: g)
        #expect(!ids.isEmpty)
        for id in ids {
            let e = view.entity(id)!
            #expect(e.owner == view.player)
            if case .unit = e.kind {} else { Issue.record("a building was boxed") }
        }
        #expect(!ids.contains(EntityID(view.entities.last { $0.owner == PlayerID(1) && $0.kind == .unit(.spearman) }!.id.rawValue)))
        // An empty box holds nothing, and a box over a building alone holds nothing.
        #expect(MapHitTesting.ownPeople(in: CGRect(x: 0, y: 0, width: 5, height: 5), view: view, geometry: g).isEmpty)
        let tc = g.scenePoint(for: entity(1).position)
        #expect(MapHitTesting.ownPeople(in: CGRect(x: tc.x - 8, y: tc.y - 8, width: 16, height: 16), view: view, geometry: geometry(10, 10)).isEmpty)
    }

    @Test func aBoxCoversExactlyThePeopleInsideAtEveryZoom() {
        for zoom in [0.5, 1.0, 2.0] {
            let g = geometry(10, 10, zoom: zoom)
            let box = CGRect(x: 0, y: 0, width: 1440, height: 900)
            let all = MapHitTesting.ownPeople(in: box, view: view, geometry: g)
            let expected = view.entities.filter { if case .unit = $0.kind { $0.owner == view.player && box.contains(CGPoint(x: g.scenePoint(for: $0.position).x, y: g.scenePoint(for: $0.position).y + 20 * zoom)) } else { false } }
            #expect(all == expected.map(\.id))
        }
    }
}

/// A building drawn taller than its block is hit up to the top of its drawing,
/// measured from its anchor, and no higher, even over its back corner.
@Test func aTallBuildingIsHitUpToTheTopOfItsDrawingAndNoHigher() {
    var view = Samples.bronzeAgeSkirmish()
    view.entities.removeAll { if case .unit = $0.kind { true } else { false } }
    let centre = view.entities.first { $0.kind == .building(.townCentre) && $0.owner == view.player }!
    let g = geometry(centre.position.x, centre.position.y)
    let anchor = g.scenePoint(for: centre.position)
    let tall: (EntityView) -> Double? = { $0.id == centre.id ? 100 : nil }
    // Over the anchor: hit below the top, missed above it.
    #expect(MapHitTesting.entity(at: CGPoint(x: anchor.x, y: anchor.y + 95), in: view, geometry: g, drawnHeight: tall)?.id == centre.id)
    #expect(MapHitTesting.entity(at: CGPoint(x: anchor.x, y: anchor.y + 105), in: view, geometry: g, drawnHeight: tall)?.id != centre.id)
}
