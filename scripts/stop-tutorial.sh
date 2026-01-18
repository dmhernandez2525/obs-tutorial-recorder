#!/bin/zsh
# =============================================================================
# Stop Tutorial Recording
# =============================================================================
# Stops OBS recording and collects all ISO recordings from Source Record
# =============================================================================

set -e

OBS_WEBSOCKET_PORT=4455
SESSION_FILE="/tmp/obs-tutorial-session.txt"
SESSION_START_FILE="/tmp/obs-tutorial-start-time.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; write_log "INFO" "$1"; }
log_success() { echo "${GREEN}[OK]${NC} $1"; write_log "SUCCESS" "$1"; }
log_warning() { echo "${YELLOW}[WARNING]${NC} $1"; write_log "WARNING" "$1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; write_log "ERROR" "$1"; }

# Write to session log file for debugging
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Get session log from session file
    if [[ -f "$SESSION_FILE" ]]; then
        local project_dir=$(cat "$SESSION_FILE")
        local log_file="$project_dir/session.log"
        if [[ -d "$project_dir" ]]; then
            echo "[$timestamp] [$level] $message" >> "$log_file"
        fi
    fi
}

# =============================================================================
# OBS WebSocket
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
        sleep 0.3
        echo '{"op":1,"d":{"rpcVersion":1}}'
        sleep 0.3
        echo "$request_msg"
        sleep 0.5
    } | timeout 5 websocat "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null | grep "\"op\":7" | head -1
}

# =============================================================================
# Helper Functions
# =============================================================================

get_session_dir() {
    if [[ -f "$SESSION_FILE" ]]; then
        cat "$SESSION_FILE"
    else
        local latest=$(find "$HOME/Desktop/Tutorial Recordings" -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -r | head -1)
        if [[ -n "$latest" ]]; then
            echo "$latest"
        else
            log_error "No active session found."
            exit 1
        fi
    fi
}

get_session_start_time() {
    if [[ -f "$SESSION_START_FILE" ]]; then
        cat "$SESSION_START_FILE"
    else
        # Default: 30 minutes ago
        echo $(($(date +%s) - 1800))
    fi
}

wait_for_file_complete() {
    local file="$1"
    local max_wait=15
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        local size1=$(stat -f%z "$file" 2>/dev/null || echo "0")
        sleep 1
        local size2=$(stat -f%z "$file" 2>/dev/null || echo "0")

        if [[ "$size1" == "$size2" && "$size1" != "0" ]]; then
            return 0
        fi
        ((waited++))
    done
    return 1
}

collect_source_recordings() {
    local raw_dir="$1"
    local start_time="$2"
    local collected=0

    log_info "Collecting ISO recordings from Source Record..."

    # Wait for files to finish writing
    sleep 3

    # Find all video files in Movies created after session start
    # Source Record uses ~/Movies by default
    local search_dirs=("$HOME/Movies" "$raw_dir")

    for search_dir in "${search_dirs[@]}"; do
        [[ ! -d "$search_dir" ]] && continue

        # Find recent video files (modified after session start)
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue

            local file_mtime=$(stat -f%m "$file" 2>/dev/null || echo "0")

            # Only process files created after our session started
            if [[ "$file_mtime" -ge "$start_time" ]]; then
                # Wait for file to finish writing
                if wait_for_file_complete "$file"; then
                    local filename=$(basename "$file")
                    local dest="$raw_dir/$filename"

                    # Move if not already in raw_dir
                    if [[ "$file" != "$dest" && ! -f "$dest" ]]; then
                        mv "$file" "$dest"
                        log_success "Collected: $filename"
                        ((collected++))
                    elif [[ "$file" == "$dest" ]]; then
                        log_success "Found: $filename"
                        ((collected++))
                    fi
                fi
            fi
        done < <(find "$search_dir" -maxdepth 1 -type f \( -name "*.mkv" -o -name "*.mov" -o -name "*.mp4" \) 2>/dev/null)
    done

    echo "$collected"
}

