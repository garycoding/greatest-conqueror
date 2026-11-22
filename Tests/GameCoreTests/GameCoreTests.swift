// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import Testing
@testable import GameCore

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}

@Test func valuesEncodeAndDecodeToThemselves() throws {
    #expect(try roundTrip(Samples.map()) == Samples.map())
    #expect(try roundTrip(Samples.townsAgeOpening()) == Samples.townsAgeOpening())
    #expect(try roundTrip(Samples.farmsAgeSkirmish()) == Samples.farmsAgeSkirmish())
    #expect(try roundTrip(Samples.twoPlayerSetup()) == Samples.twoPlayerSetup())
    #expect(try roundTrip(Catalogue.standard) == Catalogue.standard)
    let orders: [Order] = [
        .move(units: [EntityID(1)], to: MapPosition(x: 1, y: 2)), .gather(units: [EntityID(2)], site: SiteID(3)),
        .work(units: [EntityID(4)], at: EntityID(1)), .construct(workers: [EntityID(5)], building: .house, at: GridPoint(3, 4)),
        .attack(units: [EntityID(6)], target: EntityID(9)), .train(at: EntityID(1), unit: .worker),
        .cancelTraining(at: EntityID(1)), .advanceAge(at: EntityID(1)), .stop(units: [EntityID(1)]),
        .demolish(workers: [EntityID(2)], building: EntityID(1)), .setPaused(true),
    ]
    #expect(try roundTrip(orders) == orders)
    #expect(try roundTrip(OrderResult.refused(.notEnough(ResourceAmounts([.wood: 20])))) == .refused(.notEnough(ResourceAmounts([.wood: 20]))))
}

