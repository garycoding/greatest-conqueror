// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// The tables of the game: what everything costs, how strong it is, and how long
// it takes. The simulation, the interface and the computer player all read these
// values, so they live here. They are first estimates, to be tuned by play;
// every duration is in ticks (see `Tick`).

/// How a unit or building attacks.
public struct Attack: Hashable, Codable, Sendable {
    /// Harm per blow, before armour.
    public var damage: Int
    /// Reach in tiles; 1 or less is a melee attack.
    public var range: Double
    /// Ticks between blows.
    public var interval: Int
    /// The radius in tiles within which a blow also harms the target's
    /// neighbours (a cannon's shot); `nil` for a blow that harms the target alone.
    public var area: Double?

    public init(damage: Int, range: Double, interval: Int, area: Double? = nil) {
        self.damage = damage; self.range = range; self.interval = interval; self.area = area
    }
}

public struct UnitStats: Hashable, Codable, Sendable {
    public var kind: UnitKind
    /// The age in which the kind can first be trained.
    public var age: Age
    public var cost: ResourceAmounts
    public var trainTime: Int
    public var health: Int
    public var armour: Int
    /// Tiles per second.
    public var speed: Double
    /// Tiles within which it sees.
    public var sight: Double
    public var attack: Attack?
    /// The building kinds at which it is trained.
    public var trainedAt: [BuildingKind]
    /// How many places it takes under the population limit.
    public var population: Int

    public init(kind: UnitKind, age: Age, cost: ResourceAmounts, trainTime: Int, health: Int, armour: Int,
                speed: Double, sight: Double, attack: Attack?, trainedAt: [BuildingKind], population: Int = 1) {
        self.kind = kind; self.age = age; self.cost = cost; self.trainTime = trainTime; self.health = health
        self.armour = armour; self.speed = speed; self.sight = sight; self.attack = attack
        self.trainedAt = trainedAt; self.population = population
    }
}

public struct BuildingStats: Hashable, Codable, Sendable {
    public var kind: BuildingKind
    public var age: Age
    public var cost: ResourceAmounts
    /// Ticks of one worker's work to construct it; more workers finish sooner.
    public var buildTime: Int
    public var health: Int
    public var armour: Int
    /// The tiles it covers, from its origin toward +x and +y.
    public var footprint: GridPoint
    public var sight: Double
    /// Towers, castles and the town centre shoot at opponents in range.
    public var attack: Attack?
    /// Population places it provides.
    public var housing: Int
    /// Resources that workers (or boats, at a boat house) may deliver here.
    public var accepts: [Resource]
    /// What may be trained here.
    public var trains: [UnitKind]

    public init(kind: BuildingKind, age: Age, cost: ResourceAmounts, buildTime: Int, health: Int, armour: Int,
                footprint: GridPoint, sight: Double, attack: Attack? = nil, housing: Int = 0,
                accepts: [Resource] = [], trains: [UnitKind] = []) {
        self.kind = kind; self.age = age; self.cost = cost; self.buildTime = buildTime; self.health = health
        self.armour = armour; self.footprint = footprint; self.sight = sight; self.attack = attack
        self.housing = housing; self.accepts = accepts; self.trains = trains
    }
}

/// What it takes to leave an age for the next (requirement 6): paid at a town
/// centre when the advance begins, which then takes `time` ticks there.
public struct AdvanceStats: Hashable, Codable, Sendable {
    public var from: Age
    public var cost: ResourceAmounts
    public var time: Int

    public init(from: Age, cost: ResourceAmounts, time: Int) {
        self.from = from; self.cost = cost; self.time = time
    }
}

/// Gathering rates and loads. Tables are arrays indexed by `SiteKind.rawValue`,
/// not dictionaries, so that they encode identically in every process.
public struct GatheringStats: Hashable, Codable, Sendable {
    /// Units of the resource a worker takes from a site per second, by site kind.
    public var perSecondBySite: [Double]
    /// Food per second a worker earns tending a farm.
    public var farmingPerSecond: Double
    /// The food a farm yields before it runs dry and must be reseeded (ruled 2026-11-19).
    public var farmYield: Int
    /// What reseeding a farm that has run dry costs.
    public var farmReseed: ResourceAmounts
    /// How much a worker carries before returning to deliver it.
    public var load: Int
    /// What each kind of site holds when the map is made, by site kind.
    public var amountBySite: [Int]

