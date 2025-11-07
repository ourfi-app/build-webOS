#!/bin/bash

# Copyright (c) 2025 webOS Open Source Edition
# Helper script to launch QEMU with graphics rendering enabled

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_WEBOS_DIR="$(dirname "$SCRIPT_DIR")"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Launch QEMU with graphics rendering for webOS testing.

OPTIONS:
    -m, --machine MACHINE    Target machine (default: qemux86-64)
                            Options: qemux86, qemux86-64, qemuarm

    -i, --image IMAGE       Image to boot (default: webos-image)

    -d, --display DISPLAY   Display backend (default: sdl)
                            Options: sdl, gtk, vnc, none

    --memory SIZE          Memory in MB (default: 2048)

    --no-virgl             Disable VirtIO GPU acceleration

    --no-kvm               Disable KVM acceleration

    --serial               Enable serial console output

    --nographic            Run in non-graphical mode (serial only)

    -h, --help             Show this help message

EXAMPLES:
    # Basic usage with defaults
    $0

    # Use qemux86 machine
    $0 --machine qemux86

    # Use GTK display with 4GB memory
    $0 --display gtk --memory 4096

    # Headless VNC mode
    $0 --display vnc

    # Disable GPU acceleration (software rendering)
    $0 --no-virgl

    # Non-graphical mode with serial console
    $0 --nographic

EOF
}

# Default configuration
MACHINE="${MACHINE:-qemux86-64}"
IMAGE="${IMAGE:-webos-image}"
DISPLAY_BACKEND="sdl"
MEMORY="2048"
ENABLE_VIRGL=true
ENABLE_KVM=true
ENABLE_SERIAL=false
NOGRAPHIC=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--machine)
            MACHINE="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        -d|--display)
            DISPLAY_BACKEND="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --no-virgl)
            ENABLE_VIRGL=false
            shift
            ;;
        --no-kvm)
            ENABLE_KVM=false
            shift
            ;;
        --serial)
            ENABLE_SERIAL=true
            shift
            ;;
        --nographic)
            NOGRAPHIC=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Source the build environment
if [ ! -f "${BUILD_WEBOS_DIR}/oe-init-build-env" ]; then
    print_error "Build environment not initialized."
    echo ""
    echo "Please run the following commands first:"
    echo "  cd $BUILD_WEBOS_DIR"
    echo "  ./mcf -p 0 -b 0 $MACHINE"
    exit 1
fi

cd "$BUILD_WEBOS_DIR"
source oe-init-build-env > /dev/null

# Build QEMU options
QEMU_OPTS=""

# Memory configuration
QEMU_OPTS="$QEMU_OPTS -m $MEMORY"

# Display configuration
if [ "$NOGRAPHIC" = true ]; then
    QEMU_OPTS="$QEMU_OPTS -nographic"
    print_info "Running in non-graphical mode (serial console only)"
else
    case "$DISPLAY_BACKEND" in
        sdl)
            if $ENABLE_VIRGL; then
                QEMU_OPTS="$QEMU_OPTS -display sdl,gl=on"
            else
                QEMU_OPTS="$QEMU_OPTS -display sdl"
            fi
            ;;
        gtk)
            if $ENABLE_VIRGL; then
                QEMU_OPTS="$QEMU_OPTS -display gtk,gl=on"
            else
                QEMU_OPTS="$QEMU_OPTS -display gtk"
            fi
            ;;
        vnc)
            QEMU_OPTS="$QEMU_OPTS -display vnc=:1"
            print_info "VNC server will be available at localhost:5901"
            ;;
        none)
            QEMU_OPTS="$QEMU_OPTS -display none"
            ;;
        *)
            print_error "Unknown display backend: $DISPLAY_BACKEND"
            exit 1
            ;;
    esac
fi

# VirtIO GPU configuration
if $ENABLE_VIRGL && [ "$NOGRAPHIC" = false ]; then
    QEMU_OPTS="$QEMU_OPTS -device virtio-vga-gl"
    print_info "VirtIO GPU acceleration enabled"
else
    QEMU_OPTS="$QEMU_OPTS -vga std"
    if [ "$NOGRAPHIC" = false ]; then
        print_warning "VirtIO GPU disabled, using software rendering"
    fi
fi

# KVM configuration
if $ENABLE_KVM; then
    if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        QEMU_OPTS="$QEMU_OPTS -enable-kvm"
        print_success "KVM acceleration enabled"
    else
        print_warning "KVM not available, using software emulation (slower)"
        print_warning "To enable KVM: sudo usermod -aG kvm $USER (then log out/in)"
    fi
fi

# Audio support
if command -v pulseaudio &> /dev/null || pgrep -x pulseaudio > /dev/null; then
    QEMU_OPTS="$QEMU_OPTS -audiodev pa,id=snd0 -device AC97,audiodev=snd0"
    print_info "PulseAudio support enabled"
fi

# Serial console
if $ENABLE_SERIAL; then
    QEMU_OPTS="$QEMU_OPTS -serial mon:stdio"
    print_info "Serial console enabled"
fi

# Check if image exists
IMAGE_DIR="${BUILD_WEBOS_DIR}/BUILD/deploy/images/${MACHINE}"
if [ ! -d "$IMAGE_DIR" ]; then
    print_error "Image directory not found: $IMAGE_DIR"
    echo ""
    echo "Please build the image first:"
    echo "  source oe-init-build-env"
    echo "  bitbake $IMAGE"
    exit 1
fi

# Display launch information
echo ""
echo "=========================================="
echo "  webOS QEMU Graphics Testing"
echo "=========================================="
echo ""
print_info "Machine:        $MACHINE"
print_info "Image:          $IMAGE"
print_info "Display:        $DISPLAY_BACKEND"
print_info "Memory:         ${MEMORY}MB"
print_info "VirtIO GPU:     $ENABLE_VIRGL"
print_info "KVM:            $ENABLE_KVM"
echo ""
print_info "QEMU options:   $QEMU_OPTS"
echo ""
echo "=========================================="
echo ""

# Export display if not set
if [ -z "$DISPLAY" ] && [ "$NOGRAPHIC" = false ] && [ "$DISPLAY_BACKEND" != "vnc" ]; then
    print_warning "DISPLAY environment variable not set"
    export DISPLAY=:0
    print_info "Setting DISPLAY=$DISPLAY"
fi

# Run QEMU
print_info "Starting QEMU..."
echo ""

# Check if runqemu-wrapper exists, otherwise use runqemu directly
if command -v runqemu &> /dev/null; then
    exec runqemu "$MACHINE" "$IMAGE" qemuparams="$QEMU_OPTS" "$@"
else
    print_error "runqemu command not found. Make sure you've sourced oe-init-build-env"
    exit 1
fi
