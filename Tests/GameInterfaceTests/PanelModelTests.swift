// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameInterface

private let catalogue = Catalogue.standard

private func model(_ view: PlayerView, _ selection: [EntityID]) -> PanelModel {
    PanelModel(view: view, catalogue: catalogue, selection: selection)
}

private func offer(_ m: PanelModel, _ id: String) -> ActionOffer {
    m.actions.first { $0.id == id }!
}

// MARK: The opening, in the age of towns

@Test func theTownCentreOffersWorkers() {
    let view = Samples.townsAgeOpening()
    let m = model(view, [view.id(of: .building(.townCentre))])
    #expect(m.train.map(\.id) == ["train-worker"])
    #expect(m.build.isEmpty)
    #expect(offer(m, "train-worker").title == "Worker")
    #expect(offer(m, "train-worker").cost == ResourceAmounts([.food: 50]))
}

@Test func theOpeningIsAtItsPopulationLimitSoTrainingIsRefusedForThatReason() {
    let view = Samples.townsAgeOpening()   // 5 of 5
    let m = model(view, [view.id(of: .building(.townCentre))])
    let why = offer(m, "train-worker").unavailable
    #expect(why?.refusal == .populationLimit)
    #expect(why?.explanation == "Population full (5 of 5); build a house")
}

@Test func trainingIsAvailableWithRoomAndResources() {
    var view = Samples.townsAgeOpening()
    view.populationLimit = 10
    let tc = view.id(of: .building(.townCentre))
    let m = model(view, [tc])
    #expect(offer(m, "train-worker").isAvailable)
    #expect(offer(m, "train-worker").order == .train(at: tc, unit: .worker))
}

@Test func lackingResourcesNamesTheShortfall() {
    var view = Samples.townsAgeOpening()
    view.populationLimit = 10
    view.resources = ResourceAmounts([.food: 40, .wood: 5])
    let m = model(view, [view.id(of: .building(.townCentre))])
    let worker = offer(m, "train-worker").unavailable
    #expect(worker?.refusal == .notEnough(ResourceAmounts([.food: 10])))
    #expect(worker?.explanation == "Short of 10 Food")
}

@Test func workersOfferTheBuildingsOfTheAgesReached() {
    let view = Samples.townsAgeOpening()
    let m = model(view, [view.id(of: .unit(.worker))])
    #expect(m.build.map(\.id) == ["build-townCentre", "build-house"])
    #expect(m.train.isEmpty)
    // 140 wood is held: a town centre wants 300.
    let centre = offer(m, "build-townCentre").unavailable
    #expect(centre?.refusal == .notEnough(ResourceAmounts([.wood: 160])))
    #expect(offer(m, "build-house").isAvailable)
    #expect(offer(m, "build-house").action == .place(.house))
    #expect(offer(m, "build-house").order == nil)
}

@Test func nonWorkersOfferNoBuildings() {
    var view = Samples.townsAgeOpening()
    view.entities.append(EntityView(id: EntityID(900), owner: view.player, kind: .unit(.fishingBoat), position: MapPosition(x: 10, y: 12),
                                    tile: GridPoint(10, 12), facing: .right, health: 25, maxHealth: 25, activity: .idle))
    let m = model(view, [EntityID(900)])
    #expect(m.build.isEmpty)
    #expect(m.actions.map(\.id) == ["dismiss"])
}

@Test func theAgeIsCheckedBeforeResourcesAndTheLimit() {
    var view = Samples.farmsAgeSkirmish()
    view.resources = ResourceAmounts()
    let m = model(view, [view.id(of: .building(.barracks))])
    #expect(offer(m, "train-soldier2").unavailable?.refusal == .ageNotReached(.ships))
    #expect(offer(m, "train-soldier2").unavailable?.explanation == "Needs the age of ships")
    #expect(offer(m, "train-soldier1").unavailable?.refusal == .notEnough(ResourceAmounts([.food: 60, .gold: 20])))
}

// MARK: The skirmish, in the age of farms

