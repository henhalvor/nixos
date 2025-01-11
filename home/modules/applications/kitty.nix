{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      family = "Fira Code";
      size = 12;
    };
    scrollback_lines = 10000;
    window_title_format = "Kitty Terminal";
  };
}
