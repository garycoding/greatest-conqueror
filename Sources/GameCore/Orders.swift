// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Everything a player, human or computer, can tell the game to do. A human's
/// clicks and a computer player's decisions become the same orders, so that
/// both play by the same rules (requirement 22). Orders cross the network
/// unchanged in a later milestone, so they are Codable.
public enum Order: Hashable, Codable, Sendable {
    /// Walk to a point.
    case move(units: [EntityID], to: MapPosition)
    /// Workers gather at a site: fell a tree, hunt prey, or mine a deposit.
    /// Copper and tin miners carry loads home like any other; on delivery each
    /// unit of copper ore pairs with a unit of tin ore to make one unit of
    /// bronze. Unpaired ore is held, unseen by the player, up to one load of
    /// each; ore beyond that is lost. So bronze is made only whilst both are
    /// mined (requirement 18).
    case gather(units: [EntityID], site: SiteID)
    /// Work at a building: workers tend a stock pen; engineers finish or repair
    /// it; scholars research where research is under way at that building, and
    /// otherwise, at a town centre, study toward the next age. Repair costs
    /// nothing and restores health at the rate of construction.
    case work(units: [EntityID], at: EntityID)
    /// Engineers construct a new building with its footprint's origin at `at`.
    case construct(engineers: [EntityID], building: BuildingKind, at: GridPoint)
    /// Engineers pull down one of the player's own buildings, taking half its
    /// construction time; the player receives half its cost, and training or
    /// research under way there is cancelled and refunded (requirement 28).
    case demolish(engineers: [EntityID], building: EntityID)
    /// Attack a person or building that is not an ally's. A warfighter whose
    /// target is gone takes the nearest opponent in sight. Towers and town
    /// centres shoot people only.
    case attack(units: [EntityID], target: EntityID)
    /// Queue a person for training at a building.
    case train(at: EntityID, unit: UnitKind)
    /// Remove the last person from a building's queue, refunding its cost.
    case cancelTraining(at: EntityID)
    /// Begin researching an improvement at a building; scholars working there
    /// carry it out.
    case research(at: EntityID, improvement: Improvement)
    /// Advance to the next age, once the scholars' study is complete; this pays
    /// the advance's cost (requirement 16).
    case advanceAge
    /// A founder builds a new town centre, free of cost, at `at`; it comes with
    /// `Catalogue.founderPeople` people, one an engineer and the rest workers, and the founder disappears (requirement 26).
    /// It takes effect when ordered; the founder need not walk there.
    case found(founder: EntityID, at: GridPoint)
    /// Pay to turn warfighters into the kind a later age brings, at a building
    /// that trains that kind (requirement 17; see `Catalogue.upgrades`).
    /// `UpgradeStats.time` applies to each warfighter, all of them at once,
    /// wherever each stands.
    case upgrade(units: [EntityID], to: UnitKind, at: EntityID)
    /// Pause or resume the match for everyone (docs/requirements.md, "The match").
    /// Accepted from any human player, and accepted whilst paused.
    case setPaused(Bool)
    /// Merchants trade at the nearest own town centre, turning the stock of
    /// `give` into `take` at `MerchantStats.exchangeRate`, until `give` runs out
    /// or they are given other work (requirement 15).
    case exchange(merchants: [EntityID], give: Resource, take: Resource)
    /// Merchants carry `resource` from the player's stock to an ally's building
    /// that accepts it, a load at a time, until the stock runs out or they are
    /// given other work (requirement 15).
    case carry(merchants: [EntityID], resource: Resource, to: EntityID)
    /// Stop whatever the units are doing.
    case stop(units: [EntityID])
    /// The player's own people leave the match at once, freeing their places;
    /// nothing is returned. A founder cannot be dismissed (requirement 30).
    case dismiss(units: [EntityID])
    /// Sow a farm that has run dry again, paying `GatheringStats.farmReseed`.
    case reseed(farm: EntityID)
    /// A person's car, made beside one of the player's town centres (ruled
    /// 2026-11-21); up to `CarStats.perPerson` each.
    case summonCar
    /// Turn the kill radius of the person's own cars on or off (ruled 2026-11-21).
    case setKillRadius(cars: [EntityID], on: Bool)
    /// Engineers build a bridge in a straight line from the land tile `from` to
    /// the land tile `to`, one piece on each water tile between, paying for every
    /// piece at once; they build from the `from` bank outwards (ruled 2026-11-21).
    case buildBridge(engineers: [EntityID], from: GridPoint, to: GridPoint)
}

/// Why an order was refused. The interface shows it to the player.
public enum OrderRefusal: Hashable, Codable, Sendable, CustomStringConvertible {
    /// The player lacks these resources.
    case notEnough(ResourceAmounts)
    /// The player has not reached the age the order needs.
    case ageNotReached(Age)
    /// The population limit is reached.
    case populationLimit
    /// Not every entity named belongs to the player, or none of them can carry it out.
    case notYours
    /// The target cannot be acted on in this way.
    case invalidTarget
    /// The building cannot stand there.
    case placementBlocked
    /// Allies cannot attack one another (requirement 6), and founders cannot attack.
    case cannotAttack
    /// The scholars' study is not yet complete.
    case studyIncomplete
    /// The match is over, or paused (every order but `setPaused` is refused whilst paused).
    case notNow

    public var description: String {
        switch self {
        case .notEnough(let short): "Not enough: \(short)"
        case .ageNotReached(let age): "Needs the \(age.name) age"
        case .populationLimit: "Population limit reached; build a house"
        case .notYours: "Not yours to order"
        case .invalidTarget: "Cannot do that there"
        case .placementBlocked: "Cannot build there"
        case .cannotAttack: "Cannot attack that"
        case .studyIncomplete: "The scholars have not finished their study"
        case .notNow: "Not now"
        }
    }
}

public enum OrderResult: Hashable, Codable, Sendable {
    case accepted
    case refused(OrderRefusal)

    public var isAccepted: Bool { self == .accepted }
}
