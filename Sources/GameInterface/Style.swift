// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import GameCore
import SwiftUI

/// The look of the interface: Cartoon Modern (docs/design.md), with flat muted
/// colour, a thin dark line laid a little out of register with the colour, and
/// Futura where the Mac has it.
enum Palette {
    static let paper = Color(red: 0.96, green: 0.92, blue: 0.82)
    static let paperDeep = Color(red: 0.89, green: 0.83, blue: 0.69)
    static let ink = Color(red: 0.17, green: 0.15, blue: 0.15)
    static let inkSoft = Color(red: 0.17, green: 0.15, blue: 0.15).opacity(0.65)
    static let teal = Color(red: 0.20, green: 0.45, blue: 0.45)
    static let ochre = Color(red: 0.85, green: 0.62, blue: 0.25)
    static let brick = Color(red: 0.72, green: 0.28, blue: 0.20)
    static let sage = Color(red: 0.55, green: 0.65, blue: 0.42)

    static func colour(of civilization: Civilization) -> Color {
        let c = TeamColour.of(civilization)
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    static func colour(of resource: Resource) -> Color {
        switch resource {
        case .food: Color(red: 0.80, green: 0.40, blue: 0.28)
        case .wood: Color(red: 0.55, green: 0.38, blue: 0.24)
        case .gold: Color(red: 0.90, green: 0.74, blue: 0.28)
        }
    }

    static func tint(of unit: UnitKind) -> Color {
        switch unit {
        case .worker: ochre
        case .car, .boat: paperDeep
        default: brick
        }
    }
}

enum Typeface {
    /// Futura where available; the system falls back to its own face where not.
    static func text(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Futura-Bold" : "Futura-Medium", size: size)
    }
}

/// A panel of flat colour, with its line laid slightly out of register.
struct CartoonBox: ViewModifier {
    var fill: Color = Palette.paper
    var radius: CGFloat = 6
    var lineWidth: CGFloat = 1.5

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Palette.ink, lineWidth: lineWidth).offset(x: 1, y: 1))
    }
}

extension View {
    func cartoonBox(fill: Color = Palette.paper, radius: CGFloat = 6, lineWidth: CGFloat = 1.5) -> some View {
        modifier(CartoonBox(fill: fill, radius: radius, lineWidth: lineWidth))
    }
}

/// A bar from 0 to 1.
struct MeterBar: View {
    var fraction: Double
    var fill: Color
    var height: CGFloat = 9

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2).fill(Palette.paperDeep)
                RoundedRectangle(cornerRadius: height / 2).fill(fill)
                    .frame(width: max(0, g.size.width * CGFloat(min(1, max(0, fraction)))))
            }
            .overlay(RoundedRectangle(cornerRadius: height / 2).stroke(Palette.ink, lineWidth: 1))
        }
        .frame(height: height)
    }
}

// MARK: Sprites and drawn symbols

private struct SpriteSourceKey: EnvironmentKey {
    static let defaultValue: any SpriteSource = EmptySpriteSource()
}

extension EnvironmentValues {
    /// Where the interface looks for icons. Until the artwork exists, nothing
    /// answers and every icon is a drawn symbol.
    public var spriteSource: any SpriteSource {
        get { self[SpriteSourceKey.self] }
        set { self[SpriteSourceKey.self] = newValue }
    }
}

private struct TeamColourKey: EnvironmentKey {
    static let defaultValue: TeamColour? = nil
}

extension EnvironmentValues {
    /// The colour an icon's team-colour layer takes: the viewing player's.
    public var teamColour: TeamColour? {
        get { self[TeamColourKey.self] }
        set { self[TeamColourKey.self] = newValue }
    }
}

