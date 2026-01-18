#!/bin/zsh
# =============================================================================
# Start Tutorial Recording
# =============================================================================
# This script prepares and starts a tutorial recording session:
# 1. Prompts for project name
# 2. Creates organized folder structure
# 3. Verifies hardware (camera, microphone)
# 4. Configures OBS output path via WebSocket
# 5. Launches OBS if not running
# =============================================================================

set -e

# Configuration
RECORDINGS_BASE="$HOME/Desktop/Tutorial Recordings"
OBS_WEBSOCKET_PORT=4455
OBS_WEBSOCKET_PASSWORD=""  # Set if you configure a password in OBS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Helper Functions
# =============================================================================

sanitize_project_name() {
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g'
}

check_device() {
    local device_name="$1"
    local device_type="$2"

    if system_profiler SPUSBDataType 2>/dev/null | grep -qi "$device_name"; then
        log_success "$device_type detected: $device_name"
        return 0
    else
        log_warning "$device_type not detected: $device_name"
        return 1
    fi
}

check_audio_device() {
    local device_name="$1"

    # Check in audio devices
    if system_profiler SPAudioDataType 2>/dev/null | grep -qi "$device_name"; then
        return 0
    fi

    # Also check USB devices for USB audio
    if system_profiler SPUSBDataType 2>/dev/null | grep -qi "$device_name"; then
        return 0
    fi

    return 1
}

prompt_project_name() {
    local default_name="Untitled Tutorial"
    local project_name

    # Use AppleScript for GUI dialog
    project_name=$(osascript -e "
        set dialogResult to display dialog \"Enter project name for this tutorial:\" default answer \"$default_name\" buttons {\"Cancel\", \"Start Recording\"} default button \"Start Recording\" with title \"Tutorial Recording Setup\"
        return text returned of dialogResult
    " 2>/dev/null) || {
        log_error "User cancelled or dialog failed"
        exit 1
    }

    echo "$project_name"
}

create_folder_structure() {
    local project_name="$1"
    local date_prefix=$(date +%Y-%m-%d)
    local safe_name=$(sanitize_project_name "$project_name")
    local project_dir="${RECORDINGS_BASE}/${date_prefix}_${safe_name}"

    # Create base directory if needed
    mkdir -p "$RECORDINGS_BASE"

    # Handle duplicate folder names
    local counter=1
    local final_dir="$project_dir"
    while [[ -d "$final_dir" ]]; do
        final_dir="${project_dir}-${counter}"
        ((counter++))
    done

    # Create folder structure
    mkdir -p "$final_dir/raw"
    mkdir -p "$final_dir/exports"

    # Create metadata file
    local metadata_file="$final_dir/metadata.json"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Detect connected devices
    local camera_device="Sony ZV-E10 (USB-C)"
    local mic_device="fifine SC3"
    local capture_card="Not connected"

    if system_profiler SPUSBDataType 2>/dev/null | grep -qi "cam link\|elgato"; then
        capture_card="Elgato Cam Link 4K"
        camera_device="Sony ZV-E10 (via Capture Card)"
    fi

    cat > "$metadata_file" << EOF
{
  "projectName": "$project_name",
  "dateCreated": "$timestamp",
  "recordings": [],
  "equipment": {
    "camera": "$camera_device",
    "microphone": "$mic_device",
    "captureCard": "$capture_card"
  },
  "tags": [],
  "description": ""
}
EOF

    echo "$final_dir"
}

is_obs_running() {
    pgrep -x "OBS" > /dev/null 2>&1
}

launch_obs() {
    if is_obs_running; then
        log_info "OBS is already running, bringing to front..."
        osascript -e 'tell application "OBS" to activate' 2>/dev/null || true
    else
        log_info "Launching OBS Studio..."
        open -a "OBS"

        # Wait for OBS to start
        local max_wait=30
        local waited=0
        while ! is_obs_running && [[ $waited -lt $max_wait ]]; do
            sleep 1
            ((waited++))
        done

        if ! is_obs_running; then
            log_error "OBS failed to start within ${max_wait} seconds"
            exit 1
        fi

        # Give OBS time to initialize WebSocket server
        sleep 3
    fi
}

