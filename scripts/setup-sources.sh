#!/bin/zsh
# =============================================================================
# Setup OBS Sources via WebSocket
# =============================================================================
# This script adds all required sources to the current OBS scene
# Run this ONCE after OBS is open with the Tutorial Recording scene collection
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/obs-websocket.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[OK]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }

echo ""
echo "${GREEN}=== OBS Source Setup ===${NC}"
echo ""

# Check OBS is running
if ! pgrep -x "OBS" > /dev/null 2>&1; then
    log_error "OBS is not running. Please start OBS first."
    exit 1
fi

# Wait for WebSocket
log_info "Connecting to OBS WebSocket..."
if ! obs_ws_wait 10; then
    log_error "Could not connect to OBS WebSocket"
    log_info "Make sure WebSocket is enabled: Tools > WebSocket Server Settings"
    exit 1
fi
log_success "Connected to OBS WebSocket"

# Create main scene if needed
log_info "Creating scene: Tutorial Recording..."
obs_create_scene "Tutorial Recording" 2>/dev/null
sleep 0.5

# Add Screen 1
log_info "Adding Screen 1 (Display 0)..."
obs_create_input "Tutorial Recording" "Screen 1" "screen_capture" '{"display":0,"show_cursor":true}' 2>/dev/null
sleep 0.5

# Add Screen 2
log_info "Adding Screen 2 (Display 1)..."
obs_create_input "Tutorial Recording" "Screen 2" "screen_capture" '{"display":1,"show_cursor":true}' 2>/dev/null
sleep 0.5

# Add Screen 3
log_info "Adding Screen 3 (Display 2)..."
obs_create_input "Tutorial Recording" "Screen 3" "screen_capture" '{"display":2,"show_cursor":true}' 2>/dev/null
sleep 0.5

# Add Camera
log_info "Adding Camera (Sony ZV-E10)..."
obs_create_input "Tutorial Recording" "Camera - ZV-E10" "av_capture_device_v2" '{"device_name":"ZV-E10","preset":"AVCaptureSessionPreset1280x720"}' 2>/dev/null
sleep 0.5

# Add Microphone
log_info "Adding Microphone (FIFINE)..."
obs_create_input "Tutorial Recording" "Microphone - FIFINE" "coreaudio_input_capture" '{"device_id":"fifine_SC3"}' 2>/dev/null
sleep 0.5

echo ""
log_success "Sources added!"
echo ""
echo "You may need to:"
echo "  1. Right-click sources in OBS to configure display/device selection"
echo "  2. Arrange sources in the preview (drag to resize/position)"
echo "  3. Select the correct audio device for the microphone"
echo ""
