// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// The figures of the catalogue that the tables do not hold (requirement 25
// names costs, health, attacks, building and production times, gathering,
// healing and repair rates and radii, and the advances; these are the rest):
// how each kind moves, sees, is armoured and is housed, the shape of the
// ground's sites, the start of a match, the damage bonuses and the car. They
// stay in the code until a later step moves them into the tables.

/// What the tables leave to the code about a unit kind.
public struct UnitShape: Hashable, Sendable {
    public var kind: UnitKind
    public var armour: Int
    /// Tiles per second.
    public var speed: Double
    public var sight: Double
    public var population: Int
    /// The radius of a blow's harm about its target, for the kinds whose blow has one.
    public var area: Double?
}

/// What the tables leave to the code about a building kind.
public struct BuildingShape: Hashable, Sendable {
    public var kind: BuildingKind
    public var armour: Int
    public var footprint: GridPoint
    public var sight: Double
    public var housing: Int
    public var accepts: [Resource]
}

/// Everything in the catalogue that the tables leave to the code.
public struct CatalogueShape: Sendable {
    public var units: [UnitShape]
    public var buildings: [BuildingShape]
    public var gathering: GatheringStats
    public var bonuses: [Bonus]
    public var startingResources: ResourceAmounts
    public var startingPeople: Int
    public var populationMaximum: Int
    public var car: CarStats?

    public func unit(_ kind: UnitKind) -> UnitShape { units.first { $0.kind == kind }! }
    public func building(_ kind: BuildingKind) -> BuildingShape { buildings.first { $0.kind == kind }! }

    public static let standard: CatalogueShape = {
        func cost(_ pairs: [Resource: Int]) -> ResourceAmounts { ResourceAmounts(pairs) }
        let units: [UnitShape] = [
            UnitShape(kind: .worker, armour: 0, speed: 1.0, sight: 4, population: 1),
            // A boat (ruled 2026-11-21): on the water only, a worker's speed.
            UnitShape(kind: .boat, armour: 0, speed: 1.0, sight: 5, population: 1),
            // A person's car (ruled 2026-11-21): outside the population, twice a worker's speed.
            UnitShape(kind: .car, armour: 0, speed: 2.0, sight: 8, population: 0),
            UnitShape(kind: .spearman, armour: 1, speed: 1.0, sight: 5, population: 1),
            UnitShape(kind: .swordsman, armour: 2, speed: 1.0, sight: 5, population: 1),
            UnitShape(kind: .musketeer, armour: 1, speed: 1.0, sight: 7, population: 1),
            UnitShape(kind: .rifleman, armour: 1, speed: 1.1, sight: 8, population: 1),
            UnitShape(kind: .horseman, armour: 1, speed: 2.2, sight: 7, population: 2),
            UnitShape(kind: .knight, armour: 3, speed: 2.0, sight: 7, population: 2),
            UnitShape(kind: .cannon, armour: 2, speed: 0.6, sight: 9, population: 3, area: 1.5),
            UnitShape(kind: .fieldGun, armour: 2, speed: 0.8, sight: 10, population: 3, area: 1.5),
        ]
        let buildings: [BuildingShape] = [
            BuildingShape(kind: .townCentre, armour: 2, footprint: GridPoint(3, 3), sight: 8, housing: 5, accepts: [.food, .wood, .gold]),
            BuildingShape(kind: .house, armour: 0, footprint: GridPoint(2, 2), sight: 3, housing: 5, accepts: []),
            // A boat house on the shore (ruled 2026-11-21): it takes in the boats' loads.
            BuildingShape(kind: .boatHouse, armour: 0, footprint: GridPoint(2, 2), sight: 4, housing: 0, accepts: [.food, .gold]),
            BuildingShape(kind: .barracks, armour: 1, footprint: GridPoint(3, 3), sight: 4, housing: 0, accepts: []),
            BuildingShape(kind: .watchTower, armour: 2, footprint: GridPoint(1, 1), sight: 9, housing: 0, accepts: []),
            BuildingShape(kind: .farm, armour: 0, footprint: GridPoint(3, 3), sight: 2, housing: 0, accepts: []),
            BuildingShape(kind: .stable, armour: 1, footprint: GridPoint(3, 3), sight: 4, housing: 0, accepts: []),
            BuildingShape(kind: .castle, armour: 4, footprint: GridPoint(4, 4), sight: 10, housing: 10, accepts: []),
        ]
        let gathering = GatheringStats(farmYield: 300, farmReseed: cost([.wood: 60]), load: 10,
                                       siteAmount: [.tree: 100, .prey: 150, .gold: 400, .fish: 200])
        let bonuses: [Bonus] = [
            Bonus(.spearman, against: .horseman, 3),
            Bonus(.swordsman, against: .spearman, 1.5),
            Bonus(.knight, against: .swordsman, 1.5), Bonus(.knight, against: .musketeer, 1.5),
            Bonus(.spearman, against: .knight, 2.5),
            Bonus(.musketeer, against: .knight, 2), Bonus(.musketeer, against: .swordsman, 1.5),
            Bonus(.rifleman, against: .knight, 2), Bonus(.rifleman, against: .musketeer, 1.5), Bonus(.rifleman, against: .swordsman, 1.5),
            Bonus(.fieldGun, against: .rifleman, 1.5), Bonus(.fieldGun, against: .musketeer, 1.5),
        ]
        return CatalogueShape(units: units, buildings: buildings, gathering: gathering, bonuses: bonuses,
                              startingResources: cost([.food: 200, .wood: 250]), startingPeople: 3,
                              populationMaximum: 200, car: CarStats(killRadius: 11))
    }()
}
