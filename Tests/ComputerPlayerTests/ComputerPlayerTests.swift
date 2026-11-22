// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import ComputerPlayer

// Every test asks for orders through `decide(_:_:)`, which checks each order
// the player emits against the rules in `OrderCheck`.

private func player(_ difficulty: Difficulty = .standard, seed: UInt64 = 1) -> ComputerPlayer {
    ComputerPlayer(player: TestViews.me, difficulty: difficulty, seed: seed)
}

private func attacks(_ orders: [Order]) -> [(units: [EntityID], target: EntityID)] {
    orders.compactMap { if case .attack(let units, let target) = $0 { return (units, target) } else { return nil } }
}

private func constructs(_ orders: [Order]) -> [(engineers: [EntityID], kind: BuildingKind, origin: GridPoint)] {
    orders.compactMap { if case .construct(let e, let k, let at) = $0 { return (e, k, at) } else { return nil } }
}

private func moves(_ orders: [Order]) -> [(units: [EntityID], to: MapPosition)] {
    orders.compactMap { if case .move(let units, let to) = $0 { return (units, to) } else { return nil } }
}

// MARK: The Stone age

@Test func trainsWorkersAndGathersFromTheOpening() {
    let view = TestViews.openingWithRoom()
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.train(at: EntityID(1), unit: .worker)))
    let gathered = orders.compactMap { order -> ResourceSite? in
        guard case .gather(let units, let site) = order, units.contains(EntityID(2)) else { return nil }
        return view.sites.first { $0.id == site }
    }
    #expect(gathered.count == 1)
    #expect(gathered.allSatisfy { [.food, .wood, .stone].contains($0.kind.yield) })
}

@Test func anOpponentsWorkerAmongTheBuildingsIsNoThreat() {
    // A scouting worker beside the town centre: training and gathering go on.
    var view = TestViews.openingWithRoom()
    view.add(.unit(.worker), owner: TestViews.enemy, at: 12.5, 11.5, .moving)
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.train(at: EntityID(1), unit: .worker)))
    #expect(orders.contains { if case .gather = $0 { return true } else { return false } })
}

@Test func buildsAHouseAtThePopulationLimit() {
    let view = Samples.stoneAgeOpening()
    #expect(view.population == view.populationLimit)
    var cp = player()
    let orders = decide(&cp, view)
    let houses = constructs(orders).filter { $0.kind == .house }
    #expect(houses.count == 1)
    #expect(houses.allSatisfy { $0.engineers == [EntityID(6)] && Placement.canPlace(.house, at: $0.origin, in: view) })
    // Training would be refused at the limit, so none is ordered.
    #expect(!orders.contains { if case .train = $0 { return true } else { return false } })
}

@Test func trainsAnEngineerFirstWhenItHasNone() {
    // The start a match gives: a town centre and three workers, five places.
    var view = Samples.stoneAgeOpening()
    view.remove([EntityID(5), EntityID(6)])
    for id in [2, 3, 4] { view.set(EntityID(id), .idle) }
    view.population = 3
    view.resources = Catalogue.standard.startingResources
    view.ageProgress = 0
    view.tick = 0
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.train(at: EntityID(1), unit: .engineer)))
    #expect(orders.filter { if case .gather = $0 { return true } else { return false } }.count >= 1)
}

@Test func keepsScholarsStudyingAtTheTownCentre() {
    var view = Samples.stoneAgeOpening()
    view.set(EntityID(5), .idle)
    var cp = player()
    #expect(decide(&cp, view).contains(.work(units: [EntityID(5)], at: EntityID(1))))
}

@Test func advancesWhenStudyIsCompleteAndTheCostCovered() {
    var cp = player()
    #expect(decide(&cp, TestViews.openingReadyToAdvance()).contains(.advanceAge))

    var short = TestViews.openingReadyToAdvance()
    short.resources = ResourceAmounts([.food: 200, .wood: 260, .stone: 50])
    var poor = player()
    #expect(!decide(&poor, short).contains(.advanceAge))

    var unfinished = TestViews.openingReadyToAdvance()
    unfinished.ageProgress = 0.9
    var early = player()
    #expect(!decide(&early, unfinished).contains(.advanceAge))
}

