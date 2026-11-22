// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import MapDrawing

@Suite struct CommandsTests {
    let view = Samples.bronzeAgeSkirmish()

    func id(_ kind: EntityKind, owner: Int = 0, nth: Int = 0) -> EntityID {
        view.entities.filter { $0.kind == kind && $0.owner == PlayerID(owner) }[nth].id
    }

    @Test func clickSelectionReplacesOrAddsOrToggles() {
        let a = EntityID(2), b = EntityID(3)
        #expect(MapCommands.selection(afterClickOn: a, current: [b], additive: false) == [a])
        #expect(MapCommands.selection(afterClickOn: a, current: [b], additive: true) == [b, a])
        #expect(MapCommands.selection(afterClickOn: a, current: [a, b], additive: true) == [b])
        #expect(MapCommands.selection(afterClickOn: nil, current: [a], additive: false) == [])
        #expect(MapCommands.selection(afterClickOn: nil, current: [a], additive: true) == [a])
    }

    @Test func boxSelectionReplacesOrAdds() {
        let a = EntityID(2), b = EntityID(3), c = EntityID(4)
        #expect(MapCommands.selection(afterBoxHolding: [b, c], current: [a], additive: false) == [b, c])
        #expect(MapCommands.selection(afterBoxHolding: [b, c], current: [a, b], additive: true) == [a, b, c])
    }

    @Test func groundGivesMove() {
        let worker = id(.unit(.worker))
        let order = MapCommands.contextualOrder(on: .ground(MapPosition(x: 3, y: 4)), view: view, selection: [worker])
        #expect(order == .move(units: [worker], to: MapPosition(x: 3, y: 4)))
    }

