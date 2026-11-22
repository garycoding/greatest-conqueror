// swift-tools-version: 6.0
// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

// Greatest Conqueror: one package of separate modules. Every target is declared
// here, so that work on one module never edits this shared file. See
// docs/architecture.md once it exists, and docs/design.md.

import PackageDescription

let package = Package(
    name: "GreatestConqueror",
    platforms: [.macOS(.v15)],
    targets: [
        // The types every module shares: the map, players, people, buildings,
        // orders, the state one Mac reports, and the protocols at each seam.
        .target(name: "GameCore"),
        // The rules of the game. Plain Swift: no Apple frameworks.
        .target(name: "GameSimulation", dependencies: ["GameCore"]),
        .target(name: "MapGeneration", dependencies: ["GameCore"]),
        .target(name: "ComputerPlayer", dependencies: ["GameCore"]),
        // The sprites and the code that makes them.
        .target(name: "Artwork", dependencies: ["GameCore"]),
        // The SpriteKit scene that draws a state and turns clicks into orders.
        .target(name: "MapDrawing", dependencies: ["GameCore", "Artwork"]),
        // The SwiftUI views around the map.
        .target(name: "GameInterface", dependencies: ["GameCore", "Artwork"]),
        // Setting up, finding and joining a match on the LAN (a later milestone).
        .target(name: "GameNetwork", dependencies: ["GameCore"]),
        // The app.
        .executableTarget(
            name: "GreatestConqueror",
            dependencies: [
                "GameCore", "GameSimulation", "MapGeneration", "ComputerPlayer",
                "Artwork", "MapDrawing", "GameInterface", "GameNetwork",
            ]
        ),

        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "GameSimulationTests", dependencies: ["GameSimulation", "GameCore"]),
        .testTarget(name: "MapGenerationTests", dependencies: ["MapGeneration", "GameCore"]),
        .testTarget(name: "ComputerPlayerTests", dependencies: ["ComputerPlayer", "GameCore"]),
        .testTarget(name: "ArtworkTests", dependencies: ["Artwork", "GameCore"]),
        .testTarget(name: "MapDrawingTests", dependencies: ["MapDrawing", "GameCore"]),
        .testTarget(name: "GameInterfaceTests", dependencies: ["GameInterface", "GameCore", "Artwork"]),
        .testTarget(name: "GameNetworkTests", dependencies: ["GameNetwork", "GameCore"]),
        // Whole matches between computer players, without a screen (step 5).
        .testTarget(
            name: "MatchTests",
            dependencies: ["GameCore", "GameSimulation", "MapGeneration", "ComputerPlayer", "GameNetwork"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
