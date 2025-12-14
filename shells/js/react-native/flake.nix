{
  description = "React Native development environment with Android SDK and emulator support";

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

    # Wrapper scripts for AVD management
    packages.x86_64-linux.create-avd = pkgs.writeScriptBin "create-avd" (builtins.readFile ./scripts/create-avd.sh);
    packages.x86_64-linux.run-emulator = pkgs.writeScriptBin "run-emulator" (builtins.readFile ./scripts/run-emulator.sh);
    packages.x86_64-linux.list-avds = pkgs.writeScriptBin "list-avds" (builtins.readFile ./scripts/list-avds.sh);

    packages.x86_64-linux.default = self.packages.x86_64-linux.android-sdk;

    devShells.x86_64-linux.default = pkgs.mkShell rec {
      JAVA_HOME = "${pkgs.corretto17}/lib/openjdk";
      ANDROID_HOME = "${self.packages.x86_64-linux.android-sdk}/share/android-sdk";
      ANDROID_SDK_ROOT = "${self.packages.x86_64-linux.android-sdk}/share/android-sdk";
      GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_SDK_ROOT}/build-tools/34.0.0/aapt2";

      nativeBuildInputs = [
        # Node.js environment
        pkgs.nodejs_20
        pkgs.nodePackages.eas-cli
        pkgs.yarn
        
        # Android development
        pkgs.watchman
        pkgs.corretto17
        pkgs.aapt
        
        # Android SDK and tools
        self.packages.x86_64-linux.android-sdk
        
        # AVD management scripts
        self.packages.x86_64-linux.create-avd
        self.packages.x86_64-linux.run-emulator
        self.packages.x86_64-linux.list-avds
        
        # Steam-run for Hyprland emulator compatibility
        pkgs.steam-run
        
        # Optional: Android Studio for GUI AVD management
        pkgs.android-studio
        
        # AWS CLI (if needed for deployment)
        pkgs.awscli2
        
        # Direnv for automatic environment loading
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
        echo "  Available Commands:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  AVD Management:"
        echo "    create-avd <name>       - Create a new Android Virtual Device"
        echo "    run-emulator <name>     - Launch an emulator"
        echo "    list-avds               - List all AVDs and running emulators"
        echo ""
        echo "  Device Management:"
        echo "    adb devices             - List connected devices (physical + emulators)"
        echo "    adb shell               - Open shell on device"
        echo ""
        echo "  React Native:"
        echo "    yarn expo run:android   - Build and run on device/emulator"
        echo "    yarn expo start         - Start Metro bundler"
        echo ""
        echo "  Android Studio:"
        echo "    android-studio          - Launch Android Studio (GUI AVD manager)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Quick Start:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  1. Create an AVD:        create-avd Pixel_8_API_35"
        echo "  2. Launch emulator:      run-emulator Pixel_8_API_35"
        echo "  3. Run your app:         yarn expo run:android"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Ensure AVD directory exists
        mkdir -p "$ANDROID_AVD_HOME"
      '';
    };

    # Backward compatibility
    devShell.x86_64-linux = self.devShells.x86_64-linux.default;
  };
}
