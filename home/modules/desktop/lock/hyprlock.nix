{ config, lib, pkgs, ... }:
{
  programs.hyprlock = {
    enable = true;
    settings = {
      background = [{
        path = "${config.stylix.image}";
        blur_passes = 2;
        blur_size = 4;
      }];
      input-field = [{
        size = "250, 50";
        outline_thickness = 2;
        fade_on_empty = true;
        placeholder_text = "Password...";
      }];
    };
  };
}