    @Test func siteGivesGatherForWorkersOnly() {
        let worker = id(.unit(.worker)), scholar = id(.unit(.scholar))
        let tree = view.sites.first { $0.kind == .tree }!
        #expect(MapCommands.contextualOrder(on: .site(tree), view: view, selection: [worker, scholar])
                == .gather(units: [worker], site: tree.id))
        #expect(MapCommands.contextualOrder(on: .site(tree), view: view, selection: [scholar])
                == .move(units: [scholar], to: tree.tile.centre))
    }

    @Test func aSiteInTheWaterGivesGatherForBoatsOnly() {
        var view = self.view
        let worker = id(.unit(.worker))
        var boat = view.entity(worker)!
        boat.id = EntityID(9_000)
        boat.kind = .unit(.boat)
        view.entities.append(boat)
        var stone = view.sites.first { $0.kind == .stone }!
        stone.id = SiteID(9_000)
        view.sites.append(stone)
        view.terrain[stone.tile.y * view.mapWidth + stone.tile.x] = .deepWater
        #expect(MapCommands.contextualOrder(on: .site(stone), view: view, selection: [worker, boat.id])
                == .gather(units: [boat.id], site: stone.id))
        #expect(MapCommands.contextualOrder(on: .site(stone), view: view, selection: [worker])
                == .move(units: [worker], to: stone.tile.centre))
        let tree = view.sites.first { $0.kind == .tree }!
        #expect(MapCommands.contextualOrder(on: .site(tree), view: view, selection: [worker, boat.id])
                == .gather(units: [worker], site: tree.id))
    }

    @Test func ownUnfinishedOrDamagedBuildingGivesWorkForEngineers() {
        let engineer = id(.unit(.engineer)), worker = id(.unit(.worker))
        let tower = view.entities.first { $0.kind == .building(.watchTower) }!
        #expect(MapCommands.contextualOrder(on: .entity(tower), view: view, selection: [engineer, worker])
                == .work(units: [engineer], at: tower.id))
        var damaged = view.entity(id(.building(.house)))!
        damaged.health -= 10
        #expect(MapCommands.contextualOrder(on: .entity(damaged), view: view, selection: [engineer])
                == .work(units: [engineer], at: damaged.id))
        // A sound house is only walked to.
        let house = view.entity(id(.building(.house)))!
        #expect(MapCommands.contextualOrder(on: .entity(house), view: view, selection: [engineer])
                == .move(units: [engineer], to: house.position))
    }

    @Test func ownTownCentreAndStockPenGiveWork() {
        let worker = id(.unit(.worker)), scholar = id(.unit(.scholar)), clubman = id(.unit(.clubman))
        let townCentre = view.entity(id(.building(.townCentre)))!
        #expect(MapCommands.contextualOrder(on: .entity(townCentre), view: view, selection: [worker, scholar, clubman])
                == .work(units: [worker, scholar], at: townCentre.id))
        let pen = view.entity(id(.building(.stockPen)))!
        #expect(MapCommands.contextualOrder(on: .entity(pen), view: view, selection: [worker])
                == .work(units: [worker], at: pen.id))
        #expect(MapCommands.contextualOrder(on: .entity(pen), view: view, selection: [clubman])
                == .move(units: [clubman], to: pen.position))
    }

    @Test func aCompleteFarmOrWorkshopTakesWorkers() {
        var v = view
        v.age = .alchemy
        let worker = id(.unit(.worker)), clubman = id(.unit(.clubman))
        for kind in [BuildingKind.farm, .alchemistsWorkshop] {
            let place = EntityView(id: EntityID(9000 + kind.rawValue), owner: v.player, kind: .building(kind),
                                   position: MapPosition(x: 20.5, y: 20.5), tile: GridPoint(20, 20), facing: .right, health: 100, maxHealth: 100,
                                   activity: .idle)
            v.entities.append(place)
            #expect(MapCommands.contextualOrder(on: .entity(place), view: v, selection: [worker, clubman])
                    == .work(units: [worker], at: place.id), "\(kind)")
            var unfinished = place
            unfinished.activity = .underConstruction(0.5)
            #expect(MapCommands.contextualOrder(on: .entity(unfinished), view: v, selection: [worker])
                    == .move(units: [worker], to: place.position), "\(kind)")
        }
    }

    @Test func scholarsWorkAtACompleteBuildingThatResearches() {
        let scholar = id(.unit(.scholar)), clubman = id(.unit(.clubman))
        let barracks = view.entity(id(.building(.barracks)))!
        #expect(MapCommands.contextualOrder(on: .entity(barracks), view: view, selection: [scholar, clubman])
                == .work(units: [scholar], at: barracks.id))
        var unfinished = barracks
        unfinished.activity = .underConstruction(0.5)
        #expect(MapCommands.contextualOrder(on: .entity(unfinished), view: view, selection: [scholar])
                == .move(units: [scholar], to: barracks.position))
        // A house researches nothing: scholars only go there.
        let house = view.entity(id(.building(.house)))!
        #expect(MapCommands.contextualOrder(on: .entity(house), view: view, selection: [scholar])
                == .move(units: [scholar], to: house.position))
    }

    @Test func aDoubleClickSelectsThoseOfTheSameKindAndJobOnScreen() {
        var v = view
        let workers = v.entities.filter { $0.owner == v.player && $0.kind == .unit(.worker) }.map(\.id)
        #expect(workers.count >= 2)
        let extra = EntityID(9001), idle = EntityID(9002), far = EntityID(9003)
        for (id, job) in [(extra, Job.gathering(.tree)), (idle, .idle), (far, .gathering(.tree))] {
            v.entities.append(EntityView(id: id, owner: v.player, kind: .unit(.worker), position: MapPosition(x: 5.5, y: 5.5),
                                         tile: GridPoint(5, 5), facing: .right, health: 25, maxHealth: 25, activity: .idle))
            v.entities[v.entities.count - 1].job = job
        }
        for i in v.entities.indices where v.entities[i].id == workers[0] { v.entities[i].job = .gathering(.tree) }
        let clubman = id(.unit(.clubman))
        let onScreen = [workers[0], extra, idle, clubman]   // `far` is off the screen
        // Lumberjacks on the screen, whether chopping or carrying; not the idle one, the clubman or the one off the screen.
        #expect(MapCommands.selection(afterDoubleClickOn: workers[0], onScreen: onScreen, view: v) == [workers[0], extra])
        #expect(MapCommands.selection(afterDoubleClickOn: idle, onScreen: onScreen, view: v) == [idle])
        // A building, an opponent or nothing: as a single click.
        let barracks = id(.building(.barracks))
        #expect(MapCommands.selection(afterDoubleClickOn: barracks, onScreen: onScreen, view: v) == [barracks])
        #expect(MapCommands.selection(afterDoubleClickOn: nil, onScreen: onScreen, view: v) == [])
    }

    @Test func anOpponentGivesAttack() {
        let clubman = id(.unit(.clubman))
        let enemy = view.entity(id(.unit(.spearman), owner: 1))!
        #expect(MapCommands.contextualOrder(on: .entity(enemy), view: view, selection: [clubman])
                == .attack(units: [clubman], target: enemy.id))
        let enemyTown = view.entity(id(.building(.townCentre), owner: 1))!
        #expect(MapCommands.contextualOrder(on: .entity(enemyTown), view: view, selection: [clubman])
                == .attack(units: [clubman], target: enemyTown.id))
    }

    @Test func nothingIsOrderedWithoutOwnPeopleSelected() {
        let enemy = view.entity(id(.unit(.spearman), owner: 1))!
        let house = id(.building(.house))
        #expect(MapCommands.contextualOrder(on: .ground(MapPosition(x: 1, y: 1)), view: view, selection: []) == nil)
        #expect(MapCommands.contextualOrder(on: .ground(MapPosition(x: 1, y: 1)), view: view, selection: [enemy.id]) == nil)
        #expect(MapCommands.contextualOrder(on: .ground(MapPosition(x: 1, y: 1)), view: view, selection: [house]) == nil)
    }
}
