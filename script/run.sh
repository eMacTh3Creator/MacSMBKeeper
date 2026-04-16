#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Ensure xcodegen is installed
if ! command -v xcodegen &>/dev/null; then
    echo "Error: xcodegen is not installed. Install with: brew install xcodegen"
    exit 1
fi

echo "==> Generating Xcode project..."
xcodegen generate --spec project.yml

BUILD_DIR="/tmp/MacSMBKeeper-build"

echo "==> Building MacSMBKeeper..."
xcodebuild -project MacSMBKeeper.xcodeproj \
    -scheme MacSMBKeeper \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | tail -20

APP_PATH="$BUILD_DIR/Build/Products/Release/Mac SMB Keeper.app"
if [ -d "$APP_PATH" ]; then
    echo ""
    echo "==> Build succeeded!"
    echo "    App: $APP_PATH"
    echo ""
    echo "    To run: open \"$APP_PATH\""
else
    echo ""
    echo "==> Build failed. Check output above."
    exit 1
fi
