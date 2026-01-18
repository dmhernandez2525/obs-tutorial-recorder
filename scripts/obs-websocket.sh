#!/bin/zsh
# =============================================================================
# OBS WebSocket Helper Functions
# =============================================================================
# Properly implements the OBS WebSocket 5.x protocol with handshake
# =============================================================================

OBS_WS_PORT=${OBS_WEBSOCKET_PORT:-4455}

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

# Send a request and get response using a persistent connection
obs_ws_request() {
    local request_type="$1"
    local request_data="$2"
    local request_id="req_$(date +%s%N)"

    # Build the request message
    local request_msg
    if [[ -n "$request_data" ]]; then
        request_msg='{"op":6,"d":{"requestType":"'"$request_type"'","requestId":"'"$request_id"'","requestData":'"$request_data"'}}'
    else
        request_msg='{"op":6,"d":{"requestType":"'"$request_type"'","requestId":"'"$request_id"'"}}'
    fi

    # Use websocat with proper handshake
    # Send identify, wait for identified, then send request
    local result=$(
        {
            # Wait to receive Hello (op:0), then send Identify (op:1)
            sleep 0.3
            echo '{"op":1,"d":{"rpcVersion":1}}'
            # Wait for Identified (op:2), then send our request
            sleep 0.3
            echo "$request_msg"
            sleep 0.3
        } | timeout 5 websocat -n "ws://localhost:${OBS_WS_PORT}" 2>/dev/null | grep -m1 '"requestId"'
    )

    echo "$result"
}

# Simpler version - fire and forget with identify
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

    # Use grep to get the response (op:7) rather than events (op:5)
    {
        sleep 0.3
        echo '{"op":1,"d":{"rpcVersion":1}}'
        sleep 0.3
        echo "$request_msg"
        sleep 0.5
    } | timeout 5 websocat "ws://localhost:${OBS_WS_PORT}" 2>/dev/null | grep "\"op\":7" | head -1
}

# Check if WebSocket is available
obs_ws_check() {
    # Pipe approach works, -n1 fails on some systems
    echo '{"op":1,"d":{"rpcVersion":1}}' | timeout 2 websocat "ws://localhost:${OBS_WS_PORT}" 2>/dev/null | grep -q "obsStudioVersion"
}

# Wait for OBS WebSocket to become available
obs_ws_wait() {
    local max_attempts=${1:-20}
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if obs_ws_check; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

# Get current scene list
obs_get_scenes() {
    obs_ws_request "GetSceneList"
}

# Create a new scene
obs_create_scene() {
    local scene_name="$1"
    obs_ws_send "CreateScene" '{"sceneName":"'"$scene_name"'"}'
}

# Create input (source)
obs_create_input() {
    local scene_name="$1"
    local input_name="$2"
    local input_kind="$3"
    local input_settings="$4"

    local data='{"sceneName":"'"$scene_name"'","inputName":"'"$input_name"'","inputKind":"'"$input_kind"'"'
    if [[ -n "$input_settings" ]]; then
        data="$data"',"inputSettings":'"$input_settings"
    fi
    data="$data"'}'

    obs_ws_send "CreateInput" "$data"
}

# Set recording directory
obs_set_record_directory() {
    local dir="$1"
    obs_ws_send "SetRecordDirectory" '{"recordDirectory":"'"$dir"'"}'
}

# Start recording
obs_start_record() {
    obs_ws_send "StartRecord"
}

# Stop recording
obs_stop_record() {
    obs_ws_send "StopRecord"
}

# Get record status
obs_get_record_status() {
    obs_ws_request "GetRecordStatus"
}
