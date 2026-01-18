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
SOURCE_RECORD_VERSION="0.4.6"
SOURCE_RECORD_URL="https://github.com/exeldro/obs-source-record/releases/download/${SOURCE_RECORD_VERSION}/source-record-${SOURCE_RECORD_VERSION}-macos.zip"

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

    local packages=("websocat" "ffmpeg")

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
    log_step "Installing Source Record Plugin"

    local plugin_dir="$OBS_PLUGINS_DIR/source-record.plugin"

    # Create plugins directory if needed
    mkdir -p "$OBS_PLUGINS_DIR"

    if [[ -d "$plugin_dir" ]]; then
        log_success "Source Record plugin already installed"
        return 0
    fi

    log_info "Downloading Source Record v${SOURCE_RECORD_VERSION}..."

    local temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/source-record.zip"

    # Download the plugin
    if curl -fsSL -o "$zip_file" "$SOURCE_RECORD_URL" 2>/dev/null; then
        log_success "Downloaded Source Record plugin"
    else
        log_warning "Could not download from GitHub, trying OBS forum..."
        # Fallback: direct user to manual download
        log_warning "Please download Source Record manually from:"
        echo "  https://obsproject.com/forum/resources/source-record.1285/"
        echo ""
        echo "Then extract and copy source-record.plugin to:"
        echo "  $OBS_PLUGINS_DIR/"
        rm -rf "$temp_dir"
        return 1
    fi

    # Extract the plugin
    log_info "Extracting plugin..."
    unzip -q "$zip_file" -d "$temp_dir"

    # Find and copy the .plugin bundle
    local plugin_bundle=$(find "$temp_dir" -name "*.plugin" -type d | head -1)

    if [[ -n "$plugin_bundle" ]]; then
        cp -R "$plugin_bundle" "$OBS_PLUGINS_DIR/"
        log_success "Source Record plugin installed to $OBS_PLUGINS_DIR"
    else
        # Try alternate structure (some releases have different layouts)
        if [[ -d "$temp_dir/obs-plugins" ]]; then
            cp -R "$temp_dir/obs-plugins/"* "$OBS_PLUGINS_DIR/" 2>/dev/null || true
        fi
        if [[ -d "$temp_dir/data" ]]; then
            mkdir -p "$HOME/Library/Application Support/obs-studio/data"
            cp -R "$temp_dir/data/"* "$HOME/Library/Application Support/obs-studio/data/" 2>/dev/null || true
        fi
        log_success "Source Record plugin files installed"
    fi

    # Cleanup
    rm -rf "$temp_dir"
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
# Create Desktop Apps
# =============================================================================

create_app() {
    local app_name="$1"
    local script_path="$2"
    local app_path="$HOME/Desktop/${app_name}.app"

    log_info "Creating: $app_name.app"

    rm -rf "$app_path"
    mkdir -p "$app_path/Contents/MacOS"
    mkdir -p "$app_path/Contents/Resources"

    # Info.plist
    cat > "$app_path/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.tutorial-recorder.${app_name// /-}</string>
    <key>CFBundleName</key>
    <string>${app_name}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF

    # Launcher script
    cat > "$app_path/Contents/MacOS/launcher" << EOF
#!/bin/zsh
osascript -e 'tell application "Terminal"
    activate
    do script "$script_path"
end tell'
EOF

    chmod +x "$app_path/Contents/MacOS/launcher"
    log_success "Created: ~/Desktop/$app_name.app"
}

create_desktop_apps() {
    log_step "Creating Desktop Apps"

    create_app "Start Tutorial" "$SCRIPTS_DIR/start-tutorial.sh"
    create_app "Stop Tutorial" "$SCRIPTS_DIR/stop-tutorial.sh"
    create_app "Toggle Recording" "$SCRIPTS_DIR/toggle-recording.sh"
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
    echo "    - OBS Studio"
    echo "    - Source Record plugin (ISO recordings)"
    echo ""
    echo "  ${GREEN}Desktop Apps:${NC}"
    echo "    - Start Tutorial.app"
    echo "    - Stop Tutorial.app"
    echo "    - Toggle Recording.app"
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
    echo "  ${YELLOW}3. Add Source Record Filter to Each Source:${NC}"
    echo "     For each source you want to record separately:"
    echo "     - Right-click the source > Filters"
    echo "     - Click + under 'Effect Filters'"
    echo "     - Select 'Source Record'"
    echo "     - Configure recording format (MOV or MKV recommended)"
    echo "     - Leave file path empty (uses default ~/Movies)"
    echo ""
    echo "  ${YELLOW}4. Grant Permissions:${NC}"
    echo "     System Settings > Privacy & Security:"
    echo "     - Screen Recording: OBS"
    echo "     - Camera: OBS"
    echo "     - Microphone: OBS"
    echo "     - Accessibility: Terminal"
    echo ""
    echo "${BOLD}${GREEN}Ready to use!${NC}"
    echo "  Double-click 'Start Tutorial.app' on your Desktop to begin."
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
    install_obs
    install_source_record
    make_scripts_executable
    create_desktop_apps
    create_folders
    print_instructions
}

main "$@"
