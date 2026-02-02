{ config, lib, pkgs, ... }:
let
  temperature = 3400;
  
  toggleScript = pkgs.writeShellScriptBin "nightlight-toggle" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if redshift is running
    if ${pkgs.procps}/bin/pgrep -af redshift | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|nightlight' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.redshift}/bin/redshift"; then
      # Kill redshift
      pkill -f redshift
      
      # Verify it stopped
      sleep 0.5
      if ${pkgs.procps}/bin/pgrep -af redshift | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|nightlight' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.redshift}/bin/redshift"; then
        ${pkgs.libnotify}/bin/notify-send --expire-time=4000 "Night Light" "Error: Process still running after kill"
      else
        ${pkgs.libnotify}/bin/notify-send --expire-time=2000 "Night Light" "Disabled"
      fi
    else
      # Start redshift
      ${pkgs.redshift}/bin/redshift -O ${toString temperature} &
      disown
      ${pkgs.libnotify}/bin/notify-send --expire-time=1500 "Night Light" "Enabled (${toString temperature}K)"
    fi
  '';
in {
  home.packages = [
    pkgs.redshift
    toggleScript
  ];
}