    public init(perSecond: [SiteKind: Double], farmingPerSecond: Double, farmYield: Int, farmReseed: ResourceAmounts,
                load: Int, siteAmount: [SiteKind: Int]) {
        perSecondBySite = SiteKind.allCases.map { perSecond[$0] ?? 0 }
        amountBySite = SiteKind.allCases.map { siteAmount[$0] ?? 0 }
        self.farmingPerSecond = farmingPerSecond; self.farmYield = farmYield; self.farmReseed = farmReseed
        self.load = load
    }

    public func perSecond(_ kind: SiteKind) -> Double {
        kind.rawValue < perSecondBySite.count ? perSecondBySite[kind.rawValue] : 0
    }
    public func amount(_ kind: SiteKind) -> Int {
        kind.rawValue < amountBySite.count ? amountBySite[kind.rawValue] : 0
    }
}

/// A person's car (ruled 2026-11-21): every enemy unit within `killRadius`
/// tiles of it dies at once, unless its person has turned the radius off.
public struct CarStats: Hashable, Codable, Sendable {
    public var killRadius: Double
    /// How many cars a person may make (ruled 2026-11-21: up to five).
    public var perPerson: Int
    /// How far the car's laser reaches, in tiles (ruled 2026-11-21).
    public var laserRange: Double
    /// Ticks in which the laser burns down any building, whatever its size.
    public var laserTime: Int

    public init(killRadius: Double, perPerson: Int = 5, laserRange: Double = 8, laserTime: Int = 4 * Tick.rate) {
        self.killRadius = killRadius; self.perPerson = perPerson; self.laserRange = laserRange; self.laserTime = laserTime
    }
}

/// A damage multiplier when one kind strikes another.
public struct Bonus: Hashable, Codable, Sendable {
    public var attacker: UnitKind
    public var defender: UnitKind
    public var multiplier: Double
    public init(_ attacker: UnitKind, against defender: UnitKind, _ multiplier: Double) {
        self.attacker = attacker; self.defender = defender; self.multiplier = multiplier
    }
}

/// All the tables of the game.
public struct Catalogue: Hashable, Codable, Sendable {
    public var units: [UnitStats]
    public var buildings: [BuildingStats]
    public var advances: [AdvanceStats]
    public var gathering: GatheringStats
    /// Damage multipliers; 1 where none is listed.
    public var bonuses: [Bonus]
    /// What every player holds at the start of a match.
    public var startingResources: ResourceAmounts
    /// Workers each player begins with, beside the town centre.
    public var startingPeople: Int
    /// The population limit can never exceed this, however many houses stand.
    public var populationMaximum: Int
    /// What a person's car does; nil for no car.
    public var car: CarStats?

    public init(units: [UnitStats], buildings: [BuildingStats], advances: [AdvanceStats], gathering: GatheringStats,
                bonuses: [Bonus], startingResources: ResourceAmounts, startingPeople: Int, populationMaximum: Int,
                car: CarStats? = nil) {
        self.units = units; self.buildings = buildings; self.advances = advances
        self.gathering = gathering; self.bonuses = bonuses
        self.startingResources = startingResources; self.startingPeople = startingPeople
        self.populationMaximum = populationMaximum; self.car = car
    }

    public func stats(_ kind: UnitKind) -> UnitStats { units.first { $0.kind == kind }! }
    public func stats(_ kind: BuildingKind) -> BuildingStats { buildings.first { $0.kind == kind }! }
    public func advance(from age: Age) -> AdvanceStats? { advances.first { $0.from == age } }

    /// The last age a player can reach with these tables.
    public var lastAge: Age {
        var age = Age.towns
        while advance(from: age) != nil, let next = Age(rawValue: age.rawValue + 1) { age = next }
        return age
    }

    /// The damage multiplier when `attacker` strikes `defender`.
    public func bonus(_ attacker: UnitKind, against defender: UnitKind) -> Double {
        bonuses.first { $0.attacker == attacker && $0.defender == defender }?.multiplier ?? 1
    }

