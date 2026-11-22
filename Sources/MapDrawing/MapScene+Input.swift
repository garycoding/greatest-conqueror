// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import GameCore
import SpriteKit

/// The arrow keys, which scroll the map whilst held.
public enum ArrowKey: Hashable, Sendable { case left, right, up, down }

/// The keys the map answers to.
public enum MapKey: Equatable, Sendable {
    case escape
    case arrow(ArrowKey)
    /// A number key, 0 to 9: with Command it sets a group, alone it recalls one.
    case digit(Int)
    /// Shift-C: the person's car (ruled 2026-11-21).
    case summonCar
    /// F: select the person's founder and centre the view on it (ruled 2026-11-22).
    case founder

    init?(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.shift, .command, .option, .control])
        switch event.keyCode {
        case 8 where modifiers == .shift: self = .summonCar
        case 3 where modifiers.isEmpty: self = .founder
        case 53: self = .escape
        case 123: self = .arrow(.left)
        case 124: self = .arrow(.right)
        case 125: self = .arrow(.down)
        case 126: self = .arrow(.up)
        default:
            guard let text = event.charactersIgnoringModifiers, text.count == 1, let digit = text.first?.wholeNumberValue,
                  (0...9).contains(digit) else { return nil }
            self = .digit(digit)
        }
    }
}

// The actions of the map, in scene points, so that they are tested without events;
// the event handlers below only convert and call them. Orders go only through
// `session.issue`.
extension MapScene {
    /// How far a drag must go before it is a box and not a click, in points.
    static let dragThreshold = 4.0

    // MARK: Selecting and placing

    /// A left click: place the building being placed, else select what is under the point.
    public func click(at point: CGPoint, additive: Bool = false) {
        if session.placing != nil {
            place(at: point, keepPlacing: additive)
            return
        }
        let hit = MapHitTesting.entity(at: point, in: session.view, geometry: geometry, catalogue: session.catalogue,
                                       drawnHeight: { [entityNodes] in entityNodes[$0.id]?.drawnHeight })
        session.selection = MapCommands.selection(afterClickOn: hit?.id, current: session.selection, additive: additive)
    }

    /// A double-click: select the player's own people on the screen of the kind
    /// and job of the one clicked.
    public func doubleClick(at point: CGPoint) {
        guard session.placing == nil else { return }
        let hit = MapHitTesting.entity(at: point, in: session.view, geometry: geometry, catalogue: session.catalogue,
                                       drawnHeight: { [entityNodes] in entityNodes[$0.id]?.drawnHeight })
        let onScreen = MapHitTesting.ownPeople(in: CGRect(origin: .zero, size: size), view: session.view, geometry: geometry)
        session.selection = MapCommands.selection(afterDoubleClickOn: hit?.id, onScreen: onScreen, view: session.view)
    }

    /// A dragged box: select the player's own people inside it.
    public func selectBox(from a: CGPoint, to b: CGPoint, additive: Bool = false) {
        let box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
        let boxed = MapHitTesting.ownPeople(in: box, view: session.view, geometry: geometry)
        session.selection = MapCommands.selection(afterBoxHolding: boxed, current: session.selection, additive: additive)
    }

    /// Place the building being placed with its footprint under the pointer: the
    /// selected workers are ordered to construct it. Where the footprint is not
    /// allowed, or no worker is selected, nothing is issued and the refusal is shown.
    func place(at point: CGPoint, keepPlacing: Bool) {
        guard let kind = session.placing else { return }
        let catalogue = session.catalogue
        let origin = Placement.origin(kind, centre: geometry.mapPosition(for: point), catalogue: catalogue)
        guard Placement.canPlace(kind, at: origin, in: session.view, catalogue: catalogue) else {
            session.lastRefusal = .placementBlocked
            return
        }
        // A founder founds a town centre, free, rather than constructing it (ruled 2026-11-22).
        if kind == .townCentre, let founder = session.ownSelection.first(where: { $0.kind == .unit(.founder) }) {
            session.issue(.found(founder: founder.id, at: origin))
            if !keepPlacing { session.placing = nil }
            return
        }
        let workers = session.ownSelection.filter { $0.kind == .unit(.worker) }.map(\.id)
        guard !workers.isEmpty else {
            session.lastRefusal = .notYours
            return
        }
        session.issue(.construct(workers: workers, building: kind, at: origin))
        if !keepPlacing { session.placing = nil }
    }

    // MARK: The contextual order

    /// A right-click: cancel a placement, else give the contextual order to the
    /// selected people (`MapCommands.contextualOrder`).
    public func rightClick(at point: CGPoint) {
        if session.placing != nil {
            session.placing = nil
            return
        }
        var target = MapHitTesting.target(at: point, in: session.view, geometry: geometry, catalogue: session.catalogue,
                                          drawnHeight: { [entityNodes] in entityNodes[$0.id]?.drawnHeight })
        if case .ground(let position) = target {
            target = .ground(MapPosition(x: min(max(position.x, 0), Double(session.view.mapWidth)),
                                         y: min(max(position.y, 0), Double(session.view.mapHeight))))
        }
        if let order = MapCommands.contextualOrder(on: target, view: session.view, selection: session.selection,
                                                     catalogue: session.catalogue) {
            session.issue(order)
        }
    }

