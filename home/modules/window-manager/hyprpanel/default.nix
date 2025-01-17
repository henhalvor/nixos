{ inputs, ... }:
{
  imports = [ inputs.hyprpanel.homeManagerModules.hyprpanel ];

  programs.hyprpanel = {

    # Enable the module.
    # Default: false
    enable = true;

    # Add '/nix/store/.../hyprpanel' to your
    # Hyprland config 'exec-once'.
    # Default: false
    hyprland.enable = true;

    # Fix the overwrite issue with HyprPanel.
    # See below for more information.
    # Default: false
    overwrite.enable = true;

    # Import a theme from './themes/*.json'.
    # Default: ""
    theme = "catppuccin_macchiato";

    # Override the final config with an arbitrary set.
    # Useful for overriding colors in your selected theme.
    # Default: {}
    override = {
      theme.bar.menus.text = "#123ABC";
    };

    # Configure bar layouts for monitors.
    # See 'https://hyprpanel.com/configuration/panel.html'.
    # Default: null
    layout = {
      "bar.layouts" = {
        "0" = {
          left = [ "workspaces" ];
          middle = [ "clock" ];
          right = [ "hypridle" "hyprsunset" "volume" "media" "bluetooth" "network" "systray" "notifications" "battery" "dashboard" ];
        };
      };
    };

    # Configure and theme almost all options from the GUI.
    # Options that require '{}' or '[]' are not yet implemented,
    # except for the layout above.
    # See 'https://hyprpanel.com/configuration/settings.html'.
    # Default: <same as gui>
    settings = {
      bar.launcher.autoDetectIcon = true;
      bar.workspaces.show_icons = true;
      bar.clock.format = "%b %d  %H:%M";

      # Disable labels for modules
      bar.volume.label = false;
      bar.media.show_label = false;
      bar.bluetooth.label = false;
      bar.network.label = false;
      bar.notifications.show_total = false;

      # Hyprsunset
      bar.customModules.hyprsunset.label =  false;
      bar.customModules.hyprsunset.offIcon = "󰛨";
      bar.customModules.hyprsunset.onIcon =  "󱩌";
      bar.customModules.hyprsunset.pollingInterval =  2000;
      bar.customModules.hyprsunset.temperature =  "6000k";

      # Hypridle
bar.customModules.hypridle.label =  false;
bar.customModules.hypridle.offIcon =  "";
bar.customModules.hypridle.onIcon =  "";
bar.customModules.hypridle.pollingInterval =  2000;

      menus.clock = {
        time = {
          military = true;
          hideSeconds = true;
        };
        weather.unit = "metric";
      };

      menus.dashboard.directories.enabled = false;
      menus.dashboard.stats.enable_gpu = true;

      theme.bar.transparent = true;

      theme.font = {
        name = "CaskaydiaCove NF";
        size = "12px";
      };
      
      # Wallpaper
      wallpaper.enable =  true;
      wallpaper.image =  "~/.dotfiles/home/modules/window-manager/hyprpanel/catpuccin_landscape.png";

       # Scaling
      scalingPriority =  "hyprland";

    };
  };
}


