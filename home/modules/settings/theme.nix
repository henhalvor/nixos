# DEPRECATED: using dedicated themes/ folder now
{ config, pkgs, lib, ... }:

{
  # Install theme-related packages (removed the conflicting combination)
  home.packages = with pkgs; [
    catppuccin-gtk
    catppuccin-kde
    bibata-cursors
    # Removed papirus-icon-theme and catppuccin-papirus-folders from here
  ];

  # GTK theming
  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Macchiato-Standard-Blue-Dark";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        size = "standard";
        tweaks = [ "rimless" "black" ];
        variant = "macchiato";
      };
    };
    iconTheme = {
      # Use Papirus-Dark with Catppuccin folders
      name = "Papirus-Dark";
      # This is the proper way to get Papirus with Catppuccin folders
      package = pkgs.catppuccin-papirus-folders.override {
        flavor =
          "macchiato"; # You can change to any flavor: latte, frappe, macchiato, mocha
        accent = "blue"; # You can change to any accent color
      };
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  # QT theming
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "gtk2";
  };

  # Rest of the file remains unchanged
  # Hyprland specific styling
  home.file.".config/hypr/colorscheme.conf".text = ''
    # Catppuccin Macchiato colors for Hyprland
    $rosewater = 0xfff4dbd6
    $flamingo  = 0xfff0c6c6
    $pink      = 0xfff5bde6
    $mauve     = 0xffc6a0f6
    $red       = 0xffed8796
    $maroon    = 0xffee99a0
    $peach     = 0xfff5a97f
    $yellow    = 0xffeed49f
    $green     = 0xffa6da95
    $teal      = 0xff8bd5ca
    $sky       = 0xff91d7e3
    $sapphire  = 0xff7dc4e4
    $blue      = 0xff8aadf4
    $lavender  = 0xffb7bdf8
    $text      = 0xffcad3f5
    $subtext1  = 0xffb8c0e0
    $subtext0  = 0xffa5adcb
    $overlay2  = 0xff939ab7
    $overlay1  = 0xff8087a2
    $overlay0  = 0xff6e738d
    $surface2  = 0xff5b6078
    $surface1  = 0xff494d64
    $surface0  = 0xff363a4f
    $base      = 0xff24273a
    $mantle    = 0xff1e2030
    $crust     = 0xff181926
  '';

  # Add to hyprland config (you'll need to source this file in your main hyprland conf)
  home.file.".config/hypr/hyprland-colors.conf".text = ''
    source = ~/.config/hypr/colorscheme.conf

    # Set window decoration colors
    general {
      # See https://wiki.hyprland.org/Configuring/Variables/ for more
      border_size = 2
      col.active_border = $lavender $mauve 45deg
      col.inactive_border = $overlay0
      
      gaps_in = 5
      gaps_out = 10
    }

    # Set window opacity
    decoration {
      rounding = 10
      active_opacity = 1.0
      inactive_opacity = 0.9
      
      drop_shadow = true
      shadow_range = 4
      shadow_render_power = 3
      col.shadow = rgba(1a1a1aee)
    }
  '';
}
