{
  config,
  lib,
  pkgs,
  userSettings,
  desktop,
  hostConfig,
  ...
}: let
  # Import scripts
  toggleMonitorsWorkstation = import ../../scripts/toggle-monitors-workstation-hyprland.nix {
    inherit pkgs;
  };
  sunshineMonitorSetup = import ../../../../nixos/modules/server/sunshine/sunshine-monitor-setup.nix {
    inherit pkgs;
  };
  sunshineMonitorRestore = import ../../../../nixos/modules/server/sunshine/sunshine-monitor-restore.nix {
    inherit pkgs;
  };
  brightnessExternal = import ../../scripts/brightness-external.nix {
    inherit pkgs;
  };

  # Get host-specific desktop config
  monitors = hostConfig.desktop.monitors or [];
  workspaceRules = hostConfig.desktop.workspaceRules or [];
  extraConfig = hostConfig.desktop.extraConfig or "";

  # Convert monitor list to Hyprland format
  monitorsConfig = lib.concatMapStringsSep "\n" (m: "monitor=${m}") monitors;

  # Determine lock command
  lockBin =
    {
      hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
      swaylock = "${pkgs.swaylock}/bin/swaylock";
      loginctl = "loginctl lock-session";
    }.${
      desktop.lock
    } or "loginctl lock-session";

  # Host-specific packages based on hostname
  hostPackages =
    if hostConfig.hostname == "workstation"
    then [
      toggleMonitorsWorkstation
      sunshineMonitorSetup
      sunshineMonitorRestore
      brightnessExternal
    ]
    else [];

  # Host-specific keybinds based on hostname
  hostBinds =
    if hostConfig.hostname == "workstation"
    then [
      "$mainMod, M, exec, toggle-monitors"
      ",XF86MonBrightnessUp,exec, brightness-external --increase"
      ",XF86MonBrightnessDown,exec, brightness-external --decrease"
    ]
    else if hostConfig.hostname == "lenovo-yoga-pro-7"
    then [
      ",XF86MonBrightnessUp,exec, brightnessctl s +10%"
      ",XF86MonBrightnessDown,exec, brightnessctl s 10%-"
    ]
    else [];

  # Host-specific input settings
  hostInput =
    if hostConfig.hostname == "lenovo-yoga-pro-7"
    then {
      touchpad = {natural_scroll = true;};
    }
    else {};

  # Host-specific decorations (battery optimization for laptops)
  hostDecorations =
    if hostConfig.hostname == "lenovo-yoga-pro-7"
    then {
      # Minimal decorations for battery life
    }
    else {
      # Full decorations for workstation
      active_opacity = 1.0;
      inactive_opacity = 1.0;
      fullscreen_opacity = 1.0;

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
      };
    };

  # Host-specific animations (battery optimization for laptops)
  hostAnimations =
    if hostConfig.hostname == "lenovo-yoga-pro-7"
    then {
      enabled = false; # Disable for battery life
    }
    else {
      # Full animations for workstation
    };

  # Host-specific exec-once commands
  hostExecOnce =
    if hostConfig.hostname == "workstation"
    then [
      "[workspace 2 silent] ${userSettings.term}"
    ]
    else [];

  # Bar-specific exec-once commands
  barExecOnce =
    if desktop.bar == "hyprpanel"
    then [
      "hyprpanel &"
    ]
    # else if desktop.bar == "waybar"
    # then [
    #   "waybar &"
    # ]
    else [];
