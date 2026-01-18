#!/bin/zsh
# =============================================================================
# OBS Tutorial Recorder - Complete Installer
# =============================================================================
# Run this script from the repository root:
#   ./install.sh
#
# This script will:
#   1. Install dependencies (Homebrew packages)
#   2. Install OBS Studio (if not present)
#   3. Install Source Record plugin for ISO recordings
#   4. Create Desktop apps for one-click recording
#   5. Set up folder structure
#   6. Configure OBS WebSocket settings
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Configuration
RECORDINGS_BASE="$HOME/Desktop/Tutorial Recordings"
OBS_PLUGINS_DIR="$HOME/Library/Application Support/obs-studio/plugins"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[OK]${NC} $1"; }
log_warning() { echo "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }
log_step() { echo "\n${CYAN}${BOLD}=== $1 ===${NC}\n"; }

# =============================================================================
# Pre-flight Checks
# =============================================================================

preflight_checks() {
    log_step "Pre-flight Checks"

    # Check macOS version
    local macos_version=$(sw_vers -productVersion)
    log_info "macOS version: $macos_version"

    # Check architecture
    local arch=$(uname -m)
    log_info "Architecture: $arch"

    if [[ "$arch" != "arm64" && "$arch" != "x86_64" ]]; then
        log_error "Unsupported architecture: $arch"
        exit 1
    fi

    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew not installed."
        echo ""
        echo "Install Homebrew first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        exit 1
    fi
    log_success "Homebrew installed"
}

# =============================================================================
# Install Dependencies
# =============================================================================

install_dependencies() {
    log_step "Installing Dependencies"

    local packages=("websocat" "ffmpeg" "rclone" "whisper-cpp")

    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            log_info "Installing $pkg..."
            brew install "$pkg"
            log_success "$pkg installed"
        else
            log_success "$pkg already installed"
        fi
    done
}

# =============================================================================
# Setup Transcription (Whisper)
# =============================================================================

setup_transcription() {
    log_step "Setting Up Transcription"

    local MODELS_DIR="$HOME/.cache/whisper"
    local MODEL_FILE="ggml-small.en.bin"
    local MODEL_PATH="$MODELS_DIR/$MODEL_FILE"
    local MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_FILE"

    mkdir -p "$MODELS_DIR"

    if [[ -f "$MODEL_PATH" ]]; then
        log_success "Whisper model already downloaded"
    else
        log_info "Downloading Whisper small model (500MB)..."
        log_info "This provides higher accuracy for tutorial content."
        echo ""

        if curl -L "$MODEL_URL" -o "$MODEL_PATH" --progress-bar; then
            log_success "Whisper model downloaded to $MODELS_DIR"
        else
            log_warning "Could not download Whisper model automatically"
            log_info "You can download it later from Preferences"
        fi
    fi
}

# =============================================================================
# Install OBS Studio
# =============================================================================

install_obs() {
    log_step "Installing OBS Studio"

    if [[ -d "/Applications/OBS.app" ]]; then
        local obs_version=$(/Applications/OBS.app/Contents/MacOS/OBS --version 2>/dev/null | head -1 || echo "unknown")
        log_success "OBS already installed: $obs_version"
    else
        log_info "Installing OBS Studio via Homebrew..."
        brew install --cask obs
        log_success "OBS Studio installed"
    fi
}

# =============================================================================
# Install Source Record Plugin
# =============================================================================

install_source_record() {
    log_step "Source Record Plugin"

    # Use the dedicated setup script to install the plugin
    if [[ -f "$SCRIPTS_DIR/setup-source-record.sh" ]]; then
        "$SCRIPTS_DIR/setup-source-record.sh" install
    else
        log_warning "setup-source-record.sh not found, skipping plugin installation"
        log_info "Source Record plugin enables ISO recordings (separate file per source)"
        log_info "Download manually from: https://obsproject.com/forum/resources/source-record.1285/"
    fi
}

# =============================================================================
# Make Scripts Executable
# =============================================================================

make_scripts_executable() {
    log_step "Setting Up Scripts"

    chmod +x "$SCRIPTS_DIR/"*.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/install.sh"

    log_success "All scripts are now executable"
}

# =============================================================================
# Build Menubar App
# =============================================================================

build_menubar_app() {
    log_step "Building Menubar App"

    local app_name="Tutorial Recorder"
    local app_path="$HOME/Desktop/${app_name}.app"
    local source_dir="$SCRIPT_DIR/TutorialRecorder"
    local build_dir="$source_dir/build"

    # Check for Swift compiler
    if ! command -v swiftc &> /dev/null; then
        log_warning "Swift compiler not found. Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        log_warning "Please run install.sh again after Xcode tools are installed."
        return 1
    fi

    log_info "Compiling Swift menubar app..."

    # Clean previous build
    rm -rf "$build_dir"
    rm -rf "$app_path"
    mkdir -p "$build_dir"

    # Compile Swift
    if swiftc -o "$build_dir/TutorialRecorder" \
        -O \
        -target arm64-apple-macosx12.0 \
        -sdk $(xcrun --show-sdk-path) \
        -framework Cocoa \
        "$source_dir/main.swift" 2>/dev/null; then
        log_success "Compiled successfully"
    else
        log_error "Swift compilation failed"
        log_info "Falling back to shell script apps..."
        create_fallback_apps
        return 0
    fi

    log_info "Creating app bundle..."

    # Create app bundle structure
    mkdir -p "$app_path/Contents/MacOS"
    mkdir -p "$app_path/Contents/Resources"

    # Copy executable
    cp "$build_dir/TutorialRecorder" "$app_path/Contents/MacOS/"

    # Create Info.plist
    cat > "$app_path/Contents/Info.plist" << 'PLIST'
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
PLIST

    # Build and copy app icon
    if [[ -d "$source_dir/AppIcon.iconset" ]]; then
        log_info "Building app icon..."
        iconutil -c icns "$source_dir/AppIcon.iconset" -o "$app_path/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    elif [[ -f "$source_dir/AppIcon.icns" ]]; then
        cp "$source_dir/AppIcon.icns" "$app_path/Contents/Resources/"
    fi

    # Touch the app to refresh icon cache
    touch "$app_path"

    log_success "Created: ~/Desktop/$app_name.app"

    # Remove old apps if they exist
    rm -rf "$HOME/Desktop/Start Tutorial.app" 2>/dev/null
    rm -rf "$HOME/Desktop/Stop Tutorial.app" 2>/dev/null
    rm -rf "$HOME/Desktop/Toggle Recording.app" 2>/dev/null
}

create_fallback_apps() {
    # Fallback: create simple shell script apps
    log_info "Creating fallback shell script apps..."

    local app_path="$HOME/Desktop/Start Tutorial.app"
    rm -rf "$app_path"
    mkdir -p "$app_path/Contents/MacOS"

    cat > "$app_path/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.tutorial-recorder.start</string>
    <key>CFBundleName</key>
    <string>Start Tutorial</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF

    cat > "$app_path/Contents/MacOS/launcher" << EOF
#!/bin/zsh
osascript -e 'tell application "Terminal"
    activate
    do script "$SCRIPTS_DIR/start-tutorial.sh"
end tell'
EOF
    chmod +x "$app_path/Contents/MacOS/launcher"
    log_success "Created: ~/Desktop/Start Tutorial.app"

    # Stop app
    app_path="$HOME/Desktop/Stop Tutorial.app"
    rm -rf "$app_path"
    mkdir -p "$app_path/Contents/MacOS"

    cat > "$app_path/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.tutorial-recorder.stop</string>
    <key>CFBundleName</key>
    <string>Stop Tutorial</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF

    cat > "$app_path/Contents/MacOS/launcher" << EOF
#!/bin/zsh
osascript -e 'tell application "Terminal"
    activate
    do script "$SCRIPTS_DIR/stop-tutorial.sh"
end tell'
EOF
    chmod +x "$app_path/Contents/MacOS/launcher"
    log_success "Created: ~/Desktop/Stop Tutorial.app"
}

# =============================================================================
# Create Folder Structure
# =============================================================================

create_folders() {
    log_step "Creating Folder Structure"

    mkdir -p "$RECORDINGS_BASE"
    log_success "Created: $RECORDINGS_BASE"
}

# =============================================================================
# Print Instructions
# =============================================================================

print_instructions() {
    log_step "Installation Complete!"

    echo "${BOLD}What was installed:${NC}"
    echo ""
    echo "  ${GREEN}Dependencies:${NC}"
    echo "    - websocat (WebSocket communication)"
    echo "    - ffmpeg (video processing)"
    echo "    - rclone (cloud sync to Google Drive)"
    echo "    - whisper-cpp (audio transcription)"
    echo "    - OBS Studio"
    echo "    - Source Record plugin (ISO recordings)"
    echo ""
    echo "  ${GREEN}Menubar App:${NC}"
    echo "    - Tutorial Recorder.app (on Desktop)"
    echo "    - Adds icon to menu bar for quick control"
    echo "    - Includes cloud sync integration"
    echo ""
    echo "  ${GREEN}Folders:${NC}"
    echo "    - ~/Desktop/Tutorial Recordings/"
    echo ""
    echo "${BOLD}${CYAN}=== REQUIRED: First-Time OBS Setup ===${NC}"
    echo ""
    echo "  ${YELLOW}1. Enable WebSocket Server:${NC}"
    echo "     - Open OBS"
    echo "     - Go to Tools > WebSocket Server Settings"
    echo "     - Check 'Enable WebSocket server'"
    echo "     - Set Port to 4455"
    echo "     - UNCHECK 'Enable Authentication'"
    echo "     - Click OK"
    echo ""
    echo "  ${YELLOW}2. Add Your Sources:${NC}"
    echo "     In OBS, click + in Sources panel to add:"
    echo "     - macOS Screen Capture (for each monitor)"
    echo "     - Video Capture Device (your camera)"
    echo "     - Audio Input Capture (your microphone)"
    echo ""
    echo "  ${YELLOW}3. Add Source Record Filters (Automated):${NC}"
    echo "     After adding sources, run this to add filters automatically:"
    echo "     ${CYAN}./scripts/setup-source-record.sh filters${NC}"
    echo "     (Or add manually: right-click source > Filters > + > Source Record)"
    echo ""
    echo "  ${YELLOW}4. Grant Permissions:${NC}"
    echo "     System Settings > Privacy & Security:"
    echo "     - Screen Recording: OBS"
    echo "     - Camera: OBS"
    echo "     - Microphone: OBS"
    echo "     - Accessibility: Terminal"
    echo ""
    echo "${BOLD}${CYAN}=== OPTIONAL: Cloud Sync Setup ===${NC}"
    echo ""
    echo "  To backup recordings to Google Drive:"
    echo "  ${CYAN}./scripts/setup-cloud-sync.sh configure${NC}"
    echo ""
    echo "  This enables automatic backup of recordings after each session."
    echo "  Access sync controls from the menubar app's Cloud Sync submenu."
    echo ""
    echo "${BOLD}${GREEN}Ready to use!${NC}"
    echo ""
    echo "  1. Double-click 'Tutorial Recorder.app' on Desktop to launch"
    echo "  2. Look for the video icon in your menu bar"
    echo "  3. Click it to start/stop recordings"
    echo ""
    echo "  ${CYAN}Tip:${NC} Add to Login Items for auto-start:"
    echo "       System Settings > General > Login Items > Add 'Tutorial Recorder'"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "${GREEN}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}${BOLD}║     OBS Tutorial Recorder - Complete Installer     ║${NC}"
    echo "${GREEN}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    preflight_checks
    install_dependencies
    setup_transcription
    install_obs
    install_source_record
    make_scripts_executable
    build_menubar_app
    create_folders
    print_instructions
}

main "$@"