@Test func catalogueHoldsEveryKind() {
    let c = Catalogue.standard
    for kind in UnitKind.allCases { #expect(c.units.filter { $0.kind == kind }.count == 1, "\(kind)") }
    for kind in BuildingKind.allCases { #expect(c.buildings.filter { $0.kind == kind }.count == 1, "\(kind)") }
    // An advance out of every age but the last.
    for age in Age.allCases { #expect((c.advance(from: age) != nil) == (age.next != nil), "\(age)") }
    #expect(c.lastAge == .hospitals)
    #expect([BuildingKind.townCentre, .house].allSatisfy { c.stats($0).age == .towns })
    #expect([BuildingKind.barracks, .watchTower].allSatisfy { c.stats($0).age == .farms })
    // Everything trainable is trained somewhere that trains it, and the reverse.
    for stats in c.units where !stats.trainedAt.isEmpty {
        for building in stats.trainedAt { #expect(c.stats(building).trains.contains(stats.kind), "\(stats.kind) at \(building)") }
    }
    for stats in c.buildings {
        for unit in stats.trains { #expect(c.stats(unit).trainedAt.contains(stats.kind), "\(unit) at \(stats.kind)") }
    }
    // Workers deliver food, wood and gold to the town centre; boats food and gold to the boat house.
    #expect(c.stats(.townCentre).accepts == [.food, .wood, .gold])
    #expect(c.stats(.boatHouse).accepts == [.food, .gold])
}

@Test func theFiveAgesAndTheThreeResources() {
    #expect(Age.allCases == [.towns, .farms, .ships, .cannons, .hospitals])
    #expect(Age.allCases.map(\.rawValue) == [0, 1, 2, 3, 4])
    #expect(Age.allCases.map(\.look) == [.stone, .bronze, .iron, .alchemy, .industrial])
    #expect(Age.towns.title == "Age of towns" && Age.hospitals.title == "Age of hospitals")
    #expect(Resource.allCases == [.food, .wood, .gold])
    #expect(SiteKind.gold.yield == .gold && SiteKind.fish.yield == .food && SiteKind.prey.yield == .food)
    #expect(Samples.townsAgeOpening().shownResources == [.food, .wood, .gold])
}

@Test func generatorIsSeededAndStable() {
    var a = SeededGenerator(seed: 42), b = SeededGenerator(seed: 42), c = SeededGenerator(seed: 43)
    let xs = (0..<5).map { _ in a.next() }
    #expect(xs == (0..<5).map { _ in b.next() })
    #expect(xs != (0..<5).map { _ in c.next() })
    // A fixed value, so that a change of algorithm is noticed: saved matches depend on it.
    var d = SeededGenerator(seed: 1)
    #expect(d.next() == 0xB3F2_AF6D_0FC7_10C5)
    var sum = StableChecksum(); sum.add("cities")
    #expect(sum.value == 0x3F72_BDA1_17A8_8752)
}

@Test func projectionRoundTrips() {
    for p in [MapPosition(x: 0, y: 0), MapPosition(x: 3.5, y: 7.25), MapPosition(x: 31, y: 2)] {
        let back = Projection.map(Projection.screen(p))
        #expect(abs(back.x - p.x) < 1e-9 && abs(back.y - p.y) < 1e-9)
    }
    #expect(Projection.screen(MapPosition(x: 1, y: 0)).x > 0)   // +x toward the lower right
    #expect(Projection.screen(MapPosition(x: 0, y: 1)).x < 0)   // +y toward the lower left
    #expect(Projection.screen(MapPosition(x: 1, y: 1)).y < 0)   // both downward
}

@Test func spriteChecklistCoversTheFirstTwoAges() {
    let keys = SpriteKey.required(through: .farms)
    #expect(Set(keys).count == keys.count)
    for kind in BuildingKind.allCases where Catalogue.standard.stats(kind).age <= .farms {
        #expect(keys.contains(SpriteKey(.building(kind, .bronze), .complete)))
    }
    #expect(keys.contains(SpriteKey(.unit(.worker, .stone), .working)))
    #expect(keys.contains(SpriteKey(.unit(.worker, .bronze), .working)))
    #expect(keys.contains(SpriteKey(.unit(.spearman, .bronze), .fighting)))
    #expect(!keys.contains(SpriteKey(.unit(.swordsman, .iron), .fighting)))
    #expect(keys.contains(SpriteKey(.site(.gold), .complete)))
}

@MainActor @Test func sessionTakesRefusalsFromTheViewAndDropsVanishedSelection() {
    var sent: [Order] = []
    let session = PlayerSession(view: Samples.townsAgeOpening(), catalogue: .standard,
                                camera: Camera(centre: MapPosition(x: 10, y: 10))) { sent.append($0) }
    session.selection = [EntityID(1), EntityID(999)]
    session.issue(.setPaused(true))
    #expect(sent == [.setPaused(true)])
    var next = Samples.farmsAgeSkirmish()
    next.events.append(.refused(.populationLimit))
    session.update(next)
    #expect(session.selection == [EntityID(1)])
    #expect(session.lastRefusal == .populationLimit)
}

@Test func placementFollowsTheOneRule() {
    let view = Samples.townsAgeOpening()
    // On open, explored grass beside the town centre: allowed.
    #expect(Placement.canPlace(.house, at: GridPoint(12, 7), in: view))
    // Over the town centre's own footprint: refused.
    #expect(!Placement.canPlace(.house, at: GridPoint(9, 9), in: view))
    // On a tree: refused; on unexplored ground: refused; off the map: refused.
    #expect(!Placement.canPlace(.house, at: GridPoint(4, 4), in: view))
    #expect(!Placement.canPlace(.house, at: GridPoint(28, 2), in: view))
    #expect(!Placement.canPlace(.house, at: GridPoint(-1, 3), in: view))
    #expect(Placement.footprint(.townCentre, at: GridPoint(8, 8)).count == 9)
    #expect(Placement.origin(.townCentre, centre: MapPosition(x: 9.5, y: 9.5)) == GridPoint(8, 8))
    #expect(Placement.centre(.townCentre, origin: GridPoint(8, 8)) == MapPosition(x: 9.5, y: 9.5))
}

@Test func spriteSubjectsAgreeWithTheChecklist() {
    let view = Samples.farmsAgeSkirmish()
    let keys = Set(SpriteKey.required(through: .hospitals))
    for entity in view.entities {
        let owner = view.players.first { $0.id == entity.owner }!
        let subject = SpriteSubject.of(entity, ownerAge: owner.age)
        let pose: SpritePose = { if case .building = entity.kind { return .complete } else { return .standing } }()
        #expect(keys.contains(SpriteKey(subject, pose)), "\(subject)")
    }
}

@Test func encodingsDoNotDependOnTheProcess() throws {
    // A fixed value: if a dictionary crept back into these types, the encoding
    // would change between processes and this would fail at random.
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    var sum = StableChecksum()
    sum.add(bytes: try encoder.encode(Catalogue.standard))
    sum.add(bytes: try encoder.encode(Samples.twoPlayerSetup()))
    sum.add(bytes: try encoder.encode(Samples.farmsAgeSkirmish()))
    #expect(sum.value == EncodingFixture.expected, "update EncodingFixture.expected only for a deliberate change: \(String(sum.value, radix: 16))")
}

enum EncodingFixture { static let expected: UInt64 = 0xFE6D_956D_0BE2_8961 }

@Test func samplesAreConsistent() {
    for view in [Samples.townsAgeOpening(), Samples.farmsAgeSkirmish()] {
        #expect(view.terrain.count == view.mapWidth * view.mapHeight)
        #expect(view.visibility.count == view.terrain.count)
        #expect(view.entities.map(\.id) == view.entities.map(\.id).sorted())
        #expect(Set(view.entities.map(\.id)).count == view.entities.count)
        for e in view.entities { if case .building(let b) = e.kind { #expect(Placement.origin(b, centre: e.position) == e.tile, "\(b)") } }
    }
    let skirmish = Samples.farmsAgeSkirmish()
    let used = skirmish.entities.filter { $0.owner == skirmish.player }.reduce(0) { n, e in
        if case .unit(let k) = e.kind { return n + Catalogue.standard.stats(k).population } else { return n } }
    let housing = skirmish.entities.filter { $0.owner == skirmish.player }.reduce(0) { n, e in
        if case .building(let k) = e.kind { return n + Catalogue.standard.stats(k).housing } else { return n } }
    #expect(skirmish.population == used && skirmish.populationLimit == housing)
    #expect(Samples.townsAgeOpening().entities.first!.tile == Samples.map().starts[0])
    let map = Samples.map()
    #expect(map.starts.count == 2)
    #expect(map.sites.map(\.id) == map.sites.map(\.id).sorted())
}
