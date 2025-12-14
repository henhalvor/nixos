# React Native Android Development Environment

Nix flake for React Native development with Android SDK, emulator support, and
Hyprland compatibility.

## Two Versions Available

### 1. `flake.nix` - Development/Template Version

- Uses external script files (`scripts/*.sh`)
- Best for: Editing/maintaining in `.dotfiles`
- **Requires**: Scripts directory when copying to projects

### 2. `flake-standalone.nix` - Portable/Project Version ⭐ **RECOMMENDED**

- Self-contained (scripts embedded in flake)
- Best for: Copying to individual React Native projects
- **No external dependencies** - just copy the single file

## Usage in Projects

### Option A: Copy Standalone Flake (Recommended)

```bash
# In your React Native project root
cp ~/.dotfiles/shells/js/react-native/flake-standalone.nix ./flake.nix

# Create .envrc for automatic dev shell activation
echo "use flake" > .envrc
direnv allow

# Now when you cd into this directory, dev shell auto-activates!
```

### Option B: Reference from .dotfiles

```bash
# In your React Native project
echo "use flake ~/.dotfiles/shells/js/react-native#" > .envrc
direnv allow
```

## Quick Start

### 1. Enter Development Shell

**If using standalone flake in project:**

```bash
nix develop
```

**If using direnv (auto-activation):**

```bash
cd your-project  # Dev shell activates automatically
```

### 2. Create an AVD (Android Virtual Device)

```bash
create-avd Pixel_8_API_35
```

**Options:**

- `-r, --ram <MB>` - RAM allocation (default: 4096MB)
- `-c, --cores <N>` - CPU cores (default: 4)
- `-d, --device <profile>` - Device profile (default: pixel_8)
- `-p, --playstore` - Use Google Play Store system image
- `--help` - Show full help

**Examples:**

```bash
# Create tablet emulator with custom RAM
create-avd -d pixel_tablet -r 2048 Tablet_API_35

# Create emulator with Play Store
create-avd --playstore Pixel_8_Play_API_35
```

### 3. Launch Emulator

```bash
run-emulator Pixel_8_API_35
```

**Options:**

- `-w, --wipe-data` - Wipe user data before starting
- `-c, --cold-boot` - Force cold boot (ignore snapshots)
- `-g, --gpu <mode>` - GPU mode: host, swiftshader_indirect (default: host)
- `--help` - Show full help

**Examples:**

```bash
# Launch with cold boot
run-emulator --cold-boot Pixel_8_API_35

# Launch with software rendering (more compatible, slower)
run-emulator --gpu swiftshader_indirect Pixel_8_API_35
```

### 4. List AVDs

```bash
list-avds
```

### 5. Delete AVDs

How to Delete an AVD Method 1: Using avdmanager (Recommended) avdmanager delete
avd -n Pixel_8_API_35 This cleanly removes both the .avd directory and .ini
file. Method 2: Manual Deletion

### 6. Misc

AVD Storage Space Each AVD typically uses:

- Base system image: ~1-2GB (shared across AVDs, stored in Android SDK)
- AVD instance: ~2-8GB depending on:
  - Storage size configured (default: 8GB)
  - Installed apps
  - User data
  - Snapshots (can be large!) To check: du -sh
    ~/.config/.android/avd/Pixel_8_API_35.avd du -sh
    ~/.config/.android/avd/Pixel_Tablet_API_35.avd

