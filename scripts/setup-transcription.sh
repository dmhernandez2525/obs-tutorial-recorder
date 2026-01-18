#!/bin/bash
# =============================================================================
# Setup Transcription (Whisper)
# =============================================================================
# Standalone script to install whisper-cpp and download models
#
# Usage:
#   ./setup-transcription.sh           # Install whisper + small model (default)
#   ./setup-transcription.sh tiny      # Install whisper + tiny model
#   ./setup-transcription.sh small     # Install whisper + small model
#   ./setup-transcription.sh medium    # Install whisper + medium model
#   ./setup-transcription.sh all       # Install whisper + all models
#   ./setup-transcription.sh status    # Check installation status
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

MODELS_DIR="$HOME/.cache/whisper"
BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

# =============================================================================
# Check Status
# =============================================================================

check_status() {
    echo ""
    echo -e "${CYAN}${BOLD}=== Transcription Status ===${NC}"
    echo ""

    # Check whisper-cli (Homebrew package is whisper-cpp but binary is whisper-cli)
    if command -v whisper-cli &> /dev/null || [[ -f /opt/homebrew/bin/whisper-cli ]]; then
        log_success "whisper-cli: installed (via whisper-cpp)"
    else
        log_error "whisper-cli: not installed"
        echo "         Run: brew install whisper-cpp"
    fi

    echo ""
    echo "Models directory: $MODELS_DIR"
    echo ""

    # Check models
    if [[ -d "$MODELS_DIR" ]]; then
        echo "Available models:"
        for model in tiny base small medium; do
            local file="$MODELS_DIR/ggml-${model}.en.bin"
            if [[ -f "$file" ]]; then
                local size=$(du -h "$file" | cut -f1)
                log_success "  $model: $size"
            else
                echo -e "  $model: ${YELLOW}not downloaded${NC}"
            fi
        done
    else
        log_warning "Models directory does not exist"
    fi

    echo ""
}

# =============================================================================
# Install whisper-cpp
# =============================================================================

install_whisper() {
    # Check for whisper-cli (the actual binary name from whisper-cpp package)
    if command -v whisper-cli &> /dev/null || [[ -f /opt/homebrew/bin/whisper-cli ]]; then
        log_success "whisper-cpp already installed"
        return 0
    fi

    log_info "Installing whisper-cpp via Homebrew..."

    if ! command -v brew &> /dev/null; then
        log_error "Homebrew not installed"
        echo "Install Homebrew first: https://brew.sh"
        exit 1
    fi

    brew install whisper-cpp

    if [[ -f /opt/homebrew/bin/whisper-cli ]] || command -v whisper-cli &> /dev/null; then
        log_success "whisper-cpp installed"
    else
        log_error "Failed to install whisper-cpp"
        exit 1
    fi
}

# =============================================================================
# Download Model
# =============================================================================

download_model() {
    local model=$1
    local file="ggml-${model}.en.bin"
    local path="$MODELS_DIR/$file"
    local url="$BASE_URL/$file"

    mkdir -p "$MODELS_DIR"

    if [[ -f "$path" ]]; then
        log_success "$model model already exists"
        return 0
    fi

    log_info "Downloading $model model..."

    case $model in
        tiny)   echo "  Size: ~75MB, Speed: Very Fast, Accuracy: Good" ;;
        base)   echo "  Size: ~150MB, Speed: Fast, Accuracy: Better" ;;
        small)  echo "  Size: ~500MB, Speed: Medium, Accuracy: High (recommended)" ;;
        medium) echo "  Size: ~1.5GB, Speed: Slow, Accuracy: Very High" ;;
    esac
    echo ""

    if curl -L "$url" -o "$path" --progress-bar; then
        log_success "$model model downloaded"
    else
        log_error "Failed to download $model model"
        rm -f "$path"
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    local action="${1:-small}"

    echo ""
    echo -e "${GREEN}${BOLD}=== Transcription Setup (Whisper) ===${NC}"
    echo ""

    case $action in
        status)
            check_status
            exit 0
            ;;
        tiny|base|small|medium)
            install_whisper
            download_model "$action"
            ;;
        all)
            install_whisper
            download_model "tiny"
            download_model "base"
            download_model "small"
            ;;
        *)
            echo "Usage: $0 [tiny|base|small|medium|all|status]"
            echo ""
            echo "Models:"
            echo "  tiny    - 75MB, fastest, good for quick drafts"
            echo "  base    - 150MB, fast, better accuracy"
            echo "  small   - 500MB, recommended for tutorials"
            echo "  medium  - 1.5GB, highest accuracy, slowest"
            echo "  all     - Download tiny, base, and small models"
            echo ""
            echo "  status  - Show installation status"
            exit 1
            ;;
    esac

    echo ""
    log_success "Transcription setup complete!"
    echo ""
    echo "Models available in: $MODELS_DIR"
    ls -lh "$MODELS_DIR"/*.bin 2>/dev/null || echo "No models found"
    echo ""
}

main "$@"
