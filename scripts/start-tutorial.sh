#!/bin/zsh
# =============================================================================
# Start Tutorial Recording - One-Click Automated Version
# =============================================================================

set -e

# Configuration
RECORDINGS_BASE="$HOME/Desktop/Tutorial Recordings"
OBS_WEBSOCKET_PORT=4455
AUTO_START_RECORDING=true
COUNTDOWN_SECONDS=5

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# =============================================================================
# OBS WebSocket Functions (with proper handshake)
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

    # Proper handshake: wait for Hello, send Identify, then send request
    # Use grep to get the response (op:7) rather than events (op:5)
    {
        sleep 0.3
        echo '{"op":1,"d":{"rpcVersion":1}}'
        sleep 0.3
        echo "$request_msg"
        sleep 0.5
    } | timeout 5 websocat "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null | grep "\"op\":7" | head -1
}

obs_ws_check() {
    # Send identify and check for Hello response (pipe approach works, -n1 fails on some systems)
    echo '{"op":1,"d":{"rpcVersion":1}}' | timeout 2 websocat "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null | grep -q "obsStudioVersion"
}

obs_ws_wait() {
    local max_attempts=${1:-40}  # Default 40 seconds
    local attempt=0
    while [[ $attempt -lt $max_attempts ]]; do
        if obs_ws_check; then
            echo ""
            return 0
        fi
        sleep 1
        ((attempt++))
        echo -ne "\r${BLUE}[INFO]${NC} Waiting for OBS WebSocket... ($attempt/$max_attempts)   "
    done
    echo ""
    return 1
}

# =============================================================================
# Project Selection
# =============================================================================

get_existing_projects() {
    if [[ -d "$RECORDINGS_BASE" ]]; then
        find "$RECORDINGS_BASE" -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -r | head -10
    fi
}

