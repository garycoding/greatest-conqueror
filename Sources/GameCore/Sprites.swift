// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// What a sprite shows. The drawing (`MapDrawing`) asks for sprites by key and
/// the artwork (`Artwork`) supplies them, so that the two agree without either
/// waiting for the other (docs/architecture.md, "Sprites").
public enum SpriteSubject: Hashable, Codable, Sendable {
    /// A unit of a kind in a look (`Age.look`). Use `SpriteSubject.of(_:ownerAge:)`
    /// to choose it: a worker's or a boat's look follows the owner's age,
    /// whereas a warfighter or the car keeps the look of the age its kind belongs to.
    case unit(UnitKind, Look)
    /// A building, in the look of the owner's age.
    case building(BuildingKind, Look)
    case site(SiteKind)
    /// Plain rock on a deposit's tile, before the player reaches its age.
    case outcrop
    /// A ground tile; `variant` gives variety between neighbouring tiles.
    case terrain(Terrain, variant: Int)

    /// The subject for an entity, as both the drawing and the artwork must name it.
    public static func of(_ entity: EntityView, ownerAge: Age, catalogue: Catalogue = .standard) -> SpriteSubject {
        of(entity.kind, ownerAge: ownerAge, catalogue: catalogue)
    }

    /// The subject for a kind of an owner in an age: a kind without a drawing
    /// of its own is drawn as its stand-in (`StandIn`).
    public static func of(_ kind: EntityKind, ownerAge: Age, catalogue: Catalogue = .standard) -> SpriteSubject {
        switch kind {
        case .unit(let kind):
            let drawn = StandIn.unit(kind)
            let own = catalogue.stats(drawn).age
            return .unit(drawn, (drawn.keepsItsLook ? own : max(own, ownerAge)).look)
        case .building(let kind):
            let drawn = StandIn.building(kind)
            return StandIn.subject(.building(drawn, max(catalogue.stats(drawn).age, ownerAge).look))
        }
    }
}

/// The kinds drawn, until their own art is made, as an existing kind (step 5
/// of the plan; step 8 replaces this table with the new drawings): the doctor
/// and the founder as the worker, the navy ship as the fishing boat, drawn
/// larger, knight 3 as knight 2, the cannon factory as the barracks, the
/// hospital as the house, and the fruit bush as the tree, drawn smaller.
/// Every other kind is drawn as itself.
public enum StandIn {
    public static func unit(_ kind: UnitKind) -> UnitKind {
        switch kind {
        case .doctor, .founder: .worker
        case .navyShip: .fishingBoat
        case .knight3: .knight2
        default: kind
        }
    }

    public static func building(_ kind: BuildingKind) -> BuildingKind {
        switch kind {
        case .cannonFactory: .barracks
        case .hospital: .house
        default: kind
        }
    }

    /// The fruit bush as the tree, the nearest plant drawn, until step 8 draws the bush.
    public static func site(_ kind: SiteKind) -> SiteKind { kind == .fruit ? .tree : kind }

    /// How much larger than its stand-in a kind is drawn.
    public static func scale(_ kind: EntityKind) -> Double { kind == .unit(.navyShip) ? 1.5 : 1 }

    /// How much larger than its stand-in a site is drawn: the fruit bush at a
    /// little over a third of the tree's height.
    public static func scale(_ kind: SiteKind) -> Double { kind == .fruit ? 0.4 : 1 }

    /// A look a kind lacks, drawn in another: the castle, of the age of ships
    /// now (requirement 10), in the Iron look as in the Alchemy look.
    public static func subject(_ subject: SpriteSubject) -> SpriteSubject {
        subject == .building(.castle, .iron) ? .building(.castle, .alchemy) : subject
    }
}

/// A pose within limited animation. Open-ended, so that the art style guide can
/// add poses without changing the key's shape; the drawing falls back to
/// `.standing` (people) or `.complete` (buildings) where a pose is missing.
public struct SpritePose: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }

    public static let standing: SpritePose = "standing"
    public static let walking: SpritePose = "walking"
    public static let working: SpritePose = "working"
    public static let fighting: SpritePose = "fighting"
    public static let complete: SpritePose = "complete"
    public static let underConstruction: SpritePose = "under-construction"
    /// A site on a water tile (ruled 2026-11-21): a rock rising from the water,
    /// with a waterline and ripples and no shadow on the ground. The drawing
    /// falls back to `.complete` where it is missing.
    public static let afloat: SpritePose = "afloat"
}

/// Which way a person is seen in a sprite (ruled 2026-11-21: eight facings,
/// five views drawn): from the side facing right, from the front a quarter
/// turn toward the right, from the front, from behind, and from behind a
/// quarter turn toward the right. The drawing mirrors them for the facings
/// toward the left (`Facing.mirrored`).
public enum SpriteView: String, Codable, Sendable, Hashable, CaseIterable {
    case side
    case frontQuarter = "front-quarter"
    case front
    case back
    case backQuarter = "back-quarter"
}

