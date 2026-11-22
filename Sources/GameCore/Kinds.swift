// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// The kinds of unit. Workers and boats are one kind each in every age; each
/// warfighter is a kind of its own. The warfighters are those of Cities of
/// Progress that become the tiers of soldiers, knights and cannons in a later
/// step (docs/requirements.md, requirement 19).
public enum UnitKind: Int, CaseIterable, Codable, Sendable, Hashable {
    /// Gathers, farms, builds and repairs.
    case worker
    /// A boat (ruled 2026-11-21): trained at a boat house, it moves only on
    /// water and gathers from the sites there as a worker does on land.
    case boat
    /// A person's car (ruled 2026-11-21): made with Shift-C; it cannot be
    /// harmed, and every enemy unit within `CarStats.killRadius` dies at once.
    case car
    /// Soldiers 1 to 4.
    case spearman, swordsman, musketeer, rifleman
    /// Knights 1 and 2.
    case horseman, knight
    /// Cannons 1 and 2.
    case cannon, fieldGun

    public var isWarfighter: Bool {
        switch self {
        case .worker, .boat, .car: false
        case .spearman, .swordsman, .musketeer, .rifleman, .horseman, .knight, .cannon, .fieldGun: true
        }
    }

    /// The name of this kind at the owner's age, for the interface.
    public func stageName(at age: Age) -> String {
        switch self {
        case .worker: "Worker"
        case .car: "Car"
        case .boat: age >= .hospitals ? "Steam trawler" : age >= .cannons ? "Fishing smack"
            : age >= .ships ? "Fishing boat" : age >= .farms ? "Reed boat" : "Dugout"
        case .spearman: "Spearman"
        case .swordsman: "Swordsman"
        case .musketeer: "Musketeer"
        case .rifleman: "Rifleman"
        case .horseman: "Horseman"
        case .knight: "Knight"
        case .cannon: "Cannon"
        case .fieldGun: "Field gun"
        }
    }
}

/// The kinds of building (docs/requirements.md, requirement 10).
public enum BuildingKind: Int, CaseIterable, Codable, Sendable, Hashable {
    case townCentre, house, farm
    /// A boat house on the shore (ruled 2026-11-21): it trains boats and takes
    /// in what they bring back.
    case boatHouse
    case barracks, watchTower, stable, castle

    public var name: String {
        switch self {
        case .townCentre: "Town centre"
        case .house: "House"
        case .farm: "Farm"
        case .boatHouse: "Boat house"
        case .barracks: "Barracks"
        case .watchTower: "Watch tower"
        case .stable: "Stable"
        case .castle: "Castle"
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
