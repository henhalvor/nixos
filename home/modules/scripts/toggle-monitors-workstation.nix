{ pkgs, ... }:
pkgs.writeShellScriptBin "toggle-monitors" ''
  #!/bin/bash

  DEBUG_FILE="/tmp/monitor-toggle.log"
  echo "=== Monitor Toggle Debug $(date) ===" >> "$DEBUG_FILE"

  # Detect which window manager is running
  if pgrep -x "sway" > /dev/null; then
    WM="sway"
    echo "Detected window manager: Sway" >> "$DEBUG_FILE"
  elif pgrep -x "Hyprland" > /dev/null; then
    WM="hyprland"
    echo "Detected window manager: Hyprland" >> "$DEBUG_FILE"
  else
    echo "No supported window manager detected" >> "$DEBUG_FILE"
    exit 1
  fi

  # Function to get monitor power state
  get_monitor_power() {
    local monitor_name=$1
    if [[ "$WM" == "sway" ]]; then
      swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$monitor_name\") | .power // false"
    elif [[ "$WM" == "hyprland" ]]; then
      # In Hyprland, we check if the monitor is enabled (no direct power state)
      if hyprctl monitors | grep -q "Monitor $monitor_name"; then
        echo "true"
      else
        echo "false"
      fi
    fi
  }

  # Function to count monitors
  count_monitors() {
    if [[ "$WM" == "sway" ]]; then
      swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="HDMI-A-1" or .name=="DP-1") | .name' | wc -l
    elif [[ "$WM" == "hyprland" ]]; then
      hyprctl monitors | grep -E "Monitor (HDMI-A-1|DP-1)" | wc -l
    fi
  }

  # Function to turn monitor off
  turn_monitor_off() {
    local monitor_name=$1
    if [[ "$WM" == "sway" ]]; then
      swaymsg "output $monitor_name power off" >> "$DEBUG_FILE" 2>&1
    elif [[ "$WM" == "hyprland" ]]; then
      hyprctl dispatch dpms off "$monitor_name" >> "$DEBUG_FILE" 2>&1
    fi
  }

  # Function to turn monitor on
  turn_monitor_on() {
    local monitor_name=$1
    if [[ "$WM" == "sway" ]]; then
      swaymsg "output $monitor_name power on" >> "$DEBUG_FILE" 2>&1
    elif [[ "$WM" == "hyprland" ]]; then
      hyprctl dispatch dpms on "$monitor_name" >> "$DEBUG_FILE" 2>&1
    fi
  }

  # Function to configure monitor
  configure_monitor() {
    local monitor_name=$1
    local config=$2
    if [[ "$WM" == "sway" ]]; then
      swaymsg "output $monitor_name $config power on" >> "$DEBUG_FILE" 2>&1
    elif [[ "$WM" == "hyprland" ]]; then
      # For Hyprland, we use keyword monitor to reconfigure
      hyprctl keyword monitor "$config" >> "$DEBUG_FILE" 2>&1
    fi
  }

  # Function to move workspace to output
  move_workspace_to_output() {
    local workspace=$1
    local output=$2
    if [[ "$WM" == "sway" ]]; then
      swaymsg "workspace $workspace, move workspace to output $output" >> "$DEBUG_FILE" 2>&1
    elif [[ "$WM" == "hyprland" ]]; then
      # In Hyprland, workspace assignment is handled by workspace rules
      # We can force move the workspace if needed
      hyprctl dispatch moveworkspacetomonitor "$workspace $output" >> "$DEBUG_FILE" 2>&1
    fi
  }

  # Get the current state
  hdmi_power=$(get_monitor_power "HDMI-A-1")
  dp_power=$(get_monitor_power "DP-1")

  # Count how many monitors are present
  monitor_count=$(count_monitors)

  echo "HDMI-A-1 power: $hdmi_power" >> "$DEBUG_FILE"
  echo "DP-1 power: $dp_power" >> "$DEBUG_FILE"
  echo "Monitors detected: $monitor_count" >> "$DEBUG_FILE"

  # If either monitor is on, turn both off
  if [[ "$hdmi_power" == "true" ]] || [[ "$dp_power" == "true" ]]; then
    echo "Turning monitors OFF" >> "$DEBUG_FILE"
    turn_monitor_off "HDMI-A-1"
    turn_monitor_off "DP-1"
  else
    echo "Turning monitors ON with full initialization..." >> "$DEBUG_FILE"
    
    # Step 1: Power on the monitors
    turn_monitor_on "HDMI-A-1"
    turn_monitor_on "DP-1"
    
    # Step 2: Wait for monitors to power up and be detected
    echo "Waiting for monitors to initialize..." >> "$DEBUG_FILE"
    sleep 2
    
    # Step 3: Force full reconfiguration with your exact settings
    echo "Applying full configuration..." >> "$DEBUG_FILE"
    if [[ "$WM" == "sway" ]]; then
      configure_monitor "HDMI-A-1" "scale 1 mode 2560x1440@144Hz position 1080,0"
      configure_monitor "DP-1" "scale 1 mode 1920x1080@143855mHz transform 270 position 0,-180"
    elif [[ "$WM" == "hyprland" ]]; then
      configure_monitor "HDMI-A-1" "HDMI-A-1,2560x1440@144,1080x0,1"
      configure_monitor "DP-1" "DP-1,1920x1080@144,0x-180,1,transform,1"
    fi
    
    # Step 4: Another brief wait
    sleep 1
    
    # Step 5: Ensure power is on again (sometimes needed after mode changes)
    turn_monitor_on "HDMI-A-1"
    turn_monitor_on "DP-1"
    
    # Step 6: Force workspace assignments to be applied
    echo "Reassigning workspaces..." >> "$DEBUG_FILE"
    move_workspace_to_output "2" "HDMI-A-1"
    move_workspace_to_output "1" "DP-1"
    
    echo "Monitor initialization complete" >> "$DEBUG_FILE"
  fi

  echo "=== End Debug ===" >> "$DEBUG_FILE"
''

