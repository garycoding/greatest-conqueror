// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Why a button cannot act now: the refusal the game would give, and a line
/// that says it in particular ("Short of 20 Wood").
public struct Unavailability: Hashable, Sendable {
    public var refusal: OrderRefusal
    public var explanation: String

    public init(_ refusal: OrderRefusal, _ explanation: String) {
        self.refusal = refusal; self.explanation = explanation
    }
}

/// One button of the panels: what it does, what it costs, and whether it can act now.
/// A button that cannot act stays enabled: pressing it shows its refusal
/// (`perform(in:)`), and its tooltip and refusal line say why.
public struct ActionOffer: Identifiable, Hashable, Sendable {
    public enum Section: Int, Hashable, Sendable {
        case train, research, build, upgrade, age, demolish, dismiss, trade, carry, reseed, car

        public var heading: String {
            switch self {
            case .train: "Train"
            case .research: "Research"
            case .build: "Build"
            case .upgrade: "Upgrade"
            case .age: "Advance"
            case .demolish: "Demolish"
            case .dismiss: "Dismiss"
            case .trade: "Trade for"
            case .carry: "Send to"
            case .reseed: "Farm"
            case .car: "Car"
            }
        }
    }

    public enum Action: Hashable, Sendable {
        case train(at: EntityID, unit: UnitKind)
        case place(BuildingKind)
        case research(at: EntityID, improvement: Improvement)
        /// `at` is nil when no building of the player's trains the new kind.
        case upgrade(units: [EntityID], to: UnitKind, at: EntityID?)
        case advanceAge
        case demolish(engineers: [EntityID], building: EntityID)
        case dismiss(units: [EntityID])
        case exchange(merchants: [EntityID], give: Resource, take: Resource)
        case carry(merchants: [EntityID], resource: Resource, to: EntityID)
        case reseed(farm: EntityID)
        /// Turn the kill radius of these cars on or off (ruled 2026-11-21).
        case killRadius(cars: [EntityID], on: Bool)
    }

    public var id: String
    public var section: Section
    public var title: String
    /// A second line: what it is or does.
    public var detail: String
    public var cost: ResourceAmounts
    public var action: Action
    public var unavailable: Unavailability?
    /// The key that does it, without modifiers.
    public var shortcut: Character?
    /// What the button's icon shows, if anything.
    public var icon: EntityKind?
    public var iconSubject: SpriteSubject?

    public var isAvailable: Bool { unavailable == nil }

    /// The order this button issues, or `nil` where it issues none (placing a
    /// building sets `PlayerSession.placing`; an upgrade without a building).
    public var order: Order? {
        switch action {
        case .train(let building, let unit): .train(at: building, unit: unit)
        case .place: nil
        case .research(let building, let improvement): .research(at: building, improvement: improvement)
        case .upgrade(let units, let kind, let building): building.map { .upgrade(units: units, to: kind, at: $0) }
        case .advanceAge: .advanceAge
        case .demolish(let engineers, let building): .demolish(engineers: engineers, building: building)
        case .dismiss(let units): .dismiss(units: units)
        case .exchange(let merchants, let give, let take): .exchange(merchants: merchants, give: give, take: take)
        case .carry(let merchants, let resource, let building): .carry(merchants: merchants, resource: resource, to: building)
        case .reseed(let farm): .reseed(farm: farm)
        case .killRadius(let cars, let on): .setKillRadius(cars: cars, on: on)
        }
    }

    /// The button's second line: what it costs, or for demolition what it returns.
    public var costLine: String {
        if case .demolish = action, let back = refund { return "Returns \(InterfaceText.cost(back))" }
        if case .dismiss(let units) = action { return units.count == 1 ? "Frees 1 place" : "Frees \(units.count) places" }
        if case .exchange(_, let give, _) = action { return "Gives \(give.name), 3 for 2" }
        if case .carry(_, let resource, _) = action { return "Your \(resource.name), a load at a time" }
        return InterfaceText.cost(cost)
    }