@Test func theBarracksAtThePopulationLimit() {
    let view = Samples.farmsAgeSkirmish()   // 15 of 15
    let barracks = view.id(of: .building(.barracks))
    let m = model(view, [barracks])
    #expect(m.train.map(\.id) == ["train-soldier1", "train-soldier2", "train-soldier3", "train-soldier4"])
    #expect(offer(m, "train-soldier1").unavailable?.refusal == .populationLimit)
    #expect(offer(m, "train-soldier1").unavailable?.explanation == "Population full (15 of 15); build a house")
    // Resources are not the cause: 420 food, 310 wood, 60 gold.
    #expect(view.resources.covers(catalogue.stats(.soldier1).cost))
    #expect(offer(m, "train-soldier1").title == "Soldier 1")
}

@Test func theLimitAtItsMaximumSaysTheHousesCannotHelp() {
    var view = Samples.farmsAgeSkirmish()
    view.population = 200; view.populationLimit = 200
    let m = model(view, [view.id(of: .building(.barracks))])
    #expect(offer(m, "train-soldier1").unavailable?.explanation == "Population full (200 of 200)")
}

@Test func aKnightTakesTwoPlaces() {
    var view = Samples.farmsAgeSkirmish()
    view.age = .cannons
    view.population = 14
    view.resources = ResourceAmounts([.food: 1000, .wood: 1000, .gold: 1000])
    view.entities.append(EntityView(id: EntityID(900), owner: view.player, kind: .building(.stable),
                                    position: MapPosition(x: 25.5, y: 25.5), tile: GridPoint(24, 24), facing: .right,
                                    health: 500, maxHealth: 500, activity: .idle))
    // One place is left: a spearman takes it; a knight needs two.
    #expect(offer(model(view, [view.id(of: .building(.barracks))]), "train-soldier1").isAvailable)
    #expect(offer(model(view, [EntityID(900)]), "train-knight2").unavailable?.refusal == .populationLimit)
}

@Test func aBuildingUnderConstructionOffersOnlyDemolition() {
    let view = Samples.farmsAgeSkirmish()
    let tower = view.entities.first { $0.owner == view.player && $0.kind == .building(.tower) && $0.activity != .idle }!.id
    let m = model(view, [tower])
    #expect(m.actions.map(\.id) == ["demolish"])
    guard case .single(let detail) = m.content else { Issue.record("expected a single entity"); return }
    #expect(detail.name == "Tower")
    #expect(detail.progress == 0.6)
    #expect(detail.activity == "Under construction")
}

@Test func workersAndWarfightersTogetherOfferTheBuildingsAndDismissal() {
    let view = Samples.farmsAgeSkirmish()
    let m = model(view, view.ids(ofUnits: [.worker, .soldier1]))
    #expect(m.build.count == 6)
    #expect(offer(m, "build-barracks").isAvailable)           // 100 wood of 310
    #expect(offer(m, "build-tower").isAvailable)         // 100 wood of 310
    guard case .several(let total, let counts) = m.content else { Issue.record("expected several"); return }
    #expect(total == 9 + 4)
    #expect(counts.map(\.count) == [9, 4])
    #expect(counts.map(\.name) == ["Worker", "Soldier 1"])
}

// MARK: Contents

@Test func severalWorkersAreCountedByKind() {
    let view = Samples.townsAgeOpening()
    let m = model(view, view.ids(ofUnits: [.worker]))
    guard case .several(let total, let counts) = m.content else { Issue.record("expected several"); return }
    #expect(total == 5)
    #expect(counts.map(\.name) == ["Worker"])
    #expect(counts.map(\.count) == [5])
}

@Test func aSinglePersonIsShownWithHealthAndActivity() {
    let view = Samples.farmsAgeSkirmish()
    let spearman = view.entities.first { $0.owner == view.player && $0.kind == .unit(.soldier1) && $0.health < $0.maxHealth }!
    guard case .single(let d) = model(view, [spearman.id]).content else { Issue.record("expected single"); return }
    #expect(d.name == "Soldier 1")
    #expect(d.health == 43 && d.maxHealth == 55)
    #expect(abs(d.healthFraction - 43.0 / 55.0) < 1e-9)
    #expect(d.activity == "Fighting")
    #expect(d.ownerLine == "Sumer, yours")
}

