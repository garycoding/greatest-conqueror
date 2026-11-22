// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import GameCore
import SwiftUI

// MARK: Resource bar

/// The age's name, each resource of the ages reached with its amount, the
/// population of its limit, and the civilization.
public struct ResourceBar: View {
    let session: PlayerSession

    public init(session: PlayerSession) { self.session = session }

    public var body: some View {
        let model = ResourceBarModel(view: session.view)
        HStack(spacing: 18) {
            HStack(spacing: 8) {
                Circle().fill(model.civilization.map(Palette.colour(of:)) ?? Palette.paperDeep)
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1.2)).frame(width: 16, height: 16)
                Text(model.civilizationName).font(Typeface.text(15, bold: true))
            }
            Text("\(model.ageName) Age")
                .font(Typeface.text(13, bold: true))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .cartoonBox(fill: Palette.ochre.opacity(0.55), radius: 10, lineWidth: 1.2)
            Spacer(minLength: 8)
            ForEach(model.items) { item in
                HStack(spacing: 5) {
                    ResourceGlyph(resource: item.resource, size: 20)
                    Text("\(item.amount)").font(Typeface.text(15)).monospacedDigit()
                }
                .help(item.name)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.name) \(item.amount)")
            }
            HStack(spacing: 5) {
                PersonGlyph(kind: .worker).frame(width: 20, height: 20)
                Text(model.populationText).font(Typeface.text(15)).monospacedDigit()
                    .foregroundStyle(model.isPopulationFull ? Palette.brick : Palette.ink)
            }
            .help("Population of its limit")
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .cartoonBox(fill: Palette.paper, radius: 0, lineWidth: 1.5)
    }
}

// MARK: Buttons

/// A button of the panels. It stays enabled when it cannot act: its tooltip and
/// its refusal line say why, and pressing it shows the refusal.
struct ActionButton: View {
    let offer: ActionOffer
    let session: PlayerSession
    var wide = false

