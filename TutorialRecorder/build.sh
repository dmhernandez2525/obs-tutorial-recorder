#!/bin/zsh
# Build Tutorial Recorder menubar app

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Tutorial Recorder"
APP_PATH="$HOME/Desktop/${APP_NAME}.app"
BUILD_DIR="$SCRIPT_DIR/build"
SOURCES_DIR="$SCRIPT_DIR/Sources"

echo "Building Tutorial Recorder..."

# Clean previous build
rm -rf "$BUILD_DIR"
rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR"

# Collect all Swift source files
SWIFT_FILES=(
    "$SOURCES_DIR/Utils.swift"
    "$SOURCES_DIR/SyncManager.swift"
    "$SOURCES_DIR/TranscriptionManager.swift"
    "$SOURCES_DIR/RecordingManager.swift"
    "$SOURCES_DIR/OBSSourceManager.swift"
    "$SOURCES_DIR/Windows/ProgressWindow.swift"
    "$SOURCES_DIR/Windows/ProfileSetupWindow.swift"
    "$SOURCES_DIR/Windows/FirstTimeSetupWizard.swift"
    "$SOURCES_DIR/Windows/SyncConfigWindow.swift"
    "$SOURCES_DIR/Windows/SyncStatusWindow.swift"
    "$SOURCES_DIR/Windows/MainPanel.swift"
    "$SOURCES_DIR/AppDelegate.swift"
    "$SOURCES_DIR/main.swift"
)

echo "Compiling ${#SWIFT_FILES[@]} source files..."

# Compile Swift
swiftc -o "$BUILD_DIR/TutorialRecorder" \
    -O \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework Cocoa \
    "${SWIFT_FILES[@]}"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

# Create icon from iconset
echo "Building app icon..."
if [ -d "$SCRIPT_DIR/AppIcon.iconset" ]; then
    iconutil -c icns "$SCRIPT_DIR/AppIcon.iconset" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
elif [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$APP_PATH/Contents/Resources/"
fi

# Touch the app to refresh icon cache
touch "$APP_PATH"

echo ""
echo "✅ Build successful!"
echo "   App created at: $APP_PATH"
echo ""
echo "To add to Login Items (auto-start):"
echo "  System Settings > General > Login Items > Add '$APP_NAME'"
