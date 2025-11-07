#!/bin/bash

# Copyright (c) 2025 webOS Open Source Edition
# Setup script for QEMU render/graphics testing environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_WEBOS_DIR="$(dirname "$SCRIPT_DIR")"
RENDER_CONF="${BUILD_WEBOS_DIR}/webos-render.conf"

echo "=========================================="
echo "webOS QEMU Render Environment Setup"
echo "=========================================="
echo ""

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running on a system with display capabilities
check_display_support() {
    echo "Checking display support..."

    if [ -n "$DISPLAY" ]; then
        print_status "X11 display detected: $DISPLAY"
        GRAPHICS_BACKEND="x11"
    elif [ -n "$WAYLAND_DISPLAY" ]; then
        print_status "Wayland display detected: $WAYLAND_DISPLAY"
        GRAPHICS_BACKEND="wayland"
    else
        print_warning "No display server detected. Graphics will use virtual framebuffer."
        GRAPHICS_BACKEND="headless"
    fi
}

# Check for required packages
check_dependencies() {
    echo ""
    echo "Checking system dependencies..."

    local missing_packages=()

    # Essential QEMU packages
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        missing_packages+=("qemu-system-x86")
    fi

    # Graphics libraries
    if ! ldconfig -p | grep -q libGL.so; then
        missing_packages+=("libgl1-mesa-dev")
    fi

    if ! ldconfig -p | grep -q libvirglrenderer; then
        missing_packages+=("libvirglrenderer1")
    fi

    # SDL2 for QEMU graphics
    if ! ldconfig -p | grep -q libSDL2; then
        missing_packages+=("libsdl2-2.0-0")
    fi

    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_warning "Missing packages detected: ${missing_packages[*]}"
        echo ""
        echo "Install them with:"
        echo "  sudo apt-get install ${missing_packages[*]}"
        echo ""
        read -p "Would you like to continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "All required dependencies are installed"
    fi
}

# Check OpenGL/Mesa support
check_opengl_support() {
    echo ""
    echo "Checking OpenGL support..."

    if command -v glxinfo &> /dev/null; then
        GL_RENDERER=$(glxinfo | grep "OpenGL renderer" | cut -d':' -f2 | xargs || echo "Unknown")
        GL_VERSION=$(glxinfo | grep "OpenGL version" | cut -d':' -f2 | xargs || echo "Unknown")
        print_status "OpenGL Renderer: $GL_RENDERER"
        print_status "OpenGL Version: $GL_VERSION"

        # Check for hardware acceleration
        if echo "$GL_RENDERER" | grep -qi "llvmpipe\|software"; then
            print_warning "Software rendering detected (llvmpipe). Hardware acceleration may not be available."
        fi
    else
        print_warning "glxinfo not found. Install mesa-utils to check OpenGL support."
    fi
}

# Create render-specific configuration
create_render_config() {
    echo ""
    echo "Creating render environment configuration..."

    cat > "$RENDER_CONF" << 'EOF'
# webOS QEMU Render Environment Configuration
# This file contains settings optimized for graphics testing with QEMU

# Enable graphics features for testing
DISTRO_FEATURES:append = " opengl vulkan wayland"

# QEMU graphics configuration
QB_GRAPHICS ?= "-vga std"
QB_OPT_APPEND:append = " -display sdl,gl=on"

# Enable virgl (VirtIO GPU) for hardware-accelerated 3D
QB_OPT_APPEND:append = " -device virtio-vga-gl"

# Memory settings for graphics workloads (increase if needed)
QB_MEM ?= "-m 2048"

# Enable KVM if available for better performance
QB_OPT_APPEND:append = " ${@bb.utils.contains('MACHINE_FEATURES', 'kvm', '-enable-kvm', '', d)}"

# Qt6 graphics settings for webOS
QT_QPA_PLATFORM ?= "wayland"
QT_QUICK_BACKEND ?= "software"

# Mesa/DRI settings
PACKAGECONFIG:append:pn-mesa = " gallium-llvm"
PACKAGECONFIG:append:pn-mesa = " virgl"

# Enable additional image features for testing
EXTRA_IMAGE_FEATURES += "debug-tweaks tools-debug tools-profile"

# Add graphics testing tools to the image
IMAGE_INSTALL:append = " \
    mesa-demos \
    kmscube \
    weston \
    weston-examples \
    qt6-qtbase-examples \
"
EOF

    print_status "Created render configuration: $RENDER_CONF"
    echo ""
    echo "To use this configuration, add the following to your webos-local.conf:"
    echo "  require $(realpath --relative-to="${BUILD_WEBOS_DIR}" "$RENDER_CONF")"
}

