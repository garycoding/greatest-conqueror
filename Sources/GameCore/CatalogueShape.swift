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
}

/// Everything in the catalogue that the tables leave to the code.
public struct CatalogueShape: Sendable {
    public var units: [UnitShape]
    public var buildings: [BuildingShape]
    public var gathering: GatheringStats
    public var bonuses: [Bonus]
    public var startingResources: ResourceAmounts
    public var startingPeople: Int
    public var founderPeople: Int
    /// How many troops a navy ship carries (requirement 16).
    public var shipCargo: Int
    public var populationMaximum: Int
    public var car: CarStats?

    public func unit(_ kind: UnitKind) -> UnitShape { units.first { $0.kind == kind }! }
    public func building(_ kind: BuildingKind) -> BuildingShape { buildings.first { $0.kind == kind }! }

    public static let standard: CatalogueShape = {
        func cost(_ pairs: [Resource: Int]) -> ResourceAmounts { ResourceAmounts(pairs) }
        let units: [UnitShape] = [
            UnitShape(kind: .worker, armour: 0, speed: 1.0, sight: 4, population: 1),
            UnitShape(kind: .doctor, armour: 0, speed: 1.0, sight: 5, population: 1),
            // A fishing boat (ruled 2026-11-21): on the water only, a worker's speed.
            UnitShape(kind: .fishingBoat, armour: 0, speed: 1.0, sight: 5, population: 1),
            // A person's car (ruled 2026-11-21): outside the population, twice a worker's speed.
            UnitShape(kind: .car, armour: 0, speed: 2.0, sight: 8, population: 0),
            UnitShape(kind: .soldier1, armour: 1, speed: 1.0, sight: 5, population: 1),
            UnitShape(kind: .soldier2, armour: 2, speed: 1.0, sight: 5, population: 1),
            UnitShape(kind: .soldier3, armour: 1, speed: 1.0, sight: 7, population: 1),
            UnitShape(kind: .soldier4, armour: 1, speed: 1.1, sight: 8, population: 1),
            UnitShape(kind: .knight1, armour: 1, speed: 2.2, sight: 7, population: 2),
            UnitShape(kind: .knight2, armour: 3, speed: 2.0, sight: 7, population: 2),
            UnitShape(kind: .knight3, armour: 3, speed: 2.1, sight: 8, population: 2),
            UnitShape(kind: .cannon1, armour: 2, speed: 0.6, sight: 9, population: 3, area: 1.5),
            UnitShape(kind: .cannon2, armour: 2, speed: 0.8, sight: 10, population: 3, area: 1.5),
            // A navy ship (requirement 16): on the water only, with built-in cannons.
            UnitShape(kind: .navyShip, armour: 3, speed: 1.3, sight: 9, population: 3),
            // A founder (ruled 2026-11-22): outside the population, a little quicker than a worker.
            UnitShape(kind: .founder, armour: 0, speed: 1.2, sight: 5, population: 0),
        ]
        let buildings: [BuildingShape] = [
            BuildingShape(kind: .townCentre, armour: 2, footprint: GridPoint(3, 3), sight: 8, housing: 5),
            BuildingShape(kind: .house, armour: 0, footprint: GridPoint(2, 2), sight: 3, housing: 5),
            // A boat house on the shore (ruled 2026-11-21), where boats are made.
            BuildingShape(kind: .boatHouse, armour: 0, footprint: GridPoint(2, 2), sight: 4, housing: 0),
            BuildingShape(kind: .barracks, armour: 1, footprint: GridPoint(3, 3), sight: 4, housing: 0),
            BuildingShape(kind: .tower, armour: 2, footprint: GridPoint(1, 1), sight: 9, housing: 0),
            BuildingShape(kind: .farm, armour: 0, footprint: GridPoint(3, 3), sight: 2, housing: 0),
            BuildingShape(kind: .stable, armour: 1, footprint: GridPoint(3, 3), sight: 4, housing: 0),
            BuildingShape(kind: .castle, armour: 4, footprint: GridPoint(4, 4), sight: 10, housing: 10),
            BuildingShape(kind: .cannonFactory, armour: 1, footprint: GridPoint(3, 3), sight: 4, housing: 0),
            BuildingShape(kind: .hospital, armour: 1, footprint: GridPoint(3, 3), sight: 4, housing: 0),
        ]
        let gathering = GatheringStats(farmYield: 300, farmReseed: cost([.wood: 60]),
                                       siteAmount: [.tree: 100, .prey: 150, .gold: 400, .fish: 200, .fruit: 150])
        let bonuses: [Bonus] = [
            Bonus(.soldier1, against: .knight1, 3),
            Bonus(.soldier2, against: .soldier1, 1.5),
            Bonus(.knight2, against: .soldier2, 1.5), Bonus(.knight2, against: .soldier3, 1.5),
            Bonus(.knight3, against: .soldier3, 1.5), Bonus(.knight3, against: .soldier4, 1.5),
            Bonus(.soldier1, against: .knight2, 2.5),
            Bonus(.soldier3, against: .knight2, 2), Bonus(.soldier3, against: .soldier2, 1.5),
            Bonus(.soldier4, against: .knight2, 2), Bonus(.soldier4, against: .knight3, 2), Bonus(.soldier4, against: .soldier3, 1.5), Bonus(.soldier4, against: .soldier2, 1.5),
            Bonus(.cannon2, against: .soldier4, 1.5), Bonus(.cannon2, against: .soldier3, 1.5),
        ]
        return CatalogueShape(units: units, buildings: buildings, gathering: gathering, bonuses: bonuses,
                              startingResources: cost([.food: 200, .wood: 250]), startingPeople: 3,
                              founderPeople: 2, shipCargo: 20, populationMaximum: 200, car: CarStats(killRadius: 11))
    }()
}
