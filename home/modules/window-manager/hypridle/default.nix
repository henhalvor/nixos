{ config, lib, pkgs, ... }:
{
  home.packages = [ pkgs.hypridle ];

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        # These commands define the basic behavior of our screen locking system
        lock_cmd = hyprlock                    # Command to lock the screen
        unlock_cmd = notify-send "Welcome back!"
        before_sleep_cmd = hyprlock            # Ensures screen is locked before sleep
        after_sleep_cmd = notify-send "Welcome back!"
    }

    # This listener handles immediate lock on lid close
    listener {
        device = LIBINPUT_DEVICE_LID_SWITCH    # Monitors laptop lid events
        on-lid-close = hyprlock                # Locks immediately when lid closes
        on-lid-open = notify-send "Welcome back!"
    }

    # This listener adds a 5-minute delay before suspending after lid close
    listener {
        device = LIBINPUT_DEVICE_LID_SWITCH    # Also monitors lid events
        timeout = 300                          # 5 minute delay (in seconds)
        on-timeout = systemctl suspend         # Suspends system after timeout
        # The timeout only starts counting after the lid closes
        on-lid-open = reset                    # Cancels suspension if lid opens
    }

    # Standard idle-based screen locking remains active
    listener {
        timeout = 300                          # 5 minutes of inactivity
        on-timeout = notify-send "Locking screen in 30 seconds..."
        on-resume = notify-send "Welcome back!"
    }

    listener {
        timeout = 330                          # 5.5 minutes of inactivity
        on-timeout = hyprlock                  # Locks screen after warning
    }
  '';
}
