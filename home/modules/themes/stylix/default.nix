{ config, pkgs, lib, userSettings, systemName, unstable, ... }:
let
  # Theme definitions
  themes = {
    catppuccin-mocha = {
      base16Scheme =
        "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    };
    nord = { base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml"; };
    dracula = {
      base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    };
    gruvbox-dark-medium = {
      base16Scheme =
        "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    };
    rose-pine-moon = {
      base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
    };
    gruvbox-dark-hard = {
      base16Scheme =
        "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
    };
    catppuccin-macchiato = {
      base16Scheme =
        "${pkgs.base16-schemes}/share/themes/catppuccin-macchiato.yaml";
    };
    # Add more themes as needed
  };

  # Get theme from user settings, fallback to catppuccin-mocha
  selectedTheme = userSettings.stylixTheme.scheme or "catppuccin-mocha";
  selectedWallpaper =
    userSettings.stylixTheme.wallpaper or "catppuccin_landscape.png";

  # Resolve wallpaper path - assumes wallpapers are in hyprpaper directory
  # Reference the assets directory - this will copy it to the Nix store
  assetsDir = ../../../../assets;
  wallpaperPath = "${assetsDir}/wallpapers/${selectedWallpaper}";

  themeConfig = themes.${selectedTheme};

in {

  # In a separate file or at the top level of your home.nix
  home.packages = with pkgs;
    [
      anki # Just the anki package, not ankiAddons
    ];
  stylix = {
    enable = true;

    # Use theme from user settings
    base16Scheme = themeConfig.base16Scheme;
    image = wallpaperPath;

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    # Fonts
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.hack;
        name = "Hack Nerd Font";
      };
      sansSerif = {
        package =
          pkgs.nerd-fonts.hack; # You can use different fonts for sans-serif
        name = "Hack Nerd Font";
      };
      serif = {
        package = pkgs.nerd-fonts.hack; # And for serif
        name = "Hack Nerd Font";
      };
      sizes = {
        applications = lib.mkDefault 11;
        desktop = lib.mkDefault 10;
        popups = lib.mkDefault 12;
        terminal = lib.mkDefault 10;
      };
    };
    # Override anki to use unstable version that has ankiAddons

  };

}
