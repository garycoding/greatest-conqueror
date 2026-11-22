// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// The kinds of unit (docs/requirements.md, requirements 12 to 20). Workers,
/// doctors and fishing boats are one kind each in every age; soldiers, knights
/// and cannons come in tiers, each a kind of its own (requirement 19). The
/// founder and the car are made by no maker and are not units (ruled
/// 2026-11-22): neither keeps a player in the match.
public enum UnitKind: Int, CaseIterable, Codable, Sendable, Hashable {
    /// Gathers, hunts, farms, cuts wood, mines gold, builds, repairs and demolishes.
    case worker
    /// Heals wounded units of its player (requirement 13).
    case doctor
    /// A fishing boat (requirement 14): made at a boathouse, it moves only on
    /// water and catches fish and mines gold there.
    case fishingBoat
    /// Soldiers 1 to 4.
    case soldier1, soldier2, soldier3, soldier4
    /// Knights 1 to 3.
    case knight1, knight2, knight3
    /// Cannons 1 and 2.
    case cannon1, cannon2
    /// A navy ship (requirements 16 and 18): made at a boathouse, it moves on
    /// water, carries troops, attacks with built-in cannons and, from the age
    /// of hospitals, makes soldiers, knights and cannons at the shore.
    case navyShip
    /// A person's car (ruled 2026-11-21): made with Shift-C; it cannot be
    /// harmed, and every enemy unit within `CarStats.killRadius` dies at once.
    case car
    /// A person's founder (ruled 2026-11-22): given to a person who has lost
    /// every worker and town centre whilst a teammate stands; it cannot be
    /// harmed or attack, and builds one town centre free.
    case founder

    /// A soldier, knight or cannon: the troops, which attack, come in tiers and
    /// may board a navy ship (requirements 15, 16 and 19).
    public var isWarfighter: Bool {
        switch self {
        case .worker, .doctor, .fishingBoat, .navyShip, .car, .founder: false
        case .soldier1, .soldier2, .soldier3, .soldier4, .knight1, .knight2, .knight3, .cannon1, .cannon2: true
        }
    }

    /// Whether the kind moves on water only: the fishing boat and the navy ship.
    public var isAfloat: Bool { self == .fishingBoat || self == .navyShip }

    /// Whether the kind is a unit (ruled 2026-11-22): anything that moves but
    /// the car and the founder.
    public var isUnit: Bool { self != .car && self != .founder }

    /// Whether the kind keeps the look of the age in which it first appears,
    /// rather than taking its owner's: the tiers, the navy ship, the car and the founder.
    public var keepsItsLook: Bool { isWarfighter || self == .car || self == .founder }

    /// Towers, castles and navy ships are upgraded at each new age (requirement 24).
    public var isUpgradedWithAge: Bool { self == .navyShip }

    /// The name of this kind at the owner's age, for the interface.
    public func stageName(at age: Age) -> String {
        switch self {
        case .worker: "Worker"
        case .doctor: "Doctor"
        case .car: "Car"
        case .founder: "Founder"
        case .fishingBoat: age >= .hospitals ? "Steam trawler" : age >= .cannons ? "Fishing smack"
            : age >= .ships ? "Fishing boat" : age >= .farms ? "Reed boat" : "Dugout"
        case .navyShip: "Navy ship"
        case .soldier1: "Soldier 1"
        case .soldier2: "Soldier 2"
        case .soldier3: "Soldier 3"
        case .soldier4: "Soldier 4"
        case .knight1: "Knight 1"
        case .knight2: "Knight 2"
        case .knight3: "Knight 3"
        case .cannon1: "Cannon 1"
        case .cannon2: "Cannon 2"
        }
    }
}

/// The kinds of building (docs/requirements.md, requirement 10).
public enum BuildingKind: Int, CaseIterable, Codable, Sendable, Hashable {
    case townCentre, house, farm
    /// A boathouse on the shore: it makes fishing boats and navy ships and
    /// takes in what fishing boats bring back.
    case boatHouse
    case barracks, tower, stable, castle
    /// Makes cannons from the age of cannons (requirement 17).
    case cannonFactory
    /// Makes doctors from the age of hospitals (requirement 17).
    case hospital

    public var name: String {
        switch self {
        case .townCentre: "Town centre"
        case .house: "House"
        case .farm: "Farm"
        case .boatHouse: "Boathouse"
        case .barracks: "Barracks"
        case .tower: "Tower"
        case .stable: "Stable"
        case .castle: "Castle"
        case .cannonFactory: "Cannon factory"
        case .hospital: "Hospital"
        }
    }
}

/// Either kind of thing a player owns on the map.
public enum EntityKind: Hashable, Codable, Sendable {
    case unit(UnitKind)
    case building(BuildingKind)
}

/// Which way a person faces on the screen, in eight directions (ruled
/// 2026-11-21). Five views are drawn, facing right, down-right, down, up and
/// up-right; the drawing mirrors them for the other three
/// (docs/architecture.md, "Sprites"). `right` and `left` keep their values,
/// so that older saves open.
public enum Facing: Int, Codable, Sendable, Hashable, CaseIterable {
    case right, left
    case downRight, down, downLeft, upLeft, up, upRight

    /// The view drawn for this facing.
    public var view: SpriteView {
        switch self {
        case .right, .left: .side
        case .downRight, .downLeft: .frontQuarter
        case .down: .front
        case .up: .back
        case .upRight, .upLeft: .backQuarter
        }
    }

    /// Whether the drawing mirrors the view: for the facings toward the left.
    public var mirrored: Bool { self == .left || self == .downLeft || self == .upLeft }

    /// The facing nearest a movement of `dx` and `dy` across the map, as it
    /// runs on the screen (+x to the lower right, +y to the lower left, a tile
    /// twice as wide as it is high); nil for no movement.
    public static func of(dx: Double, dy: Double) -> Facing? {
        let sx = (dx - dy) * 2, sy = dx + dy
        guard abs(sx) > 1e-9 || abs(sy) > 1e-9 else { return nil }
        // The nearest eighth of a turn, by comparison alone so that every Mac
        // agrees: within 22.5 degrees of an axis is that axis, else the diagonal.
        let t = 0.41421356237309503     // tan(22.5 degrees)
        let horizontal = abs(sy) <= abs(sx) * t, vertical = abs(sx) <= abs(sy) * t
        switch (sx > 0, sy > 0) {
        case _ where horizontal: return sx > 0 ? .right : .left
        case _ where vertical: return sy > 0 ? .down : .up
        case (true, true): return .downRight
        case (false, true): return .downLeft
        case (false, false): return .upLeft
        case (true, false): return .upRight
        }
    }
}
