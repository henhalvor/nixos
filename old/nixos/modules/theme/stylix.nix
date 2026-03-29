{ config, pkgs, lib, userSettings, ... }:
let
  theme = import ../../../lib/theme.nix { inherit pkgs userSettings; };
in {
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    base16Scheme = theme.base16Scheme;
    image = theme.image;
    cursor = theme.cursor;
    fonts = theme.fonts;
  };
}
