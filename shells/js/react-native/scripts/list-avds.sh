#!/usr/bin/env bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Android Virtual Devices (AVDs)                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get list of AVDs
AVD_LIST=$(avdmanager list avd 2>/dev/null)

if [ -z "$AVD_LIST" ] || ! echo "$AVD_LIST" | grep -q "Name:"; then
    echo -e "${YELLOW}No AVDs found.${NC}"
    echo ""
    echo "Create a new AVD with:"
    echo "  create-avd <avd-name>"
    echo ""
    echo "Example:"
    echo "  create-avd Pixel_8_API_35"
    exit 0
fi

# Parse and display AVD information
echo "$AVD_LIST" | awk '
BEGIN {
    RS="---------"
    FS="\n"
    count=0
}
/Name:/ {
    count++
    name = ""
    device = ""
    path = ""
    target = ""
    abi = ""
    
    for (i=1; i<=NF; i++) {
        if ($i ~ /Name:/) {
            gsub(/^[ \t]+Name: /, "", $i)
            name = $i
        }
        if ($i ~ /Device:/) {
            gsub(/^[ \t]+Device: /, "", $i)
            device = $i
        }
        if ($i ~ /Path:/) {
            gsub(/^[ \t]+Path: /, "", $i)
            path = $i
        }
        if ($i ~ /Target:/) {
            gsub(/^[ \t]+Target: /, "", $i)
            target = $i
        }
        if ($i ~ /ABI:/) {
            gsub(/^[ \t]+ABI: /, "", $i)
            abi = $i
        }
    }
    
    if (name != "") {
        print "\033[0;32m● " name "\033[0m"
        if (device != "") print "  Device:  " device
        if (target != "") print "  Target:  " target
        if (abi != "") print "  ABI:     " abi
        print ""
    }
}
END {
    if (count > 0) {
        print "\033[0;36mTotal AVDs: " count "\033[0m"
    }
}
'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Running Emulators                             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for running emulators
RUNNING=$(adb devices 2>/dev/null | grep "emulator-" | awk '{print $1}')

if [ -z "$RUNNING" ]; then
    echo -e "${YELLOW}No emulators currently running.${NC}"
else
    echo -e "${GREEN}Running emulators:${NC}"
    echo "$RUNNING" | while read -r emulator; do
        echo -e "  ${GREEN}●${NC} $emulator"
    done
fi

echo ""
echo -e "${CYAN}Commands:${NC}"
echo "  create-avd <name>    - Create a new AVD"
echo "  run-emulator <name>  - Launch an emulator"
echo "  adb devices          - Show all connected devices (physical + emulators)"
echo ""
