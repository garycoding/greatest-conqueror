# Greatest Conqueror

A real-time strategy game for macOS. Players on the same LAN, with computer players, lead their civilizations through five ages: the age of towns, of farms, of ships, of cannons and of hospitals. Every number that sets the play (costs, health, damage, rates and times) is read from CSV files that can be edited in the game.

## Status

Version 0.1.0 is in development. The code was made from [Cities of Progress](https://github.com/garycoding/cities-of-progress) at commit 6492cca, and is being changed to the rules of Greatest Conqueror; until that work is done, the game still plays by the rules of Cities of Progress, and the documents in `docs/` still describe that game.

It is a personal project, written in Swift for macOS on Apple silicon, and its source is published under the AGPL. No built app is distributed.

## Building and running

The game is one Swift package. With Xcode installed:

```bash
swift build
swift test
scripts/make-app.sh
```

The last command assembles `build/Greatest Conqueror.app`.

## Documents

- [`docs/requirements.md`](docs/requirements.md): what the game must do.
- [`docs/design.md`](docs/design.md): how it is built.
- [`docs/decisions.md`](docs/decisions.md): the dated rulings, including each departure from the ParkviewLab handbook.
- [`docs/in-flight_ideas.md`](docs/in-flight_ideas.md): ideas not yet decided.

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). The code and the artwork are licensed under AGPL-3.0-or-later, and the documents under CC-BY-4.0; see [`LICENSING.md`](LICENSING.md).

## Releasing

Releases follow the tag-driven flow of the [ParkviewLab handbook](https://github.com/ParkviewLab/handbook/blob/main/docs/releases.md). There has been none yet.

---
<sub>© 2026 Gary Frattarola · Licensed under [CC-BY-4.0](LICENSES/CC-BY-4.0.txt)</sub>
