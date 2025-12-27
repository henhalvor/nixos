{ pkgs, ... }:

pkgs.writeShellScriptBin "sunshine-monitor-restore" ''
  #!/bin/bash

  DEBUG_FILE="/tmp/sunshine-monitor-restore.log"
  STATE_FILE="/tmp/sunshine-monitor-state"
  
  echo "=== Sunshine Monitor Restore $(date) ===" >> "$DEBUG_FILE"
  
  # Load saved DPMS state if available
  if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
    echo "Loaded saved DPMS state: HDMI=$HDMI_DPMS, DP=$DP_DPMS" >> "$DEBUG_FILE"
  else
    echo "Warning: No saved DPMS state found, monitors may have been on" >> "$DEBUG_FILE"
    HDMI_DPMS="true"
    DP_DPMS="true"
  fi
  
  # Re-enable Samsung DP-1 (landscape monitor)
  echo "Re-enabling DP-1 (Samsung)..." >> "$DEBUG_FILE"
  ${pkgs.hyprland}/bin/hyprctl keyword monitor "DP-1,2560x1440@144,1080x0,1" >> "$DEBUG_FILE" 2>&1
  
  sleep 1
  
  # Restore ASUS HDMI-A-1 to portrait mode (transform,1)
  echo "Rotating HDMI-A-1 back to portrait..." >> "$DEBUG_FILE"
  ${pkgs.hyprland}/bin/hyprctl keyword monitor "HDMI-A-1,1920x1080@144,0x-180,1,transform,1" >> "$DEBUG_FILE" 2>&1
  
  sleep 1
  
  # Restore workspace assignments
  echo "Restoring workspace assignments..." >> "$DEBUG_FILE"
  ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
  ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 DP-1 >> "$DEBUG_FILE" 2>&1
  ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 DP-1 >> "$DEBUG_FILE" 2>&1
  
  sleep 1
  
  # Restore original DPMS state if monitors were off
  if [ "$HDMI_DPMS" = "false" ] || [ "$DP_DPMS" = "false" ]; then
    echo "Restoring DPMS state (monitors were off before streaming)..." >> "$DEBUG_FILE"
    ${pkgs.hyprland}/bin/hyprctl dispatch dpms off >> "$DEBUG_FILE" 2>&1
  fi
  
  # Clean up state file
  rm -f "$STATE_FILE"
  
  echo "Monitor restore complete - back to normal dual-monitor setup" >> "$DEBUG_FILE"
  echo "DPMS state restored to pre-streaming state" >> "$DEBUG_FILE"
  echo "=== End Restore ===" >> "$DEBUG_FILE"
''