---
Clean Up Snapshots (Frees Space)
Snapshots can grow large over time. To remove them:
# Remove snapshots for specific AVD
rm -rf ~/.config/.android/avd/Pixel_8_API_35.avd/snapshots/*
Or launch with --cold-boot to ignore snapshots:
run-emulator --cold-boot Pixel_8_API_35
---

## System Images Location The shared Android system images (base OS) are in: /nix/store/<hash>-android-sdk-env/share/android-sdk/system-images/ Example: /nix/store/4wjq9kmrjhgn4l64axsbn73ii3nb5ig1-android-sdk-env/share/android-sdk/system-images/android-35/google_apis/x86_64/ These are shared by all AVDs using the same API level/image type.

Quick Reference

| What            | Location                                                      |
| --------------- | ------------------------------------------------------------- |
| AVD instances   | ~/.config/.android/avd/                                       |
| AVD configs     | ~/.config/.android/avd/*.ini                                  |
| System images   | /nix/store/*-android-sdk-env/share/android-sdk/system-images/ |
| Emulator binary | /nix/store/_-emulator-_/emulator/emulator                     |
| ADB binary      | In android-sdk/platform-tools/adb                             |

# Delete AVD directory

rm -rf ~/.config/.android/avd/Pixel_8_API_35.avd

# Delete AVD config file

rm ~/.config/.android/avd/Pixel_8_API_35.ini Method 3: Using list-avds +
avdmanager

# First, see what AVDs exist

list-avds

# Then delete specific one

## avdmanager delete avd -n <avd-name>

Shows all created AVDs and currently running emulators.

## React Native Commands

### Run on Device/Emulator

```bash
yarn expo run:android
```

### Start Metro Bundler

```bash
yarn expo start
```

### Connect Physical Device

```bash
adb devices
```

## Multi-Emulator Support

Run up to 2 emulators simultaneously (configured for 4GB RAM each):

**Terminal 1:**

```bash
run-emulator Pixel_8_API_35
```

**Terminal 2:**

```bash
run-emulator Pixel_Tablet_API_35
```

**Open Expo app on all devices:**

```bash
expo-open-all
```

See [MULTI-DEVICE-WORKFLOW.md](./MULTI-DEVICE-WORKFLOW.md) for complete guide.

## Android Studio (GUI)

Launch Android Studio for GUI-based AVD management:

```bash
android-studio
```

AVDs created in Android Studio and CLI are interchangeable - both use
`$ANDROID_AVD_HOME`.

## Environment Variables

Set automatically when entering `nix develop`:

- `ANDROID_SDK_ROOT` - Android SDK location
- `ANDROID_AVD_HOME` - AVD storage (`~/.config/.android/avd`)
- `JAVA_HOME` - Java 17 (Corretto)
- `GRADLE_OPTS` - aapt2 override for NixOS compatibility

## Hyprland Compatibility

Emulators run via `steam-run` wrapper for FHS compatibility on NixOS tiling WMs.

Window rules auto-configured in `home/modules/window-manager/hyprland.nix`:

- Emulator windows force floating
- Default size: 400x800 (phone aspect ratio)

## Troubleshooting

### "No such file or directory: scripts/create-avd.sh"

You copied `flake.nix` instead of `flake-standalone.nix`.

**Solution:**

```bash
# Replace with standalone version
cp ~/.dotfiles/shells/js/react-native/flake-standalone.nix ./flake.nix
```

### Emulator won't start

```bash
# Check KVM access (run outside nix develop)
groups | grep kvm

# If missing, rebuild NixOS:
sudo nixos-rebuild switch
# Then logout/login to apply group membership
```

### Slow emulator performance

```bash
# Verify hardware acceleration
run-emulator --cold-boot YourAVD

# Check CPU usage (should be <800% with KVM)
htop
```

### ADB not detecting emulator

```bash
# Restart adb server
adb kill-server
adb start-server
adb devices
```

### Build errors with gradle

Already configured via `GRADLE_OPTS` - aapt2 override points to NixOS-compatible
version.

If issues persist:

```bash
./gradlew --stop
./gradlew clean
yarn expo run:android
```

## System Images

Available in this flake:

- `android-35` with `google_apis` (lightweight, no Play Store)
- `android-35` with `google_apis_playstore` (full Play Store support)

Both are x86_64 (faster on x86 hosts with KVM).

## File Structure

```
shells/js/react-native/
├── flake.nix              # Template version (uses external scripts)
├── flake-standalone.nix   # Portable version (self-contained) ⭐
├── flake.lock             # Locked dependencies
├── scripts/
│   ├── create-avd.sh      # AVD creation wrapper
│   ├── run-emulator.sh    # Emulator launcher
│   └── list-avds.sh       # AVD listing utility
└── README.md              # This file
```

## Global NixOS Configuration

Android support enabled globally via `nixos/modules/android.nix`:

- `programs.adb.enable = true` - ADB + udev rules
- User added to `kvm` and `adbusers` groups

Imported in:

- `systems/workstation/configuration.nix`
- `systems/lenovo-yoga-pro-7/configuration.nix`

## Recommended Workflow

1. **Global setup** (one-time):
   ```bash
   sudo nixos-rebuild switch  # Enables adb, kvm
   # Logout/login to apply groups
   ```

2. **Per-project setup**:
   ```bash
   cd ~/code/my-react-native-app
   cp ~/.dotfiles/shells/js/react-native/flake-standalone.nix ./flake.nix
   echo "use flake" > .envrc
   direnv allow
   ```

3. **Development**:
   ```bash
   cd ~/code/my-react-native-app  # Auto-enters dev shell
   create-avd Pixel_8_API_35      # First time only
   run-emulator Pixel_8_API_35    # In separate terminal
   yarn expo run:android          # Build & run
   ```

4. **AVDs are shared** across all projects (stored in `~/.config/.android/avd`),
   so you only need to create them once!
