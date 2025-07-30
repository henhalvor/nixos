# STEP 1: Add basic layout changes
{ inputs, ... }: {
  programs.hyprpanel = {
    enable = true;
    settings = {
      # Change layout to match your original

      bar.layouts = {
        "*" = {
          left = [ "workspaces" ];
          middle = [ "clock" ];
          right = [
            "volume"
            "media"
            "bluetooth"
            "network"
            "systray"
            "notifications"
            "battery"
            "dashboard"
          ];
        };
      };

      bar.launcher.autoDetectIcon = true;
      bar.workspaces.show_icons = true;

      # Add clock format
      bar.clock.format = "%b %d  %H:%M";

      menus.clock = {
        time = {
          military = true;
          hideSeconds = true;
        };
        weather.unit = "metric";
      };

      menus.dashboard.directories.enabled = false;
      menus.dashboard.stats.enable_gpu = false; # Keep as false for now

      theme.bar.transparent = true;

      # Change font back to your original
      theme.font = {
        name = "Hack Nerd Font"; # Changed from "JetBrains Mono"
        size = "12px"; # Changed from "16px"
      };

      # Add scaling
      scalingPriority = "hyprland";
    };
  };
} # { inputs, ... }: {
#
#   programs.hyprpanel = {
#
#     # Enable the module.
#     # Default: false
#     enable = true;
#
#     # Configure and theme almost all options from the GUI.
#     # Options that require '{}' or '[]' are not yet implemented,
#     # except for the layout above.
#     # See 'https://hyprpanel.com/configuration/settings.html'.
#     # Default: <same as gui>
#     settings = {
#
#       bar.layouts = {
#         "*" = {
#           left = [ "workspaces" ];
#           middle = [ "clock" ];
#           right = [
#             "hypridle"
#             "hyprsunset"
#             "volume"
#             "media"
#             "bluetooth"
#             "network"
#             "systray"
#             "notifications"
#             "battery"
#             "dashboard"
#           ];
#         };
#       };
#
#       bar.autoDetectIcon = true;
#       bar.map_app_icons = true;
#       bar.map_to_icons = true;
#
#       bar.general.button_radius = 99;
#
#       bar.launcher.autoDetectIcon = true;
#       bar.workspaces.show_icons = true;
#       bar.clock.format = "%b %d  %H:%M";
#
#       # Disable labels for modules
#       bar.volume.label = false;
#       bar.media.show_label = false;
#       bar.bluetooth.label = false;
#       bar.network.label = false;
#       bar.notifications.show_total = false;
#
#       # Hyprsunset
#       bar.customModules.hyprsunset.label = false;
#       bar.customModules.hyprsunset.offIcon = "󰛨";
#       bar.customModules.hyprsunset.onIcon = "󱩌";
#       bar.customModules.hyprsunset.pollingInterval = 2000;
#       bar.customModules.hyprsunset.temperature = "3500k";
#
#       # Hypridle
#       bar.customModules.hypridle.label = false;
#       bar.customModules.hypridle.offIcon = "";
#       bar.customModules.hypridle.onIcon = "";
#       bar.customModules.hypridle.pollingInterval = 2000;
#
#       menus.clock = {
#         time = {
#           military = true;
#           hideSeconds = true;
#         };
#         weather.unit = "metric";
#       };
#
#       menus.dashboard.directories.enabled = false;
#       menus.dashboard.stats.enable_gpu = true;
#
#       theme.bar.transparent = true;
#
#       theme.font = {
#         name = "Hack Nerd Font";
#         size = "12px";
#       };
#
#       # Wallpaper
#       #wallpaper.enable =  true;
#       #wallpaper.image =  "~/.dotfiles/home/modules/window-manager/hyprpanel/catpuccin_landscape.png";
#
#       # Scaling
#       scalingPriority = "hyprland";
#
#     };
#   };
# }

