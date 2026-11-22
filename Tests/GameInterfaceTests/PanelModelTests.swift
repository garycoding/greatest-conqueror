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

// MARK: The Stone opening

@Test func stoneTownCentreOffersItsPeopleAndResearch() {
    let view = Samples.stoneAgeOpening()
    let m = model(view, [view.id(of: .building(.townCentre))])
    #expect(m.train.map(\.id) == ["train-worker", "train-scholar", "train-engineer", "train-merchant", "train-clubman", "train-slinger"])
    #expect(m.research.map(\.id) == ["research-betterTools", "research-ironTools", "research-guilds", "research-banking", "research-machineTools"])
    #expect(m.build.isEmpty && m.upgrade.isEmpty)
    #expect(offer(m, "train-worker").title == "Hunter")
    #expect(offer(m, "train-engineer").title == "Builder")
    #expect(offer(m, "train-worker").cost == ResourceAmounts([.food: 50]))
}

@Test func stoneOpeningIsAtItsPopulationLimitSoTrainingIsRefusedForThatReason() {
    let view = Samples.stoneAgeOpening()   // 5 of 5
    let m = model(view, [view.id(of: .building(.townCentre))])
    for id in ["train-worker", "train-scholar", "train-engineer", "train-clubman", "train-slinger"] {
        let why = offer(m, id).unavailable
        #expect(why?.refusal == .populationLimit, "\(id)")
        #expect(why?.explanation == "Population full (5 of 5); build a house", "\(id)")
    }
    // The age comes first: a Bronze-age merchant is refused for its age, not the limit.
    #expect(offer(m, "train-merchant").unavailable?.refusal == .ageNotReached(.bronze))
    #expect(offer(m, "train-merchant").unavailable?.explanation == "Needs the Bronze age")
    // Research needs no place.
    #expect(offer(m, "research-betterTools").isAvailable)
}

@Test func stoneTrainingIsAvailableWithRoomAndResources() {
    var view = Samples.stoneAgeOpening()
    view.populationLimit = 10
    let tc = view.id(of: .building(.townCentre))
    let m = model(view, [tc])
    #expect(offer(m, "train-worker").isAvailable)
    #expect(offer(m, "train-worker").order == .train(at: tc, unit: .worker))
    #expect(offer(m, "train-engineer").isAvailable)
    #expect(offer(m, "train-slinger").isAvailable)
    #expect(!offer(m, "train-merchant").isAvailable)
}

@Test func lackingResourcesNamesTheShortfall() {
    var view = Samples.stoneAgeOpening()
    view.populationLimit = 10
    view.resources = ResourceAmounts([.food: 40, .wood: 5])
    let m = model(view, [view.id(of: .building(.townCentre))])
    let worker = offer(m, "train-worker").unavailable
    #expect(worker?.refusal == .notEnough(ResourceAmounts([.food: 10])))
    #expect(worker?.explanation == "Short of 10 Food")
    // An engineer costs 50 food and 10 wood: short of both.
    let engineer = offer(m, "train-engineer").unavailable
    #expect(engineer?.refusal == .notEnough(ResourceAmounts([.food: 10, .wood: 5])))
    #expect(engineer?.explanation == "Short of 10 Food, 5 Wood")
    #expect(offer(m, "research-betterTools").unavailable?.explanation == "Short of 40 Food, 55 Wood")
}

@Test func engineersOfferTheBuildingsOfTheAgesReached() {
    let view = Samples.stoneAgeOpening()
    let m = model(view, [view.id(of: .unit(.engineer))])
    #expect(m.build.map(\.id) == ["build-townCentre", "build-house", "build-storagePit", "build-bridge", "build-boatHouse"])
    #expect(m.train.isEmpty && m.research.isEmpty)
    // 140 wood and 50 stone are held: a town centre wants 200 and 100.
    let centre = offer(m, "build-townCentre").unavailable
    #expect(centre?.refusal == .notEnough(ResourceAmounts([.wood: 60, .stone: 50])))
    #expect(offer(m, "build-house").isAvailable)
    #expect(offer(m, "build-storagePit").isAvailable)
    #expect(offer(m, "build-house").action == .place(.house))
    #expect(offer(m, "build-house").order == nil)
}

