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
      "$mod1" = "ALT";
      
      # Monitor configuration
      monitor = [
        "eDP-1,2560x1600@60,0x0,1"
        "desc:Samsung Electric Company Odyssey G52A HNMWC00587,2560x1440@144,1080x0,1"
        "desc:Unknown ASUS VG24V 0x00003EBC,1920x1080@144,0x-180,1,transform,1" # transform,1 is 90 degrees rotation
      ];

      # Input configuration
      input = {
        kb_layout = "no"
        kb_options = "caps:escape"
        
        touchpad = {
          natural_scroll = true
          tap-to-click = true
          drag_lock = true
          disable_while_typing = true
          middle_button_emulation = true
        }
      };

      # For all categories, see https://wiki.hyprland.org/Configuring/Variables/
      general {
        gaps_in = 5
        gaps_out = 10
        border_size = 2
        layout = "dwindle"
        # Reduce animations
        no_animation_overlays = true
      }

      decoration {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        rounding = 5
        blur {
            enabled = true
            size = 3
            passes = 1
            new_optimizations = true
        }
        drop_shadow = true
        shadow_range = 4
        shadow_render_power = 3
      }

      animations {
        enabled = true
        # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05"
        animation = "windows, 1, 7, myBezier"
        animation = "windowsOut, 1, 7, default, popin 80%"
        animation = "border, 1, 10, default"
        animation = "fade, 1, 7, default"
        animation = "workspaces, 1, 6, default"
      }

      dwindle {
        pseudotile = true
        preserve_split = true
      }
      
      exec-once = [
        "waybar"
        "dunst"
      ];
      
      bind = [
        # Terminal
        "$mod, Return, exec, ghostty"
        "$mod SHIFT, z, exec, alacritty -e zellij -l welcome"
        
        # Window management
        "$mod SHIFT, q, killactive"
        "$mod SHIFT, e, exit"
        "$mod, E, exec, wofi --show drun"
        "$mod SHIFT, space, togglefloating"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"
        "$mod, F, fullscreen"
        "$mod, space, focusurgentorlast"
        "$mod, a, focusurgentorlast" # Similar to focus parent
        
        # Move focus
        "$mod, h, movefocus, l"
        "$mod, j, movefocus, d"
        "$mod, k, movefocus, u"
        "$mod, l, movefocus, r"
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        
        # Move windows
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, j, movewindow, d"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, l, movewindow, r"
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        
        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        
        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        
        # Vim-style workspace switching
        "$mod CTRL, h, workspace, e-1"
        "$mod CTRL, l, workspace, e+1"
        "$mod1, h, workspace, e-1"
        "$mod1, l, workspace, e+1"
        
        # Scratchpad
        "$mod SHIFT, minus, movetoworkspace, special"
        "$mod, minus, togglespecialworkspace"
        
        # Clipboard manager
        "$mod, o, exec, clipman pick -t wofi"
        "$mod SHIFT, o, exec, clipman clear --all"
      ];

      # Bind volume keys
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"
      ];
      
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];

      # Bind brightness keys
      bindel = [
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Workspace rules for monitors
      workspace = [
        "1, monitor:desc:Unknown ASUS VG24V 0x00003EBC"
        "2, monitor:desc:Samsung Electric Company Odyssey G52A HNMWC00587"
        "3, monitor:desc:Samsung Electric Company Odyssey G52A HNMWC00587"
        # Fallback rules
        "1, monitor:eDP-1"
        "2, monitor:eDP-1"
        "3, monitor:eDP-1"
      ];
    };
  };

}
