# input-tile

macOS 26+ menu bar panel with sound input controls, plus Control Center tiles (a widget extension). Swift.

## Build

- Panel only: `./build.sh` builds `build/InputTile.app`. `./build.sh run` also launches it. Needs only the Xcode command line tools.
- Panel and tiles: `brew install xcodegen`, then `xcodegen generate` to build `InputTile.xcodeproj` from `project.yml`. Needs Xcode 26+. See `docs/xcode-setup.md`.

There is no test suite and no justfile.

## Docs

`README.md`, `docs/install.md`, `docs/xcode-setup.md`.
