#!/usr/bin/env bash
# Builds the menu bar panel app with the Xcode command line tools only (no Xcode.app).
# Output: build/InputTile.app, ad-hoc signed. Usage: ./build.sh [run]
set -euo pipefail
cd "$(dirname "$0")"

SDK="${SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
APP="build/InputTile.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -parse-as-library \
  -sdk "$SDK" -target "$(uname -m)-apple-macos26.0" \
  -swift-version 5 \
  App/InputTileApp.swift Shared/AudioInput.swift \
  -o "$APP/Contents/MacOS/InputTile"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>com.bashfulrobot.InputTile</string>
	<key>CFBundleName</key><string>InputTile</string>
	<key>CFBundleExecutable</key><string>InputTile</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>LSUIElement</key><true/>
	<key>CFBundleURLTypes</key>
	<array><dict>
		<key>CFBundleURLName</key><string>com.bashfulrobot.InputTile</string>
		<key>CFBundleURLSchemes</key><array><string>inputtile</string></array>
	</dict></array>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "built $APP"

# Stop only this user's running copy.
case "${1:-}" in
  run)  pkill -x -u "$(id -u)" InputTile 2>/dev/null || true; open "$APP" ;;
  show) pkill -x -u "$(id -u)" InputTile 2>/dev/null || true; open "$APP" --args --show ;;
esac