    var body: some View {
        Button { offer.perform(in: session) } label: {
            HStack(alignment: .top, spacing: 6) {
                if let icon = offer.icon {
                    EntityIcon(kind: icon, subject: offer.iconSubject, size: 24)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(offer.title).font(Typeface.text(11.5, bold: true)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if let key = offer.shortcut { KeyBadge(key: key) }
                    }
                    Text(offer.costLine).font(Typeface.text(9.5)).fixedSize(horizontal: false, vertical: true)
                    if let why = offer.unavailable {
                        Text(why.explanation).font(Typeface.text(9)).foregroundStyle(Palette.brick)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .foregroundStyle(offer.isAvailable ? Palette.ink : Palette.inkSoft)
            .padding(.horizontal, 7).padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
            .cartoonBox(fill: offer.isAvailable ? Palette.paper : Palette.paperDeep.opacity(0.6), radius: 5, lineWidth: 1.2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(offer.tooltip)
        .keyboardShortcut(offer.shortcut.map { KeyboardShortcut(KeyEquivalent($0), modifiers: []) })
        .accessibilityLabel(offer.title)
        .accessibilityHint(offer.unavailable?.explanation ?? "Cost \(InterfaceText.cost(offer.cost))")
    }
}

// MARK: Selection panel

/// One selected entity in full; several as counts by kind. Own buildings and
/// people offer their actions, each with its cost and, where it cannot act now,
/// the reason.
public struct SelectionPanel: View {
    let session: PlayerSession

    public init(session: PlayerSession) { self.session = session }

    public var body: some View {
        let model = PanelModel(session: session)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                switch model.content {
                case .nothing:
                    Text("Nothing selected").font(Typeface.text(14, bold: true))
                    Text("Click a person or a building on the map, or drag a box around several.")
                        .font(Typeface.text(11)).foregroundStyle(Palette.inkSoft)
                case .single(let detail):
                    HStack(spacing: 8) {
                        EntityIcon(kind: detail.kind, subject: nil, size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(detail.name).font(Typeface.text(16, bold: true))
                            Text(detail.ownerLine).font(Typeface.text(11)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    HStack(spacing: 6) {
                        Text("Health").font(Typeface.text(10.5))
                        MeterBar(fraction: detail.healthFraction, fill: detail.healthFraction > 0.35 ? Palette.sage : Palette.brick)
                        Text("\(detail.health)/\(detail.maxHealth)").font(Typeface.text(10.5)).monospacedDigit()
                    }
                    Text(detail.activity).font(Typeface.text(12))
                    if let progress = detail.progress {
                        HStack(spacing: 6) {
                            MeterBar(fraction: progress, fill: Palette.teal)
                            Text("\(Int((progress * 100).rounded(.down)))%").font(Typeface.text(10.5)).monospacedDigit()
                        }
                    }
                case .several(let total, let counts):
                    Text("\(total) selected").font(Typeface.text(16, bold: true))
                    ForEach(counts, id: \.kind) { entry in
                        HStack(spacing: 6) {
                            EntityIcon(kind: entry.kind, subject: nil, size: 20)
                            Text("\(entry.count) \u{00D7} \(entry.name)").font(Typeface.text(12))
                        }
                    }
                }
                if let placing = model.placing {
                    Text("Placing a \(placing.name.lowercased()): click the map to build; Esc to cancel.")
                        .font(Typeface.text(10.5, bold: true)).foregroundStyle(Palette.teal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 230, alignment: .topLeading)

            // Scrolls when a selection offers more than the panel holds.
            ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(model.sections, id: \.section) { group in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.section.heading.uppercased()).font(Typeface.text(9.5, bold: true)).foregroundStyle(Palette.inkSoft)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 5, alignment: .top)], alignment: .leading, spacing: 5) {
                            ForEach(group.offers) { offer in ActionButton(offer: offer, session: session) }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            }
            .scrollIndicators(.automatic)
        }
        .foregroundStyle(Palette.ink)
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cartoonBox()
    }
}

// MARK: Small map

/// The whole map as a diamond: explored terrain, the player's and allies'
/// entities, opponents in sight in their colours, and the camera's view as an
/// outline. A click or a drag sets the camera's centre.
public struct MiniMap: View {
    let session: PlayerSession
    /// The size of the map view the camera looks through, in points, for the outline.
    var viewport: CGSize

    public init(session: PlayerSession, viewport: CGSize = CGSize(width: 1100, height: 640)) {
        self.session = session; self.viewport = viewport
    }

    public var body: some View {
        GeometryReader { proxy in
            let view = session.view
            let geometry = MiniMapGeometry(mapWidth: view.mapWidth, mapHeight: view.mapHeight, size: proxy.size)
            let raster = MiniMapRaster.image(for: view)
            let marked = MiniMapRaster.marked(view)
            let camera = session.camera
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.ink.opacity(0.9)))
                if let raster {
                    var layer = context
                    layer.concatenate(geometry.transform)
                    layer.draw(Image(decorative: raster, scale: 1).interpolation(.none),
                               in: CGRect(x: 0, y: 0, width: view.mapWidth, height: view.mapHeight))
                }
                for e in marked {
                    guard let civ = view.players.first(where: { $0.id == e.owner })?.civilization else { continue }
                    let p = geometry.point(for: e.position)
                    let isBuilding: Bool
                    if case .building = e.kind { isBuilding = true } else { isBuilding = false }
                    let d: CGFloat = isBuilding ? 6 : 3.5
                    let dot = Path(CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d))
                    context.fill(dot, with: .color(Palette.colour(of: civ)))
                    context.stroke(dot, with: .color(Palette.ink), lineWidth: 0.7)
                }
                let outline = Path(geometry.cameraRect(camera, viewport: viewport))
                var clipped = context
                clipped.clip(to: Path(CGRect(origin: .zero, size: size)))
                clipped.stroke(outline, with: .color(Color.white), lineWidth: 2.4)
                clipped.stroke(outline, with: .color(Palette.ink), lineWidth: 1)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                MiniMapControl.point(drag.location, geometry: geometry, session: session)
            })
        }
        .aspectRatio(2, contentMode: .fit)
        .cartoonBox(fill: Palette.paperDeep, radius: 4)
        .accessibilityLabel("Small map")
        .accessibilityHint("Click or drag to move the view")
    }
}

// MARK: Age progress

/// The advance to the next age: the Advance button with its cost, and the
/// advance's progress once it is under way.
public struct AgeProgress: View {
    let session: PlayerSession

    public init(session: PlayerSession) { self.session = session }

