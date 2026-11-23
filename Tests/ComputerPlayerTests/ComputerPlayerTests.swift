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

private func constructs(_ orders: [Order]) -> [(builders: [EntityID], kind: BuildingKind, origin: GridPoint)] {
    orders.compactMap { if case .construct(let e, let k, let at) = $0 { return (e, k, at) } else { return nil } }
}

private func moves(_ orders: [Order]) -> [(units: [EntityID], to: MapPosition)] {
    orders.compactMap { if case .move(let units, let to) = $0 { return (units, to) } else { return nil } }
}

// MARK: The age of towns

@Test func trainsWorkersAndGathersFromTheOpening() {
    let view = TestViews.openingWithRoom()
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.train(at: EntityID(1), unit: .worker)))
    let gathered = orders.compactMap { order -> ResourceSite? in
        guard case .gather(let units, let site) = order, units.contains(EntityID(3)) else { return nil }
        return view.sites.first { $0.id == site }
    }
    #expect(gathered.count == 1)
    #expect(gathered.allSatisfy { [.food, .wood, .gold].contains($0.kind.yield) })
}

/// Early on, fruit bushes near the base feed the player as deer do (ruled 2026-11-22).
@Test func gathersFruitForFoodEarlyAsItHunts() {
    var view = Samples.townsAgeOpening()
    view.remove([EntityID(5), EntityID(6)])
    for id in [2, 3, 4] { view.set(EntityID(id), .idle) }
    view.population = 3
    view.resources = Catalogue.standard.startingResources
    view.ageProgress = 0
    view.tick = 0
    for i in view.sites.indices where view.sites[i].kind == .prey { view.sites[i].kind = .fruit }
    var cp = player()
    let orders = decide(&cp, view)
    let gathered = orders.compactMap { order -> ResourceSite? in
        guard case .gather(_, let site) = order else { return nil }
        return view.sites.first { $0.id == site }
    }
    #expect(gathered.contains { $0.kind == .fruit })
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
    let view = Samples.townsAgeOpening()
    #expect(view.population == view.populationLimit)
    var cp = player()
    let orders = decide(&cp, view)
    let houses = constructs(orders).filter { $0.kind == .house }
    #expect(houses.count == 1)
    // The oldest worker builds.
    #expect(houses.allSatisfy { $0.builders == [EntityID(2)] && Placement.canPlace(.house, at: $0.origin, in: view) })
    // Training would be refused at the limit, so none is ordered.
    #expect(!orders.contains { if case .train = $0 { return true } else { return false } })
}

@Test func trainsWorkersFromTheStart() {
    // The start a match gives: a town centre and three workers, five places.
    var view = Samples.townsAgeOpening()
    view.remove([EntityID(5), EntityID(6)])
    for id in [2, 3, 4] { view.set(EntityID(id), .idle) }
    view.population = 3
    view.resources = Catalogue.standard.startingResources
    view.ageProgress = 0
    view.tick = 0
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.train(at: EntityID(1), unit: .worker)))
    #expect(orders.filter { if case .gather = $0 { return true } else { return false } }.count >= 1)
}

@Test func advancesAtTheTownCentreOnceTheCostIsCovered() {
    var cp = player()
    #expect(decide(&cp, TestViews.openingReadyToAdvance()).contains(.advanceAge(at: EntityID(1))))

    var short = TestViews.openingReadyToAdvance()
    short.resources = ResourceAmounts([.food: 200, .wood: 260, .gold: 50])
    var poor = player()
    #expect(!decide(&poor, short).contains { if case .advanceAge = $0 { return true } else { return false } })

    var underWay = TestViews.openingReadyToAdvance()
    underWay.ageProgress = 0.4
    var waiting = player()
    #expect(!decide(&waiting, underWay).contains { if case .advanceAge = $0 { return true } else { return false } })

    var few = Samples.townsAgeOpening()
    few.resources = ResourceAmounts([.food: 420, .wood: 260, .gold: 50])
    var early = player()
    #expect(!decide(&early, few).contains { if case .advanceAge = $0 { return true } else { return false } })
}