@Test func aWorkerWalkingAndAWorkerHunting() {
    let view = Samples.townsAgeOpening()
    let walker = view.entities.first { $0.kind == .unit(.worker) && $0.activity == .moving }!
    guard case .single(let d) = model(view, [walker.id]).content else { Issue.record("expected single"); return }
    #expect(d.name == "Worker")
    #expect(d.activity == "Walking")
    let hunter = view.entities.first { $0.activity == .gathering(.prey) }!
    guard case .single(let h) = model(view, [hunter.id]).content else { Issue.record("expected single"); return }
    #expect(h.activity == "Hunting")
}

@Test func trainingShowsItsQueueAndProgress() {
    let view = Samples.farmsAgeSkirmish()
    guard case .single(let d) = model(view, [view.id(of: .building(.barracks))]).content else { Issue.record("expected single"); return }
    #expect(d.activity == "Training Soldier 1, 2 queued")
    #expect(d.progress == 0.4)
}

@Test func anOpponentsBuildingOffersNothingAndIsLabelled() {
    let view = Samples.farmsAgeSkirmish()
    let theirs = view.id(of: .building(.townCentre), owner: PlayerID(1))
    let m = model(view, [theirs])
    #expect(m.actions.isEmpty)
    guard case .single(let d) = m.content else { Issue.record("expected single"); return }
    #expect(d.ownerLine == "Egypt, opponent")
}

@Test func nothingSelectedOffersNothing() {
    let m = model(Samples.townsAgeOpening(), [])
    #expect(m.content == .nothing && m.actions.isEmpty)
}

@Test func aPausedOrFinishedMatchRefusesEverythingButNotAsAShortage() {
    var view = Samples.townsAgeOpening()
    view.populationLimit = 10
    view.isPaused = true
    var m = model(view, [view.id(of: .building(.townCentre))])
    #expect(m.actions.allSatisfy { $0.unavailable?.refusal == .notNow })
    #expect(offer(m, "train-worker").unavailable?.explanation == "The match is paused")
    view.isPaused = false
    view.outcome = .won(TeamID(1))
    m = model(view, [view.id(of: .building(.townCentre))])
    #expect(offer(m, "train-worker").unavailable?.explanation == "The match is over")
}

// MARK: Pressing buttons

@MainActor
@Test func anAvailableButtonIssuesItsOrder() {
    var view = Samples.townsAgeOpening()
    view.populationLimit = 10
    let tc = view.id(of: .building(.townCentre))
    let (session, recorder) = makeSession(view, select: [tc])
    PanelModel(session: session).offer(forKey: "w")!.perform(in: session)
    #expect(recorder.orders == [.train(at: tc, unit: .worker)])
    #expect(session.lastRefusal == nil)
}

@MainActor
@Test func anUnavailableButtonStaysLiveShowsItsRefusalAndIssuesNothing() {
    let view = Samples.townsAgeOpening()   // at its limit
    let (session, recorder) = makeSession(view, select: [view.id(of: .building(.townCentre))])
    let button = PanelModel(session: session).offer(forKey: "w")!
    #expect(!button.isAvailable)
    button.perform(in: session)
    #expect(recorder.orders.isEmpty)
    #expect(session.lastRefusal == .populationLimit)
    #expect(button.tooltip.contains("Not now: Population full (5 of 5); build a house."))
}

@MainActor
@Test func aBuildingButtonSetsPlacingAndASecondPressClearsIt() {
    let view = Samples.townsAgeOpening()
    let (session, recorder) = makeSession(view, select: [view.id(of: .unit(.worker))])
    let house = PanelModel(session: session).offer(forKey: "h")!
    house.perform(in: session)
    #expect(session.placing == .house)
    house.perform(in: session)
    #expect(session.placing == nil)
    #expect(recorder.orders.isEmpty)
}

