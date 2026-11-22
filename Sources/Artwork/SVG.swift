// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The pictures are written as SVG text and drawn by macOS (docs/architecture.md,
// "Sprites"; docs/decisions.md, "Verifications"). This file holds the small
// writer the drawings use: points, paints, and the elements themselves.

/// A point in figure units. x runs toward the front (the figure faces right) and
/// y downward, as SVG has it; the origin is on the ground, between the feet.
struct P: Sendable, Equatable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }

    static func + (a: P, b: P) -> P { P(a.x + b.x, a.y + b.y) }
    static func - (a: P, b: P) -> P { P(a.x - b.x, a.y - b.y) }
    static func * (a: P, k: Double) -> P { P(a.x * k, a.y * k) }

    /// The unit vector at `degrees` from straight down, positive toward the front:
    /// the angle every limb and tool is given in.
    static func direction(_ degrees: Double) -> P {
        let r = degrees * .pi / 180
        return P(sin(r), cos(r))
    }

    /// This point turned by `degrees` about `centre`, as SVG's `rotate` turns it
    /// (positive is clockwise on the screen).
    func rotated(_ degrees: Double, about centre: P) -> P {
        let r = degrees * .pi / 180, c = cos(r), s = sin(r)
        let d = self - centre
        return P(centre.x + d.x * c - d.y * s, centre.y + d.x * s + d.y * c)
    }
}

/// Which of a sprite's two images is being drawn. The base is the picture; the
/// mask is white where the civilization's colour goes and black everywhere
/// else, including every line and limb that passes in front of the coloured
/// part, so that the tinted mask laid over the base never covers them.
enum Layer: Sendable {
    case base, mask
}

/// What fills or strokes an element.
enum Paint: Sendable {
    case none
    /// A colour of the picture, as `#rrggbb`.
    case colour(String)
    /// The part that carries the team's colour: neutral in the base, white in the mask.
    case team
}

/// SVG text for one picture, written in figure units.
struct SVG {
    let layer: Layer
    private(set) var body = ""

    init(layer: Layer) { self.layer = layer }

    /// The cloth of a team-coloured part in the base, before the drawing tints it.
    static let neutral = "#e4dccb"

    func value(_ paint: Paint) -> String {
        switch (layer, paint) {
        case (_, .none): "none"
        case (.base, .colour(let c)): c
        case (.base, .team): SVG.neutral
        case (.mask, .team): "#ffffff"
        case (.mask, .colour): "#000000"
        }
    }

    /// The attributes shared by every element.
    private func style(fill: Paint, stroke: Paint, width: Double, opacity: Double) -> String {
        var s = "fill=\"\(value(fill))\""
        if case .none = stroke {} else {
            s += " stroke=\"\(value(stroke))\" stroke-width=\"\(num(width))\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
        }
        if opacity < 1 { s += " opacity=\"\(num(opacity))\"" }
        return s
    }

    mutating func raw(_ text: String) { body += text }

    mutating func path(_ d: String, fill: Paint = .none, stroke: Paint = .none, width: Double = 1.8, opacity: Double = 1) {
        body += "<path d=\"\(d)\" \(style(fill: fill, stroke: stroke, width: width, opacity: opacity))/>"
    }

    mutating func path(_ d: PathData, fill: Paint = .none, stroke: Paint = .none, width: Double = 1.8, opacity: Double = 1) {
        path(d.text, fill: fill, stroke: stroke, width: width, opacity: opacity)
    }

    /// A line through the points, with round caps and joins.
    mutating func line(_ points: [P], stroke: Paint, width: Double, opacity: Double = 1) {
        var d = PathData()
        d.move(points[0])
        for point in points.dropFirst() { d.line(point) }
        path(d, stroke: stroke, width: width, opacity: opacity)
    }

    mutating func polygon(_ points: [P], fill: Paint, stroke: Paint = .none, width: Double = 1.8, opacity: Double = 1) {
        let list = points.map { "\(num($0.x)),\(num($0.y))" }.joined(separator: " ")
        body += "<polygon points=\"\(list)\" \(style(fill: fill, stroke: stroke, width: width, opacity: opacity))/>"
    }

    mutating func ellipse(_ c: P, _ rx: Double, _ ry: Double, fill: Paint, stroke: Paint = .none, width: Double = 1.8,
                          opacity: Double = 1) {
        body += "<ellipse cx=\"\(num(c.x))\" cy=\"\(num(c.y))\" rx=\"\(num(rx))\" ry=\"\(num(ry))\" "
            + "\(style(fill: fill, stroke: stroke, width: width, opacity: opacity))/>"
    }

    mutating func circle(_ c: P, _ r: Double, fill: Paint, stroke: Paint = .none, width: Double = 1.8, opacity: Double = 1) {
        ellipse(c, r, r, fill: fill, stroke: stroke, width: width, opacity: opacity)
    }

    /// Elements drawn moved to `origin` and turned by `degrees` (clockwise on the screen).
    mutating func group(at origin: P = P(0, 0), turned degrees: Double = 0, _ content: (inout SVG) -> Void) {
        body += "<g transform=\"translate(\(num(origin.x)),\(num(origin.y))) rotate(\(num(degrees)))\">"
        content(&self)
        body += "</g>"
    }

    /// Elements turned by `degrees` about `centre`.
    mutating func group(turned degrees: Double, about centre: P, _ content: (inout SVG) -> Void) {
        body += "<g transform=\"rotate(\(num(degrees)) \(num(centre.x)) \(num(centre.y)))\">"
        content(&self)
        body += "</g>"
    }

    /// The whole document: the canvas's area of figure space, drawn at its pixel size.
    func document(_ canvas: Canvas) -> String {
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(canvas.pixelWidth)\" height=\"\(canvas.pixelHeight)\" "
            + "viewBox=\"\(num(canvas.minX)) \(num(canvas.minY)) \(num(canvas.width)) \(num(canvas.height))\">"
            + body + "</svg>"
    }
}

/// The `d` attribute of a path, built from points.
struct PathData {
    private(set) var text = ""
    mutating func move(_ p: P) { text += "M\(num(p.x)),\(num(p.y)) " }
    mutating func line(_ p: P) { text += "L\(num(p.x)),\(num(p.y)) " }
    mutating func quad(_ c: P, _ p: P) { text += "Q\(num(c.x)),\(num(c.y)) \(num(p.x)),\(num(p.y)) " }
    mutating func cubic(_ c1: P, _ c2: P, _ p: P) {
        text += "C\(num(c1.x)),\(num(c1.y)) \(num(c2.x)),\(num(c2.y)) \(num(p.x)),\(num(p.y)) "
    }
    mutating func close() { text += "Z " }
}

/// A number written with at most two decimals and never in exponent form, so
/// that the same drawing always gives the same text.
func num(_ value: Double) -> String {
    let hundredths = Int((value * 100).rounded())
    let sign = hundredths < 0 ? "-" : ""
    let magnitude = abs(hundredths)
    let whole = magnitude / 100, fraction = magnitude % 100
    if fraction == 0 { return "\(sign)\(whole)" }
    return fraction < 10 ? "\(sign)\(whole).0\(fraction)" : "\(sign)\(whole).\(fraction)"
}
