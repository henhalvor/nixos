{
  config,
  pkgs,
  userSettings,
  lib,
  systemName,
  ...
}: let
  # Import the script
  toggleMonitorsWorkstation = import ../scripts/toggle-monitors-workstation-hyprland.nix {
    inherit pkgs;
  };

  # Define system-specific configurations
  systemConfigs = {
    lenovo-yoga-pro-7 = {
      monitors = ''
        # Clear any previous monitor settings and set defaults
        monitor=,preferred,auto,1

        # Define specific monitor configurations
        # Laptop built-in display
        monitor=eDP-1,2560x1600@60,0x0,1.6

        # Samsung Odyssey (DP-9) - Center screen with native resolution
        monitor=DP-9,2560x1440@144,0x0,1

        # ASUS monitor (DP-8) - Position in portrait to the left of Samsung
        monitor=DP-8,1920x1080@144,-1080x240,1,transform,1
      '';

      extraBinds = [
        # Laptop-specific brightness controls
        ",XF86MonBrightnessUp,exec, brightnessctl s +10%"
        ",XF86MonBrightnessDown,exec, brightnessctl s 10%-"
      ];

      # NEW: Battery-optimized animations (LAPTOP ONLY)
      extraAnimations = {
        enabled = false; # Disable all animations for battery life
      };

      # NEW: Battery-optimized decorations (LAPTOP ONLY)
      extraDecorations = {};

      # NEW: Battery-optimized misc settings (LAPTOP ONLY)
      extraMisc = {};

      extraInput = {touchpad = {natural_scroll = true;};};

      extraPackages = [];

      extraWindowRules = [
        "workspace 1, class:^(vivaldi)$"
        # "workspace 2, class:^(kitty)$"
        # "workspace 3, class:^(code)$"
        # Laptop-specific window rules can go here
        
        # Android emulator windows - force floating for tiling WM compatibility
        "float, class:^(emulator64-crash-service)$"
        "float, class:^(qemu-system-x86_64)$"
        "float, class:^(Emulator)$"
        "float, title:^(Android Emulator)$"
        "float, title:^(Emulator)$"
        "size 400 800, class:^(qemu-system-x86_64)$"
        
        # Emulator toolbar/extended controls - critical for side panel buttons
        "float, title:^(Extended controls)$"
        "pin, title:^(Extended controls)$"
        "stayfocused, title:^(Extended controls)$"
      ];

      extraExecOnce = [
        # Better startup sequence to ensure monitors turn on
        # "sleep 1 && hyprctl dispatch dpms on"
      ];

      workspaceRules = [
        # Workspace assignments for multi-monitor setup
        # Samsung monitor (main display) - DP-9
        "2, monitor:DP-9"
        "3, monitor:DP-9"

        # ASUS monitor (portrait mode) - DP-8
        "1, monitor:DP-8"

        # Fallback for when laptop screen is active
        "1, monitor:eDP-1"
        "2, monitor:eDP-1"
        "3, monitor:eDP-1"
      ];
    };

    workstation = {
      monitors = ''
        # Clear any previous monitor settings and set defaults
        monitor=,preferred,auto,1

        # Define specific monitor configurations for workstation
        # Samsung monitor (HDMI-A-1) - Main display
        monitor=DP-1,2560x1440@144,1080x0,1

        # ASUS monitor (DP-1) - Portrait mode to the left
        monitor=HDMI-A-1,1920x1080@144,0x-180,1,transform,1
      '';

      extraBinds = [
        # Workstation-specific monitor toggle
        "$mainMod, M, exec, toggle-monitors"
      ];

      extraAnimations = {enabled = true;};

      extraDecorations = {
        # opacity
        active_opacity = 1.0; # opacity for focused windows (100%)
        inactive_opacity = 1.0; # opacity for unfocused windows (95%)
        fullscreen_opacity = 1.0; # opacity for fullscreen (100%)

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
          # color = "rgba(00000055)";
        };
      };
      extraMisc = {};

      extraInput = {
        # Workstation-specific input settings
      };

      extraPackages = [toggleMonitorsWorkstation];

      extraWindowRules = [
        # Workstation-specific workspace assignments
        "workspace 1, class:^(vivaldi)$"
        # "workspace 2, class:^(kitty)$"
        # "workspace 3, class:^(code)$"
        
        # Android emulator windows - force floating for tiling WM compatibility
        "float, class:^(emulator64-crash-service)$"
        "float, class:^(qemu-system-x86_64)$"
        "float, class:^(Emulator)$"
        "float, title:^(Android Emulator)$"
        "float, title:^(Emulator)$"
        "size 400 800, class:^(qemu-system-x86_64)$"
        
        # Emulator toolbar/extended controls - critical for side panel buttons
        "float, title:^(Extended controls)$"
        "pin, title:^(Extended controls)$"
        "stayfocused, title:^(Extended controls)$"
      ];

      extraExecOnce = [
        # Workstation-specific startup commands
        "${userSettings.term}"
      ];

      workspaceRules = [
        # Workspace assignments for multi-monitor setup

        # ASUS monitor (portrait mode) - HDMI-A-1
        "1, monitor:HDMI-A-1"

        # Samsung monitor (main display) - DP-1
        "2, monitor:DP-1"
        "3, monitor:DP-1"
      ];
    };
  };

  currentConfig =
    systemConfigs.${systemName} or systemConfigs.lenovo-yoga-pro-7;
