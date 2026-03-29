{ pkgs, ... }:

pkgs.writeShellScriptBin "sunshine-monitor-setup" ''
  #!/bin/bash

  DEBUG_FILE="/tmp/sunshine-monitor-setup.log"
  STATE_FILE="/tmp/sunshine-monitor-state"
  
  echo "=== Sunshine Monitor Setup $(date) ===" >> "$DEBUG_FILE"
  
  # Save current DPMS state for both monitors
  HDMI_DPMS=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="HDMI-A-1") | .dpmsStatus')
  DP_DPMS=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="DP-1") | .dpmsStatus')
  
  echo "HDMI-A-1 DPMS: $HDMI_DPMS" >> "$DEBUG_FILE"
  echo "DP-1 DPMS: $DP_DPMS" >> "$DEBUG_FILE"
  
  # Save state to file for restore script
  echo "HDMI_DPMS=$HDMI_DPMS" > "$STATE_FILE"
  echo "DP_DPMS=$DP_DPMS" >> "$STATE_FILE"
  
  # Force monitors ON if they were off (required for proper Sunshine rendering)
  if [ "$HDMI_DPMS" = "false" ] || [ "$DP_DPMS" = "false" ]; then
    echo "Monitors were off - turning them on for streaming..." >> "$DEBUG_FILE"
    ${pkgs.hyprland}/bin/hyprctl dispatch dpms on >> "$DEBUG_FILE" 2>&1
    sleep 2
  fi
  
  # Disable Samsung DP-1 (landscape monitor)
  echo "Disabling DP-1 (Samsung)..." >> "$DEBUG_FILE"
  ${pkgs.hyprland}/bin/hyprctl keyword monitor "DP-1,disable" >> "$DEBUG_FILE" 2>&1
  
  sleep 1
  
  # Rotate ASUS HDMI-A-1 to landscape mode (remove transform,1 which is portrait)
  echo "Rotating HDMI-A-1 to landscape..." >> "$DEBUG_FILE"
  ${pkgs.hyprland}/bin/hyprctl keyword monitor "HDMI-A-1,1920x1080@144,0x0,1" >> "$DEBUG_FILE" 2>&1
  
  sleep 1
  
  # Move active workspaces to HDMI-A-1
  echo "Moving workspaces to HDMI-A-1..." >> "$DEBUG_FILE"
  ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
  ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
  ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
  
  echo "Monitor setup complete - HDMI-A-1 is now monitor 0 in landscape" >> "$DEBUG_FILE"
  echo "Note: Monitors temporarily enabled for streaming (will restore state on disconnect)" >> "$DEBUG_FILE"
  echo "=== End Setup ===" >> "$DEBUG_FILE"
''