/// Each difficulty advances at its own pace (`Tuning.advanceAt`): `hard` from
/// three minutes, `standard` from four, `easy` from six.
@Test func advancesOnlyOnceTheDifficultysTimeHasCome() {
    func advances(_ difficulty: Difficulty, at minutes: Double) -> Bool {
        var view = TestViews.openingReadyToAdvance()
        view.tick = Tick.seconds(minutes * 60)
        var cp = player(difficulty)
        return decide(&cp, view).contains(.advanceAge(at: EntityID(1)))
    }
    #expect(advances(.hard, at: 3.5))
    #expect(!advances(.standard, at: 3.5))
    #expect(advances(.standard, at: 4.5))
    #expect(!advances(.easy, at: 4.5))
    #expect(advances(.easy, at: 6.5))
}

// MARK: The later ages

/// The best tier of each line, soldiers, knights and cannons, that a maker
/// makes in an age, read from `production.csv`.
@Test func theBestTiersAreReadFromTheTables() {
    let turn = Turn(view: Samples.farmsAgeSkirmish(), catalogue: .standard, tuning: Tuning.of(.hard),
                    me: Samples.farmsAgeSkirmish().me!, memory: Memory(), generator: SeededGenerator(seed: 1),
                    regions: Regions(terrain: Samples.farmsAgeSkirmish().terrain, width: 32, height: 32))
    #expect(turn.bestTiers(madeBy: .building(.barracks), at: .farms) == [.soldier1])
    #expect(turn.bestTiers(madeBy: .building(.barracks), at: .ships) == [.soldier2])
    #expect(turn.bestTiers(madeBy: .building(.castle), at: .cannons) == [.soldier3, .knight2, .cannon1])
    #expect(turn.bestTiers(madeBy: .building(.castle), at: .hospitals) == [.soldier4, .knight3, .cannon2])
    #expect(turn.bestTiers(madeBy: .unit(.navyShip), at: .cannons).isEmpty)
    #expect(turn.bestTiers(madeBy: .unit(.navyShip), at: .hospitals) == [.soldier4, .knight3, .cannon2])
    #expect(turn.bestTiers(at: .ships) == [.soldier2, .knight1])
}

/// The skirmish moved on to the age of hospitals, the fight over, with room
/// and stock to spare, a castle and a hospital standing beside the barracks.
private func hospitalsAge() -> (view: PlayerView, castle: EntityID, hospital: EntityID) {
    var view = TestViews.farmsArmy(extra: 0)
    view.age = .hospitals
    view.players[0].age = .hospitals
    view.set(EntityID(10), .idle)
    let castle = view.add(.building(.castle), owner: TestViews.me, at: 3, 15)
    let hospital = view.add(.building(.hospital), owner: TestViews.me, at: 9.5, 16.5)
    view.resources = ResourceAmounts([.food: 3000, .wood: 3000, .gold: 3000])
    view.populationLimit = 60
    return (view, castle, hospital)
}

@Test func everyMakerMakesTheBestTierItsAgeAllows() {
    let (view, castle, _) = hospitalsAge()
    var cp = player(.hard)
    let trained = decide(&cp, view).compactMap { order -> (EntityID, UnitKind)? in
        if case .train(let at, let unit) = order { return (at, unit) } else { return nil }
    }
    #expect(trained.contains { $0.0 == EntityID(10) && $0.1 == .soldier4 })
    #expect(trained.contains { $0.0 == castle && [.soldier4, .knight3, .cannon2].contains($0.1) })
    #expect(trained.allSatisfy { !$0.1.isWarfighter || [.soldier4, .knight3, .cannon2].contains($0.1) })
}

