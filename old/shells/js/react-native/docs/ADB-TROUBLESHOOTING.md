# ADB Connection Troubleshooting

## Symptom: Emulator Toolbar Buttons Not Working

**Working:**
- Settings (gear icon)
- Screenshot (camera icon)
- Extended controls (three dots)

**Not Working:**
- Home button (circle)
- Back button (arrow)
- Recent apps (square)
- Volume up/down

## Root Cause

These buttons send **ADB commands** to the emulator. If ADB can't connect, the buttons are non-functional.

The issue occurs because:
1. Emulator runs inside `steam-run` (FHS environment)
2. ADB server runs outside `steam-run`
3. Emulator can't find the ADB server

## Solution Applied

Updated `run-emulator` script to:
1. Start ADB server before launching emulator
2. Set `ADB_SERVER_SOCKET=tcp:127.0.0.1:5037` to connect to host ADB

## Testing

### 1. Copy Updated Flake
```bash
cd ~/code/idea-flow
cp ~/.dotfiles/shells/js/react-native/flake-standalone.nix ./flake.nix
direnv reload
```

### 2. Launch Emulator
```bash
run-emulator Pixel_8_API_35
```

**Expected output:**
```
Starting ADB server...
* daemon not running; starting now at tcp:5037
* daemon started successfully
Using steam-run for Hyprland compatibility...
```

### 3. Verify ADB Connection
```bash
# In separate terminal
adb devices
```

**Expected output:**
```
List of devices attached
emulator-5554   device
```

### 4. Test Toolbar Buttons

Click in emulator toolbar:
- ✓ Home button → should go to home screen
- ✓ Back button → should navigate back
- ✓ Volume up/down → should change volume

## Manual Verification

If buttons still don't work, test ADB manually:

```bash
# Home button
adb shell input keyevent KEYCODE_HOME

# Back button
adb shell input keyevent KEYCODE_BACK

# Volume up
adb shell input keyevent KEYCODE_VOLUME_UP
```

**If these work:** ADB is connected, toolbar issue is something else.  
**If these fail:** ADB connection issue.

## Common ADB Issues

### Issue: "No devices found"
```bash
adb kill-server
adb start-server
adb devices
```

### Issue: "Device offline"
```bash
adb reconnect
```

### Issue: "Unauthorized"
On emulator screen, tap "Allow" on USB debugging prompt.

### Issue: Multiple devices connected
Specify emulator:
```bash
adb -s emulator-5554 shell input keyevent KEYCODE_HOME
```

## Environment Variables

The emulator needs these to find ADB:

```bash
# Set in run-emulator script
export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037
```

Without this, emulator looks for ADB in steam-run's FHS environment (won't find it).

## Debugging

### Check if emulator can see ADB server:
```bash
# While emulator is running
netstat -tlnp | grep 5037
```

Should show:
```
tcp    0    0 127.0.0.1:5037    0.0.0.0:*    LISTEN    <pid>/adb
```

### Check emulator logs for ADB errors:
```bash
run-emulator Pixel_8_API_35 2>&1 | grep -i "adb\|unable to connect"
```

Should NOT show:
```
ERROR | Unable to connect to adb daemon on port: 5037
```

## Alternative: Use Keyboard Shortcuts

If ADB connection is flaky, use keyboard instead of toolbar:

| Button | Keyboard Shortcut |
|--------|------------------|
| Home | `Home` key |
| Back | `Esc` |
| Recent Apps | `F2` |
| Volume Up | `Ctrl + =` |
| Volume Down | `Ctrl + -` |
| Power | `F7` |

These work **without ADB** (sent directly to emulator).