in {
  imports = [../rofi];

  home.packages = with pkgs;
    [
      hyprland
      brightnessctl
      pamixer
      playerctl
      ddcutil
      bluez
      blueberry
    ]
    ++ hostPackages;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;

    settings = {
      # Startup commands
      exec-once =
        [
          "${userSettings.browser}"
        ]
        ++ hostExecOnce ++ barExecOnce;

      # Input configuration
      input =
        {
          kb_layout = "no";
          kb_options = "caps:escape";
          numlock_by_default = true;
          follow_mouse = 1;
          float_switch_override_focus = 0;
          mouse_refocus = 0;
          sensitivity = 0;
        }
        // hostInput;

      general = {
        "$mainMod" = "SUPER";
        layout = "dwindle";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        no_border_on_floating = false;
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
      };

      decoration =
        {
          rounding = 10;
        }
        // hostDecorations;

      animations =
        {
          bezier = [
            "fluent_decel, 0, 0.2, 0.4, 1"
            "easeOutCirc, 0, 0.55, 0.45, 1"
            "easeOutCubic, 0.33, 1, 0.68, 1"
            "fade_curve, 0, 0.55, 0.45, 1"
          ];

          animation = [
            "windowsIn,   0, 4, easeOutCubic,  popin 20%"
            "windowsOut,  0, 4, fluent_decel,  popin 80%"
            "windowsMove, 1, 2, fluent_decel, slide"
            "fadeIn,      1, 3,   fade_curve"
            "fadeOut,     1, 3,   fade_curve"
            "fadeSwitch,  0, 1,   easeOutCirc"
            "fadeShadow,  1, 10,  easeOutCirc"
            "fadeDim,     1, 4,   fluent_decel"
            "workspaces,  1, 4,   easeOutCubic, fade"
          ];
        }
        // hostAnimations;

      bind =
        [
          # Core keybindings
          "$mainMod, Return, exec, ${userSettings.term}"
          "$mainMod SHIFT, C, exec, hyprctl reload"
          "$mainMod SHIFT, Q, killactive,"
          "$mainMod, F, fullscreen, 0"
          "$mainMod, Space, exec, toggle_float"
          "$mainMod, D, exec, ${pkgs.rofi-wayland}/bin/rofi -show drun -theme ${config.home.homeDirectory}/.config/rofi/theme.rasi"
          "$mainMod, O, exec, clipboard-history"
          "$mainMod SHIFT, O, exec, clipboard-clear"
          "$mainMod, X, togglesplit,"
          "$mainMod, E, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e yazi-float'"
          "$mainMod, I, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e btop'"
          "$mainMod, B, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e bluetui'"
          "$mainMod SHIFT, L, exec, ${lockBin}"

          # Screenshot
          ",Print, exec, screenshot --copy"
          "$mainMod, Print, exec, screenshot --save"
          "$mainMod SHIFT, Print, exec, screenshot --swappy"

          # Focus movement
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"
          "$mainMod, h, movefocus, l"
          "$mainMod, j, movefocus, d"
          "$mainMod, k, movefocus, u"
          "$mainMod, l, movefocus, r"

          # Workspace switching
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

          # Move to workspace
          "$mainMod SHIFT, 1, movetoworkspacesilent, 1"
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

          # Window control
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

          # Media controls
          ",XF86AudioPlay,exec, playerctl play-pause"
          ",XF86AudioNext,exec, playerctl next"
          ",XF86AudioPrev,exec, playerctl previous"
          ",XF86AudioStop,exec, playerctl stop"

          "$mainMod, mouse_down, workspace, e-1"
          "$mainMod, mouse_up, workspace, e+1"
        ]
        ++ hostBinds;

      bindl = [];

      binde = [
        ",XF86AudioRaiseVolume,exec, pamixer -i 2"
        ",XF86AudioLowerVolume,exec, pamixer -d 2"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      windowrule = [
        "float,title:^(Transmission)$"
        "float,title:^(Volume Control)$"
        "float,title:^(Firefox — Sharing Indicator)$"
        "move 0 0,title:^(Firefox — Sharing Indicator)$"
        "size 700 450,title:^(Volume Control)$"
        "move 40 55%,title:^(Volume Control)$"
      ];

      windowrulev2 = [
        # Basic application rules
        "tile, class:^(Aseprite)$"
        "pin, class:^(rofi)$"
        "idleinhibit focus, class:^(mpv)$"

        # Firefox/Zen Picture-in-Picture rules
        "float, title:^(Picture-in-Picture)$"
        "size 480 270, title:^(Picture-in-Picture)$"
        "move 68% 70%, title:^(Picture-in-Picture)$"
        "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
        "noborder, title:^(Picture-in-Picture)$"
        "rounding 6, title:^(Picture-in-Picture)$"
        "keepaspectratio, title:^(Picture-in-Picture)$"
        "minsize 320 180, title:^(Picture-in-Picture)$"
        "maxsize 960 540, title:^(Picture-in-Picture)$"

        # More generic PiP rules
        "float, title:.*Picture.?in.?Picture.*"
        "size 480 270, title:.*Picture.?in.?Picture.*"
        "move 68% 70%, title:.*Picture.?in.?Picture.*"

        "float, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "size 480 270, class:^(firefox)$, title:^(Picture-in-Picture)$"
        "move 68% 70%, class:^(firefox)$, title:^(Picture-in-Picture)$"

        "float, class:^(zen)$, title:^(Picture-in-Picture)$"
        "size 480 270, class:^(zen)$, title:^(Picture-in-Picture)$"
        "move 68% 70%, class:^(zen)$, title:^(Picture-in-Picture)$"

        "pin, title:^(Picture-in-Picture)$"

        # Opacity settings
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

        # Floating windows
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

        # xwaylandvideobridge
        "opacity 0.0 override,class:^(xwaylandvideobridge)$"
        "noanim,class:^(xwaylandvideobridge)$"
        "noinitialfocus,class:^(xwaylandvideobridge)$"
        "maxsize 1 1,class:^(xwaylandvideobridge)$"
        "noblur,class:^(xwaylandvideobridge)$"

        # No gaps when only one window
        "bordersize 0, floating:0, onworkspace:w[t1]"
        "rounding 0, floating:0, onworkspace:w[t1]"
        "bordersize 0, floating:0, onworkspace:w[tg1]"
        "rounding 0, floating:0, onworkspace:w[tg1]"
        "bordersize 0, floating:0, onworkspace:f[1]"
        "rounding 0, floating:0, onworkspace:f[1]"

        # Remove context menu transparency
        "opaque,class:^()$,title:^()$"
        "noshadow,class:^()$,title:^()$"
        "noblur,class:^()$,title:^()$"

        # Kitty styling
        "rounding 10, class:^(kitty)$"

        # Android emulator windows
        "float, class:^(emulator64-crash-service)$"
        "float, class:^(qemu-system-x86_64)$"
        "float, class:^(Emulator)$"
        "float, title:^(Android Emulator)$"
        "float, title:^(Emulator)$"
        "size 400 800, class:^(qemu-system-x86_64)$"

        # Emulator toolbar
        "float, title:^(Extended controls)$"
        "pin, title:^(Extended controls)$"
        "stayfocused, title:^(Extended controls)$"

        # Workspace-specific window assignments
        "workspace 1, class:^(vivaldi)$"
      ];

      workspace =
        [
          "w[t1], gapsout:0, gapsin:0"
          "w[tg1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ]
        ++ workspaceRules;
    };

    extraConfig = ''
      # Monitor configuration from host
      ${monitorsConfig}

      # Additional host-specific config
      ${extraConfig}

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
    '';
  };

  # Add scripts to PATH
  home.sessionPath = ["${config.home.homeDirectory}/.local/bin"];
  home.file.".local/bin/.keep".text = "";
}
