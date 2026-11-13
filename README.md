# InputTile

Sound input controls for macOS 26 (Tahoe) and later. A Control Center tile shows your current microphone, and tapping it opens a panel that copies the system Sound panel, with an input volume slider and a list of input devices.

- Input tile for Control Center, showing the current mic. A tap opens the panel.
- Input Mute tile, a toggle that mutes the current input.
- Panel with a volume slider and device list, also opened from a menu bar icon.

## Quickstart

```
xcode-select --install
git clone https://github.com/bashfulrobot/input-tile.git
cd input-tile
./build.sh run
```

This builds the panel with only the command line tools and adds a mic icon to the menu bar.

More detail:

- [docs/install.md](docs/install.md) covers the panel install and troubleshooting.
- [docs/xcode-setup.md](docs/xcode-setup.md) covers building the Control Center tiles, which need Xcode.

## Limits

Third-party Control Center tiles can only be buttons and toggles. They cannot hold a slider or expand into a device list the way the system Sound control does, so the tile opens a separate panel styled to match.

## License

[MIT](LICENSE)