select_or_create_project() {
    local existing_projects=($(get_existing_projects))
    local project_list=""

    if [[ ${#existing_projects[@]} -gt 0 ]]; then
        for proj in "${existing_projects[@]}"; do
            local name=$(basename "$proj")
            if [[ -n "$project_list" ]]; then
                project_list="$project_list, \"$name\""
            else
                project_list="\"$name\""
            fi
        done
    fi

    local result
    if [[ -n "$project_list" ]]; then
        result=$(osascript << EOF
set projectList to {"➕ Create New Project", $project_list}
set selectedProject to choose from list projectList with title "Tutorial Recording" with prompt "Select existing project or create new:" default items {"➕ Create New Project"}
if selectedProject is false then
    error "User cancelled"
end if
return item 1 of selectedProject
EOF
        ) || exit 1
    else
        result="➕ Create New Project"
    fi

    if [[ "$result" == "➕ Create New Project" ]]; then
        local new_name=$(osascript -e '
            set dialogResult to display dialog "Enter name for new tutorial project:" default answer "Untitled Tutorial" buttons {"Cancel", "Create"} default button "Create" with title "New Project"
            return text returned of dialogResult
        ' 2>/dev/null) || exit 1
        echo "NEW:$new_name"
    else
        echo "EXISTING:$RECORDINGS_BASE/$result"
    fi
}

sanitize_project_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g'
}

create_folder_structure() {
    local project_name="$1"
    local date_prefix=$(date +%Y-%m-%d)
    local safe_name=$(sanitize_project_name "$project_name")
    local project_dir="${RECORDINGS_BASE}/${date_prefix}_${safe_name}"

    mkdir -p "$RECORDINGS_BASE"

    local counter=1
    local final_dir="$project_dir"
    while [[ -d "$final_dir" ]]; do
        final_dir="${project_dir}-${counter}"
        ((counter++))
    done

    mkdir -p "$final_dir/raw"
    mkdir -p "$final_dir/exports"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "$final_dir/metadata.json" << EOF
{
  "projectName": "$project_name",
  "dateCreated": "$timestamp",
  "recordings": [],
  "equipment": {
    "camera": "Sony ZV-E10",
    "microphone": "fifine SC3"
  },
  "tags": [],
  "description": ""
}
EOF
    echo "$final_dir"
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    clear
    echo ""
    echo "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo "${GREEN}║     TUTORIAL RECORDING SETUP           ║${NC}"
    echo "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Select or create project
    log_info "Select project..."
    local selection=$(select_or_create_project)

    local PROJECT_DIR
    local PROJECT_NAME

    if [[ "$selection" == NEW:* ]]; then
        PROJECT_NAME="${selection#NEW:}"
        log_info "Creating new project: $PROJECT_NAME"
        PROJECT_DIR=$(create_folder_structure "$PROJECT_NAME")
        log_success "Created: $PROJECT_DIR"
    else
        PROJECT_DIR="${selection#EXISTING:}"
        PROJECT_NAME=$(basename "$PROJECT_DIR" | sed 's/^[0-9-]*_//')
        log_success "Using existing project: $PROJECT_NAME"
    fi

    RAW_DIR="$PROJECT_DIR/raw"

    # Save session info
    echo "$PROJECT_DIR" > /tmp/obs-tutorial-session.txt
    date +%s > /tmp/obs-tutorial-start-time.txt
    touch /tmp/obs-recording-active.txt

    # Step 2: Launch OBS if needed
    log_info "Checking OBS..."
    local obs_was_running=false
    if pgrep -x "OBS" > /dev/null 2>&1; then
        obs_was_running=true
        log_success "OBS is already running"
    else
        log_info "Launching OBS (this may take a moment)..."
        open -a "OBS"
        sleep 5  # Give OBS time to start
    fi

    # Step 3: Connect via WebSocket
    if ! command -v websocat &> /dev/null; then
        log_error "websocat not installed. Run: brew install websocat"
        exit 1
    fi

    log_info "Connecting to OBS WebSocket..."
    local ws_timeout=40
    if [[ "$obs_was_running" == "false" ]]; then
        ws_timeout=60  # More time if we just launched OBS
    fi

    if ! obs_ws_wait $ws_timeout; then
        log_error "Could not connect to OBS WebSocket after ${ws_timeout}s"
        log_info ""
        log_info "Please check:"
        log_info "  1. OBS is running"
        log_info "  2. Tools > WebSocket Server Settings > Enable WebSocket server"
        log_info "  3. Port is 4455, Authentication is OFF"
        log_info ""
        open "$PROJECT_DIR"
        exit 1
    fi
    log_success "WebSocket connected"

    # Step 4: Set recording directory
    log_info "Setting recording path: $RAW_DIR"
    obs_ws_send "SetRecordDirectory" '{"recordDirectory":"'"$RAW_DIR"'"}' > /dev/null
    log_success "Recording path configured"

    # Step 5: Start recording
    if [[ "$AUTO_START_RECORDING" == "true" ]]; then
        echo ""
        echo "${CYAN}════════════════════════════════════════${NC}"
        for ((i=COUNTDOWN_SECONDS; i>0; i--)); do
            echo "Recording starts in ${CYAN}$i${NC}..."
            osascript -e "display notification \"Starting in $i...\" with title \"$PROJECT_NAME\"" 2>/dev/null &
            sleep 1
        done
        echo "${CYAN}════════════════════════════════════════${NC}"
        echo ""

        log_info "Starting recording..."
        local result=$(obs_ws_send "StartRecord")

        if echo "$result" | grep -q '"requestStatus"'; then
            log_success "Recording started!"
            osascript -e 'display notification "Recording NOW!" with title "Recording Started" sound name "Glass"' 2>/dev/null &

            echo ""
            echo "${GREEN}╔════════════════════════════════════════╗${NC}"
            echo "${GREEN}║         RECORDING IN PROGRESS          ║${NC}"
            echo "${GREEN}╚════════════════════════════════════════╝${NC}"
            echo ""
            echo "Project: ${CYAN}$PROJECT_NAME${NC}"
            echo "Saving to: ${CYAN}$RAW_DIR${NC}"
            echo ""
            echo "To stop recording:"
            echo "  • Double-click ${YELLOW}Stop Tutorial.app${NC} on Desktop"
            echo "  • Or click ${YELLOW}Stop Recording${NC} in OBS"
            echo ""
        else
            log_warning "Recording may not have started. Check OBS manually."
            log_info "Response: $result"
        fi
    fi

    echo ""
    echo "This window will stay open. Close after recording."
    echo ""

    # Open project folder
    open "$PROJECT_DIR"
}

main "$@"
