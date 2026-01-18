#!/bin/zsh
# =============================================================================
# Setup Cloud Sync with rclone
# =============================================================================
# This script configures rclone for Google Drive backup of recordings
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

CONFIG_FILE="$HOME/.config/tutorial-recorder/sync-config.json"
RCLONE_REMOTE="tutorial-recordings"

# =============================================================================
# Check Prerequisites
# =============================================================================

check_rclone() {
    if ! command -v rclone &> /dev/null; then
        log_error "rclone not installed. Installing..."
        brew install rclone
    fi
    log_success "rclone installed: $(rclone version | head -1)"
}

# =============================================================================
# Configure Google Drive
# =============================================================================

configure_gdrive() {
    echo ""
    echo "${CYAN}=== Google Drive Configuration ===${NC}"
    echo ""

    # Check if remote already exists
    if rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
        log_success "Remote '$RCLONE_REMOTE' already configured"
        echo ""
        read -q "REPLY?Reconfigure? (y/n) "
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        rclone config delete "$RCLONE_REMOTE"
    fi

    echo ""
    log_info "Setting up Google Drive remote..."
    echo ""
    echo "This will open a browser for Google authentication."
    echo "Please authorize rclone to access your Google Drive."
    echo ""
    read -k "?Press any key to continue..."
    echo ""

    # Create the remote interactively
    rclone config create "$RCLONE_REMOTE" drive \
        scope=drive \
        --all

    # Verify connection
    echo ""
    log_info "Verifying connection..."
    if rclone lsd "${RCLONE_REMOTE}:" &> /dev/null; then
        log_success "Google Drive connected successfully!"
    else
        log_error "Could not connect to Google Drive"
        return 1
    fi
}

# =============================================================================
# Configure Sync Settings
# =============================================================================

configure_sync() {
    echo ""
    echo "${CYAN}=== Sync Configuration ===${NC}"
    echo ""

    mkdir -p "$(dirname "$CONFIG_FILE")"

    # Default settings
    local recordings_path="$HOME/Desktop/Tutorial Recordings"
    local gdrive_path="Tutorial Recordings"
    local auto_sync="true"
    local sync_exports_only="false"

    echo "Configure sync settings:"
    echo ""

    # Local recordings path
    echo "Local recordings folder:"
    echo "  Current: $recordings_path"
    read "?  New path (or press Enter to keep): " new_path
    [[ -n "$new_path" ]] && recordings_path="$new_path"

    # Google Drive path
    echo ""
    echo "Google Drive destination folder:"
    echo "  Current: $gdrive_path"
    read "?  New path (or press Enter to keep): " new_gdrive
    [[ -n "$new_gdrive" ]] && gdrive_path="$new_gdrive"

    # Auto sync
    echo ""
    read -q "REPLY?Auto-sync after recording stops? (y/n) "
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]] && auto_sync="true" || auto_sync="false"

    # Sync only exports
    echo ""
    read -q "REPLY?Sync only exports folder (skip raw files)? (y/n) "
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]] && sync_exports_only="true" || sync_exports_only="false"

    # Save configuration
    cat > "$CONFIG_FILE" << EOF
{
    "rclone_remote": "$RCLONE_REMOTE",
    "local_path": "$recordings_path",
    "remote_path": "$gdrive_path",
    "auto_sync": $auto_sync,
    "sync_exports_only": $sync_exports_only,
    "exclude_patterns": [
        "*.tmp",
        "*.part",
        ".DS_Store",
        "Thumbs.db"
    ],
    "additional_folders": []
}
EOF

    log_success "Configuration saved to $CONFIG_FILE"
}

# =============================================================================
# Add Additional Sync Folders
# =============================================================================

add_sync_folder() {
    echo ""
    echo "${CYAN}=== Add Additional Sync Folder ===${NC}"
    echo ""

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Run setup first to create configuration"
        return 1
    fi

    read "?Local folder path: " local_folder
    [[ -z "$local_folder" ]] && return 1

    read "?Google Drive destination: " remote_folder
    [[ -z "$remote_folder" ]] && return 1

    read "?Exclude patterns (comma-separated, or Enter for none): " excludes

    # Add to config using Python
    python3 << EOF
import json

with open("$CONFIG_FILE", 'r') as f:
    config = json.load(f)

config['additional_folders'].append({
    "local": "$local_folder",
    "remote": "$remote_folder",
    "excludes": [x.strip() for x in "$excludes".split(',') if x.strip()]
})

with open("$CONFIG_FILE", 'w') as f:
    json.dump(config, f, indent=2)

print("Folder added to sync configuration")
EOF
}

# =============================================================================
# Test Sync (Dry Run)
# =============================================================================

