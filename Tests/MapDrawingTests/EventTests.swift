// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import Artwork
import GameCore
import SpriteKit
import Testing
@testable import MapDrawing

/// The events of the window system reach the scene's actions through `MapSKView`.
@MainActor
@Suite struct EventTests {
    func host() -> (MapSKView, NSWindow, MapScene, PlayerSession, OrderLog) {
        let (session, log) = makeSession(Samples.townsAgeOpening())
        let view = MapSKView(frame: CGRect(origin: .zero, size: screenSize))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: true)
        window.contentView = view
        let scene = MapScene(session: session, sprites: EmptySpriteSource(), size: screenSize)
        view.presentScene(scene)
        return (view, window, scene, session, log)
    }

    func mouse(_ type: NSEvent.EventType, at point: CGPoint, in window: NSWindow, flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    func key(_ characters: String, code: UInt16, in window: NSWindow, down: Bool = true, flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: flags, timestamp: 0,
                         windowNumber: window.windowNumber, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }

    @Test func clickAndRightClickAreHandedToTheScene() {
        let (view, window, scene, session, log) = host()
        let worker = scene.geometry.scenePoint(for: MapPosition(x: 12, y: 9))
        view.mouseDown(with: mouse(.leftMouseDown, at: CGPoint(x: worker.x, y: worker.y + 20), in: window))
        view.mouseUp(with: mouse(.leftMouseUp, at: CGPoint(x: worker.x, y: worker.y + 20), in: window))
        #expect(session.selection == [EntityID(2)])
        let ground = scene.geometry.scenePoint(for: MapPosition(x: 4.5, y: 20.5))
        view.rightMouseDown(with: mouse(.rightMouseDown, at: ground, in: window))
        #expect(log.orders == [.move(units: [EntityID(2)], to: MapPosition(x: 4.5, y: 20.5))])
    }

    @Test func shiftClickAddsToTheSelection() {
        let (view, window, scene, session, _) = host()
        for (x, y, shift) in [(12.0, 9.0, false), (5.0, 6.0, true)] {
            let p = scene.geometry.scenePoint(for: MapPosition(x: x, y: y))
            let at = CGPoint(x: p.x, y: p.y + 20)
            view.mouseDown(with: mouse(.leftMouseDown, at: at, in: window, flags: shift ? .shift : []))
            view.mouseUp(with: mouse(.leftMouseUp, at: at, in: window, flags: shift ? .shift : []))
        }
        #expect(session.selection == [EntityID(2), EntityID(3)])
    }

    @Test func keysAreMappedToArrowsDigitsAndEscape() {
        let (view, window, scene, session, _) = host()
        session.selection = [EntityID(2)]
        view.keyDown(with: key("1", code: 18, in: window, flags: .command))
        #expect(session.groups[1] == [EntityID(2)])
        session.selection = []
        view.keyDown(with: key("1", code: 18, in: window))
        #expect(session.selection == [EntityID(2)])
        view.keyDown(with: key("\u{F702}", code: 123, in: window))
        #expect(scene.heldArrows == [.left])
        view.keyUp(with: key("\u{F702}", code: 123, in: window, down: false))
        #expect(scene.heldArrows.isEmpty)
        session.placing = .house
        view.keyDown(with: key("\u{1B}", code: 53, in: window))
        #expect(session.placing == nil)
        #expect(view.performKeyEquivalent(with: key("2", code: 19, in: window, flags: .command)))
    }

    @Test func zoomingMultipliesTheSessionsZoom() throws {
        let (view, _, _, session, _) = host()
        let before = session.camera.zoom
        // A magnify event cannot be built directly; the scene's action is the same.
        view.mapSceneForTest?.zoom(by: 1.25, about: CGPoint(x: 720, y: 450))
        #expect(abs(session.camera.zoom - before * 1.25) < 1e-9)
    }
}

extension MapSKView {
    var mapSceneForTest: MapScene? { scene as? MapScene }
}