@Test func nonEngineersOfferNoBuildings() {
    let view = Samples.stoneAgeOpening()
    let m = model(view, view.ids(ofUnits: [.worker, .scholar]))
    #expect(m.build.isEmpty)
    #expect(m.actions.map(\.id) == ["dismiss"])
}

@Test func theAgeIsCheckedBeforeResourcesAndTheLimit() {
    var view = Samples.stoneAgeOpening()
    view.resources = ResourceAmounts()
    let m = model(view, [view.id(of: .building(.townCentre))])
    #expect(offer(m, "train-merchant").unavailable?.refusal == .ageNotReached(.bronze))
    #expect(offer(m, "train-worker").unavailable?.refusal == .notEnough(ResourceAmounts([.food: 50])))
}

// MARK: The Bronze skirmish

@Test func bronzeBarracksAtThePopulationLimit() {
    let view = Samples.bronzeAgeSkirmish()   // 15 of 15
    let barracks = view.id(of: .building(.barracks))
    let m = model(view, [barracks])
    #expect(m.train.map(\.id) == ["train-clubman", "train-slinger", "train-spearman", "train-archer", "train-chariot", "train-swordsman", "train-musketeer", "train-rifleman"])
    for o in m.train where !["train-swordsman", "train-musketeer", "train-rifleman"].contains(o.id) {
        #expect(o.unavailable?.refusal == .populationLimit, "\(o.id)")
        #expect(o.unavailable?.explanation == "Population full (15 of 15); build a house")
    }
    // Resources are not the cause: 420 food, 310 wood, 85 bronze, 60 gold.
    #expect(view.resources.covers(catalogue.stats(.chariot).cost))
    // Research does not need a place.
    #expect(m.research.map(\.id) == ["research-bronzeWeapons", "research-shields", "research-ironWeapons", "research-mail"])
    #expect(m.research.prefix(2).allSatisfy { $0.isAvailable })
    #expect(m.research.suffix(2).allSatisfy { !$0.isAvailable })   // the Iron age is not reached
    #expect(offer(m, "train-spearman").title == "Spearman")
}

@Test func theLimitAtItsMaximumSaysTheHousesCannotHelp() {
    var view = Samples.bronzeAgeSkirmish()
    view.population = 200; view.populationLimit = 200
    let m = model(view, [view.id(of: .building(.barracks))])
    #expect(offer(m, "train-spearman").unavailable?.explanation == "Population full (200 of 200)")
}

@Test func aChariotTakesTwoPlaces() {
    var view = Samples.bronzeAgeSkirmish()
    view.population = 14
    let m = model(view, [view.id(of: .building(.barracks))])
    #expect(offer(m, "train-spearman").isAvailable)
    #expect(offer(m, "train-chariot").unavailable?.refusal == .populationLimit)
}

@Test func bronzeTownCentreResearchOmitsWhatIsKnown() {
    let view = Samples.bronzeAgeSkirmish()   // better tools is known
    let m = model(view, [view.id(of: .building(.townCentre))])
    #expect(m.research.map(\.id) == ["research-ironTools", "research-guilds", "research-banking", "research-machineTools"])   // later ages', not yet reached
    #expect(offer(m, "train-merchant").unavailable?.refusal == .populationLimit)   // the age is reached
}

@Test func researchUnderWayBlocksOthersAtThatBuilding() {
    var view = Samples.bronzeAgeSkirmish()
    let barracks = view.id(of: .building(.barracks))
    let i = view.entities.firstIndex { $0.id == barracks }!
    view.entities[i].activity = .researching(.shields, 0.3)
    let m = model(view, [barracks])
    #expect(offer(m, "research-bronzeWeapons").unavailable?.explanation == "Research is already under way here")
}

@Test func aBuildingUnderConstructionOffersOnlyDemolition() {
    let view = Samples.bronzeAgeSkirmish()
    let tower = view.id(of: .building(.watchTower))
    let m = model(view, [tower])
    #expect(m.actions.map(\.id) == ["demolish"])
    guard case .single(let detail) = m.content else { Issue.record("expected a single entity"); return }
    #expect(detail.name == "Watch tower")
    #expect(detail.progress == 0.6)
    #expect(detail.activity == "Under construction")
}

