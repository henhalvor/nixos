{ config, lib, pkgs, desktop, ... }:
let
  lockBin = {
    hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
    swaylock = "${pkgs.swaylock}/bin/swaylock";
    loginctl = "loginctl lock-session";
  }.${desktop.lock} or "loginctl lock-session";
in {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof ${desktop.lock} || ${lockBin}";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 300; on-timeout = lockBin; }
        { timeout = 600; on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
      ];
    };
  };
}
