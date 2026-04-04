# Hyprpanel — status bar for Hyprland
# Source: home/modules/desktop/bars/hyprpanel.nix
# Template B2: HM-only with host-specific configs + theme mapping
#
# Config files in hyprpanel-configs/ (per-host JSON + theme JSON).
# Uses osConfig.networking.hostName and osConfig.my.theme.scheme.
{self, ...}: {
  flake.nixosModules.hyprpanel = {...}: {
    home-manager.sharedModules = [self.homeModules.hyprpanel];
  };

  flake.homeModules.hyprpanel = {
    pkgs,
    lib,
    osConfig,
    ...
  }: let
    # Theme mapping: stylix scheme → hyprpanel theme
    hyprpanelThemeMap = {
      gruvbox-dark-medium = "gruvbox";
      gruvbox-dark-hard = "gruvbox";
      catppuccin-mocha = "catppuccin_macchiato";
      catppuccin-macchiato = "catppuccin_macchiato";
      nord = "gruvbox";
      dracula = "gruvbox";
      rose-pine-moon = "gruvbox";
    };

    selectedStylixTheme = osConfig.my.theme.scheme or "gruvbox-dark-hard";
    selectedHyprpanelTheme = hyprpanelThemeMap.${selectedStylixTheme} or "gruvbox";

    hostname = osConfig.networking.hostName;

    systemConfigs = {
      workstation.configFile = ./workstation.json;
      lenovo-yoga-pro-7.configFile = ./lenovo-yoga-pro-7.json;
    };

    currentConfig = systemConfigs.${hostname} or systemConfigs.lenovo-yoga-pro-7;
    currentTheme = ./themes/${selectedHyprpanelTheme}.json;

    baseConfig = builtins.fromJSON (builtins.readFile currentConfig.configFile);
    themeConfig = builtins.fromJSON (builtins.readFile currentTheme);
    mergedConfig = lib.recursiveUpdate themeConfig baseConfig;
    mergedConfigFile = pkgs.writeText "hyprpanel-config.json" (builtins.toJSON mergedConfig);
  in {
    home.packages = with pkgs; [hyprpanel grimblast wf-recorder];
    xdg.configFile."hyprpanel/config.json".source = mergedConfigFile;
  };
}
