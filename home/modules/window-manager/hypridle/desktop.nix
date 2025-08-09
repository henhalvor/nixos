{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.hypridle ];

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = hyprlock
        unlock_cmd = hyprctl dispatch dpms on && notify-send "Welcome back!"
    }


  '';
}