// MARK: Shortcuts

@Test func keysAreUniqueWithinWhatOneSelectionOffers() {
    let selections: [(PlayerView, [UnitKind], [BuildingKind])] = [
        (Samples.townsAgeOpening(), [], [.townCentre]),
        (Samples.farmsAgeSkirmish(), [], [.barracks]),
        (Samples.farmsAgeSkirmish(), [], [.townCentre]),
        (Samples.farmsAgeSkirmish(), [.worker, .soldier1, .knight2], []),
        (Samples.townsAgeOpening(), [.worker], []),
        ({ var v = Samples.farmsAgeSkirmish(); v.age = .hospitals; return v }(), [.worker], []),
        ({ var v = Samples.farmsAgeSkirmish(); v.age = .hospitals; return v }(), [], [.townCentre]),
    ]
    for (view, units, buildings) in selections {
        let ids = view.ids(ofUnits: units) + buildings.map { view.id(of: .building($0)) }
        let keys = model(view, ids).actions.compactMap(\.shortcut) + [PanelModel.advanceKey, PanelModel.pauseKey]
        #expect(Set(keys).count == keys.count, "\(keys)")
    }
}

@Test func theKeyFindsItsOfferWhateverTheCase() {
    var view = Samples.townsAgeOpening()
    view.populationLimit = 10
    let m = model(view, [view.id(of: .building(.townCentre))])
    #expect(m.offer(forKey: "W")?.id == "train-worker")
    #expect(m.offer(forKey: "x")?.id == "demolish")
    #expect(m.offer(forKey: "z") == nil)
}

// MARK: Demolition

@Test func aSingleOwnBuildingOffersDemolitionByTheNearestWorkerWhereNoneIsIdle() {
    let view = Samples.townsAgeOpening()   // no worker is idle; the hunter is nearest
    let centre = view.id(of: .building(.townCentre))
    let m = model(view, [centre])
    let d = offer(m, "demolish")
    #expect(d.order == .demolish(workers: [EntityID(2)], building: centre))
    #expect(d.isAvailable && d.shortcut == "x")
    #expect(d.detail.contains(InterfaceText.cost(catalogue.stats(.townCentre).cost.share(0.5))))
}

@Test func idleWorkersDemolishTogetherAndWithoutOneDemolitionIsRefused() {
    var view = Samples.townsAgeOpening()
    let centre = view.id(of: .building(.townCentre))
    let idle = EntityID(6)
    let i = view.entities.firstIndex { $0.id == idle }!
    view.entities[i].activity = .idle
    #expect(offer(model(view, [centre]), "demolish").order == .demolish(workers: [idle], building: centre))
    view.entities.removeAll { $0.kind == .unit(.worker) }
    let why = offer(model(view, [centre]), "demolish").unavailable
    #expect(why?.explanation == "Needs a worker")
}

@Test func nothingOffersDemolitionOfAnotherPlayersBuildingOrOfSeveral() {
    let view = Samples.farmsAgeSkirmish()
    #expect(model(view, [view.id(of: .building(.townCentre), owner: PlayerID(1))]).demolish.isEmpty)
    #expect(model(view, view.ids(ofUnits: [.worker])).demolish.isEmpty)
}

// MARK: Dismissal

@Test func ownPeopleOfferDismissalOnTheDeleteKey() {
    let view = Samples.townsAgeOpening()
    let workers = view.ids(ofUnits: [.worker])
    let d = offer(model(view, workers), "dismiss")
    #expect(d.order == .dismiss(units: workers.sorted()))
    #expect(d.shortcut == PanelModel.deleteKey)
    #expect(d.costLine == "Frees \(workers.count) places")
    #expect(model(view, [view.id(of: .building(.townCentre))]).dismiss.isEmpty)
}

// MARK: Step 5: the navy ship, the founder and the workers' names