/// A resource's symbol: a flat shape in the resource's colour.
struct ResourceGlyph: View {
    let resource: Resource
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, s in
            let r = CGRect(origin: .zero, size: s).insetBy(dx: 2, dy: 2)
            let path: Path
            switch resource {
            case .food: path = Path(ellipseIn: r)
            case .wood: path = Path(roundedRect: r.insetBy(dx: 0, dy: s.height * 0.12), cornerRadius: 3)
            case .gold: path = Self.polygon(in: r, sides: 4)
            }
            context.fill(path, with: .color(Palette.colour(of: resource)))
            context.stroke(path.offsetBy(dx: 0.8, dy: 0.8), with: .color(Palette.ink), lineWidth: 1.1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func polygon(in r: CGRect, sides: Int) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) / 2
        let start = -Double.pi / 2
        for i in 0..<sides {
            let a = start + 2 * Double.pi * Double(i) / Double(sides)
            let pt = CGPoint(x: c.x + radius * CGFloat(cos(a)), y: c.y + radius * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// A person or a building: the artwork's sprite where `SpriteSource` has one,
/// otherwise a symbol drawn here.
struct EntityIcon: View {
    @Environment(\.spriteSource) private var sprites
    @Environment(\.teamColour) private var team
    let kind: EntityKind
    var subject: SpriteSubject?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let image = sprite {
                ZStack {
                    Image(decorative: image.base, scale: 2).resizable().scaledToFit()
                    // The team-colour layer, tinted as the map tints it.
                    if let mask = image.teamMask, let team {
                        Image(decorative: mask, scale: 2).resizable().scaledToFit()
                            .colorMultiply(Color(red: team.red, green: team.green, blue: team.blue))
                    }
                }
            } else {
                switch kind {
                case .unit(let u): PersonGlyph(kind: u)
                case .building(let b): BuildingGlyph(kind: b)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var sprite: SpriteImage? {
        guard let subject else { return nil }
        let pose: SpritePose
        switch kind {
        case .unit: pose = .standing
        case .building: pose = .complete
        }
        return sprites.sprite(SpriteKey(subject, pose))
    }
}

struct PersonGlyph: View {
    let kind: UnitKind

    var body: some View {
        Canvas { context, s in
            let u = min(s.width, s.height), mid = s.width / 2
            let body = Path(roundedRect: CGRect(x: mid - u * 0.24, y: u * 0.44, width: u * 0.48, height: u * 0.5), cornerRadius: u * 0.16)
            let head = Path(ellipseIn: CGRect(x: mid - u * 0.17, y: u * 0.08, width: u * 0.34, height: u * 0.34))
            context.fill(body, with: .color(Palette.tint(of: kind)))
            context.fill(head, with: .color(Color(red: 0.93, green: 0.78, blue: 0.62)))
            var mark = Path()
            switch kind {
            case .spearman, .swordsman:
                mark.move(to: CGPoint(x: mid + u * 0.34, y: u * 0.96)); mark.addLine(to: CGPoint(x: mid + u * 0.34, y: u * 0.12))
            case .musketeer, .rifleman:
                mark.addArc(center: CGPoint(x: mid + u * 0.30, y: u * 0.62), radius: u * 0.26,
                            startAngle: .degrees(-70), endAngle: .degrees(70), clockwise: false)
            case .horseman, .knight, .cannon, .fieldGun, .car, .boat:
                mark.addEllipse(in: CGRect(x: mid - u * 0.46, y: u * 0.76, width: u * 0.24, height: u * 0.24))
                mark.addEllipse(in: CGRect(x: mid + u * 0.22, y: u * 0.76, width: u * 0.24, height: u * 0.24))
            case .worker:
                break
            }
            context.stroke(mark, with: .color(Palette.ink), lineWidth: 1.3)
            context.stroke(body.offsetBy(dx: 0.8, dy: 0.8), with: .color(Palette.ink), lineWidth: 1.1)
            context.stroke(head.offsetBy(dx: 0.8, dy: 0.8), with: .color(Palette.ink), lineWidth: 1.1)
        }
    }
}

struct BuildingGlyph: View {
    let kind: BuildingKind

    var body: some View {
        Canvas { context, s in
            let u = min(s.width, s.height)
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path {
                Path(CGRect(x: u * x, y: u * y, width: u * w, height: u * h))
            }
            func roof(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: u * x, y: u * (y + h))); p.addLine(to: CGPoint(x: u * (x + w / 2), y: u * y))
                p.addLine(to: CGPoint(x: u * (x + w), y: u * (y + h))); p.closeSubpath()
                return p
            }
            var parts: [(Path, Color)] = []
            let wall = Color(red: 0.86, green: 0.74, blue: 0.55), roofColour = Palette.brick
            switch kind {
            case .townCentre:
                parts = [(rect(0.08, 0.5, 0.84, 0.42), wall), (rect(0.36, 0.2, 0.28, 0.72), wall), (roof(0.30, 0.04, 0.40, 0.2), roofColour)]
            case .house:
                parts = [(rect(0.2, 0.5, 0.6, 0.42), wall), (roof(0.12, 0.2, 0.76, 0.32), roofColour)]
            case .barracks:
                parts = [(rect(0.06, 0.45, 0.88, 0.45), wall), (roof(0.02, 0.22, 0.96, 0.26), Palette.teal), (rect(0.44, 0.04, 0.05, 0.22), Palette.ink), (rect(0.49, 0.04, 0.2, 0.1), roofColour)]
            case .watchTower:
                parts = [(rect(0.34, 0.3, 0.32, 0.62), wall), (rect(0.24, 0.14, 0.52, 0.2), Color(red: 0.55, green: 0.38, blue: 0.24))]
            case .farm:
                parts = [(rect(0.06, 0.5, 0.88, 0.4), Color(red: 0.76, green: 0.66, blue: 0.36))]
            case .stable:
                parts = [(rect(0.06, 0.45, 0.88, 0.45), wall), (roof(0.02, 0.22, 0.96, 0.26), Color(red: 0.55, green: 0.38, blue: 0.24))]
            case .castle:
                parts = [(rect(0.1, 0.35, 0.8, 0.55), Color(red: 0.62, green: 0.6, blue: 0.56)), (rect(0.04, 0.15, 0.2, 0.75), Color(red: 0.62, green: 0.6, blue: 0.56)), (rect(0.76, 0.15, 0.2, 0.75), Color(red: 0.62, green: 0.6, blue: 0.56))]
            case .boatHouse:
                parts = [(rect(0.1, 0.3, 0.8, 0.45), Color(red: 0.55, green: 0.38, blue: 0.24)),
                         (rect(0.0, 0.75, 1.0, 0.2), Color(red: 0.36, green: 0.52, blue: 0.72))]
            }
            for (path, colour) in parts {
                context.fill(path, with: .color(colour))
                context.stroke(path.offsetBy(dx: 0.8, dy: 0.8), with: .color(Palette.ink), lineWidth: 1.1)
            }
        }
    }
}

/// A small key badge: the shortcut of a button.
struct KeyBadge: View {
    let key: Character

    var body: some View {
        Text(key == "\u{8}" ? "\u{232B}" : String(key).uppercased())
            .font(Typeface.text(9, bold: true))
            .foregroundStyle(Palette.ink)
            .frame(width: 14, height: 14)
            .background(RoundedRectangle(cornerRadius: 3).fill(Palette.paperDeep))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 0.8))
    }
}
