#!/bin/zsh
# =============================================================================
# Setup Source Record Plugin for ISO Recordings
# =============================================================================
# This script:
#   1. Downloads and installs the Source Record plugin
#   2. Adds Source Record filters to all video sources in OBS
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[OK]${NC} $1"; }
log_warning() { echo "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }

PLUGIN_DIR="$HOME/Library/Application Support/obs-studio/plugins"
DOWNLOAD_URL="https://obsproject.com/forum/resources/source-record.1285/version/6239/download?file=113214"
OBS_WEBSOCKET_PORT=4455

# =============================================================================
# Install Source Record Plugin
# =============================================================================

install_plugin() {
    log_info "Checking for Source Record plugin..."

    mkdir -p "$PLUGIN_DIR"

    if [[ -d "$PLUGIN_DIR/source-record.plugin" ]]; then
        log_success "Source Record plugin already installed"
        return 0
    fi

    log_info "Downloading Source Record plugin..."

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    if ! curl -fsSL -o source-record.zip "$DOWNLOAD_URL" 2>/dev/null; then
        log_error "Failed to download plugin"
        rm -rf "$temp_dir"
        return 1
    fi

    log_info "Extracting plugin..."
    unzip -q source-record.zip

    # Find the appropriate pkg for this architecture
    local arch=$(uname -m)
    local pkg_file=""

    if [[ "$arch" == "arm64" ]]; then
        pkg_file=$(find . -name "*arm64*.pkg" | head -1)
    else
        pkg_file=$(find . -name "*x86_64*.pkg" | head -1)
    fi

    if [[ -z "$pkg_file" ]]; then
        pkg_file=$(find . -name "*universal*.pkg" | head -1)
    fi

    if [[ -z "$pkg_file" ]]; then
        log_error "Could not find appropriate pkg file for $arch"
        rm -rf "$temp_dir"
        return 1
    fi

    log_info "Installing from: $(basename "$pkg_file")"

    # Extract pkg contents
    pkgutil --expand "$pkg_file" expanded_pkg
    mkdir -p payload
    cd payload
    cat ../expanded_pkg/*/Payload | gunzip -dc 2>/dev/null | cpio -id 2>/dev/null

    # Copy plugin to user plugins directory
    if [[ -d "./Library/Application Support/obs-studio/plugins/source-record.plugin" ]]; then
        cp -R "./Library/Application Support/obs-studio/plugins/source-record.plugin" "$PLUGIN_DIR/"
        log_success "Source Record plugin installed to: $PLUGIN_DIR"
    else
        log_error "Plugin extraction failed"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi

    cd /
    rm -rf "$temp_dir"

    log_warning "Please restart OBS to load the new plugin"
    return 0
}

# =============================================================================
# Add Source Record Filters
# =============================================================================

obs_ws_request() {
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
    } | timeout 5 websocat "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null | grep '"op":7'
}

check_obs_websocket() {
    echo '{"op":1,"d":{"rpcVersion":1}}' | timeout 2 websocat "ws://localhost:${OBS_WEBSOCKET_PORT}" 2>/dev/null | grep -q "obsStudioVersion"
}

get_video_sources() {
    local result=$(obs_ws_request "GetInputList")
    echo "$result" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        data = json.loads(line)
        if data.get('op') == 7:
            inputs = data.get('d', {}).get('responseData', {}).get('inputs', [])
            for inp in inputs:
                kind = inp.get('inputKind', '')
                name = inp.get('inputName', '')
                if any(x in kind for x in ['screen_capture', 'av_capture', 'video_capture', 'window']):
                    print(name)
    except:
        pass
" 2>/dev/null
}

check_filter_exists() {
    local source_name="$1"
    local result=$(obs_ws_request "GetSourceFilterList" "{\"sourceName\":\"$source_name\"}")
    echo "$result" | grep -q '"filterName":"Source Record"'
}

configure_filter_settings() {
    local source_name="$1"

    # record_mode: 1=Always, 2=Streaming, 3=Recording, 4=Streaming or Recording
    # Setting to 3 so it records when OBS is recording
    # Using Apple VT hardware encoder for stability (x264 causes pipe write errors on macOS)
    # Using mkv format for reliability
    local settings="{\"record_mode\":3,\"path\":\"$HOME/Movies\",\"rec_format\":\"mkv\",\"encoder\":\"com.apple.videotoolbox.videoencoder.ave.avc\",\"filename_formatting\":\"%CCYY-%MM-%DD %hh-%mm-%ss $source_name\"}"

    local result=$(obs_ws_request "SetSourceFilterSettings" "{\"sourceName\":\"$source_name\",\"filterName\":\"Source Record\",\"filterSettings\":$settings,\"overlay\":true}")

    if echo "$result" | grep -q '"result":true'; then
        return 0
    fi
    return 1
}

add_source_record_filter() {
    local source_name="$1"

    log_info "Adding Source Record filter to: $source_name"

    # Check if filter already exists
    if check_filter_exists "$source_name"; then
        log_success "  Filter exists, configuring settings..."
        if configure_filter_settings "$source_name"; then
            log_success "  Configured to record when OBS records"
        fi
        return 0
    fi

    # Add the filter with proper settings
    # record_mode 3 = "Recording" mode (records when OBS is recording)
    # Using Apple VT hardware encoder for macOS stability
    local settings="{\"record_mode\":3,\"path\":\"$HOME/Movies\",\"rec_format\":\"mkv\",\"encoder\":\"com.apple.videotoolbox.videoencoder.ave.avc\",\"filename_formatting\":\"%CCYY-%MM-%DD %hh-%mm-%ss $source_name\"}"
    local result=$(obs_ws_request "CreateSourceFilter" "{\"sourceName\":\"$source_name\",\"filterName\":\"Source Record\",\"filterKind\":\"source_record_filter\",\"filterSettings\":$settings}")

    if echo "$result" | grep -q '"result":true'; then
        log_success "  Filter added and configured to record when OBS records"
        return 0
    else
        log_warning "  Could not add filter (may already exist or source type not supported)"
        return 1
    fi
}

setup_filters() {
    log_info "Checking OBS WebSocket connection..."

    if ! check_obs_websocket; then
        log_error "Cannot connect to OBS WebSocket"
        log_info "Make sure:"
        log_info "  1. OBS is running"
        log_info "  2. Tools > WebSocket Server Settings > Enable WebSocket server"
        log_info "  3. Port is 4455, Authentication is OFF"
        return 1
    fi

    log_success "Connected to OBS WebSocket"

    # Check if Source Record filter kind is available
    local filter_kinds=$(obs_ws_request "GetSourceFilterKindList")
    if ! echo "$filter_kinds" | grep -q "source_record_filter"; then
        log_error "Source Record plugin not loaded in OBS"
        log_info "Please restart OBS to load the plugin, then run this script again"
        return 1
    fi

    log_info "Finding video sources..."
    local sources=$(get_video_sources)

    if [[ -z "$sources" ]]; then
        log_warning "No video sources found in OBS"
        log_info "Add your sources (Screen Capture, Camera, etc.) first"
        return 1
    fi

    log_info "Adding Source Record filters..."
    echo "$sources" | while read -r source; do
        [[ -n "$source" ]] && add_source_record_filter "$source"
    done

    log_success "Source Record setup complete!"
    echo ""
    log_info "Each video source will now record to a separate file"
    log_info "Files are saved to ~/Movies by default"
    log_info ""
    log_info "Note: Microphone audio is embedded in all recordings."
    log_info "To extract audio: ffmpeg -i 'Screen 1.mkv' -vn -acodec copy audio.aac"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo "${GREEN}║     Source Record Setup                ║${NC}"
    echo "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""

    case "${1:-all}" in
        install)
            install_plugin
            ;;
        filters)
            setup_filters
            ;;
        all|*)
            install_plugin
            echo ""
            if pgrep -x "OBS" > /dev/null 2>&1; then
                setup_filters
            else
                log_info "Start OBS and run '$0 filters' to add filters to sources"
            fi
            ;;
    esac
}

main "$@"
