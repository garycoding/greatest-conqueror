# Licensing

Copyright © 2026 Gary Frattarola.

## How this project is licensed

The code and the game's artwork are licensed under `AGPL-3.0-or-later`. The full text is in [`LICENSE`](LICENSE) and [`LICENSES/`](LICENSES/).

## Per-bucket licensing

Different kinds of content carry different licences (encoded in [`REUSE.toml`](REUSE.toml) and per-file SPDX headers):

| Bucket | Licence |
|---|---|
| Code, build scripts, configs, lockfiles, workflows | `AGPL-3.0-or-later` |
| The game's artwork (`Sources/Artwork/`, and the drawings in `docs/art/`) | `AGPL-3.0-or-later` |
| Documentation (`docs/` apart from `docs/art/`, `README.md`, this file) | `CC-BY-4.0` |

The artwork carries the code's licence because the sprites are part of the program: one licence for everything the app contains leaves no question about combining the two.

## REUSE compliance

This repo is [REUSE](https://reuse.software/)-compliant. Every file has a licence via an SPDX header or a `REUSE.toml` annotation. Verify with:

```bash
uvx --from "reuse[charset-normalizer]" reuse lint
```

Any new file needs an SPDX header or a `REUSE.toml` entry, or the lint breaks.
