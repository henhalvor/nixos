# Niri — scrollable tiling Wayland compositor
# Source: nixos/modules/desktop/sessions/niri.nix + home/modules/desktop/sessions/niri.nix
# Template C: Colocated NixOS + HM
#
# Config is KDL-based in modules/features/niri-config/
# Host-specific config selected by hostname.
{self, ...}: {
  flake.nixosModules.niri = {pkgs-unstable, ...}: {
    programs.niri = {
      enable = true;
      package = pkgs-unstable.niri;
    };

    security.pam.services.swaylock = {};
    security.polkit.enable = true;

    # Common Wayland env vars are in desktopCommon; Niri sets XDG_CURRENT_DESKTOP itself

    # video group is set in the user module
    programs.light.enable = true;

    home-manager.sharedModules = [self.homeModules.niri];
  };

  flake.homeModules.niri = {
    config,
    pkgs,
    osConfig,
    ...
  }: let
    hostname = osConfig.networking.hostName;

    toggle-monitors-niri = pkgs.writeShellScriptBin "toggle-monitors" ''
      #!/bin/bash
      DEBUG_FILE="/tmp/niri-monitor-toggle.log"
      echo "=== Monitor Toggle Debug $(date) ===" >> "$DEBUG_FILE"

      outputs_json=$(niri msg --json outputs)

      get_output_enabled() {
        printf '%s' "$outputs_json" | ${pkgs.jq}/bin/jq -r --arg name "$1" '
          if type == "array" then
            any(.[]; (.name // .connector // .output // "") == $name and .current_mode != null)
          else
            .[$name].current_mode != null
          end
        '
      }

      hdmi_on=$(get_output_enabled "HDMI-A-1")
      dp_on=$(get_output_enabled "DP-1")

      echo "HDMI-A-1 enabled: $hdmi_on" >> "$DEBUG_FILE"
      echo "DP-1 enabled: $dp_on" >> "$DEBUG_FILE"

      if [[ "$hdmi_on" == "true" || "$dp_on" == "true" ]]; then
        echo "Turning monitors OFF" >> "$DEBUG_FILE"
        niri msg output HDMI-A-1 off >> "$DEBUG_FILE" 2>&1
        niri msg output DP-1 off >> "$DEBUG_FILE" 2>&1
      else
        echo "Turning monitors ON" >> "$DEBUG_FILE"
        niri msg output HDMI-A-1 on >> "$DEBUG_FILE" 2>&1
        niri msg output DP-1 on >> "$DEBUG_FILE" 2>&1
        sleep 2
      fi
      echo "=== End Debug ===" >> "$DEBUG_FILE"
    '';

    brightness-external = pkgs.writeShellScriptBin "brightness-external" ''
      #!/usr/bin/env bash
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
      case "$1" in
        --increase|up)
          increase_brightness "$ASUS_BUS" &
          increase_brightness "$SAMSUNG_BUS" &
          wait ;;
        --decrease|down)
          decrease_brightness "$ASUS_BUS" &
          decrease_brightness "$SAMSUNG_BUS" &
          wait ;;
        *) echo "Usage: $0 {--increase|--decrease}"; exit 1 ;;
      esac
    '';

    hostPackages =
      if hostname == "workstation"
      then [toggle-monitors-niri brightness-external]
      else [];

    # Select host-specific KDL config file
    hostConfigFile =
      if hostname == "workstation"
      then "hosts/workstation.kdl"
      else "hosts/default.kdl";

    # Path to the niri-config directory co-located with this feature
    niriConfigSrc = ./config;
  in {
    home.packages = with pkgs;
      [brightnessctl pamixer playerctl ddcutil bluez blueberry swaybg xwayland-satellite]
      ++ hostPackages;

    # Wayland env vars are in desktopCommon; niri sets XDG_CURRENT_DESKTOP itself

    xdg.configFile = {
      "niri/config.kdl".source = "${niriConfigSrc}/config.kdl";
      "niri/common".source = "${niriConfigSrc}/common";
      "niri/host.kdl".source = "${niriConfigSrc}/${hostConfigFile}";
    };
  };
}
