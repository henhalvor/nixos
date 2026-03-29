# Hypridle — idle daemon for Hyprland
# Source: home/modules/desktop/idle/hypridle.nix
# Template B2: HM-only with NixOS option for lock command
{self, ...}: {
  flake.nixosModules.hypridle = {lib, ...}: {
    options.my.hypridle.lockCommand = lib.mkOption {
      type = lib.types.str;
      default = "hyprlock";
      description = "Lock screen command name (hyprlock, swaylock, loginctl)";
    };

    config.home-manager.sharedModules = [self.homeModules.hypridle];
  };

  flake.homeModules.hypridle = {pkgs, osConfig, ...}: let
    lockName = osConfig.my.hypridle.lockCommand;
    lockBin =
      {
        hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
        swaylock = "${pkgs.swaylock}/bin/swaylock";
        loginctl = "loginctl lock-session";
      }
      .${lockName}
      or "loginctl lock-session";
  in {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof ${lockName} || ${lockBin}";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
        listener = [
          {
            timeout = 300;
            on-timeout = lockBin;
          }
          {
            timeout = 600;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
}
