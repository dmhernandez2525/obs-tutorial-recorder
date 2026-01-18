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
# Project Selection
# =============================================================================

get_existing_projects() {
    # List existing project folders, newest first
    if [[ -d "$RECORDINGS_BASE" ]]; then
        find "$RECORDINGS_BASE" -maxdepth 1 -type d -name "20*" 2>/dev/null | sort -r | head -10
    fi
}

select_or_create_project() {
    local existing_projects=($(get_existing_projects))
    local project_list=""

    # Build list for AppleScript
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

    # Show dialog with existing projects or just new project prompt
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
        # Prompt for new project name
        local new_name=$(osascript -e '
            set dialogResult to display dialog "Enter name for new tutorial project:" default answer "Untitled Tutorial" buttons {"Cancel", "Create"} default button "Create" with title "New Project"
            return text returned of dialogResult
        ' 2>/dev/null) || exit 1

        echo "NEW:$new_name"
    else
        # Return existing project path
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
# OBS Control
# =============================================================================

is_obs_running() {
    pgrep -x "OBS" > /dev/null 2>&1
}

ensure_obs_websocket_config() {
    # Make sure WebSocket is enabled in OBS config
    local config_file="$HOME/Library/Application Support/obs-studio/global.ini"
    if [[ -f "$config_file" ]]; then
        if ! grep -q "ServerEnabled=true" "$config_file" 2>/dev/null; then
            log_info "Enabling OBS WebSocket server..."
            # Add WebSocket settings if missing
            sed -i '' 's/\[OBSWebSocket\]/[OBSWebSocket]\nServerEnabled=true\nServerPort=4455\nAuthRequired=false/' "$config_file" 2>/dev/null || true
        fi
    fi
}

wait_for_obs_websocket() {
    local max_attempts=20
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        # Try to connect and get a response
        local response=$(echo '{"op": 1, "d": {"rpcVersion": 1}}' | timeout 2 websocat -n1 "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null || true)
        if [[ -n "$response" ]]; then
            return 0
        fi
        sleep 1
        ((attempt++))
        echo -ne "\r${BLUE}[INFO]${NC} Waiting for OBS WebSocket... ($attempt/$max_attempts)"
    done
    echo ""
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

set_profile() {
    local profile="$1"
    obs_websocket_request "SetCurrentProfile" '{"profileName": "'"$profile"'"}'
}

set_scene_collection() {
    local collection="$1"
    obs_websocket_request "SetCurrentSceneCollection" '{"sceneCollectionName": "'"$collection"'"}'
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
    touch /tmp/obs-recording-active.txt

    # Step 2: Ensure OBS WebSocket is configured
    ensure_obs_websocket_config

    # Step 3: Launch OBS
    log_info "Launching OBS..."
    if ! is_obs_running; then
        # Launch OBS with specific profile and scene collection
        open -a "OBS" --args --profile "Tutorial Recording" --collection "Tutorial Recording"
        sleep 3

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

            # Switch to correct profile and scene collection
            log_info "Loading Tutorial Recording profile..."
            set_profile "Tutorial Recording"
            sleep 1
            set_scene_collection "Tutorial Recording"
            sleep 1

            # Set recording directory
            log_info "Setting recording path: $RAW_DIR"
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
            log_info "You may need to enable WebSocket in OBS:"
            log_info "  Tools > WebSocket Server Settings > Enable"
            log_info ""
            log_info "Recording path: $RAW_DIR"
            log_info "Please start recording manually in OBS"
        fi
    else
        log_warning "websocat not installed"
        log_info "Install with: brew install websocat"
        log_info "Recording path: $RAW_DIR"
    fi

    echo ""
    echo "This window will stay open. Close after recording."
    echo ""

    # Open project folder
    open "$PROJECT_DIR"
}

main "$@"
