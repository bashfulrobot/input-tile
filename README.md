# InputTile

Sound input controls for macOS 26 (Tahoe) and later. A panel copies the system Sound panel, with an input volume slider and a list of input devices. Control Center tiles show your current microphone and open that panel.

## Two ways to install

| | Panel only | Panel and Control Center tiles |
| --- | --- | --- |
| You get | A menu bar icon that opens the panel | The same, plus the Input and Input Mute tiles in Control Center |
| You need | Xcode command line tools | Xcode 26 or later and an Apple ID |
| Setup | Quickstart below | [docs/xcode-setup.md](docs/xcode-setup.md) |

## Quickstart, panel only

```
xcode-select --install
git clone https://github.com/bashfulrobot/input-tile.git
cd input-tile
./build.sh run
```

This builds the panel with only the command line tools and adds a mic icon to the menu bar. It does not add anything to Control Center. See [docs/install.md](docs/install.md) for details and troubleshooting.

## Add the Control Center tiles

The tiles are a second, separate step. They are a widget extension, so they need full Xcode and a signing identity. Follow [docs/xcode-setup.md](docs/xcode-setup.md) after the quickstart above, or instead of it, since the Xcode build includes the panel.

- The Input tile shows the current mic, and a tap opens the panel.
- The Input Mute tile mutes or unmutes the current input.

## Limits

Third-party Control Center tiles can only be buttons and toggles. They cannot hold a slider or expand into a device list the way the system Sound control does, so the tile opens a separate panel styled to match.

## License

[MIT](LICENSE)
