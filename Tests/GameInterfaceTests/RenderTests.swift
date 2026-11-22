// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import Foundation
import GameCore
import SwiftUI
import Testing
@testable import GameInterface

/// Renders each view and the whole screen to PNG files, for looking at. The
/// directory is `COP_RENDERS` where set; otherwise the images are rendered and
/// checked but not written.
@MainActor
func render<V: View>(_ name: String, width: CGFloat, height: CGFloat, scale: CGFloat = 2, @ViewBuilder _ content: () -> V) -> Bool {
    let framed = content()
        .frame(width: width, height: height)
        .environment(\.colorScheme, .light)
    let renderer = ImageRenderer(content: framed)
    renderer.scale = scale
    guard let image = renderer.cgImage else { return false }
    guard Int(width * scale) == image.width, Int(height * scale) == image.height else { return false }
    if let dir = ProcessInfo.processInfo.environment["COP_RENDERS"] {
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: url) }
    }
    return true
}

@MainActor
func session(_ view: PlayerView, select ids: [EntityID] = [], placing: BuildingKind? = nil) -> PlayerSession {
    let s = makeSession(view, select: ids).0
    s.placing = placing
    s.camera = Camera(centre: MapPosition(x: 12, y: 12))
    return s
}

struct EmptyMap: View {
    var body: some View {
        ZStack {
            Color(red: 0.74, green: 0.80, blue: 0.62)
            Text("map").font(.custom("Futura-Medium", size: 18)).foregroundStyle(Color.black.opacity(0.35))
        }
    }
}

@MainActor
@Test func everyViewRendersForBothSamples() {
    let stone = Samples.townsAgeOpening()
    var stoneRoom = stone
    stoneRoom.populationLimit = 10
    var advance = stone
    advance.resources = ResourceAmounts([.food: 400, .wood: 150, .gold: 50])
    let bronze = Samples.farmsAgeSkirmish()
    let samples: [(String, PlayerView)] = [("stone", stone), ("bronze", bronze)]

    for (name, view) in samples {
        #expect(render("\(name)-resource-bar", width: 1440, height: 44) { ResourceBar(session: session(view)) })
        #expect(render("\(name)-minimap", width: 330, height: 165) { MiniMap(session: session(view)) })
        #expect(render("\(name)-age-progress", width: 220, height: 130) { AgeProgress(session: session(view)) })
        #expect(render("\(name)-pause", width: 140, height: 44) { PauseButton(session: session(view)).padding(5) })
    }
    #expect(render("stone-age-progress-ready", width: 220, height: 130) { AgeProgress(session: session(advance)) })
    var paused = stone; paused.isPaused = true
    #expect(render("stone-pause-paused", width: 140, height: 44) { PauseButton(session: session(paused)).padding(5) })

    // The selection panel.
    let tc = stone.id(of: .building(.townCentre))
    #expect(render("stone-panel-town-centre-at-limit", width: 1000, height: 250) { SelectionPanel(session: session(stone, select: [tc])).padding(8) })
    #expect(render("stone-panel-town-centre-room", width: 1000, height: 250) { SelectionPanel(session: session(stoneRoom, select: [tc])).padding(8) })
    #expect(render("stone-panel-worker", width: 1000, height: 250) {
        SelectionPanel(session: session(stone, select: [stone.id(of: .unit(.worker))], placing: .house)).padding(8)
    })
    #expect(render("stone-panel-nothing", width: 1000, height: 250) { SelectionPanel(session: session(stone)).padding(8) })
    #expect(render("stone-panel-hunters", width: 1000, height: 250) {
        SelectionPanel(session: session(stone, select: stone.ids(ofUnits: [.worker]))).padding(8)
    })
    #expect(render("bronze-panel-barracks", width: 1000, height: 250) {
        SelectionPanel(session: session(bronze, select: [bronze.id(of: .building(.barracks))])).padding(8)
    })
    #expect(render("bronze-panel-army-and-workers", width: 1000, height: 260) {
        SelectionPanel(session: session(bronze, select: bronze.ids(ofUnits: [.worker, .soldier1, .knight2]))).padding(8)
    })
    #expect(render("bronze-panel-enemy-town-centre", width: 1000, height: 250) {
        SelectionPanel(session: session(bronze, select: [bronze.id(of: .building(.townCentre), owner: PlayerID(1))])).padding(8)
    })
    #expect(render("bronze-panel-spearman", width: 1000, height: 250) {
        let spear = bronze.entities.first { $0.owner == bronze.player && $0.kind == .unit(.soldier1) }!.id
        return SelectionPanel(session: session(bronze, select: [spear])).padding(8)
    })

    // The banner, the match screens.
    let banner = session(stone); banner.lastRefusal = .populationLimit
    #expect(render("refusal-banner", width: 420, height: 60) { RefusalBanner(session: banner).padding(8) })
    #expect(render("new-match", width: 820, height: 520) { NewMatchView(onStart: { _ in }, onCancel: {}) })
    var won = stone; won.outcome = .won(TeamID(0))
    var lost = stone; lost.outcome = .won(TeamID(1))
    #expect(render("match-over-victory", width: 520, height: 260) { MatchOverView(session: session(won), onClose: {}) })
    #expect(render("match-over-defeat", width: 520, height: 260) { MatchOverView(session: session(lost), onClose: {}) })

    // The whole screen, with an empty map slot, at the size of a 1440 x 900 window.
    #expect(render("stone-hud-town-centre", width: 1440, height: 900, scale: 1) {
        GameHUD(session: session(stone, select: [tc])) { EmptyMap() }
    })
    #expect(render("stone-hud-worker-placing", width: 1440, height: 900, scale: 1) {
        let s = session(stoneRoom, select: [stone.id(of: .unit(.worker))], placing: .house)
        s.lastRefusal = .notEnough(ResourceAmounts([.wood: 60]))
        return GameHUD(session: s) { EmptyMap() }
    })
    #expect(render("bronze-hud-barracks", width: 1440, height: 900, scale: 1) {
        let s = session(bronze, select: [bronze.id(of: .building(.barracks))])
        s.lastRefusal = .populationLimit
        return GameHUD(session: s) { EmptyMap() }
    })
    #expect(render("bronze-hud-army", width: 1440, height: 900, scale: 1) {
        GameHUD(session: session(bronze, select: bronze.ids(ofUnits: [.soldier1, .knight2]))) { EmptyMap() }
    })
    var bronzePaused = bronze; bronzePaused.isPaused = true
    #expect(render("bronze-hud-paused", width: 1440, height: 900, scale: 1) { GameHUD(session: session(bronzePaused)) { EmptyMap() } })
    var bronzeWon = bronze; bronzeWon.outcome = .won(TeamID(0))
    #expect(render("bronze-hud-victory", width: 1440, height: 900, scale: 1) { GameHUD(session: session(bronzeWon)) { EmptyMap() } })
}
