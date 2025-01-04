{ config, pkgs, ... }:

{
  home.sessionVariables = {
    # Wayland specific
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    settings = {
      "$mod" = "SUPER";
      
      monitor = [
        "eDP-1,2560x1600@60,0x0,1"
      ];
      
      exec-once = [
        "waybar"
        "dunst"
      ];
      
      bind = [
        "$mod, Return, exec, ghostty"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, E, exec, wofi --show drun"
        "$mod, V, togglefloating"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"
        
        # Move focus with mod + arrow keys
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
      ];
    };
  };

  # Fixing problems with themes: https://wiki.hyprland.org/Nix/Hyprland-on-Home-Manager/
   home.pointerCursor = {
      gtk.enable = true;
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 16;
    };

  gtk = {
    enable = true;

    theme = {
      package = pkgs.flat-remix-gtk;
      name = "Flat-Remix-GTK-Grey-Darkest";
    };

    iconTheme = {
      package = pkgs.gnome.adwaita-icon-theme;
      name = "Adwaita";
    };

    font = {
      name = "Sans";
      size = 11;
    };
  };

  # Fix for programs that don’t work in systemd services, but do on the terminal 
  wayland.windowManager.hyprland.systemd.variables = ["--all"];
}
