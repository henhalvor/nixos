{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      background_opacity = "0.6"; # 0.9 means 90% opaque
      # Optional: disable opacity in fullscreen
      dynamic_background_opacity = "yes";
      # Optional: if you want transparency to work well with background blur
      background_blur = "1";

      # Font settings
      font_family = "Hack Nerd Font";
      font_size = "10";

      # Optional font tweaks
      bold_font = "Hack Nerd Font Bold";
      italic_font = "Hack Nerd Font Italic";
      bold_italic_font = "Hack Nerd Font Bold Italic";
    };
  };
}
