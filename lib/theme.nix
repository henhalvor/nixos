{ pkgs, userSettings }:
let
  cfg = userSettings.stylixTheme;

  schemes = {
    "catppuccin-mocha" = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    "catppuccin-macchiato" = "${pkgs.base16-schemes}/share/themes/catppuccin-macchiato.yaml";
    "gruvbox-dark-hard" = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
    "nord" = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    "dracula" = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    "rose-pine-moon" = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
  };
in {
  base16Scheme = schemes.${cfg.scheme} or (throw "Unknown scheme: ${cfg.scheme}");
  image = ../assets/wallpapers/${cfg.wallpaper};

  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  fonts = {
    monospace = { package = pkgs.nerd-fonts.hack; name = "Hack Nerd Font"; };
    sansSerif = { package = pkgs.inter; name = "Inter"; };
    serif = { package = pkgs.noto-fonts; name = "Noto Serif"; };
    sizes = { applications = 11; desktop = 11; popups = 11; terminal = 10; };
  };
}
