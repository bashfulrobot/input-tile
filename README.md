# InputTile

Sound input controls for macOS 26 (Tahoe) and later. A Control Center tile shows your current microphone, and tapping it opens a panel that copies the system Sound panel, with an input volume slider and a list of input devices.

## What you get

- Input tile for Control Center, showing the current mic. A tap opens the panel.
- Input Mute tile, a toggle that mutes the current input.
- Sound-style panel with a volume slider, the device list, and a link to Sound Settings.
- Menu bar icon that opens the same panel.

The panel updates live when you plug in a mic or change the input elsewhere, and the tiles follow.

## Requirements

- macOS 26 or later.
- For the panel only, the Xcode command line tools (`xcode-select --install`).
- For the Control Center tiles, Xcode 26 or later and an Apple ID. A free Personal Team signs the build.

## Quickstart, panel only

```
./build.sh run
```

This builds `build/InputTile.app` with `swiftc`, signs it ad hoc, and launches it. Click the mic icon in the menu bar. If the icon is missing, allow InputTile in System Settings > Menu Bar.

## Install without Xcode

The panel needs only the command line tools, so anyone can build it:

```
xcode-select --install
git clone https://github.com/bashfulrobot/input-tile.git
cd input-tile
./build.sh run
mv build/InputTile.app /Applications/
```

The Control Center tiles are a widget extension, which needs Xcode to build and a signing identity to load. A prebuilt copy for other people would need a paid Apple Developer ID certificate and notarization (UNVERIFIED for ad hoc signed extensions). No prebuilt release exists yet.

## Quickstart, with the Control Center tiles

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

## Use it

- Tap the Input tile to open the panel in the top-right corner of the screen.
- Click a device to make it the system input, and drag the slider to set its volume.
- Click anywhere outside the panel to close it.
- Tap the Input Mute tile to mute or unmute.

## Troubleshooting

- After every Xcode rebuild, run `pkill -x InputTileWidget`. Control Center keeps the old extension process running, so a tap can use stale code.
- Teams, Zoom and other virtual devices can switch the input back by themselves when no call is active. This is macOS behavior, and the same device does it from System Settings.
- To confirm the real input, run `system_profiler SPAudioDataType | grep -B12 "Default Input Device: Yes"`.
- If a tap does nothing, `log show --last 2m --predicate 'process == "InputTileWidget"'` shows whether the intent ran.

## Limits

Third-party Control Center tiles can only be buttons and toggles (WidgetKit `ControlWidgetButton` and `ControlWidgetToggle`). They cannot hold a slider or expand into a device list the way the system Sound control does. The tile opens a separate panel styled to match.

## Layout

- `Shared/AudioInput.swift` lists input devices and sets the default input, volume and mute through CoreAudio.
- `App/InputTileApp.swift` is the menu bar app, the panel window, and the `inputtile://panel` URL handler.
- `Widget/InputControls.swift` holds the two Control Center tiles and their App Intents.
- `project.yml` is the XcodeGen spec, and `build.sh` is the command line tools build.