    /// What the action gives back, for demolition.
    public var refund: ResourceAmounts?

    public var tooltip: String {
        var text = "\(section.heading) \(title): \(detail.isEmpty ? "" : detail + " ")Cost: \(InterfaceText.cost(cost))."
        if let unavailable { text += " Not now: \(unavailable.explanation)." }
        if let shortcut { text += " Key: \(String(shortcut).uppercased())." }
        return text
    }

    /// Press the button. A button that cannot act sets the session's refusal
    /// and issues nothing; one that places a building chooses it (a second
    /// press chooses nothing again); the rest issue their order.
    @MainActor
    public func perform(in session: PlayerSession) {
        if let unavailable {
            session.lastRefusal = unavailable.refusal
            return
        }
        switch action {
        case .place(let kind): session.placing = (session.placing == kind) ? nil : kind
        default: if let order { session.issue(order) }
        }
    }
}

/// A selected entity, in words.
public struct EntityDetail: Hashable, Sendable {
    public var id: EntityID
    public var kind: EntityKind
    public var name: String
    /// "Sumer, yours", "Egypt, ally" or "Egypt, opponent".
    public var ownerLine: String
    public var health: Int
    public var maxHealth: Int
    public var activity: String
    /// From 0 to 1, for construction, training and research.
    public var progress: Double?

    public var healthFraction: Double { maxHealth > 0 ? InterfaceText.clamp(Double(health) / Double(maxHealth)) : 0 }
}

public struct KindCount: Hashable, Sendable {
    public var kind: EntityKind
    public var name: String
    public var count: Int
}

/// What the selection panel shows for the session's selection, and which
/// actions it offers, each with the reason it is or is not available. Computed
/// from the view and the catalogue alone, so that it is testable without a screen.
public struct PanelModel: Sendable {
    public enum Content: Hashable, Sendable {
        case nothing
        case single(EntityDetail)
        case several(total: Int, counts: [KindCount])
    }

    public var content: Content
    public var train: [ActionOffer] = []
    public var research: [ActionOffer] = []
    public var build: [ActionOffer] = []
    public var upgrade: [ActionOffer] = []
    public var demolish: [ActionOffer] = []
    public var dismiss: [ActionOffer] = []
    public var trade: [ActionOffer] = []
    public var carry: [ActionOffer] = []
    public var reseed: [ActionOffer] = []
    public var car: [ActionOffer] = []
    /// A building the player is placing, for the panel's hint.
    public var placing: BuildingKind?

    public var actions: [ActionOffer] { train + research + reseed + car + build + upgrade + trade + carry + demolish + dismiss }
    public var sections: [(section: ActionOffer.Section, offers: [ActionOffer])] {
        [(.train, train), (.research, research), (.reseed, reseed), (.car, car), (.build, build), (.upgrade, upgrade), (.trade, trade), (.carry, carry), (.demolish, demolish), (.dismiss, dismiss)].filter { !$0.1.isEmpty }
    }

    /// The offer that a key press does, if any.
    public func offer(forKey key: Character) -> ActionOffer? {
        let lower = Character(key.lowercased())
        return actions.first { $0.shortcut == lower }
    }

    @MainActor
    public init(session: PlayerSession) {
        self.init(view: session.view, catalogue: session.catalogue, selection: session.selection, placing: session.placing)
    }