@Test func aHospitalMakesDoctorsAndTheyKeepWithTheArmy() {
    let (view, _, hospital) = hospitalsAge()
    var cp = player(.hard)
    #expect(decide(&cp, view).contains(.train(at: hospital, unit: .doctor)))

    // An idle doctor far from the army goes to it; one healing is left alone.
    var later = view
    later.tick += Tick.seconds(2)
    let idle = later.add(.unit(.doctor), owner: TestViews.me, at: 2, 2)
    let healing = later.add(.unit(.doctor), owner: TestViews.me, at: 3, 2)
    for i in later.entities.indices where later.entities[i].id == idle { later.entities[i].job = .idle }
    for i in later.entities.indices where later.entities[i].id == healing { later.entities[i].job = .healing }
    var second = player(.hard)
    let orders = decide(&second, later)
    #expect(moves(orders).contains { $0.units == [idle] })
    #expect(!orders.contains { order in
        if case .move(let units, _) = order { return units.contains(healing) }
        return false
    })
}

/// What the plan for the coming age lacks draws the workers: with no gold in
/// hand, gold has a larger share than with a stock of it.
@Test func theWorkersFollowWhatThePlanLacks() {
    func goldShare(holding gold: Int) -> Double {
        var view = TestViews.farmsArmy(extra: 0)
        view.resources = ResourceAmounts([.food: 400, .wood: 400, .gold: gold])
        let turn = Turn(view: view, catalogue: .standard, tuning: Tuning.of(.standard), me: view.me!, memory: Memory(),
                        generator: SeededGenerator(seed: 1),
                        regions: Regions(terrain: view.terrain, width: view.mapWidth, height: view.mapHeight))
        return turn.workShares(OpenSites(view: view, memory: Memory()))[Resource.gold.rawValue]
    }
    #expect(goldShare(holding: 0) > goldShare(holding: 3000))
}

// MARK: Boats (ruled 2026-11-21)

/// The opening, moved on to the age of farms (in which the boathouse is first
/// built), with a pond to the east of the town centre, a shoal of fish in it.
private func openingByAPond() -> PlayerView {
    var view = Samples.townsAgeOpening()
    view.age = .farms
    let pond = (4...8).flatMap { y in (15...19).map { GridPoint($0, y) } }
    view.sites.removeAll { pond.contains($0.tile) }
    for t in pond { view.terrain[t.y * view.mapWidth + t.x] = .deepWater }
    for (k, t) in [GridPoint(16, 5), GridPoint(17, 5), GridPoint(16, 6), GridPoint(17, 6)].enumerated() {
        view.sites.append(ResourceSite(id: SiteID(9_000 + k), kind: .fish, tile: t, remaining: 200))
    }
    view.sites.sort { $0.id < $1.id }
    view.populationLimit = 20
    view.resources = ResourceAmounts([.food: 400, .wood: 400, .gold: 50])
    return view
}

@Test func buildsABoatHouseOnTheShoreOfWaterWithFish() {
    var view = openingByAPond()
    view.add(.unit(.worker), owner: TestViews.me, at: 13, 8)
    // The age's barracks and tower stand already, so that the boathouse is the building wanted.
    _ = view.add(.building(.barracks), owner: TestViews.me, at: 2, 14)
    _ = view.add(.building(.tower), owner: TestViews.me, at: 7, 1)
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
    let boat = view.add(.unit(.fishingBoat), owner: TestViews.me, at: 15.5, 7.5)
    var cp = player()
    let orders = decide(&cp, view)
    #expect(orders.contains(.train(at: house, unit: .fishingBoat)))
    let fished = orders.compactMap { order -> SiteID? in
        guard case .gather(let units, let site) = order, units == [boat] else { return nil }
        return site
    }
    #expect(fished.count == 1)
    #expect(fished.allSatisfy { id in view.sites.first { $0.id == id }?.kind == .fish })
}