configure_obs_via_websocket() {
    local output_path="$1"

    # Check if websocat is available for WebSocket communication
    if ! command -v websocat &> /dev/null; then
        log_warning "websocat not installed. OBS output path must be set manually."
        log_info "Install with: brew install websocat"
        log_info "Or manually set recording path to: $output_path"
        return 1
    fi

    # Create WebSocket message to set recording path
    local message='{"op": 6, "d": {"requestType": "SetRecordDirectory", "requestId": "set-dir-1", "requestData": {"recordDirectory": "'"$output_path"'"}}}'

    # Send to OBS WebSocket (requires obs-websocket to be enabled)
    echo "$message" | timeout 5 websocat -n1 "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null || {
        log_warning "Could not connect to OBS WebSocket. Make sure:"
        log_info "  1. OBS WebSocket server is enabled (Tools > WebSocket Server Settings)"
        log_info "  2. Port is set to ${OBS_WEBSOCKET_PORT}"
        log_info "  3. Authentication is disabled (or set password in this script)"
        return 1
    }

    log_success "OBS recording path configured via WebSocket"
    return 0
}

show_ready_notification() {
    local project_dir="$1"
    local project_name="$2"

    osascript -e "
        display notification \"Project: $project_name\" with title \"Tutorial Recording Ready\" subtitle \"Press Cmd+Shift+R to start recording\" sound name \"Glass\"
    " 2>/dev/null || true
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    log_info "=== Tutorial Recording Setup ==="
    echo ""

    # Step 1: Prompt for project name
    log_info "Step 1: Getting project name..."
    PROJECT_NAME=$(prompt_project_name)
    log_success "Project: $PROJECT_NAME"
    echo ""

    # Step 2: Check hardware
    log_info "Step 2: Checking hardware..."

    local hw_warnings=0

    # Check for camera (ZV-E10 via USB or capture card)
    if check_audio_device "ZV-E10" || check_device "Cam Link" "Capture Card" || check_device "Elgato" "Capture Card"; then
        log_success "Camera/Capture device detected"
    else
        log_warning "No camera or capture card detected"
        ((hw_warnings++))
    fi

    # Check for FIFINE microphone
    if check_audio_device "fifine" || check_device "fifine" "Microphone"; then
        log_success "FIFINE microphone detected"
    else
        log_warning "FIFINE microphone not detected"
        ((hw_warnings++))
    fi

    # Warn if hardware missing
    if [[ $hw_warnings -gt 0 ]]; then
        local continue_anyway=$(osascript -e "
            set dialogResult to display dialog \"$hw_warnings device(s) not detected. Continue anyway?\" buttons {\"Cancel\", \"Continue\"} default button \"Continue\" with title \"Hardware Warning\" with icon caution
            return button returned of dialogResult
        " 2>/dev/null) || exit 1

        if [[ "$continue_anyway" != "Continue" ]]; then
            log_error "Setup cancelled by user"
            exit 1
        fi
    fi
    echo ""

    # Step 3: Create folder structure
    log_info "Step 3: Creating folder structure..."
    PROJECT_DIR=$(create_folder_structure "$PROJECT_NAME")
    log_success "Created: $PROJECT_DIR"
    echo ""

    # Step 4: Launch OBS
    log_info "Step 4: Launching OBS..."
    launch_obs
    log_success "OBS is running"
    echo ""

    # Step 5: Configure OBS output path
    log_info "Step 5: Configuring OBS output path..."
    RAW_DIR="$PROJECT_DIR/raw"

    if ! configure_obs_via_websocket "$RAW_DIR"; then
        log_warning "Automatic configuration failed."
        log_info "Please manually set OBS recording path to:"
        log_info "  $RAW_DIR"
        echo ""

        # Show the path in a dialog for easy copy
        osascript -e "
            display dialog \"Set OBS recording path to:

$RAW_DIR

(Settings > Output > Recording Path)\" buttons {\"OK\"} default button \"OK\" with title \"Manual Configuration Required\"
        " 2>/dev/null || true
    fi
    echo ""

    # Step 6: Show ready notification
    log_info "Step 6: Ready to record!"
    show_ready_notification "$PROJECT_DIR" "$PROJECT_NAME"

    echo ""
    log_success "=== Setup Complete ==="
    echo ""
    echo "Project Directory: $PROJECT_DIR"
    echo "Recording Path:    $RAW_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Verify OBS sources are configured correctly"
    echo "  2. Check audio levels in OBS mixer"
    echo "  3. Press Cmd+Shift+R to start recording (or click Start Recording in OBS)"
    echo ""

    # Save session info for stop script
    echo "$PROJECT_DIR" > /tmp/obs-tutorial-session.txt

    # Open the project folder in Finder
    open "$PROJECT_DIR"
}

main "$@"
