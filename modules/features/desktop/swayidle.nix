# Swayidle — idle daemon for Sway/Niri
# Source: home/modules/desktop/idle/swayidle.nix
# Template B2: HM-only with NixOS options for lock command + session
{self, ...}: {
  flake.nixosModules.swayidle = {lib, ...}: {
    options.my.swayidle = {
      lockCommand = lib.mkOption {
        type = lib.types.str;
        default = "swaylock";
        description = "Lock screen command name (swaylock, hyprlock, loginctl)";
      };
      session = lib.mkOption {
        type = lib.types.str;
        default = "sway";
        description = "Session type for monitor power command (sway or niri)";
      };
    };

    config.home-manager.sharedModules = [self.homeModules.swayidle];
  };

  flake.homeModules.swayidle = {pkgs, osConfig, ...}: let
    cfg = osConfig.my.swayidle;
    lockBin =
      {
        swaylock = "${pkgs.swaylock}/bin/swaylock -f";
        hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
        loginctl = "loginctl lock-session";
      }
      .${cfg.lockCommand}
      or "loginctl lock-session";

    monitorPowerTimeout =
      if cfg.session == "niri"
      then {
        timeout = 600;
        command = "niri msg action power-off-monitors";
      }
      else {
        timeout = 600;
        command = "swaymsg 'output * dpms off'";
        resumeCommand = "swaymsg 'output * dpms on'";
      };
  in {
    services.swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 300;
          command = lockBin;
        }
        monitorPowerTimeout
      ];
      events = [
        {
          event = "before-sleep";
          command = lockBin;
        }
      ];
    };
  };
}
