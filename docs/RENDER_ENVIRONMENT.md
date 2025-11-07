# webOS QEMU Render Environment Setup

This guide explains how to set up a development and testing environment for webOS with QEMU graphics rendering support.

## Overview

The render environment provides:
- **Hardware-accelerated 3D graphics** using VirtIO GPU (virgl)
- **OpenGL and Vulkan support** for modern graphics workloads
- **Wayland display server** for compositor testing
- **Qt6 graphics testing** with proper rendering backend
- **Graphics debugging tools** (mesa-demos, kmscube, etc.)

## Prerequisites

### System Requirements

- **Ubuntu 20.04 or 22.04** (recommended)
- **Minimum 8GB RAM** (16GB recommended for comfortable development)
- **OpenGL support** (hardware or software rendering)
- **X11 or Wayland** display server

### Required Packages

Install system dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
    qemu-system-x86 \
    qemu-system-arm \
    libgl1-mesa-dev \
    libvirglrenderer1 \
    libsdl2-2.0-0 \
    mesa-utils \
    pulseaudio
```

## Quick Start

### 1. Run Setup Script

```bash
./scripts/setup-render-env.sh
```

This script will:
- Check your system for graphics support
- Verify required dependencies
- Create `webos-render.conf` with graphics settings
- Generate helper scripts for running QEMU

### 2. Enable Render Configuration

Add the render configuration to your build:

```bash
echo 'require webos-render.conf' >> webos-local.conf
```

### 3. Configure Build Environment

```bash
./mcf -p 0 -b 0 qemux86-64
source oe-init-build-env
```

### 4. Build the Image

```bash
bitbake webos-image
```

This will take 2-6 hours on first build (subsequent builds are faster with sstate-cache).

### 5. Run QEMU with Graphics

```bash
./scripts/run-qemu-graphics.sh
```

## Supported QEMU Machines

The render environment supports these QEMU machines:

| Machine | Architecture | Notes |
|---------|--------------|-------|
| `qemux86-64` | x86_64 | **Recommended** - Best performance with KVM |
| `qemux86` | x86 (32-bit) | Legacy support |
| `qemuarm` | ARM | Slower, no KVM on x86 hosts |

## Graphics Configuration

### VirtIO GPU (virgl)

The default configuration uses VirtIO GPU for hardware-accelerated 3D:

```bitbake
QB_OPT_APPEND:append = " -device virtio-vga-gl"
QB_OPT_APPEND:append = " -display sdl,gl=on"
```

This enables:
- OpenGL acceleration in the guest
- GPU command forwarding to the host
- Better performance for Qt6 and Wayland compositors

### Display Options

You can customize the display backend when running QEMU:

**SDL with OpenGL (default):**
```bash
./scripts/run-qemu-graphics.sh
```

**GTK backend:**
```bash
runqemu qemux86-64 webos-image qemuparams="-display gtk,gl=on"
```

**VNC (headless):**
```bash
runqemu qemux86-64 webos-image qemuparams="-display vnc=:1"
```

Then connect with: `vncviewer localhost:5901`

### Memory Configuration

Default memory is 2GB. For graphics-intensive testing, increase it:

```bash
# In webos-render.conf or webos-local.conf
QB_MEM = "-m 4096"
```

## Testing Graphics Rendering

### Check OpenGL Support

Inside QEMU:

```bash
# Check OpenGL renderer
glxinfo | grep "OpenGL renderer"

# Run OpenGL demo
glxgears

# Test KMS/DRM
kmscube
```

### Test Qt6 Rendering

```bash
# List Qt6 examples
ls /usr/share/qt6/examples/

# Run a Qt6 Quick example
/usr/share/qt6/examples/quick/quickwidgets/quickwidget/quickwidget
```

### Wayland Compositor Testing

```bash
# Start Weston compositor
weston &

# Run Weston examples
weston-simple-egl
weston-flower
```

## Performance Optimization

### Enable KVM Acceleration

For best performance on x86_64 hosts:

```bash
# Check KVM availability
ls -l /dev/kvm

# Add your user to kvm group
sudo usermod -aG kvm $USER
# Log out and back in for changes to take effect
```

The helper script automatically enables KVM if available.

### CPU and Thread Settings

Adjust parallel build settings in `conf/local.conf`:

```bitbake
# Use 75% of CPU cores
BB_NUMBER_THREADS = "12"
PARALLEL_MAKE = "-j 12"
```

### Graphics Driver Selection

For software rendering (no GPU):
```bitbake
# In webos-local.conf
QB_OPT_APPEND:remove = " -device virtio-vga-gl"
QB_GRAPHICS = "-vga std"
```

## Troubleshooting

### No Graphics Display

**Symptom:** QEMU starts but shows no graphics

**Solution:**
```bash
# Check display environment
echo $DISPLAY

# If empty, export it
export DISPLAY=:0

# Or use VNC
runqemu qemux86-64 webos-image qemuparams="-display vnc=:1"
```

### OpenGL Errors

**Symptom:** `failed to create virgl renderer`

**Solution:**
```bash
# Check Mesa/virgl installation
ldconfig -p | grep virglrenderer

# Install if missing
sudo apt-get install libvirglrenderer1

# Or disable virgl
QB_OPT_APPEND:remove = " -device virtio-vga-gl"
```

### Slow Performance

**Symptom:** Graphics rendering is very slow

**Solutions:**
1. Enable KVM (x86_64 only)
2. Increase QEMU memory: `QB_MEM = "-m 4096"`
3. Use hardware rendering (not llvmpipe)
4. Reduce graphics features if on software rendering

### Build Failures

**Symptom:** `mesa` or `qt6` build failures

**Solution:**
```bash
# Clean and rebuild
bitbake -c cleanall mesa
bitbake mesa

# Check build logs
cat BUILD/tmp/work/*/mesa/*/temp/log.do_compile
```

## Advanced Configuration

### Custom QEMU Options

Edit `scripts/run-qemu-graphics.sh` or pass custom parameters:

```bash
./scripts/run-qemu-graphics.sh qemuparams="-smp 4 -cpu host"
```

### Vulkan Support

Add Vulkan to your configuration:

```bitbake
# In webos-local.conf
DISTRO_FEATURES:append = " vulkan"
IMAGE_INSTALL:append = " vulkan-tools"
```

Test with: `vulkaninfo`

### Network Configuration

QEMU uses slirp networking by default. For better networking:

```bash
# Create TAP interface (requires root)
sudo ip tuntap add dev tap0 mode tap
sudo ip link set tap0 up
sudo ip addr add 192.168.7.1/24 dev tap0

# Use in QEMU
runqemu qemux86-64 webos-image slirp
```

## CI/CD Integration

For automated testing in headless environments:

```bash
# Use Xvfb (virtual framebuffer)
Xvfb :99 -screen 0 1280x1024x24 &
export DISPLAY=:99

./scripts/run-qemu-graphics.sh qemuparams="-display gtk"
```

## Additional Resources

- [webOS OSE Documentation](https://www.webosose.org/docs/)
- [Yocto QEMU Documentation](https://docs.yoctoproject.org/dev-manual/qemu.html)
- [VirtIO GPU](https://www.kraxel.org/blog/2016/09/using-virtio-gpu-with-libvirt-and-spice/)
- [Mesa virgl](https://virgil3d.github.io/)

## Getting Help

If you encounter issues:

1. Check `BUILD/tmp/log/cooker/qemux86-64/console-latest.log`
2. Review QEMU output for errors
3. Verify graphics drivers with `glxinfo`
4. Test with software rendering first

For webOS-specific questions, consult the [webOS OSE forums](https://forum.webosose.org/).