/// From the age of hospitals a navy ship at the shore makes warfighters, of
/// the best tiers (requirements 17 and 18).
@Test func aNavyShipAtTheShoreMakesWarfightersInTheAgeOfHospitals() {
    var view = openingByAPond()
    view.age = .hospitals
    view.players[0].age = .hospitals
    view.resources = ResourceAmounts([.food: 3000, .wood: 3000, .gold: 3000])
    view.populationLimit = 40
    let ship = view.add(.unit(.navyShip), owner: TestViews.me, at: 15.5, 6.5)
    var cp = player(.hard)
    let made = decide(&cp, view).compactMap { order -> UnitKind? in
        if case .train(let at, let unit) = order, at == ship { return unit } else { return nil }
    }
    #expect(made.count == 1)
    #expect(made.allSatisfy { [.soldier4, .knight3, .cannon2].contains($0) })
}

/// A boathouse for navy ships goes on the shore of open water even where the
/// water holds no fish or gold.
@Test func buildsABoatHouseByOpenWaterForTheNavy() {
    var view = openingByAPond()
    view.age = .ships
    view.players[0].age = .ships
    view.sites.removeAll { view.terrain[$0.tile.y * view.mapWidth + $0.tile.x].isWater }
    view.add(.unit(.worker), owner: TestViews.me, at: 13, 8)
    _ = view.add(.building(.barracks), owner: TestViews.me, at: 2, 14)
    _ = view.add(.building(.tower), owner: TestViews.me, at: 7, 1)
    _ = view.add(.building(.stable), owner: TestViews.me, at: 2, 18)
    _ = view.add(.building(.castle), owner: TestViews.me, at: 8, 18)
    view.resources = ResourceAmounts([.food: 2000, .wood: 2000, .gold: 2000])
    var cp = player(.hard)
    let houses = constructs(decide(&cp, view)).filter { $0.kind == .boatHouse }
    #expect(houses.count == 1)
}

@Test func workersAreNeverSentToTheWater() {
    var view = openingByAPond()
    // Gold in the pond: workers look for it on land, never there.
    view.sites.append(ResourceSite(id: SiteID(9_100), kind: .gold, tile: GridPoint(18, 7), remaining: 250))
    var cp = player()
    for order in decide(&cp, view) {
        guard case .gather(let units, let site) = order, let found = view.sites.first(where: { $0.id == site }) else { continue }
        let afloat = view.terrain[found.tile.y * view.mapWidth + found.tile.x].isWater
        #expect(!afloat || units.allSatisfy { view.entity($0)?.kind == .unit(.fishingBoat) })
    }
}

// MARK: The age of farms

@Test func buildsTheBuildingsOfTheAgeOfFarms() {
    var view = TestViews.farmsArmy(extra: 0, tick: Tick.seconds(600))
    view.remove([EntityID(10), EntityID(11), EntityID(12), EntityID(13)])
    view.set(EntityID(6), .idle)
    view.set(EntityID(16), .idle)
    view.add(.unit(.worker), owner: TestViews.me, at: 9, 13)
    view.population = 13
    view.populationLimit = 25
    var cp = player()
    let kinds = constructs(decide(&cp, view)).map(\.kind)
    #expect(kinds.contains(.barracks))
    #expect(kinds.contains(.tower))
}

@Test func defendsInTheSkirmish() {
    let view = Samples.farmsAgeSkirmish()
    var cp = player()
    let orders = decide(&cp, view)
    let opponents = Set(view.owned(by: TestViews.enemy).filter { $0.kind != .building(.townCentre) }.map(\.id))
    let defence = attacks(orders).filter { opponents.contains($0.target) }
    #expect(!defence.isEmpty)
    // The knight, the one warfighter not yet fighting, takes the swordsman it strikes half as hard again.
    #expect(defence.contains { $0.units == [EntityID(22)] && $0.target == EntityID(24) })
}

@Test func attacksTheNearestKnownBuildingWithALargeArmy() {
    let view = TestViews.farmsArmy(extra: 10)
    var cp = player()
    let orders = decide(&cp, view)
    let centre = view.first(.building(.townCentre), of: TestViews.enemy)!.id
    let attack = attacks(orders).first { $0.target == centre }
    #expect(attack != nil)
    #expect((attack?.units.count ?? 0) >= 10)
}