@Test func aNavyShipOffersTheTroopsItMakesAndShowsItsCargo() {
    var view = Samples.farmsAgeSkirmish()
    view.age = .hospitals
    var ship = view.entities.first { $0.owner == view.player && $0.kind == .unit(.worker) }!
    ship.id = EntityID(9_100)
    ship.kind = .unit(.navyShip)
    ship.passengers = 4
    view.entities.append(ship)
    let m = model(view, [ship.id])
    #expect(Set(m.train.map(\.id)) == Set(catalogue.made(by: .unit(.navyShip)).map { "train-\($0.unit)" }))
    #expect(offer(m, "train-knight3").order == .train(at: ship.id, unit: .knight3))
    guard case .single(let detail) = m.content else { Issue.record("not one"); return }
    #expect(detail.name == "Navy ship" && detail.activity.contains("4 of 20 troops aboard"))
}

@Test func aFounderOffersOneTownCentreFreeAndCannotBeDismissed() {
    var view = Samples.townsAgeOpening()
    view.entities.removeAll { $0.owner == view.player }
    view.entities.append(EntityView(id: EntityID(9_300), owner: view.player, kind: .unit(.founder),
                                    position: MapPosition(x: 20.5, y: 14.5), tile: GridPoint(20, 14), facing: .right,
                                    health: 1, maxHealth: 1, activity: .idle))
    let m = model(view, [EntityID(9_300)])
    #expect(m.build.map(\.id) == ["found"])
    #expect(offer(m, "found").cost.isZero && offer(m, "found").action == .place(.townCentre))
    #expect(m.dismiss.isEmpty)
}

@Test func aWorkersNameFollowsItsWork() {
    var view = Samples.townsAgeOpening()
    let worker = view.id(of: .unit(.worker))
    let i = view.entities.firstIndex { $0.id == worker }!
    for (job, name) in [(Job.gathering(.tree), "Lumberjack"), (.gathering(.prey), "Hunter"), (.gathering(.gold), "Miner"), (.gathering(.fruit), "Gatherer"),
                        (.working(.farm), "Farmer"), (.constructing, "Builder"), (.repairing, "Repairer"), (.idle, "Worker")] {
        view.entities[i].job = job
        guard case .single(let detail) = model(view, [worker]).content else { Issue.record("not one"); return }
        #expect(detail.name == name, "\(job)")
    }
}

