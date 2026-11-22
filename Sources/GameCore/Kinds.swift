// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// The kinds of person. The four peaceful sectors have one kind each, whose
/// stage (hunter, herder and so on) follows the owner's age and changes at once
/// when the age changes (docs/requirements.md, "Sectors"). Each warfighter is a
/// kind of its own. The first milestone holds the Stone and Bronze ages; later
/// milestones add cases.
public enum UnitKind: Int, CaseIterable, Codable, Sendable, Hashable {
    case worker, scholar, engineer, merchant
    /// Received by a player who has lost everything whilst an ally lives
    /// (requirements 26 and 27). It cannot attack and cannot be killed.
    case founder
    case clubman, slinger
    case spearman, archer, chariot
    case swordsman, horseman, catapult
    case knight, musketeer, cannon
    case rifleman, fieldGun, armouredCar
    /// A person's car (ruled 2026-11-21): one for each person, made with
    /// Shift-C; it cannot be harmed, and every enemy unit within
    /// `CarStats.killRadius` dies at once. It belongs to no sector.
    case car
    /// A boat (ruled 2026-11-21): trained at a boat house, it moves only on
    /// water and gathers from the sites there as a worker does on land. It
    /// belongs to no sector.
    case boat

    public var sector: Sector? {
        switch self {
        case .worker: .workers
        case .scholar: .scholars
        case .engineer: .engineers
        case .merchant: .merchants
        case .founder, .car, .boat: nil
        case .clubman, .slinger, .spearman, .archer, .chariot, .swordsman, .horseman, .catapult, .knight, .musketeer, .cannon,
             .rifleman, .fieldGun, .armouredCar:
            .warfighters
        }
    }

    public var isWarfighter: Bool { sector == .warfighters }

    /// The name of this kind at the owner's age, for the interface.
    public func stageName(at age: Age) -> String {
        switch self {
        case .worker: age >= .industrial ? "Factory hand" : age >= .alchemy ? "Craftsman" : age >= .iron ? "Farmer" : age >= .bronze ? "Herder" : "Hunter"
        case .scholar: age >= .industrial ? "Scientist" : age >= .alchemy ? "Alchemist" : age >= .iron ? "Philosopher" : age >= .bronze ? "Scribe" : "Elder"
        case .engineer: age >= .industrial ? "Mechanic" : age >= .alchemy ? "Gunsmith" : age >= .iron ? "Siege engineer" : age >= .bronze ? "Mason" : "Builder"
        case .merchant: age >= .industrial ? "Industrialist" : age >= .alchemy ? "Banker" : age >= .iron ? "Caravan trader" : "Trader"
        case .founder: "Founder"
        case .car: "Car"
        case .boat: age >= .industrial ? "Steam trawler" : age >= .alchemy ? "Fishing smack"
            : age >= .iron ? "Fishing boat" : age >= .bronze ? "Reed boat" : "Dugout"
        case .clubman: "Clubman"
        case .slinger: "Slinger"
        case .spearman: "Spearman"
        case .archer: "Archer"
        case .chariot: "Chariot"
        case .swordsman: "Swordsman"
        case .horseman: "Horseman"
        case .catapult: "Catapult"
        case .knight: "Knight"
        case .musketeer: "Musketeer"
        case .cannon: "Cannon"
        case .rifleman: "Rifleman"
        case .fieldGun: "Field gun"
        case .armouredCar: "Armoured car"
        }
    }
}

/// The kinds of building of the Stone and Bronze ages (docs/requirements.md,
/// "Buildings and ages"). Later milestones add cases.
public enum BuildingKind: Int, CaseIterable, Codable, Sendable, Hashable {
    case townCentre, house, storagePit
    case stockPen, barracks, watchTower, palisade
    case farm, stable, siegeWorkshop, stoneWall
    case castle, alchemistsWorkshop
    case factory, railwayDepot, oilWell
    /// One water tile's piece of a bridge, built by engineers in a line from
    /// bank to bank (ruled 2026-11-21).
    case bridge
    /// A boat house on the shore (ruled 2026-11-21): it trains boats and takes
    /// in what they bring back.
    case boatHouse

    public var name: String {
        switch self {
        case .townCentre: "Town centre"
        case .house: "House"
        case .storagePit: "Storage pit"
        case .stockPen: "Stock pen"
        case .barracks: "Barracks"
        case .watchTower: "Watch tower"
        case .palisade: "Palisade"
        case .farm: "Farm"
        case .stable: "Stable"
        case .siegeWorkshop: "Siege workshop"
        case .stoneWall: "Stone wall"
        case .castle: "Castle"
        case .alchemistsWorkshop: "Alchemist's workshop"
        case .factory: "Factory"
        case .railwayDepot: "Railway depot"
        case .oilWell: "Oil well"
        case .bridge: "Bridge"
        case .boatHouse: "Boat house"
        }
    }
}

