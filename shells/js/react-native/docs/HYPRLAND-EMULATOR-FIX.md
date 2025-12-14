# Android Emulator Toolbar Fix for Hyprland

## Issue: Side Panel Buttons Not Working

The Android Emulator's toolbar (home, back, volume buttons) doesn't respond to clicks on Hyprland/tiling WMs.

### Root Cause
The emulator toolbar is a separate Qt window that gets tiled incorrectly, preventing mouse input from reaching it.

### Solution

#### 1. Apply Hyprland Window Rules (Already Done)
Window rules added to `home/modules/window-manager/hyprland.nix`:
```nix
"float, title:^(Extended controls)$"
"pin, title:^(Extended controls)$"  
"stayfocused, title:^(Extended controls)$"
```

#### 2. Rebuild Home Manager
```bash
home-manager switch --flake ~/.dotfiles
```

**OR** if using NixOS system-level config:
```bash
sudo nixos-rebuild switch
```

#### 3. Reload Hyprland Config
```bash
hyprctl reload
```

#### 4. Restart Emulator
Close the emulator and relaunch:
```bash
run-emulator Pixel_8_API_35
```

---

## Alternative Workarounds (If Rules Don't Help)

### Option A: Use Hardware Keyboard Shortcuts
Instead of clicking toolbar buttons, use keyboard:
- **Back**: `Esc`
- **Home**: `Home` key
- **App Switcher**: `F2`
- **Volume Up**: `Ctrl + =`
- **Volume Down**: `Ctrl + -`
- **Power**: `F7`

### Option B: Extended Controls Window
Open the full emulator controls panel:
1. Click the **`...`** (three dots) in toolbar
2. Or press `Ctrl + Shift + P`
3. This opens a dedicated controls window with:
   - Location/GPS
   - Phone calls
   - Battery level
   - Camera
   - All hardware buttons

### Option C: Use ADB Commands
```bash
# Home button
adb shell input keyevent KEYCODE_HOME

# Back button  
adb shell input keyevent KEYCODE_BACK

# Volume up
adb shell input keyevent KEYCODE_VOLUME_UP

# Volume down
adb shell input keyevent KEYCODE_VOLUME_DOWN

# Power button
adb shell input keyevent KEYCODE_POWER
```

### Option D: Disable Toolbar Entirely
Run emulator without toolbar:
```bash
run-emulator Pixel_8_API_35 &
```
Then use keyboard shortcuts or ADB commands.

---

## Debugging

### Check if window rules are applied:
```bash
# While emulator is running
hyprctl clients | grep -A 20 "emulator\|qemu\|Android"
```

Look for:
- `floating: 1` (should be true)
- `class:` (note the exact class name)
- `title:` (note the exact title)

### Update rules if class/title differs:
If the actual class/title doesn't match, update the window rules:

```bash
# Find exact window info
hyprctl clients | grep -B 2 -A 15 "Android\|Emulator"
```

Then adjust rules in `hyprland.nix` accordingly.

---

## Performance Tips

### Reduce Emulator Overhead
```bash
# Use software rendering (slower but more compatible)
run-emulator --gpu swiftshader_indirect Pixel_8_API_35

# Cold boot (skip snapshot loading)
run-emulator --cold-boot Pixel_8_API_35
```

### Check GPU Acceleration
```bash
# Should show "host" mode
run-emulator Pixel_8_API_35 2>&1 | grep "GPU mode"
```

---

## Known Working Setup

- **OS**: NixOS with Hyprland
- **GPU**: NVIDIA RTX 3050 (proprietary drivers)
- **Emulator**: Android 35 (API 35)
- **Wrapper**: steam-run (for FHS compatibility)
- **Window rules**: Float + pin + stayfocused

**Expected behavior after fixes:**
- Emulator window floats (not tiled)
- Toolbar responds to clicks
- Extended controls window opens correctly
- Keyboard shortcuts work
