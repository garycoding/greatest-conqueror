// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore

/// What the resource bar shows: the age, each resource,
/// the population, and the civilization.
public struct ResourceBarModel: Sendable {
    public struct Item: Hashable, Sendable, Identifiable {
        public var resource: Resource
        public var amount: Int
        public var id: Resource { resource }
        public var name: String { resource.name }
    }

    public var ageName: String
    public var items: [Item]
    public var population: Int
    public var populationLimit: Int
    public var civilization: Civilization?

    public var populationText: String { "\(population) of \(populationLimit)" }
    public var isPopulationFull: Bool { population >= populationLimit }
    public var civilizationName: String { civilization?.name ?? "" }

    public init(view: PlayerView) {
        ageName = view.age.title
        items = view.shownResources.map { Item(resource: $0, amount: view.resources[$0]) }
        population = view.population
        populationLimit = view.populationLimit
        civilization = view.me?.civilization
    }
}

/// The advance to the next age: its progress, and the means of beginning it at
/// a town centre (requirement 6).
public struct AgeProgressModel: Sendable {
    public var age: Age
    public var nextAge: Age?
    /// The advance under way, from 0 to 1; 0 when none is.
    public var progress: Double
    public var advance: AdvanceStats?
    /// The Advance button, whilst no advance is under way.
    public var advanceOffer: ActionOffer?

    public var isAdvancing: Bool { progress > 0 }

    /// Whether the Advance button is shown: no advance is under way and the catalogue has the step.
    public var showsAdvance: Bool { !isAdvancing && advanceOffer != nil }

    public var caption: String {
        guard let nextAge else { return "The last age is reached" }
        guard advance != nil else { return "The age of \(nextAge.name) is not yet part of the game" }
        if isAdvancing { return "Advancing to the age of \(nextAge.name)" }
        return "Next: the age of \(nextAge.name)"
    }

    public var percentText: String { "\(Int((progress * 100).rounded(.down)))%" }

    public init(view: PlayerView, catalogue: Catalogue) {
        age = view.age
        nextAge = view.age.next
        progress = InterfaceText.clamp(view.ageProgress)
        advance = catalogue.advance(from: view.age)
        guard nextAge != nil, let advance, progress <= 0 else { return }
        let centre = view.entities.first {
            $0.owner == view.player && $0.kind == .building(.townCentre) && !PanelModel.isUnderConstruction($0)
        }
        var why: Unavailability?
        if view.outcome != nil {
            why = Unavailability(.notNow, "The match is over")
        } else if view.isPaused {
            why = Unavailability(.notNow, "The match is paused")
        } else if centre == nil {
            why = Unavailability(.invalidTarget, "Needs a town centre")
        } else if !view.resources.covers(advance.cost) {
            let short = view.resources.shortfall(for: advance.cost)
            why = Unavailability(.notEnough(short), "Short of \(InterfaceText.cost(short))")
        }
        let target = nextAge?.name ?? ""
        let seconds = Int((Double(advance.time) / Double(Tick.rate)).rounded())
        advanceOffer = ActionOffer(
            id: "advance", section: .age, title: "Advance to the age of \(target)",
            detail: "At a town centre, in \(seconds) seconds.",
            cost: advance.cost, action: .advanceAge(at: centre?.id ?? EntityID(-1)), unavailable: why,
            shortcut: PanelModel.advanceKey, icon: nil, iconSubject: nil)
    }
}

/// The pause button: which way it turns and what it says.
public struct PauseModel: Sendable {
    public var isPaused: Bool
    public var title: String { isPaused ? "Resume" : "Pause" }
    /// The order the button issues.
    public var order: Order { .setPaused(!isPaused) }

    public init(view: PlayerView) { isPaused = view.isPaused }
}

/// The sign over the map whilst the match is paused (requirement 30): that it
/// is paused, and who paused it, named as the others know them: "you", a
/// person's name in a match across the network, or else a civilization.
public struct PauseSignModel: Hashable, Sendable {
    public var title = "Paused"
    /// "Paused by Hyun"; nil where the match is held for a person whose Mac has left.
    public var byLine: String?

    /// Nil whilst the match runs, or once it is over.
    public init?(view: PlayerView, names: [PlayerID: String] = [:]) {
        guard view.isPaused, view.outcome == nil else { return nil }
        guard let by = view.pausedBy else {
            byLine = nil
            return
        }
        if by == view.player {
            byLine = "Paused by you"
        } else if let name = names[by], !name.isEmpty {
            byLine = "Paused by \(name)"
        } else {
            byLine = "Paused by " + (view.players.first { $0.id == by }?.civilization.name ?? "another player")
        }
    }
}

/// The speed beside the pause button: one step slower or faster among the
/// speeds the match allows, which the Speed menu also sets.
public struct SpeedControlModel {
    public var speed: Double
    public var speeds: [Double]
    public var slower: () -> Void
    public var faster: () -> Void

    public init(speed: Double, speeds: [Double], slower: @escaping () -> Void, faster: @escaping () -> Void) {
        self.speed = speed; self.speeds = speeds; self.slower = slower; self.faster = faster
    }

    public var text: String { speed.formatted() + "\u{00D7}" }
    public var canGoSlower: Bool { speeds.first.map { speed > $0 } ?? false }
    public var canGoFaster: Bool { speeds.last.map { speed < $0 } ?? false }
}

/// Victory or defeat, from the outcome and the player's team.
public struct MatchOverModel: Hashable, Sendable {
    public var isVictory: Bool
    public var title: String
    public var message: String

