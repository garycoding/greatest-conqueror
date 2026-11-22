# Design notes: Greatest Conqueror

Status: in discussion, 2026-11-18. This file records design decisions as they are made. What the game must do is in [`requirements.md`](requirements.md).

## Decided

These were ruled by the person for whom the game is made.

- **Language and platform (2026-11-18):** Swift, for macOS only. Apple's frameworks are used freely.
- **Rendering (2026-11-18):** two-dimensional sprites drawn with SpriteKit, at a fixed angle. Three-dimensional models with RealityKit were considered and set aside: performance with about 1,200 moving models is unknown, the overlays (unexplored ground, selection rings, health bars) need custom work in 3D, and sprites are easier for an agent to verify. The artwork module may later produce its sprites by rendering simple models to images.
- **Setting up and joining (2026-11-18):** one Mac sets up a match, and the others on the LAN join it.
- **Network (2026-11-18):** the Mac that sets up the match runs the simulation. The other Macs send their players' orders to it and receive the state of what their team can see, several times a second, and draw it. Deterministic lockstep (every Mac running the simulation and exchanging only orders) was considered and set aside: Swift's dictionaries and sets iterate in an order that differs in every process, by design, which makes identical results on every Mac easy to break; a LAN carries the larger traffic without difficulty, and a co-operative game has no need to keep one player's Mac from knowing what another's knows.
- **Autosave (2026-11-18):** every match, on one Mac or across the LAN, saves itself every two minutes of play and when the app quits, keeping the last three saves under the match's name in `~/Library/Application Support/Greatest Conqueror/Autosaves/`; File > Open Autosave lists them.
- **Art style (2026-11-18):** Cartoon Modern, the mid-century graphic style with limited animation. Its marks, taken from the reference pictures supplied: flat fields of muted colour with a sponged grain; a thin dark line drawn loosely over colour that sits slightly out of register with it; figures built from simple geometry, with large heads, pointed noses and thin limbs; pattern used as decoration; a small palette for each picture. Two examples set the direction: [`art/cartoon-modern-scene-1.png`](art/cartoon-modern-scene-1.png) (a Bronze-age town) and [`art/cartoon-modern-people-2.png`](art/cartoon-modern-people-2.png) (one person from each of six ages; the second version, with a little more detail in the faces, as asked). An earlier drawing of three other styles was rejected.

## Internal mechanics

These concern how the code works and not what the player sees or does. They were decided in the course of the design and are open to correction.

- **Simulation:** the rules of the game (movement, combat, economies, ages) are plain Swift that uses none of Apple's frameworks, so that the rules can be tested without a screen, and whole matches between computer players can run as tests.
- **Finding a match:** Bonjour, through the Network framework.
- **Saved matches and network messages:** the state of the simulation, encoded with Codable.
- **Code organisation:** one Swift package of separate modules (shared types, simulation, map generator, computer player, network, drawing, interface, artwork, and the app). The app bundle is assembled from the package by `scripts/make-app.sh`, with no Xcode project, so that agents working in parallel never edit a shared project file and the same commands run locally and on GitHub. If that proves unworkable, a thin Xcode project around the package is the fallback.
- **Frameworks by concern:** SpriteKit for the map and units; SwiftUI for menus, the team-grouping screen and dialogs; SVG files drawn by macOS (`NSImage`) with a grain added by Core Image for the artwork; GameplayKit for terrain noise in map generation; AVFoundation for sound.

## The art

The art style, its palettes, noses and movement were ruled on 2026-11-18 and are recorded in [`art-style.md`](art-style.md).

## Previously open in the art

- The figures in the two examples are stiffer and more uniform than those of the reference pictures, and the line is even where theirs swells and thins. Further rounds are expected before the look is settled.
- A palette for each of the seven ages.
- How a figure moves within limited animation (which poses it holds, and what shifts between them).
- The noses. The large triangular noses of the two examples are disliked (2026-11-18) and are not to be used; the style guide is to show smaller noses, varied from one character to the next, for a ruling.

## Verified

The results of the verifications made before building are in [`decisions.md`](decisions.md#verifications-2026-11-18). One remains: an unsigned app on a second Mac.

## Facts

- This Mac has Xcode 27.2 and Swift 6.4.2 (checked 2026-11-18).
- Apple's documentation describes SceneKit as soft-deprecated and suggests RealityKit for new games; SpriteKit is not deprecated, according to replies on Apple's developer forums (searched 2026-11-18).