@Test func warfightersOfferUpgradesWhereTheCatalogueHasOne() {
    let view = Samples.bronzeAgeSkirmish()
    let army = view.ids(ofUnits: [.clubman, .slinger, .spearman, .archer, .chariot])
    let m = model(view, army)
    #expect(m.upgrade.map(\.id) == ["upgrade-clubman", "upgrade-slinger", "upgrade-spearman", "upgrade-chariot"])
    let barracks = view.id(of: .building(.barracks))
    #expect(m.upgrade[0].action == .upgrade(units: [view.id(of: .unit(.clubman))], to: .spearman, at: barracks))
    #expect(m.upgrade[0].isAvailable)
    #expect(m.upgrade[0].cost == ResourceAmounts([.food: 20, .bronze: 15]))
    #expect(m.upgrade[0].title == "Clubman to Spearman")
    #expect(m.upgrade[0].shortcut == "u" && m.upgrade[1].shortcut == nil)
    #expect(m.build.isEmpty)
}

@Test func anUpgradeCostsPerWarfighterAndSaysWhatIsMissing() {
    var view = Samples.bronzeAgeSkirmish()
    // Two clubmen: 40 food, 30 bronze; hold 25 bronze.
    let extra = EntityView(id: EntityID(900), owner: view.player, kind: .unit(.clubman), position: MapPosition(x: 16, y: 11),
                           tile: GridPoint(16, 11), facing: .right, health: 40, maxHealth: 40, activity: .idle)
    view.entities.append(extra)
    view.resources[.bronze] = 25
    let clubmen = view.ids(ofUnits: [.clubman])
    #expect(clubmen.count == 2)
    let m = model(view, clubmen)
    #expect(m.upgrade.count == 1)
    #expect(m.upgrade[0].cost == ResourceAmounts([.food: 40, .bronze: 30]))
    #expect(m.upgrade[0].unavailable?.explanation == "Short of 5 Bronze")
}

@Test func anUpgradeNeedsABuildingThatTrainsTheNewKind() {
    var view = Samples.bronzeAgeSkirmish()
    let barracks = view.id(of: .building(.barracks))
    view.entities.removeAll { $0.id == barracks }
    let m = model(view, [view.id(of: .unit(.clubman))])
    #expect(m.upgrade[0].unavailable?.refusal == .invalidTarget)
    #expect(m.upgrade[0].unavailable?.explanation == "Needs a barracks to train the Spearman")
    #expect(m.upgrade[0].order == nil)
}

@Test func anUpgradeAwaitsItsAge() {
    // A clubman in the Stone age: the spearman is a Bronze kind.
    var view = Samples.stoneAgeOpening()
    view.entities.append(EntityView(id: EntityID(900), owner: view.player, kind: .unit(.clubman), position: MapPosition(x: 10, y: 12),
                                    tile: GridPoint(10, 12), facing: .right, health: 40, maxHealth: 40, activity: .idle))
    let m = model(view, [EntityID(900)])
    #expect(m.upgrade[0].unavailable?.refusal == .ageNotReached(.bronze))
}

@Test func engineersAndWarfightersTogetherOfferBothSets() {
    let view = Samples.bronzeAgeSkirmish()
    let m = model(view, view.ids(ofUnits: [.engineer, .clubman, .slinger]))
    #expect(m.build.count == 9)
    #expect(m.upgrade.count == 2)
    #expect(offer(m, "build-barracks").isAvailable)           // 100 wood of 310
    #expect(offer(m, "build-watchTower").isAvailable)         // 80 stone of 120
    guard case .several(let total, let counts) = m.content else { Issue.record("expected several"); return }
    #expect(total == 4)   // the sample holds two engineers
    #expect(counts.map(\.count) == [2, 1, 1])
    #expect(counts.map(\.name) == ["Mason", "Clubman", "Slinger"])
}

// MARK: Contents

