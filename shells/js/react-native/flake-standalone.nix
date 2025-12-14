{
  description = "React Native development environment with Android SDK and emulator support (standalone/portable)";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?ref=nixos-unstable";
    };
    android.url = "github:tadfisher/android-nixpkgs?rev=a21442ddcdf359be82220a6e82eff7432d9a4190";
    android.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";

      config = {
        permittedInsecurePackages = [
          "gradle-7.6.6"
        ];
        allowUnfree = true;
      };
    };

    # Embedded scripts (no external file dependencies)
    createAvdScript = pkgs.writeScriptBin "create-avd" ''
      #!/usr/bin/env bash
      set -e

      DEFAULT_RAM=4096
      DEFAULT_CORES=4
      DEFAULT_STORAGE=8192
      DEFAULT_DEVICE="pixel_8"
      DEFAULT_API_LEVEL=35

      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m'

      usage() {
          cat <<EOF
      Usage: create-avd [OPTIONS] <avd-name>

      Create a new Android Virtual Device (AVD) for development.

      Arguments:
        avd-name              Name for the AVD (e.g., Pixel_8_API_35)

      Options:
        -d, --device         Device profile (default: pixel_8)
        -r, --ram            RAM in MB (default: 4096)
        -c, --cores          CPU cores (default: 4)
        -s, --storage        Storage in MB (default: 8192)
        -a, --api-level      Android API level (default: 35)
        -p, --playstore      Use Google Play Store image (default: false)
        -h, --help           Show this help message

      Examples:
        create-avd Pixel_8_API_35
        create-avd -r 2048 -c 2 Tablet_API_35
        create-avd --playstore Pixel_8_Play_API_35
      EOF
      }

      RAM=$DEFAULT_RAM
      CORES=$DEFAULT_CORES
      STORAGE=$DEFAULT_STORAGE
      DEVICE=$DEFAULT_DEVICE
      API_LEVEL=$DEFAULT_API_LEVEL
      USE_PLAYSTORE=false
      AVD_NAME=""

      while [[ $# -gt 0 ]]; do
          case $1 in
              -d|--device) DEVICE="$2"; shift 2 ;;
              -r|--ram) RAM="$2"; shift 2 ;;
              -c|--cores) CORES="$2"; shift 2 ;;
              -s|--storage) STORAGE="$2"; shift 2 ;;
              -a|--api-level) API_LEVEL="$2"; shift 2 ;;
              -p|--playstore) USE_PLAYSTORE=true; shift ;;
              -h|--help) usage; exit 0 ;;
              -*) echo -e "''${RED}Unknown option: $1''${NC}"; usage; exit 1 ;;
              *) AVD_NAME="$1"; shift ;;
          esac
      done

      if [ -z "$AVD_NAME" ]; then
          echo -e "''${RED}Error: AVD name is required''${NC}"
          usage
          exit 1
      fi

      if [ "$USE_PLAYSTORE" = true ]; then
          SYSTEM_IMAGE="system-images;android-''${API_LEVEL};google_apis_playstore;x86_64"
          IMAGE_TYPE="google_apis_playstore"
      else
          SYSTEM_IMAGE="system-images;android-''${API_LEVEL};google_apis;x86_64"
          IMAGE_TYPE="google_apis"
      fi

      echo -e "''${GREEN}Creating AVD: $AVD_NAME''${NC}"
      echo "  Device: $DEVICE"
      echo "  API Level: $API_LEVEL"
      echo "  Image Type: $IMAGE_TYPE"
      echo "  RAM: ''${RAM}MB"
      echo "  CPU Cores: $CORES"
      echo "  Storage: ''${STORAGE}MB"
      echo ""

      if [ -d "$ANDROID_AVD_HOME/$AVD_NAME.avd" ]; then
          echo -e "''${YELLOW}Warning: AVD '$AVD_NAME' already exists''${NC}"
          read -p "Overwrite? (y/N): " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
              echo "Aborted."
              exit 0
          fi
          avdmanager delete avd -n "$AVD_NAME"
      fi

      echo -e "''${GREEN}Creating AVD with avdmanager...''${NC}"
      echo "no" | avdmanager create avd \
          -k "$SYSTEM_IMAGE" \
          -n "$AVD_NAME" \
          -d "$DEVICE" \
          --force

      AVD_CONFIG="$ANDROID_AVD_HOME/$AVD_NAME.avd/config.ini"

      if [ -f "$AVD_CONFIG" ]; then
          echo -e "''${GREEN}Configuring AVD hardware properties...''${NC}"

          sed -i "s/hw.ramSize=.*/hw.ramSize=$RAM/" "$AVD_CONFIG"
          sed -i "s/hw.cpu.ncore=.*/hw.cpu.ncore=$CORES/" "$AVD_CONFIG"
          sed -i "s/disk.dataPartition.size=.*/disk.dataPartition.size=''${STORAGE}M/" "$AVD_CONFIG"

          if ! grep -q "hw.gpu.enabled" "$AVD_CONFIG"; then
              echo "hw.gpu.enabled=yes" >> "$AVD_CONFIG"
          else
              sed -i "s/hw.gpu.enabled=.*/hw.gpu.enabled=yes/" "$AVD_CONFIG"
          fi

          if ! grep -q "hw.gpu.mode" "$AVD_CONFIG"; then
              echo "hw.gpu.mode=host" >> "$AVD_CONFIG"
          else
              sed -i "s/hw.gpu.mode=.*/hw.gpu.mode=host/" "$AVD_CONFIG"
          fi

          # Enable hardware keyboard (CRITICAL for physical keyboard input)
          sed -i "s/hw.keyboard=no/hw.keyboard=yes/" "$AVD_CONFIG"
      fi

      echo -e "''${GREEN}✓ AVD '$AVD_NAME' created successfully!''${NC}"
      echo ""
      echo "To launch this emulator, run:"
      echo "  run-emulator $AVD_NAME"
      echo ""
      echo "To list all AVDs, run:"
      echo "  list-avds"
    '';

    expoOpenAllScript = pkgs.writeScriptBin "expo-open-all" ''
      #!/usr/bin/env bash
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

      PACKAGE_NAME=''${1:-com.anonymous.ideaflow}

      for device in $DEVICES; do
          echo "Opening Expo on $device..."
          adb -s "$device" shell am start -n "$PACKAGE_NAME/.MainActivity" 2>/dev/null || \
          adb -s "$device" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 2>/dev/null || \
          echo "  ⚠ Could not open app on $device (app not installed?)"
      done

      echo ""
      echo "✓ Opened on all devices"
    '';

    emuButtonsScript = pkgs.writeScriptBin "emu-buttons" ''
      #!/usr/bin/env bash
      case "$1" in
          home|h)
              adb shell input keyevent KEYCODE_HOME
              echo "Home"
              ;;
          back|b)
              adb shell input keyevent KEYCODE_BACK
              echo "Back"
              ;;
          recent|r)
              adb shell input keyevent KEYCODE_APP_SWITCH
              echo "Recent Apps"
              ;;
          vol-up|vu)
              adb shell input keyevent KEYCODE_VOLUME_UP
              echo "Volume Up"
              ;;
          vol-down|vd)
              adb shell input keyevent KEYCODE_VOLUME_DOWN
              echo "Volume Down"
              ;;
          power|p)
              adb shell input keyevent KEYCODE_POWER
              echo "Power"
              ;;
          menu|m)
              adb shell input keyevent KEYCODE_MENU
              echo "Menu"
              ;;
          *)
              cat <<EOF
      Usage: emu-buttons <command>

      Commands:
        home, h         - Home button
        back, b         - Back button
        recent, r       - Recent apps
        vol-up, vu      - Volume up
        vol-down, vd    - Volume down
        power, p        - Power button
        menu, m         - Menu button

      Examples:
        emu-buttons home
        emu-buttons b
        emu-buttons vu
      EOF
              ;;
      esac
    '';

    runEmulatorScript = pkgs.writeScriptBin "run-emulator" ''
      #!/usr/bin/env bash
      set -e

      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      NC='\033[0m'

      usage() {
          cat <<EOF
      Usage: run-emulator [OPTIONS] [avd-name]

      Launch an Android emulator with hardware acceleration and Hyprland compatibility.

      Arguments:
        avd-name              Name of the AVD to launch (if not provided, lists available AVDs)

      Options:
        -w, --wipe-data       Wipe user data before starting
        -c, --cold-boot       Force cold boot (ignore snapshots)
        -g, --gpu <mode>      GPU mode: host, swiftshader_indirect (default: host)
        -p, --port <port>     Console port number (default: auto)
        -h, --help            Show this help message

      Examples:
        run-emulator Pixel_8_API_35
        run-emulator --wipe-data Pixel_8_API_35
        run-emulator --cold-boot --gpu swiftshader_indirect Test_Device
      EOF
      }

      list_avds() {
          echo -e "''${BLUE}Available AVDs:''${NC}"
          avdmanager list avd | grep "Name:" | sed 's/    Name: /  - /'
          echo ""
          echo "Run 'run-emulator <avd-name>' to launch an emulator"
      }

      WIPE_DATA=false
      COLD_BOOT=false
      GPU_MODE="host"
      PORT=""
      AVD_NAME=""

      while [[ $# -gt 0 ]]; do
          case $1 in
              -w|--wipe-data) WIPE_DATA=true; shift ;;
              -c|--cold-boot) COLD_BOOT=true; shift ;;
              -g|--gpu) GPU_MODE="$2"; shift 2 ;;
              -p|--port) PORT="$2"; shift 2 ;;
              -h|--help) usage; exit 0 ;;
              -*) echo -e "''${RED}Unknown option: $1''${NC}"; usage; exit 1 ;;
              *) AVD_NAME="$1"; shift ;;
          esac
      done

      if [ -z "$AVD_NAME" ]; then
          list_avds
          exit 0
      fi

      if [ ! -d "$ANDROID_AVD_HOME/$AVD_NAME.avd" ]; then
          echo -e "''${RED}Error: AVD '$AVD_NAME' not found''${NC}"
          echo ""
          list_avds
          exit 1
      fi

      EMULATOR_CMD="$ANDROID_SDK_ROOT/emulator/emulator"
      EMULATOR_ARGS="-avd $AVD_NAME"
      EMULATOR_ARGS="$EMULATOR_ARGS -gpu $GPU_MODE"
      EMULATOR_ARGS="$EMULATOR_ARGS -no-metrics -no-audio"

      if [ "$GPU_MODE" = "host" ]; then
          EMULATOR_ARGS="$EMULATOR_ARGS -feature -Vulkan"
      fi

      [ "$WIPE_DATA" = true ] && EMULATOR_ARGS="$EMULATOR_ARGS -wipe-data"
      [ "$COLD_BOOT" = true ] && EMULATOR_ARGS="$EMULATOR_ARGS -no-snapshot-load"
      [ -n "$PORT" ] && EMULATOR_ARGS="$EMULATOR_ARGS -port $PORT"

      echo -e "''${GREEN}Launching emulator: $AVD_NAME''${NC}"
      echo "  GPU Mode: $GPU_MODE"
      [ "$WIPE_DATA" = true ] && echo "  Wipe Data: enabled"
      [ "$COLD_BOOT" = true ] && echo "  Cold Boot: enabled"
      [ -n "$PORT" ] && echo "  Port: $PORT"
      echo ""
      echo -e "''${YELLOW}Starting ADB server...''${NC}"

      # Ensure ADB server is running
      adb start-server 2>/dev/null || true

      echo -e "''${YELLOW}Using steam-run for Hyprland compatibility...''${NC}"
      echo ""

      # Set ADB_SERVER_SOCKET to use host ADB server from within steam-run
      export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037

      # Force X11 backend for Qt (better toolbar button compatibility on Wayland/Hyprland)
      export QT_QPA_PLATFORM=xcb

      # Disable Qt Wayland to prevent input issues
      export QT_QPA_PLATFORMTHEME=""

      exec ${pkgs.steam-run}/bin/steam-run $EMULATOR_CMD $EMULATOR_ARGS
    '';

    listAvdsScript = pkgs.writeScriptBin "list-avds" ''
      #!/usr/bin/env bash

      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      CYAN='\033[0;36m'
      NC='\033[0m'

      echo -e "''${BLUE}╔════════════════════════════════════════════════════════════════╗''${NC}"
      echo -e "''${BLUE}║            Android Virtual Devices (AVDs)                      ║''${NC}"
      echo -e "''${BLUE}╚════════════════════════════════════════════════════════════════╝''${NC}"
      echo ""

      AVD_LIST=$(avdmanager list avd 2>/dev/null)

      if [ -z "$AVD_LIST" ] || ! echo "$AVD_LIST" | grep -q "Name:"; then
          echo -e "''${YELLOW}No AVDs found.''${NC}"
          echo ""
          echo "Create a new AVD with:"
          echo "  create-avd <avd-name>"
          echo ""
          echo "Example:"
          echo "  create-avd Pixel_8_API_35"
          exit 0
      fi

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
      echo -e "''${BLUE}╔════════════════════════════════════════════════════════════════╗''${NC}"
      echo -e "''${BLUE}║                  Running Emulators                             ║''${NC}"
      echo -e "''${BLUE}╚════════════════════════════════════════════════════════════════╝''${NC}"
      echo ""

      RUNNING=$(adb devices 2>/dev/null | grep "emulator-" | awk '{print $1}')

      if [ -z "$RUNNING" ]; then
          echo -e "''${YELLOW}No emulators currently running.''${NC}"
      else
          echo -e "''${GREEN}Running emulators:''${NC}"
          echo "$RUNNING" | while read -r emulator; do
              echo -e "  ''${GREEN}●''${NC} $emulator"
          done
      fi

      echo ""
      echo -e "''${CYAN}Commands:''${NC}"
      echo "  create-avd <name>    - Create a new AVD"
      echo "  run-emulator <name>  - Launch an emulator"
      echo "  adb devices          - Show all connected devices (physical + emulators)"
      echo ""
    '';
  in {
    packages.x86_64-linux.android-sdk =
      inputs.android.sdk.x86_64-linux
      (sdkPkgs: [
        sdkPkgs.cmdline-tools-latest
        sdkPkgs.cmake-3-22-1
        sdkPkgs.build-tools-34-0-0
        sdkPkgs.build-tools-35-0-0
        sdkPkgs.platform-tools
        sdkPkgs.platforms-android-35
        sdkPkgs.emulator
        sdkPkgs.system-images-android-35-google-apis-x86-64
        sdkPkgs.system-images-android-35-google-apis-playstore-x86-64
        sdkPkgs.ndk-27-1-12297006
      ]);

    packages.x86_64-linux.create-avd = createAvdScript;
    packages.x86_64-linux.run-emulator = runEmulatorScript;
    packages.x86_64-linux.list-avds = listAvdsScript;
    packages.x86_64-linux.emu-buttons = emuButtonsScript;
    packages.x86_64-linux.expo-open-all = expoOpenAllScript;

    packages.x86_64-linux.default = self.packages.x86_64-linux.android-sdk;

    devShells.x86_64-linux.default = pkgs.mkShell rec {
      JAVA_HOME = "${pkgs.corretto17}/lib/openjdk";
      ANDROID_HOME = "${self.packages.x86_64-linux.android-sdk}/share/android-sdk";
      ANDROID_SDK_ROOT = "${self.packages.x86_64-linux.android-sdk}/share/android-sdk";
      GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_SDK_ROOT}/build-tools/34.0.0/aapt2";

      nativeBuildInputs = [
        pkgs.nodejs_20
        pkgs.nodePackages.eas-cli
        pkgs.yarn
        pkgs.watchman
        pkgs.corretto17
        pkgs.aapt
        self.packages.x86_64-linux.android-sdk
        createAvdScript
        runEmulatorScript
        listAvdsScript
        emuButtonsScript
        expoOpenAllScript
        pkgs.steam-run
        pkgs.android-studio
        pkgs.awscli2
        pkgs.direnv
      ];

      shellHook = ''
        # Set AVD and emulator home directories (must be set in shellHook for proper expansion)
        export ANDROID_AVD_HOME="$HOME/.config/.android/avd"
        export ANDROID_EMULATOR_HOME="$HOME/.config/.android"

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  React Native Android Development Environment"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  Android SDK: ${ANDROID_SDK_ROOT}"
        echo "  AVD Home:    $ANDROID_AVD_HOME"
        echo "  Java:        ${JAVA_HOME}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Quick Start:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  1. Create an AVD:        create-avd Pixel_8_API_35"
        echo "  2. Launch emulator:      run-emulator Pixel_8_API_35"
        echo "  3. Run your app:         yarn expo run:android"
        echo ""
        echo "  Utilities:"
        echo "    list-avds              - List all AVDs"
        echo "    expo-open-all          - Open Expo app on all connected devices"
        echo "    emu-buttons home       - Send home button (if toolbar broken)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        mkdir -p "$ANDROID_AVD_HOME"
      '';
    };

    # Backward compatibility
    devShell.x86_64-linux = self.devShells.x86_64-linux.default;
  };
}
