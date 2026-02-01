{ config, lib, pkgs, ... }:
let colors = config.lib.stylix.colors; in
{
  programs.swaylock = {
    enable = true;
    settings = {
      image = "${config.stylix.image}";
      scaling = "fill";
      indicator-radius = 100;
      show-failed-attempts = true;
      color = colors.base00;
      inside-color = colors.base01;
      ring-color = colors.base0D;
      key-hl-color = colors.base0B;
    };
  };
}
