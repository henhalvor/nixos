# Gammastep — night light with toggle script
# Source: home/modules/desktop/nightlight/gammastep.nix
# Template B2: HM-only
{self, ...}: {
  flake.nixosModules.gammastep = {...}: {
    home-manager.sharedModules = [self.homeModules.gammastep];
  };

  flake.homeModules.gammastep = {pkgs, ...}: let
    temperature = 3400;
    toggleScript = pkgs.writeShellScriptBin "nightlight-toggle" ''
      #!/usr/bin/env bash
      set -euo pipefail
      if ${pkgs.procps}/bin/pgrep -af gammastep | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|nightlight' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.gammastep}/bin/gammastep"; then
        pkill -f gammastep
        sleep 0.5
        if ${pkgs.procps}/bin/pgrep -af gammastep | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|nightlight' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.gammastep}/bin/gammastep"; then
          ${pkgs.libnotify}/bin/notify-send --expire-time=4000 "Night Light" "Error: Process still running after kill"
        else
          ${pkgs.libnotify}/bin/notify-send --expire-time=2000 "Night Light" "Disabled"
        fi
      else
        ${pkgs.gammastep}/bin/gammastep -O ${toString temperature} &
        disown
        ${pkgs.libnotify}/bin/notify-send --expire-time=1500 "Night Light" "Enabled (${toString temperature}K)"
      fi
    '';
  in {
    home.packages = [pkgs.gammastep toggleScript];
  };
}
