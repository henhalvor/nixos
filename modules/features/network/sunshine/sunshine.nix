# Sunshine — remote game streaming server
# Source: nixos/modules/server/sunshine/default.nix + monitor scripts
# Defines options.my.sunshine.user for user-specific config.
# Monitor setup/restore scripts are exported as packages for hyprland to reference.
{...}: {
  flake.nixosModules.sunshine = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.my.sunshine;
    homeDir = config.users.users.${cfg.user}.home;

    sunshine-monitor-setup = pkgs.writeShellScriptBin "sunshine-monitor-setup" ''
      #!/bin/bash
      DEBUG_FILE="/tmp/sunshine-monitor-setup.log"
      STATE_FILE="/tmp/sunshine-monitor-state"

      echo "=== Sunshine Monitor Setup $(date) ===" >> "$DEBUG_FILE"

      HDMI_DPMS=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="HDMI-A-1") | .dpmsStatus')
      DP_DPMS=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="DP-1") | .dpmsStatus')

      echo "HDMI-A-1 DPMS: $HDMI_DPMS" >> "$DEBUG_FILE"
      echo "DP-1 DPMS: $DP_DPMS" >> "$DEBUG_FILE"

      echo "HDMI_DPMS=$HDMI_DPMS" > "$STATE_FILE"
      echo "DP_DPMS=$DP_DPMS" >> "$STATE_FILE"

      if [ "$HDMI_DPMS" = "false" ] || [ "$DP_DPMS" = "false" ]; then
        echo "Monitors were off - turning them on for streaming..." >> "$DEBUG_FILE"
        ${pkgs.hyprland}/bin/hyprctl dispatch dpms on >> "$DEBUG_FILE" 2>&1
        sleep 2
      fi

      echo "Disabling DP-1 (Samsung)..." >> "$DEBUG_FILE"
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "DP-1,disable" >> "$DEBUG_FILE" 2>&1
      sleep 1

      echo "Rotating HDMI-A-1 to landscape..." >> "$DEBUG_FILE"
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "HDMI-A-1,1920x1080@144,0x0,1" >> "$DEBUG_FILE" 2>&1
      sleep 1

      echo "Moving workspaces to HDMI-A-1..." >> "$DEBUG_FILE"
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 HDMI-A-1 >> "$DEBUG_FILE" 2>&1

      echo "=== End Setup ===" >> "$DEBUG_FILE"
    '';

    sunshine-monitor-restore = pkgs.writeShellScriptBin "sunshine-monitor-restore" ''
      #!/bin/bash
      DEBUG_FILE="/tmp/sunshine-monitor-restore.log"
      STATE_FILE="/tmp/sunshine-monitor-state"

      echo "=== Sunshine Monitor Restore $(date) ===" >> "$DEBUG_FILE"

      if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        echo "Loaded saved DPMS state: HDMI=$HDMI_DPMS, DP=$DP_DPMS" >> "$DEBUG_FILE"
      else
        echo "Warning: No saved DPMS state found" >> "$DEBUG_FILE"
        HDMI_DPMS="true"
        DP_DPMS="true"
      fi

      echo "Re-enabling DP-1 (Samsung)..." >> "$DEBUG_FILE"
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "DP-1,2560x1440@144,1080x0,1" >> "$DEBUG_FILE" 2>&1
      sleep 1

      echo "Rotating HDMI-A-1 back to portrait..." >> "$DEBUG_FILE"
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "HDMI-A-1,1920x1080@144,0x-180,1,transform,1" >> "$DEBUG_FILE" 2>&1
      sleep 1

      echo "Restoring workspace assignments..." >> "$DEBUG_FILE"
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 DP-1 >> "$DEBUG_FILE" 2>&1
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 DP-1 >> "$DEBUG_FILE" 2>&1
      sleep 1

      if [ "$HDMI_DPMS" = "false" ] || [ "$DP_DPMS" = "false" ]; then
        echo "Restoring DPMS state (monitors were off before streaming)..." >> "$DEBUG_FILE"
        ${pkgs.hyprland}/bin/hyprctl dispatch dpms off >> "$DEBUG_FILE" 2>&1
      fi

      rm -f "$STATE_FILE"
      echo "=== End Restore ===" >> "$DEBUG_FILE"
    '';
  in {
    options.my.sunshine = {
      user = lib.mkOption {
        type = lib.types.str;
        description = "Username for Sunshine config deployment";
      };
    };

    config = {
      services.sunshine = {
        enable = true;
        autoStart = true;
        capSysAdmin = true;
        openFirewall = true;
      };

      environment.systemPackages = with pkgs; [
        libva-utils
        cudatoolkit
        sunshine-monitor-setup
        sunshine-monitor-restore
      ];

      services.avahi.publish.enable = true;
      services.avahi.publish.userServices = true;

      # Deploy apps.json declaratively
      systemd.tmpfiles.rules = [
        "L+ ${homeDir}/.config/sunshine/apps.json - ${cfg.user} users - ${./apps.json}"
      ];
    };
  };
}
