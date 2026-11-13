# Xcode setup for the Control Center tiles

The tiles are a widget extension. They need Xcode to build and a signing identity to load. The panel alone does not need any of this, see [install.md](install.md).

## Requirements

- macOS 26 or later.
- Xcode 26 or later.
- An Apple ID. A free Personal Team signs the build.

## Build and run

```
brew install xcodegen
xcodegen generate
open InputTile.xcodeproj
```

In Xcode:

1. Add your Apple ID under Settings > Accounts.
2. Select the project, then set Team to your Personal Team on both targets, `InputTile` and `InputTileWidget`.
3. Choose the `InputTile` scheme with My Mac as the destination, then press ⌘R.
4. Run `pkill -x InputTileWidget` so Control Center loads the new build.
5. Open Control Center, choose Edit Controls, search "Input", and drag in the tiles.

macOS may ask whether to open "Input Tile" from an unidentified developer. Choose Open Anyway, since you built it.

## Sharing a build

A prebuilt copy for other people would need a paid Apple Developer ID certificate and notarization (UNVERIFIED for ad hoc signed extensions). No prebuilt release exists, so each person builds it with these steps.

## Troubleshooting

- After every Xcode rebuild, run `pkill -x InputTileWidget`. Control Center keeps the old extension process running, so a tap can use stale code.
- If a tap does nothing, `log show --last 2m --predicate 'process == "InputTileWidget"'` shows whether the intent ran.
- `xcodegen generate` rewrites the Xcode project, so set the Team again if Xcode asks.

## Project layout

- `Shared/AudioInput.swift` lists input devices and sets the default input, volume and mute through CoreAudio.
- `App/InputTileApp.swift` is the menu bar app, the panel window, and the `inputtile://panel` URL handler.
- `Widget/InputControls.swift` holds the two Control Center tiles and their App Intents.
- `project.yml` is the XcodeGen spec, and `build.sh` is the command line tools build.
