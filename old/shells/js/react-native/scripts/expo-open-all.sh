#!/usr/bin/env bash
# Open Expo app on all connected Android devices/emulators

set -e

DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | grep -v "^$" | wc -l)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "No Android devices connected"
    exit 1
fi

echo "Found $DEVICE_COUNT device(s):"
echo "$DEVICES"
echo ""

# Get package name from app.json or default
PACKAGE_NAME=${1:-com.anonymous.ideaflow}

for device in $DEVICES; do
    echo "Opening Expo on $device..."
    adb -s "$device" shell am start -n "$PACKAGE_NAME/.MainActivity" 2>/dev/null || \
    adb -s "$device" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 2>/dev/null || \
    echo "  ⚠ Could not open app on $device (app not installed?)"
done

echo ""
echo "✓ Opened on all devices"
