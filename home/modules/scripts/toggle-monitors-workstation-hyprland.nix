{ pkgs, ... }:

pkgs.writeShellScriptBin "toggle-monitors" ''


  #!/bin/bash

  DEBUG_FILE="/tmp/hypr-monitor-toggle.log"

  echo "=== Monitor Toggle Debug $(date) ===" >> "$DEBUG_FILE"

  # Use jq to parse DPMS states as booleans
  HDMI_STATUS=$(hyprctl monitors -j | jq -r '.[] | select(.name=="HDMI-A-1") | .dpmsStatus')
  DP_STATUS=$(hyprctl monitors -j | jq -r '.[] | select(.name=="DP-1") | .dpmsStatus')

  echo "HDMI-A-1 DPMS status: $HDMI_STATUS" >> "$DEBUG_FILE"
  echo "DP-1 DPMS status: $DP_STATUS" >> "$DEBUG_FILE"

  # Convert true/false to 1/0
  HDMI_ON=$([[ "$HDMI_STATUS" == "true" ]] && echo 1 || echo 0)
  DP_ON=$([[ "$DP_STATUS" == "true" ]] && echo 1 || echo 0)

  # If either is on, turn both off
  if [[ "$HDMI_ON" -eq 1 || "$DP_ON" -eq 1 ]]; then
    echo "Turning monitors OFF" >> "$DEBUG_FILE"
    hyprctl dispatch dpms off >> "$DEBUG_FILE" 2>&1
  else
    echo "Turning monitors ON with full initialization..." >> "$DEBUG_FILE"

    hyprctl dispatch dpms on >> "$DEBUG_FILE" 2>&1
    sleep 2

    echo "Reapplying monitor configuration..." >> "$DEBUG_FILE"
    hyprctl keyword monitor "DP-1,2560x1440@144,1080x0,1" >> "$DEBUG_FILE" 2>&1
    hyprctl keyword monitor "HDMI-A-1,1920x1080@144,0x-180,1,transform,1" >> "$DEBUG_FILE" 2>&1

    sleep 1

    echo "Reassigning workspaces..." >> "$DEBUG_FILE"
    hyprctl dispatch moveworkspacetomonitor 1 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
    hyprctl dispatch moveworkspacetomonitor 2 DP-1 >> "$DEBUG_FILE" 2>&1

    echo "Monitor reinitialization complete" >> "$DEBUG_FILE"
  fi

  echo "=== End Debug ===" >> "$DEBUG_FILE"

''

