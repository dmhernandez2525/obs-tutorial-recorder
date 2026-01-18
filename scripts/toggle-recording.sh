#!/bin/zsh
# =============================================================================
# Toggle Tutorial Recording
# =============================================================================
# Single script that:
# - Starts a new session if not currently recording
# - Stops and processes if currently recording
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"
SESSION_FILE="/tmp/obs-tutorial-session.txt"
RECORDING_STATE_FILE="/tmp/obs-recording-active.txt"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

is_recording() {
    [[ -f "$RECORDING_STATE_FILE" ]] && [[ -f "$SESSION_FILE" ]]
}

check_obs_recording_status() {
    # Try to check via WebSocket if available
    if command -v websocat &> /dev/null; then
        local message='{"op": 6, "d": {"requestType": "GetRecordStatus", "requestId": "status-1"}}'
        local response=$(echo "$message" | timeout 3 websocat -n1 "ws://localhost:4455" 2>/dev/null)

        if echo "$response" | grep -q '"outputActive":true'; then
            return 0  # Recording
        elif echo "$response" | grep -q '"outputActive":false'; then
            return 1  # Not recording
        fi
    fi

    # Fall back to file-based check
    is_recording
}

start_recording() {
    echo "${BLUE}[TOGGLE]${NC} Starting new recording session..."
    touch "$RECORDING_STATE_FILE"
    "$SCRIPT_DIR/start-tutorial.sh"

    if [[ $? -eq 0 ]]; then
        # Wait a moment then show start instruction
        osascript -e '
            display dialog "Session ready! Click OK and then press Cmd+Shift+R in OBS to start recording." buttons {"OK"} default button "OK" with title "Start Recording"
        ' 2>/dev/null || true
    fi
}

stop_recording() {
    echo "${GREEN}[TOGGLE]${NC} Stopping recording session..."
    "$SCRIPT_DIR/stop-tutorial.sh"
    rm -f "$RECORDING_STATE_FILE"
}

main() {
    if is_recording; then
        stop_recording
    else
        start_recording
    fi
}

main "$@"