@Test func buildsAStoragePitNearDistantResources() {
    var view = Samples.stoneAgeOpening()
    // Two workers fell trees in the far corner of the forest, eleven tiles from the town centre.
    view.entities[2].position = MapPosition(x: 1.5, y: 2.5)
    view.entities[2].tile = GridPoint(1, 2)
    view.add(.unit(.worker), owner: TestViews.me, at: 2.5, 1.5, .gathering(.tree))
    view.add(.unit(.engineer), owner: TestViews.me, at: 8, 7)
    view.population = 7
    view.populationLimit = 20
    var cp = player()
    let pits = constructs(decide(&cp, view)).filter { $0.kind == .storagePit }
    #expect(pits.count == 1)
    for pit in pits {
        let centre = Placement.centre(.storagePit, origin: pit.origin)
        #expect(centre.distance(to: MapPosition(x: 2, y: 2)) <= 7)
    }
}

// MARK: Boats (ruled 2026-11-21)

/// The Stone age opening with a pond to the east of the town centre, a shoal of fish in it.
private func openingByAPond() -> PlayerView {
    var view = Samples.stoneAgeOpening()
    let pond = (4...8).flatMap { y in (15...19).map { GridPoint($0, y) } }
    view.sites.removeAll { pond.contains($0.tile) }
    for t in pond { view.terrain[t.y * view.mapWidth + t.x] = .deepWater }
    for (k, t) in [GridPoint(16, 5), GridPoint(17, 5), GridPoint(16, 6), GridPoint(17, 6)].enumerated() {
        view.sites.append(ResourceSite(id: SiteID(9_000 + k), kind: .fish, tile: t, remaining: 200))
    }
    view.sites.sort { $0.id < $1.id }
    view.populationLimit = 20
    view.resources = ResourceAmounts([.food: 400, .wood: 400, .stone: 50])
    return view
}

@Test func buildsABoatHouseOnTheShoreOfWaterWithFish() {
    var view = openingByAPond()
    view.add(.unit(.engineer), owner: TestViews.me, at: 13, 8)
    var cp = player()
    let houses = constructs(decide(&cp, view)).filter { $0.kind == .boatHouse }
    #expect(houses.count == 1)
    for house in houses {
        #expect(Placement.touchesWater(Placement.footprint(.boatHouse, at: house.origin), width: view.mapWidth,
                                       height: view.mapHeight, terrain: view.terrain))
    }
}

@Test func aBoatHouseTrainsBoatsAndAnIdleBoatFishes() {
    var view = openingByAPond()
    let house = view.add(.building(.boatHouse), owner: TestViews.me, at: 14, 6)
    let boat = view.add(.unit(.boat), owner: TestViews.me, at: 15.5, 7.5)
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.train(at: house, unit: .boat)))
    let fished = orders.compactMap { order -> SiteID? in
        guard case .gather(let units, let site) = order, units == [boat] else { return nil }
        return site
    }
    #expect(fished.count == 1)
    #expect(fished.allSatisfy { id in view.sites.first { $0.id == id }?.kind == .fish })
}

@Test func workersAreNeverSentToTheWater() {
    var view = openingByAPond()
    // Stone in the pond only: workers look for it on land, never there.
    view.sites.append(ResourceSite(id: SiteID(9_100), kind: .stone, tile: GridPoint(18, 7), remaining: 250))
    var cp = player()
    for order in decide(&cp, view) {
        guard case .gather(let units, let site) = order, let found = view.sites.first(where: { $0.id == site }) else { continue }
        let afloat = view.terrain[found.tile.y * view.mapWidth + found.tile.x].isWater
        #expect(!afloat || units.allSatisfy { view.entity($0)?.kind == .unit(.boat) })
    }
}

// MARK: The Bronze age

@Test func buildsTheBronzeAgeBuildings() {
    var view = TestViews.bronzeArmy(extra: 0, tick: Tick.seconds(600))
    view.remove([EntityID(10), EntityID(11), EntityID(12)])
    view.set(EntityID(6), .idle)
    view.set(EntityID(16), .idle)
    view.add(.unit(.engineer), owner: TestViews.me, at: 9, 13)
    view.population = 13
    view.populationLimit = 25
    var cp = player()
    let kinds = constructs(decide(&cp, view)).map(\.kind)
    #expect(kinds.contains(.barracks))
    #expect(kinds.contains(.stockPen))
}

@Test func defendsInTheBronzeSkirmish() {
    let view = Samples.bronzeAgeSkirmish()
    var cp = player()
    let orders = decide(&cp, view)
    let opponents = Set(view.owned(by: TestViews.enemy).filter { $0.kind != .building(.townCentre) }.map(\.id))
    let defence = attacks(orders).filter { opponents.contains($0.target) }
    #expect(!defence.isEmpty)
    // The chariot, the one warfighter not yet fighting, takes the archer it strikes twice as hard.
    #expect(defence.contains { $0.units == [EntityID(22)] && $0.target == EntityID(24) })
}