test_sync() {
    echo ""
    echo "${CYAN}=== Testing Sync (Dry Run) ===${NC}"
    echo ""

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration not found. Run setup first."
        return 1
    fi

    local config=$(cat "$CONFIG_FILE")
    local local_path=$(echo "$config" | python3 -c "import sys,json; print(json.load(sys.stdin)['local_path'])")
    local remote_path=$(echo "$config" | python3 -c "import sys,json; print(json.load(sys.stdin)['remote_path'])")

    log_info "Testing sync from: $local_path"
    log_info "To: ${RCLONE_REMOTE}:$remote_path"
    echo ""

    rclone sync "$local_path" "${RCLONE_REMOTE}:$remote_path" \
        --dry-run \
        --progress \
        --exclude ".DS_Store" \
        --exclude "*.tmp" \
        2>&1 | head -50

    echo ""
    log_info "This was a dry run. No files were transferred."
}

# =============================================================================
# Run Sync
# =============================================================================

run_sync() {
    local sync_type="${1:-all}"  # all, recordings, or folder path

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration not found. Run: setup-cloud-sync.sh configure"
        return 1
    fi

    local config=$(cat "$CONFIG_FILE")
    local remote=$(echo "$config" | python3 -c "import sys,json; print(json.load(sys.stdin)['rclone_remote'])")
    local local_path=$(echo "$config" | python3 -c "import sys,json; print(json.load(sys.stdin)['local_path'])")
    local remote_path=$(echo "$config" | python3 -c "import sys,json; print(json.load(sys.stdin)['remote_path'])")
    local exports_only=$(echo "$config" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sync_exports_only', False))")

    log_info "Starting sync..."

    local exclude_args="--exclude .DS_Store --exclude *.tmp --exclude *.part"

    if [[ "$exports_only" == "True" ]]; then
        exclude_args="$exclude_args --exclude raw/"
    fi

    if [[ "$sync_type" == "all" ]] || [[ "$sync_type" == "recordings" ]]; then
        log_info "Syncing: $local_path -> ${remote}:$remote_path"

        rclone sync "$local_path" "${remote}:$remote_path" \
            $exclude_args \
            --progress \
            --transfers 4 \
            --checkers 8 \
            --log-level INFO

        log_success "Recordings sync complete"
    fi

    # Sync additional folders
    if [[ "$sync_type" == "all" ]]; then
        python3 << EOF
import json
import subprocess

with open("$CONFIG_FILE", 'r') as f:
    config = json.load(f)

for folder in config.get('additional_folders', []):
    local = folder['local']
    remote = folder['remote']
    excludes = folder.get('excludes', [])

    exclude_args = ' '.join([f'--exclude "{e}"' for e in excludes])

    print(f"\nSyncing: {local} -> {config['rclone_remote']}:{remote}")

    cmd = f"rclone sync '{local}' '{config['rclone_remote']}:{remote}' {exclude_args} --progress"
    subprocess.run(cmd, shell=True)
EOF
    fi
}

# =============================================================================
# Show Status
# =============================================================================

show_status() {
    echo ""
    echo "${CYAN}=== Sync Status ===${NC}"
    echo ""

    # Check rclone
    if command -v rclone &> /dev/null; then
        log_success "rclone: $(rclone version | head -1 | cut -d' ' -f2)"
    else
        log_error "rclone: not installed"
    fi

    # Check remote
    if rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
        log_success "Remote: $RCLONE_REMOTE configured"

        # Show usage
        local usage=$(rclone about "${RCLONE_REMOTE}:" 2>/dev/null | grep "Used:" | head -1)
        [[ -n "$usage" ]] && log_info "Google Drive $usage"
    else
        log_warning "Remote: not configured"
    fi

    # Check config
    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "Config: $CONFIG_FILE"
        echo ""
        echo "Current configuration:"
        cat "$CONFIG_FILE" | python3 -c "
import sys, json
config = json.load(sys.stdin)
print(f\"  Local path: {config['local_path']}\")
print(f\"  Remote path: {config['remote_path']}\")
print(f\"  Auto-sync: {config['auto_sync']}\")
print(f\"  Exports only: {config.get('sync_exports_only', False)}\")
print(f\"  Additional folders: {len(config.get('additional_folders', []))}\")
"
    else
        log_warning "Config: not found"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo "${GREEN}║     Cloud Sync Setup (rclone)          ║${NC}"
    echo "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""

    case "${1:-}" in
        configure)
            check_rclone
            configure_gdrive
            configure_sync
            ;;
        add-folder)
            add_sync_folder
            ;;
        test)
            test_sync
            ;;
        sync)
            run_sync "${2:-all}"
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  configure   - Set up Google Drive and sync settings"
            echo "  add-folder  - Add additional folder to sync"
            echo "  test        - Test sync (dry run)"
            echo "  sync [type] - Run sync (type: all, recordings)"
            echo "  status      - Show sync status"
            echo ""
            ;;
    esac
}

main "$@"
