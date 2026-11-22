// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Everything a player, human or computer, can tell the game to do. A human's
/// clicks and a computer player's decisions become the same orders, so that
/// both play by the same rules (requirement 22). Orders cross the network
/// unchanged in a later milestone, so they are Codable.
public enum Order: Hashable, Codable, Sendable {
    /// Walk to a point.
    case move(units: [EntityID], to: MapPosition)
    /// Workers gather at a site: fell a tree, hunt prey or mine gold; boats
    /// fish or mine gold in the water. They carry each load to the nearest
    /// town centre (boats to the nearest boat house).
    case gather(units: [EntityID], site: SiteID)
    /// Workers work at a building: they construct it, repair it, or tend it if
    /// it is a farm. Repair costs nothing; each worker restores
    /// `UnitStats.repairing` health points a second (requirement 12).
    case work(units: [EntityID], at: EntityID)
    /// Workers construct a new building with its footprint's origin at `at`.
    case construct(workers: [EntityID], building: BuildingKind, at: GridPoint)
    /// Workers pull down one of the player's own buildings, taking its
    /// `demolish_seconds` of work; the player receives its `demolish_return`
    /// share of its cost, and training or an advance under way there is
    /// cancelled and refunded.
    case demolish(workers: [EntityID], building: EntityID)
    /// Attack a unit or building that is not an ally's. A warfighter whose
    /// target is gone takes the nearest opponent in sight. Towers and town
    /// centres shoot units only.
    case attack(units: [EntityID], target: EntityID)
    /// Queue a unit for training at a maker: a building, or a navy ship.
    case train(at: EntityID, unit: UnitKind)
    /// Remove the last unit from a maker's queue, refunding its cost.
    case cancelTraining(at: EntityID)
    /// Begin the advance to the next age at one of the player's town centres,
    /// paying its cost; the player reaches the next age when the advance's
    /// time has passed there (requirement 6).
    case advanceAge(at: EntityID)
    /// Pause or resume the match for everyone (docs/requirements.md, "The match").
    /// Accepted from any human player, and accepted whilst paused.
    case setPaused(Bool)
    /// Stop whatever the units are doing.
    case stop(units: [EntityID])
    /// The player's own units leave the match at once, freeing their places;
    /// nothing is returned.
    case dismiss(units: [EntityID])
    /// Sow a farm that has run dry again, paying `GatheringStats.farmReseed`.
    case reseed(farm: EntityID)
    /// A person's car, made beside one of the player's town centres (ruled
    /// 2026-11-21); up to `CarStats.perPerson` each.
    case summonCar
    /// Turn the kill radius of the person's own cars on or off (ruled 2026-11-21).
    case setKillRadius(cars: [EntityID], on: Bool)
    /// Doctors heal a wounded unit of the player's up to its maximum health (requirement 13).
    case heal(doctors: [EntityID], target: EntityID)
    /// Troops (soldiers, knights and cannons) board a navy ship of the
    /// player's that is at the shore, as many as it has room for (requirement 16).
    case board(units: [EntityID], ship: EntityID)
    /// Navy ships sail to the shore near a point on land and land their troops there (requirement 16).
    case land(ships: [EntityID], at: MapPosition)
    /// A founder lays out a town centre, free, at `at`, and goes to build it
    /// (ruled 2026-11-22). When it is finished, `Catalogue.founderPeople`
    /// workers appear beside it and the founder becomes a worker.
    case found(founder: EntityID, at: GridPoint)
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
    /// Allies cannot attack one another, and some units cannot attack.
    case cannotAttack
    /// The match is over, or paused (every order but `setPaused` is refused whilst paused).
    case notNow

    public var description: String {
        switch self {
        case .notEnough(let short): "Not enough: \(short)"
        case .ageNotReached(let age): "Needs the age of \(age.name)"
        case .populationLimit: "Population limit reached; build a house"
        case .notYours: "Not yours to order"
        case .invalidTarget: "Cannot do that there"
        case .placementBlocked: "Cannot build there"
        case .cannotAttack: "Cannot attack that"
        case .notNow: "Not now"
        }
    }
}

public enum OrderResult: Hashable, Codable, Sendable {
    case accepted
    case refused(OrderRefusal)

    public var isAccepted: Bool { self == .accepted }
}
