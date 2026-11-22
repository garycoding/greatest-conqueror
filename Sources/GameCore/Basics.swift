// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// The vocabulary of the game: ages, looks, resources, civilizations, and the identifiers of players, teams and things on the map.
// See docs/requirements.md for what each means in play.

/// The simulation advances in ticks. Every duration in the catalogue is in ticks.
public enum Tick {
    /// Ticks per second of game time.
    public static let rate = 20

    /// The number of ticks in a number of seconds.
    public static func seconds(_ s: Double) -> Int { Int((s * Double(rate)).rounded()) }
}

/// The five ages, in order (requirement 5). `Comparable` follows that order.
/// Each is drawn in the look of an age of Cities of Progress (`Age.look`).
public enum Age: Int, CaseIterable, Codable, Sendable, Comparable, Hashable {
    case towns, farms, ships, cannons, hospitals

    public static func < (a: Age, b: Age) -> Bool { a.rawValue < b.rawValue }

    /// The age after this one, or `nil` for the age of hospitals.
    public var next: Age? { Age(rawValue: rawValue + 1) }

    /// The age's own word, as in "the age of towns".
    public var name: String {
        switch self {
        case .towns: "towns"
        case .farms: "farms"
        case .ships: "ships"
        case .cannons: "cannons"
        case .hospitals: "hospitals"
        }
    }

    /// The age's name for the interface: "Age of towns".
    public var title: String { "Age of \(name)" }

    /// The look in which the age is drawn (requirement 7).
    public var look: Look {
        switch self {
        case .towns: .stone
        case .farms: .bronze
        case .ships: .iron
        case .cannons: .alchemy
        case .hospitals: .industrial
        }
    }
}

/// The looks in which the art is drawn: the ages of Cities of Progress whose
/// drawings Greatest Conqueror reuses (requirement 7). The art's batches are
/// named by their look.
public enum Look: Int, CaseIterable, Codable, Sendable, Comparable, Hashable {
    case stone, bronze, iron, alchemy, industrial

    public static func < (a: Look, b: Look) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .stone: "Stone"
        case .bronze: "Bronze"
        case .iron: "Iron"
        case .alchemy: "Alchemy"
        case .industrial: "Industrial"
        }
    }
}

/// The three resources a player can hold (requirement 8).
public enum Resource: Int, CaseIterable, Codable, Sendable, Hashable {
    case food, wood, gold

    public var name: String {
        switch self {
        case .food: "Food"
        case .wood: "Wood"
        case .gold: "Gold"
        }
    }
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

    /// That share of each amount, rounded down: what a demolished building returns.
    public func share(_ fraction: Double) -> ResourceAmounts {
        var out = self
        for r in Resource.allCases { out[r] = Int((Double(self[r]) * fraction).rounded(.down)) }
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
