# React Native Android - Quick Start

## Setup (One-Time)

### 1. Global NixOS Setup
```bash
sudo nixos-rebuild switch
# Logout/login to apply kvm & adbusers groups
```

### 2. Copy Flake to Your Project
```bash
cd ~/code/your-react-native-project
cp ~/.dotfiles/shells/js/react-native/flake-standalone.nix ./flake.nix
echo "use flake" > .envrc
direnv allow
```

## Daily Workflow

### Create AVD (First Time Only)
```bash
create-avd Pixel_8_API_35
```

### Launch Emulator
```bash
# Terminal 1
run-emulator Pixel_8_API_35
```

### Run App
```bash
# Terminal 2
yarn expo run:android
```

## Common Commands

| Command | Description |
|---------|-------------|
| `list-avds` | Show all AVDs |
| `create-avd <name>` | Create new AVD |
| `create-avd -d pixel_tablet <name>` | Create tablet AVD |
| `create-avd --playstore <name>` | Create AVD with Play Store |
| `run-emulator <name>` | Launch emulator |
| `run-emulator --cold-boot <name>` | Launch with cold boot |
| `adb devices` | List connected devices |
| `android-studio` | Open Android Studio |

## Troubleshooting

### Emulator slow or won't start
```bash
groups | grep kvm  # Should show "kvm"
# If missing: sudo nixos-rebuild switch, then logout/login
```

### ADB not seeing emulator
```bash
adb kill-server && adb start-server
```

## Multi-Emulator Setup

**Terminal 1:** `run-emulator Pixel_8_API_35`  
**Terminal 2:** `run-emulator Pixel_Tablet_API_35`  
**Terminal 3:** `yarn expo run:android`

Choose device when prompted!
