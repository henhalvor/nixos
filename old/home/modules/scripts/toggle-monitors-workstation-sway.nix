{ pkgs, ... }:
pkgs.writeShellScriptBin "toggle-monitors" ''
  #!/bin/bash

  DEBUG_FILE="/tmp/sway-monitor-toggle.log"
  echo "=== Monitor Toggle Debug $(date) ===" >> "$DEBUG_FILE"

  # Get the current state
  hdmi_power=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="HDMI-A-1") | .power // false')
  dp_power=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="DP-1") | .power // false')

  # Count how many monitors are present
  monitor_count=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="HDMI-A-1" or .name=="DP-1") | .name' | wc -l)

  echo "HDMI-A-1 power: $hdmi_power" >> "$DEBUG_FILE"
  echo "DP-1 power: $dp_power" >> "$DEBUG_FILE"
  echo "Monitors detected: $monitor_count" >> "$DEBUG_FILE"

  # If either monitor is on, turn both off
  if [[ "$hdmi_power" == "true" ]] || [[ "$dp_power" == "true" ]]; then
    echo "Turning monitors OFF" >> "$DEBUG_FILE"
    swaymsg 'output HDMI-A-1 power off' >> "$DEBUG_FILE" 2>&1
    swaymsg 'output DP-1 power off' >> "$DEBUG_FILE" 2>&1
  else
    echo "Turning monitors ON with full initialization..." >> "$DEBUG_FILE"
    
    # Step 1: Power on the monitors
    swaymsg 'output HDMI-A-1 power on' >> "$DEBUG_FILE" 2>&1
    swaymsg 'output DP-1 power on' >> "$DEBUG_FILE" 2>&1
    
    # Step 2: Wait for monitors to power up and be detected
    echo "Waiting for monitors to initialize..." >> "$DEBUG_FILE"
    sleep 2
    
    # Step 3: Force full reconfiguration with your exact settings
    echo "Applying full configuration..." >> "$DEBUG_FILE"
    swaymsg 'output HDMI-A-1 scale 1 mode 2560x1440@144Hz position 1080,0 power on' >> "$DEBUG_FILE" 2>&1
    swaymsg 'output DP-1 scale 1 mode 1920x1080@143855mHz transform 270 position 0,-180 power on' >> "$DEBUG_FILE" 2>&1
    
    # Step 4: Another brief wait
    sleep 1
    
    # Step 5: Ensure power is on again (sometimes needed after mode changes)
    swaymsg 'output HDMI-A-1 power on' >> "$DEBUG_FILE" 2>&1
    swaymsg 'output DP-1 power on' >> "$DEBUG_FILE" 2>&1
    
    # Step 6: Force workspace assignments to be applied
    echo "Reassigning workspaces..." >> "$DEBUG_FILE"
    swaymsg 'workspace 2, move workspace to output HDMI-A-1' >> "$DEBUG_FILE" 2>&1
    swaymsg 'workspace 1, move workspace to output DP-1' >> "$DEBUG_FILE" 2>&1
    
    echo "Monitor initialization complete" >> "$DEBUG_FILE"
  fi

  echo "=== End Debug ===" >> "$DEBUG_FILE"
''

