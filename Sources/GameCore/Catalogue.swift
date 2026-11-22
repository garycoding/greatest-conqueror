// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// The catalogue: every figure the simulation, the interface and the computer
// player read about the kinds of unit and building, the ages and the start of a
// match. The figures that requirement 25 names come from the three tables
// (CatalogueTables.swift); the rest from `CatalogueShape`. Every duration is in
// ticks (see `Tick`).

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
    /// The age in which the kind first appears, whose look it keeps if it is a
    /// warfighter; each maker makes it from the age `production.csv` gives.
    public var age: Age
    public var cost: ResourceAmounts
    public var health: Int
    public var armour: Int
    /// Tiles per second.
    public var speed: Double
    /// Tiles within which it sees.
    public var sight: Double
    public var attack: Attack?
    /// The makers at which it is made (`Catalogue.production`): buildings, or the navy ship.
    public var trainedAt: [EntityKind]
    /// For a navy ship, what it makes (`Catalogue.production`); empty for every other kind.
    public var trains: [UnitKind]
    /// For a navy ship, its upgrade in each later age that `stats.csv` gives a
    /// row of its own, in the order of the ages (requirement 24).
    public var levels: [AgeUpgrade]
    /// How many places it takes under the population limit.
    public var population: Int
    /// Units of each resource it takes from a site a second, by `Resource.rawValue`:
    /// food from prey or fish, wood from trees, gold from gold mines.
    public var gathering: [Double]
    /// Food a second it earns tending a farm.
    public var farming: Double
    /// Health points a second it restores to a wounded unit: a doctor's (requirement 13).
    public var healing: Double?
    /// Health points a second it restores to a damaged building: a worker's (requirement 12).
    public var repairing: Double?
    /// The radius in tiles within which it looks, idle, for a unit to heal or a building to repair.
    public var radius: Double?

    public init(kind: UnitKind, age: Age, cost: ResourceAmounts, health: Int, armour: Int, speed: Double, sight: Double,
                attack: Attack?, trainedAt: [EntityKind] = [], trains: [UnitKind] = [], levels: [AgeUpgrade] = [],
                population: Int = 1, gathering: [Double] = [],
                farming: Double = 0, healing: Double? = nil, repairing: Double? = nil, radius: Double? = nil) {
        self.kind = kind; self.age = age; self.cost = cost; self.health = health
        self.armour = armour; self.speed = speed; self.sight = sight; self.attack = attack
        self.trainedAt = trainedAt; self.trains = trains; self.levels = levels; self.population = population
        self.gathering = gathering.count == Resource.allCases.count ? gathering : Array(repeating: 0, count: Resource.allCases.count)
        self.farming = farming; self.healing = healing; self.repairing = repairing; self.radius = radius
    }

    /// Units of a resource it takes from a site a second.
    public func gathers(_ resource: Resource) -> Double {
        resource.rawValue < gathering.count ? gathering[resource.rawValue] : 0
    }
}

public struct BuildingStats: Hashable, Codable, Sendable {
    public var kind: BuildingKind
    /// The age from which it can be built.
    public var age: Age
    public var cost: ResourceAmounts
    /// Ticks of one worker's work to construct it; more workers finish sooner.
    public var buildTime: Int
    /// Ticks of one worker's work to demolish it; more workers finish sooner.
    public var demolishTime: Int
    /// The share of its cost that demolishing it returns, from 0 to 1.
    public var demolishReturn: Double
    public var health: Int
    public var armour: Int
    /// The tiles it covers, from its origin toward +x and +y.
    public var footprint: GridPoint
    public var sight: Double
    /// Towers, castles and the town centre shoot at opponents in range; for a
    /// tower or a castle, this is its attack in the age in which it first appears.
    public var attack: Attack?
    /// Population places it provides.
    public var housing: Int
    /// Resources that workers (or boats, at a boat house) may deliver here.
    public var accepts: [Resource]
    /// What may be made here (`Catalogue.production`).
    public var trains: [UnitKind]
    /// For a tower or a castle, its upgrade in each later age that `stats.csv`
    /// gives a row of its own, in the order of the ages (requirement 24).
    public var levels: [AgeUpgrade]

    public init(kind: BuildingKind, age: Age, cost: ResourceAmounts, buildTime: Int, demolishTime: Int? = nil,
                demolishReturn: Double = 0.5, health: Int, armour: Int,
                footprint: GridPoint, sight: Double, attack: Attack? = nil, housing: Int = 0,
                accepts: [Resource] = [], trains: [UnitKind] = [], levels: [AgeUpgrade] = []) {
        self.kind = kind; self.age = age; self.cost = cost; self.buildTime = buildTime
        self.demolishTime = demolishTime ?? max(1, buildTime / 2); self.demolishReturn = demolishReturn
        self.health = health
        self.armour = armour; self.footprint = footprint; self.sight = sight; self.attack = attack
        self.housing = housing; self.accepts = accepts; self.trains = trains; self.levels = levels
    }
}

/// A tower's, a castle's or a navy ship's figures from a later age on
/// (`BuildingStats.levels`, `UnitStats.levels`; requirement 24).
public struct AgeUpgrade: Hashable, Codable, Sendable {
    public var age: Age
    public var health: Int
    public var attack: Attack?

    public init(age: Age, health: Int, attack: Attack?) { self.age = age; self.health = health; self.attack = attack }
}

/// The figures that the age upgrades: the maximum health and the attack.
public struct AgeFigures: Hashable, Sendable {
    public var health: Int
    public var attack: Attack?
}

