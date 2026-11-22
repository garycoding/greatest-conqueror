// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// The tables of the game: what everything costs, how strong it is, and how long
// it takes. The simulation, the interface and the computer player all read these
// values, so they live here. They are first estimates, to be tuned by play;
// every duration is in ticks (see `Tick`).

/// How a person attacks.
public struct Attack: Hashable, Codable, Sendable {
    /// Harm per blow, before armour.
    public var damage: Int
    /// Reach in tiles; 1 or less is a melee attack.
    public var range: Double
    /// Ticks between blows.
    public var interval: Int
    /// The radius in tiles within which a blow also harms the target's
    /// neighbours (the catapult's stone); `nil` for a blow that harms the target
    /// alone. Optional so that saves made before it existed still open.
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
    /// Ticks of one engineer's work to construct it; more engineers finish sooner.
    public var buildTime: Int
    public var health: Int
    public var armour: Int
    /// The tiles it covers, from its origin tile toward +x and +y.
    public var footprint: GridPoint
    public var sight: Double
    /// Towers and the town centre shoot at opponents in range.
    public var attack: Attack?
    /// Population places it provides.
    public var housing: Int
    /// Resources that workers may deliver here.
    public var accepts: [Resource]
    /// What may be trained here.
    public var trains: [UnitKind]
    /// What may be researched here.
    public var researches: [Improvement]

    public init(kind: BuildingKind, age: Age, cost: ResourceAmounts, buildTime: Int, health: Int, armour: Int,
                footprint: GridPoint, sight: Double, attack: Attack? = nil, housing: Int = 0,
                accepts: [Resource] = [], trains: [UnitKind] = [], researches: [Improvement] = []) {
        self.kind = kind; self.age = age; self.cost = cost; self.buildTime = buildTime; self.health = health
        self.armour = armour; self.footprint = footprint; self.sight = sight; self.attack = attack
        self.housing = housing; self.accepts = accepts; self.trains = trains; self.researches = researches
    }
}

public struct ImprovementStats: Hashable, Codable, Sendable {
    public var improvement: Improvement
    public var age: Age
    public var cost: ResourceAmounts
    /// Scholar-ticks of work: one scholar takes this many ticks, two take half.
    public var work: Int
    /// Workers take this many times as much from a site in the same time
    /// (herding excepted); the effects of several improvements multiply.
    public var gatheringMultiplier: Double
    /// Added to the damage of each blow a warfighter strikes.
    public var warfighterDamage: Int
    /// Added to the armour of each warfighter.
    public var warfighterArmour: Int
    /// A farm yields this many times as much; optional so that older saves open.
    public var farmingMultiplier: Double?
    /// A workshop makes this many times as much gunpowder; optional so that older saves open.
    public var productionMultiplier: Double?
    /// Merchants' exchanges give this many times as much; optional so that older saves open.
    public var exchangeMultiplier: Double?
    /// Oil wells pump this many times as much; optional so that older saves open.
    public var pumpingMultiplier: Double?

    public init(improvement: Improvement, age: Age, cost: ResourceAmounts, work: Int,
                gatheringMultiplier: Double = 1, warfighterDamage: Int = 0, warfighterArmour: Int = 0,
                farmingMultiplier: Double? = nil, productionMultiplier: Double? = nil, exchangeMultiplier: Double? = nil,
                pumpingMultiplier: Double? = nil) {
        self.pumpingMultiplier = pumpingMultiplier
        self.improvement = improvement; self.age = age; self.cost = cost; self.work = work
        self.gatheringMultiplier = gatheringMultiplier; self.warfighterDamage = warfighterDamage
        self.warfighterArmour = warfighterArmour; self.farmingMultiplier = farmingMultiplier
        self.productionMultiplier = productionMultiplier; self.exchangeMultiplier = exchangeMultiplier
    }
}

/// What it takes to leave an age for the next (requirement 16).
public struct AdvanceStats: Hashable, Codable, Sendable {
    public var from: Age
    /// Paid when the advance is completed.
    public var cost: ResourceAmounts
    /// Scholar-ticks of study needed: progress accumulates whilst scholars work at
    /// a town centre, one point per scholar per tick.
    public var study: Int

