// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import Artwork
import GameCore
import SpriteKit
import SwiftUI

/// The SpriteKit view that hosts a `MapScene`. It hands every mouse, key, scroll
/// and pinch event to the scene itself, and keeps the keyboard focus.
public final class MapSKView: SKView {
    private var mapScene: MapScene? { scene as? MapScene }

    public override var acceptsFirstResponder: Bool { true }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        mapScene?.mouseDown(with: event)
    }

    public override func mouseDragged(with event: NSEvent) { mapScene?.mouseDragged(with: event) }
    public override func mouseUp(with event: NSEvent) { mapScene?.mouseUp(with: event) }
    public override func rightMouseDown(with event: NSEvent) { mapScene?.rightMouseDown(with: event) }
    public override func keyDown(with event: NSEvent) { mapScene?.keyDown(with: event) }
    public override func keyUp(with event: NSEvent) { mapScene?.keyUp(with: event) }
    public override func scrollWheel(with event: NSEvent) { mapScene?.scrollWheel(with: event) }
    public override func magnify(with event: NSEvent) { mapScene?.magnify(with: event) }

    /// Command with a number key sets a group; the menu would otherwise sound the alert.
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let key = MapKey(event), case .digit = key, let mapScene {
            return mapScene.handleKeyDown(key, command: true)
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// The map, for SwiftUI: a `MapScene` driven by a `PlayerSession` and drawn with
/// the sprites of a `SpriteSource`.
public struct MapView: NSViewRepresentable {
    public let session: PlayerSession
    public let sprites: any SpriteSource

    public init(session: PlayerSession, sprites: any SpriteSource) {
        self.session = session
        self.sprites = sprites
    }

    public func makeNSView(context: Context) -> MapSKView {
        let view = MapSKView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800))
        view.ignoresSiblingOrder = true
        view.presentScene(MapScene(session: session, sprites: sprites, size: view.bounds.size))
        return view
    }

    public func updateNSView(_ view: MapSKView, context: Context) {}
}