in {
  imports = [./hyprpanel ./hyprsunset ./rofi ./hypridle ./hyprlock ./kanshi];

  home.packages = with pkgs;
    [
      hyprland
      # Wayland essentials
      wl-clipboard # Clipboard
      clipman # Clipboard management
      # slurp           # Screen region selector
      brightnessctl # For screen brightness control
      pamixer # For volume control
      playerctl # You already have this for media controls
      # nm-applet # Network manager applet (optional)
      ddcutil # External monitor brightness control
      bluez # bluetooth
      blueberry
    ]
    ++ currentConfig.extraPackages;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    # Define Hyprland configuration
    settings = {
      # autostart
      exec-once = let
        # Base startup commands that apply to all systems
        baseExecOnce = [
          # "hash dbus-update-activation-environment 2>/dev/null"
          # "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          # "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          #
          # "nm-applet &"
          # "poweralertd &"
          "wl-paste --type text --watch clipman store &" # Store text entries
          "wl-paste --type image --watch clipman store &" # Store images
          # "hyprpanel &"    # Dont manually start hyprpanel, it is started by systemd service
          "hypridle &"
          "vivaldi"

          #   "swaync &"
          #   "hyprctl setcursor Bibata-Modern-Ice 24 &"
          #   "swww-daemon &"
          #
          # "hyprlock"
        ];
      in
        baseExecOnce ++ currentConfig.extraExecOnce;

      input = let
        # Base input configuration that applies to all systems
        baseInput = {
          kb_layout = "no";
          kb_options = "grp:alt_caps_toggle";
          numlock_by_default = true;
          follow_mouse = 1;
          float_switch_override_focus = 0;
          mouse_refocus = 0;
          sensitivity = 0;
        };
      in
        baseInput // currentConfig.extraInput;

      general = {
        "$mainMod" = "SUPER";
        layout = "dwindle";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        # "col.active_border" = "rgb(98971A) rgb(CC241D) 45deg";
        # "col.inactive_border" = "0x00000000";
        no_border_on_floating = false;
        # Allow dragging with left mouse button
        resize_on_border = true;
        extend_border_grab_area = 15;
        hover_icon_on_border = true;
      };

      misc = let
        baseMisc = {
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
      in
        baseMisc // currentConfig.extraMisc;

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

      decoration = let
        baseDecoration = {
          rounding = 10; # Rounding on all windows
        };
      in
        baseDecoration // currentConfig.extraDecorations;

      animations = let
        baseAnimations = {
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
      in
        baseAnimations // currentConfig.extraAnimations;

      bind = let
        # Base keybindings that apply to all systems
        baseBinds = [
          # show keybinds list
          # "$mainMod, F1, exec, show-keybinds"

          # keybindings
          "$mainMod, Return, exec, ${userSettings.term}"
          "$mainMod SHIFT, C, exec, hyprctl reload"
          "$mainMod SHIFT, Q, killactive,"
          "$mainMod, F, fullscreen, 0"
          "$mainMod, Space, exec, toggle_float"
          "$mainMod, D, exec, ${pkgs.rofi-wayland}/bin/rofi -show drun -theme ${config.home.homeDirectory}/.config/rofi/theme.rasi"
          "$mainMod, O, exec, clipman pick -t rofi -T'-theme ${config.home.homeDirectory}/.config/rofi/theme.rasi'"
          "$mainMod SHIFT, O, exec, clipman clear --all"
          "$mainMod, X, togglesplit,"
          "$mainMod, E, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e yazi'"
          "$mainMod, B, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e btop'"
          # "$mainMod, SHIFT, L, exec, ${pkgs.hyprlock}/bin/hyprlock"
          # "$mainMod SHIFT, B, exec, toggle_waybar"

          "$mainMod SHIFT, M, exec, ${toggleMonitorsWorkstation}"

          # screenshot
          ",Print, exec, screenshot --copy"
          "$mainMod, Print, exec, screenshot --save"
          "$mainMod SHIFT, Print, exec, screenshot --swappy"

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
        ];
      in
        baseBinds ++ currentConfig.extraBinds;

      # binds active in lockscreen
      bindl = [
        # Brightness
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
        "float,title:^(Transmission)$"
        "float,title:^(Volume Control)$"
        "float,title:^(Firefox — Sharing Indicator)$"
        "move 0 0,title:^(Firefox — Sharing Indicator)$"
        "size 700 450,title:^(Volume Control)$"
        "move 40 55%,title:^(Volume Control)$"
      ];

      # windowrulev2
      windowrulev2 = let
        # Base window rules that apply to all systems
        baseWindowRules = [
          # Basic application rules
          # "float, class:^(imv)$"  #Floating image viewer
          # "float, class:^(mpv)$"  # Floating media player
          "tile, class:^(Aseprite)$"
          "pin, class:^(rofi)$"
          "idleinhibit focus, class:^(mpv)$"

          # Top and bottom margin for floating file manager launched by browser etc..
          # "float, center, size 90% 90%, margins 0 0 40 10, class:^(nautilus)$"

          # Firefox/Zen Picture-in-Picture rules
          "float, title:^(Picture-in-Picture)$"
          "size 480 270, title:^(Picture-in-Picture)$" # 16:9 aspect ratio at reasonable size
          "move 68% 70%, title:^(Picture-in-Picture)$" # Position farther from right edge (68% instead of 75%)
          "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
          "noborder, title:^(Picture-in-Picture)$"
          "rounding 6, title:^(Picture-in-Picture)$"
          "keepaspectratio, title:^(Picture-in-Picture)$"
          "minsize 320 180, title:^(Picture-in-Picture)$" # Minimum size (16:9)
          "maxsize 960 540, title:^(Picture-in-Picture)$" # Maximum size (16:9)

          # More generic PiP rules (for other applications)
          "float, title:.*Picture.?in.?Picture.*"
          "size 480 270, title:.*Picture.?in.?Picture.*"
          "move 68% 70%, title:.*Picture.?in.?Picture.*" # Adjusted position

          # More rules for Firefox specifically
          "float, class:^(firefox)$, title:^(Picture-in-Picture)$"
          "size 480 270, class:^(firefox)$, title:^(Picture-in-Picture)$"
          "move 68% 70%, class:^(firefox)$, title:^(Picture-in-Picture)$" # Adjusted position

          # More specific rules for Zen browser if needed
          "float, class:^(zen)$, title:^(Picture-in-Picture)$"
          "size 480 270, class:^(zen)$, title:^(Picture-in-Picture)$"
          "move 68% 70%, class:^(zen)$, title:^(Picture-in-Picture)$" # Adjusted position

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
          "rounding 10, class:^(kitty)$" # Rounded corners for all Kitty windows
        ];
      in
        baseWindowRules ++ currentConfig.extraWindowRules;

      # No gaps when only
      workspace = let
        # Base workspace rules that apply to all systems
        baseWorkspaceRules = [
          "w[t1], gapsout:0, gapsin:0"
          "w[tg1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ];
        # System-specific workspace rules
        systemWorkspaceRules = currentConfig.workspaceRules or [];
      in
        baseWorkspaceRules ++ systemWorkspaceRules;
    };

    extraConfig = ''
      # System-specific monitor configuration
      ${currentConfig.monitors}



      xwayland {
        force_zero_scaling = true;
      }

      env = QT_QPA_PLATFORM,wayland
      env = SDL_VIDEODRIVER,wayland
      env = CLUTTER_BACKEND,wayland
      env = XDG_SESSION_TYPE,wayland
      env = MOZ_ENABLE_WAYLAND,1
      env = WLR_NO_HARDWARE_CURSORS,1
      env = XCURSOR_SIZE,24

      # Uncomment these for NVIDIA-specific configurations
      # env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      # env = GBM_BACKEND,nvidia-drm
      # env = __GL_GSYNC_ALLOWED,0
      # env = __GL_VRR_ALLOWED,0
      # env = LIBVA_DRIVER_NAME,nvidia
      # env = NVD_BACKEND,direct

    '';
  };

  # Create the scripts directory and add it to PATH
  home.sessionPath = ["${config.home.homeDirectory}/.local/bin"];

  # Ensure the .local/bin directory exists
  home.file.".local/bin/.keep".text = "";
}