/// The direction in which a bridge runs, as a piece of it is drawn. A bridge
/// runs straight, along either axis: movement does not cut a corner past
/// water, so a diagonal bridge could not be crossed.
public enum BridgeRun: Int, CaseIterable, Codable, Sendable, Hashable {
    /// Along the map's x axis.
    case alongX
    /// Along the map's y axis.
    case alongY

    /// The run of a line from `a` to `b`, or nil if it is not straight.
    public static func of(from a: GridPoint, to b: GridPoint) -> BridgeRun? {
        if a == b { return nil }
        if a.y == b.y { return .alongX }
        if a.x == b.x { return .alongY }
        return nil
    }

    /// The step from a tile to the next across the run: toward the foot of
    /// the screen, where a bridge's second row lies.
    public var across: GridPoint { self == .alongX ? GridPoint(0, 1) : GridPoint(1, 0) }
}

/// A bridge piece's place in its bridge (ruled 2026-11-21): a bridge is two
/// tiles wide, a lane in each row, and rises from each bank toward its middle.
public struct BridgePlace: Codable, Sendable, Hashable {
    /// How much the deck rises over each piece, in points, and how high it may rise.
    public static let rise = 4, top = 12

    public var run: BridgeRun
    /// 0 for the row dragged, 1 for the row beside it (`BridgeRun.across`).
    public var lane: Int
    /// The piece's place along its row, from 0 at the end nearer the map's
    /// origin, and how many pieces the row has.
    public var index: Int
    public var count: Int

    public init(run: BridgeRun, lane: Int, index: Int, count: Int) {
        self.run = run; self.lane = lane; self.index = index; self.count = count
    }

    /// The deck's height in points `position` pieces from the row's start (0 to `count`).
    public func height(at position: Int) -> Int {
        max(0, min(Self.rise * position, Self.rise * (count - position), Self.top))
    }

    /// The deck's height at the piece's back edge (nearer the map's origin) and at its front.
    public var heights: (back: Int, front: Int) { (height(at: index), height(at: index + 1)) }

    /// Whether the piece is the middle of its row, where a gatehouse may stand.
    public var middle: Bool { index == count / 2 }

    /// The pose naming the piece's drawing, complete or under construction.
    public func pose(complete: Bool) -> SpritePose {
        let name = run == .alongX ? "along-x" : "along-y"
        let (back, front) = heights
        return SpritePose(rawValue: "bridge-\(name)-lane-\(lane)-from-\(back)-to-\(front)" + (middle ? "-middle" : "")
                          + (complete ? "" : "-under-construction"))
    }

    /// One piece of every drawing a bridge may need: each run, lane, pair of
    /// heights and middle or not, in rows of every length up to `BridgeRule.maxWater`.
    public static let drawings: [BridgePlace] = {
        var seen = Set<SpritePose>(), out: [BridgePlace] = []
        for run in BridgeRun.allCases {
            for lane in 0...1 {
                for count in 1...BridgeRule.maxWater {
                    for index in 0..<count {
                        let place = BridgePlace(run: run, lane: lane, index: index, count: count)
                        if seen.insert(place.pose(complete: true)).inserted { out.append(place) }
                    }
                }
            }
        }
        return out
    }()
}

/// Either kind of thing a player owns on the map.
public enum EntityKind: Hashable, Codable, Sendable {
    case unit(UnitKind)
    case building(BuildingKind)
}

/// Improvements that scholars research at buildings. Later milestones add cases.
public enum Improvement: Int, CaseIterable, Codable, Sendable, Hashable {
    /// Workers gather faster.
    case betterTools
    /// Warfighters strike harder.
    case bronzeWeapons
    /// Warfighters take less harm.
    case shields
    /// Workers gather faster again (Iron age).
    case ironTools
    /// Warfighters strike harder again.
    case ironWeapons
    /// Warfighters take less harm again.
    case mail
    /// Farms yield more.
    case plough
    /// Warfighters strike harder (Alchemy age).
    case betterPowder
    /// Warfighters take less harm.
    case plateArmour
    /// Workers gather faster and workshops make more gunpowder.
    case guilds
    /// Merchants' exchanges give more.
    case banking
    /// Workers gather faster and workshops make more (Industrial age).
    case machineTools
    /// Warfighters strike harder.
    case rifling
    /// Warfighters take less harm.
    case steelPlate
    /// Oil wells pump more.
    case refining
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