    public init(view: PlayerView, catalogue: Catalogue, selection: [EntityID], placing: BuildingKind? = nil) {
        self.placing = placing
        let selected = selection.compactMap { view.entity($0) }
        func age(of owner: PlayerID) -> Age { view.players.first { $0.id == owner }?.age ?? view.age }

        // The content.
        switch selected.count {
        case 0:
            content = .nothing
        case 1:
            let e = selected[0]
            let ownerAge = age(of: e.owner)
            let (text, progress) = InterfaceText.describe(e.activity, of: e.kind, age: ownerAge)
            let civ = view.players.first { $0.id == e.owner }?.civilization.name ?? "Unknown"
            let relation = e.owner == view.player ? "yours" : (view.isAlly(e.owner) ? "ally" : "opponent")
            content = .single(EntityDetail(id: e.id, kind: e.kind, name: InterfaceText.name(of: e.kind, at: ownerAge),
                                           ownerLine: "\(civ), \(relation)", health: e.health, maxHealth: e.maxHealth,
                                           activity: text, progress: progress))
        default:
            var counts: [EntityKind: Int] = [:]
            for e in selected { counts[e.kind, default: 0] += 1 }
            let ordered = counts.keys.sorted { Self.rank($0) < Self.rank($1) }
            content = .several(total: selected.count, counts: ordered.map {
                KindCount(kind: $0, name: InterfaceText.name(of: $0, at: view.age), count: counts[$0] ?? 0)
            })
        }

        // What the match allows at all.
        let gate: Unavailability?
        if view.outcome != nil {
            gate = Unavailability(.notNow, "The match is over")
        } else if view.isPaused {
            gate = Unavailability(.notNow, "The match is paused")
        } else {
            gate = nil
        }

        let planner = Planner(view: view, catalogue: catalogue, gate: gate)
        let own = selected.filter { $0.owner == view.player }

        // Train and research at a single own building that stands complete.
        if selected.count == 1, let b = own.first, case .building(let kind) = b.kind, !Self.isUnderConstruction(b) {
            let stats = catalogue.stats(kind)
            train = stats.trains.filter { $0 != .founder && catalogue.stats($0).age <= catalogue.lastAge }.map { unit in
                let u = catalogue.stats(unit)
                let name = unit.stageName(at: view.age)
                return ActionOffer(
                    id: "train-\(unit)", section: .train, title: name, detail: "Trains one \(name).", cost: u.cost,
                    action: .train(at: b.id, unit: unit),
                    unavailable: planner.check(cost: u.cost, age: u.age, population: u.population),
                    shortcut: Self.trainKey(unit), icon: .unit(unit),
                    iconSubject: planner.subject(.unit(unit)))
            }
            var researching = false
            if case .researching = b.activity { researching = true }
            research = stats.researches.filter { !view.improvements.contains($0) }.map { improvement in
                let r = catalogue.stats(improvement)
                var why = planner.check(cost: r.cost, age: r.age)
                if why == nil && researching { why = Unavailability(.notNow, "Research is already under way here") }
                return ActionOffer(
                    id: "research-\(improvement)", section: .research, title: InterfaceText.name(of: improvement),
                    detail: InterfaceText.effect(of: improvement), cost: r.cost,
                    action: .research(at: b.id, improvement: improvement), unavailable: why,
                    shortcut: Self.researchKey(improvement), icon: nil, iconSubject: nil)
            }
        }

        // Reseed a single own farm that has run dry (ruled 2026-11-19); its farmer
        // does so on his own, so the button serves a farm left without one.
        if selected.count == 1, let b = own.first, b.kind == .building(.farm), let left = b.remaining,
           let cost = catalogue.gathering.farmReseed {
            var why = planner.check(cost: cost, age: catalogue.stats(.farm).age)
            if left > 0 { why = Unavailability(.invalidTarget, "\(left) food left to harvest") }
            reseed = [ActionOffer(
                id: "reseed", section: .reseed, title: "Reseed",
                detail: "Sows the field again once it has run dry; a farmer at work there does so on his own.",
                cost: cost, action: .reseed(farm: b.id), unavailable: why, shortcut: "e", icon: nil, iconSubject: nil)]
        }

        // Turn the selected cars' kill radius off or on (ruled 2026-11-21): the
        // button turns it off while any of them has it on, so that one press
        // settles them all.
        let cars = own.filter { $0.kind == .unit(.car) }
        if !cars.isEmpty {
            let anyOn = cars.contains { $0.killRadiusOff != true }
            car = [ActionOffer(
                id: "kill-radius", section: .car, title: anyOn ? "Kill radius off" : "Kill radius on",
                detail: anyOn
                    ? "The car stops killing enemy units near it; its laser still burns buildings."
                    : "Every enemy unit near the car dies at once, as when it was made.",
                cost: ResourceAmounts(), action: .killRadius(cars: cars.map(\.id), on: !anyOn), unavailable: nil,
                shortcut: "z", icon: nil, iconSubject: nil)]
        }

        // Demolish a single own building (requirement 28): the player's idle
        // engineers do it, or the nearest engineer where none is idle.
        if selected.count == 1, let b = own.first, case .building(let kind) = b.kind {
            let engineers = view.entities.filter { $0.owner == view.player && $0.kind == .unit(.engineer) }
            let idle = engineers.filter { $0.activity == .idle }.map(\.id)
            let nearest = engineers.min {
                let a = ($0.position.x - b.position.x, $0.position.y - b.position.y)
                let c = ($1.position.x - b.position.x, $1.position.y - b.position.y)
                return (a.0 * a.0 + a.1 * a.1, $0.id) < (c.0 * c.0 + c.1 * c.1, $1.id)
            }
            let crew = idle.isEmpty ? nearest.map { [$0.id] } ?? [] : idle
            var why = gate
            if why == nil && crew.isEmpty { why = Unavailability(.notYours, "Needs an engineer") }
            let back = catalogue.stats(kind).cost.halved
            demolish = [ActionOffer(
                id: "demolish", section: .demolish, title: kind.name,
                detail: "Engineers pull it down and return half its cost (\(InterfaceText.cost(back))).",
                cost: ResourceAmounts(), action: .demolish(engineers: crew, building: b.id), unavailable: why,
                shortcut: "x", icon: nil, iconSubject: nil, refund: back)]
        }

        // A founder founds one town centre, free; it then becomes an engineer (requirement 26).
        if own.contains(where: { $0.kind == .unit(.founder) }) {
            build = [ActionOffer(
                id: "build-townCentre", section: .build, title: BuildingKind.townCentre.name,
                detail: "The founder builds it where you click, free, with two workers, and becomes an engineer.",
                cost: ResourceAmounts(), action: .place(.townCentre), unavailable: gate,
                shortcut: Self.buildKey(.townCentre), icon: .building(.townCentre),
                iconSubject: planner.subject(.building(.townCentre)))]
        }

        // Buildings for engineers, of the ages reached.
        if own.contains(where: { $0.kind == .unit(.engineer) }) {
            // A bridge only where the match's setup allows bridges (ruled 2026-11-21).
            build = catalogue.buildings.filter { $0.age <= view.age && ($0.kind != .bridge || view.bridges) }.map { b in
                ActionOffer(
                    id: "build-\(b.kind)", section: .build, title: b.kind.name, detail: b.kind == .bridge
                        ? "Engineers build it across water: drag from one bank to the other. The cost is for each water tile."
                        : "Engineers construct it where you click.",
                    cost: b.cost, action: .place(b.kind), unavailable: planner.check(cost: b.cost, age: b.age),
                    shortcut: Self.buildKey(b.kind), icon: .building(b.kind), iconSubject: planner.subject(.building(b.kind)))
            }
        }

        // Dismiss the player's own people, founders excepted (requirement 30).
        let leaving = own.filter { if case .unit(let kind) = $0.kind { return kind != .founder } else { return false } }
            .map(\.id).sorted()
        if !leaving.isEmpty {
            let what = leaving.count == 1 ? (selected.first.map { InterfaceText.name(of: $0.kind, at: view.age) } ?? "Person")
                                          : "\(leaving.count) people"
            dismiss = [ActionOffer(
                id: "dismiss", section: .dismiss, title: what,
                detail: "They leave at once and free their places; nothing is returned.",
                cost: ResourceAmounts(), action: .dismiss(units: leaving), unavailable: gate,
                shortcut: Self.deleteKey, icon: nil, iconSubject: nil)]
        }

        // Merchants trade the player's largest stock for another resource, and
        // carry resources to an ally's town centre (requirement 15).
        let merchantIDs = own.filter { $0.kind == .unit(.merchant) }.map(\.id).sorted()
        if !merchantIDs.isEmpty, catalogue.merchants != nil {
            let shown = view.shownResources
            let hasCentre = view.entities.contains {
                $0.owner == view.player && $0.kind == .building(.townCentre) && !Self.isUnderConstruction($0)
            }
            for take in shown {
                let give = shown.filter { $0 != take }.max { view.resources[$0] < view.resources[$1] }
                let why: Unavailability? = gate
                    ?? (hasCentre ? nil : Unavailability(.invalidTarget, "Needs a town centre"))
                    ?? ((give.map { view.resources[$0] } ?? 0) > 0 ? nil
                    : Unavailability(.notEnough(ResourceAmounts()), "Nothing to trade"))
                trade.append(ActionOffer(
                    id: "trade-\(take)", section: .trade, title: take.name,
                    detail: "Merchants at the town centre trade your \(give?.name ?? "stock") for \(take.name) until it runs out.",
                    cost: ResourceAmounts(), action: .exchange(merchants: merchantIDs, give: give ?? take, take: take),
                    unavailable: why, shortcut: nil, icon: nil, iconSubject: nil))
            }
            let me = view.players.first { $0.id == view.player }
            let allies = view.players.filter { $0.id != view.player && $0.team == me?.team && !$0.isDefeated }
            for ally in allies {
                guard let centre = view.entities.first(where: {
                    $0.owner == ally.id && $0.kind == .building(.townCentre) && !Self.isUnderConstruction($0)
                }) else { continue }
                for resource in shown where view.resources[resource] > 0 {
                    carry.append(ActionOffer(
                        id: "carry-\(ally.id.rawValue)-\(resource)", section: .carry,
                        title: "\(ally.civilization.name): \(resource.name)",
                        detail: "Merchants carry your \(resource.name) to \(ally.civilization.name)'s town centre, a load at a time, until it runs out.",
                        cost: ResourceAmounts(), action: .carry(merchants: merchantIDs, resource: resource, to: centre.id),
                        unavailable: gate, shortcut: nil, icon: nil, iconSubject: nil))
                }
            }
        }

        // Upgrades for warfighters where the catalogue has one.
        var keyGiven = false
        let warfighters = Dictionary(grouping: own.filter { $0.kind.isWarfighterKind }, by: { $0.kind })
        for kind in warfighters.keys.sorted(by: { Self.rank($0) < Self.rank($1) }) {
            guard case .unit(let from) = kind, let up = catalogue.upgrade(from: from), let group = warfighters[kind] else { continue }
            let ids = group.map(\.id).sorted()
            var total = ResourceAmounts()
            for _ in ids { total = total + up.cost }
            let target = up.to.stageName(at: view.age)
            let host = view.entities
                .filter { $0.owner == view.player && !Self.isUnderConstruction($0) }
                .first { if case .building(let k) = $0.kind { return catalogue.stats(k).trains.contains(up.to) } else { return false } }
            var why = planner.check(cost: total, age: catalogue.stats(up.to).age)
            if why == nil && host == nil {
                let names = catalogue.stats(up.to).trainedAt.map(\.name).joined(separator: " or ").lowercased()
                why = Unavailability(.invalidTarget, "Needs a \(names) to train the \(target)")
            }
            upgrade.append(ActionOffer(
                id: "upgrade-\(from)", section: .upgrade, title: "\(from.stageName(at: view.age)) to \(target)",
                detail: "Turns \(ids.count) \(from.stageName(at: view.age)) into \(target).", cost: total,
                action: .upgrade(units: ids, to: up.to, at: host?.id), unavailable: why,
                shortcut: keyGiven ? nil : "u", icon: .unit(up.to), iconSubject: planner.subject(.unit(up.to))))
            keyGiven = true
        }
    }

