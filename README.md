# InputTile

Two Control Center tiles for macOS 26 (Tahoe):

- Input Device: shows the current sound input, a tap switches to the next device.
- Input Mute: shows the device name, a tap mutes or unmutes the input.

## Build

Needs full Xcode 26 (the command line tools cannot build or sign a widget extension).

```
brew install xcodegen
xcodegen generate
open InputTile.xcodeproj
```

1. Set your Team ID under Signing & Capabilities for both targets (or in `project.yml`).
2. Run the `InputTile` scheme once so the extension registers.
3. Control Center > Edit Controls > search "Input", drag a tile in.

The host app window lists input devices to check CoreAudio works before using the tiles.

## Layout

- `Shared/AudioInput.swift`: CoreAudio list, switch, mute.
- `Widget/InputControls.swift`: `ControlWidget` tiles and `AppIntent` actions.
- `App/`: host app (required for the extension to register).