    public init(from: Age, cost: ResourceAmounts, study: Int) {
        self.from = from; self.cost = cost; self.study = study
    }
}

/// Gathering rates and loads. Tables are arrays indexed by `SiteKind.rawValue`,
/// not dictionaries, so that they encode identically in every process.
public struct GatheringStats: Hashable, Codable, Sendable {
    /// Units of the resource a worker takes from a site per second, by site kind.
    public var perSecondBySite: [Double]
    /// Food per second a worker earns tending a stock pen (herds, Bronze age).
    public var herdingPerSecond: Double
    /// Food per second a worker earns tending a farm (Iron age), before the
    /// plough; optional so that older saves open, and then no farm yields.
    public var farmingPerSecond: Double?
    /// The food a farm yields before it runs dry and must be reseeded (ruled
    /// 2026-11-19); optional so that older saves open, and then a farm never runs dry.
    public var farmYield: Int?
    /// What reseeding a farm that has run dry costs.
    public var farmReseed: ResourceAmounts?
    /// How much a worker carries before returning to deliver it.
    public var load: Int
    /// What each kind of site holds when the map is made, by site kind.
    public var amountBySite: [Int]

    public init(perSecond: [SiteKind: Double], herdingPerSecond: Double, farmingPerSecond: Double? = nil,
                farmYield: Int? = nil, farmReseed: ResourceAmounts? = nil, load: Int, siteAmount: [SiteKind: Int]) {
        self.farmYield = farmYield; self.farmReseed = farmReseed
        perSecondBySite = SiteKind.allCases.map { perSecond[$0] ?? 0 }
        amountBySite = SiteKind.allCases.map { siteAmount[$0] ?? 0 }
        self.herdingPerSecond = herdingPerSecond; self.farmingPerSecond = farmingPerSecond; self.load = load
    }

    /// A kind newer than a saved table (fish, 2026-11-21) takes the standard figure.
    public func perSecond(_ kind: SiteKind) -> Double {
        kind.rawValue < perSecondBySite.count ? perSecondBySite[kind.rawValue] : Catalogue.standard.gathering.perSecond(kind)
    }
    public func amount(_ kind: SiteKind) -> Int {
        kind.rawValue < amountBySite.count ? amountBySite[kind.rawValue] : Catalogue.standard.gathering.amount(kind)
    }
}

/// How the alchemist's workshop makes gunpowder (ruled 2026-11-19): up to
/// `workers` craftsmen work there, each turning `woodPerUnit` wood into one
/// gunpowder at `perSecond` a second while the stock holds the wood.
public struct WorkshopStats: Hashable, Codable, Sendable {
    public var perSecond: Double
    public var woodPerUnit: Int
    public var workers: Int

    public init(perSecond: Double, woodPerUnit: Int, workers: Int) {
        self.perSecond = perSecond; self.woodPerUnit = woodPerUnit; self.workers = workers
    }
}

/// How an oil well pumps (ruled 2026-11-19): standing on an oil field, it
/// pumps `perSecond` oil a second into its owner's stock, without workers,
/// until the fields beneath it are empty.
public struct OilWellStats: Hashable, Codable, Sendable {
    public var perSecond: Double

    public init(perSecond: Double) { self.perSecond = perSecond }
}

/// The railway between a player's depots (ruled 2026-11-19): people board at
/// one depot and come out at another `journeyTime` ticks later, whatever the
/// distance; merchants carrying to an ally ride from the player's depot to the
/// ally's in the same time.
public struct RailwayStats: Hashable, Codable, Sendable {
    public var journeyTime: Int

    public init(journeyTime: Int) { self.journeyTime = journeyTime }
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

    private enum CodingKeys: String, CodingKey { case killRadius, perPerson, laserRange, laserTime }

    /// A car saved before the laser, or before five cars, opens with the standard ones.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        killRadius = try c.decode(Double.self, forKey: .killRadius)
        perPerson = try c.decodeIfPresent(Int.self, forKey: .perPerson) ?? 5
        laserRange = try c.decodeIfPresent(Double.self, forKey: .laserRange) ?? 8
        laserTime = try c.decodeIfPresent(Int.self, forKey: .laserTime) ?? 4 * Tick.rate
    }
}

