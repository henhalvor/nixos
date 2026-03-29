# Brightness External — ddcutil wrapper for external monitor brightness
# Source: home/modules/scripts/brightness-external.nix
# Template B2: HM-only (standalone script package)
# Note: This script is also inlined in hyprland.nix and niri.nix for keybindings.
# This feature provides it as a standalone command.
{ self, ... }: {
  flake.nixosModules.brightnessExternal = { ... }: {
    home-manager.sharedModules = [ self.homeModules.brightnessExternal ];
  };

  flake.homeModules.brightnessExternal = { pkgs, ... }: {
    home.packages = [
      (pkgs.writeShellScriptBin "brightness-external" ''
        #!/usr/bin/env bash

        # External monitor brightness control using ddcutil
        # Controls both ASUS (bus 3) and Samsung (bus 4) monitors

        VCP_BRIGHTNESS=10
        STEP=10
        ASUS_BUS=3
        SAMSUNG_BUS=4

        get_brightness() {
            local bus=$1
            ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" getvcp "$VCP_BRIGHTNESS" 2>/dev/null | grep -oP 'current value =\s+\K\d+'
            sleep 0.05
        }

        set_brightness() {
            local bus=$1
            local value=$2
            ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" setvcp "$VCP_BRIGHTNESS" "$value" 2>/dev/null
            sleep 0.1
        }

        increase_brightness() {
            local bus=$1
            local current=$(get_brightness "$bus")
            if [[ -n "$current" ]]; then
                local new=$((current + STEP))
                [[ $new -gt 100 ]] && new=100
                set_brightness "$bus" "$new"
            fi
        }

        decrease_brightness() {
            local bus=$1
            local current=$(get_brightness "$bus")
            if [[ -n "$current" ]]; then
                local new=$((current - STEP))
                [[ $new -lt 0 ]] && new=0
                set_brightness "$bus" "$new"
            fi
        }

        case "''${1:-}" in
            --increase|up)
                increase_brightness "$ASUS_BUS" &
                increase_brightness "$SAMSUNG_BUS" &
                wait ;;
            --decrease|down)
                decrease_brightness "$ASUS_BUS" &
                decrease_brightness "$SAMSUNG_BUS" &
                wait ;;
            *)
                echo "Usage: $0 {--increase|--decrease|up|down}"
                exit 1 ;;
        esac
      '')
    ];
  };
}