/// The upgrade for an age: the last of `levels` reached by `age`, else the
/// kind's own figures.
func figures(base health: Int, _ attack: Attack?, levels: [AgeUpgrade], at age: Age) -> AgeFigures {
    var out = AgeFigures(health: health, attack: attack)
    for level in levels where level.age <= age { out = AgeFigures(health: level.health, attack: level.attack) }
    return out
}

extension UnitStats {
    /// Its health and attack for an owner in `age` (requirement 24).
    public func figures(at age: Age) -> AgeFigures { GameCore.figures(base: health, attack, levels: levels, at: age) }
}

extension BuildingStats {
    /// Its health and attack for an owner in `age` (requirement 24).
    public func figures(at age: Age) -> AgeFigures { GameCore.figures(base: health, attack, levels: levels, at: age) }
}

extension BuildingKind {
    /// The kinds upgraded at each new age, whose later rows in `stats.csv` are
    /// their upgrades (requirement 24): the tower and the castle.
    public var isUpgradedWithAge: Bool { self == .tower || self == .castle }
}

/// One maker and one unit it makes (`production.csv`): the age from which it
/// makes it, and the ticks each takes. A maker is a building, or the navy
/// ship (requirement 17).
public struct ProductionStats: Hashable, Codable, Sendable {
    public var maker: EntityKind
    public var unit: UnitKind
    public var age: Age
    public var time: Int

    public init(maker: EntityKind, unit: UnitKind, age: Age, time: Int) {
        self.maker = maker; self.unit = unit; self.age = age; self.time = time
    }

    public init(maker: BuildingKind, unit: UnitKind, age: Age, time: Int) {
        self.init(maker: .building(maker), unit: unit, age: age, time: time)
    }
}

/// What it takes to leave an age for the next (requirement 6, `ages.csv`):
/// paid at a town centre when the advance begins, which then takes `time` ticks there.
public struct AdvanceStats: Hashable, Codable, Sendable {
    public var from: Age
    public var cost: ResourceAmounts
    public var time: Int

    public init(from: Age, cost: ResourceAmounts, time: Int) {
        self.from = from; self.cost = cost; self.time = time
    }
}

/// The ground's sites and the farm. Tables are arrays indexed by
/// `SiteKind.rawValue`, not dictionaries, so that they encode identically in
/// every process.
public struct GatheringStats: Hashable, Codable, Sendable {
    /// The food a farm yields before it runs dry and must be reseeded (ruled 2026-11-19).
    public var farmYield: Int
    /// What reseeding a farm that has run dry costs.
    public var farmReseed: ResourceAmounts
    /// How much a worker carries before returning to deliver it.
    public var load: Int
    /// What each kind of site holds when the map is made, by site kind.
    public var amountBySite: [Int]

    public init(farmYield: Int, farmReseed: ResourceAmounts, load: Int, siteAmount: [SiteKind: Int]) {
        amountBySite = SiteKind.allCases.map { siteAmount[$0] ?? 0 }
        self.farmYield = farmYield; self.farmReseed = farmReseed; self.load = load
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
    /// Who makes what, from which age, and how long each takes.
    public var production: [ProductionStats]
    public var advances: [AdvanceStats]
    public var gathering: GatheringStats
    /// Damage multipliers; 1 where none is listed.
    public var bonuses: [Bonus]
    /// What every player holds at the start of a match.
    public var startingResources: ResourceAmounts
    /// Workers each player begins with, beside the town centre.
    public var startingPeople: Int
    /// Workers who appear beside the town centre a founder builds, when it is
    /// finished (ruled 2026-11-22).
    public var founderPeople: Int
    /// How many troops a navy ship carries (requirement 16).
    public var shipCargo: Int
    /// The population limit can never exceed this, however many houses stand.
    public var populationMaximum: Int
    /// What a person's car does; nil for no car.
    public var car: CarStats?

    public init(units: [UnitStats], buildings: [BuildingStats], production: [ProductionStats], advances: [AdvanceStats],
                gathering: GatheringStats, bonuses: [Bonus], startingResources: ResourceAmounts, startingPeople: Int,
                founderPeople: Int = 2, shipCargo: Int = 20, populationMaximum: Int, car: CarStats? = nil) {
        self.units = units; self.buildings = buildings; self.production = production; self.advances = advances
        self.gathering = gathering; self.bonuses = bonuses
        self.startingResources = startingResources; self.startingPeople = startingPeople; self.founderPeople = founderPeople; self.shipCargo = shipCargo
        self.populationMaximum = populationMaximum; self.car = car
    }

    public func stats(_ kind: UnitKind) -> UnitStats { units.first { $0.kind == kind }! }
    public func stats(_ kind: BuildingKind) -> BuildingStats { buildings.first { $0.kind == kind }! }
    public func advance(from age: Age) -> AdvanceStats? { advances.first { $0.from == age } }

    /// How a maker makes a unit, if it does.
    public func production(of unit: UnitKind, at maker: EntityKind) -> ProductionStats? {
        production.first { $0.unit == unit && $0.maker == maker }
    }

    /// How a building makes a unit, if it does.
    public func production(of unit: UnitKind, at maker: BuildingKind) -> ProductionStats? {
        production(of: unit, at: .building(maker))
    }

    /// What a maker makes, in the order of `production.csv`.
    public func made(by maker: EntityKind) -> [ProductionStats] { production.filter { $0.maker == maker } }

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

    /// The standard tables: the package's default files (`TableTexts.defaults`)
    /// on `CatalogueShape.standard`. The defaults are checked by the tests, so a
    /// fault in them stops the program at once rather than playing on with a
    /// catalogue that is not the one intended.
    public static let standard: Catalogue = {
        do {
            return try Catalogue(tables: .defaults)
        } catch {
            preconditionFailure("the default tables do not load: \(error)")
        }
    }()
}