    /// `nil` whilst the match is on.
    public init?(view: PlayerView) {
        guard let outcome = view.outcome else { return nil }
        let team: TeamID
        switch outcome { case .won(let t): team = t }
        isVictory = view.me?.team == team
        let winners = view.players.filter { $0.team == team }.map { $0.civilization.name }
        if isVictory {
            title = "Victory"
            message = "Your team has defeated every opponent."
        } else {
            title = "Defeat"
            message = winners.isEmpty ? "The match is lost." : "\(winners.joined(separator: " and ")) won the match."
        }
    }
}

/// The small map: the whole map as the diamond the main view shows it as, fitted
/// to a rectangle. The screen's 2 to 1 diamond, whatever the map's width and
/// height (`Projection`), fixes the rectangle's shape.
public struct MiniMapGeometry: Hashable, Sendable {
    public var mapWidth: Int
    public var mapHeight: Int
    public var size: CGSize

    public init(mapWidth: Int, mapHeight: Int, size: CGSize) {
        self.mapWidth = max(1, mapWidth); self.mapHeight = max(1, mapHeight); self.size = size
    }

    /// Points of the small map per point of the main view at zoom 1.
    public var scale: Double {
        let w = Double(mapWidth + mapHeight) * Projection.tileWidth / 2
        let h = Double(mapWidth + mapHeight) * Projection.tileHeight / 2
        return min(Double(size.width) / w, Double(size.height) / h)
    }

    private var minX: Double { -Double(mapHeight) * Projection.tileWidth / 2 }
    private var offsetX: Double { (Double(size.width) - Double(mapWidth + mapHeight) * Projection.tileWidth / 2 * scale) / 2 }
    private var offsetY: Double { (Double(size.height) - Double(mapWidth + mapHeight) * Projection.tileHeight / 2 * scale) / 2 }

    /// The affine map from tile units (x, y) to points of the small map.
    public var transform: CGAffineTransform {
        let s = scale, tw = Projection.tileWidth / 2, th = Projection.tileHeight / 2
        return CGAffineTransform(a: s * tw, b: s * th, c: -s * tw, d: s * th, tx: offsetX - s * minX, ty: offsetY)
    }

    /// Where a map position lies on the small map, y downward.
    public func point(for p: MapPosition) -> CGPoint {
        CGPoint(x: offsetX + ((p.x - p.y) * Projection.tileWidth / 2 - minX) * scale,
                y: offsetY + (p.x + p.y) * Projection.tileHeight / 2 * scale)
    }

    /// The map position under a point of the small map, held within the map.
    public func position(at point: CGPoint) -> MapPosition {
        let sx = (Double(point.x) - offsetX) / scale + minX
        let sy = -(Double(point.y) - offsetY) / scale
        let p = Projection.map(ScreenPoint(x: sx, y: sy))
        return MapPosition(x: min(max(p.x, 0), Double(mapWidth)), y: min(max(p.y, 0), Double(mapHeight)))
    }

    /// The camera's view as a rectangle on the small map, for a main view of `viewport` points.
    public func cameraRect(_ camera: Camera, viewport: CGSize) -> CGRect {
        let c = point(for: camera.centre)
        let w = Double(viewport.width) / camera.zoom * scale, h = Double(viewport.height) / camera.zoom * scale
        return CGRect(x: Double(c.x) - w / 2, y: Double(c.y) - h / 2, width: w, height: h)
    }
}

/// A click or drag on the small map, applied to the session.
@MainActor
public enum MiniMapControl {
    /// Centre the camera on the map position under `point`.
    public static func point(_ point: CGPoint, geometry: MiniMapGeometry, session: PlayerSession) {
        session.camera.centre = geometry.position(at: point)
    }
}

/// One pixel for each tile: the terrain where explored, black where not, and
/// duller where out of sight. The small map draws it under a transform.
public enum MiniMapRaster {
    public static func colour(of terrain: Terrain) -> (red: Double, green: Double, blue: Double) {
        switch terrain {
        case .grass: (0.63, 0.73, 0.46)
        case .dirt: (0.72, 0.58, 0.40)
        case .sand: (0.90, 0.82, 0.60)
        case .forest: (0.38, 0.54, 0.38)
        case .shallowWater: (0.56, 0.76, 0.80)
        case .deepWater: (0.34, 0.54, 0.65)
        }
    }

    /// The RGBA of a tile.
    public static func rgba(for view: PlayerView, x: Int, y: Int) -> [UInt8] {
        let p = GridPoint(x, y)
        let visibility = view.visibility(at: p)
        if visibility == .unexplored { return [0, 0, 0, 255] }
        let c = colour(of: view.terrain(at: p))
        let k = visibility == .visible ? 1.0 : 0.62
        func byte(_ v: Double) -> UInt8 { UInt8(max(0, min(255, (v * k * 255).rounded()))) }
        return [byte(c.red), byte(c.green), byte(c.blue), 255]
    }

    public static func image(for view: PlayerView) -> CGImage? {
        let w = view.mapWidth, h = view.mapHeight
        guard w > 0, h > 0, view.terrain.count == w * h, view.visibility.count == w * h else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(w * h * 4)
        for y in 0..<h { for x in 0..<w { bytes += rgba(for: view, x: x, y: y) } }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The entities the small map marks: those of the player and allies, and
    /// opponents' where in sight now.
    public static func marked(_ view: PlayerView) -> [EntityView] {
        view.entities.filter { e in
            view.isAlly(e.owner) || view.visibility(at: e.position.tile) == .visible
        }
    }
}