    public var body: some View {
        let model = AgeProgressModel(view: session.view, catalogue: session.catalogue)
        VStack(alignment: .leading, spacing: 6) {
            Text(model.caption).font(Typeface.text(12, bold: true)).fixedSize(horizontal: false, vertical: true)
            if model.nextAge != nil, model.advance != nil {
                HStack(spacing: 6) {
                    MeterBar(fraction: model.progress, fill: Palette.ochre, height: 11)
                    Text(model.percentText).font(Typeface.text(11)).monospacedDigit()
                }
                if let offer = model.advanceOffer, model.showsAdvance {
                    ActionButton(offer: offer, session: session, wide: true)
                } else {
                    Text("The town centre carries the advance forward.")
                        .font(Typeface.text(10)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.ink)
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .cartoonBox()
    }
}

// MARK: Pause

/// Pauses or resumes the match for everyone.
public struct PauseButton: View {
    let session: PlayerSession

    public init(session: PlayerSession) { self.session = session }

    public var body: some View {
        let model = PauseModel(view: session.view)
        Button { session.issue(model.order) } label: {
            HStack(spacing: 6) {
                PauseSymbol(paused: model.isPaused).frame(width: 14, height: 14)
                Text(model.title).font(Typeface.text(13, bold: true))
                KeyBadgeWide(text: "Space")
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12).frame(height: 34)
            .cartoonBox(fill: model.isPaused ? Palette.ochre.opacity(0.6) : Palette.paper, radius: 17, lineWidth: 1.3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])
        .help(model.isPaused ? "Resume the match for everyone (Space)" : "Pause the match for everyone (Space)")
    }
}

/// The sign over the map whilst the match is paused, and who paused it.
struct PauseSign: View {
    let model: PauseSignModel

    var body: some View {
        VStack(spacing: 2) {
            Text(model.title).font(Typeface.text(34, bold: true))
            if let by = model.byLine { Text(by).font(Typeface.text(15)) }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 28).padding(.vertical, 10)
        .cartoonBox(fill: Palette.paper.opacity(0.92), radius: 10, lineWidth: 1.8)
        .accessibilityElement(children: .combine)
    }
}

/// The match's speed, one step slower or faster, beside the pause button.
public struct SpeedControl: View {
    let model: SpeedControlModel

    public init(model: SpeedControlModel) { self.model = model }

    public var body: some View {
        HStack(spacing: 4) {
            step("\u{2212}", enabled: model.canGoSlower, help: "Slower (\u{2212})", action: model.slower)
            Text(model.text).font(Typeface.text(13, bold: true)).monospacedDigit().frame(minWidth: 34)
                .help("The match's speed; the Speed menu sets it too")
            step("+", enabled: model.canGoFaster, help: "Faster (=)", action: model.faster)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 6).frame(height: 34)
        .cartoonBox(fill: Palette.paper, radius: 17, lineWidth: 1.3)
    }

    private func step(_ title: String, enabled: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button { if enabled { action() } } label: {
            Text(title).font(Typeface.text(15, bold: true)).frame(width: 22, height: 22)
                .foregroundStyle(enabled ? Palette.ink : Palette.inkSoft)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct PauseSymbol: View {
    let paused: Bool

    var body: some View {
        Canvas { context, s in
            var p = Path()
            if paused {
                p.move(to: CGPoint(x: s.width * 0.15, y: 0)); p.addLine(to: CGPoint(x: s.width, y: s.height / 2))
                p.addLine(to: CGPoint(x: s.width * 0.15, y: s.height)); p.closeSubpath()
            } else {
                p.addRect(CGRect(x: s.width * 0.1, y: 0, width: s.width * 0.3, height: s.height))
                p.addRect(CGRect(x: s.width * 0.6, y: 0, width: s.width * 0.3, height: s.height))
            }
            context.fill(p, with: .color(Palette.ink))
        }
    }
}

struct KeyBadgeWide: View {
    let text: String

    var body: some View {
        Text(text).font(Typeface.text(9, bold: true)).foregroundStyle(Palette.ink)
            .padding(.horizontal, 4).frame(height: 14)
            .background(RoundedRectangle(cornerRadius: 3).fill(Palette.paperDeep))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 0.8))
    }
}

// MARK: Refusal banner

/// Shows `session.lastRefusal` for a few seconds and then sets it to `nil`.
public struct RefusalBanner: View {
    let session: PlayerSession
    var seconds: Double

    public init(session: PlayerSession, seconds: Double = 4) { self.session = session; self.seconds = seconds }

    public var body: some View {
        if let refusal = session.lastRefusal {
            Text(refusal.description)
                .font(Typeface.text(14, bold: true))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .cartoonBox(fill: Palette.ochre.opacity(0.85), radius: 8, lineWidth: 1.4)
                .task(id: refusal) { await Self.expire(session, after: seconds, matching: refusal) }
                .accessibilityAddTraits(.isStaticText)
        }
    }

    /// Wait, then clear the session's refusal if it is still the one shown.
    @MainActor
    public static func expire(_ session: PlayerSession, after seconds: Double, matching refusal: OrderRefusal) async {
        try? await Task.sleep(for: .seconds(seconds))
        if !Task.isCancelled, session.lastRefusal == refusal { session.lastRefusal = nil }
    }
}

// MARK: Match over

/// Victory or defeat, from the view's outcome and the player's team.
public struct MatchOverView: View {
    let session: PlayerSession
    var onClose: (() -> Void)?

    public init(session: PlayerSession, onClose: (() -> Void)? = nil) { self.session = session; self.onClose = onClose }

    public var body: some View {
        if let model = MatchOverModel(view: session.view) {
            VStack(spacing: 12) {
                Text(model.title).font(Typeface.text(40, bold: true))
                    .foregroundStyle(model.isVictory ? Palette.teal : Palette.brick)
                Text(model.message).font(Typeface.text(16)).multilineTextAlignment(.center)
                if let onClose {
                    Button(action: onClose) {
                        Text("Back to the menu").font(Typeface.text(14, bold: true))
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .cartoonBox(fill: Palette.ochre.opacity(0.7), radius: 16, lineWidth: 1.3)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 48).padding(.vertical, 32)
            .cartoonBox(fill: Palette.paper, radius: 10, lineWidth: 2)
        }
    }
}

// MARK: The whole screen

/// The bar at the top, the panel and the small map at the bottom, around a slot
/// for the map view, which another module supplies. `overlay` is laid over the
/// map above the paused sign and below the end of the match: the notices of a
/// match across the LAN (`MatchNoticeLayer`).
public struct GameHUD<MapSlot: View, Overlay: View>: View {
    let session: PlayerSession
    let map: MapSlot
    let overlay: Overlay
    let sprites: any SpriteSource
    let onClose: (() -> Void)?
    /// The people's names by seat, for the pause sign, in a match across the network.
    var names: [PlayerID: String]
    /// The speed beside the pause button, where the app gives one.
    var speed: SpeedControlModel?

    public init(session: PlayerSession, sprites: any SpriteSource = EmptySpriteSource(), names: [PlayerID: String] = [:],
                speed: SpeedControlModel? = nil,
                onMatchOver: (() -> Void)? = nil, @ViewBuilder map: () -> MapSlot, @ViewBuilder overlay: () -> Overlay) {
        self.session = session; self.sprites = sprites; self.names = names; self.speed = speed
        self.onClose = onMatchOver; self.map = map(); self.overlay = overlay()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ResourceBar(session: session)
                if let speed { SpeedControl(model: speed) }
                PauseButton(session: session).padding(.trailing, 8)
            }
            .background(Palette.paper)
            ZStack {
                map
                VStack {
                    RefusalBanner(session: session).padding(.top, 14)
                    Spacer()
                }
                if let sign = PauseSignModel(view: session.view, names: names) {
                    PauseSign(model: sign)
                }
                overlay
                if session.view.outcome != nil {
                    Palette.ink.opacity(0.35)
                    MatchOverView(session: session, onClose: onClose)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            HStack(alignment: .top, spacing: 8) {
                SelectionPanel(session: session)
                AgeProgress(session: session).frame(width: 220)
                MiniMap(session: session).frame(width: 340, height: 170).frame(maxHeight: .infinity)
            }
            .padding(8)
            .frame(height: 262)
            .clipped()
            .background(Palette.paperDeep)
            .overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 1.5) }
            // Cancels placing a building; zero-sized, not hidden, so that its shortcut stays live.
            Button("") { session.placing = nil }
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
        }
        .environment(\.spriteSource, sprites)
        .environment(\.teamColour, session.view.players.first { $0.id == session.view.player }
            .map { TeamColour.of($0.civilization) })
    }
}

extension GameHUD where Overlay == EmptyView {
    public init(session: PlayerSession, sprites: any SpriteSource = EmptySpriteSource(), names: [PlayerID: String] = [:],
                speed: SpeedControlModel? = nil, onMatchOver: (() -> Void)? = nil, @ViewBuilder map: () -> MapSlot) {
        self.init(session: session, sprites: sprites, names: names, speed: speed, onMatchOver: onMatchOver, map: map,
                  overlay: { EmptyView() })
    }
}
