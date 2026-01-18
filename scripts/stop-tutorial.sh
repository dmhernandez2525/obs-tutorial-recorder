#!/bin/zsh
# =============================================================================
# Stop Tutorial Recording
# =============================================================================

set -e

OBS_WEBSOCKET_PORT=4455
SESSION_FILE="/tmp/obs-tutorial-session.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# OBS WebSocket (with proper handshake)
# =============================================================================

obs_ws_send() {
    local request_type="$1"
    local request_data="$2"
    local request_id="req_$(date +%s%N)"

    local request_msg
    if [[ -n "$request_data" ]]; then
        request_msg='{"op":6,"d":{"requestType":"'"$request_type"'","requestId":"'"$request_id"'","requestData":'"$request_data"'}}'
    else
        request_msg='{"op":6,"d":{"requestType":"'"$request_type"'","requestId":"'"$request_id"'"}}'
    fi

    {
        sleep 0.2
        echo '{"op":1,"d":{"rpcVersion":1}}'
        sleep 0.3
        echo "$request_msg"
        sleep 0.2
    } | timeout 4 websocat "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null | tail -1
}

# =============================================================================
# Helper Functions
# =============================================================================

get_session_dir() {
    if [[ -f "$SESSION_FILE" ]]; then
        cat "$SESSION_FILE"
    else
        # Try to find most recent recording folder
        local latest=$(find "$HOME/Desktop/Tutorial Recordings" -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -r | head -1)
        if [[ -n "$latest" ]]; then
            echo "$latest"
        else
            log_error "No active session found."
            exit 1
        fi
    fi
}

wait_for_recording_file() {
    local raw_dir="$1"
    local max_wait=30
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        # Find most recent video file (MKV or MOV)
        local latest_file=$(find "$raw_dir" -type f \( -name "*.mkv" -o -name "*.mov" -o -name "*.mp4" \) 2>/dev/null | xargs ls -t 2>/dev/null | head -1)

        if [[ -n "$latest_file" ]]; then
            local size1=$(stat -f%z "$latest_file" 2>/dev/null || echo "0")
            sleep 2
            local size2=$(stat -f%z "$latest_file" 2>/dev/null || echo "0")

            if [[ "$size1" == "$size2" && "$size1" != "0" ]]; then
                echo "$latest_file"
                return 0
            fi
        fi
        sleep 1
        ((waited++))
    done
    return 1
}

remux_to_mp4() {
    local input_file="$1"
    local ext="${input_file##*.}"
    local mp4_file="${input_file%.*}.mp4"

    if [[ "$ext" == "mp4" ]]; then
        echo "$input_file"
        return 0
    fi

    if ! command -v ffmpeg &> /dev/null; then
        log_warning "ffmpeg not installed. Skipping remux."
        echo "$input_file"
        return 0
    fi

    log_info "Remuxing to MP4..."
    ffmpeg -i "$input_file" -c copy -y "$mp4_file" 2>/dev/null && {
        log_success "Created: $(basename "$mp4_file")"
        echo "$mp4_file"
    } || {
        echo "$input_file"
    }
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

    [[ ! -f "$metadata_file" ]] && return

    local filename=$(basename "$recording_file")
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local duration=$(get_video_duration "$recording_file")

    python3 << EOF
import json
try:
    with open("$metadata_file", 'r') as f:
        data = json.load(f)
    data['recordings'].append({
        "filename": "$filename",
        "startTime": "$timestamp",
        "duration": "$duration seconds",
        "notes": ""
    })
    with open("$metadata_file", 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    pass
EOF
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    echo ""
    echo "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo "${GREEN}║     STOP TUTORIAL RECORDING            ║${NC}"
    echo "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""

    # Get session directory
    PROJECT_DIR=$(get_session_dir)
    RAW_DIR="$PROJECT_DIR/raw"
    log_info "Project: $(basename "$PROJECT_DIR")"

    # Stop recording via WebSocket
    log_info "Stopping OBS recording..."
    local result=$(obs_ws_send "StopRecord")

    if echo "$result" | grep -q '"result":true'; then
        log_success "Recording stopped"
        # Extract output path from response
        local output_path=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('d',{}).get('responseData',{}).get('outputPath',''))" 2>/dev/null)
        if [[ -n "$output_path" ]]; then
            log_info "Saved to: $output_path"
        fi
    else
        log_warning "Could not stop via WebSocket. Please stop manually in OBS."
        osascript -e 'display dialog "Click Stop Recording in OBS, then click OK." buttons {"OK"} default button "OK"' 2>/dev/null || true
    fi

    # Wait for file
    log_info "Waiting for recording file..."
    sleep 2

    # Check for files in raw dir or default OBS location
    RECORDING_FILE=$(wait_for_recording_file "$RAW_DIR")
    if [[ -z "$RECORDING_FILE" ]]; then
        # Check Movies folder (OBS default)
        local movies_file=$(find "$HOME/Movies" -maxdepth 1 -type f \( -name "*.mkv" -o -name "*.mov" \) -mmin -5 2>/dev/null | head -1)
        if [[ -n "$movies_file" ]]; then
            log_info "Found recording in Movies folder, moving to project..."
            mv "$movies_file" "$RAW_DIR/"
            RECORDING_FILE="$RAW_DIR/$(basename "$movies_file")"
        fi
    fi

    if [[ -n "$RECORDING_FILE" ]]; then
        log_success "Recording: $(basename "$RECORDING_FILE")"
        log_info "Size: $(du -h "$RECORDING_FILE" | cut -f1)"

        # Remux if needed
        FINAL_FILE=$(remux_to_mp4 "$RECORDING_FILE")

        # Update metadata
        update_metadata "$PROJECT_DIR" "$FINAL_FILE"
        log_success "Metadata updated"
    else
        log_warning "Recording file not found in project folder"
    fi

    # Cleanup
    rm -f "$SESSION_FILE" /tmp/obs-recording-active.txt

    # Show notification
    osascript -e 'display notification "Recording complete!" with title "Tutorial Recording" sound name "Glass"' 2>/dev/null &

    echo ""
    log_success "Done!"
    echo ""

    # Open project folder
    open "$PROJECT_DIR"
}

main "$@"