@Test func severalWorkersAreCountedByKindAtTheOwnersStage() {
    let view = Samples.stoneAgeOpening()
    let m = model(view, view.ids(ofUnits: [.worker, .scholar]))
    guard case .several(let total, let counts) = m.content else { Issue.record("expected several"); return }
    #expect(total == 4)
    #expect(counts.map(\.name) == ["Hunter", "Elder"])
    #expect(counts.map(\.count) == [3, 1])
    let bronze = Samples.bronzeAgeSkirmish()
    let b = model(bronze, bronze.ids(ofUnits: [.worker]))
    guard case .several(_, let bc) = b.content else { Issue.record("expected several"); return }
    #expect(bc.map(\.name) == ["Herder"])
}

@Test func aSinglePersonIsShownWithHealthAndActivity() {
    let view = Samples.bronzeAgeSkirmish()
    let spearman = view.entities.first { $0.owner == view.player && $0.kind == .unit(.spearman) }!
    guard case .single(let d) = model(view, [spearman.id]).content else { Issue.record("expected single"); return }
    #expect(d.name == "Spearman")
    #expect(d.health == 43 && d.maxHealth == 55)
    #expect(abs(d.healthFraction - 43.0 / 55.0) < 1e-9)
    #expect(d.activity == "Fighting")
    #expect(d.ownerLine == "Sumer, yours")
}

@Test func aWorkerCarryingAndAHunterGathering() {
    let view = Samples.stoneAgeOpening()
    let carrier = view.entities.first { $0.activity == .carrying(.food, 6) }!
    guard case .single(let d) = model(view, [carrier.id]).content else { Issue.record("expected single"); return }
    #expect(d.name == "Hunter")
    #expect(d.activity == "Carrying 6 Food")
    let hunter = view.entities.first { $0.activity == .gathering(.prey) }!
    guard case .single(let h) = model(view, [hunter.id]).content else { Issue.record("expected single"); return }
    #expect(h.activity == "Hunting")
}

@Test func trainingShowsItsQueueAndProgress() {
    let view = Samples.bronzeAgeSkirmish()
    guard case .single(let d) = model(view, [view.id(of: .building(.barracks))]).content else { Issue.record("expected single"); return }
    #expect(d.activity == "Training Spearman, 2 queued")
    #expect(d.progress == 0.4)
}

@Test func anOpponentsBuildingOffersNothingAndIsLabelled() {
    let view = Samples.bronzeAgeSkirmish()
    let theirs = view.id(of: .building(.townCentre), owner: PlayerID(1))
    let m = model(view, [theirs])
    #expect(m.actions.isEmpty)
    guard case .single(let d) = m.content else { Issue.record("expected single"); return }
    #expect(d.ownerLine == "Egypt, opponent")
}

@Test func nothingSelectedOffersNothing() {
    let m = model(Samples.stoneAgeOpening(), [])
    #expect(m.content == .nothing && m.actions.isEmpty)
}

@Test func aPausedOrFinishedMatchRefusesEverythingButNotAsAShortage() {
    var view = Samples.stoneAgeOpening()
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
    var view = Samples.stoneAgeOpening()
    view.populationLimit = 10
    let tc = view.id(of: .building(.townCentre))
    let (session, recorder) = makeSession(view, select: [tc])
    PanelModel(session: session).offer(forKey: "w")!.perform(in: session)
    #expect(recorder.orders == [.train(at: tc, unit: .worker)])
    #expect(session.lastRefusal == nil)
}