@Test func marchesOnABuildingRememberedOutOfSight() {
    var cp = player()
    let small = TestViews.farmsArmy(extra: 0)
    #expect(attacks(decide(&cp, small)).isEmpty)
    let centre = small.first(.building(.townCentre), of: TestViews.enemy)!
    var later = TestViews.farmsArmy(extra: 10, tick: small.tick + Tick.seconds(2))
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
    // Eight warfighters are too few to attack alone, but enough to join the ally,
    // at its target rather than the nearer town centre.
    let joint = attacks(orders).filter { $0.target == farHouse }
    #expect(joint.count == 1)
    #expect(joint.allSatisfy { $0.units.count == 8 })
    #expect(attacks(orders).allSatisfy { view.entity($0.target)?.owner == TestViews.enemy })

    let (alone, _) = TestViews.alliedAttack(allyAttacking: false)
    var unjoined = player()
    #expect(attacks(decide(&unjoined, alone)).isEmpty)
}

@Test func scoutsWhenNoOpponentIsKnown() {
    var view = Samples.farmsAgeSkirmish()
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

@Test func choosesNothingOutOfTurnOrForAnotherPlayer() {
    var cp = player()
    var paused = Samples.townsAgeOpening()
    paused.isPaused = true
    #expect(decide(&cp, paused).isEmpty)
    var over = Samples.townsAgeOpening()
    over.outcome = .won(TeamID(1))
    #expect(decide(&cp, over).isEmpty)
    var other = ComputerPlayer(player: TestViews.enemy, difficulty: .standard, seed: 1)
    #expect(decide(&other, Samples.townsAgeOpening()).isEmpty)
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
    let early = TestViews.farmsArmy(extra: 10, tick: Tick.seconds(12 * 60))
    var standard = player(.standard)
    var easy = player(.easy)
    #expect(!attacks(decide(&standard, early)).isEmpty)
    #expect(attacks(decide(&easy, early)).isEmpty)

    // Sixteen minutes in, with six: easy attacks; standard and hard wait for more.
    let late = TestViews.farmsArmy(extra: 1, tick: Tick.seconds(16 * 60))
    for difficulty in Difficulty.allCases {
        var cp = player(difficulty)
        #expect(attacks(decide(&cp, late)).isEmpty == (difficulty != .easy), "\(difficulty)")
    }
}

@Test func hardLeansFurtherTowardCounters() {
    var seen = [Double](repeating: 0, count: UnitKind.allCases.count)
    seen[UnitKind.knight1.rawValue] = 6
    let kinds: [UnitKind] = [.soldier1, .soldier3, .knight1]
    func spearmen(_ difficulty: Difficulty) -> Double {
        let weights = Turn.mix(kinds, seen: seen, counters: Tuning.of(difficulty).counters, catalogue: .standard)
        return weights[0] / weights.reduce(0, +)
    }
    #expect(spearmen(.easy) < spearmen(.standard))
    #expect(spearmen(.standard) < spearmen(.hard))

    // Seeing only horsemen, the barracks trains the spearman that strikes them three times as hard.
    var view = TestViews.farmsArmy(extra: 0, tick: Tick.seconds(600))
    view.set(EntityID(10), .idle)
    view.add(.unit(.knight1), owner: TestViews.enemy, at: 28, 3, .moving)
    view.add(.unit(.knight1), owner: TestViews.enemy, at: 29, 3, .moving)
    view.setVisibility(.visible) { $0.x >= 24 && $0.y < 6 }
    var hard = player(.hard)
    #expect(decide(&hard, view).contains(.train(at: EntityID(10), unit: .soldier1)))
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

enum OrderFixture { static let expected: UInt64 = 0x4349_F29F_4C4F_E9D2 }

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
