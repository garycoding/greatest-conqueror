// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import MapDrawing

@Suite struct CommandsTests {
    let view = Samples.farmsAgeSkirmish()

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
        let worker = id(.unit(.worker)), spearman = id(.unit(.soldier1))
        let tree = view.sites.first { $0.kind == .tree }!
        #expect(MapCommands.contextualOrder(on: .site(tree), view: view, selection: [worker, spearman])
                == .gather(units: [worker], site: tree.id))
        #expect(MapCommands.contextualOrder(on: .site(tree), view: view, selection: [spearman])
                == .move(units: [spearman], to: tree.tile.centre))
    }

    /// A right-click on a fruit bush with workers selected gathers it (ruled 2026-11-22).
    @Test func aFruitBushGivesGatherForWorkers() {
        var view = self.view
        let worker = id(.unit(.worker)), spearman = id(.unit(.soldier1))
        var bush = view.sites.first { $0.kind == .tree }!
        bush.id = SiteID(9_001)
        bush.kind = .fruit
        view.sites.append(bush)
        #expect(MapCommands.contextualOrder(on: .site(bush), view: view, selection: [worker, spearman])
                == .gather(units: [worker], site: bush.id))
        #expect(MapCommands.contextualOrder(on: .site(bush), view: view, selection: [spearman])
                == .move(units: [spearman], to: bush.tile.centre))
    }

    @Test func aSiteInTheWaterGivesGatherForBoatsOnly() {
        var view = self.view
        let worker = id(.unit(.worker))
        var boat = view.entity(worker)!
        boat.id = EntityID(9_000)
        boat.kind = .unit(.fishingBoat)
        view.entities.append(boat)
        var gold = view.sites.first { $0.kind == .gold }!
        gold.id = SiteID(9_000)
        view.sites.append(gold)
        view.terrain[gold.tile.y * view.mapWidth + gold.tile.x] = .deepWater
        #expect(MapCommands.contextualOrder(on: .site(gold), view: view, selection: [worker, boat.id])
                == .gather(units: [boat.id], site: gold.id))
        #expect(MapCommands.contextualOrder(on: .site(gold), view: view, selection: [worker])
                == .move(units: [worker], to: gold.tile.centre))
        let tree = view.sites.first { $0.kind == .tree }!
        #expect(MapCommands.contextualOrder(on: .site(tree), view: view, selection: [worker, boat.id])
                == .gather(units: [worker], site: tree.id))
    }

    @Test func ownUnfinishedOrDamagedBuildingGivesWorkForWorkers() {
        let worker = id(.unit(.worker)), spearman = id(.unit(.soldier1))
        let tower = view.entities.first { $0.kind == .building(.tower) && $0.activity != .idle }!
        #expect(MapCommands.contextualOrder(on: .entity(tower), view: view, selection: [worker, spearman])
                == .work(units: [worker], at: tower.id))
        var damaged = view.entity(id(.building(.house)))!
        damaged.health -= 10
        #expect(MapCommands.contextualOrder(on: .entity(damaged), view: view, selection: [worker])
                == .work(units: [worker], at: damaged.id))
        // A sound house is only walked to.
        let house = view.entity(id(.building(.house)))!
        #expect(MapCommands.contextualOrder(on: .entity(house), view: view, selection: [worker])
                == .move(units: [worker], to: house.position))
        // So is a sound town centre.
        let townCentre = view.entity(id(.building(.townCentre)))!
        #expect(MapCommands.contextualOrder(on: .entity(townCentre), view: view, selection: [worker, spearman])
                == .move(units: [worker, spearman], to: townCentre.position))
    }

    @Test func aFarmTakesWorkers() {
        var v = view
        v.age = .ships
        let worker = id(.unit(.worker)), spearman = id(.unit(.soldier1))
        let place = EntityView(id: EntityID(9000), owner: v.player, kind: .building(.farm),
                               position: MapPosition(x: 20.5, y: 20.5), tile: GridPoint(20, 20), facing: .right, health: 150,
                               maxHealth: 150, activity: .idle)
        v.entities.append(place)
        #expect(MapCommands.contextualOrder(on: .entity(place), view: v, selection: [worker, spearman])
                == .work(units: [worker], at: place.id))
        #expect(MapCommands.contextualOrder(on: .entity(place), view: v, selection: [spearman])
                == .move(units: [spearman], to: place.position))
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
        let clubman = id(.unit(.soldier1))
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
        let clubman = id(.unit(.soldier1))
        let enemy = view.entity(id(.unit(.soldier1), owner: 1))!
        #expect(MapCommands.contextualOrder(on: .entity(enemy), view: view, selection: [clubman])
                == .attack(units: [clubman], target: enemy.id))
        let enemyTown = view.entity(id(.building(.townCentre), owner: 1))!
        #expect(MapCommands.contextualOrder(on: .entity(enemyTown), view: view, selection: [clubman])
                == .attack(units: [clubman], target: enemyTown.id))
    }

    @Test func nothingIsOrderedWithoutOwnPeopleSelected() {
        let enemy = view.entity(id(.unit(.soldier1), owner: 1))!
        let house = id(.building(.house))
        #expect(MapCommands.contextualOrder(on: .ground(MapPosition(x: 1, y: 1)), view: view, selection: []) == nil)
        #expect(MapCommands.contextualOrder(on: .ground(MapPosition(x: 1, y: 1)), view: view, selection: [enemy.id]) == nil)
        #expect(MapCommands.contextualOrder(on: .ground(MapPosition(x: 1, y: 1)), view: view, selection: [house]) == nil)
    }

    // MARK: Navy ships, doctors and founders (requirements 13 and 16, ruled 2026-11-22)

    /// The skirmish with a navy ship of the player's beside its first worker.
    func withShip(passengers: Int) -> (PlayerView, EntityID) {
        var view = self.view
        var ship = view.entity(id(.unit(.worker)))!
        ship.id = EntityID(9_100)
        ship.kind = .unit(.navyShip)
        ship.passengers = passengers
        view.entities.append(ship)
        return (view, ship.id)
    }

    @Test func troopsRightClickedOntoTheirShipBoardIt() {
        let (view, ship) = withShip(passengers: 0)
        let worker = id(.unit(.worker)), spearman = id(.unit(.soldier1))
        #expect(MapCommands.contextualOrder(on: .entity(view.entity(ship)!), view: view, selection: [worker, spearman])
                == .board(units: [worker, spearman], ship: ship))
    }

    @Test func aLoadedShipRightClickedOntoLandLandsAndOntoWaterMoves() {
        var (view, ship) = withShip(passengers: 3)
        let land = MapPosition(x: 3.5, y: 4.5)
        #expect(MapCommands.contextualOrder(on: .ground(land), view: view, selection: [ship]) == .land(ships: [ship], at: land))
        view.terrain[4 * view.mapWidth + 3] = .deepWater
        #expect(MapCommands.contextualOrder(on: .ground(land), view: view, selection: [ship]) == .move(units: [ship], to: land))
        let (empty, unloaded) = withShip(passengers: 0)
        #expect(MapCommands.contextualOrder(on: .ground(MapPosition(x: 3.5, y: 6.5)), view: empty, selection: [unloaded])
                == .move(units: [unloaded], to: MapPosition(x: 3.5, y: 6.5)))
    }

    @Test func doctorsRightClickedOntoAWoundedUnitOfTheirsHealIt() {
        var view = self.view
        var doctor = view.entity(id(.unit(.worker)))!
        doctor.id = EntityID(9_200)
        doctor.kind = .unit(.doctor)
        view.entities.append(doctor)
        let spearman = id(.unit(.soldier1))
        let i = view.entities.firstIndex { $0.id == spearman }!
        view.entities[i].health = 1
        #expect(MapCommands.contextualOrder(on: .entity(view.entities[i]), view: view, selection: [doctor.id])
                == .heal(doctors: [doctor.id], target: spearman))
        view.entities[i].health = view.entities[i].maxHealth
        #expect(MapCommands.contextualOrder(on: .entity(view.entities[i]), view: view, selection: [doctor.id])
                == .move(units: [doctor.id], to: view.entities[i].position))
    }
}

