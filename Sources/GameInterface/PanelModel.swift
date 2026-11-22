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
        case train, build, age, demolish, dismiss, reseed, car, orders

        public var heading: String {
            switch self {
            case .train: "Train"
            case .build: "Build"
            case .age: "Advance"
            case .demolish: "Demolish"
            case .dismiss: "Dismiss"
            case .reseed: "Farm"
            case .car: "Car"
            case .orders: "Orders"
            }
        }
    }

    public enum Action: Hashable, Sendable {
        case train(at: EntityID, unit: UnitKind)
        case place(BuildingKind)
        /// The advance to the next age, at a town centre of the player's.
        case advanceAge(at: EntityID)
        case demolish(workers: [EntityID], building: EntityID)
        case dismiss(units: [EntityID])
        case reseed(farm: EntityID)
        /// Turn the kill radius of these cars on or off (ruled 2026-11-21).
        case killRadius(cars: [EntityID], on: Bool)
        /// Board a navy ship (requirement 16).
        case board(units: [EntityID], ship: EntityID)
        /// Land a navy ship's troops at a point on the shore (requirement 16).
        case land(ships: [EntityID], at: MapPosition)
        /// Doctors heal a wounded unit (requirement 13).
        case heal(doctors: [EntityID], target: EntityID)
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
    /// building sets `PlayerSession.placing`).
    public var order: Order? {
        switch action {
        case .train(let building, let unit): .train(at: building, unit: unit)
        case .place: nil
        case .advanceAge(let centre): .advanceAge(at: centre)
        case .demolish(let workers, let building): .demolish(workers: workers, building: building)
        case .dismiss(let units): .dismiss(units: units)
        case .reseed(let farm): .reseed(farm: farm)
        case .killRadius(let cars, let on): .setKillRadius(cars: cars, on: on)
        case .board(let units, let ship): .board(units: units, ship: ship)
        case .land(let ships, let point): .land(ships: ships, at: point)
        case .heal(let doctors, let target): .heal(doctors: doctors, target: target)
        }
    }

    /// The button's second line: what it costs, or for demolition what it returns.
    public var costLine: String {
        if case .demolish = action, let back = refund { return "Returns \(InterfaceText.cost(back))" }
        if case .dismiss(let units) = action { return units.count == 1 ? "Frees 1 place" : "Frees \(units.count) places" }
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
    /// From 0 to 1, for construction, training and an advance.
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
    public var build: [ActionOffer] = []
    public var demolish: [ActionOffer] = []
    public var dismiss: [ActionOffer] = []
    public var reseed: [ActionOffer] = []
    public var car: [ActionOffer] = []
    /// Boarding, landing and healing: the orders a right-click also gives.
    public var orders: [ActionOffer] = []
    /// A building the player is placing, for the panel's hint.
    public var placing: BuildingKind?

    public var actions: [ActionOffer] { train + reseed + car + orders + build + demolish + dismiss }
    public var sections: [(section: ActionOffer.Section, offers: [ActionOffer])] {
        [(.train, train), (.reseed, reseed), (.car, car), (.orders, orders), (.build, build), (.demolish, demolish),
         (.dismiss, dismiss)].filter { !$0.1.isEmpty }
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
            var (text, progress) = InterfaceText.describe(e.activity, of: e.kind, age: ownerAge)
            if let job = e.job, job == .healing { text = "Healing" }
            // A navy ship's troops, and what it is making (requirements 16 and 18).
            if let aboard = e.passengers {
                text += "; \(aboard) of \(catalogue.shipCargo) troops aboard"
                if let making = e.making {
                    let (line, done) = InterfaceText.describe(making, of: e.kind, age: ownerAge)
                    text += "; \(line)"
                    progress = done
                }
            }
            let civ = view.players.first { $0.id == e.owner }?.civilization.name ?? "Unknown"
            let relation = e.owner == view.player ? "yours" : (view.isAlly(e.owner) ? "ally" : "opponent")
            content = .single(EntityDetail(id: e.id, kind: e.kind, name: InterfaceText.name(of: e, at: ownerAge),
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

        // Train at a single own maker: a building that stands complete, or a
        // navy ship, which makes units whilst at the shore (requirement 18).
        if selected.count == 1, let b = own.first, !Self.isUnderConstruction(b) {
            train = catalogue.made(by: b.kind).filter { $0.age <= catalogue.lastAge }.map { made in
                let unit = made.unit
                let u = catalogue.stats(unit)
                let name = unit.stageName(at: view.age)
                let detail = b.kind == .unit(.navyShip) ? "Makes one \(name) on the shore, whilst the ship is at the shore."
                                                        : "Trains one \(name)."
                return ActionOffer(
                    id: "train-\(unit)", section: .train, title: name, detail: detail, cost: u.cost,
                    action: .train(at: b.id, unit: unit),
                    unavailable: planner.check(cost: u.cost, age: made.age, population: u.population),
                    shortcut: Self.trainKey(unit), icon: .unit(unit),
                    iconSubject: planner.subject(.unit(unit)))
            }
        }

        // Reseed a single own farm that has run dry (ruled 2026-11-19); its farmer
        // does so on his own, so the button serves a farm left without one.
        if selected.count == 1, let b = own.first, b.kind == .building(.farm), let left = b.remaining {
            let cost = catalogue.gathering.farmReseed
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

        // Demolish a single own building: the player's idle workers do it, or
        // the nearest worker where none is idle.
        let workers = view.entities.filter { $0.owner == view.player && $0.kind == .unit(.worker) }
        if selected.count == 1, let b = own.first, case .building(let kind) = b.kind {
            let idle = workers.filter { $0.activity == .idle }.map(\.id)
            let nearest = workers.min {
                let a = ($0.position.x - b.position.x, $0.position.y - b.position.y)
                let c = ($1.position.x - b.position.x, $1.position.y - b.position.y)
                return (a.0 * a.0 + a.1 * a.1, $0.id) < (c.0 * c.0 + c.1 * c.1, $1.id)
            }
            let crew = idle.isEmpty ? nearest.map { [$0.id] } ?? [] : idle
            var why = gate
            if why == nil && crew.isEmpty { why = Unavailability(.notYours, "Needs a worker") }
            let back = catalogue.stats(kind).cost.share(catalogue.stats(kind).demolishReturn)
            demolish = [ActionOffer(
                id: "demolish", section: .demolish, title: kind.name,
                detail: "Workers pull it down and return part of its cost (\(InterfaceText.cost(back))).",
                cost: ResourceAmounts(), action: .demolish(workers: crew, building: b.id), unavailable: why,
                shortcut: "x", icon: nil, iconSubject: nil, refund: back)]
        }

        // A founder builds one town centre, free (ruled 2026-11-22).
        if own.contains(where: { $0.kind == .unit(.founder) }) && !own.contains(where: { $0.kind == .unit(.worker) }) {
            build = [ActionOffer(
                id: "found", section: .build, title: BuildingKind.townCentre.name,
                detail: "The founder builds it where you click, free; when it is finished, two workers appear and the founder becomes a worker.",
                cost: ResourceAmounts(), action: .place(.townCentre), unavailable: gate,
                shortcut: Self.buildKey(.townCentre), icon: .building(.townCentre),
                iconSubject: planner.subject(.building(.townCentre)))]
        }

        // Buildings for workers, of the ages reached.
        if own.contains(where: { $0.kind == .unit(.worker) }) {
            build = catalogue.buildings.filter { $0.age <= view.age }.map { b in
                ActionOffer(
                    id: "build-\(b.kind)", section: .build, title: b.kind.name, detail: "Workers construct it where you click.",
                    cost: b.cost, action: .place(b.kind), unavailable: planner.check(cost: b.cost, age: b.age),
                    shortcut: Self.buildKey(b.kind), icon: .building(b.kind), iconSubject: planner.subject(.building(b.kind)))
            }
        }

        orders = Self.shipAndCareOffers(own: own, view: view, catalogue: catalogue, gate: gate)

        // Dismiss the player's own units; a founder cannot be dismissed.
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

    }

    // MARK: Shortcuts

    /// Keys for the actions that are not tied to the selection.
    public static let pauseKey: Character = " "
    public static let advanceKey: Character = "n"
    public static let boardKey: Character = "v"
    public static let landKey: Character = "p"
    public static let healKey: Character = "e"
    /// The Delete key (backspace), which dismisses the selected people.
    public static let deleteKey: Character = "\u{8}"

    static func trainKey(_ unit: UnitKind) -> Character? {
        // F is left free: it finds the founder (ruled 2026-11-22).
        switch unit {
        case .worker: "w"
        case .doctor: "o"
        case .fishingBoat: "b"
        case .navyShip: "y"
        case .soldier1: "q"
        case .soldier2: "a"
        case .soldier3: "s"
        case .soldier4: "d"
        case .knight1: "r"
        case .knight2: "k"
        case .knight3: "u"
        case .cannon1: "j"
        case .cannon2: "g"
        case .car, .founder: nil
        }
    }

    static func buildKey(_ kind: BuildingKind) -> Character? {
        switch kind {
        case .townCentre: "t"
        case .house: "h"
        case .barracks: "b"
        case .tower: "w"
        // F is left free: it finds the founder (ruled 2026-11-22).
        case .farm: "r"
        case .stable: "l"
        case .castle: "c"
        case .boatHouse: "i"
        case .cannonFactory: "m"
        case .hospital: "o"
        }
    }

    // MARK: Boarding, landing and healing

    /// The buttons for the orders a right-click gives (requirements 13 and 16),
    /// each aimed at the nearest fitting target: the nearest navy ship of the
    /// player's with room, for troops to board; the nearest open shore tile, for
    /// a ship to land its troops on; the nearest wounded unit of the player's
    /// within the doctors' radius, for doctors to heal.
    static func shipAndCareOffers(own: [EntityView], view: PlayerView, catalogue: Catalogue,
                                  gate: Unavailability?) -> [ActionOffer] {
        func distance(_ a: MapPosition, _ b: MapPosition) -> Double { a.distance(to: b) }
        func nearest(_ candidates: [EntityView], to p: MapPosition) -> EntityView? {
            candidates.min { (distance($0.position, p), $0.id) < (distance($1.position, p), $1.id) }
        }
        var offers: [ActionOffer] = []

        let boarders = own.filter { if case .unit(let k) = $0.kind { return k.boardsShips } else { return false } }
        if let first = boarders.first {
            let ships = view.entities.filter {
                $0.owner == view.player && $0.kind == .unit(.navyShip) && ($0.passengers ?? 0) < catalogue.shipCargo
            }
            let ship = nearest(ships, to: first.position)
            var why = gate
            if why == nil && ship == nil { why = Unavailability(.invalidTarget, "No navy ship of yours with room") }
            offers.append(ActionOffer(
                id: "board", section: .orders, title: "Board",
                detail: "The selected go aboard the nearest navy ship of yours with room, once it is at the shore; up to \(catalogue.shipCargo) a ship.",
                cost: ResourceAmounts(), action: .board(units: boarders.map(\.id), ship: ship?.id ?? EntityID(-1)),
                unavailable: why, shortcut: boardKey, icon: .unit(.navyShip), iconSubject: nil))
        }

        let loaded = own.filter { $0.kind == .unit(.navyShip) && ($0.passengers ?? 0) > 0 }
        if let ship = loaded.first {
            let shore = nearestShore(to: ship.position, view: view, catalogue: catalogue)
            var why = gate
            if why == nil && shore == nil { why = Unavailability(.invalidTarget, "No open shore near the ship") }
            offers.append(ActionOffer(
                id: "land", section: .orders, title: "Land",
                detail: "The ship sails to the nearest open shore and sets its troops down there.",
                cost: ResourceAmounts(), action: .land(ships: loaded.map(\.id), at: shore?.centre ?? ship.position),
                unavailable: why, shortcut: landKey, icon: nil, iconSubject: nil))
        }

        let doctors = own.filter { if case .unit(let k) = $0.kind { return catalogue.stats(k).healing ?? 0 > 0 } else { return false } }
        if let first = doctors.first, case .unit(let doctorKind) = first.kind {
            let radius = catalogue.stats(doctorKind).radius
            let wounded = view.entities.filter { e in
                guard e.owner == view.player, case .unit(let k) = e.kind, k.isUnit, !k.isAfloat, e.health < e.maxHealth,
                      !(doctors.count == 1 && e.id == first.id) else { return false }
                return radius.map { distance(e.position, first.position) <= $0 } ?? true
            }
            let target = nearest(wounded, to: first.position)
            var why = gate
            if why == nil && target == nil { why = Unavailability(.invalidTarget, "No wounded unit of yours near") }
            offers.append(ActionOffer(
                id: "heal", section: .orders, title: "Heal",
                detail: "The doctors heal the nearest wounded unit of yours up to its full health; more doctors heal it faster.",
                cost: ResourceAmounts(),
                action: .heal(doctors: doctors.map(\.id).filter { $0 != target?.id }, target: target?.id ?? EntityID(-1)),
                unavailable: why, shortcut: healKey, icon: nil, iconSubject: nil))
        }
        return offers
    }

    /// The open land tile nearest a point within six tiles: passable, and not
    /// covered by a building or a site that blocks it.
    static func nearestShore(to point: MapPosition, view: PlayerView, catalogue: Catalogue) -> GridPoint? {
        let occupied = Placement.occupied(buildings: view.entities.compactMap { e -> (kind: BuildingKind, origin: GridPoint)? in
            guard case .building(let kind) = e.kind else { return nil }
            return (kind, e.tile)
        }, sites: view.sites, catalogue: catalogue)
        let t = point.tile
        var best: (GridPoint, Double)?
        for y in (t.y - 6)...(t.y + 6) {
            for x in (t.x - 6)...(t.x + 6) {
                guard x >= 0, y >= 0, x < view.mapWidth, y < view.mapHeight else { continue }
                let tile = GridPoint(x, y)
                guard view.terrain(at: tile).isPassable, !occupied.contains(tile) else { continue }
                let d = tile.centre.distance(to: point)
                if d <= 6, best.map({ d < $0.1 || (d == $0.1 && tile < $0.0) }) ?? true { best = (tile, d) }
            }
        }
        return best?.0
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
                return Unavailability(.ageNotReached(age), "Needs the age of \(age.name)")
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
            SpriteSubject.of(kind, ownerAge: view.age, catalogue: catalogue)
        }
    }
}

extension EntityKind {
    var isWarfighterKind: Bool {
        if case .unit(let u) = self { return u.isWarfighter }
        return false
    }
}
