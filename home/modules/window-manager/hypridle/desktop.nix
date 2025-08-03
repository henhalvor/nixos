{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.hypridle ];

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = hyprlock
        unlock_cmd = hyprctl dispatch dpms on && notify-send "Welcome back!"
    }


    # Notify 30 seconds before locking
    listener {
        timeout = 300                        # 5 minutes of inactivity
        on-timeout = notify-send "Locking screen in 30 seconds..."
        on-resume = notify-send "Welcome back!"
    }

    # Lock screen after 5.5 minutes of inactivity
    listener {
        timeout = 330                        # 5.5 minutes
        on-timeout = loginctl lock-session
    }
  '';
}

