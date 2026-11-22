// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Network
import Observation

/// A match announced on the LAN, as a browser finds it.
public struct FoundMatch: Hashable, Sendable, Identifiable {
    /// The name under which the host announces the match: its lobby's.
    public var name: String
    public var endpoint: NWEndpoint
    public var id: String { name }

    public init(name: String, endpoint: NWEndpoint) {
        self.name = name
        self.endpoint = endpoint
    }
}

/// Lists the matches hosted on the LAN, announced through Bonjour as
/// `NetService.type`, so that nobody types an address.
@MainActor
@Observable
public final class MatchBrowser {
    /// The matches found, by name.
    public private(set) var matches: [FoundMatch] = []
    /// Why matches cannot be looked for, if they cannot.
    public private(set) var problem: String?
    @ObservationIgnored private var browser: NWBrowser?

    public init() {}

    public func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: NetService.type, domain: nil), using: NWParameters())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let found = results.compactMap { result -> FoundMatch? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return FoundMatch(name: name, endpoint: result.endpoint)
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.found(found) } }
        }
        browser.stateUpdateHandler = { [weak self] state in
            let problem: String? = switch state {
            case .failed(let error), .waiting(let error): Self.describe(error)
            default: nil
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.problem = problem } }
        }
        browser.start(queue: DispatchQueue(label: "GameNetwork.MatchBrowser"))
        self.browser = browser
    }

    public func stop() {
        browser?.cancel()
        browser = nil
        matches = []
    }

    /// The same match may be found on more than one interface; it is listed once.
    private func found(_ found: [FoundMatch]) {
        guard browser != nil else { return }
        var seen = Set<String>()
        matches = found.sorted { $0.name < $1.name }.filter { seen.insert($0.name).inserted }
    }

    private nonisolated static func describe(_ error: NWError) -> String {
        // kDNSServiceErr_PolicyDenied: the person has not allowed local network access.
        if case .dns(let code) = error, code == -65570 {
            return "This Mac does not let the game look for matches on the local network. Allow it in System Settings, under Privacy & Security, Local Network."
        }
        return "Matches cannot be looked for on the network: \(error.localizedDescription)"
    }
}
