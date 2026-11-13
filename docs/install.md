# Install

This installs the panel and menu bar icon. It needs only the Xcode command line tools, not Xcode. For the Control Center tiles, see [xcode-setup.md](xcode-setup.md).

## Requirements

- macOS 26 or later.
- The Xcode command line tools (`xcode-select --install`).

## Steps

```
xcode-select --install
git clone https://github.com/bashfulrobot/input-tile.git
cd input-tile
./build.sh run
mv build/InputTile.app /Applications/
```

`build.sh` compiles with `swiftc`, signs the app ad hoc, and launches it. Click the mic icon in the menu bar to open the panel.

## Troubleshooting

- If the menu bar icon is missing, allow InputTile in System Settings > Menu Bar.
- Teams, Zoom and other virtual devices can switch the input back by themselves when no call is active. This is macOS behavior, and the same device does it from System Settings.
- To confirm the real input, run `system_profiler SPAudioDataType | grep -B12 "Default Input Device: Yes"`.
