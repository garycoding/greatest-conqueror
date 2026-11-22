// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The car seen from its other four sides (ruled 2026-11-21: eight facings,
// five views drawn). The car is taken as a body as wide as two fifths of its
// length, its glasshouse narrowing toward the roof. A view turns it by its
// yaw (`SpriteView.yaw`) as the figure is turned: the near side is the side
// drawing itself, foreshortened; the nose or the tail is a face of its own,
// with the slope of the bonnet or the boot and the glass above it; the far
// wheels show beneath. Seen straight from the front or behind, the side is
// gone, and the face shows the whole width with both wheels under it.

extension CarSaloon {
    /// Half the body's width, and the glasshouse's half width at its foot and at the roof.
    static let halfWidth = 22.0, glassFoot = 18.4, glassTop = 14.2
    /// Where the nose and the tail stand along the car.
    static let nose = 56.4, tail = -56.2

    /// A frame of a pose drawn in a view other than the side.
    static func drawInView(_ svg: inout SVG, _ pose: SpritePose, _ frame: Int, view: SpriteView) {
        let yaw = view.yaw * .pi / 180, c = cos(yaw), s = sin(yaw)
        let spin = pose == .walking ? -Double(frame) * turn : 0
        let ride = Self.ride(pose, frame)
        let ink = Paint.colour(Ink.line)
        /// A point of the car's space (x along, y down, z to its right) on the screen.
        func at(_ x: Double, _ y: Double, _ z: Double) -> P { P(x * c - z * s, y) }
        let w = halfWidth
        let front = view == .front || view == .frontQuarter
        let endX = front ? nose : tail

        // The shadow, as long as the car shows and as wide.
        let reach = abs(60 * c) + abs(w * s) + 2
        svg.ellipse(P(0, 0.2), reach, 3.8, fill: .colour("#000000"), opacity: 0.16)

        // The far wheels, under the body: the end's two when the side is gone, else the far side's.
        for axle in [rearAxle, frontAxle] {
            let near = (axle.x > 0) == front
            if abs(c) < 0.01 {
                guard near else { continue }
                for z in [-(w - 4.5), w - 4.5] { tyreEndOn(&svg, at: at(axle.x, axle.y, z)) }
            } else {
                let p = at(axle.x, axle.y, -w + 3)
                svg.ellipse(p, wheelRadius * abs(c) + 1.2, wheelRadius, fill: .colour(CarInk.tyre), stroke: ink, width: 1)
            }
        }

        svg.group(at: P(0, -ride)) { svg in
            // The end: nose or tail, from the sill to the shoulder, across the whole width.
            let shoulder = front ? -18.4 : -22.6
            let corner = 5.0
            var end = PathData()
            end.move(at(endX, sill, -w + corner))
            end.line(at(endX, sill, w - corner))
            end.quad(at(endX, sill, w), at(endX, sill - corner, w))
            end.line(at(endX, shoulder + 2, w))
            end.quad(at(endX, shoulder, w), at(endX, shoulder, w - corner))
            end.line(at(endX, shoulder, -w + corner))
            end.quad(at(endX, shoulder, -w), at(endX, shoulder + 2, -w))
            end.line(at(endX, sill - corner, -w))
            end.quad(at(endX, sill, -w), at(endX, sill, -w + corner))
            end.close()
            svg.path(end, fill: .team)
            // Its tones: the sky along the top, the shade below.
            let top = [at(endX, shoulder + 0.6, -w + 2), at(endX, shoulder + 0.6, w - 2), at(endX, shoulder + 3.4, w - 1.5),
                       at(endX, shoulder + 3.4, -w + 1.5)]
            tonePolygon(&svg, top, colour: CarInk.highlight, strength: 0.55)
            let low = [at(endX, -10.5, -w + 0.6), at(endX, -10.5, w - 0.6), at(endX, sill - 0.4, w - 3),
                       at(endX, sill - 0.4, -w + 3)]
            tonePolygon(&svg, low, colour: CarInk.shade, strength: 0.5)
            if front {
                // The slim head lamps at the corners, and the slim intake low in the middle.
                for z in [-w + 2.4, w - 9.6] {
                    let lamp = [at(endX, -15.6, z), at(endX, -15.6, z + 7.2), at(endX, -14, z + 7.4), at(endX, -14.2, z)]
                    svg.polygon(lamp, fill: .colour(CarInk.lens), stroke: ink, width: 0.6)
                    svg.line([at(endX, -15, z + 1), at(endX, -15, z + 6.2)], stroke: .colour(CarInk.lamp), width: 0.7)
                }
                let intake = [at(endX, -10.8, -w * 0.42), at(endX, -10.8, w * 0.42), at(endX, -9.2, w * 0.38),
                              at(endX, -9.2, -w * 0.38)]
                svg.polygon(intake, fill: .colour(CarInk.trim), stroke: ink, width: 0.6)
            } else {
                // The tail lamp: one red bar across the whole tail, brighter at its ends.
                let bar = [at(endX, -20.6, -w + 1.6), at(endX, -20.6, w - 1.6), at(endX, -18.8, w - 1.6),
                           at(endX, -18.8, -w + 1.6)]
                svg.polygon(bar, fill: .colour(CarInk.tail), stroke: ink, width: 0.6)
                for z in [-w + 2, w - 6] {
                    svg.polygon([at(endX, -20.4, z), at(endX, -20.4, z + 4), at(endX, -19, z + 4), at(endX, -19, z)],
                                fill: .colour(CarInk.tailLit))
                }
                // The diffuser, dark under the bumper.
                svg.polygon([at(endX, sill - 1.6, -w * 0.6), at(endX, sill - 1.6, w * 0.6), at(endX, sill, w * 0.5),
                             at(endX, sill, -w * 0.5)], fill: .colour(CarInk.trim))
            }
            svg.path(end, stroke: ink, width: 1.2)

            // The slope above the end: the bonnet, or the boot's deck.
            let (deckFrom, deckTo): ((Double, Double), (Double, Double)) = front
                ? ((53.8, -18.4), (20, -24.6)) : ((-55, -24), (-45.5, -25))
            let deck = [at(deckFrom.0, deckFrom.1, -w + 1), at(deckFrom.0, deckFrom.1, w - 1), at(deckTo.0, deckTo.1, w - 2.4),
                        at(deckTo.0, deckTo.1, -w + 2.4)]
            svg.polygon(deck, fill: .team)
            tonePolygon(&svg, deck, colour: CarInk.highlight, strength: 0.4)
            svg.polygon(deck, fill: .none, stroke: ink, width: 1)

            // The glass above it: the windscreen, or the rear window, narrowing to the roof.
            let (glassFrom, glassTo): ((Double, Double), (Double, Double)) = front
                ? ((20, -24.6), (-1, -33.8)) : ((-45.5, -25), (-25, -32.2))
            let glass = [at(glassFrom.0, glassFrom.1, -glassFoot), at(glassFrom.0, glassFrom.1, glassFoot),
                         at(glassTo.0, glassTo.1, glassTop), at(glassTo.0, glassTo.1, -glassTop)]
            svg.polygon(glass, fill: .colour(CarInk.glass), stroke: ink, width: 1.1)
            // Its sheen: a pale band across, leaning.
            let sheen = [glass[0] + (glass[3] - glass[0]) * 0.25, glass[0] + (glass[3] - glass[0]) * 0.45,
                         glass[1] + (glass[2] - glass[1]) * 0.6, glass[1] + (glass[2] - glass[1]) * 0.4]
            svg.polygon(sheen, fill: .colour(CarInk.glassSheen), opacity: 0.45)
            // The roof's edge, dark glass, over the top of the pane.
            svg.line([at(glassTo.0, glassTo.1, -glassTop), at(glassTo.0, glassTo.1, glassTop)], stroke: .colour(CarInk.pillar),
                     width: 1.6)
            // The pillars at the glass's sides, in the body's colour.
            for z in [-1.0, 1.0] {
                svg.line([at(glassFrom.0, glassFrom.1, z * glassFoot), at(glassTo.0, glassTo.1, z * glassTop)],
                         stroke: .colour(CarInk.pillar), width: 1.4)
            }
            if front {
                // The wing mirrors, standing out at the foot of the windscreen.
                for z in [-1.0, 1.0] {
                    guard abs(c) < 0.01 || z < 0 else { continue }
                    let m = at(19, -25.4, z * (w + 2.6))
                    svg.ellipse(m, 2.4 * max(abs(s), 0.5), 1.6, fill: .team, stroke: ink, width: 0.7)
                }
            }

            // The near side: the side drawing itself, foreshortened (none from straight ahead or behind).
            if abs(c) > 0.01 {
                let shift = at(0, 0, w)
                svg.raw("<g transform=\"translate(\(num(shift.x)),0) scale(\(num(abs(c))),1)\">")
                wells(&svg)
                body(&svg)
                glasshouse(&svg)
                doors(&svg)
                lamps(&svg)
                svg.raw("</g>")
            }
        }
        // The near wheels, turning as the car drives.
        if abs(c) > 0.01 {
            let shift = at(0, 0, w)
            svg.raw("<g transform=\"translate(\(num(shift.x)),0) scale(\(num(abs(c))),1)\">")
            wheel(&svg, at: rearAxle, degrees: spin)
            wheel(&svg, at: frontAxle, degrees: spin + 31)
            svg.raw("</g>")
        } else {
            // From straight ahead or behind, the near wheels are the end's own, drawn under it already.
        }
        if pose == .walking && frame % 6 == 3 {
            let behind = at(front ? rearAxle.x - 13 : frontAxle.x + 13, -2.4, 0)
            BronzePeopleProps.dust(&svg, at: behind, size: 0.6, opacity: 0.25)
        }
    }

    /// A tyre seen end on, under the body: a dark upright band with a sheen.
    private static func tyreEndOn(_ svg: inout SVG, at c: P) {
        let r = wheelRadius, half = 3.6
        let tyre = [c + P(-half, -r), c + P(half, -r), c + P(half, r), c + P(-half, r)]
        svg.polygon(tyre, fill: .colour(CarInk.tyre), stroke: .colour(Ink.line), width: 1)
        svg.line([c + P(-half + 1.2, -r + 2), c + P(-half + 1.2, r - 2)], stroke: .colour(CarInk.tyreSheen), width: 0.7,
                 opacity: 0.7)
    }

    /// A tone laid over a painted face, as `tone` lays one over the side.
    private static func tonePolygon(_ svg: inout SVG, _ points: [P], colour: String, strength: Double) {
        svg.polygon(points, fill: .colour(colour), opacity: svg.layer == .base ? 1 : strength)
    }
}
