#!/bin/zsh
# =============================================================================
# OBS Initial Setup Script
# =============================================================================
# Run this ONCE to configure OBS for tutorial recording.
# This script:
# 1. Creates necessary OBS configuration files
# 2. Sets up recording profiles
# 3. Provides manual configuration steps
# =============================================================================

set -e

# Configuration paths
OBS_CONFIG_DIR="$HOME/Library/Application Support/obs-studio"
OBS_PROFILES_DIR="$OBS_CONFIG_DIR/basic/profiles"
OBS_SCENES_DIR="$OBS_CONFIG_DIR/basic/scenes"
PROFILE_NAME="Tutorial Recording"
SCENE_COLLECTION_NAME="Tutorial Recording"

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
# Create OBS Profile for Recording Settings
# =============================================================================

create_obs_profile() {
    local profile_dir="$OBS_PROFILES_DIR/$PROFILE_NAME"

    log_info "Creating OBS profile: $PROFILE_NAME"

    mkdir -p "$profile_dir"

    # Basic.ini - Main profile settings
    cat > "$profile_dir/basic.ini" << 'EOF'
[General]
Name=Tutorial Recording

[Video]
BaseCX=1920
BaseCY=1080
OutputCX=1920
OutputCY=1080
FPSType=0
FPSCommon=30

[Audio]
SampleRate=48000
ChannelSetup=Stereo

[Output]
Mode=Advanced
FilePath=~/Desktop/Tutorial Recordings
RecFormat=mkv
RecTracks=3
RecEncoder=apple_vt_h264_hw
RecMuxerCustom=
RecSplitFile=false
RecSplitFileTime=15
RecSplitFileSize=2048
RecSplitFileResetTimestamps=false
FlvTrack=1
EOF

    # recordEncoder.json - Hardware encoder settings (Apple VideoToolbox)
    cat > "$profile_dir/recordEncoder.json" << 'EOF'
{
    "bitrate": 40000,
    "keyint_sec": 2,
    "profile": "high",
    "rate_control": "CBR"
}
EOF

    log_success "Profile created at: $profile_dir"
}

# =============================================================================
# Create OBS Scene Collection
# =============================================================================

create_scene_collection() {
    local scene_file="$OBS_SCENES_DIR/$SCENE_COLLECTION_NAME.json"

    log_info "Creating scene collection: $SCENE_COLLECTION_NAME"

    mkdir -p "$OBS_SCENES_DIR"

    # This is a minimal scene collection that OBS can load
    # The actual sources need to be added manually due to device IDs
    cat > "$scene_file" << 'EOF'
{
    "current_program_scene": "Tutorial Recording",
    "current_scene": "Tutorial Recording",
    "name": "Tutorial Recording",
    "scene_order": [
        {"name": "Tutorial Recording"},
        {"name": "Camera Only"},
        {"name": "Screen Only"}
    ],
    "scenes": [
        {
            "name": "Tutorial Recording",
            "items": []
        },
        {
            "name": "Camera Only",
            "items": []
        },
        {
            "name": "Screen Only",
            "items": []
        }
    ],
    "sources": []
}
EOF

    log_success "Scene collection created at: $scene_file"
}

# =============================================================================
# Print Manual Setup Instructions
# =============================================================================

