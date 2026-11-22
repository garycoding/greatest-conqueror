#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# make-app.sh: assemble the macOS app bundle from the Swift package, without an
# Xcode project (docs/decisions.md), and sign it ad hoc. No Developer ID is used:
# the game is for personal use and is not distributed as a built app.
#
# Usage: scripts/make-app.sh [output-directory]   (default: build)
# Prints the path of the assembled .app.
set -euo pipefail

NAME="Greatest Conqueror"
EXE="GreatestConqueror"
BUNDLE_ID="io.github.garycoding.greatest-conqueror"
OUT="${1:-build}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION.txt")"
# The build stamp a hosting Mac compares with a joining one (NetMessage.hello).
BUILD="$(git -C "$ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)$(git -C "$ROOT" diff --quiet HEAD 2>/dev/null || echo -modified)"

cd "$ROOT"
swift build -c release --product "$EXE" >&2
BIN="$(swift build -c release --show-bin-path)/$EXE"
APP="$OUT/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXE"
# The resource bundles of the package's modules (GameCore's default tables), where
# the code SwiftPM generates for `Bundle.module` looks in an app: its Resources.
for bundle in "$(dirname "$BIN")"/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXE</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>GreatestConquerorBuild</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSLocalNetworkUsageDescription</key><string>Greatest Conqueror finds and joins matches on your local network.</string>
  <key>NSBonjourServices</key><array><string>_greatconqueror._tcp</string></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >&2
echo "$APP"
