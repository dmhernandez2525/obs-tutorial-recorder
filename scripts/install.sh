#!/bin/zsh
# =============================================================================
# Install OBS Tutorial Recorder
# =============================================================================
# This script:
# 1. Installs required dependencies (websocat)
# 2. Makes scripts executable
# 3. Creates Automator apps on Desktop
# 4. Sets up the Tutorial Recordings folder
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }
log_step() { echo "\n${CYAN}=== $1 ===${NC}\n"; }

# =============================================================================
# Install Dependencies
# =============================================================================

install_dependencies() {
    log_step "Installing Dependencies"

    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew not installed. Please install Homebrew first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi

    # Install websocat (for OBS WebSocket communication)
    if ! command -v websocat &> /dev/null; then
        log_info "Installing websocat (for OBS WebSocket control)..."
        brew install websocat
        log_success "websocat installed"
    else
        log_success "websocat already installed"
    fi

    # Check for ffmpeg
    if ! command -v ffmpeg &> /dev/null; then
        log_info "Installing ffmpeg (for video remuxing)..."
        brew install ffmpeg
        log_success "ffmpeg installed"
    else
        log_success "ffmpeg already installed"
    fi

    # Check for OBS
    if [[ ! -d "/Applications/OBS.app" ]]; then
        log_info "Installing OBS Studio..."
        brew install --cask obs
        log_success "OBS installed"
    else
        log_success "OBS already installed"
    fi
}

# =============================================================================
# Make Scripts Executable
# =============================================================================

make_scripts_executable() {
    log_step "Making Scripts Executable"

    chmod +x "$SCRIPT_DIR/start-tutorial.sh"
    chmod +x "$SCRIPT_DIR/stop-tutorial.sh"
    chmod +x "$SCRIPT_DIR/toggle-recording.sh"
    chmod +x "$SCRIPT_DIR/setup-obs.sh"

    log_success "All scripts are now executable"
}

# =============================================================================
# Create Automator Apps
# =============================================================================

create_automator_app() {
    local app_name="$1"
    local script_path="$2"
    local app_path="$HOME/Desktop/${app_name}.app"

    log_info "Creating: $app_name.app"

    # Remove existing app
    rm -rf "$app_path"

    # Create app bundle structure
    mkdir -p "$app_path/Contents/MacOS"
    mkdir -p "$app_path/Contents/Resources"

    # Create Info.plist
    cat > "$app_path/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.tutorial-recorder.${app_name// /-}</string>
    <key>CFBundleName</key>
    <string>${app_name}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

    # Create launcher script
    cat > "$app_path/Contents/MacOS/launcher" << EOF
#!/bin/zsh
# Open Terminal and run the script
osascript -e 'tell application "Terminal"
    activate
    do script "$script_path"
end tell'
EOF

    chmod +x "$app_path/Contents/MacOS/launcher"

    log_success "Created: $app_path"
}

create_all_apps() {
    log_step "Creating Desktop Apps"

    create_automator_app "Start Tutorial" "$SCRIPT_DIR/start-tutorial.sh"
    create_automator_app "Stop Tutorial" "$SCRIPT_DIR/stop-tutorial.sh"
    create_automator_app "Toggle Recording" "$SCRIPT_DIR/toggle-recording.sh"

    log_success "All apps created on Desktop"
}

# =============================================================================
# Create Tutorial Recordings Folder
# =============================================================================

create_recordings_folder() {
    log_step "Creating Recordings Folder"

    local recordings_dir="$HOME/Desktop/Tutorial Recordings"

    if [[ ! -d "$recordings_dir" ]]; then
        mkdir -p "$recordings_dir"
        log_success "Created: $recordings_dir"
    else
        log_success "Folder already exists: $recordings_dir"
    fi
}

# =============================================================================
# Print Post-Install Instructions
# =============================================================================

print_post_install() {
    log_step "Installation Complete!"

    echo "The following items have been installed:"
    echo ""
    echo "  ${GREEN}Desktop Apps:${NC}"
    echo "    - Start Tutorial.app   (double-click to begin a new session)"
    echo "    - Stop Tutorial.app    (double-click to end and process recording)"
    echo "    - Toggle Recording.app (single app for start/stop)"
    echo ""
    echo "  ${GREEN}Scripts:${NC}"
    echo "    - $SCRIPT_DIR/start-tutorial.sh"
    echo "    - $SCRIPT_DIR/stop-tutorial.sh"
    echo "    - $SCRIPT_DIR/toggle-recording.sh"
    echo "    - $SCRIPT_DIR/setup-obs.sh"
    echo ""
    echo "  ${GREEN}Recordings Folder:${NC}"
    echo "    - ~/Desktop/Tutorial Recordings/"
    echo ""
    echo "${CYAN}Next Steps:${NC}"
    echo "  1. Run the OBS setup script:"
    echo "     ${BLUE}$SCRIPT_DIR/setup-obs.sh${NC}"
    echo ""
    echo "  2. Follow the on-screen instructions to configure OBS"
    echo ""
    echo "  3. Grant necessary permissions in System Settings when prompted"
    echo ""
    echo "  4. Test by double-clicking 'Start Tutorial' on your Desktop"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "${GREEN}========================================${NC}"
    echo "${GREEN}   OBS Tutorial Recorder Installer     ${NC}"
    echo "${GREEN}========================================${NC}"
    echo ""

    install_dependencies
    make_scripts_executable
    create_all_apps
    create_recordings_folder
    print_post_install

    # Ask to run OBS setup
    echo ""
    read -q "REPLY?Run OBS setup now? (y/n) "
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/setup-obs.sh"
    fi
}

main "$@"
