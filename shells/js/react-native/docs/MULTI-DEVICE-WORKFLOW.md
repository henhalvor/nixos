# Multi-Device React Native Development Workflow

Develop simultaneously on phone + tablet emulators with instant hot reload.

## Setup (One-Time)

### 1. Create Tablet Emulator
```bash
create-avd -d pixel_tablet Pixel_Tablet_API_35
```

### 2. Verify AVDs
```bash
list-avds
```

Should show:
- Pixel_8_API_35 (phone)
- Pixel_Tablet_API_35 (tablet)

---

## Daily Development Workflow

### Terminal Layout

Open 3 terminals:

```
┌─────────────────┬─────────────────┐
│  Terminal 1     │  Terminal 2     │
│  Phone Emulator │  Tablet Emulator│
├─────────────────┴─────────────────┤
│  Terminal 3: Dev Server           │
└───────────────────────────────────┘
```

### Terminal 1: Launch Phone Emulator
```bash
run-emulator Pixel_8_API_35
```

### Terminal 2: Launch Tablet Emulator
```bash
run-emulator Pixel_Tablet_API_35
```

### Terminal 3: Verify Both Connected
```bash
adb devices
```

**Expected output:**
```
List of devices attached
emulator-5554   device
emulator-5556   device
```

---

## First Time / After Adding Dependencies

### Option A: Install on Both (Automatic)

```bash
yarn android
```

Expo will prompt which device to use:
- Select **first device** (emulator-5554)
- Wait for build & install
- Then run again and select **second device** (emulator-5556)

### Option B: Build Once, Install on Both

```bash
# Build and install on first device
yarn android

# Install same APK on second device
adb -s emulator-5556 install -r android/app/build/outputs/apk/debug/app-debug.apk
```

---

## Development with Hot Reload

### Start Dev Server
```bash
yarn start
```

### Open on Both Devices

**Method 1: Expo CLI (Interactive)**

In Expo dev server, press:
1. `a` → Opens on first device (emulator-5554)
2. `a` again → Opens on second device (emulator-5556)

Or:
- `shift+a` → Select specific device

**Method 2: Auto-Open All (Recommended)**

```bash
# After yarn start, in separate terminal:
expo-open-all
```

Or specify package name:
```bash
expo-open-all com.yourcompany.yourapp
```

**Method 3: Manual via ADB**

```bash
# Get your package name from app.json
PACKAGE=com.anonymous.ideaflow

# Open on both devices
adb -s emulator-5554 shell monkey -p $PACKAGE -c android.intent.category.LAUNCHER 1
adb -s emulator-5556 shell monkey -p $PACKAGE -c android.intent.category.LAUNCHER 1
```

---

## Hot Reload Behavior

**Changes auto-update on BOTH devices simultaneously:**
- ✅ JS/TSX changes → Instant hot reload
- ✅ Style changes → Instant hot reload
- ✅ Component changes → Instant hot reload
- ⚠️ Native code changes → Requires rebuild (`yarn android`)
- ⚠️ New dependencies → Requires rebuild (`yarn android`)

**To trigger reload manually:**
- Press `r` in Expo CLI
- Or shake device/emulator (Ctrl+M in emulator)

---

## Troubleshooting

### Device Not Listed in Expo

**Check ADB connection:**
```bash
adb devices
```

**Restart ADB if needed:**
```bash
adb kill-server
adb start-server
adb devices
```

### App Not Updating on One Device

**Reload manually:**
```bash
# Press 'r' in Expo CLI, or:
adb -s emulator-5556 shell input keyevent KEYCODE_MENU
# Then tap "Reload"
```

### Different Behavior on Phone vs Tablet

**Check screen dimensions:**
```bash
# Phone
adb -s emulator-5554 shell wm size

# Tablet
adb -s emulator-5556 shell wm size
```

**Test responsive layouts:**
- Phone: 1080x2400 (portrait)
- Tablet: 2560x1600 (landscape)

### Emulator Slow with Both Running

**Reduce resources per emulator:**
```bash
# Create lighter emulators
create-avd -r 2048 -c 2 Pixel_8_Light_API_35
create-avd -r 2048 -c 2 -d pixel_tablet Pixel_Tablet_Light_API_35
```

**Or close one when not needed:**
- Develop on phone primarily
- Open tablet only for layout testing

---

## Advanced: Specific Device Testing

### Install on Specific Device Only

```bash
# Build for device
yarn android --device emulator-5556
```

### Run ADB Commands on Specific Device

```bash
# Screenshot from tablet
adb -s emulator-5556 exec-out screencap -p > tablet-screenshot.png

# Clear app data on phone
adb -s emulator-5554 shell pm clear com.anonymous.ideaflow

# Check logs from specific device
adb -s emulator-5554 logcat | grep ReactNative
```

### Switch Between Devices in Expo CLI

While `yarn start` is running:
- `shift+a` → Shows device picker
- `d` → Open dev menu on selected device
- `r` → Reload on all devices

---

## Recommended Workflow Summary

**Setup:**
```bash
# Terminal 1
run-emulator Pixel_8_API_35

# Terminal 2  
run-emulator Pixel_Tablet_API_35

# Terminal 3
yarn start
```

**Daily Development:**
1. Start both emulators
2. `yarn start` in Terminal 3
3. Press `a` twice in Expo CLI (or use `expo-open-all`)
4. Make code changes → Hot reload on both devices ✨
5. Test layouts on phone vs tablet simultaneously

**After Adding Dependencies:**
```bash
yarn android  # Builds and installs on first device
# Then manually install on second or run yarn android again
```

**Quick Device Control:**
```bash
expo-open-all          # Open app on all devices
emu-buttons home       # Home button via ADB
list-avds              # List all emulators
```

---

## Performance Tips

**Optimize for multi-device development:**
- Use `--no-dev` for production-like performance testing
- Profile on phone (slower device) first
- Test tablet-specific layouts separately
- Close unused emulators to free resources

**System resources with 2 emulators:**
- RAM: ~8GB (4GB each)
- CPU: ~8 cores utilized
- Works best on systems with 16GB+ RAM