@Test func attacksTheNearestKnownBuildingWithALargeArmy() {
    let view = TestViews.bronzeArmy(extra: 10)
    var cp = player()
    let orders = decide(&cp, view)
    let centre = view.first(.building(.townCentre), of: TestViews.enemy)!.id
    let attack = attacks(orders).first { $0.target == centre }
    #expect(attack != nil)
    #expect((attack?.units.count ?? 0) >= 10)
}

@Test func marchesOnABuildingRememberedOutOfSight() {
    var cp = player()
    let small = TestViews.bronzeArmy(extra: 0)
    #expect(attacks(decide(&cp, small)).isEmpty)
    let centre = small.first(.building(.townCentre), of: TestViews.enemy)!
    var later = TestViews.bronzeArmy(extra: 10, tick: small.tick + Tick.seconds(2))
    later.remove([centre.id])
    later.setVisibility(.explored) { $0.x >= 19 }
    let marches = moves(decide(&cp, later)).filter { $0.to == centre.position }
    #expect(marches.count == 1)
    #expect((marches.first?.units.count ?? 0) >= 10)
}

@Test func joinsAnAlliedComputerPlayersAttackAndNeverAttacksAnAlly() {
    let (view, farHouse) = TestViews.alliedAttack(allyAttacking: true)
    var cp = player()
    let orders = decide(&cp, view)
    // Six warfighters are too few to attack alone, but enough to join the ally,
    // at its target rather than the nearer town centre.
    let joint = attacks(orders).filter { $0.target == farHouse }
    #expect(joint.count == 1)
    #expect(joint.allSatisfy { $0.units.count == 6 })
    #expect(attacks(orders).allSatisfy { view.entity($0.target)?.owner == TestViews.enemy })

    let (alone, _) = TestViews.alliedAttack(allyAttacking: false)
    var unjoined = player()
    #expect(attacks(decide(&unjoined, alone)).isEmpty)
}

@Test func upgradesStoneWarfighters() {
    var view = TestViews.bronzeArmy(extra: 0, tick: Tick.seconds(600))
    view.set(EntityID(18), .idle)
    view.set(EntityID(19), .idle)
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.upgrade(units: [EntityID(18)], to: .spearman, at: EntityID(10))))
    #expect(orders.contains(.upgrade(units: [EntityID(19)], to: .archer, at: EntityID(10))))
}

@Test func scoutsWhenNoOpponentIsKnown() {
    var view = Samples.bronzeAgeSkirmish()
    view.remove(view.owned(by: TestViews.enemy).map(\.id))
    view.events = []
    var cp = player()
    let scouting = moves(decide(&cp, view))
    #expect(scouting.count == 1)
    for move in scouting {
        #expect(move.units == [EntityID(22)])
        #expect(view.visibility(at: move.to.tile) == .unexplored)
    }
}

@Test func foundsATownCentreNearAnAlly() {
    let view = TestViews.founderBesideAlly()
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.count == 1)
    guard case .found(let founder, let at)? = orders.first else {
        Issue.record("expected a founding, got \(orders)")
        return
    }
    #expect(view.entity(founder)?.kind == .unit(.founder))
    let allied = view.first(.building(.townCentre), of: TestViews.ally)!
    #expect(Placement.centre(.townCentre, origin: at).distance(to: allied.position) <= 18)
}

@Test func choosesNothingOutOfTurnOrForAnotherPlayer() {
    var cp = player()
    var paused = Samples.stoneAgeOpening()
    paused.isPaused = true
    #expect(decide(&cp, paused).isEmpty)
    var over = Samples.stoneAgeOpening()
    over.outcome = .won(TeamID(1))
    #expect(decide(&cp, over).isEmpty)
    var other = ComputerPlayer(player: TestViews.enemy, difficulty: .standard, seed: 1)
    #expect(decide(&other, Samples.stoneAgeOpening()).isEmpty)
}

// MARK: Difficulty

@Test func easyActsMoreSlowly() {
    let first = TestViews.openingWithRoom()
    var second = TestViews.openingWithRoom()
    second.tick = first.tick + Tick.seconds(1)
    second.set(EntityID(3), .idle)
    var third = second
    third.tick = first.tick + Tick.seconds(3)

    var standard = player(.standard)
    _ = decide(&standard, first)
    #expect(!decide(&standard, second).isEmpty)

    var easy = player(.easy)
    _ = decide(&easy, first)
    #expect(decide(&easy, second).isEmpty)
    #expect(!decide(&easy, third).isEmpty)
}

