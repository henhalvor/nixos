{ config, lib, pkgs, desktop, ... }:
let
  lockBin = {
    swaylock = "${pkgs.swaylock}/bin/swaylock -f";
    hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
    loginctl = "loginctl lock-session";
  }.${desktop.lock} or "loginctl lock-session";
  monitorPowerTimeout =
    if desktop.session == "niri"
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
      { timeout = 300; command = lockBin; }
      monitorPowerTimeout
    ];
    events = [
      { event = "before-sleep"; command = lockBin; }
    ];
  };
}
