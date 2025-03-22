{ config, lib, pkgs, ... }:
{
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

# { config, lib, pkgs, ... }:
# {
#   home.packages = [ pkgs.hypridle ];
#
#   xdg.configFile."hypr/hypridle.conf".text = ''
#     general {
#         # These commands define the basic behavior of our screen locking system
#         lock_cmd = hyprlock                    # Command to lock the screen
#         unlock_cmd = notify-send "Welcome back!"
#         before_sleep_cmd = loginctl lock-session            # Ensures screen is locked before sleep
#         after_sleep_cmd = notify-send "Welcome back!"
#     }
#
#     #
#     # SCREEN LOCKING ON LID CLOSE
#     #
#     # This listener handles immediate lock on lid close
#     listener {
#         device = LIBINPUT_DEVICE_LID_SWITCH    # Monitors laptop lid events
#         on-lid-close = loginctl lock-session               # Locks immediately when lid closes
#         on-lid-open = notify-send "Welcome back!"
#     }
#
#
#    #
#    # IDLE-BASED SUSPENSION AFTER LID CLOSE
#    #
#    # This listener adds a 5-minute delay before suspending after lid close
#    # 5-minute timer only starts after the lid is closed and is reset if the lid is opened
#     listener {
#         device = LIBINPUT_DEVICE_LID_SWITCH    # Monitors lid events
#         timeout = 300                          # 5 minute delay (in seconds)
#         on-timeout = systemctl suspend         # Suspends system after timeout
#         on-lid-open = reset                    # Cancels suspension if lid opens
#     }
#
#    #
#    # IDLE-BASED LOCKING
#    #
#
#    # This listener warns the user that the screen is being locked in 30 seconds after 5 minutes of inactivity
#    # This listeneer also welcomes the user back after unlocking the screen with a notification
#     listener {
#         timeout = 300                          # 5 minutes of inactivity
#         on-timeout = notify-send "Locking screen in 30 seconds..."
#         on-resume = notify-send "Welcome back!"
#     }
#
#    # This listener locks the screen after 5 minutes of inactivity
#     listener {
#         timeout = 330                          # 5.5 minutes of inactivity
#         on-timeout = loginctl lock-session                  # Locks screen after warning
#     }
#   '';
# }
#
#
#     # This listener handles immediate lock on lid close
#     # listener {
#     #     device = LIBINPUT_DEVICE_LID_SWITCH    # Monitors laptop lid events
#     #     on-lid-close = hyprlock && hyprctl dispatch dpms off               # Locks immediately when lid closes
#     #     on-lid-open = hyprctl dispatch dpms on && notify-send "Welcome back!"
#     # }
