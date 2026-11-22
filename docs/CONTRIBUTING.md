# Contributing

This repo follows the conventions of the [ParkviewLab handbook](https://github.com/ParkviewLab/handbook/tree/main), with the departures recorded in [`decisions.md`](decisions.md). The essentials:

## Branch and PR flow

- Branch off `develop` into an ephemeral worktree named with a prefix: `feature-`, `bug-`/`fix-`, `doc-`, `test-`, `ops-`, `ci-`, `build-`, `release-` (hyphen, not slash). Push the branch when it is created, then after each commit. See the handbook's `branching.md`.
- Open a PR into `develop`. The repo is merge-commit only, so a merge always makes a merge commit titled `<PR title> (#N)`.
- Releases are cut from `main` via the CLI, not a PR, and end with the back-merge pull request. See the handbook's `releases.md`.

## PR titles

The PR title becomes the merge commit's subject, from which the changelog is generated, so prefix every title with a [Conventional Commit](https://www.conventionalcommits.org/) type: `feat:`, `fix:`, `perf:`, `refactor:`, `docs:`, `test:`, `build:`, `chore:`, `ci:`. See the handbook's `commits-and-changelogs.md`.

## Local checks before opening a PR

Run the same checks CI requires, so the PR is green on arrival. Xcode must be installed (the package uses Swift 6 language mode):

```bash
swift build
swift test
uvx --from "reuse[charset-normalizer]" reuse lint
```

A PR can't be merged until the required checks pass on a branch up to date with `develop`: `reuse`, the version guard (`no-version-change`) and `swift-test`; administrators are bound too.

## Code

- One module per directory under `Sources/`, with its tests under `Tests/<Module>Tests/`. `Package.swift` declares every target; work on a module changes only that module's two directories.
- `GameSimulation` uses no Apple frameworks, so that the rules can be tested without a screen.
- Every Swift file opens with its SPDX header, as a `//` comment.
- Tests use Swift Testing (`import Testing`).

## Versioning

The version lives in `VERSION.txt` only; never hard-code it elsewhere, and never change it in feature work. See the handbook's `releases.md`.

## AI contributors

Follow the behavioural contract in the handbook's `ai-collaboration.md`, with the departures recorded in [`decisions.md`](decisions.md).
