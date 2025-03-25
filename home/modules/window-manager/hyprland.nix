{ config, pkgs, userSettings, ... }:

{

  imports = [
    ./hyprpanel
    ./rofi
    ./hyprpaper
    ./hypridle
    ./hyprlock
    ./hyprland-services.nix
    ./kanshi
  ];



  home.packages = with pkgs; [
    hyprland
    # Wayland essentials
    wl-clipboard # Clipboard 
    clipman # Clipboard management
    # slurp           # Screen region selector
    brightnessctl   # For screen brightness control
    pamixer         # For volume control
    playerctl       # You already have this for media controls
    # nm-applet # Network manager applet (optional)
    ddcutil # External monitor brightness control
    bluez # bluetooth
    blueberry
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    # Define Hyprland configuration
    settings = {
      # autostart
      exec-once = [
        # "hash dbus-update-activation-environment 2>/dev/null"
        # "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        # "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        #
        # "nm-applet &"
        # "poweralertd &"
        "wl-paste --type text --watch clipman store &"    # Store text entries
        "wl-paste --type image --watch clipman store &"   # Store images
        "hyprpanel &"
        "hyprpaper &"
        "hypridle &" 

        #   "swaync &"
        #   "hyprctl setcursor Bibata-Modern-Ice 24 &"
        #   "swww-daemon &"
        #
          # "hyprlock"
      ];

      input = {
        kb_layout = "no";
        kb_options = "grp:alt_caps_toggle";
        numlock_by_default = true;
        follow_mouse = 1;
        float_switch_override_focus = 0;
        mouse_refocus = 0;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
        };
      };

      general = {
        "$mainMod" = "SUPER";
        layout = "dwindle";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgb(98971A) rgb(CC241D) 45deg";
        "col.inactive_border" = "0x00000000";
        border_part_of_window = false;
        no_border_on_floating = false;
       # Allow dragging with left mouse button
        resize_on_border = true;
        extend_border_grab_area = 15;
        hover_icon_on_border = true;
            };

      misc = {
        disable_autoreload = true;
        disable_hyprland_logo = true;
        always_follow_on_dnd = true;
        layers_hog_keyboard_focus = true;
        animate_manual_resizes = false;
        enable_swallow = true;
        focus_on_activate = true;
        new_window_takes_over_fullscreen = 2;
        middle_click_paste = false;
      };

      dwindle = {
        # no_gaps_when_only = false;
        force_split = 0;
        special_scale_factor = 1.0;
        split_width_multiplier = 1.0;
        use_active_for_splits = true;
        pseudotile = "yes";
        preserve_split = "yes";
      };

      master = {
        new_status = "master";
        special_scale_factor = 1;
        # no_gaps_when_only = false;
      };

      decoration = {
        # Rounding
        rounding = 10;

        # Opacity
        active_opacity = 1.0;    # Opacity for focused windows (100%)
        inactive_opacity = 0.95;  # Opacity for unfocused windows (95%)
        fullscreen_opacity = 1.0; # Opacity for fullscreen (100%)

        blur = {
          enabled = true;
          size = 3;
          passes = 2;
          brightness = 1;
          contrast = 1.4;
          ignore_opacity = true;
          noise = 0;
          new_optimizations = true;
          xray = true;
        };

        shadow = {
          enabled = true;

          ignore_window = true;
          offset = "0 2";
          range = 20;
          render_power = 3;
          color = "rgba(00000055)";
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "fluent_decel, 0, 0.2, 0.4, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutCubic, 0.33, 1, 0.68, 1"
          "fade_curve, 0, 0.55, 0.45, 1"
        ];

        animation = [
          # name, enable, speed, curve, style

          # Windows
          "windowsIn,   0, 4, easeOutCubic,  popin 20%" # window open
          "windowsOut,  0, 4, fluent_decel,  popin 80%" # window close.
          "windowsMove, 1, 2, fluent_decel, slide" # everything in between, moving, dragging, resizing.

          # Fade
          "fadeIn,      1, 3,   fade_curve" # fade in (open) -> layers and windows
          "fadeOut,     1, 3,   fade_curve" # fade out (close) -> layers and windows
          "fadeSwitch,  0, 1,   easeOutCirc" # fade on changing activewindow and its opacity
          "fadeShadow,  1, 10,  easeOutCirc" # fade on changing activewindow for shadows
          "fadeDim,     1, 4,   fluent_decel" # the easing of the dimming of inactive windows
          # "border,      1, 2.7, easeOutCirc"  # for animating the border's color switch speed
          # "borderangle, 1, 30,  fluent_decel, once" # for animating the border's gradient angle - styles: once (default), loop
          "workspaces,  1, 4,   easeOutCubic, fade" # styles: slide, slidevert, fade, slidefade, slidefadevert
        ];
      };

      bind = [
        # show keybinds list
        # "$mainMod, F1, exec, show-keybinds"

        # keybindings
        "$mainMod, Return, exec, ${userSettings.term}"
        "$mainMod SHIFT, C, exec, hyprctl reload"
        "$mainMod SHIFT, Q, killactive,"
        "$mainMod, F, fullscreen, 0"
        "$mainMod, Space, exec, toggle_float"
        "$mainMod, D, exec, rofi -show drun || pkill rofi"
        "$mainMod, O, exec, clipman pick -t rofi"
        "$mainMod SHIFT, O, exec, clipman clear --all"
        "$mainMod, X, togglesplit,"
         "$mainMod, E, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e yazi'"
        # "$mainMod SHIFT, B, exec, toggle_waybar"

        # Lock screen
        "$mainMod SHIFT, L, exec, hyprlock"


        "$mainMod SHIFT, D, exec, ~/.local/bin/toggle-laptop-display"
        "$mainMod SHIFT, M, exec, hyprctl dispatch dpms on && notify-send 'All displays forced on'"


        # screenshot
        ",Print, exec, screenshot --copy"
        "$mainMod, Print, exec, screenshot --save"
        "$mainMod SHIFT, Print, exec, screenshot --swappy"

        # External monitor brightness
        # Both monitors
        # "$mainMod, N, exec, ${config.home.homeDirectory}/.local/bin/monitor-brightness up all"
        # "$mainMod, M, exec, ${config.home.homeDirectory}/.local/bin/monitor-brightness down all"
        #
        # # Samsung monitor only (HDMI)
        # "$mainMod SHIFT, N, exec, ${config.home.homeDirectory}/.local/bin/monitor-brightness up samsung"
        # "$mainMod SHIFT, M, exec, ${config.home.homeDirectory}/.local/bin/monitor-brightness down samsung"
        #
        # # ASUS monitor only (DP)
        # "$mainMod ALT, N, exec, ${config.home.homeDirectory}/.local/bin/monitor-brightness up asus"
        # "$mainMod ALT, M, exec, ${config.home.homeDirectory}/.local/bin/monitor-brightness down asus"
        #
        # Laptop display
        # Enable built-in display
        # "$mainMod SHIFT, F, exec, hyprctl keyword monitor 'eDP-1,  2560x1600@90, 0x0, 1.6'"
        "$mainMod SHIFT, F, exec, hyprctl keyword monitor 'eDP-1, enable'"
        # Disable built-in display
        "$mainMod ALT, F, exec, hyprctl keyword monitor 'eDP-1, disable'"

        #switch focus
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod, h, movefocus, l"
        "$mainMod, j, movefocus, d"
        "$mainMod, k, movefocus, u"
        "$mainMod, l, movefocus, r"

        # switch workspace
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # same as above, but switch to the workspace
        "$mainMod SHIFT, 1, movetoworkspacesilent, 1" # movetoworkspacesilent
        "$mainMod SHIFT, 2, movetoworkspacesilent, 2"
        "$mainMod SHIFT, 3, movetoworkspacesilent, 3"
        "$mainMod SHIFT, 4, movetoworkspacesilent, 4"
        "$mainMod SHIFT, 5, movetoworkspacesilent, 5"
        "$mainMod SHIFT, 6, movetoworkspacesilent, 6"
        "$mainMod SHIFT, 7, movetoworkspacesilent, 7"
        "$mainMod SHIFT, 8, movetoworkspacesilent, 8"
        "$mainMod SHIFT, 9, movetoworkspacesilent, 9"
        "$mainMod SHIFT, 0, movetoworkspacesilent, 10"
        "$mainMod CTRL, c, movetoworkspace, empty"

        # window control
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        "$mainMod SHIFT, h, movewindow, l"
        "$mainMod SHIFT, j, movewindow, d"
        "$mainMod SHIFT, k, movewindow, u"
        "$mainMod SHIFT, l, movewindow, r"

        "$mainMod CTRL, left, resizeactive, -80 0"
        "$mainMod CTRL, right, resizeactive, 80 0"
        "$mainMod CTRL, up, resizeactive, 0 -80"
        "$mainMod CTRL, down, resizeactive, 0 80"
        "$mainMod CTRL, h, resizeactive, -80 0"
        "$mainMod CTRL, j, resizeactive, 0 80"
        "$mainMod CTRL, k, resizeactive, 0 -80"
        "$mainMod CTRL, l, resizeactive, 80 0"

        "$mainMod ALT, left, moveactive,  -80 0"
        "$mainMod ALT, right, moveactive, 80 0"
        "$mainMod ALT, up, moveactive, 0 -80"
        "$mainMod ALT, down, moveactive, 0 80"
        "$mainMod ALT, h, moveactive,  -80 0"
        "$mainMod ALT, j, moveactive, 0 80"
        "$mainMod ALT, k, moveactive, 0 -80"
        "$mainMod ALT, l, moveactive, 80 0"

        # media and volume controls
        # ",XF86AudioMute,exec, pamixer -t"
        ",XF86AudioPlay,exec, playerctl play-pause"
        ",XF86AudioNext,exec, playerctl next"
        ",XF86AudioPrev,exec, playerctl previous"
        ",XF86AudioStop,exec, playerctl stop"

        "$mainMod, mouse_down, workspace, e-1"
        "$mainMod, mouse_up, workspace, e+1"

        # clipboard manager
        "$mainMod, V, exec, cliphist list | rofi -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' | cliphist decode | wl-copy"
      ];

       # binds active in lockscreen
       bindl = [
        # Brightness
        # Control all displays together
        # Normal press: Small adjustments (5%)
        ",XF86MonBrightnessUp, exec, brightnessctl set 5%+ && ${config.home.homeDirectory}/.local/bin/monitor-brightness up all"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%- && ${config.home.homeDirectory}/.local/bin/monitor-brightness down all"
        
        # With Super key: Large adjustments
        "$mainMod, XF86MonBrightnessUp, exec, brightnessctl set 100%+ && ${config.home.homeDirectory}/.local/bin/monitor-brightness up all && ${config.home.homeDirectory}/.local/bin/monitor-brightness up all && ${config.home.homeDirectory}/.local/bin/monitor-brightness up all"
        "$mainMod, XF86MonBrightnessDown, exec, brightnessctl set 100%- && ${config.home.homeDirectory}/.local/bin/monitor-brightness down all && ${config.home.homeDirectory}/.local/bin/monitor-brightness down all && ${config.home.homeDirectory}/.local/bin/monitor-brightness down all"
             ];

       # binds that repeat when held
       binde = [
         ",XF86AudioRaiseVolume,exec, pamixer -i 2"
         ",XF86AudioLowerVolume,exec, pamixer -d 2"
       ];

      # mouse binding
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # windowrule
      windowrule = [
        "float,imv"
        "float,mpv"
        "tile,Aseprite"
        "pin,rofi"
        "idleinhibit focus,mpv"
        "float,title:^(Transmission)$"
        "float,title:^(Volume Control)$"
        "float,title:^(Firefox — Sharing Indicator)$"
        "move 0 0,title:^(Firefox — Sharing Indicator)$"
        "size 700 450,title:^(Volume Control)$"
        "move 40 55%,title:^(Volume Control)$"
      ];

      # windowrulev2
      windowrulev2 = [
        # Firefox/Zen Picture-in-Picture rules
        "float, title:^(Picture-in-Picture)$"
        "size 480 270, title:^(Picture-in-Picture)$"  # 16:9 aspect ratio at reasonable size
        "move 68% 70%, title:^(Picture-in-Picture)$"  # Position farther from right edge (68% instead of 75%)
        "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
        "noborder, title:^(Picture-in-Picture)$"
        "rounding 6, title:^(Picture-in-Picture)$"
        "keepaspectratio, title:^(Picture-in-Picture)$"
        "minsize 320 180, title:^(Picture-in-Picture)$"  # Minimum size (16:9)
        "maxsize 960 540, title:^(Picture-in-Picture)$"  # Maximum size (16:9)

        # More generic PiP rules (for other applications)
        "float, title:.*Picture.?in.?Picture.*"
        "size 480 270, title:.*Picture.?in.?Picture.*"
        "move 68% 70%, title:.*Picture.?in.?Picture.*"  # Adjusted position

        # More rules for Firefox specifically
        "float, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "size 480 270, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "move 68% 70%, class:^(firefox)$, title:^(Picture-in-Picture)$"  # Adjusted position

        # More specific rules for Zen browser if needed
        "float, class:^(zen)$, title:^(Picture-in-Picture)$"
        "size 480 270, class:^(zen)$, title:^(Picture-in-Picture)$"
        "move 68% 70%, class:^(zen)$, title:^(Picture-in-Picture)$"  # Adjusted position       

        # Add these rules to your configuration
        # "unset, pin, title:^(Picture-in-Picture)$"

        "pin, title:^(Picture-in-Picture)$"
        # "forceinput, title:^(Picture-in-Picture)$"

          # Opacity for specific windows
        "opacity 1.0 override 1.0 override, title:^(.*imv.*)$"
        "opacity 1.0 override 1.0 override, title:^(.*mpv.*)$"
        "opacity 1.0 override 1.0 override, class:(zen)"
        "workspace 1, class:^(zen)$"

        # Idle inhibit
        "idleinhibit focus, class:^(mpv)$"
        "idleinhibit fullscreen, class:^(firefox)$"
        "idleinhibit focus, class:^(firefox)$"
        "idleinhibit fullscreen, class:^(zen)$"
        "idleinhibit focus, class:^(zen)$"

        "float,class:^(org.gnome.Calculator)$"
        "float,class:^(org.gnome.FileRoller)$"
        "float,class:^(pavucontrol)$"
        "float,class:^(SoundWireServer)$"
        "float,class:^(.sameboy-wrapped)$"
        "float,class:^(file_progress)$"
        "float,class:^(confirm)$"
        "float,class:^(dialog)$"
        "float,class:^(download)$"
        "float,class:^(notification)$"
        "float,class:^(error)$"
        "float,class:^(confirmreset)$"
        "float,title:^(Open File)$"
        "float,title:^(File Upload)$"
        "float,title:^(branchdialog)$"
        "float,title:^(Confirm to replace files)$"
        "float,title:^(File Operation Progress)$"

        "opacity 0.0 override,class:^(xwaylandvideobridge)$"
        "noanim,class:^(xwaylandvideobridge)$"
        "noinitialfocus,class:^(xwaylandvideobridge)$"
        "maxsize 1 1,class:^(xwaylandvideobridge)$"
        "noblur,class:^(xwaylandvideobridge)$"

        # No gaps when only
        "bordersize 0, floating:0, onworkspace:w[t1]"
        "rounding 0, floating:0, onworkspace:w[t1]"
        "bordersize 0, floating:0, onworkspace:w[tg1]"
        "rounding 0, floating:0, onworkspace:w[tg1]"
        "bordersize 0, floating:0, onworkspace:f[1]"
        "rounding 0, floating:0, onworkspace:f[1]"

        # "maxsize 1111 700, floating: 1"
        # "center, floating: 1"

        # Remove context menu transparency in chromium based apps
        "opaque,class:^()$,title:^()$"
        "noshadow,class:^()$,title:^()$"
        "noblur,class:^()$,title:^()$"

       # Basic Kitty styling that applies always
        "rounding 10, class:^(kitty)$"   # Rounded corners for all Kitty windows
      ];

      # No gaps when only
      workspace = [
        "w[t1], gapsout:0, gapsin:0"
        "w[tg1], gapsout:0, gapsin:0"
        "f[1], gapsout:0, gapsin:0"
      ];
    };


    extraConfig = "
 
  # Clear any previous monitor settings and set defaults
  monitor=,preferred,auto,1
  
  # Define specific monitor configurations
  # Laptop built-in display
  monitor=eDP-1,2560x1600@90,0x0,1.6
  
  # Samsung Odyssey (DP-9) - Center screen with native resolution
  monitor=DP-9,2560x1440@144,0x0,1
  
  # ASUS monitor (DP-8) - Position in portrait to the left of Samsung
  monitor=DP-8,1920x1080@144,-1080x240,1,transform,1
  
  # Better startup sequence to ensure monitors turn on
  exec-once = sleep 1 && hyprctl dispatch dpms on
  
    # Suspend and resume fix
    exec-once = ${pkgs.bash}/bin/bash -c 'echo 'systemctl --user restart hyprpaper.service hyprpanel.service' > /tmp/hypr-resume-fix && systemd-inhibit --what=handle-lid-switch sleep infinity'

      xwayland {
        force_zero_scaling = true
      }

      env = QT_QPA_PLATFORM,wayland
      env = SDL_VIDEODRIVER,wayland
      env = CLUTTER_BACKEND,wayland
      env = XDG_SESSION_TYPE,wayland
      env = WLR_RENDERER,vulkan
      env = MOZ_ENABLE_WAYLAND,1
      env = WLR_NO_HARDWARE_CURSORS,0
      env = XCURSOR_SIZE,24
 
      # # env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      # # env = GBM_BACKEND,nvidia-drm
      # env = __GL_GSYNC_ALLOWED,0
      # env = __GL_VRR_ALLOWED,0
      # # env = LIBVA_DRIVER_NAME,nvidia
      # env = NVD_BACKEND,direct
      #

      source = ~/.config/hypr/colorscheme.conf
    ";


  };

  # Create the scripts directory and add it to PATH
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # Ensure the .local/bin directory exists
  home.file.".local/bin/.keep".text = "";

  home.file.".local/bin/toggle-laptop-display" = {
    executable = true;
    text = ''
      #!/bin/sh
      if hyprctl monitors | grep -A 20 "Monitor eDP-1" | grep -q "disabled: false"; then
        hyprctl keyword monitor "eDP-1,disable"
        hyprctl notify 1 5000 0 "Laptop display disabled"
      else
        hyprctl keyword monitor "eDP-1,2560x1600@90,0x0,1.6"
        hyprctl notify 1 5000 0 "Laptop display enabled"
      fi
    '';
  };

  home.file.".local/bin/monitor-brightness" = {
    executable = true;
    text = ''
      #!/bin/sh
      # Usage: monitor-brightness up|down [monitor]
      # monitor can be: samsung, asus, or all (default)
      
      SAMSUNG_BUS=4
      ASUS_BUS=5
      STEP=30
      MAX_BRIGHTNESS=255  # Maximum possible DDC/CI brightness value
      
      adjust_brightness() {
        local bus=$1
        local direction=$2
        
        # Get the full output from ddcutil for debugging
        ddcutil_output=$(ddcutil --bus=$bus getvcp 10)
        echo "Raw ddcutil output for bus $bus:"
        echo "$ddcutil_output"
        
        # Extract just the current value number, handling different output formats
        current=$(echo "$ddcutil_output" | grep -o 'current value =.*' | cut -d= -f2 | cut -d, -f1 | tr -d ' ')
        
        # If we couldn't get a valid number, start from 0
        if ! [ "$current" -eq "$current" ] 2>/dev/null; then
          echo "Could not parse current value, starting from 0"
          current=0
        fi
        
        # Calculate new brightness
        if [ "$direction" = "up" ]; then
          new_value=$((current + STEP))
          if [ $new_value -gt $MAX_BRIGHTNESS ]; then
            new_value=$MAX_BRIGHTNESS
          fi
        else
          new_value=$((current - STEP))
          if [ $new_value -lt 0 ]; then
            new_value=0
          fi
        fi
        
        echo "Adjusting monitor on bus $bus: Current=$current New=$new_value"
        ddcutil --bus=$bus setvcp 10 $new_value
      }
      
      direction=$1
      monitor=''${2:-all}
      
      case "$monitor" in
        "samsung")
          adjust_brightness $SAMSUNG_BUS "$direction"
          ;;
        "asus")
          adjust_brightness $ASUS_BUS "$direction"
          ;;
        "all")
          adjust_brightness $SAMSUNG_BUS "$direction"
          adjust_brightness $ASUS_BUS "$direction"
          ;;
        *)
          echo "Usage: monitor-brightness up|down [samsung|asus|all]"
          exit 1
          ;;
      esac
    '';
  };

}


