# Power Monitor — comprehensive power/performance monitoring script
# Source: home/modules/scripts/power-monitor.nix
# Template B2: HM-only
{ self, ... }: {
  flake.nixosModules.powerMonitor = { ... }: {
    home-manager.sharedModules = [ self.homeModules.powerMonitor ];
  };

  flake.homeModules.powerMonitor = { pkgs, ... }: let
    power-monitor = pkgs.writeScriptBin "power-monitor" ''
      #!${pkgs.bash}/bin/bash

      # Power Monitor Script for NixOS
      # Collects comprehensive power and performance data in LLM-friendly format

      set -euo pipefail

      export PATH="${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.procps}/bin:${pkgs.util-linux}/bin:${pkgs.bc}/bin:$PATH"
      export PATH="${pkgs.lm_sensors}/bin:${pkgs.sysstat}/bin:${pkgs.libva-utils}/bin:${pkgs.linuxPackages.cpupower}/bin:${pkgs.tlp}/bin:$PATH"

      if [ -t 1 ]; then
          RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
          BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
      else
          RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; NC=""
      fi

      print_section() { echo -e "\n''${BLUE}=== $1 ===''${NC}"; }
      print_metric() { echo -e "''${CYAN}$1:''${NC} $2"; }
      get_value_or_na() { if [ -f "$1" ]; then cat "$1" 2>/dev/null || echo "N/A"; else echo "N/A"; fi; }

      if [ "$EUID" -ne 0 ]; then
          echo -e "''${YELLOW}Note: Running without sudo. Some metrics may be unavailable.''${NC}"
      fi

      echo -e "''${GREEN}SYSTEM POWER PERFORMANCE REPORT''${NC}"
      echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "Hostname: $(hostname)"

      # Battery
      print_section "BATTERY STATUS"
      if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
          for bat in /sys/class/power_supply/BAT*; do
              if [ -d "$bat" ]; then
                  BAT_NAME=$(basename "$bat")
                  print_metric "Battery" "$BAT_NAME"
                  print_metric "  Status" "$(get_value_or_na "$bat/status")"
                  if [ -f "$bat/charge_now" ] && [ -f "$bat/charge_full" ]; then
                      CHARGE_NOW=$(cat "$bat/charge_now"); CHARGE_FULL=$(cat "$bat/charge_full")
                      PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($CHARGE_NOW/$CHARGE_FULL)*100}")
                      print_metric "  Charge" "''${PERCENTAGE}%"
                  elif [ -f "$bat/capacity" ]; then
                      print_metric "  Charge" "$(cat "$bat/capacity")%"
                  fi
                  if [ -f "$bat/power_now" ]; then
                      POWER_MW=$(cat "$bat/power_now")
                      POWER_W=$(awk "BEGIN {printf \"%.2f\", $POWER_MW/1000000}")
                      print_metric "  Power Draw" "''${POWER_W}W"
                  fi
                  if [ -f "$bat/charge_full" ] && [ -f "$bat/charge_full_design" ]; then
                      FULL=$(cat "$bat/charge_full"); DESIGN=$(cat "$bat/charge_full_design")
                      HEALTH=$(awk "BEGIN {printf \"%.1f\", ($FULL/$DESIGN)*100}")
                      print_metric "  Battery Health" "''${HEALTH}%"
                  fi
              fi
          done
      else
          print_metric "Battery" "No battery detected"
      fi

      # CPU
      print_section "CPU PERFORMANCE"
      print_metric "CPU Model" "$(lscpu | grep 'Model name:' | cut -d: -f2 | xargs)"
      print_metric "CPU Governor" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
      FREQS=""
      for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
          if [ -f "$cpu/cpufreq/scaling_cur_freq" ]; then
              CORE=$(basename "$cpu")
              FREQ=$(awk '{printf "%.2f", $1/1000000}' "$cpu/cpufreq/scaling_cur_freq")
              FREQS="''${FREQS}''${CORE}:''${FREQ}GHz "
          fi
      done
      print_metric "CPU Frequencies" "$FREQS"

      if [ -f /proc/stat ]; then
          CPU_STAT1=$(head -1 /proc/stat); sleep 1; CPU_STAT2=$(head -1 /proc/stat)
          CPU_USAGE=$(awk 'BEGIN {
              split("'"$CPU_STAT1"'", s1); split("'"$CPU_STAT2"'", s2);
              idle1=s1[5]+s1[6]; idle2=s2[5]+s2[6]; t1=0; t2=0;
              for(i=2;i<=8;i++){t1+=s1[i];t2+=s2[i]}
              d=t2-t1; if(d>0) printf "%.1f",100*(1-(idle2-idle1)/d); else print "N/A"
          }')
          print_metric "CPU Usage" "''${CPU_USAGE}%"
      fi

      # Temperature
      print_section "THERMAL STATUS"
      if command -v sensors &> /dev/null; then
          TEMPS=$(sensors 2>/dev/null | grep -E "Package|Core|temp1" | grep -oE '[0-9]+\.[0-9]+°C' | head -5 | tr '\n' ' ')
          print_metric "Temperatures" "$TEMPS"
      fi

      # GPU
      print_section "GPU STATUS"
      if [ -d /sys/class/drm/card0/device ]; then
          GPU_PATH="/sys/class/drm/card0/device"
          print_metric "GPU Power State" "$(get_value_or_na "$GPU_PATH/power_dpm_state")"
          print_metric "GPU Performance Level" "$(get_value_or_na "$GPU_PATH/power_dpm_force_performance_level")"
          [ -f "$GPU_PATH/gpu_busy_percent" ] && print_metric "GPU Usage" "$(cat "$GPU_PATH/gpu_busy_percent")%"
          for hwmon in "$GPU_PATH"/hwmon/hwmon*; do
              if [ -f "$hwmon/power1_average" ]; then
                  GPU_POWER=$(cat "$hwmon/power1_average")
                  print_metric "GPU Power Draw" "$(awk "BEGIN {printf \"%.2f\", $GPU_POWER/1000000}")W"
                  break
              fi
          done
      fi

      # Power Management
      print_section "POWER MANAGEMENT"
      [ -f /sys/firmware/acpi/platform_profile ] && print_metric "Platform Profile" "$(cat /sys/firmware/acpi/platform_profile)"
      for ac in /sys/class/power_supply/AC*; do
          if [ -f "$ac/online" ]; then
              [ "$(cat "$ac/online")" = "1" ] && print_metric "Power Source" "AC Power" || print_metric "Power Source" "Battery"
              break
          fi
      done

      # System Load
      print_section "SYSTEM LOAD"
      print_metric "Load Average" "$(uptime | awk -F'load average:' '{print $2}')"
      print_metric "Memory Usage" "$(free -h | awk '/^Mem:/ {print $3 " / " $2 " (" int($3/$2 * 100) "%)"}')"

      # Top processes
      print_section "TOP POWER CONSUMING PROCESSES"
      ps aux --sort=-%cpu | head -6 | awk 'NR>1 {printf "  %-20s %5s%% CPU %5s%% MEM %s\n", substr($11,1,20), $3, $4, $1}'

      echo -e "\n''${GREEN}Report complete.''${NC}"
    '';
  in {
    home.packages = with pkgs; [
      power-monitor
      coreutils gawk gnugrep gnused procps util-linux bc
      lm_sensors sysstat libva-utils linuxPackages.cpupower tlp
    ];

    programs.zsh.shellAliases = {
      pm = "power-monitor";
      pms = "sudo power-monitor";
    };

    xdg.desktopEntries.power-monitor = {
      name = "Power Monitor";
      comment = "Monitor system power consumption and performance";
      exec = "${pkgs.kitty}/bin/kitty -e power-monitor";
      terminal = false;
      categories = [ "System" "Monitor" ];
      icon = "utilities-system-monitor";
    };
  };
}
