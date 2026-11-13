# InputTile

Sound input controls for macOS 26 (Tahoe), in two parts.

## 1. Sound-style input panel (menu bar app, no Xcode needed)

A menu bar item whose panel copies the system Sound panel: title, input volume slider, "Input" list of
devices (selected one shown as a white circle with a blue glyph), and a "Sound Settings…" link.
It updates live when devices are plugged in or the default input changes.

```
./build.sh run       # builds build/InputTile.app with the command line tools, ad-hoc signs, launches
./build.sh preview   # same panel in a normal window, for screenshots
```

If no mic icon shows, allow it in System Settings > Menu Bar.

Note: SwiftUI's `@State` is a macro whose plugin ships only in Xcode.app, so this code uses
`ObservableObject` instead to build with the command line tools.

## 2. Control Center tiles (needs Xcode 26 or later)

`Widget/` holds two `ControlWidget` tiles: Input (shows the current mic, a tap opens the panel from part 1
through the `inputtile://panel` URL, in the top-right corner like a Control Center sub-panel) and Input Mute.
The host app must be running or launchable for the tap to work.
Third-party controls get only buttons and toggles, no slider and no expandable device list, so they
cannot match the Sound control. Building the extension needs `xcodebuild`.

```
brew install xcodegen
xcodegen generate
open InputTile.xcodeproj
```

Set your Team ID on both targets, run once, then Edit Controls > search "Input".

## Layout

- `Shared/AudioInput.swift`: CoreAudio list, switch, volume, mute.
- `App/InputTileApp.swift`: menu bar panel.
- `Widget/InputControls.swift`: Control Center tiles and intents.
- `build.sh`: command line tools build.