# Create helper script to run QEMU with graphics
create_run_script() {
    echo ""
    echo "Creating QEMU graphics launcher script..."

    local RUN_SCRIPT="${SCRIPT_DIR}/run-qemu-graphics.sh"

    cat > "$RUN_SCRIPT" << 'RUNSCRIPT_EOF'
#!/bin/bash

# Helper script to launch QEMU with graphics rendering enabled

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_WEBOS_DIR="$(dirname "$SCRIPT_DIR")"

# Source the build environment
if [ ! -f "${BUILD_WEBOS_DIR}/oe-init-build-env" ]; then
    echo "Error: Build environment not initialized. Run './mcf' first."
    exit 1
fi

cd "$BUILD_WEBOS_DIR"
source oe-init-build-env > /dev/null

# Default machine
MACHINE=${MACHINE:-qemux86-64}
IMAGE=${IMAGE:-webos-image}

# Graphics options
QEMU_GRAPHICS_OPTS="-vga std -display sdl,gl=on"
QEMU_VIRTIO_GPU="-device virtio-vga-gl"
QEMU_MEMORY="-m 2048"

# Enable KVM if available
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    QEMU_KVM_OPTS="-enable-kvm"
    echo "KVM acceleration enabled"
else
    QEMU_KVM_OPTS=""
    echo "Warning: KVM not available, using software emulation (slower)"
fi

# Audio support (optional)
QEMU_AUDIO_OPTS="-audiodev pa,id=snd0 -device AC97,audiodev=snd0"

echo "=========================================="
echo "Launching QEMU with Graphics Rendering"
echo "=========================================="
echo "Machine: $MACHINE"
echo "Image: $IMAGE"
echo ""

# Check if image exists
IMAGE_FILE="${BUILD_WEBOS_DIR}/BUILD/deploy/images/${MACHINE}/${IMAGE}-${MACHINE}.wic"
if [ ! -f "$IMAGE_FILE" ] && [ ! -f "${IMAGE_FILE}.qemuboot.conf" ]; then
    echo "Error: Image not found. Build it first with:"
    echo "  bitbake $IMAGE"
    exit 1
fi

# Run QEMU with graphics
echo "Starting QEMU with graphics rendering..."
echo ""

# Use runqemu with custom options
runqemu "$MACHINE" "$IMAGE" \
    qemuparams="$QEMU_MEMORY $QEMU_KVM_OPTS $QEMU_GRAPHICS_OPTS $QEMU_VIRTIO_GPU $QEMU_AUDIO_OPTS" \
    "$@"
RUNSCRIPT_EOF

    chmod +x "$RUN_SCRIPT"
    print_status "Created QEMU launcher: $RUN_SCRIPT"
}

# Display summary
display_summary() {
    echo ""
    echo "=========================================="
    echo "Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Add render configuration to your build:"
    echo "   echo 'require webos-render.conf' >> webos-local.conf"
    echo ""
    echo "2. Configure and build the image:"
    echo "   ./mcf -p 0 -b 0 qemux86-64"
    echo "   source oe-init-build-env"
    echo "   bitbake webos-image"
    echo ""
    echo "3. Run QEMU with graphics rendering:"
    echo "   ./scripts/run-qemu-graphics.sh"
    echo ""
    echo "Graphics Backend: $GRAPHICS_BACKEND"
    echo ""
    echo "For more information, see: docs/RENDER_ENVIRONMENT.md"
    echo ""
}

# Main execution
main() {
    check_display_support
    check_dependencies
    check_opengl_support
    create_render_config
    create_run_script
    display_summary
}

main "$@"
