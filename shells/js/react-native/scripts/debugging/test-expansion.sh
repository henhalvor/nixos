#!/usr/bin/env bash
# Test script to verify ANDROID_AVD_HOME expansion works correctly

echo "Testing ANDROID_AVD_HOME expansion..."
echo ""
echo "Raw value: $ANDROID_AVD_HOME"
echo ""

# Test expansion (same method used in scripts)
AVD_HOME="${ANDROID_AVD_HOME/#\$HOME/$HOME}"
echo "Expanded value: $AVD_HOME"
echo ""

# Check if directory exists
if [ -d "$AVD_HOME" ]; then
    echo "✓ Directory exists"
    echo ""
    echo "AVDs found:"
    ls -d "$AVD_HOME"/*.avd 2>/dev/null | while read avd; do
        basename "$avd" .avd
    done
else
    echo "✗ Directory does not exist: $AVD_HOME"
    echo ""
    echo "Creating directory..."
    mkdir -p "$AVD_HOME"
    echo "✓ Created: $AVD_HOME"
fi
