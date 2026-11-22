// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import GameCore
import GameInterface
import MapDrawing
import SwiftUI

/// The window's content: the new-match screen, a lobby or the join screen
/// while a match across the LAN is set up, or the match.
struct RootView: View {
    let game: GameController

    var body: some View {
        Group {
            if let match = game.match {
                MatchScreen(session: match.session, game: game).id(ObjectIdentifier(match))
            } else if let client = game.client, let session = client.session {
                MatchScreen(session: session, game: game).id(ObjectIdentifier(session))
            } else if let client = game.client {
                centred {
                    if let lobby = client.lobby, let seat = client.seat {
                        LobbyView(model: LobbyModel(lobby: lobby, me: seat),
                                  onChooseCivilization: { game.chooseCivilization($0) },
                                  onLeave: { game.leaveLobby() })
                    } else {
                        ConnectingView(onCancel: { game.leaveLobby() })
                    }
                }
            } else if let server = game.server, let seat = server.hostSeat {
                centred {
                    VStack(spacing: 12) {
                        LobbyView(model: LobbyModel(lobby: server.lobby, me: seat),
                                  onStart: { game.startHosted() },
                                  onChooseCivilization: { game.chooseCivilization($0) },
                                  onLeave: { game.endMatch() })
                        if game.isResuming && !server.lobby.isReady {
                            Button("Start now, with computer players in the empty seats") { game.startWithoutAbsentPeople() }
                        }
                    }
                }
            } else if game.browser != nil {
                centred {
                    JoinView(matches: game.foundMatches, name: game.personName, message: game.joinProblem,
                             onNameChange: { game.personName = $0 },
                             onJoin: { game.join($0, as: $1) },
                             onCancel: { game.endMatch() })
                }
            } else {
                centred {
                    NewMatchView(model: NewMatchModel(maxPlayers: 6, hostName: game.personName),
                                 onStart: { game.start($0) },
                                 onHost: { game.host($0) },
                                 onJoin: { game.lookForMatches() })
                }
            }
        }
        .onChange(of: game.client?.state) { _, _ in game.clientStateChanged() }
        .alert("Greatest Conqueror", isPresented: Binding(get: { game.problem != nil }, set: { if !$0 { game.problem = nil } })) {
            Button("OK") { game.problem = nil }
        } message: {
            Text(game.problem ?? "")
        }
    }

    /// Centred in the window, and scrolled up and down where it is taller than the window.
    private func centred(@ViewBuilder _ content: () -> some View) -> some View {
        let content = content()
        return GeometryReader { window in
            ScrollView(.vertical) {
                content
                    .padding(24)
                    .frame(minWidth: window.size.width, minHeight: window.size.height)
            }
        }
    }
}

/// Shown on a joining Mac until the host answers.
private struct ConnectingView: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Joining the match\u{2026}").font(.title2)
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
        }
        .padding(24)
    }
}

/// A match on screen: the interface's panels around the map, with the
/// notices of a match across the LAN over it.
struct MatchScreen: View {
    let session: PlayerSession
    let game: GameController

    var body: some View {
        GameHUD(session: session, sprites: game.sprites, onMatchOver: { game.endMatch() }) {
            MapView(session: session, sprites: game.sprites)
        } overlay: {
            if game.isOnNetwork {
                MatchNoticeLayer(notices: game.notices,
                                 onBannerExpired: { game.notices.clearBanner($0) },
                                 onHandToComputer: { game.handToComputer($0, difficulty: $1) },
                                 onLeave: { game.endMatch() })
            }
        }
    }
}
