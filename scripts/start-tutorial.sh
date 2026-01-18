#!/bin/zsh
# =============================================================================
# Start Tutorial Recording - One-Click Automated Version
# =============================================================================
# Double-click this to:
# 1. Prompt for project name
# 2. Create organized folder structure
# 3. Launch OBS with correct settings
# 4. Configure recording path
# 5. Auto-start recording after countdown
# =============================================================================

set -e

# Configuration
RECORDINGS_BASE="$HOME/Desktop/Tutorial Recordings"
OBS_WEBSOCKET_PORT=4455
AUTO_START_RECORDING=true
COUNTDOWN_SECONDS=5

# Colors for output
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
# Helper Functions
# =============================================================================

sanitize_project_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g'
}

prompt_project_name() {
    local default_name="Untitled Tutorial"
    osascript -e "
        set dialogResult to display dialog \"Enter project name for this tutorial:\" default answer \"$default_name\" buttons {\"Cancel\", \"Start\"} default button \"Start\" with title \"New Tutorial Recording\"
        return text returned of dialogResult
    " 2>/dev/null || exit 1
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

is_obs_running() {
    pgrep -x "OBS" > /dev/null 2>&1
}

wait_for_obs_websocket() {
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if echo '{"op": 1, "d": {"rpcVersion": 1}}' | timeout 2 websocat -n1 "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null | grep -q "Hello"; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

obs_websocket_request() {
    local request_type="$1"
    local request_data="$2"
    local request_id=$(date +%s%N)

    local message
    if [[ -n "$request_data" ]]; then
        message='{"op": 6, "d": {"requestType": "'"$request_type"'", "requestId": "'"$request_id"'", "requestData": '"$request_data"'}}'
    else
        message='{"op": 6, "d": {"requestType": "'"$request_type"'", "requestId": "'"$request_id"'"}}'
    fi

    echo "$message" | timeout 5 websocat -n1 "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null
}

set_recording_directory() {
    local dir="$1"
    obs_websocket_request "SetRecordDirectory" '{"recordDirectory": "'"$dir"'"}'
}

start_recording() {
    obs_websocket_request "StartRecord"
}

show_countdown() {
    local seconds=$1
    local project_name="$2"

    for ((i=seconds; i>0; i--)); do
        osascript -e "display notification \"Starting in $i...\" with title \"Recording: $project_name\"" 2>/dev/null &
        echo "${CYAN}Recording starts in $i...${NC}"
        sleep 1
    done

    osascript -e "display notification \"Recording NOW!\" with title \"Recording Started\" sound name \"Glass\"" 2>/dev/null &
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

    # Step 1: Get project name
    log_info "Getting project name..."
    PROJECT_NAME=$(prompt_project_name)
    log_success "Project: $PROJECT_NAME"

    # Step 2: Create folders
    log_info "Creating folder structure..."
    PROJECT_DIR=$(create_folder_structure "$PROJECT_NAME")
    RAW_DIR="$PROJECT_DIR/raw"
    log_success "Created: $PROJECT_DIR"

    # Save session info
    echo "$PROJECT_DIR" > /tmp/obs-tutorial-session.txt
    touch /tmp/obs-recording-active.txt

    # Step 3: Launch OBS
    log_info "Launching OBS..."
    if ! is_obs_running; then
        open -a "OBS"
        sleep 2

        # Wait for OBS to fully start
        local waited=0
        while ! is_obs_running && [[ $waited -lt 15 ]]; do
            sleep 1
            ((waited++))
        done
    else
        osascript -e 'tell application "OBS" to activate' 2>/dev/null || true
    fi
    log_success "OBS is running"

    # Step 4: Configure via WebSocket
    log_info "Connecting to OBS WebSocket..."

    if command -v websocat &> /dev/null; then
        if wait_for_obs_websocket; then
            log_success "WebSocket connected"

            # Set recording directory
            log_info "Setting recording path to: $RAW_DIR"
            set_recording_directory "$RAW_DIR"
            log_success "Recording path configured"

            # Auto-start recording
            if [[ "$AUTO_START_RECORDING" == "true" ]]; then
                echo ""
                echo "${CYAN}════════════════════════════════════════${NC}"
                show_countdown $COUNTDOWN_SECONDS "$PROJECT_NAME"
                echo "${CYAN}════════════════════════════════════════${NC}"
                echo ""

                log_info "Starting recording..."
                start_recording
                log_success "Recording started!"

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
                echo "  • Or press ${YELLOW}Cmd+Shift+S${NC} in OBS"
                echo ""
            fi
        else
            log_warning "Could not connect to OBS WebSocket"
            log_info "Please start recording manually in OBS"
            log_info "Set recording path to: $RAW_DIR"
        fi
    else
        log_warning "websocat not installed - manual recording required"
        log_info "Recording path: $RAW_DIR"
    fi

    # Keep terminal open with status
    echo ""
    echo "This window will stay open. Close it when done or after stopping recording."
    echo ""

    # Open project folder
    open "$PROJECT_DIR"
}

main "$@"
