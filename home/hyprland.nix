{ config, pkgs, ... }:

{
  home.sessionVariables = {
    # Wayland specific
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
  };

# Waybar configuration
  programs.waybar = {
    enable = true;
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 12pt;
        padding: 0 8px;
      }
      
      window#waybar {
        background: #292b2e;
        color: #ffffff;
      }
    '';
    settings = [{
      layer = "top";
      position = "top";
      height = 30;
      modules-left = ["hyprland/workspaces" "hyprland/window"];
      modules-center = ["clock"];
      modules-right = ["pulseaudio" "network" "battery" "tray"];
      
      "clock" = {
        format = "{:%H:%M}";
        tooltip = true;
        tooltip-format = "{:%Y-%m-%d}";
      };
      
      "battery" = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% ";
        format-plugged = "{capacity}% ";
        format-icons = ["" "" "" "" ""];
      };
    }];
  };

  # Wofi configuration
  programs.wofi = {
    enable = true;
    settings = {
      width = 600;
      height = 400;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
    };
    style = ''
      window {
        margin: 5px;
        background-color: #292b2e;
        border-radius: 15px;
      }
      
      #input {
        margin: 5px;
        background-color: #1c1f24;
        border: none;
        border-radius: 15px;
        color: white;
      }
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    settings = {
      # Startup applications
      exec-once = [
        "waybar"           # Start the status bar
        "swaync"          # Start notification daemon
      ];
      
     general = {
        "$mod" = "SUPER";
      };

      bind = [
        # Terminal
        "$mod, Return, exec, ghostty"

        # Application launcher
        "$mod, d, exec, wofi --show drun"
      ];

      input = {
        "kb_layout" = "no";
      };

    };
  };
}



