// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
@testable import GameInterface
import AppKit
import SwiftUI
import Testing

/// The Bronze skirmish with an ally, Harappa, whose town centre the player can see.
func merchantSkirmish() -> PlayerView {
    var view = Samples.bronzeAgeSkirmish()
    let ally = PlayerID(2)
    view.players.append(PlayerSummary(id: ally, civilization: .harappa, team: view.players[0].team, isHuman: true,
                                      age: .bronze, isDefeated: false, isFounding: false))
    let id = EntityID((view.entities.map(\.id.rawValue).max() ?? 0) + 1)
    let stats = Catalogue.standard.stats(.townCentre)
    view.entities.append(EntityView(id: id, owner: ally, kind: .building(.townCentre), position: MapPosition(x: 3.5, y: 15.5),
                                    tile: GridPoint(2, 14), facing: .right, health: stats.health, maxHealth: stats.health,
                                    activity: .idle))
    return view
}

@MainActor
@Test func aMerchantsPanelOffersTradeAndSending() {
    let view = merchantSkirmish()
    let merchant = view.entities.first { $0.kind == .unit(.merchant) && $0.owner == view.player }!.id
    let m = PanelModel(view: view, catalogue: .standard, selection: [merchant])
    #expect(m.trade.map(\.id) == view.shownResources.map { "trade-\($0)" })
    #expect(m.carry.allSatisfy { $0.title.hasPrefix("Harappa: ") })
    #expect(!m.carry.isEmpty)
    if case .exchange(_, let give, let take) = m.trade.first(where: { $0.id == "trade-gold" })!.action {
        #expect(take == .gold && give != .gold)
    } else {
        Issue.record("trade-gold is not an exchange")
    }
    #expect(hostedRender("merchant-panel", width: 1440, height: 900) {
        GameHUD(session: session(view, select: [merchant])) { EmptyMap() }
    })
}

/// Renders through an `NSHostingView`, which draws the panel's scroll view that `ImageRenderer` leaves blank.
@MainActor
private func hostedRender<V: View>(_ name: String, width: CGFloat, height: CGFloat, @ViewBuilder _ content: () -> V) -> Bool {
    let view = NSHostingView(rootView: content().frame(width: width, height: height).environment(\.colorScheme, .light))
    view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    view.appearance = NSAppearance(named: .aqua)
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
    view.cacheDisplay(in: view.bounds, to: rep)
    if let dir = ProcessInfo.processInfo.environment["COP_RENDERS"], let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }
    return rep.pixelsWide > 0
}
