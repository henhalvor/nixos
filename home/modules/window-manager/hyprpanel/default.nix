{ pkgs, lib, config, systemName, userSettings, ... }:
let
  # Theme mapping: stylix theme -> hyprpanel theme
  hyprpanelThemeMap = {
    # Gruvbox variants -> gruvbox theme
    gruvbox-dark-medium = "gruvbox";
    gruvbox-dark-hard = "gruvbox"; 
    
    # Catppuccin variants -> catppuccin_macchiato theme
    catppuccin-mocha = "catppuccin_macchiato";
    catppuccin-macchiato = "catppuccin_macchiato";
    
    # Fallbacks for unmapped themes -> default to gruvbox
    nord = "gruvbox";
    dracula = "gruvbox"; 
    rose-pine-moon = "gruvbox";
  };

  # Get selected theme from userSettings (passed from flake.nix)
  selectedStylixTheme = userSettings.stylixTheme.scheme or "gruvbox-dark-hard";

  # Map to hyprpanel theme, with fallback
  selectedHyprpanelTheme = hyprpanelThemeMap.${selectedStylixTheme} or "gruvbox";

  # Define system-specific configurations
  systemConfigs = {
    workstation = {
      configFile = ./workstation.json;
      extraPackages = [ ];
    };

    lenovo-yoga-pro-7 = {
      configFile = ./lenovo-yoga-pro-7.json;
      extraPackages = [ ];
    };
  };

  # Fallback if unknown system
  currentConfig =
    systemConfigs.${systemName} or systemConfigs.lenovo-yoga-pro-7;

  configTarget = "${config.home.homeDirectory}/.config/hyprpanel/config.json";

  # Dynamic theme selection based on stylix theme
  currentTheme = ./themes/${selectedHyprpanelTheme}.json;

  # Merge theme and system config dynamically
  baseConfig = builtins.fromJSON (builtins.readFile currentConfig.configFile);
  themeConfig = builtins.fromJSON (builtins.readFile currentTheme);
  mergedConfig = lib.recursiveUpdate themeConfig baseConfig;

  combinedConfigJson = pkgs.writeText "hyprpanel-merged-config.json"
    (builtins.toJSON mergedConfig);

in {

  home.packages = with pkgs; [
    grimblast # Screenshot tool for Hyprland
    wf-recorder # Screen recorder
  ];

  programs.hyprpanel.enable = true;

  home.activation.copyHyprpanelConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$(dirname "${configTarget}")"
      cp -f "${combinedConfigJson}" "${configTarget}"
    '';

}

# { inputs, ... }: {
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