    // MARK: Shortcuts

    /// Keys for the actions that are not tied to the selection.
    public static let pauseKey: Character = " "
    public static let advanceKey: Character = "n"
    /// The Delete key (backspace), which dismisses the selected people.
    public static let deleteKey: Character = "\u{8}"

    static func trainKey(_ unit: UnitKind) -> Character? {
        switch unit {
        case .worker: "w"
        case .scholar: "s"
        case .engineer: "e"
        case .merchant: "m"
        case .clubman: "c"
        case .slinger: "l"
        case .spearman: "p"
        case .archer: "a"
        case .chariot: "h"
        case .swordsman: "q"
        case .horseman: "r"
        case .catapult: "u"
        case .knight: "k"
        case .musketeer: "m"
        case .cannon: "j"
        case .rifleman: "f"
        case .fieldGun: "d"
        case .armouredCar: "v"
        case .car: nil
        case .boat: "b"
        case .founder: nil
        }
    }

    static func buildKey(_ kind: BuildingKind) -> Character? {
        switch kind {
        case .townCentre: "t"
        case .house: "h"
        case .storagePit: "s"
        case .stockPen: "k"
        case .barracks: "b"
        case .watchTower: "w"
        case .palisade: "p"
        case .farm: "f"
        case .stable: "l"
        case .siegeWorkshop: "g"
        case .stoneWall: "o"
        case .castle: "c"
        case .alchemistsWorkshop: "a"
        case .factory: "y"
        case .railwayDepot: "d"
        case .oilWell: "r"
        // "x" for a crossing: "b" is the barracks.
        case .bridge: "x"
        // "i" for an inlet: "b" is the barracks and "o" the stone wall.
        case .boatHouse: "i"
        }
    }