    // MARK: Keys

    /// A key pressed. Returns whether the map used it.
    @discardableResult
    public func handleKeyDown(_ key: MapKey, command: Bool = false) -> Bool {
        switch key {
        case .escape:
            session.placing = nil
            dragStart = nil
            dragIsBox = false
            boxOutline.isHidden = true
            return true
        case .arrow(let arrow):
            heldArrows.insert(arrow)
            return true
        case .summonCar:
            session.issue(.summonCar)
            return true
        case .founder:
            return selectFounder()
        case .digit(let number):
            if command {
                session.groups[number] = session.ownSelection.map(\.id)
            } else if let group = session.groups[number] {
                let alive = group.filter { session.view.entity($0) != nil }
                if !alive.isEmpty { session.selection = alive }
            }
            return true
        }
    }

    /// Select the person's founder and centre the view on it; nothing happens
    /// while the person has none (ruled 2026-11-22).
    @discardableResult
    public func selectFounder() -> Bool {
        guard let founder = session.view.entities.first(where: { $0.owner == session.view.player && $0.kind == .unit(.founder) })
        else { return false }
        session.selection = [founder.id]
        setCamera(Camera(centre: founder.position, zoom: session.camera.zoom))
        return true
    }

    public func handleKeyUp(_ key: MapKey) {
        if case .arrow(let arrow) = key { heldArrows.remove(arrow) }
    }

    // MARK: The camera

    /// Shift what is drawn by `delta` scene points (the camera moves the other way).
    public func scroll(contentBy delta: CGVector) {
        setCamera(geometry.panned(contentBy: delta, mapWidth: session.view.mapWidth, mapHeight: session.view.mapHeight))
    }

    /// Zoom by a factor, within the limits of `Camera`, keeping the map under `anchor` in place.
    public func zoom(by factor: Double, about anchor: CGPoint) {
        setCamera(geometry.zoomed(by: factor, about: anchor, mapWidth: session.view.mapWidth, mapHeight: session.view.mapHeight))
    }

    // MARK: Dragging

    func beginDrag(at point: CGPoint) {
        dragStart = point
        dragIsBox = false
        pointer = point
    }

    func continueDrag(to point: CGPoint) {
        pointer = point
        guard let start = dragStart, session.placing == nil else { return }
        if !dragIsBox, hypot(point.x - start.x, point.y - start.y) < Self.dragThreshold { return }
        dragIsBox = true
        boxOutline.path = CGPath(rect: CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                                              width: abs(start.x - point.x), height: abs(start.y - point.y)), transform: nil)
        boxOutline.isHidden = false
    }

    func endDrag(at point: CGPoint, additive: Bool) {
        guard let start = dragStart else { return }
        let wasBox = dragIsBox
        dragStart = nil
        dragIsBox = false
        boxOutline.isHidden = true
        if wasBox { selectBox(from: start, to: point, additive: additive) } else { click(at: point, additive: additive) }
    }

    // MARK: Events

    public override func mouseDown(with event: NSEvent) { beginDrag(at: event.location(in: self)) }

    public override func mouseDragged(with event: NSEvent) { continueDrag(to: event.location(in: self)) }

    public override func mouseUp(with event: NSEvent) {
        let wasBox = dragIsBox
        endDrag(at: event.location(in: self), additive: event.modifierFlags.contains(.shift))
        // The first click of a double-click has selected the one clicked; the second widens it.
        if event.clickCount == 2, !wasBox { doubleClick(at: event.location(in: self)) }
    }

    public override func mouseMoved(with event: NSEvent) { pointer = event.location(in: self) }

    public override func rightMouseDown(with event: NSEvent) { rightClick(at: event.location(in: self)) }

    public override func keyDown(with event: NSEvent) {
        guard let key = MapKey(event) else { return }
        handleKeyDown(key, command: event.modifierFlags.contains(.command))
    }

    public override func keyUp(with event: NSEvent) {
        if let key = MapKey(event) { handleKeyUp(key) }
    }

    /// A two-finger drag scrolls; a mouse wheel, or Command with two fingers, zooms.
    public override func scrollWheel(with event: NSEvent) {
        let location = event.location(in: self)
        if event.hasPreciseScrollingDeltas, !event.modifierFlags.contains(.command) {
            scroll(contentBy: CGVector(dx: event.scrollingDeltaX, dy: -event.scrollingDeltaY))
        } else {
            let rate = event.hasPreciseScrollingDeltas ? 0.01 : 0.04
            zoom(by: exp(event.scrollingDeltaY * rate), about: location)
        }
    }

    public override func magnify(with event: NSEvent) {
        zoom(by: 1 + event.magnification, about: event.location(in: self))
    }
}
