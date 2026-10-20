#!/bin/zsh
# Builds Pomodoro.app and installs it to ~/Applications.
set -e
cd "$(dirname "$0")"

APP=build/Pomodoro.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macos14.0" \
  Pomodoro.swift -o "$APP/Contents/MacOS/Pomodoro"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Pomodoro</string>
  <key>CFBundleDisplayName</key><string>Pomodoro</string>
  <key>CFBundleIdentifier</key><string>local.pomodoro.menubar</string>
  <key>CFBundleExecutable</key><string>Pomodoro</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

mkdir -p ~/Applications
pkill -x Pomodoro 2>/dev/null || true
rm -rf ~/Applications/Pomodoro.app
cp -R "$APP" ~/Applications/
open ~/Applications/Pomodoro.app
echo "Installed to ~/Applications/Pomodoro.app"