remux_to_mp4() {
    local input_file="$1"
    local ext="${input_file##*.}"

    [[ "$ext" == "mp4" ]] && { echo "$input_file"; return 0; }

    if ! command -v ffmpeg &> /dev/null; then
        echo "$input_file"
        return 0
    fi

    local mp4_file="${input_file%.*}.mp4"
    log_info "Remuxing: $(basename "$input_file")..."

    if ffmpeg -i "$input_file" -c copy -y "$mp4_file" 2>/dev/null; then
        log_success "Created: $(basename "$mp4_file")"
        echo "$mp4_file"
    else
        echo "$input_file"
    fi
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
    local metadata_file="$project_dir/metadata.json"

    [[ ! -f "$metadata_file" ]] && return

    local raw_dir="$project_dir/raw"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Build list of all recordings
    local recordings_json="["
    local first=true

    for file in "$raw_dir"/*.{mp4,mov,mkv} 2>/dev/null; do
        [[ ! -f "$file" ]] && continue

        local filename=$(basename "$file")
        local duration=$(get_video_duration "$file")
        local size=$(du -h "$file" | cut -f1)

        if [[ "$first" == "true" ]]; then
            first=false
        else
            recordings_json+=","
        fi

        recordings_json+="{\"filename\":\"$filename\",\"duration\":\"${duration}s\",\"size\":\"$size\"}"
    done

    recordings_json+="]"

    python3 << EOF
import json
try:
    with open("$metadata_file", 'r') as f:
        data = json.load(f)
    data['recordings'] = $recordings_json
    data['lastUpdated'] = "$timestamp"
    with open("$metadata_file", 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    pass
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo "${GREEN}║     STOP TUTORIAL RECORDING            ║${NC}"
    echo "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""

    # Get session info
    PROJECT_DIR=$(get_session_dir)
    RAW_DIR="$PROJECT_DIR/raw"
    SESSION_START=$(get_session_start_time)

    log_info "Project: $(basename "$PROJECT_DIR")"

    # Ensure raw directory exists
    mkdir -p "$RAW_DIR"

    # Stop main recording via WebSocket
    log_info "Stopping OBS recording..."
    local result=$(obs_ws_send "StopRecord")

    if echo "$result" | grep -q '"result":true'; then
        log_success "Main recording stopped"
    else
        log_warning "Could not stop via WebSocket. Please stop manually in OBS."
        osascript -e 'display dialog "Click Stop Recording in OBS, then click OK." buttons {"OK"} default button "OK"' 2>/dev/null || true
    fi

    # Give Source Record filters time to finish
    log_info "Waiting for all recordings to complete..."
    sleep 5

    # Collect all ISO recordings from Source Record
    local file_count=$(collect_source_recordings "$RAW_DIR" "$SESSION_START")

    echo ""
    if [[ "$file_count" -gt 0 ]]; then
        log_success "Collected $file_count recording(s)"

        # List all files
        echo ""
        echo "${CYAN}Recordings:${NC}"
        for file in "$RAW_DIR"/*.{mp4,mov,mkv} 2>/dev/null; do
            [[ ! -f "$file" ]] && continue
            local size=$(du -h "$file" | cut -f1)
            echo "  - $(basename "$file") ($size)"
        done
        echo ""

        # Ask about remuxing
        local non_mp4_count=$(find "$RAW_DIR" -name "*.mkv" -o -name "*.mov" 2>/dev/null | wc -l | tr -d ' ')

        if [[ "$non_mp4_count" -gt 0 ]]; then
            log_info "Found $non_mp4_count non-MP4 file(s)"
            echo -n "Remux to MP4? (y/n) [y]: "
            read -r do_remux
            do_remux=${do_remux:-y}

            if [[ "$do_remux" =~ ^[Yy] ]]; then
                for file in "$RAW_DIR"/*.{mkv,mov} 2>/dev/null; do
                    [[ ! -f "$file" ]] && continue
                    remux_to_mp4 "$file"
                done
            fi
        fi

        # Update metadata
        update_metadata "$PROJECT_DIR"
        log_success "Metadata updated"
    else
        log_warning "No recordings found"
    fi

    # Cleanup session files
    rm -f "$SESSION_FILE" "$SESSION_START_FILE" /tmp/obs-recording-active.txt

    # Notification
    osascript -e 'display notification "Recording complete!" with title "Tutorial Recording" sound name "Glass"' 2>/dev/null &

    echo ""
    log_success "Done!"
    echo ""
    echo "Project folder: ${CYAN}$PROJECT_DIR${NC}"
    echo ""

    # Open project folder
    open "$PROJECT_DIR"
}

main "$@"