@Test func easyAttacksLaterAndWithASmallerArmy() {
    // Twelve minutes in, with fifteen warfighters: standard attacks; easy waits.
    let early = TestViews.bronzeArmy(extra: 10, tick: Tick.seconds(12 * 60))
    var standard = player(.standard)
    var easy = player(.easy)
    #expect(!attacks(decide(&standard, early)).isEmpty)
    #expect(attacks(decide(&easy, early)).isEmpty)

    // Sixteen minutes in, with six: easy attacks; standard and hard wait for more.
    let late = TestViews.bronzeArmy(extra: 1, tick: Tick.seconds(16 * 60))
    for difficulty in Difficulty.allCases {
        var cp = player(difficulty)
        #expect(attacks(decide(&cp, late)).isEmpty == (difficulty != .easy), "\(difficulty)")
    }
}

@Test func hardLeansFurtherTowardCounters() {
    var seen = [Double](repeating: 0, count: UnitKind.allCases.count)
    seen[UnitKind.chariot.rawValue] = 6
    let kinds: [UnitKind] = [.spearman, .archer, .chariot]
    func spearmen(_ difficulty: Difficulty) -> Double {
        let weights = Turn.mix(kinds, seen: seen, counters: Tuning.of(difficulty).counters, catalogue: .standard)
        return weights[0] / weights.reduce(0, +)
    }
    #expect(spearmen(.easy) < spearmen(.standard))
    #expect(spearmen(.standard) < spearmen(.hard))

    // Seeing only chariots, the barracks trains the spearman that strikes them three times as hard.
    var view = TestViews.bronzeArmy(extra: 0, tick: Tick.seconds(600))
    view.set(EntityID(10), .idle)
    view.add(.unit(.chariot), owner: TestViews.enemy, at: 28, 3, .moving)
    view.add(.unit(.chariot), owner: TestViews.enemy, at: 29, 3, .moving)
    view.setVisibility(.visible) { $0.x >= 24 && $0.y < 6 }
    var hard = player(.hard)
    #expect(decide(&hard, view).contains(.train(at: EntityID(10), unit: .spearman)))
}

// MARK: Determinism, saving and speed

@Test func theSameSeedAndViewsGiveTheSameOrders() throws {
    func play(seed: UInt64) -> [Order] {
        var cp = player(seed: seed)
        return TestViews.sequence().flatMap { decide(&cp, $0) }
    }
    let orders = play(seed: 7)
    #expect(!orders.isEmpty)
    #expect(orders == play(seed: 7))
    // The scout's destination is drawn from the generator, so another seed differs.
    #expect(orders != play(seed: 8))
    // A stored value, which another process must reproduce.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var sum = StableChecksum()
    for order in orders { sum.add(bytes: try encoder.encode(order)) }
    #expect(sum.value == OrderFixture.expected,
            "update OrderFixture.expected only for a deliberate change: \(String(sum.value, radix: 16))")
}

enum OrderFixture { static let expected: UInt64 = 0xB1BD_1677_C669_4364 }

@Test func aSavedPlayerResumesWithTheSameDecisions() throws {
    let views = TestViews.sequence()
    var original = player(seed: 11)
    for view in views.prefix(3) { _ = decide(&original, view) }
    var resumed = try JSONDecoder().decode(ComputerPlayer.self, from: JSONEncoder().encode(original))
    for view in views.dropFirst(3) {
        #expect(decide(&original, view) == decide(&resumed, view))
    }
}

/// Two milliseconds in a release build, as the game runs; a debug build on a
/// shared CI runner is several times slower, and slower still when its other
/// test targets run beside it (12.8 ms seen on 2026-11-19), so it is allowed twenty-five.
#if DEBUG
private let decisionLimit = Duration.milliseconds(25)
#else
private let decisionLimit = Duration.milliseconds(2)
#endif

@Test func decidesInUnderTwoMillisecondsWithFourHundredEntities() {
    let view = TestViews.crowded()
    #expect(view.entities.count == 400)
    var checked = player(.hard)
    let orders = decide(&checked, view)
    #expect(constructs(orders).contains { $0.kind == .house })
    #expect(!attacks(orders).isEmpty)
    for difficulty in Difficulty.allCases {
        var times: [Duration] = []
        for run in 0..<15 {
            // A fresh player each time, so that every call acts rather than waits.
            var cp = player(difficulty, seed: UInt64(run))
            var orders: [Order] = []
            times.append(ContinuousClock().measure { orders = cp.decide(view: view, catalogue: .standard) })
            let problems = OrderCheck.problems(orders, in: view, catalogue: .standard)
            #expect(problems.isEmpty, "\(problems)")
        }
        let median = times.sorted()[times.count / 2]
        print("decide, \(difficulty), 400 entities: median \(median), longest \(times.max()!)")
        #expect(median < decisionLimit, "\(difficulty): \(median)")
    }
}
