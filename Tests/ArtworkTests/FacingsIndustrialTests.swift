// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The Industrial age's people and warriors in the five views (ruled
/// 2026-11-21): every key of every kind, in every pose its side view has and
/// every frame, gives a sprite with the team's colour in each view.
@Suite struct FacingsIndustrialTests {
    /// Each kind drawn in the five views, the source that draws it, and the name of its renders.
    static let kinds: [(kind: UnitKind, source: any ViewedSpriteSource, name: String)] = [
        (.worker, IndustrialPeopleSprites(), "factory-hand"),
        (.rifleman, IndustrialWarriorSprites(), "rifleman"),
        (.fieldGun, IndustrialWarriorSprites(), "field-gun"),
    ]

    @Test func everyKindIsDrawnInEveryView() {
        for (kind, source, _) in Self.kinds {
            #expect(source.drawsViews(of: .unit(kind, .industrial)), "\(kind)")
        }
    }

    @Test(arguments: SpriteView.allCases)
    func everyKeyHasASpriteWithTheTeamsColour(_ view: SpriteView) throws {
        for (kind, source, _) in Self.kinds {
            let subject = SpriteSubject.unit(kind, .industrial)
            let poses = [SpritePose.standing, .walking, .working, .fighting].filter { source.sprite(SpriteKey(subject, $0)) != nil }
            #expect(!poses.isEmpty, "\(kind)")
            for pose in poses {
                for frame in 0..<SpriteKey.framesPerPose {
                    let key = SpriteKey(subject, pose, frame: frame, view: view)
                    let sprite = try #require(source.sprite(key), "\(key)")
                    let mask = try #require(sprite.teamMask, "\(key) has no team colour")
                    #expect(mask.width == sprite.base.width && mask.height == sprite.base.height, "\(key)")
                }
            }
        }
    }
}

/// The pictures for reviewing the Industrial age's five views, written to the
/// directory named by `FACING_RENDERS`; skipped when it is not set: for each
/// kind a sheet of its eight facings by pose and through the walk, and a GIF
/// of it walking round, in the manner of `FacingRenders`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FACING_RENDERS"] != nil))
struct FacingsIndustrialRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FACING_RENDERS"] ?? "/", isDirectory: true)

    /// The width of a column and the size of a frame of the walk, wider for the machines.
    private static func room(_ kind: UnitKind) -> (column: Double, round: Int) {
        switch kind {
        case .fieldGun: (250, 600)
        default: (150, 360)
        }
    }

    @Test(arguments: FacingsIndustrialTests.kinds.map(\.name))
    func sheetAndRound(_ name: String) throws {
        let (kind, source, _) = try #require(FacingsIndustrialTests.kinds.first { $0.name == name })
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Named by the unit kind, as `FacingRenders` names the hunter's sheet, so that every age's sheets line up.
        try sheet(.unit(kind, .industrial), source: source, name: "industrial-\(kind)", title: "The \(name.replacingOccurrences(of: "-", with: " ")) (\(kind))",
                  room: Self.room(kind).column)
        try round(.unit(kind, .industrial), source: source, name: "industrial-\(kind)", size: Self.room(kind).round)
    }

    /// The eight facings in the order of a turn, each its view and mirroring.
    private let facings: [Facing] = [.right, .downRight, .down, .downLeft, .left, .upLeft, .up, .upRight]

    private func sheet(_ subject: SpriteSubject, source: any SpriteSource, name: String, title: String, room column: Double) throws {
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting].filter { source.sprite(SpriteKey(subject, $0)) != nil }
        let row = 170.0, left = 140.0, top = 110.0
        let width = Int(left + column * Double(facings.count) + 40), height = Int(top + row * Double(poses.count + 3) + 40)
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("\(title) facing eight ways: five views drawn, three mirrored; each pose at frame 0, then the walk at frames 3, 6 and 9",
                      in: context, at: CGPoint(x: 20, y: Double(height) - 40), size: 15)
        for (i, facing) in facings.enumerated() {
            Preview.label("\(facing)", in: context, at: CGPoint(x: left + Double(i) * column + 30, y: Double(height) - 80), size: 14)
        }
        let rows: [(String, SpritePose, Int)] = poses.map { ("\($0.rawValue)", $0, 0) } + [3, 6, 9].map { ("walking \($0)", SpritePose.walking, $0) }
        for (r, (label, pose, frame)) in rows.enumerated() {
            let ground = Double(height) - top - Double(r) * row - row * 0.85
            Preview.label(label, in: context, at: CGPoint(x: 16, y: ground + 40), size: 14)
            for (i, facing) in facings.enumerated() {
                let sprite = try #require(source.sprite(SpriteKey(subject, pose, frame: frame, view: facing.view)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
                let at = CGPoint(x: left + Double(i) * column + column / 2, y: ground)
                context.saveGState()
                context.translateBy(x: at.x, y: at.y)
                context.scaleBy(x: facing.mirrored ? -1 : 1, y: 1)
                Preview.place(image, anchor: sprite.anchor, at: .zero, in: context)
                context.restoreGState()
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("\(name)-facings.png"))
    }

    /// The subject walking a circle, one facing after another, 12 frames to
    /// each, at game size enlarged twice.
    private func round(_ subject: SpriteSubject, source: any SpriteSource, name: String, size: Int) throws {
        let walk: [(Facing, Double, Double)] = [(.right, 1, -1), (.downRight, 1, 0), (.down, 1, 1), (.downLeft, 0, 1),
                                               (.left, -1, 1), (.upLeft, -1, 0), (.up, -1, -1), (.upRight, 0, -1)]
        let k = 2.0, step = 1.4 / 12
        var path: [(Double, Double)] = []
        var px = 0.0, py = 0.0
        for (_, dx, dy) in walk {
            let length = (dx * dx + dy * dy).squareRoot()
            for _ in 0..<12 { path.append((px, py)); px += dx / length * step; py += dy / length * step }
        }
        let mx = path.map(\.0).reduce(0, +) / Double(path.count), my = path.map(\.1).reduce(0, +) / Double(path.count)
        var frames: [CGImage] = []
        var n = 0
        for (facing, _, _) in walk {
            for frame in 0..<12 {
                let (x, y) = (path[n].0 - mx, path[n].1 - my)
                n += 1
                let context = Raster.bitmap(width: size, height: size)!
                context.draw(Preview.ground(width: size, height: size, tile: 128), in: CGRect(x: 0, y: 0, width: size, height: size))
                let sprite = try #require(source.sprite(SpriteKey(subject, .walking, frame: frame, view: facing.view)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
                let at = CGPoint(x: Double(size) / 2 + (x - y) * 32 * k, y: Double(size) / 2 - 20 - (x + y) * 16 * k)
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