    /// The standard tables: the figures of Cities of Progress for the kinds
    /// that remain, with the costs in resources that are gone moved to wood
    /// (stone) and gold (bronze, iron, gunpowder and oil), until they are tuned.
    public static let standard: Catalogue = {
        func cost(_ pairs: [Resource: Int]) -> ResourceAmounts { ResourceAmounts(pairs) }
        let s = Tick.seconds
        let units: [UnitStats] = [
            UnitStats(kind: .worker, age: .towns, cost: cost([.food: 50]), trainTime: s(12), health: 25, armour: 0,
                      speed: 1.0, sight: 4, attack: Attack(damage: 3, range: 1, interval: s(1.5)), trainedAt: [.townCentre]),
            // A boat (ruled 2026-11-21): on the water only, a worker's speed, health and load.
            UnitStats(kind: .boat, age: .towns, cost: cost([.wood: 50]), trainTime: s(15), health: 25, armour: 0,
                      speed: 1.0, sight: 5, attack: nil, trainedAt: [.boatHouse]),
            // A person's car (ruled 2026-11-21): free, outside the population, twice a worker's speed.
            UnitStats(kind: .car, age: .towns, cost: cost([:]), trainTime: 0, health: 1, armour: 0,
                      speed: 2.0, sight: 8, attack: nil, trainedAt: [], population: 0),
            UnitStats(kind: .spearman, age: .farms, cost: cost([.food: 60, .gold: 20]), trainTime: s(14), health: 55, armour: 1,
                      speed: 1.0, sight: 5, attack: Attack(damage: 5, range: 1, interval: s(1.5)), trainedAt: [.barracks]),
            UnitStats(kind: .swordsman, age: .ships, cost: cost([.food: 60, .gold: 25]), trainTime: s(14), health: 70, armour: 2,
                      speed: 1.0, sight: 5, attack: Attack(damage: 7, range: 1, interval: s(1.5)), trainedAt: [.barracks]),
            UnitStats(kind: .musketeer, age: .cannons, cost: cost([.food: 60, .gold: 30]), trainTime: s(16), health: 60,
                      armour: 1, speed: 1.0, sight: 7, attack: Attack(damage: 12, range: 6, interval: s(3)),
                      trainedAt: [.barracks, .castle]),
            UnitStats(kind: .rifleman, age: .hospitals, cost: cost([.food: 60, .gold: 40]), trainTime: s(16),
                      health: 70, armour: 1, speed: 1.1, sight: 8, attack: Attack(damage: 14, range: 7, interval: s(2.5)),
                      trainedAt: [.barracks]),
            UnitStats(kind: .horseman, age: .ships, cost: cost([.food: 80, .gold: 20]), trainTime: s(18), health: 90, armour: 1,
                      speed: 2.2, sight: 7, attack: Attack(damage: 7, range: 1, interval: s(1.4)), trainedAt: [.stable],
                      population: 2),
            UnitStats(kind: .knight, age: .cannons, cost: cost([.food: 100, .gold: 60]), trainTime: s(20), health: 130, armour: 3,
                      speed: 2.0, sight: 7, attack: Attack(damage: 10, range: 1, interval: s(1.5)), trainedAt: [.stable, .castle],
                      population: 2),
            UnitStats(kind: .cannon, age: .cannons, cost: cost([.wood: 120, .gold: 140]), trainTime: s(35),
                      health: 160, armour: 2, speed: 0.6, sight: 9, attack: Attack(damage: 30, range: 10, interval: s(5), area: 1.5),
                      trainedAt: [.castle], population: 3),
            UnitStats(kind: .fieldGun, age: .hospitals, cost: cost([.gold: 180]), trainTime: s(35),
                      health: 180, armour: 2, speed: 0.8, sight: 10, attack: Attack(damage: 32, range: 12, interval: s(5), area: 1.5),
                      trainedAt: [.castle], population: 3),
        ]
        let buildings: [BuildingStats] = [
            BuildingStats(kind: .townCentre, age: .towns, cost: cost([.wood: 300]), buildTime: s(120), health: 1200,
                          armour: 2, footprint: GridPoint(3, 3), sight: 8, attack: Attack(damage: 3, range: 6, interval: s(2)),
                          housing: 5, accepts: [.food, .wood, .gold], trains: [.worker]),
            BuildingStats(kind: .house, age: .towns, cost: cost([.wood: 30]), buildTime: s(20), health: 200, armour: 0,
                          footprint: GridPoint(2, 2), sight: 3, housing: 5),
            // A boat house on the shore (ruled 2026-11-21): it trains boats and takes in their loads.
            BuildingStats(kind: .boatHouse, age: .towns, cost: cost([.wood: 100]), buildTime: s(30), health: 300, armour: 0,
                          footprint: GridPoint(2, 2), sight: 4, accepts: [.food, .gold], trains: [.boat]),
            BuildingStats(kind: .barracks, age: .farms, cost: cost([.wood: 100]), buildTime: s(40), health: 500, armour: 1,
                          footprint: GridPoint(3, 3), sight: 4, trains: [.spearman, .swordsman, .musketeer, .rifleman]),
            BuildingStats(kind: .watchTower, age: .farms, cost: cost([.wood: 100]), buildTime: s(40), health: 400,
                          armour: 2, footprint: GridPoint(1, 1), sight: 9, attack: Attack(damage: 4, range: 7, interval: s(2))),
            // The farm is of the age of farms (requirement 10), not of Cities of
            // Progress's Iron age: the stock pen, which fed that game's Bronze age, is gone.
            BuildingStats(kind: .farm, age: .farms, cost: cost([.wood: 60]), buildTime: s(20), health: 150, armour: 0,
                          footprint: GridPoint(3, 3), sight: 2),
            BuildingStats(kind: .stable, age: .ships, cost: cost([.wood: 120]), buildTime: s(45), health: 500, armour: 1,
                          footprint: GridPoint(3, 3), sight: 4, trains: [.horseman, .knight]),
            BuildingStats(kind: .castle, age: .cannons, cost: cost([.wood: 800]), buildTime: s(150), health: 3000,
                          armour: 4, footprint: GridPoint(4, 4), sight: 10, attack: Attack(damage: 8, range: 8, interval: s(2)),
                          housing: 10, trains: [.knight, .musketeer, .cannon, .fieldGun]),
        ]
        // Each advance's time is the Cities of Progress study divided among the
        // four scholars it was set for.
        let advances: [AdvanceStats] = [
            AdvanceStats(from: .towns, cost: cost([.food: 300, .wood: 100]), time: s(90)),
            AdvanceStats(from: .farms, cost: cost([.food: 500, .gold: 250]), time: s(150)),
            AdvanceStats(from: .ships, cost: cost([.food: 800, .gold: 400]), time: s(200)),
            AdvanceStats(from: .cannons, cost: cost([.food: 1000, .gold: 750]), time: s(250)),
        ]
        let gathering = GatheringStats(
            perSecond: [.tree: 0.6, .prey: 0.8, .gold: 0.4, .fish: 0.7],
            farmingPerSecond: 0.9,
            farmYield: 300,
            farmReseed: cost([.wood: 60]),
            load: 10,
            siteAmount: [.tree: 100, .prey: 150, .gold: 400, .fish: 200]
        )
        let bonuses: [Bonus] = [
            Bonus(.spearman, against: .horseman, 3),
            Bonus(.swordsman, against: .spearman, 1.5),
            Bonus(.knight, against: .swordsman, 1.5), Bonus(.knight, against: .musketeer, 1.5),
            Bonus(.spearman, against: .knight, 2.5),
            Bonus(.musketeer, against: .knight, 2), Bonus(.musketeer, against: .swordsman, 1.5),
            Bonus(.rifleman, against: .knight, 2), Bonus(.rifleman, against: .musketeer, 1.5), Bonus(.rifleman, against: .swordsman, 1.5),
            Bonus(.fieldGun, against: .rifleman, 1.5), Bonus(.fieldGun, against: .musketeer, 1.5),
        ]
        return Catalogue(units: units, buildings: buildings, advances: advances, gathering: gathering, bonuses: bonuses,
                         startingResources: cost([.food: 200, .wood: 250]),
                         startingPeople: 3, populationMaximum: 200,
                         car: CarStats(killRadius: 11))
    }()
}
