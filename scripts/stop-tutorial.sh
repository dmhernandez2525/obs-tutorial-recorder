#!/bin/zsh
# =============================================================================
# Stop Tutorial Recording
# =============================================================================
# This script stops recording and performs post-processing:
# 1. Stops OBS recording via WebSocket (or prompts manual stop)
# 2. Waits for file to be written
# 3. Remuxes MKV to MP4 (keeping original)
# 4. Updates metadata.json
# 5. Opens project folder in Finder
# =============================================================================

set -e

# Configuration
OBS_WEBSOCKET_PORT=4455
SESSION_FILE="/tmp/obs-tutorial-session.txt"

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

get_session_dir() {
    if [[ -f "$SESSION_FILE" ]]; then
        cat "$SESSION_FILE"
    else
        log_error "No active session found. Run start-tutorial.sh first."
        exit 1
    fi
}

stop_obs_recording_websocket() {
    if ! command -v websocat &> /dev/null; then
        return 1
    fi

    local message='{"op": 6, "d": {"requestType": "StopRecord", "requestId": "stop-rec-1"}}'

    echo "$message" | timeout 5 websocat -n1 "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null || return 1

    return 0
}

stop_obs_recording_manual() {
    osascript -e "
        display dialog \"Please click 'Stop Recording' in OBS, then click OK.\" buttons {\"OK\"} default button \"OK\" with title \"Stop Recording\"
    " 2>/dev/null || true
}

wait_for_recording_file() {
    local raw_dir="$1"
    local max_wait=30
    local waited=0

    log_info "Waiting for recording file to be finalized..."

    # Wait for any MKV file to appear and stop being written to
    while [[ $waited -lt $max_wait ]]; do
        # Find the most recent MKV file
        local latest_mkv=$(find "$raw_dir" -name "*.mkv" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)

        if [[ -n "$latest_mkv" ]]; then
            # Check if file is still being written (size changing)
            local size1=$(stat -f%z "$latest_mkv" 2>/dev/null || echo "0")
            sleep 2
            local size2=$(stat -f%z "$latest_mkv" 2>/dev/null || echo "0")

            if [[ "$size1" == "$size2" && "$size1" != "0" ]]; then
                echo "$latest_mkv"
                return 0
            fi
        fi

        sleep 1
        ((waited++))
    done

    return 1
}

remux_to_mp4() {
    local mkv_file="$1"
    local mp4_file="${mkv_file%.mkv}.mp4"

    if ! command -v ffmpeg &> /dev/null; then
        log_warning "ffmpeg not installed. Skipping remux."
        log_info "Install with: brew install ffmpeg"
        return 1
    fi

    log_info "Remuxing to MP4: $(basename "$mp4_file")"

    # Remux without re-encoding (fast copy)
    ffmpeg -i "$mkv_file" -c copy -y "$mp4_file" 2>/dev/null || {
        log_warning "Remux failed. MKV file is still available."
        return 1
    }

    log_success "Created: $(basename "$mp4_file")"
    echo "$mp4_file"
}

get_video_duration() {
    local video_file="$1"

    if command -v ffprobe &> /dev/null; then
        ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null | cut -d. -f1
    else
        echo "unknown"
    fi
}

update_metadata() {
    local project_dir="$1"
    local recording_file="$2"
    local metadata_file="$project_dir/metadata.json"

    if [[ ! -f "$metadata_file" ]]; then
        log_warning "Metadata file not found, skipping update"
        return 1
    fi

    local filename=$(basename "$recording_file")
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local duration=$(get_video_duration "$recording_file")

    # Create new recording entry
    local new_entry="{\"filename\": \"$filename\", \"startTime\": \"$timestamp\", \"duration\": \"$duration seconds\", \"notes\": \"\"}"

    # Use Python to update JSON (more reliable than jq for this)
    python3 << EOF
import json
import sys

try:
    with open("$metadata_file", 'r') as f:
        data = json.load(f)

    new_recording = $new_entry
    data['recordings'].append(new_recording)

    with open("$metadata_file", 'w') as f:
        json.dump(data, f, indent=2)

    print("Metadata updated successfully")
except Exception as e:
    print(f"Error updating metadata: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

show_completion_notification() {
    local project_dir="$1"
    local filename="$2"

    osascript -e "
        display notification \"Recording saved: $filename\" with title \"Recording Complete\" subtitle \"$(basename "$project_dir")\" sound name \"Glass\"
    " 2>/dev/null || true
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    log_info "=== Stop Tutorial Recording ==="
    echo ""

    # Get session directory
    PROJECT_DIR=$(get_session_dir)
    RAW_DIR="$PROJECT_DIR/raw"

    log_info "Project: $(basename "$PROJECT_DIR")"
    log_info "Raw Directory: $RAW_DIR"
    echo ""

    # Step 1: Stop OBS recording
    log_info "Step 1: Stopping OBS recording..."

    if stop_obs_recording_websocket; then
        log_success "Recording stopped via WebSocket"
    else
        log_warning "WebSocket not available, please stop manually..."
        stop_obs_recording_manual
    fi
    echo ""

    # Step 2: Wait for recording file
    log_info "Step 2: Waiting for recording file..."

    RECORDING_FILE=$(wait_for_recording_file "$RAW_DIR")

    if [[ -z "$RECORDING_FILE" ]]; then
        log_warning "Could not detect recording file automatically."

        # List available files
        log_info "Files in raw directory:"
        ls -la "$RAW_DIR" 2>/dev/null || echo "  (empty)"
        echo ""

        # Ask user to specify file manually
        osascript -e "
            display dialog \"Recording file not detected automatically. Please check the raw folder manually.\" buttons {\"OK\"} default button \"OK\" with title \"Manual Check Required\"
        " 2>/dev/null || true

        # Open folder and exit
        open "$PROJECT_DIR"
        exit 0
    fi

    log_success "Recording file: $(basename "$RECORDING_FILE")"
    log_info "Size: $(du -h "$RECORDING_FILE" | cut -f1)"
    echo ""

    # Step 3: Remux to MP4
    log_info "Step 3: Remuxing to MP4..."

    MP4_FILE=$(remux_to_mp4 "$RECORDING_FILE")

    if [[ -n "$MP4_FILE" ]]; then
        log_success "MP4 created successfully"
        log_info "Original MKV preserved as backup"
    fi
    echo ""

    # Step 4: Update metadata
    log_info "Step 4: Updating metadata..."

    if update_metadata "$PROJECT_DIR" "$RECORDING_FILE"; then
        log_success "Metadata updated"
    fi
    echo ""

    # Step 5: Cleanup and finish
    log_info "Step 5: Finalizing..."

    # Show completion notification
    show_completion_notification "$PROJECT_DIR" "$(basename "$RECORDING_FILE")"

    # Clean up session file
    rm -f "$SESSION_FILE"

    # Summary
    echo ""
    log_success "=== Recording Complete ==="
    echo ""
    echo "Project Directory: $PROJECT_DIR"
    echo ""
    echo "Files created:"
    ls -lh "$RAW_DIR" | tail -n +2 | while read line; do
        echo "  $line"
    done
    echo ""

    # Open project folder
    open "$PROJECT_DIR"

    log_success "Project folder opened in Finder"
}

main "$@"
