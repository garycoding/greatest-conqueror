// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The people of the Stone age in the five views (ruled 2026-11-21): every
/// kind, in every pose its side view has, at every frame, seen from each side.
@Suite(.serialized)
struct FacingsStoneTests {
    static let kinds: [UnitKind] = [.worker]

    @Test func everyKindIsDrawnInEveryView() {
        let sprites = CartoonSprites()
        for kind in Self.kinds { #expect(sprites.drawsViews(of: .unit(kind, .stone)), "\(kind)") }
    }

    @Test func everyKeyInEveryViewHasASpriteWithATeamMask() throws {
        let sprites = CartoonSprites()
        for pose in sprites.poses {
            guard case .unit(let kind, .stone) = pose.subject, Self.kinds.contains(kind) else { continue }
            for view in SpriteView.allCases {
                for frame in 0..<12 {
                    let key = SpriteKey(pose.subject, pose.pose, frame: frame, view: view)
                    let sprite = try #require(sprites.sprite(key), "\(key)")
                    #expect(sprite.anchor == Canvas.person.anchor, "\(key)")
                    #expect(sprite.teamMask != nil, "\(key)")
                }
            }
        }
    }

    @Test func eachViewIsADrawingOfItsOwn() throws {
        let sprites = CartoonSprites()
        for kind in Self.kinds {
            let pictures = try SpriteView.allCases.map { view in
                Pixels(try #require(sprites.sprite(SpriteKey(.unit(kind, .stone), .standing, view: view))).base).bytes
            }
            #expect(Set(pictures).count == SpriteView.allCases.count, "\(kind)")
        }
    }
}

/// The pictures of the Stone people in the five views, written to the
/// directory named by `FACING_RENDERS`; skipped when it is not set: for each
/// kind, a sheet of the eight facings by pose and through the walk, and a GIF
/// of it walking round, a facing at a time.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FACING_RENDERS"] != nil))
struct FacingsStoneRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FACING_RENDERS"] ?? "/",
                                isDirectory: true)

    static let kinds: [(UnitKind, String, String)] = [
    ]

    @Test(arguments: kinds.map(\.0)) func sheets(_ kind: UnitKind) throws {
        let (_, name, title) = Self.kinds.first { $0.0 == kind }!
        try sheet(.unit(kind, .stone), name: "stone-\(name)", title: title)
        try round(.unit(kind, .stone), name: "stone-\(name)", stride: 1.6)
    }

    /// The eight facings in the order of a turn, each its view and mirroring.
    private static let facings: [Facing] = [.right, .downRight, .down, .downLeft, .left, .upLeft, .up, .upRight]

    private func sheet(_ subject: SpriteSubject, name: String, title: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = GameSprites()
        let facings = Self.facings
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting].filter {
            source.sprite(SpriteKey(subject, $0)) != nil
        }
        let column = 150.0, row = 170.0, left = 140.0, top = 110.0
        let width = Int(left + column * Double(facings.count) + 40), height = Int(top + row * Double(poses.count + 3) + 40)
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("\(title) facing eight ways: five views drawn, three mirrored; each pose at frame 0, then the walk at frames 3, 6 and 9",
                      in: context, at: CGPoint(x: 20, y: Double(height) - 40), size: 15)
        for (i, facing) in facings.enumerated() {
            Preview.label("\(facing)", in: context, at: CGPoint(x: left + Double(i) * column + 30, y: Double(height) - 80), size: 14)
        }
        let rows: [(String, SpritePose, Int)] = poses.map { ("\($0.rawValue)", $0, 0) }
            + [3, 6, 9].map { ("walking \($0)", SpritePose.walking, $0) }
        for (r, (label, pose, frame)) in rows.enumerated() {
            let ground = Double(height) - top - Double(r) * row - row * 0.85
            Preview.label(label, in: context, at: CGPoint(x: 16, y: ground + 40), size: 14)
            for (i, facing) in facings.enumerated() {
                let sprite = try #require(source.sprite(SpriteKey(subject, pose, frame: frame, view: facing.view)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
                let at = CGPoint(x: left + Double(i) * column + column / 2, y: ground)
                if facing.mirrored {
                    context.saveGState()
                    context.translateBy(x: at.x, y: 0)
                    context.scaleBy(x: -1, y: 1)
                    Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: 0, y: at.y), in: context)
                    context.restoreGState()
                } else {
                    Preview.place(image, anchor: sprite.anchor, at: at, in: context)
                }
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("\(name)-facings.png"))
    }

    /// The kind walking a circle of eight steps' length, one facing after
    /// another, at game size enlarged twice: 12 frames to each facing.
    private func round(_ subject: SpriteSubject, name: String, stride: Double) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = GameSprites()
        let walk: [(Facing, Double, Double)] = [(.right, 1, -1), (.downRight, 1, 0), (.down, 1, 1), (.downLeft, 0, 1),
                                               (.left, -1, 1), (.upLeft, -1, 0), (.up, -1, -1), (.upRight, 0, -1)]
        let size = 360, k = 2.0
        var frames: [CGImage] = []
        let step = stride / 12
        // The path first, so that the circle can be centred in the picture.
        var path: [(Double, Double)] = []
        var px = 0.0, py = 0.0
        for (_, dx, dy) in walk {
            let length = (dx * dx + dy * dy).squareRoot()
            for _ in 0..<12 { path.append((px, py)); px += dx / length * step; py += dy / length * step }
        }
        let mx = path.map(\.0).reduce(0, +) / Double(path.count), my = path.map(\.1).reduce(0, +) / Double(path.count)
        var n = 0
        for (facing, _, _) in walk {
            for frame in 0..<12 {
                let (x, y) = (path[n].0 - mx, path[n].1 - my)
                n += 1
                let context = Raster.bitmap(width: size, height: size)!
                context.draw(Preview.ground(width: size, height: size, tile: 128), in: CGRect(x: 0, y: 0, width: size, height: size))
                let sprite = try #require(source.sprite(SpriteKey(subject, .walking, frame: frame, view: facing.view)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
                let at = CGPoint(x: Double(size) / 2 + (x - y) * 32 * k, y: Double(size) / 2 - 70 - (x + y) * 16 * k)
                context.saveGState()
                context.translateBy(x: at.x, y: at.y)
                context.scaleBy(x: facing.mirrored ? -k : k, y: k)
                Preview.place(image, anchor: sprite.anchor, at: .zero, in: context)
                context.restoreGState()
                Preview.label("\(facing)", in: context, at: CGPoint(x: 12, y: Double(size) - 28), size: 16)
                frames.append(context.makeImage()!)
            }
        }
        try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(name)-round.gif"))
    }
}
