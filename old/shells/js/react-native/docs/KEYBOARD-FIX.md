# Keyboard Input Fix for Android Emulator

## Problem
Physical keyboard didn't work inside Android emulator screen (typing in apps, text fields, etc.), even though:
- Mouse/touch worked in emulator
- Keyboard worked in emulator toolbar (Qt UI)
- Keyboard worked in other X11 apps (xterm, etc.)

## Root Cause
AVD configuration had `hw.keyboard=no` which disabled hardware keyboard passthrough to the Android virtual device.

## Solution
Changed `hw.keyboard=no` to `hw.keyboard=yes` in AVD config files.

## What Was Fixed

### 1. Existing AVDs (Manual Fix)
```bash
# Phone emulator
sed -i 's/hw.keyboard=no/hw.keyboard=yes/' ~/.config/.android/avd/Pixel_8_API_35.avd/config.ini

# Tablet emulator  
sed -i 's/hw.keyboard=no/hw.keyboard=yes/' ~/.config/.android/avd/Pixel_Tablet_API_35.avd/config.ini
```

### 2. Future AVDs (Automatic Fix)
Updated `create-avd` script to automatically enable hardware keyboard when creating new AVDs.

**Files modified:**
- `shells/js/react-native/scripts/create-avd.sh`
- `shells/js/react-native/flake-standalone.nix` (embedded script)

**Added configuration:**
```bash
# Enable hardware keyboard (CRITICAL for physical keyboard input)
sed -i "s/hw.keyboard=no/hw.keyboard=yes/" "$AVD_CONFIG"
```

## Testing

### Before Fix
❌ Keyboard typing in Android apps → No response  
❌ Text input fields → Virtual keyboard only  
❌ Hardware keyboard shortcuts in Android → Not working  

### After Fix
✅ Keyboard typing in Android apps → Works!  
✅ Text input fields → Hardware keyboard works  
✅ Hardware keyboard shortcuts → Functional  
✅ Virtual keyboard still available as fallback  

## How to Test

1. **Close any running emulators**

2. **Launch emulator:**
   ```bash
   run-emulator Pixel_8_API_35
   ```

3. **Test keyboard:**
   - Open any app with text input (Settings search, Chrome, etc.)
   - Click in a text field
   - Type on your physical keyboard
   - Text should appear! ✓

## Verification Commands

**Check AVD keyboard config:**
```bash
grep hw.keyboard ~/.config/.android/avd/Pixel_8_API_35.avd/config.ini
```

**Expected output:**
```
hw.keyboard=yes
hw.keyboard.charmap=qwerty2
hw.keyboard.lid=yes
```

## Troubleshooting Investigation Results

### What We Checked
1. ✅ QT_IM_MODULE value (was empty, no input method framework running)
2. ✅ AVD config files (FOUND THE ISSUE: `hw.keyboard=no`)
3. ⏭️ Emulator keyboard flags (not needed after fix)
4. ⏭️ Window focus behavior (not the issue)
5. ⏭️ QEMU passthrough (not needed after fix)

### What We Learned
- Setting `QT_IM_MODULE=""` breaks Qt XCB platform plugin → Don't do this
- `hw.keyboard` setting is THE critical config for hardware keyboard
- AVD creation by default disables hardware keyboard (bad default!)
- Qt layer was working fine; issue was in AVD → Android layer

### Failed Attempts
❌ `export QT_IM_MODULE=""` → Broke display connection  
❌ `export XMODIFIERS=""` → Not needed  
❌ `export GTK_IM_MODULE=""` → Not needed  

### What Actually Worked
✅ `hw.keyboard=yes` in AVD config.ini

## Future Proofing

All new AVDs created with `create-avd` will automatically have hardware keyboard enabled.

**Example:**
```bash
# New AVD will have hw.keyboard=yes automatically
create-avd MyNewDevice_API_35
```

## Notes

- Virtual keyboard is still available in Android (Settings → System → Languages & input → On-screen keyboard)
- Hardware keyboard shortcuts (Ctrl+C, Ctrl+V, etc.) now work in Android apps
- This fix applies to ALL Android emulators, not just Expo/React Native

## Related Documentation

- Main guide: `README.md`
- Multi-device workflow: `MULTI-DEVICE-WORKFLOW.md`
- Hyprland fixes: `HYPRLAND-EMULATOR-FIX.md`
- ADB troubleshooting: `ADB-TROUBLESHOOTING.md`