@MainActor
@Test func anUnavailableButtonStaysLiveShowsItsRefusalAndIssuesNothing() {
    let view = Samples.stoneAgeOpening()   // at its limit
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
    let view = Samples.stoneAgeOpening()
    let (session, recorder) = makeSession(view, select: [view.id(of: .unit(.engineer))])
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
        (Samples.stoneAgeOpening(), [], [.townCentre]),
        (Samples.bronzeAgeSkirmish(), [], [.barracks]),
        (Samples.bronzeAgeSkirmish(), [], [.townCentre]),
        (Samples.bronzeAgeSkirmish(), [.engineer, .clubman, .slinger, .spearman, .archer], []),
        (Samples.stoneAgeOpening(), [.engineer], []),
        ({ var v = Samples.bronzeAgeSkirmish(); v.age = .industrial; return v }(), [.engineer], []),
        ({ var v = Samples.bronzeAgeSkirmish(); v.age = .industrial; return v }(), [], [.townCentre]),
    ]
    for (view, units, buildings) in selections {
        let ids = view.ids(ofUnits: units) + buildings.map { view.id(of: .building($0)) }
        let keys = model(view, ids).actions.compactMap(\.shortcut) + [PanelModel.advanceKey, PanelModel.pauseKey]
        #expect(Set(keys).count == keys.count, "\(keys)")
    }
}

@Test func theKeyFindsItsOfferWhateverTheCase() {
    var view = Samples.stoneAgeOpening()
    view.populationLimit = 10
    let m = model(view, [view.id(of: .building(.townCentre))])
    #expect(m.offer(forKey: "W")?.id == "train-worker")
    #expect(m.offer(forKey: "t")?.id == "research-betterTools")
    #expect(m.offer(forKey: "z") == nil)
}

// MARK: Demolition

@Test func aSingleOwnBuildingOffersDemolitionByTheNearestEngineerWhereNoneIsIdle() {
    let view = Samples.stoneAgeOpening()   // its one engineer is moving
    let centre = view.id(of: .building(.townCentre))
    let m = model(view, [centre])
    let d = offer(m, "demolish")
    #expect(d.order == .demolish(engineers: [view.id(of: .unit(.engineer))], building: centre))
    #expect(d.isAvailable && d.shortcut == "x")
    #expect(d.detail.contains(InterfaceText.cost(catalogue.stats(.townCentre).cost.halved)))
}

@Test func idleEngineersDemolishTogetherAndWithoutOneDemolitionIsRefused() {
    var view = Samples.stoneAgeOpening()
    let centre = view.id(of: .building(.townCentre))
    let engineer = view.id(of: .unit(.engineer))
    let i = view.entities.firstIndex { $0.id == engineer }!
    view.entities[i].activity = .idle
    #expect(offer(model(view, [centre]), "demolish").order == .demolish(engineers: [engineer], building: centre))
    view.entities.remove(at: i)
    let why = offer(model(view, [centre]), "demolish").unavailable
    #expect(why?.explanation == "Needs an engineer")
}

@Test func nothingOffersDemolitionOfAnotherPlayersBuildingOrOfSeveral() {
    let view = Samples.stoneAgeOpening()
    let theirs = view.entities.first(where: { e in
        if case .building = e.kind { return e.owner != view.player } else { return false }
    })
    if let theirs { #expect(model(view, [theirs.id]).demolish.isEmpty) }
    #expect(model(view, view.ids(ofUnits: [.worker])).demolish.isEmpty)
}

// MARK: Dismissal

@Test func ownPeopleOfferDismissalOnTheDeleteKey() {
    let view = Samples.stoneAgeOpening()
    let workers = view.ids(ofUnits: [.worker])
    let d = offer(model(view, workers), "dismiss")
    #expect(d.order == .dismiss(units: workers.sorted()))
    #expect(d.shortcut == PanelModel.deleteKey)
    #expect(d.costLine == "Frees \(workers.count) places")
    #expect(model(view, [view.id(of: .building(.townCentre))]).dismiss.isEmpty)
}

@Test func aFounderIsOfferedOneFreeTownCentre() {
    var view = Samples.bronzeAgeSkirmish()
    let founder = EntityID(9100)
    view.entities.append(EntityView(id: founder, owner: view.player, kind: .unit(.founder), position: MapPosition(x: 5.5, y: 5.5),
                                    tile: GridPoint(5, 5), facing: .right, health: 100, maxHealth: 100, activity: .idle))
    let m = model(view, [founder])
    #expect(m.build.map(\.id) == ["build-townCentre"])
    #expect(m.build[0].cost == ResourceAmounts() && m.build[0].isAvailable)
    #expect(m.build[0].action == .place(.townCentre))
}
