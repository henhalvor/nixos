{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.hypridle ];

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = hyprlock
        unlock_cmd = hyprctl dispatch dpms on && notify-send "Welcome back!"
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on && systemctl --user restart hyprpaper.service hyprpanel.service && sleep 1 && notify-send "Welcome back!"
    }

    # Single listener for lid events that handles both lock and suspend
    listener {
        device = LIBINPUT_DEVICE_LID_SWITCH
        on-lid-close = loginctl lock-session && sleep 1 && hyprctl dispatch dpms off
        on-lid-open = hyprctl dispatch dpms on && notify-send "Welcome back!"
    }

    # Separate timer for suspending after lid close
    listener {
        device = LIBINPUT_DEVICE_LID_SWITCH
        timeout = 330                          # Suspend after 5.5 minutes of inactivity)
        on-timeout = systemctl suspend
        on-lid-open = reset                  # Cancels suspension if lid opens
    }

    # This listener warns the user that the screen is being locked in 30 seconds
    listener {
        timeout = 300                        # 5 minutes of inactivity
        on-timeout = notify-send "Locking screen in 30 seconds..."
        on-resume = notify-send "Welcome back!"
    }

    # This listener locks the screen after 5.5 minutes of inactivity
    listener {
        timeout = 330                        # 5.5 minutes of inactivity
        on-timeout = loginctl lock-session
    }
  '';
}

