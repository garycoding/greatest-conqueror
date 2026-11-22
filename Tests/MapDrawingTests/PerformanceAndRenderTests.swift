// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import Artwork
import CoreGraphics
import Foundation
import GameCore
import ImageIO
import SpriteKit
import Testing
import UniformTypeIdentifiers
@testable import MapDrawing

@MainActor
@Suite struct PerformanceAndRenderTests {
    /// With 1,200 placeholder people in view, building and updating the nodes from a
    /// new view takes under 4 ms on average. The limit is enforced in a release build
    /// (`swift test -c release`); a debug build, which is many times slower, only checks
    /// that the work completes.
    @Test func updatingTwelveHundredPeopleFromANewViewTakesUnderFourMilliseconds() {
        let first = crowd(1_200)
        let (session, _) = makeSession(first, camera: Camera(centre: MapPosition(x: 16, y: 16), zoom: 0.5))
        let scene = MapScene(session: session, sprites: EmptySpriteSource(), size: screenSize)
        #expect(scene.entityNodeCount == first.entities.count)

        // Views in which everybody has moved, as after each step of the simulation.
        let views = (1...120).map { i -> PlayerView in
            var view = crowd(1_200, shift: Double(i) * 0.05)
            view.tick = i
            return view
        }
        let clock = ContinuousClock()
        // Warm up: the first updates fill the caches of textures.
        for view in views.prefix(10) { session.update(view); scene.updateFromSession() }
        var total = Duration.zero
        for view in views.dropFirst(10) {
            session.update(view)
            total += clock.measure { scene.updateFromSession() }
        }
        // The nodes show the last view.
        let last = views[views.count - 1]
        for entity in last.entities.suffix(50) {
            let screen = Projection.screen(entity.position)
            let node = scene.entityNodes[entity.id]!
            #expect(abs(node.position.x - screen.x) < 1e-3 && abs(node.position.y - screen.y) < 1e-3)
        }
        let average = total / (views.count - 10)
        let milliseconds = Double(average.components.attoseconds) / 1e15 + Double(average.components.seconds) * 1000
        print("MapScene update with 1,200 people: \(milliseconds) ms on average")
        #if DEBUG
        #expect(milliseconds < 400)
        #else
        #expect(milliseconds < 4)
        #endif

        // The same with people arriving and leaving: each view drops 20 and adds 20 new ones,
        // so that nodes are built and removed as well as updated.
        var churned = views[views.count - 1]
        var nextID = (churned.entities.map(\.id.rawValue).max() ?? 0) + 1
        var churn = Duration.zero
        for i in 0..<100 {
            churned.tick += 1
            churned.entities.removeSubrange(10..<30)
            for j in 0..<20 {
                let position = MapPosition(x: 3 + Double((i * 5 + j) % 25), y: 3 + Double((i + j * 3) % 25))
                churned.entities.append(EntityView(id: EntityID(nextID), owner: PlayerID(0), kind: .unit(.worker), position: position,
                                                   tile: position.tile, facing: .right, health: 25, maxHealth: 25, activity: .moving))
                nextID += 1
            }
            session.update(churned)
            churn += clock.measure { scene.updateFromSession() }
        }
        #expect(scene.entityNodeCount == churned.entities.count)

        // A whole frame, including the change of animation frame that a quarter of a second brings.
        var frames = Duration.zero
        for i in 0..<100 {
            frames += clock.measure { scene.step(at: 1_000 + Double(i) * 0.25) }
        }
        let frameAverage = frames / 100
        let frameMilliseconds = Double(frameAverage.components.attoseconds) / 1e15 + Double(frameAverage.components.seconds) * 1000
        print("MapScene frame that changes the animation frame: \(frameMilliseconds) ms on average")
        #if !DEBUG
        #expect(frameMilliseconds < 4)
        #endif
        let churnAverage = churn / 100
        let churnMilliseconds = Double(churnAverage.components.attoseconds) / 1e15 + Double(churnAverage.components.seconds) * 1000
        print("MapScene update with 20 people replaced in each view: \(churnMilliseconds) ms on average")
        #if DEBUG
        #expect(churnMilliseconds < 400)
        #else
        #expect(churnMilliseconds < 4)
        #endif
    }

    // MARK: Rendering for inspection

    /// Renders the two sample views at 1440 x 900 into the directory named by the
    /// environment variable `MAPDRAWING_RENDERS`; skipped when it is not set.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MAPDRAWING_RENDERS"] != nil))
    func rendersTheSamples() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MAPDRAWING_RENDERS"]!, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // The Stone age opening, with the three workers selected.
        do {
            let view = Samples.stoneAgeOpening()
            let (session, _) = makeSession(view, camera: Camera(centre: MapPosition(x: 10.5, y: 10.5), zoom: 1))
            session.selection = [EntityID(2), EntityID(3), EntityID(4)]
            let image = render(session: session, sprites: EmptySpriteSource())
            try write(image, to: directory.appendingPathComponent("stone-age-opening.png"))
        }
        // The Bronze age skirmish, with an engineer and the fighters selected and a house being placed.
        do {
            let view = Samples.bronzeAgeSkirmish()
            let (session, _) = makeSession(view, camera: Camera(centre: MapPosition(x: 15, y: 10), zoom: 1))
            let own = view.entities.filter { $0.owner == view.player }
            session.selection = own.filter { [.unit(.engineer), .unit(.clubman), .unit(.spearman), .building(.townCentre)].contains($0.kind) }.map(\.id)
            session.placing = .house
            let image = render(session: session, sprites: EmptySpriteSource()) { scene in
                // A house beside the barracks (allowed), pointer over the open ground.
                scene.pointer = scene.geometry.scenePoint(for: MapPosition(x: 10, y: 4))
            }
            try write(image, to: directory.appendingPathComponent("bronze-age-skirmish.png"))
        }
        // The same view with the house over the town centre: not allowed.
        do {
            let view = Samples.bronzeAgeSkirmish()
            let (session, _) = makeSession(view, camera: Camera(centre: MapPosition(x: 12, y: 11), zoom: 1.3))
            session.placing = .barracks
            let image = render(session: session, sprites: EmptySpriteSource()) { scene in
                scene.pointer = scene.geometry.scenePoint(for: MapPosition(x: 11, y: 10))
            }
            try write(image, to: directory.appendingPathComponent("bronze-age-blocked-placement.png"))
        }
    }

    func render(session: PlayerSession, sprites: any SpriteSource, prepare: (MapScene) -> Void = { _ in }) -> CGImage {
        let size = CGSize(width: 1440, height: 900)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.ignoresSiblingOrder = true
        let scene = MapScene(session: session, sprites: sprites, size: size)
        view.presentScene(scene)
        prepare(scene)
        scene.step(at: 0)
        scene.step(at: 0.01)
        let texture = view.texture(from: scene)!
        let image = texture.cgImage()
        // Exactly 1440 x 900 pixels, whatever the display's scale.
        let context = CGContext(data: nil, width: 1440, height: 900, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1440, height: 900))
        return context.makeImage()!
    }

    func write(_ image: CGImage, to url: URL) throws {
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
