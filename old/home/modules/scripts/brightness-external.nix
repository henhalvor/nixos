{pkgs, ...}:
pkgs.writeShellScriptBin "brightness-external" ''
  #!/usr/bin/env bash

  # External monitor brightness control using ddcutil
  # Controls both ASUS (bus 3) and Samsung (bus 4) monitors

  # VCP code 10 is brightness (0-100)
  VCP_BRIGHTNESS=10

  # Brightness change amount (percentage)
  STEP=10

  # Monitor I2C buses
  ASUS_BUS=3
  SAMSUNG_BUS=4

  get_brightness() {
      local bus=$1
      # Get current brightness value, extract the number
      ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" getvcp "$VCP_BRIGHTNESS" 2>/dev/null | grep -oP 'current value =\s+\K\d+'
      # Small delay after read operation
      sleep 0.05
  }

  set_brightness() {
      local bus=$1
      local value=$2
      ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" setvcp "$VCP_BRIGHTNESS" "$value" 2>/dev/null
      # Delay after write to let monitor process the command
      sleep 0.1
  }

  increase_brightness() {
      local bus=$1
      local current=$(get_brightness "$bus")
      
      if [[ -n "$current" ]]; then
          local new=$((current + STEP))
          # Cap at 100
          if [[ $new -gt 100 ]]; then
              new=100
          fi
          set_brightness "$bus" "$new"
      fi
  }

  decrease_brightness() {
      local bus=$1
      local current=$(get_brightness "$bus")
      
      if [[ -n "$current" ]]; then
          local new=$((current - STEP))
          # Cap at 0
          if [[ $new -lt 0 ]]; then
              new=0
          fi
          set_brightness "$bus" "$new"
      fi
  }

  main() {
      local action=$1
      
      case "$action" in
          --increase|up)
              increase_brightness "$ASUS_BUS" &
              increase_brightness "$SAMSUNG_BUS" &
              wait
              ;;
          --decrease|down)
              decrease_brightness "$ASUS_BUS" &
              decrease_brightness "$SAMSUNG_BUS" &
              wait
              ;;
          *)
              echo "Usage: $0 {--increase|--decrease}"
              exit 1
              ;;
      esac
  }

  main "$@"
''
