# Koikoi

花札こいこい（任天堂ルール準拠）— iPhone / iPad / macOS / Apple Vision Pro.

Swift port of [ngs/go-koikoi](https://github.com/ngs/go-koikoi) (browser version: https://koikoi.ngs.io ).

See AGENTS.md for development docs.

## Building from source

The graphics live in a separate private repository, wired in as a git submodule
at `Assets/koikoi-swift-assets`, so that they are not covered by this project's
MIT license.

```bash
git clone git@github.com:ngs/koikoi-swift.git
cd koikoi-swift
git submodule update --init   # requires access to the private assets repository
swift test                    # rules engine and view models; no artwork needed
tuist generate --no-open      # Xcode workspace for the app target
```

`swift test` covers `KoikoiCore`, `KoikoiAI` and `KoikoiUI` and passes without
the submodule. Building the **app** target does need it: without the artwork the
app has no card images and no app icon, and there is no placeholder fallback.
Read the code, run the tests and port the rules freely; building a shippable app
from a fresh public clone is not supported.

## License

The source code is MIT licensed. The graphics are **not**: the card artwork, the
app icons and every other image belonging to the project, including the App
Store screenshots under `fastlane/screenshots`, are all rights reserved and may
not be reused without permission. See [LICENSE](LICENSE) for the exact carve-out.
