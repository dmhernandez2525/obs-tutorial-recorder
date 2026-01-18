#!/bin/zsh
# Build Tutorial Recorder menubar app

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Tutorial Recorder"
APP_PATH="$HOME/Desktop/${APP_NAME}.app"
BUILD_DIR="$SCRIPT_DIR/build"

echo "Building Tutorial Recorder..."

# Clean previous build
rm -rf "$BUILD_DIR"
rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR"

# Compile Swift
swiftc -o "$BUILD_DIR/TutorialRecorder" \
    -O \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework Cocoa \
    "$SCRIPT_DIR/main.swift"

echo "Creating app bundle..."

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/TutorialRecorder" "$APP_PATH/Contents/MacOS/"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TutorialRecorder</string>
    <key>CFBundleIdentifier</key>
    <string>com.tutorial-recorder.menubar</string>
    <key>CFBundleName</key>
    <string>Tutorial Recorder</string>
    <key>CFBundleDisplayName</key>
    <string>Tutorial Recorder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.video</string>
</dict>
</plist>
EOF

# Create icon (using system icon for now)
# We'll use iconutil to create proper icon later

echo "Done! App created at: $APP_PATH"
echo ""
echo "To add to Login Items (auto-start):"
echo "  System Settings > General > Login Items > Add '$APP_NAME'"