    static func researchKey(_ improvement: Improvement) -> Character? {
        switch improvement {
        case .betterTools: "t"
        case .bronzeWeapons: "b"
        case .shields: "d"
        case .ironTools: "i"
        case .ironWeapons: "y"
        case .mail: "v"
        case .plough: "o"
        case .betterPowder: "p"
        case .plateArmour: "a"
        case .guilds: "g"
        case .banking: "b"
        case .machineTools: "k"
        case .rifling: "r"
        case .steelPlate: "s"
        case .refining: "o"
        }
    }

    // MARK: Helpers

    static func rank(_ kind: EntityKind) -> Int {
        switch kind {
        case .unit(let u): u.rawValue
        case .building(let b): 100 + b.rawValue
        }
    }

    static func isUnderConstruction(_ e: EntityView) -> Bool {
        if case .underConstruction = e.activity { return true }
        return false
    }

    /// The common reasoning behind every offer.
    struct Planner {
        let view: PlayerView
        let catalogue: Catalogue
        let gate: Unavailability?

        /// The first reason an action cannot act: the match first, then the age,
        /// the resources and the population limit.
        func check(cost: ResourceAmounts, age: Age, population places: Int? = nil) -> Unavailability? {
            if let gate { return gate }
            if age > view.age {
                return Unavailability(.ageNotReached(age), "Needs the \(age.name) age")
            }
            if !view.resources.covers(cost) {
                let short = view.resources.shortfall(for: cost)
                return Unavailability(.notEnough(short), "Short of \(InterfaceText.cost(short))")
            }
            if let places, view.population + places > view.populationLimit {
                let advice = view.populationLimit >= catalogue.populationMaximum ? "" : "; build a house"
                return Unavailability(.populationLimit, "Population full (\(view.population) of \(view.populationLimit))\(advice)")
            }
            return nil
        }

        /// The sprite subject of an icon, chosen as `SpriteSubject.of` does for an entity.
        func subject(_ kind: EntityKind) -> SpriteSubject {
            switch kind {
            case .unit(let u):
                let own = catalogue.stats(u).age
                return .unit(u, (u.isWarfighter || u == .founder || u == .car) ? own : max(own, view.age))
            case .building(let b):
                return .building(b, max(catalogue.stats(b).age, view.age))
            }
        }
    }
}

extension EntityKind {
    var isWarfighterKind: Bool {
        if case .unit(let u) = self { return u.isWarfighter }
        return false
    }
}
