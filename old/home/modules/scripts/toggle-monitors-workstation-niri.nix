{ pkgs, ... }:
pkgs.writeShellScriptBin "toggle-monitors" ''
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
''
