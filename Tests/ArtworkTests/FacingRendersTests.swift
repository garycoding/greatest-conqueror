// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The pictures for the person's ruling on the five views, written to the
/// directory named by `FACING_RENDERS`; skipped when it is not set: a sheet of
/// each kind drawn in views, every view in every pose at frame 0 and through
/// the walk, at twice game size.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FACING_RENDERS"] != nil))
struct FacingRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FACING_RENDERS"] ?? "/",
                                isDirectory: true)

    @Test func theWorker() throws { try sheet(.unit(.worker, .stone), name: "worker", title: "The hunter (worker)") }

    @Test func theCar() throws { try sheet(.unit(.car, .stone), name: "car", title: "The car") }

    private func sheet(_ subject: SpriteSubject, name: String, title: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = GameSprites()
        // The eight facings in the order of a turn, each its view and mirroring.
        let facings: [Facing] = [.right, .downRight, .down, .downLeft, .left, .upLeft, .up, .upRight]
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting].filter {
            source.sprite(SpriteKey(subject, $0)) != nil
        }
        let scale = 2.0, column = subject == .unit(.car, .stone) ? 230.0 : 150.0, row = 170.0, left = 140.0, top = 110.0
        let width = Int(left + column * Double(facings.count) + 40), height = Int(top + row * Double(poses.count + 3) + 40)
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("\(title) facing eight ways: five views drawn, three mirrored; standing, walking, working and fighting at frame 0, then the walk at frames 0, 3, 6 and 9",
                      in: context, at: CGPoint(x: 20, y: Double(height) - 40), size: 15)
        for (i, facing) in facings.enumerated() {
            Preview.label("\(facing)", in: context, at: CGPoint(x: left + Double(i) * column + 30, y: Double(height) - 80), size: 14)
        }
        let rows: [(String, SpritePose, Int)] = poses.map { ("\($0.rawValue)", $0, 0) }
            + [3, 6, 9].map { ("walking \($0)", SpritePose.walking, $0) }
        for (r, (name, pose, frame)) in rows.enumerated() {
            let ground = Double(height) - top - Double(r) * row - row * 0.85
            Preview.label(name, in: context, at: CGPoint(x: 16, y: ground + 40), size: 14)
            for (i, facing) in facings.enumerated() {
                let key = SpriteKey(subject, pose, frame: frame, view: facing.view)
                let sprite = try #require(source.sprite(key))
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
        _ = scale
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("\(name)-facings.png"))
    }

    /// The worker walking a circle of eight steps' length, one facing after
    /// another, at game size enlarged twice: 12 frames to each facing.
    @Test func theWorkerWalkingRound() throws { try round(.unit(.worker, .stone), name: "worker-walking-round", stride: 1.6) }

    @Test func theCarDrivingRound() throws { try round(.unit(.car, .stone), name: "car-driving-round", stride: 0.9) }

    /// A subject walking or driving a circle, one facing after another.
    private func round(_ subject: SpriteSubject, name: String, stride: Double) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = GameSprites()
        let walk: [(Facing, Double, Double)] = [(.right, 1, -1), (.downRight, 1, 0), (.down, 1, 1), (.downLeft, 0, 1),
                                               (.left, -1, 1), (.upLeft, -1, 0), (.up, -1, -1), (.upRight, 0, -1)]
        let size = subject == .unit(.car, .stone) ? 560 : 360, k = 2.0
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
        try Preview.writeGIF(frames, to: directory.appendingPathComponent("\(name).gif"))
    }

    /// The car's five views close up, at four times game size.
    @Test func theCarCloseUp() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let canvas = CarSaloon.canvas.scaled(to: 5)
        let views = SpriteView.allCases
        let cell = Int(Double(canvas.width) * 5) + 20
        let width = cell * views.count, height = Int(Double(canvas.height) * 5) + 80
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        for (i, view) in views.enumerated() {
            let drawn = try #require(CarSaloon.render(.standing, frame: 0, canvas: canvas, view: view))
            let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: .of(.sumer))
            Preview.place(image, anchor: canvas.anchor, at: CGPoint(x: Double(i * cell + cell / 2), y: 40), in: context)
            Preview.label(view.rawValue, in: context, at: CGPoint(x: Double(i * cell + 20), y: Double(height) - 30), size: 22)
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("car-close.png"))
    }
}
