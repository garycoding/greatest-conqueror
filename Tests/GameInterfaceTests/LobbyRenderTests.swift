// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import Foundation
import GameCore
import SwiftUI
import Testing
@testable import GameInterface

/// Renders the screens of a match across the LAN, as `everyViewRendersForBothSamples` does the rest.
@MainActor
@Test func theLANScreensRender() {
    #expect(renderHosted("lan-new-match-open-seat", width: 820, height: 1000) {
        NewMatchView(model: hostedModel(), onStart: { _ in }, onHost: { _ in }, onCancel: {})
    })

    // Six seats on one Mac, in a window of 1440 by 900 as the app lays it out.
    var six = NewMatchModel(maxPlayers: 6)
    for _ in 0..<4 { six.addComputerPlayer() }
    #expect(renderHosted("lan-new-match-six-seats-window", width: 1440, height: 900) {
        NewMatchView(model: six, onStart: { _ in }).padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    })
    #expect(renderHosted("lan-new-match-two-seats-window", width: 1440, height: 900) {
        NewMatchView(model: NewMatchModel(maxPlayers: 6), onStart: { _ in }).padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    })

    // The lobby as the host, waiting and ready; as a joiner before and after choosing; a resumed match.
    #expect(render("lan-lobby-host-waiting", width: 820, height: 420) {
        LobbyView(model: LobbyModel(lobby: sampleLobby(), me: PlayerID(0)), onLeave: {})
    })
    #expect(render("lan-lobby-host-ready", width: 820, height: 420) {
        LobbyView(model: LobbyModel(lobby: sampleLobby(joinerCivilization: .rome), me: PlayerID(0)), onLeave: {})
    })
    #expect(render("lan-lobby-joiner-choosing", width: 820, height: 600) {
        LobbyView(model: LobbyModel(lobby: sampleLobby(), me: PlayerID(1)), onLeave: {})
    })
    #expect(render("lan-lobby-joiner-chosen", width: 820, height: 600) {
        LobbyView(model: LobbyModel(lobby: sampleLobby(joinerCivilization: .rome), me: PlayerID(1)), onLeave: {})
    })
    #expect(render("lan-lobby-joiner-fixed", width: 820, height: 460) {
        LobbyView(model: LobbyModel(lobby: sampleLobby(joinerCivilization: .rome, fixed: true), me: PlayerID(1)), onLeave: {})
    })

    // The new-match screen as the app shows it, with hosting and joining offered.
    #expect(renderHosted("lan-new-match-with-join-window", width: 1440, height: 900) {
        NewMatchView(model: NewMatchModel(maxPlayers: 6, hostName: "Gary"), onStart: { _ in }, onHost: { _ in }, onJoin: {})
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    })

    // Joining.
    let found = [FoundMatch(id: "a", name: "Gary\u{2019}s match", host: "Gary", openSeats: 1),
                 FoundMatch(id: "b", name: "Saturday", host: "Ana", openSeats: 2)]
    #expect(renderHosted("lan-join-two-matches", width: 820, height: 380) {
        JoinView(matches: found, name: "Hyun", onJoin: { _, _ in }, onCancel: {})
    })
    // As discovery finds them: the name alone, without the host or the open seats.
    #expect(renderHosted("lan-join-discovered", width: 820, height: 380) {
        JoinView(matches: [FoundMatch(id: "a", name: "Gary\u{2019}s match"), FoundMatch(id: "b", name: "Saturday")],
                 name: "Hyun", onJoin: { _, _ in }, onCancel: {})
    })
    #expect(renderHosted("lan-join-empty-unnamed", width: 820, height: 320) {
        JoinView(matches: [], name: "", onJoin: { _, _ in }, onCancel: {})
    })

    // Notices over the whole screen, which shows the match paused while a person is dropped out.
    let bronze = Samples.farmsAgeSkirmish()
    var speed = MatchNotices(isHost: false)
    speed.receive(.speedChanged(to: 2, by: "Hyun"))
    #expect(render("lan-notice-speed", width: 1440, height: 900, scale: 1) {
        GameHUD(session: session(bronze)) { EmptyMap() } overlay: { layer(speed) }
    })
    var paused = bronze; paused.isPaused = true
    var hostDrop = MatchNotices(isHost: true)
    hostDrop.receive(.dropped(player: PlayerID(1), name: "Hyun"))
    #expect(render("lan-drop-host", width: 1440, height: 900, scale: 1) {
        GameHUD(session: session(paused)) { EmptyMap() } overlay: { layer(hostDrop) }
    })
    var joinerDrop = MatchNotices(isHost: false)
    joinerDrop.receive(.dropped(player: PlayerID(2), name: "Ana"))
    #expect(render("lan-drop-joiner", width: 1440, height: 900, scale: 1) {
        GameHUD(session: session(paused)) { EmptyMap() } overlay: { layer(joinerDrop) }
    })
    var hostLeft = MatchNotices(isHost: false)
    hostLeft.receive(.hostLeaving)
    #expect(render("lan-host-left", width: 1440, height: 900, scale: 1) {
        GameHUD(session: session(paused)) { EmptyMap() } overlay: { layer(hostLeft) }
    })
}

@MainActor
private func layer(_ notices: MatchNotices) -> MatchNoticeLayer {
    MatchNoticeLayer(notices: notices, onBannerExpired: { _ in }, onHandToComputer: { _, _ in }, onLeave: {})
}

/// Renders through an `NSHostingView`, which draws AppKit controls such as a text
/// field that `ImageRenderer` leaves as a placeholder. Written where `render` writes.
@MainActor
private func renderHosted<V: View>(_ name: String, width: CGFloat, height: CGFloat, @ViewBuilder _ content: () -> V) -> Bool {
    let view = NSHostingView(rootView: content().frame(width: width, height: height).environment(\.colorScheme, .light))
    view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    view.appearance = NSAppearance(named: .aqua)
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard rep.pixelsWide > 0 else { return false }
    if let dir = ProcessInfo.processInfo.environment["COP_RENDERS"],
       let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }
    return true
}