print_manual_instructions() {
    log_step "Manual Configuration Steps"

    echo "After running this script, open OBS and complete these steps:"
    echo ""

    echo "${CYAN}1. ENABLE WEBSOCKET SERVER${NC}"
    echo "   - Go to: Tools > WebSocket Server Settings"
    echo "   - Check 'Enable WebSocket server'"
    echo "   - Port: 4455 (default)"
    echo "   - Uncheck 'Enable Authentication' (for easier automation)"
    echo "   - Click OK"
    echo ""

    echo "${CYAN}2. SELECT THE PROFILE${NC}"
    echo "   - Go to: Profile > Tutorial Recording"
    echo "   - This loads the recording settings we created"
    echo ""

    echo "${CYAN}3. SELECT THE SCENE COLLECTION${NC}"
    echo "   - Go to: Scene Collection > Tutorial Recording"
    echo "   - This loads the empty scene structure"
    echo ""

    echo "${CYAN}4. ADD DISPLAY CAPTURE SOURCE${NC}"
    echo "   - In the Sources panel, click '+'"
    echo "   - Select 'macOS Screen Capture'"
    echo "   - Name it: 'Display Capture'"
    echo "   - Choose your monitor in settings"
    echo "   - Check 'Show Cursor'"
    echo "   - Click OK"
    echo ""

    echo "${CYAN}5. ADD CAMERA SOURCE (Sony ZV-E10)${NC}"
    echo "   - In the Sources panel, click '+'"
    echo "   - Select 'Video Capture Device'"
    echo "   - Name it: 'Camera - Sony ZV-E10'"
    echo "   - Device: Select 'Sony ZV-E10' or 'USB Video' or your capture card"
    echo "   - Preset: 1280x720 (for USB-C) or 1920x1080 (for capture card)"
    echo "   - Click OK"
    echo "   - Resize and position in corner (bottom-right recommended)"
    echo ""

    echo "${CYAN}6. ADD AUDIO SOURCE (FIFINE Microphone)${NC}"
    echo "   - In the Sources panel, click '+'"
    echo "   - Select 'Audio Input Capture'"
    echo "   - Name it: 'Microphone - FIFINE'"
    echo "   - Device: Select 'fifine SC3'"
    echo "   - Click OK"
    echo ""

    echo "${CYAN}7. CONFIGURE MULTI-TRACK RECORDING${NC}"
    echo "   This allows separate video tracks for screen and camera in post-production."
    echo ""
    echo "   - Go to: Settings > Output > Recording"
    echo "   - Output Mode: Advanced"
    echo "   - Recording Format: Matroska Video (.mkv)"
    echo "   - Video Encoder: Apple VT H264 Hardware Encoder"
    echo "   - Audio Track: Check tracks 1, 2, 3"
    echo ""
    echo "   Then go to: Edit > Advanced Audio Properties"
    echo "   - Microphone - FIFINE: Enable Track 1"
    echo "   - (Camera audio if any): Enable Track 2"
    echo ""

    echo "${CYAN}8. CONFIGURE HOTKEYS${NC}"
    echo "   - Go to: Settings > Hotkeys"
    echo "   - Start Recording: Cmd+Shift+R"
    echo "   - Stop Recording: Cmd+Shift+S"
    echo "   - Pause Recording: Cmd+Shift+P (optional)"
    echo ""

    echo "${CYAN}9. DISABLE CONFIRMATION DIALOGS${NC}"
    echo "   - Go to: Settings > General"
    echo "   - Uncheck 'Show confirmation dialog when starting streams'"
    echo "   - Uncheck 'Show confirmation dialog when stopping streams'"
    echo "   - (Same for recordings if options exist)"
    echo ""

    echo "${CYAN}10. TEST YOUR SETUP${NC}"
    echo "    - Check that all sources are visible"
    echo "    - Check audio levels in the mixer (speak into mic)"
    echo "    - Do a short test recording"
    echo "    - Open the test MKV in VLC or QuickTime to verify"
    echo ""
}

# =============================================================================
# Print Permissions Instructions
# =============================================================================

print_permissions_instructions() {
    log_step "macOS Permissions Required"

    echo "OBS needs these permissions (grant when prompted, or set manually):"
    echo ""
    echo "System Settings > Privacy & Security > ..."
    echo ""
    echo "  ${CYAN}Screen Recording${NC}"
    echo "    - OBS must be in this list and enabled"
    echo "    - Allows capturing your screen"
    echo ""
    echo "  ${CYAN}Camera${NC}"
    echo "    - OBS must be in this list and enabled"
    echo "    - Allows access to Sony ZV-E10"
    echo ""
    echo "  ${CYAN}Microphone${NC}"
    echo "    - OBS must be in this list and enabled"
    echo "    - Allows access to FIFINE microphone"
    echo ""
    echo "  ${CYAN}Accessibility${NC} (for automation scripts)"
    echo "    - Terminal (or iTerm) must be enabled"
    echo "    - Allows AppleScript to control other apps"
    echo ""
    echo "  ${CYAN}Automation${NC}"
    echo "    - Terminal must be allowed to control OBS"
    echo "    - Grant when prompted"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "${GREEN}========================================${NC}"
    echo "${GREEN}   OBS Tutorial Recording Setup        ${NC}"
    echo "${GREEN}========================================${NC}"
    echo ""

    # Check if OBS config directory exists
    if [[ ! -d "$OBS_CONFIG_DIR" ]]; then
        log_warning "OBS config directory not found. Please run OBS at least once first."
        log_info "Opening OBS now..."
        open -a "OBS"
        sleep 5
    fi

    # Create profile
    log_step "Creating OBS Profile"
    create_obs_profile

    # Create scene collection
    log_step "Creating Scene Collection"
    create_scene_collection

    # Print instructions
    print_permissions_instructions
    print_manual_instructions

    echo ""
    log_success "Setup complete!"
    echo ""
    echo "Next: Open OBS and follow the manual configuration steps above."
    echo ""

    # Ask to open OBS
    read -q "REPLY?Open OBS now? (y/n) "
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open -a "OBS"
    fi
}

main "$@"