/// A bridge's limits (ruled 2026-11-21): it crosses at most `maxWater` water
/// tiles, one bridge piece (`BuildingKind.bridge`) on each.
public enum BridgeRule {
    public static let maxWater = 16
}

/// How merchants trade: at a town centre a merchant takes `exchangePerSecond`
/// of one resource from the stock each second and adds `exchangeRate` as much
/// of another; carrying to an ally, a merchant takes `load` at a time.
public struct MerchantStats: Hashable, Codable, Sendable {
    public var exchangePerSecond: Double
    public var exchangeRate: Double
    public var load: Int

    public init(exchangePerSecond: Double, exchangeRate: Double, load: Int) {
        self.exchangePerSecond = exchangePerSecond; self.exchangeRate = exchangeRate; self.load = load
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

/// Paying to turn warfighters of one kind into the kind a later age brings
/// (requirement 17). Done at a building that trains the new kind.
public struct UpgradeStats: Hashable, Codable, Sendable {
    public var from: UnitKind
    public var to: UnitKind
    /// Per warfighter upgraded.
    public var cost: ResourceAmounts
    public var time: Int
    public init(from: UnitKind, to: UnitKind, cost: ResourceAmounts, time: Int) {
        self.from = from; self.to = to; self.cost = cost; self.time = time
    }
}

/// All the tables of the game.
public struct Catalogue: Hashable, Codable, Sendable {
    public var units: [UnitStats]
    public var buildings: [BuildingStats]
    public var improvements: [ImprovementStats]
    public var advances: [AdvanceStats]
    public var gathering: GatheringStats
    /// Damage multipliers; 1 where none is listed.
    public var bonuses: [Bonus]
    public var upgrades: [UpgradeStats]
    /// What every player holds at the start of a match.
    public var startingResources: ResourceAmounts
    /// People each player begins with, beside the town centre: one engineer,
    /// so that a house can always be built, and the rest workers.
    public var startingPeople: Int
    /// The population limit can never exceed this, however many houses stand.
    public var populationMaximum: Int
    /// Workers that come with a town centre built by a founder, who becomes an
    /// engineer, so that a house can be built (requirement 26, ruled 2026-11-21).
    public var founderPeople: Int
    /// What merchants do (requirement 15, "Sectors"); optional so that saves
    /// made before merchants traded still open, and then they cannot.
    public var merchants: MerchantStats?
    /// How the alchemist's workshop makes gunpowder; optional so that older saves open.
    public var workshop: WorkshopStats?
    /// How an oil well pumps; optional so that older saves open.
    public var oilWell: OilWellStats?
    /// How the railway carries people between depots; optional so that older saves open.
    public var railway: RailwayStats?
    /// What a person's car does; optional so that older saves open, and then there is no car.
    public var car: CarStats?

    public init(units: [UnitStats], buildings: [BuildingStats], improvements: [ImprovementStats],
                advances: [AdvanceStats], gathering: GatheringStats, bonuses: [Bonus], upgrades: [UpgradeStats],
                startingResources: ResourceAmounts, startingPeople: Int, populationMaximum: Int, founderPeople: Int, merchants: MerchantStats? = nil, workshop: WorkshopStats? = nil,
                oilWell: OilWellStats? = nil, railway: RailwayStats? = nil, car: CarStats? = nil) {
        self.workshop = workshop; self.oilWell = oilWell; self.railway = railway; self.car = car
        self.merchants = merchants
        self.units = units; self.buildings = buildings; self.improvements = improvements; self.advances = advances
        self.gathering = gathering; self.bonuses = bonuses; self.upgrades = upgrades
        self.startingResources = startingResources; self.startingPeople = startingPeople
        self.populationMaximum = populationMaximum; self.founderPeople = founderPeople
    }

    public func stats(_ kind: UnitKind) -> UnitStats { units.first { $0.kind == kind }! }
    public func stats(_ kind: BuildingKind) -> BuildingStats { buildings.first { $0.kind == kind }! }
    public func stats(_ improvement: Improvement) -> ImprovementStats { improvements.first { $0.improvement == improvement }! }
    public func advance(from age: Age) -> AdvanceStats? { advances.first { $0.from == age } }

    /// The last age a player can reach with these tables: the interface offers
    /// nothing of a later age, whose units and buildings may be listed before
    /// the rules that bring them are built.
    public var lastAge: Age {
        var age = Age.stone
        while advance(from: age) != nil, let next = Age(rawValue: age.rawValue + 1) { age = next }
        return age
    }

    /// The damage multiplier when `attacker` strikes `defender`.
    public func bonus(_ attacker: UnitKind, against defender: UnitKind) -> Double {
        bonuses.first { $0.attacker == attacker && $0.defender == defender }?.multiplier ?? 1
    }

    /// The upgrade available for a kind, if any.
    public func upgrade(from kind: UnitKind) -> UpgradeStats? { upgrades.first { $0.from == kind } }

    /// The tables of the first milestone: the Stone and Bronze ages.
    public static let standard: Catalogue = {
        func cost(_ pairs: [Resource: Int]) -> ResourceAmounts { ResourceAmounts(pairs) }
        let s = Tick.seconds
        let units: [UnitStats] = [
            UnitStats(kind: .worker, age: .stone, cost: cost([.food: 50]), trainTime: s(12), health: 25, armour: 0,
                      speed: 1.0, sight: 4, attack: Attack(damage: 3, range: 1, interval: s(1.5)), trainedAt: [.townCentre]),
            UnitStats(kind: .scholar, age: .stone, cost: cost([.food: 60]), trainTime: s(15), health: 20, armour: 0,
                      speed: 0.9, sight: 4, attack: nil, trainedAt: [.townCentre]),
            UnitStats(kind: .engineer, age: .stone, cost: cost([.food: 50, .wood: 10]), trainTime: s(12), health: 25, armour: 0,
                      speed: 1.0, sight: 4, attack: Attack(damage: 2, range: 1, interval: s(1.5)), trainedAt: [.townCentre]),
            UnitStats(kind: .merchant, age: .bronze, cost: cost([.food: 50, .gold: 20]), trainTime: s(15), health: 30, armour: 0,
                      speed: 1.3, sight: 5, attack: nil, trainedAt: [.townCentre]),
            UnitStats(kind: .founder, age: .stone, cost: cost([:]), trainTime: 0, health: 1, armour: 0,
                      speed: 1.2, sight: 5, attack: nil, trainedAt: [], population: 0),
            // A person's car (ruled 2026-11-21): free, outside the population, twice a worker's speed.
            UnitStats(kind: .car, age: .stone, cost: cost([:]), trainTime: 0, health: 1, armour: 0,
                      speed: 2.0, sight: 8, attack: nil, trainedAt: [], population: 0),
            // A boat (ruled 2026-11-21): on the water only, a worker's speed, health and load.
            UnitStats(kind: .boat, age: .stone, cost: cost([.wood: 50]), trainTime: s(15), health: 25, armour: 0,
                      speed: 1.0, sight: 5, attack: nil, trainedAt: [.boatHouse]),
            UnitStats(kind: .clubman, age: .stone, cost: cost([.food: 50, .wood: 10]), trainTime: s(12), health: 40, armour: 0,
                      speed: 1.1, sight: 5, attack: Attack(damage: 4, range: 1, interval: s(1.5)), trainedAt: [.townCentre, .barracks]),
            UnitStats(kind: .slinger, age: .stone, cost: cost([.food: 40, .stone: 15]), trainTime: s(12), health: 28, armour: 0,
                      speed: 1.1, sight: 6, attack: Attack(damage: 3, range: 4, interval: s(2)), trainedAt: [.townCentre, .barracks]),
            UnitStats(kind: .spearman, age: .bronze, cost: cost([.food: 60, .bronze: 20]), trainTime: s(14), health: 55, armour: 1,
                      speed: 1.0, sight: 5, attack: Attack(damage: 5, range: 1, interval: s(1.5)), trainedAt: [.barracks]),
            UnitStats(kind: .archer, age: .bronze, cost: cost([.wood: 40, .gold: 20]), trainTime: s(14), health: 35, armour: 0,
                      speed: 1.1, sight: 7, attack: Attack(damage: 4, range: 6, interval: s(2)), trainedAt: [.barracks]),
            UnitStats(kind: .chariot, age: .bronze, cost: cost([.food: 60, .wood: 60, .bronze: 20]), trainTime: s(20), health: 100,
                      armour: 1, speed: 2.0, sight: 6, attack: Attack(damage: 6, range: 1, interval: s(1.5)), trainedAt: [.barracks],
                      population: 2),
            // The Iron age's warfighters. Their figures are provisional until the Iron age's rules are built.
            UnitStats(kind: .swordsman, age: .iron, cost: cost([.food: 60, .iron: 25]), trainTime: s(14), health: 70, armour: 2,
                      speed: 1.0, sight: 5, attack: Attack(damage: 7, range: 1, interval: s(1.5)), trainedAt: [.barracks]),
            UnitStats(kind: .horseman, age: .iron, cost: cost([.food: 80, .iron: 20]), trainTime: s(18), health: 90, armour: 1,
                      speed: 2.2, sight: 7, attack: Attack(damage: 7, range: 1, interval: s(1.4)), trainedAt: [.stable],
                      population: 2),
            UnitStats(kind: .catapult, age: .iron, cost: cost([.wood: 150, .iron: 40]), trainTime: s(30), health: 120, armour: 1,
                      speed: 0.6, sight: 8, attack: Attack(damage: 20, range: 9, interval: s(5), area: 1.5), trainedAt: [.siegeWorkshop],
                      population: 3),
            // The Alchemy age's warfighters. Their figures are provisional until the Alchemy age's rules are built.
            UnitStats(kind: .knight, age: .alchemy, cost: cost([.food: 100, .gold: 60]), trainTime: s(20), health: 130, armour: 3,
                      speed: 2.0, sight: 7, attack: Attack(damage: 10, range: 1, interval: s(1.5)), trainedAt: [.stable, .castle],
                      population: 2),
            UnitStats(kind: .musketeer, age: .alchemy, cost: cost([.food: 60, .gunpowder: 30]), trainTime: s(16), health: 60,
                      armour: 1, speed: 1.0, sight: 7, attack: Attack(damage: 12, range: 6, interval: s(3)),
                      trainedAt: [.barracks, .castle]),
            UnitStats(kind: .cannon, age: .alchemy, cost: cost([.wood: 120, .iron: 80, .gunpowder: 60]), trainTime: s(35),
                      health: 160, armour: 2, speed: 0.6, sight: 9, attack: Attack(damage: 30, range: 10, interval: s(5), area: 1.5),
                      trainedAt: [.siegeWorkshop, .castle], population: 3),
            // The Industrial age's warfighters. Their figures are provisional until the Industrial age's rules are built.
            UnitStats(kind: .rifleman, age: .industrial, cost: cost([.food: 60, .gold: 20, .gunpowder: 20]), trainTime: s(16),
                      health: 70, armour: 1, speed: 1.1, sight: 8, attack: Attack(damage: 14, range: 7, interval: s(2.5)),
                      trainedAt: [.barracks]),
            UnitStats(kind: .fieldGun, age: .industrial, cost: cost([.iron: 100, .gunpowder: 60, .oil: 20]), trainTime: s(35),
                      health: 180, armour: 2, speed: 0.8, sight: 10, attack: Attack(damage: 32, range: 12, interval: s(5), area: 1.5),
                      trainedAt: [.factory], population: 3),
            UnitStats(kind: .armouredCar, age: .industrial, cost: cost([.iron: 120, .gold: 40, .oil: 60]), trainTime: s(30),
                      health: 220, armour: 5, speed: 2.4, sight: 8, attack: Attack(damage: 12, range: 4, interval: s(1.5)),
                      trainedAt: [.factory], population: 3),
        ]
        let allStone: [Resource] = [.food, .wood, .stone, .bronze, .gold, .iron, .gunpowder]
        let buildings: [BuildingStats] = [
            BuildingStats(kind: .townCentre, age: .stone, cost: cost([.wood: 200, .stone: 100]), buildTime: s(120), health: 1200,
                          armour: 2, footprint: GridPoint(3, 3), sight: 8, attack: Attack(damage: 3, range: 6, interval: s(2)),
                          housing: 5, accepts: allStone, trains: [.worker, .scholar, .engineer, .merchant, .clubman, .slinger],
                          researches: [.betterTools, .ironTools, .guilds, .banking, .machineTools]),
            BuildingStats(kind: .house, age: .stone, cost: cost([.wood: 30]), buildTime: s(20), health: 200, armour: 0,
                          footprint: GridPoint(2, 2), sight: 3, housing: 5),
            BuildingStats(kind: .storagePit, age: .stone, cost: cost([.wood: 50]), buildTime: s(25), health: 300, armour: 0,
                          footprint: GridPoint(2, 2), sight: 3, accepts: [.wood, .stone, .bronze, .gold, .iron]),
            BuildingStats(kind: .stockPen, age: .bronze, cost: cost([.wood: 60]), buildTime: s(25), health: 250, armour: 0,
                          footprint: GridPoint(3, 3), sight: 3, accepts: [.food]),
            BuildingStats(kind: .barracks, age: .bronze, cost: cost([.wood: 100]), buildTime: s(40), health: 500, armour: 1,
                          footprint: GridPoint(3, 3), sight: 4, trains: [.clubman, .slinger, .spearman, .archer, .chariot, .swordsman, .musketeer, .rifleman],
                          researches: [.bronzeWeapons, .shields, .ironWeapons, .mail]),
            BuildingStats(kind: .watchTower, age: .bronze, cost: cost([.stone: 80, .wood: 20]), buildTime: s(40), health: 400,
                          armour: 2, footprint: GridPoint(1, 1), sight: 9, attack: Attack(damage: 4, range: 7, interval: s(2))),
            BuildingStats(kind: .palisade, age: .bronze, cost: cost([.wood: 3]), buildTime: s(4), health: 150, armour: 1,
                          footprint: GridPoint(1, 1), sight: 1),
            // One water tile's piece of a bridge (ruled 2026-11-21); the cost is for each piece.
            BuildingStats(kind: .bridge, age: .stone, cost: cost([.wood: 10]), buildTime: s(6), health: 150, armour: 1,
                          footprint: GridPoint(1, 1), sight: 1),
            // A boat house on the shore (ruled 2026-11-21): it trains boats and takes in their loads.
            BuildingStats(kind: .boatHouse, age: .stone, cost: cost([.wood: 100]), buildTime: s(30), health: 300, armour: 0,
                          footprint: GridPoint(2, 2), sight: 4, accepts: [.food, .stone, .bronze, .gold, .iron],
                          trains: [.boat]),
            // The Iron age's buildings. Their figures are provisional until the Iron age's rules are built.
            BuildingStats(kind: .farm, age: .iron, cost: cost([.wood: 60]), buildTime: s(20), health: 150, armour: 0,
                          footprint: GridPoint(3, 3), sight: 2, researches: [.plough]),
            BuildingStats(kind: .stable, age: .iron, cost: cost([.wood: 120]), buildTime: s(45), health: 500, armour: 1,
                          footprint: GridPoint(3, 3), sight: 4, trains: [.horseman, .knight]),
            BuildingStats(kind: .siegeWorkshop, age: .iron, cost: cost([.wood: 150, .stone: 50]), buildTime: s(50), health: 600,
                          armour: 1, footprint: GridPoint(3, 3), sight: 4, trains: [.catapult, .cannon]),
            BuildingStats(kind: .stoneWall, age: .iron, cost: cost([.stone: 5]), buildTime: s(6), health: 400, armour: 3,
                          footprint: GridPoint(1, 1), sight: 1),
            // The Alchemy age's buildings. Their figures are provisional until the Alchemy age's rules are built.
            BuildingStats(kind: .castle, age: .alchemy, cost: cost([.stone: 600, .wood: 200]), buildTime: s(150), health: 3000,
                          armour: 4, footprint: GridPoint(4, 4), sight: 10, attack: Attack(damage: 8, range: 8, interval: s(2)),
                          housing: 10, trains: [.knight, .musketeer, .cannon], researches: [.betterPowder, .plateArmour]),
            BuildingStats(kind: .alchemistsWorkshop, age: .alchemy, cost: cost([.wood: 150, .stone: 100, .gold: 50]),
                          buildTime: s(50), health: 600, armour: 1, footprint: GridPoint(3, 3), sight: 4),
            // The Industrial age's buildings. Their figures are provisional until the Industrial age's rules are built.
            BuildingStats(kind: .factory, age: .industrial, cost: cost([.wood: 150, .stone: 100, .iron: 150]), buildTime: s(70),
                          health: 900, armour: 2, footprint: GridPoint(3, 3), sight: 4, trains: [.fieldGun, .armouredCar],
                          researches: [.rifling, .steelPlate, .refining]),
            BuildingStats(kind: .railwayDepot, age: .industrial, cost: cost([.wood: 120, .stone: 50, .iron: 80]), buildTime: s(50),
                          health: 600, armour: 1, footprint: GridPoint(3, 3), sight: 5),
            BuildingStats(kind: .oilWell, age: .industrial, cost: cost([.wood: 80, .iron: 40]), buildTime: s(30), health: 300,
                          armour: 1, footprint: GridPoint(2, 2), sight: 3),
        ]
        let improvements: [ImprovementStats] = [
            ImprovementStats(improvement: .betterTools, age: .stone, cost: cost([.food: 80, .wood: 60]), work: s(40),
                             gatheringMultiplier: 1.2),
            ImprovementStats(improvement: .bronzeWeapons, age: .bronze, cost: cost([.food: 100, .bronze: 60]), work: s(60),
                             warfighterDamage: 1),
            ImprovementStats(improvement: .shields, age: .bronze, cost: cost([.wood: 80, .bronze: 40]), work: s(60),
                             warfighterArmour: 1),
            ImprovementStats(improvement: .ironTools, age: .iron, cost: cost([.food: 150, .iron: 80]), work: s(70),
                             gatheringMultiplier: 1.2),
            ImprovementStats(improvement: .ironWeapons, age: .iron, cost: cost([.food: 150, .iron: 100]), work: s(80),
                             warfighterDamage: 2),
            ImprovementStats(improvement: .mail, age: .iron, cost: cost([.gold: 60, .iron: 100]), work: s(80),
                             warfighterArmour: 1),
            ImprovementStats(improvement: .plough, age: .iron, cost: cost([.wood: 120, .iron: 60]), work: s(60),
                             farmingMultiplier: 1.25),
            ImprovementStats(improvement: .betterPowder, age: .alchemy, cost: cost([.gold: 150, .gunpowder: 100]), work: s(90),
                             warfighterDamage: 2),
            ImprovementStats(improvement: .plateArmour, age: .alchemy, cost: cost([.iron: 200, .gold: 100]), work: s(90),
                             warfighterArmour: 2),
            ImprovementStats(improvement: .guilds, age: .alchemy, cost: cost([.food: 250, .gold: 150]), work: s(80),
                             gatheringMultiplier: 1.15, productionMultiplier: 1.25),
            ImprovementStats(improvement: .banking, age: .alchemy, cost: cost([.gold: 200]), work: s(70),
                             exchangeMultiplier: 1.25),
            ImprovementStats(improvement: .machineTools, age: .industrial, cost: cost([.food: 300, .iron: 150]), work: s(90),
                             gatheringMultiplier: 1.15, productionMultiplier: 1.2),
            ImprovementStats(improvement: .rifling, age: .industrial, cost: cost([.iron: 150, .gunpowder: 100]), work: s(100),
                             warfighterDamage: 3),
            ImprovementStats(improvement: .steelPlate, age: .industrial, cost: cost([.iron: 250, .oil: 50]), work: s(100),
                             warfighterArmour: 2),
            ImprovementStats(improvement: .refining, age: .industrial, cost: cost([.gold: 150, .oil: 80]), work: s(80),
                             pumpingMultiplier: 1.5),
        ]
        let advances: [AdvanceStats] = [
            AdvanceStats(from: .stone, cost: cost([.food: 300, .wood: 100]), study: s(4 * 90)),
            AdvanceStats(from: .bronze, cost: cost([.food: 500, .bronze: 150, .gold: 100]), study: s(4 * 150)),
            AdvanceStats(from: .iron, cost: cost([.food: 800, .iron: 200, .gold: 200]), study: s(4 * 200)),
            AdvanceStats(from: .alchemy, cost: cost([.food: 1000, .iron: 300, .gold: 300, .gunpowder: 150]), study: s(4 * 250)),
        ]
        let gathering = GatheringStats(
            perSecond: [.tree: 0.6, .prey: 0.8, .stone: 0.5, .copper: 0.4, .tin: 0.4, .gold: 0.4, .iron: 0.4, .oilField: 0,
                        .fish: 0.7],
            herdingPerSecond: 0.7,
            farmingPerSecond: 0.9,
            farmYield: 300,
            farmReseed: cost([.wood: 60]),
            load: 10,
            siteAmount: [.tree: 100, .prey: 150, .stone: 300, .copper: 500, .tin: 500, .gold: 400, .iron: 500, .oilField: 2000,
                         .fish: 200]
        )
        let bonuses: [Bonus] = [
            Bonus(.spearman, against: .chariot, 3),
            Bonus(.chariot, against: .archer, 2), Bonus(.chariot, against: .slinger, 2),
            Bonus(.archer, against: .spearman, 1.5), Bonus(.archer, against: .clubman, 1.5),
            Bonus(.clubman, against: .slinger, 1.5),
            Bonus(.swordsman, against: .spearman, 1.5), Bonus(.swordsman, against: .clubman, 1.5),
            Bonus(.horseman, against: .archer, 2), Bonus(.horseman, against: .slinger, 2), Bonus(.horseman, against: .catapult, 3),
            Bonus(.spearman, against: .horseman, 3),
            Bonus(.archer, against: .swordsman, 1.5),
            Bonus(.knight, against: .swordsman, 1.5), Bonus(.knight, against: .archer, 1.5), Bonus(.knight, against: .musketeer, 1.5),
            Bonus(.spearman, against: .knight, 2.5),
            Bonus(.musketeer, against: .knight, 2), Bonus(.musketeer, against: .swordsman, 1.5),
            Bonus(.rifleman, against: .knight, 2), Bonus(.rifleman, against: .musketeer, 1.5), Bonus(.rifleman, against: .swordsman, 1.5),
            Bonus(.fieldGun, against: .rifleman, 1.5), Bonus(.fieldGun, against: .musketeer, 1.5), Bonus(.fieldGun, against: .armouredCar, 2),
            Bonus(.armouredCar, against: .rifleman, 2), Bonus(.armouredCar, against: .musketeer, 2), Bonus(.armouredCar, against: .cannon, 2),
        ]
        let upgrades: [UpgradeStats] = [
            UpgradeStats(from: .clubman, to: .spearman, cost: cost([.food: 20, .bronze: 15]), time: s(6)),
            UpgradeStats(from: .slinger, to: .archer, cost: cost([.wood: 20, .gold: 15]), time: s(6)),
            UpgradeStats(from: .spearman, to: .swordsman, cost: cost([.food: 20, .iron: 20]), time: s(6)),
            UpgradeStats(from: .chariot, to: .horseman, cost: cost([.food: 30, .iron: 15]), time: s(8)),
            UpgradeStats(from: .swordsman, to: .musketeer, cost: cost([.food: 20, .gunpowder: 20]), time: s(8)),
            UpgradeStats(from: .horseman, to: .knight, cost: cost([.food: 40, .gold: 30]), time: s(10)),
            UpgradeStats(from: .catapult, to: .cannon, cost: cost([.iron: 40, .gunpowder: 40]), time: s(12)),
            UpgradeStats(from: .musketeer, to: .rifleman, cost: cost([.iron: 20, .gunpowder: 15]), time: s(8)),
            UpgradeStats(from: .cannon, to: .fieldGun, cost: cost([.iron: 60, .oil: 15]), time: s(12)),
            UpgradeStats(from: .knight, to: .armouredCar, cost: cost([.iron: 80, .oil: 40]), time: s(14)),
        ]
        return Catalogue(units: units, buildings: buildings, improvements: improvements, advances: advances,
                         gathering: gathering, bonuses: bonuses, upgrades: upgrades,
                         startingResources: cost([.food: 200, .wood: 200, .stone: 50]),
                         startingPeople: 3, populationMaximum: 200, founderPeople: 2,
                         merchants: MerchantStats(exchangePerSecond: 1, exchangeRate: 2.0 / 3.0, load: 20),
                         workshop: WorkshopStats(perSecond: 0.5, woodPerUnit: 2, workers: 3),
                         oilWell: OilWellStats(perSecond: 0.5),
                         railway: RailwayStats(journeyTime: s(5)),
                         car: CarStats(killRadius: 11))
    }()
}