/// One picture: a subject in a pose, the frame of that pose, and the view a
/// person is seen from. A pose that moves has `framesPerPose` frames, shown
/// in turn at `frameRate` a second.
public struct SpriteKey: Hashable, Codable, Sendable, CustomStringConvertible {
    /// The number of frames in a pose that moves (docs/art-style.md).
    public static let framesPerPose = 12
    /// Frames shown a second (docs/art-style.md).
    public static let frameRate = 12.0

    public var subject: SpriteSubject
    public var pose: SpritePose
    public var frame: Int
    /// Which way a person is seen (ruled 2026-11-21); `.side` for everything else.
    public var view: SpriteView

    public init(_ subject: SpriteSubject, _ pose: SpritePose, frame: Int = 0, view: SpriteView = .side) {
        self.subject = subject; self.pose = pose; self.frame = frame; self.view = view
    }

    private enum CodingKeys: String, CodingKey { case subject, pose, frame, view }

    /// A key saved before views opens as the side view.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subject = try c.decode(SpriteSubject.self, forKey: .subject)
        pose = try c.decode(SpritePose.self, forKey: .pose)
        frame = try c.decode(Int.self, forKey: .frame)
        view = try c.decodeIfPresent(SpriteView.self, forKey: .view) ?? .side
    }

    /// The same key in another view.
    public func seen(_ view: SpriteView) -> SpriteKey { SpriteKey(subject, pose, frame: frame, view: view) }

    public var description: String { "\(subject) \(pose.rawValue) \(frame)" + (view == .side ? "" : " \(view.rawValue)") }

    /// The pose a person or building should show for an activity.
    public static func pose(for activity: Activity, isBuilding: Bool) -> SpritePose {
        if isBuilding {
            if case .underConstruction = activity { return .underConstruction }
            return .complete
        }
        switch activity {
        case .idle: return .standing
        case .moving: return .walking
        case .gathering, .working, .constructing: return .working
        case .fighting: return .fighting
        case .underConstruction, .training, .advancing: return .standing
        }
    }

    /// Every picture the first milestone needs, in the minimum set of poses:
    /// the artwork's checklist.
    public static func required(through age: Age, catalogue: Catalogue = .standard) -> [SpriteKey] {
        var keys: [SpriteKey] = []
        let ages = Age.allCases.filter { $0 <= age }
        // The kinds that are drawn as a stand-in (`StandIn`) add nothing to the list.
        for stats in catalogue.units where stats.age <= age && StandIn.unit(stats.kind) == stats.kind {
            let looks: [Age] = stats.kind.keepsItsLook ? [stats.age] : ages.filter { $0 >= stats.age }
            for look in looks.map(\.look) {
                for pose in [SpritePose.standing, .walking, .working, .fighting] where pose != .fighting || stats.attack != nil {
                    keys.append(SpriteKey(.unit(stats.kind, look), pose))
                }
            }
        }
        for stats in catalogue.buildings where stats.age <= age && StandIn.building(stats.kind) == stats.kind {
            for look in ages.filter({ $0 >= stats.age }).map(\.look)
            where StandIn.subject(.building(stats.kind, look)) == .building(stats.kind, look) {
                keys.append(SpriteKey(.building(stats.kind, look), .complete))
                keys.append(SpriteKey(.building(stats.kind, look), .underConstruction))
            }
        }
        for kind in SiteKind.allCases where StandIn.site(kind) == kind {
            keys.append(SpriteKey(.site(kind), .complete))
        }
        keys.append(SpriteKey(.outcrop, .complete))
        for terrain in Terrain.allCases { keys.append(SpriteKey(.terrain(terrain, variant: 0), .complete)) }
        return keys
    }
}

/// The colour of a civilization, applied to the team-colour layer of its
/// sprites (docs/architecture.md, "Sprites"). Components are 0 to 1.
public struct TeamColour: Hashable, Codable, Sendable {
    public var red: Double, green: Double, blue: Double
    public init(red: Double, green: Double, blue: Double) { self.red = red; self.green = green; self.blue = blue }

    /// Provisional colours, chosen to be told apart; the art style guide may change them.
    public static func of(_ civilization: Civilization) -> TeamColour {
        switch civilization {
        case .sumer: TeamColour(red: 0.78, green: 0.25, blue: 0.18)
        // Cobalt: the Bronze age's verdigris was nearly Egypt's old teal.
        case .egypt: TeamColour(red: 0.10, green: 0.35, blue: 0.80)
        // Lime: the old ochre was nearly the Bronze age's ground.
        case .harappa: TeamColour(red: 0.62, green: 0.80, blue: 0.20)
        case .shang: TeamColour(red: 0.25, green: 0.37, blue: 0.48)
        case .olmec: TeamColour(red: 0.55, green: 0.61, blue: 0.35)
        case .caral: TeamColour(red: 0.58, green: 0.33, blue: 0.55)
        case .rome: TeamColour(red: 0.58, green: 0.13, blue: 0.15)
        case .greece: TeamColour(red: 0.42, green: 0.64, blue: 0.86)
        case .angkor: TeamColour(red: 0.85, green: 0.47, blue: 0.20)
        case .tonga: TeamColour(red: 0.16, green: 0.16, blue: 0.20)
        case .samoa: TeamColour(red: 0.94, green: 0.64, blue: 0.58)
        }
    }
}
