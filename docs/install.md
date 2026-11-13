# Install and build

## Requirements

- macOS 26 or later.
- For the panel only, the Xcode command line tools (`xcode-select --install`).
- For the Control Center tiles, Xcode 26 or later and an Apple ID. A free Personal Team signs the build.

## Panel only, no Xcode

The panel needs only the command line tools.

```
xcode-select --install
git clone https://github.com/bashfulrobot/input-tile.git
cd input-tile
./build.sh run
mv build/InputTile.app /Applications/
```

`build.sh` compiles with `swiftc`, signs the app ad hoc, and launches it. Click the mic icon in the menu bar. If the icon is missing, allow InputTile in System Settings > Menu Bar.

## Control Center tiles, with Xcode

The tiles are a widget extension. They need Xcode to build and a signing identity to load.

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

A prebuilt copy for other people would need a paid Apple Developer ID certificate and notarization (UNVERIFIED for ad hoc signed extensions). No prebuilt release exists.

## Troubleshooting

- After every Xcode rebuild, run `pkill -x InputTileWidget`. Control Center keeps the old extension process running, so a tap can use stale code.
- Teams, Zoom and other virtual devices can switch the input back by themselves when no call is active. This is macOS behavior, and the same device does it from System Settings.
- To confirm the real input, run `system_profiler SPAudioDataType | grep -B12 "Default Input Device: Yes"`.
- If a tap does nothing, `log show --last 2m --predicate 'process == "InputTileWidget"'` shows whether the intent ran.

## Layout

- `Shared/AudioInput.swift` lists input devices and sets the default input, volume and mute through CoreAudio.
- `App/InputTileApp.swift` is the menu bar app, the panel window, and the `inputtile://panel` URL handler.
- `Widget/InputControls.swift` holds the two Control Center tiles and their App Intents.
- `project.yml` is the XcodeGen spec, and `build.sh` is the command line tools build.
