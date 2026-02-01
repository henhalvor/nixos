{ pkgs, lib, config, hostConfig, userSettings, ... }:
let
  # Theme mapping: stylix theme -> hyprpanel theme
  hyprpanelThemeMap = {
    gruvbox-dark-medium = "gruvbox";
    gruvbox-dark-hard = "gruvbox"; 
    catppuccin-mocha = "catppuccin_macchiato";
    catppuccin-macchiato = "catppuccin_macchiato";
    nord = "gruvbox";
    dracula = "gruvbox"; 
    rose-pine-moon = "gruvbox";
  };

  # Get selected theme from userSettings
  selectedStylixTheme = userSettings.stylixTheme.scheme or "gruvbox-dark-hard";
  selectedHyprpanelTheme = hyprpanelThemeMap.${selectedStylixTheme} or "gruvbox";

  # Define system-specific configurations based on hostname
  systemConfigs = {
    workstation = {
      configFile = ./hyprpanel-configs/workstation.json;
      extraPackages = [ ];
    };
    lenovo-yoga-pro-7 = {
      configFile = ./hyprpanel-configs/lenovo-yoga-pro-7.json;
      extraPackages = [ ];
    };
    "yoga-pro-7" = {
      configFile = ./hyprpanel-configs/lenovo-yoga-pro-7.json;
      extraPackages = [ ];
    };
  };

  # Fallback if unknown system
  currentConfig = systemConfigs.${hostConfig.hostname} or systemConfigs.lenovo-yoga-pro-7;

  configTarget = "${config.home.homeDirectory}/.config/hyprpanel/config.json";

  # Dynamic theme selection based on stylix theme
  currentTheme = ./hyprpanel-configs/themes/${selectedHyprpanelTheme}.json;

  # Merge theme and system config dynamically
  baseConfig = builtins.fromJSON (builtins.readFile currentConfig.configFile);
  themeConfig = builtins.fromJSON (builtins.readFile currentTheme);
  mergedConfig = lib.recursiveUpdate themeConfig baseConfig;

  combinedConfigJson = pkgs.writeText "hyprpanel-merged-config.json"
    (builtins.toJSON mergedConfig);
in {
  home.packages = with pkgs; [
    grimblast   # Screenshot tool for Hyprland
    wf-recorder # Screen recorder
  ] ++ currentConfig.extraPackages;

  programs.hyprpanel.enable = true;

  home.activation.copyHyprpanelConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$(dirname "${configTarget}")"
      cp -f "${combinedConfigJson}" "${configTarget}"
    '';
}
