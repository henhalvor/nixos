{ config, lib, pkgs, ... }:

let
  # Create the power-monitor package using writeScriptBin to avoid shellcheck
  power-monitor = pkgs.writeScriptBin "power-monitor" ''
    #!${pkgs.bash}/bin/bash

    # Power Monitor Script for NixOS
    # Collects comprehensive power and performance data in LLM-friendly format

    set -euo pipefail

    # Ensure required tools are in PATH
    export PATH="${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.procps}/bin:${pkgs.util-linux}/bin:${pkgs.bc}/bin:$PATH"
    
    # Add optional tools to PATH if they should be available
    export PATH="${pkgs.lm_sensors}/bin:${pkgs.sysstat}/bin:${pkgs.libva-utils}/bin:${pkgs.linuxPackages.cpupower}/bin:${pkgs.tlp}/bin:$PATH"

    # Colors for terminal output (disabled if piped)
    if [ -t 1 ]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        NC='\033[0m' # No Color
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        CYAN=""
        NC=""
    fi

    # Helper functions
    print_section() {
        echo -e "\n''${BLUE}=== $1 ===''${NC}"
    }

    print_metric() {
        echo -e "''${CYAN}$1:''${NC} $2"
    }

    get_value_or_na() {
        if [ -f "$1" ]; then
            cat "$1" 2>/dev/null || echo "N/A"
        else
            echo "N/A"
        fi
    }

    # Check if running as root for some commands
    if [ "$EUID" -ne 0 ]; then 
        echo -e "''${YELLOW}Note: Running without sudo. Some metrics may be unavailable.''${NC}"
        echo "For complete data, run: sudo $0"
    fi

    # Start monitoring
    echo -e "''${GREEN}SYSTEM POWER PERFORMANCE REPORT''${NC}"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"

    # Battery Information
    print_section "BATTERY STATUS"
    if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
        for bat in /sys/class/power_supply/BAT*; do
            if [ -d "$bat" ]; then
                BAT_NAME=$(basename "$bat")
                print_metric "Battery" "$BAT_NAME"
                print_metric "  Status" "$(get_value_or_na "$bat/status")"
                
                # Calculate percentage
                if [ -f "$bat/charge_now" ] && [ -f "$bat/charge_full" ]; then
                    CHARGE_NOW=$(cat "$bat/charge_now")
                    CHARGE_FULL=$(cat "$bat/charge_full")
                    PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($CHARGE_NOW/$CHARGE_FULL)*100}")
                    print_metric "  Charge" "''${PERCENTAGE}%"
                elif [ -f "$bat/capacity" ]; then
                    print_metric "  Charge" "$(cat "$bat/capacity")%"
                fi
                
                # Power draw
                if [ -f "$bat/power_now" ]; then
                    POWER_MW=$(cat "$bat/power_now")
                    POWER_W=$(awk "BEGIN {printf \"%.2f\", $POWER_MW/1000000}")
                    print_metric "  Power Draw" "''${POWER_W}W"
                elif [ -f "$bat/current_now" ] && [ -f "$bat/voltage_now" ]; then
                    CURRENT=$(cat "$bat/current_now")
                    VOLTAGE=$(cat "$bat/voltage_now")
                    POWER_W=$(awk "BEGIN {printf \"%.2f\", ($CURRENT*$VOLTAGE)/1000000000000}")
                    print_metric "  Power Draw (calculated)" "''${POWER_W}W"
                fi
                
                # Time remaining estimate
                if [ -f "$bat/charge_now" ] && [ -f "$bat/current_now" ] && [ -f "$bat/status" ]; then
                    STATUS=$(cat "$bat/status")
                    CURRENT=$(cat "$bat/current_now")
                    if [ "$STATUS" = "Discharging" ] && [ "$CURRENT" -gt 0 ]; then
                        CHARGE_NOW=$(cat "$bat/charge_now")
                        HOURS=$(awk "BEGIN {printf \"%.1f\", $CHARGE_NOW/$CURRENT}")
                        print_metric "  Time Remaining" "''${HOURS} hours"
                    fi
                fi
                
                # Battery health
                if [ -f "$bat/charge_full" ] && [ -f "$bat/charge_full_design" ]; then
                    FULL=$(cat "$bat/charge_full")
                    DESIGN=$(cat "$bat/charge_full_design")
                    HEALTH=$(awk "BEGIN {printf \"%.1f\", ($FULL/$DESIGN)*100}")
                    print_metric "  Battery Health" "''${HEALTH}%"
                fi
            fi
        done
    else
        print_metric "Battery" "No battery detected"
    fi

    # CPU Information
    print_section "CPU PERFORMANCE"
    print_metric "CPU Model" "$(lscpu | grep 'Model name:' | cut -d: -f2 | xargs)"
    print_metric "CPU Governor" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"

    # Current frequencies
    if command -v cpupower &> /dev/null; then
        print_metric "CPU Frequencies (cpupower)" ""
        cpupower frequency-info 2>/dev/null | grep -E "current CPU frequency|hardware limits" | sed 's/^/  /'
    else
        FREQS=""
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            if [ -f "$cpu/cpufreq/scaling_cur_freq" ]; then
                CORE=$(basename "$cpu")
                FREQ=$(awk '{printf "%.2f", $1/1000000}' "$cpu/cpufreq/scaling_cur_freq")
                FREQS="''${FREQS}''${CORE}:''${FREQ}GHz "
            fi
        done
        print_metric "CPU Frequencies" "$FREQS"
    fi

    # CPU stats
    if [ -f /proc/stat ]; then
        # Get CPU usage (requires two samples)
        CPU_STAT1=$(head -1 /proc/stat)
        sleep 1
        CPU_STAT2=$(head -1 /proc/stat)
        
        # Calculate CPU usage - using awk to parse the values
        CPU_USAGE=$(awk '
        BEGIN { 
            split("'"$CPU_STAT1"'", stat1); 
            split("'"$CPU_STAT2"'", stat2);
            
            idle1 = stat1[5] + stat1[6];
            idle2 = stat2[5] + stat2[6];
            
            total1 = 0; total2 = 0;
            for (i = 2; i <= 8; i++) {
                total1 += stat1[i];
                total2 += stat2[i];
            }
            
            diff_idle = idle2 - idle1;
            diff_total = total2 - total1;
            
            if (diff_total > 0) {
                usage = 100 * (1 - diff_idle / diff_total);
                printf "%.1f", usage;
            } else {
                print "N/A";
            }
        }')
        
        print_metric "CPU Usage" "''${CPU_USAGE}%"
    fi

    # Temperature
    print_section "THERMAL STATUS"
    if command -v sensors &> /dev/null; then
        TEMPS=$(sensors 2>/dev/null | grep -E "Package|Core|temp1" | grep -oE '[0-9]+\.[0-9]+°C' | head -5 | tr '\n' ' ')
        print_metric "Temperatures (sensors)" "$TEMPS"
    else
        # Fallback to sysfs
        TEMPS=""
        for temp in /sys/class/thermal/thermal_zone*/temp; do
            if [ -f "$temp" ]; then
                ZONE=$(dirname "$temp")
                TYPE=$(cat "$ZONE/type" 2>/dev/null || echo "unknown")
                TEMP_C=$(awk '{printf "%.1f", $1/1000}' "$temp")
                TEMPS="''${TEMPS}''${TYPE}:''${TEMP_C}°C "
            fi
        done
        print_metric "Temperatures" "$TEMPS"
    fi

    # AMD GPU Status
    print_section "AMD GPU STATUS"
    if [ -d /sys/class/drm/card0/device ]; then
        GPU_PATH="/sys/class/drm/card0/device"
        print_metric "GPU Power State" "$(get_value_or_na "$GPU_PATH/power_dpm_state")"
        print_metric "GPU Performance Level" "$(get_value_or_na "$GPU_PATH/power_dpm_force_performance_level")"
        
        if [ -f "$GPU_PATH/gpu_busy_percent" ]; then
            print_metric "GPU Usage" "$(cat "$GPU_PATH/gpu_busy_percent")%"
        fi
        
        # Find hwmon path dynamically
        for hwmon in "$GPU_PATH"/hwmon/hwmon*; do
            if [ -f "$hwmon/power1_average" ]; then
                GPU_POWER=$(cat "$hwmon/power1_average")
                GPU_POWER_W=$(awk "BEGIN {printf \"%.2f\", $GPU_POWER/1000000}")
                print_metric "GPU Power Draw" "''${GPU_POWER_W}W"
                break
            fi
        done
        
        # Memory clock
        if [ -f "$GPU_PATH/pp_dpm_mclk" ]; then
            MCLK=$(grep '\*' "$GPU_PATH/pp_dpm_mclk" 2>/dev/null | awk '{print $2}' || echo "N/A")
            print_metric "GPU Memory Clock" "$MCLK"
        fi
    fi

    # Power Profile and TLP Status
    print_section "POWER MANAGEMENT"
    if [ -f /sys/firmware/acpi/platform_profile ]; then
        print_metric "Platform Profile" "$(cat /sys/firmware/acpi/platform_profile)"
    fi

    if command -v tlp-stat &> /dev/null; then
        TLP_MODE=$(tlp-stat -s 2>/dev/null | grep "Mode" | awk '{print $3}' || echo "N/A")
        print_metric "TLP Mode" "$TLP_MODE"
    fi

    # Check if on AC or Battery
    for ac in /sys/class/power_supply/AC*; do
        if [ -f "$ac/online" ]; then
            AC_ONLINE=$(cat "$ac/online")
            if [ "$AC_ONLINE" = "1" ]; then
                print_metric "Power Source" "AC Power"
            else
                print_metric "Power Source" "Battery"
            fi
            break
        fi
    done

    # System Load
    print_section "SYSTEM LOAD"
    print_metric "Load Average" "$(uptime | awk -F'load average:' '{print $2}')"
    print_metric "Memory Usage" "$(free -h | awk '/^Mem:/ {print $3 " / " $2 " (" int($3/$2 * 100) "%)"}')"

    # Top Power Consumers
    print_section "TOP POWER CONSUMING PROCESSES"
    echo "Top 5 processes by CPU usage:"
    ps aux --sort=-%cpu | head -6 | awk 'NR>1 {printf "  %-20s %5s%% CPU %5s%% MEM %s\n", substr($11,1,20), $3, $4, $1}'

    # Disk I/O (can impact power)
    print_section "DISK ACTIVITY"
    if command -v iostat &> /dev/null; then
        iostat -d -x 1 2 | tail -n +4 | grep -E "nvme|sda|sdb" | awk '{printf "  %-10s r/s: %7.1f w/s: %7.1f util: %5.1f%%\n", $1, $4, $5, $NF}' | head -5
    else
        echo "  iostat not available"
    fi

    # Network interfaces power saving
    print_section "NETWORK POWER SAVING"
    for iface in /sys/class/net/*; do
        if [ -d "$iface" ] && [ "$(basename "$iface")" != "lo" ]; then
            IFACE_NAME=$(basename "$iface")
            if [ -f "$iface/power/control" ]; then
                POWER_CTRL=$(cat "$iface/power/control")
                print_metric "  $IFACE_NAME" "$POWER_CTRL"
            fi
        fi
    done

    # Video Acceleration Status
    print_section "VIDEO ACCELERATION"
    if command -v vainfo &> /dev/null; then
        VA_DRIVERS=$(vainfo 2>&1 | grep "Driver version" | cut -d: -f2 | xargs || echo "N/A")
        print_metric "VA-API Driver" "$VA_DRIVERS"
    fi

    # Summary and Recommendations
    print_section "POWER SUMMARY"
    echo "Key Metrics for Power Optimization:"

    # Calculate total system power if possible
    TOTAL_POWER=0
    POWER_SOURCES=""

    # Battery power - handle multiple battery files
    for bat_power in /sys/class/power_supply/BAT*/power_now; do
        if [ -f "$bat_power" ]; then
            BAT_POWER=$(cat "$bat_power")
            BAT_POWER_W=$(awk "BEGIN {printf \"%.2f\", $BAT_POWER/1000000}")
            TOTAL_POWER=$(awk "BEGIN {print $TOTAL_POWER + $BAT_POWER_W}")
            POWER_SOURCES="''${POWER_SOURCES}Battery:''${BAT_POWER_W}W "
            break
        fi
    done

    print_metric "• Total System Power" "''${TOTAL_POWER}W ''${POWER_SOURCES}"
    
    # Power efficiency rating
    if [ "$(awk "BEGIN {print ($TOTAL_POWER < 5)}")" = "1" ]; then
        RATING="Excellent (<5W)"
    elif [ "$(awk "BEGIN {print ($TOTAL_POWER < 10)}")" = "1" ]; then
        RATING="Good (5-10W)"
    elif [ "$(awk "BEGIN {print ($TOTAL_POWER < 15)}")" = "1" ]; then
        RATING="Average (10-15W)"
    elif [ "$(awk "BEGIN {print ($TOTAL_POWER < 20)}")" = "1" ]; then
        RATING="Poor (15-20W)"
    else
        RATING="Very Poor (>20W)"
    fi
    print_metric "• Power Efficiency Rating" "$RATING"

    # Quick diagnostics
    echo -e "\n''${YELLOW}Quick Diagnostics:''${NC}"
    if [ "$(awk "BEGIN {print ($TOTAL_POWER > 15)}")" = "1" ]; then
        echo "⚠️  High power consumption detected"
    fi
    
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
        [ "$GOV" = "performance" ] && echo "⚠️  CPU governor set to performance"
    fi
    
    if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
        PERF_LEVEL=$(cat /sys/class/drm/card0/device/power_dpm_force_performance_level)
        [ "$PERF_LEVEL" = "high" ] && echo "⚠️  GPU forced to high performance"
    fi

    echo -e "\n''${GREEN}Report complete.''${NC}"
    echo "Share this output with an LLM for power optimization advice."
  '';

in
{
  # Add the script and its dependencies to home packages
  home.packages = with pkgs; [
    power-monitor
    
    # Ensure these tools are available when the script runs
    coreutils
    gawk
    gnugrep
    gnused
    procps
    util-linux
    bc
    lm_sensors
    sysstat
    libva-utils
    linuxPackages.cpupower
    tlp
  ];
  
  # Create aliases for convenience
  programs.bash.shellAliases = {
    pm = "power-monitor";
    pms = "sudo power-monitor";
  };
  
  programs.zsh.shellAliases = {
    pm = "power-monitor";
    pms = "sudo power-monitor";
  };
  
  # Create a desktop entry
  xdg.desktopEntries.power-monitor = {
    name = "Power Monitor";
    comment = "Monitor system power consumption and performance";
    exec = "${pkgs.kitty}/bin/kitty -e power-monitor";
    terminal = false;
    categories = [ "System" "Monitor" ];
    icon = "utilities-system-monitor";
  };
}
