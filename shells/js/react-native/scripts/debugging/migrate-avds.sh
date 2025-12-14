#!/usr/bin/env bash
set -e

OLD_AVD_HOME="$HOME/.android/avd"
NEW_AVD_HOME="$HOME/.config/.android/avd"

echo "Android AVD Migration Script"
echo "============================="
echo ""
echo "Old location: $OLD_AVD_HOME"
echo "New location: $NEW_AVD_HOME"
echo ""

# Check if old directory exists and has AVDs
if [ ! -d "$OLD_AVD_HOME" ]; then
    echo "✓ No AVDs found in old location. Nothing to migrate."
    exit 0
fi

AVD_COUNT=$(find "$OLD_AVD_HOME" -maxdepth 1 -name "*.avd" -type d 2>/dev/null | wc -l)

if [ "$AVD_COUNT" -eq 0 ]; then
    echo "✓ No AVDs found in old location. Nothing to migrate."
    exit 0
fi

echo "Found $AVD_COUNT AVD(s) to migrate:"
find "$OLD_AVD_HOME" -maxdepth 1 -name "*.avd" -type d -exec basename {} .avd \;
echo ""

read -p "Migrate AVDs to new location? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

# Create new directory if it doesn't exist
mkdir -p "$NEW_AVD_HOME"

# Move AVDs
echo ""
echo "Migrating AVDs..."
find "$OLD_AVD_HOME" -maxdepth 1 -name "*.avd" -type d | while read avd_dir; do
    avd_name=$(basename "$avd_dir")
    echo "  - $avd_name"
    mv "$avd_dir" "$NEW_AVD_HOME/"
done

# Move .ini files
find "$OLD_AVD_HOME" -maxdepth 1 -name "*.ini" -type f | while read ini_file; do
    ini_name=$(basename "$ini_file")
    echo "  - $ini_name"
    
    # Update path in .ini file
    sed -i "s|$OLD_AVD_HOME|$NEW_AVD_HOME|g" "$ini_file"
    
    mv "$ini_file" "$NEW_AVD_HOME/"
done

echo ""
echo "✓ Migration complete!"
echo ""
echo "AVDs are now in: $NEW_AVD_HOME"
echo ""
echo "You can now use: run-emulator <avd-name>"
