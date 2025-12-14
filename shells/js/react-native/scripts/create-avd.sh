#!/usr/bin/env bash
set -e

# Default configuration
DEFAULT_RAM=4096
DEFAULT_CORES=4
DEFAULT_STORAGE=8192
DEFAULT_DEVICE="pixel_8"
DEFAULT_API_LEVEL=35

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: create-avd [OPTIONS] <avd-name>

Create a new Android Virtual Device (AVD) for development.

Arguments:
  avd-name              Name for the AVD (e.g., Pixel_8_API_35)

Options:
  -d, --device         Device profile (default: pixel_8)
  -r, --ram            RAM in MB (default: 4096)
  -c, --cores          CPU cores (default: 4)
  -s, --storage        Storage in MB (default: 8192)
  -a, --api-level      Android API level (default: 35)
  -p, --playstore      Use Google Play Store image (default: false)
  -h, --help           Show this help message

Examples:
  create-avd Pixel_8_API_35
  create-avd -r 2048 -c 2 Tablet_API_35
  create-avd --playstore Pixel_8_Play_API_35

Available device profiles:
  pixel_8, pixel_tablet, pixel_7, pixel_6, pixel_5
  (Run 'avdmanager list device' for complete list)
EOF
}

# Parse arguments
RAM=$DEFAULT_RAM
CORES=$DEFAULT_CORES
STORAGE=$DEFAULT_STORAGE
DEVICE=$DEFAULT_DEVICE
API_LEVEL=$DEFAULT_API_LEVEL
USE_PLAYSTORE=false
AVD_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -r|--ram)
            RAM="$2"
            shift 2
            ;;
        -c|--cores)
            CORES="$2"
            shift 2
            ;;
        -s|--storage)
            STORAGE="$2"
            shift 2
            ;;
        -a|--api-level)
            API_LEVEL="$2"
            shift 2
            ;;
        -p|--playstore)
            USE_PLAYSTORE=true
            shift
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

if [ -z "$AVD_NAME" ]; then
    echo -e "${RED}Error: AVD name is required${NC}"
    usage
    exit 1
fi

# Determine system image based on playstore flag
if [ "$USE_PLAYSTORE" = true ]; then
    SYSTEM_IMAGE="system-images;android-${API_LEVEL};google_apis_playstore;x86_64"
    IMAGE_TYPE="google_apis_playstore"
else
    SYSTEM_IMAGE="system-images;android-${API_LEVEL};google_apis;x86_64"
    IMAGE_TYPE="google_apis"
fi

echo -e "${GREEN}Creating AVD: $AVD_NAME${NC}"
echo "  Device: $DEVICE"
echo "  API Level: $API_LEVEL"
echo "  Image Type: $IMAGE_TYPE"
echo "  RAM: ${RAM}MB"
echo "  CPU Cores: $CORES"
echo "  Storage: ${STORAGE}MB"
echo ""

# Check if AVD already exists
if [ -d "$ANDROID_AVD_HOME/$AVD_NAME.avd" ]; then
    echo -e "${YELLOW}Warning: AVD '$AVD_NAME' already exists${NC}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    avdmanager delete avd -n "$AVD_NAME"
fi

# Create AVD
echo -e "${GREEN}Creating AVD with avdmanager...${NC}"
echo "no" | avdmanager create avd \
    -k "$SYSTEM_IMAGE" \
    -n "$AVD_NAME" \
    -d "$DEVICE" \
    --force

# Configure AVD hardware properties
AVD_CONFIG="$ANDROID_AVD_HOME/$AVD_NAME.avd/config.ini"

if [ -f "$AVD_CONFIG" ]; then
    echo -e "${GREEN}Configuring AVD hardware properties...${NC}"
    
    # Update RAM
    sed -i "s/hw.ramSize=.*/hw.ramSize=$RAM/" "$AVD_CONFIG"
    
    # Update CPU cores
    sed -i "s/hw.cpu.ncore=.*/hw.cpu.ncore=$CORES/" "$AVD_CONFIG"
    
    # Update storage
    sed -i "s/disk.dataPartition.size=.*/disk.dataPartition.size=${STORAGE}M/" "$AVD_CONFIG"
    
    # Enable hardware acceleration
    if ! grep -q "hw.gpu.enabled" "$AVD_CONFIG"; then
        echo "hw.gpu.enabled=yes" >> "$AVD_CONFIG"
    else
        sed -i "s/hw.gpu.enabled=.*/hw.gpu.enabled=yes/" "$AVD_CONFIG"
    fi
    
    if ! grep -q "hw.gpu.mode" "$AVD_CONFIG"; then
        echo "hw.gpu.mode=host" >> "$AVD_CONFIG"
    else
        sed -i "s/hw.gpu.mode=.*/hw.gpu.mode=host/" "$AVD_CONFIG"
    fi
    
    # Enable hardware keyboard (CRITICAL for physical keyboard input)
    sed -i "s/hw.keyboard=no/hw.keyboard=yes/" "$AVD_CONFIG"
fi

echo -e "${GREEN}✓ AVD '$AVD_NAME' created successfully!${NC}"
echo ""
echo "To launch this emulator, run:"
echo "  run-emulator $AVD_NAME"
echo ""
echo "To list all AVDs, run:"
echo "  list-avds"
