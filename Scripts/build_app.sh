#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="中大鸟桌宠.app"
APP_DIR="$ROOT_DIR/.build/$APP_NAME"
EXECUTABLE="$ROOT_DIR/.build/release/ZhongDaBirdPet"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/AppBundle/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/ZhongDaBirdPet"
if [[ -d "$ROOT_DIR/Assets/ZhongDaBird" ]]; then
  rsync -a --delete "$ROOT_DIR/Assets/ZhongDaBird/" "$APP_DIR/Contents/Resources/ZhongDaBird/"
fi
chmod +x "$APP_DIR/Contents/MacOS/ZhongDaBirdPet"

echo "$APP_DIR"
