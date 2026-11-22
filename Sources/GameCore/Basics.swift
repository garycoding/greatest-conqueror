// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// The vocabulary of the game: ages, resources, economies, sectors,
// civilizations, and the identifiers of players, teams and things on the map.
// See docs/requirements.md for what each means in play.

/// The simulation advances in ticks. Every duration in the catalogue is in ticks.
public enum Tick {
    /// Ticks per second of game time.
    public static let rate = 20

    /// The number of ticks in a number of seconds.
    public static func seconds(_ s: Double) -> Int { Int((s * Double(rate)).rounded()) }
}

/// The seven ages, in order. `Comparable` follows that order.
public enum Age: Int, CaseIterable, Codable, Sendable, Comparable, Hashable {
    case stone, bronze, iron, alchemy, industrial, silicon, ai

    public static func < (a: Age, b: Age) -> Bool { a.rawValue < b.rawValue }

    /// The age after this one, or `nil` for the AI age.
    public var next: Age? { Age(rawValue: rawValue + 1) }

    public var name: String {
        switch self {
        case .stone: "Stone"
        case .bronze: "Bronze"
        case .iron: "Iron"
        case .alchemy: "Alchemy"
        case .industrial: "Industrial"
        case .silicon: "Silicon"
        case .ai: "AI"
        }
    }
}

/// The ten resources a player can hold (requirement 13). Copper and tin are not
/// resources: they are deposits whose yield becomes bronze (requirement 18).
public enum Resource: Int, CaseIterable, Codable, Sendable, Hashable {
    case food, wood, stone, bronze, gold, iron, gunpowder, oil, electricity, data

    /// The age in which the resource first appears. Before it, the resource is
    /// neither shown nor obtainable.
    public var firstAge: Age {
        switch self {
        case .food, .wood, .stone: .stone
        case .bronze, .gold: .bronze
        case .iron: .iron
        case .gunpowder: .alchemy
        case .oil: .industrial
        case .electricity: .silicon
        case .data: .ai
        }
    }

    public var economy: Economy {
        switch self {
        case .food: .food
        case .wood, .stone: .buildingMaterials
        case .bronze, .iron: .metal
        case .gold: .wealth
        case .gunpowder: .chemistry
        case .oil, .electricity: .energy
        case .data: .information
        }
    }

    public var name: String {
        switch self {
        case .food: "Food"
        case .wood: "Wood"
        case .stone: "Stone"
        case .bronze: "Bronze"
        case .gold: "Gold"
        case .iron: "Iron"
        case .gunpowder: "Gunpowder"
        case .oil: "Oil"
        case .electricity: "Electricity"
        case .data: "Data"
        }
    }
}

/// The seven economies (requirement 14).
public enum Economy: Int, CaseIterable, Codable, Sendable, Hashable {
    case food, buildingMaterials, metal, wealth, chemistry, energy, information

    public var firstAge: Age {
        switch self {
        case .food, .buildingMaterials: .stone
        case .metal, .wealth: .bronze
        case .chemistry: .alchemy
        case .energy: .industrial
        case .information: .ai
        }
    }
}

/// The five sectors of a civilization (requirement 15).
public enum Sector: Int, CaseIterable, Codable, Sendable, Hashable {
    case workers, warfighters, scholars, engineers, merchants

    /// Merchants start in the Bronze age; the others are present from the Stone age.
    public var firstAge: Age { self == .merchants ? .bronze : .stone }
}

/// The civilizations (requirement 10). They differ in name and colour only.
public enum Civilization: Int, CaseIterable, Codable, Sendable, Hashable {
    case sumer, egypt, harappa, shang, olmec, caral, rome, greece, angkor, tonga, samoa

    public var name: String {
        switch self {
        case .sumer: "Sumer"
        case .egypt: "Egypt"
        case .harappa: "Harappa"
        case .shang: "Shang"
        case .olmec: "Olmec"
        case .caral: "Caral"
        case .rome: "Rome"
        case .greece: "Greece"
        case .angkor: "Angkor"
        case .tonga: "Tonga"
        case .samoa: "Samoa"
        }
    }
}

/// The three levels of difficulty of a computer player (requirement 22).
public enum Difficulty: Int, CaseIterable, Codable, Sendable, Hashable {
    case easy, standard, hard
}

/// A player in a match, human or computer. Numbered from 0 in the order of the setup.
public struct PlayerID: RawRepresentable, Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ value: Int) { rawValue = value }
    public static func < (a: PlayerID, b: PlayerID) -> Bool { a.rawValue < b.rawValue }
    public var description: String { "player \(rawValue)" }
}

/// A team of allied players (requirement 5).
public struct TeamID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ value: Int) { rawValue = value }
    public static func < (a: TeamID, b: TeamID) -> Bool { a.rawValue < b.rawValue }
}

/// A person or building on the map. Identifiers are never reused within a match,
/// and the simulation hands them out in increasing order.
public struct EntityID: RawRepresentable, Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ value: Int) { rawValue = value }
    public static func < (a: EntityID, b: EntityID) -> Bool { a.rawValue < b.rawValue }
    public var description: String { "#\(rawValue)" }
}

/// A resource site on the map: a tree, prey, or a deposit.
public struct SiteID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ value: Int) { rawValue = value }
    public static func < (a: SiteID, b: SiteID) -> Bool { a.rawValue < b.rawValue }
}

/// An amount of each resource. Stored in resource order, so that it is cheap and
/// deterministic to iterate.
public struct ResourceAmounts: Hashable, Codable, Sendable, CustomStringConvertible {
    public private(set) var amounts: [Int]

    public init() { amounts = Array(repeating: 0, count: Resource.allCases.count) }

    public init(_ pairs: [Resource: Int]) {
        self.init()
        for resource in Resource.allCases { amounts[resource.rawValue] = pairs[resource] ?? 0 }
    }

    public subscript(resource: Resource) -> Int {
        get { amounts[resource.rawValue] }
        set { amounts[resource.rawValue] = newValue }
    }

    /// Whether every amount here is at least the corresponding one in `cost`.
    public func covers(_ cost: ResourceAmounts) -> Bool {
        zip(amounts, cost.amounts).allSatisfy { $0 >= $1 }
    }

    /// The resources in which this falls short of `cost`, and by how much.
    public func shortfall(for cost: ResourceAmounts) -> ResourceAmounts {
        var out = ResourceAmounts()
        for resource in Resource.allCases where self[resource] < cost[resource] {
            out[resource] = cost[resource] - self[resource]
        }
        return out
    }

    /// Half of each amount, rounded down: what a demolished building returns.
    public var halved: ResourceAmounts {
        var out = self
        for r in Resource.allCases { out[r] = self[r] / 2 }
        return out
    }

    public static func + (a: ResourceAmounts, b: ResourceAmounts) -> ResourceAmounts {
        var out = a
        for r in Resource.allCases { out[r] += b[r] }
        return out
    }

    public static func - (a: ResourceAmounts, b: ResourceAmounts) -> ResourceAmounts {
        var out = a
        for r in Resource.allCases { out[r] -= b[r] }
        return out
    }

    public var isZero: Bool { amounts.allSatisfy { $0 == 0 } }

    public var description: String {
        Resource.allCases.filter { self[$0] != 0 }.map { "\($0.name) \(self[$0])" }.joined(separator: ", ")
    }
}