@Test func noTrainingKeyIsF() {
    for unit in UnitKind.allCases { #expect(PanelModel.trainKey(unit) != "f", "\(unit)") }
}

// MARK: Step 6: boarding, landing and healing

/// The skirmish with a navy ship of the player's beside its first worker.
private func withShip(passengers: Int) -> (PlayerView, EntityView) {
    var view = Samples.farmsAgeSkirmish()
    view.age = .ships
    var ship = view.entities.first { $0.owner == view.player && $0.kind == .unit(.worker) }!
    ship.id = EntityID(9_100)
    ship.kind = .unit(.navyShip)
    ship.passengers = passengers
    ship.position = MapPosition(x: ship.position.x + 1, y: ship.position.y)
    view.entities.append(ship)
    view.entities.sort { $0.id < $1.id }
    return (view, ship)
}

@Test func selectedTroopsAndWorkersOfferToBoardTheNearestShipWithRoom() {
    let (view, ship) = withShip(passengers: 3)
    let troops = view.ids(ofUnits: [.worker, .soldier1])
    let board = offer(model(view, troops), "board")
    #expect(board.order == .board(units: troops, ship: ship.id) && board.isAvailable && board.shortcut == "v")
    #expect(!board.detail.isEmpty)
    // A full ship has no room.
    let (full, _) = withShip(passengers: catalogue.shipCargo)
    let refused = offer(model(full, full.ids(ofUnits: [.soldier1])), "board")
    #expect(refused.unavailable?.explanation == "No navy ship of yours with room")
}

@Test func aLoadedShipOffersToLandOnTheNearestOpenShore() {
    let (view, ship) = withShip(passengers: 5)
    let land = offer(model(view, [ship.id]), "land")
    guard case .land(let ships, let point) = land.action else { Issue.record("not a landing"); return }
    #expect(ships == [ship.id] && land.shortcut == "p" && land.isAvailable)
    #expect(view.terrain(at: point.tile).isPassable && point.distance(to: ship.position) <= 6)
    // An empty ship offers no landing.
    let (empty, bare) = withShip(passengers: 0)
    #expect(!model(empty, [bare.id]).actions.contains { $0.id == "land" })
}

@Test func doctorsOfferToHealTheNearestWoundedUnitWithinTheirRadius() {
    var view = Samples.farmsAgeSkirmish()
    var doctor = view.entities.first { $0.owner == view.player && $0.kind == .unit(.worker) }!
    doctor.id = EntityID(9_200)
    doctor.kind = .unit(.doctor)
    view.entities.append(doctor)
    let soldier = view.entities.firstIndex { $0.owner == view.player && $0.kind == .unit(.soldier1) }!
    view.entities[soldier].health = 1
    view.entities[soldier].position = MapPosition(x: doctor.position.x + 2, y: doctor.position.y)
    let heal = offer(model(view, [doctor.id]), "heal")
    #expect(heal.order == .heal(doctors: [doctor.id], target: view.entities[soldier].id))
    #expect(heal.shortcut == "e" && heal.isAvailable)
    // Out of the radius, or with nobody wounded, it is refused.
    view.entities[soldier].health = view.entities[soldier].maxHealth
    #expect(offer(model(view, [doctor.id]), "heal").unavailable?.explanation == "No wounded unit of yours near")
}

@Test func noBuildingKeyIsFAndTheFarmIsR() {
    for kind in BuildingKind.allCases { #expect(PanelModel.buildKey(kind) != "f", "\(kind)") }
    #expect(PanelModel.buildKey(.farm) == "r")
    for key in [PanelModel.boardKey, PanelModel.landKey, PanelModel.healKey, PanelModel.advanceKey] { #expect(key != "f") }
}

/// Every maker offers what it makes, each with its key and a description.
@Test func everyMakerOffersItsUnitsWithKeysAndDescriptions() {
    var view = Samples.farmsAgeSkirmish()
    view.age = .hospitals
    view.resources = ResourceAmounts([.food: 9_999, .wood: 9_999, .gold: 9_999])
    for kind in BuildingKind.allCases where !catalogue.made(by: .building(kind)).isEmpty {
        var maker = view.entities.first { $0.owner == view.player && $0.kind == .building(.house) }!
        maker.id = EntityID(9_400 + kind.rawValue)
        maker.kind = .building(kind)
        var v = view
        v.entities.append(maker)
        let m = model(v, [maker.id])
        #expect(m.train.count == catalogue.made(by: .building(kind)).count, "\(kind)")
        for o in m.train { #expect(o.shortcut != nil && o.shortcut != "f" && !o.detail.isEmpty, "\(kind) \(o.id)") }
        let keys = m.actions.compactMap(\.shortcut)
        #expect(Set(keys).count == keys.count, "\(kind): \(keys)")
    }
}

/// Keys do not collide within any selection the new offers appear in.
@Test func theNewOffersKeysDoNotCollide() {
    let (view, ship) = withShip(passengers: 4)
    var doctorView = view
    var doctor = view.entities.first { $0.owner == view.player && $0.kind == .unit(.worker) }!
    doctor.id = EntityID(9_201)
    doctor.kind = .unit(.doctor)
    doctorView.entities.append(doctor)
    let selections: [(PlayerView, [EntityID])] = [
        (view, view.ids(ofUnits: [.worker, .soldier1])),
        (view, [ship.id]),
        (view, [ship.id] + view.ids(ofUnits: [.worker])),
        (doctorView, [doctor.id] + view.ids(ofUnits: [.worker])),
    ]
    for (v, ids) in selections {
        let keys = model(v, ids).actions.compactMap(\.shortcut) + [PanelModel.advanceKey, PanelModel.pauseKey]
        #expect(Set(keys).count == keys.count, "\(keys)")
        #expect(!keys.contains("f"))
    }
}
