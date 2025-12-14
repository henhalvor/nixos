#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: run-emulator [OPTIONS] [avd-name]

Launch an Android emulator with hardware acceleration and Hyprland compatibility.

Arguments:
  avd-name              Name of the AVD to launch (if not provided, lists available AVDs)

Options:
  -w, --wipe-data       Wipe user data before starting
  -c, --cold-boot       Force cold boot (ignore snapshots)
  -g, --gpu <mode>      GPU mode: host, swiftshader_indirect, angle_indirect (default: host)
  -p, --port <port>     Console port number (default: auto)
  -h, --help            Show this help message

Examples:
  run-emulator Pixel_8_API_35
  run-emulator --wipe-data Pixel_8_API_35
  run-emulator --cold-boot --gpu swiftshader_indirect Test_Device

GPU Modes:
  host                  - Use host GPU (fastest, requires KVM)
  swiftshader_indirect  - Software rendering (slower, more compatible)
  angle_indirect        - ANGLE renderer (Windows compatibility layer)
EOF
}

list_avds() {
    echo -e "${BLUE}Available AVDs:${NC}"
    avdmanager list avd | grep "Name:" | sed 's/    Name: /  - /'
    echo ""
    echo "Run 'run-emulator <avd-name>' to launch an emulator"
}

# Default options
WIPE_DATA=false
COLD_BOOT=false
GPU_MODE="host"
PORT=""
AVD_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--wipe-data)
            WIPE_DATA=true
            shift
            ;;
        -c|--cold-boot)
            COLD_BOOT=true
            shift
            ;;
        -g|--gpu)
            GPU_MODE="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            AVD_NAME="$1"
            shift
            ;;
    esac
done

# If no AVD name provided, list available AVDs
if [ -z "$AVD_NAME" ]; then
    list_avds
    exit 0
fi

# Check if AVD exists
if [ ! -d "$ANDROID_AVD_HOME/$AVD_NAME.avd" ]; then
    echo -e "${RED}Error: AVD '$AVD_NAME' not found${NC}"
    echo ""
    list_avds
    exit 1
fi

# Build emulator command
EMULATOR_CMD="$ANDROID_SDK_ROOT/emulator/emulator"
EMULATOR_ARGS="-avd $AVD_NAME"

# Add GPU mode
EMULATOR_ARGS="$EMULATOR_ARGS -gpu $GPU_MODE"

# Disable metrics collection
EMULATOR_ARGS="$EMULATOR_ARGS -no-metrics"

# Add Vulkan feature if using host GPU
if [ "$GPU_MODE" = "host" ]; then
    EMULATOR_ARGS="$EMULATOR_ARGS -feature -Vulkan"
fi

# Add wipe data flag
if [ "$WIPE_DATA" = true ]; then
    EMULATOR_ARGS="$EMULATOR_ARGS -wipe-data"
fi

# Add cold boot flag
if [ "$COLD_BOOT" = true ]; then
    EMULATOR_ARGS="$EMULATOR_ARGS -no-snapshot-load"
fi

# Add port if specified
if [ -n "$PORT" ]; then
    EMULATOR_ARGS="$EMULATOR_ARGS -port $PORT"
fi

echo -e "${GREEN}Launching emulator: $AVD_NAME${NC}"
echo "  GPU Mode: $GPU_MODE"
[ "$WIPE_DATA" = true ] && echo "  Wipe Data: enabled"
[ "$COLD_BOOT" = true ] && echo "  Cold Boot: enabled"
[ -n "$PORT" ] && echo "  Port: $PORT"
echo ""
echo -e "${YELLOW}Starting ADB server...${NC}"

# Ensure ADB server is running
adb start-server 2>/dev/null || true

echo -e "${YELLOW}Using steam-run for Hyprland compatibility...${NC}"
echo ""

# Set ADB_SERVER_SOCKET to use host ADB server from within steam-run
export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037

# Force X11 backend for Qt (better toolbar button compatibility on Wayland/Hyprland)
export QT_QPA_PLATFORM=xcb

# Disable Qt Wayland to prevent input issues
export QT_QPA_PLATFORMTHEME=""

# Launch emulator with steam-run for FHS compatibility (required for Hyprland)
exec steam-run $EMULATOR_CMD $EMULATOR_ARGS
