# Hyprland — dynamic tiling Wayland compositor
# Source: nixos/modules/desktop/sessions/hyprland.nix + home/modules/desktop/sessions/hyprland.nix
# Template C: Colocated NixOS + HM with options
#
# NixOS options:
#   my.hyprland.monitors       — list of monitor strings (set per-host)
#   my.hyprland.workspaceRules — list of workspace rule strings (set per-host)
#   my.hyprland.extraConfig    — extra hyprland config string
#   my.hyprland.lockCommand    — lock command name (default: "hyprlock")
#   my.hyprland.launcher       — launcher name: "rofi" (default)
#   my.hyprland.bar            — bar: "hyprpanel", "" (default: "")
{self, ...}: {
  flake.nixosModules.hyprland = {
    config,
    pkgs,
    lib,
    ...
  }: let
    hyprlandSession = (pkgs.writeTextDir "share/wayland-sessions/hyprland.desktop" ''
      [Desktop Entry]
      Name=Hyprland
      Comment=An intelligent dynamic tiling Wayland compositor
      Exec=start-hyprland
      Type=Application
      DesktopNames=Hyprland
      Keywords=tiling;wayland;compositor;
    '').overrideAttrs {passthru.providedSessions = ["hyprland"];};
  in {
    options.my.hyprland = {
      monitors = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Hyprland monitor configuration strings";
      };
      workspaceRules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Hyprland workspace rules (e.g. monitor assignments)";
      };
      extraConfig = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Extra hyprland config appended to extraConfig";
      };
      lockCommand = lib.mkOption {
        type = lib.types.str;
        default = "hyprlock";
        description = "Lock screen command name (hyprlock, swaylock, loginctl)";
      };
      launcher = lib.mkOption {
        type = lib.types.str;
        default = "rofi";
        description = "Application launcher (rofi)";
      };
      bar = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Status bar to auto-start (hyprpanel, or empty for none)";
      };
    };

    config = {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-hyprland];

      security.pam.services.hyprlock = {};

      services.displayManager.sessionPackages = [hyprlandSession];

      # Common Wayland env vars are in desktopCommon; Hyprland sets XDG_CURRENT_DESKTOP itself

      # video group is set in the user module
      programs.light.enable = true;

      home-manager.sharedModules = [self.homeModules.hyprland];
    };
  };

  flake.homeModules.hyprland = {
    config,
    pkgs,
    lib,
    osConfig,
    pkgs-unstable,
    ...
  }: let
    hostname = osConfig.networking.hostName;
    hyprCfg = osConfig.my.hyprland;

    terminal = config.my.desktop.terminal or "kitty";
    browser = config.my.desktop.browser or "zen-browser";

    # Lock command resolution
    lockBin =
      {
        hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
        swaylock = "${pkgs.swaylock}/bin/swaylock";
        loginctl = "loginctl lock-session";
      }
      .${
        hyprCfg.lockCommand
      }
      or "loginctl lock-session";

    # Monitor config
    monitorsConfig = lib.concatMapStringsSep "\n" (m: "monitor=${m}") hyprCfg.monitors;

    # --- Inline scripts ---
    hyprland-toggle-monitors = pkgs.writeShellScriptBin "hyprland-toggle-monitors" ''
      #!/bin/bash
      DEBUG_FILE="/tmp/hypr-monitor-toggle.log"
      echo "=== Monitor Toggle Debug $(date) ===" >> "$DEBUG_FILE"

      HDMI_STATUS=$(hyprctl monitors -j | jq -r '.[] | select(.name=="HDMI-A-1") | .dpmsStatus')
      DP_STATUS=$(hyprctl monitors -j | jq -r '.[] | select(.name=="DP-1") | .dpmsStatus')

      HDMI_ON=$([[ "$HDMI_STATUS" == "true" ]] && echo 1 || echo 0)
      DP_ON=$([[ "$DP_STATUS" == "true" ]] && echo 1 || echo 0)

      if [[ "$HDMI_ON" -eq 1 || "$DP_ON" -eq 1 ]]; then
        echo "Turning monitors OFF" >> "$DEBUG_FILE"
        hyprctl dispatch dpms off >> "$DEBUG_FILE" 2>&1
      else
        echo "Turning monitors ON" >> "$DEBUG_FILE"
        hyprctl dispatch dpms on >> "$DEBUG_FILE" 2>&1
        sleep 2
        hyprctl keyword monitor "DP-1,2560x1440@144,1080x0,1" >> "$DEBUG_FILE" 2>&1
        hyprctl keyword monitor "HDMI-A-1,1920x1080@144,0x-180,1,transform,1" >> "$DEBUG_FILE" 2>&1
        sleep 1
        hyprctl dispatch moveworkspacetomonitor 1 HDMI-A-1 >> "$DEBUG_FILE" 2>&1
        hyprctl dispatch moveworkspacetomonitor 2 DP-1 >> "$DEBUG_FILE" 2>&1
      fi
      echo "=== End Debug ===" >> "$DEBUG_FILE"
    '';

    hyprland-brightness-external = pkgs.writeShellScriptBin "hyprland-brightness-external" ''
      #!/usr/bin/env bash
      VCP_BRIGHTNESS=10
      STEP=10
      ASUS_BUS=3
      SAMSUNG_BUS=4

      get_brightness() {
        local bus=$1
        ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" getvcp "$VCP_BRIGHTNESS" 2>/dev/null | grep -oP 'current value =\s+\K\d+'
        sleep 0.05
      }
      set_brightness() {
        local bus=$1
        local value=$2
        ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" setvcp "$VCP_BRIGHTNESS" "$value" 2>/dev/null
        sleep 0.1
      }
      increase_brightness() {
        local bus=$1
        local current=$(get_brightness "$bus")
        if [[ -n "$current" ]]; then
          local new=$((current + STEP))
          [[ $new -gt 100 ]] && new=100
          set_brightness "$bus" "$new"
        fi
      }
      decrease_brightness() {
        local bus=$1
        local current=$(get_brightness "$bus")
        if [[ -n "$current" ]]; then
          local new=$((current - STEP))
          [[ $new -lt 0 ]] && new=0
          set_brightness "$bus" "$new"
        fi
      }
      case "$1" in
        --increase|up)
          increase_brightness "$ASUS_BUS" &
          increase_brightness "$SAMSUNG_BUS" &
          wait ;;
        --decrease|down)
          decrease_brightness "$ASUS_BUS" &
          decrease_brightness "$SAMSUNG_BUS" &
          wait ;;
        *) echo "Usage: $0 {--increase|--decrease}"; exit 1 ;;
      esac
    '';

    # Host-specific packages
    hostPackages =
      if hostname == "workstation"
      then [hyprland-toggle-monitors hyprland-brightness-external]
      else [];

    # Host-specific keybinds
    hostBinds =
      if hostname == "workstation"
      then [
        "$mainMod, M, exec, hyprland-toggle-monitors"
        ",XF86MonBrightnessUp,exec, hyprland-brightness-external --increase"
        ",XF86MonBrightnessDown,exec, hyprland-brightness-external --decrease"
      ]
      else if hostname == "lenovo-yoga-pro-7"
      then [
        ",XF86MonBrightnessUp,exec, brightnessctl s +10%"
        ",XF86MonBrightnessDown,exec, brightnessctl s 10%-"
      ]
      else [];

    # Host-specific input
    hostInput =
      if hostname == "lenovo-yoga-pro-7"
      then {touchpad.natural_scroll = true;}
      else {};

    # Host-specific decorations (minimal on laptops for battery)
    hostDecorations =
      if hostname == "lenovo-yoga-pro-7"
      then {}
      else {
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        fullscreen_opacity = 1.0;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          ignore_opacity = true;
          popups = false;
          noise = 0;
          new_optimizations = true;
          xray = false;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
        };
      };

    # Host-specific animations
    hostAnimations =
      if hostname == "lenovo-yoga-pro-7"
      then {enabled = false;}
      else {};

    # Host-specific exec-once
    hostExecOnce =
      if hostname == "workstation"
      then ["[workspace 2 silent] ${terminal}"]
      else [];

    # Launcher binds
    launcherBinds =
      if hyprCfg.launcher == "rofi"
      then [
        "$mainMod, D, exec, ${pkgs.rofi}/bin/rofi -show drun"
        "$mainMod, W, exec, ${config.home.homeDirectory}/.config/rofi/scripts/wallpaper-picker.sh"
      ]
      else [];

    # Bar exec-once
    barExecOnce =
      if hyprCfg.bar == "hyprpanel"
      then ["hyprpanel &"]
      else [];
  in {
    home.packages = with pkgs;
      [brightnessctl pamixer playerctl hyprpicker ddcutil bluez blueberry]
      ++ hostPackages;

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true;
      xwayland.enable = true;
      package = pkgs-unstable.hyprland;

      settings = {
        debug.disable_logs = true;

        exec-once =
          # ["${browser}" "[workspace special:mail silent] mail"]
          hostExecOnce
          ++ barExecOnce;

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
          gaps_in = 10;
          gaps_out = 20;
          border_size = 0;
          resize_on_border = false;
          extend_border_grab_area = 15;
          hover_icon_on_border = true;
          allow_tearing = false;
        };

        misc = {
          disable_autoreload = true;
          disable_hyprland_logo = true;
          always_follow_on_dnd = true;
          layers_hog_keyboard_focus = true;
          animate_manual_resizes = false;
          enable_swallow = true;
          focus_on_activate = true;
          on_focus_under_fullscreen = 2;
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

        scrolling = {
          fullscreen_on_one_column = true;
          column_width = 0.9;
          direction = "right";
        };

        decoration =
          {
            rounding = 25;
            rounding_power = 2;
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
            "$mainMod, Return, exec, launch-terminal"
            "$mainMod SHIFT, Return, exec, launch-terminal-plain"
            "$mainMod SHIFT, C, exec, hyprctl reload"
            "$mainMod SHIFT, Q, killactive,"
            "$mainMod, F, fullscreen, 0"
          ]
          ++ launcherBinds
          ++ [
            "$mainMod, O, exec, clipboard-history"
            "$mainMod SHIFT, O, exec, clipboard-clear"
            "$mainMod, X, togglesplit,"
            "$mainMod, E, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e yazi-float'"
            "$mainMod, I, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e btop'"
            "$mainMod, B, exec, hyprctl dispatch exec '[float; size 1111 650] kitty -e bluetui'"
            "$mainMod, A, exec, hyprctl dispatch exec '[float; size 1111 650; title opencode-ai] kitty --title opencode-ai -e opencode --model github-copilot/gpt-5-mini'"
            "$mainMod SHIFT, L, exec, ${lockBin}"

            # Scrolling layout
            "$mainMod, period, layoutmsg, move +col"
            "$mainMod, comma, layoutmsg, move -col"
            "$mainMod SHIFT, period, layoutmsg, swapcol r"
            "$mainMod SHIFT, comma, layoutmsg, swapcol l"

            # Special workspaces
            "$mainMod, G, exec, toggle-thunderbird"

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

        layerrule = [
          "blur on, match:namespace notifications"
          "ignore_alpha 0, match:namespace notifications"
          "blur on, match:namespace rofi"
          "ignore_alpha 0, match:namespace rofi"
          "no_anim on, match:namespace rofi"
          "blur on, match:namespace waybar"
          "ignore_alpha 0, match:namespace waybar"
          "no_anim on, match:namespace waybar"
        ];

        windowrule = [
          "float on, match:title ^(Transmission)$"
          "float on, match:title ^(Volume Control)$"
          "float on, match:title ^(Firefox — Sharing Indicator)$"
          "move 0 0, match:title ^(Firefox — Sharing Indicator)$"
          "size 700 450, match:title ^(Volume Control)$"
          "move 40 55%, match:title ^(Volume Control)$"

          "tile on, match:class ^(Aseprite)$"
          "pin on, match:class ^(rofi)$"
          "idle_inhibit focus, match:class ^(mpv)$"

          # PiP rules
          "float on, match:title ^(Picture-in-Picture)$"
          "size 480 270, match:title ^(Picture-in-Picture)$"
          "move 68% 70%, match:title ^(Picture-in-Picture)$"
          "opacity 1.0 override 1.0 override, match:title ^(Picture-in-Picture)$"
          "border_size 0, match:title ^(Picture-in-Picture)$"
          "rounding 6, match:title ^(Picture-in-Picture)$"
          "keep_aspect_ratio on, match:title ^(Picture-in-Picture)$"
          "min_size 320 180, match:title ^(Picture-in-Picture)$"
          "max_size 960 540, match:title ^(Picture-in-Picture)$"

          "float on, match:title .*Picture.?in.?Picture.*"
          "size 480 270, match:title .*Picture.?in.?Picture.*"
          "move 68% 70%, match:title .*Picture.?in.?Picture.*"

          "float on, match:class ^(firefox)$, match:title ^(Picture-in-Picture)$"
          "size 480 270, match:class ^(firefox)$, match:title ^(Picture-in-Picture)$"
          "move 68% 70%, match:class ^(firefox)$, match:title ^(Picture-in-Picture)$"

          "float on, match:class ^(zen)$, match:title ^(Picture-in-Picture)$"
          "size 480 270, match:class ^(zen)$, match:title ^(Picture-in-Picture)$"
          "move 68% 70%, match:class ^(zen)$, match:title ^(Picture-in-Picture)$"

          "pin on, match:title ^(Picture-in-Picture)$"

          # Opacity
          "opacity 1.0 override 1.0 override, match:title ^(.*imv.*)$"
          "opacity 1.0 override 1.0 override, match:title ^(.*mpv.*)$"
          "opacity 1.0 override 1.0 override, match:class (zen)"
          "workspace 1, match:class ^(zen)$"

          # Idle inhibit
          "idle_inhibit focus, match:class ^(mpv)$"
          "idle_inhibit fullscreen, match:class ^(firefox)$"
          "idle_inhibit focus, match:class ^(firefox)$"
          "idle_inhibit fullscreen, match:class ^(zen)$"
          "idle_inhibit focus, match:class ^(zen)$"

          # Floating windows
          "float on, match:class ^(org.gnome.Calculator)$"
          "float on, match:class ^(org.gnome.FileRoller)$"
          "float on, match:class ^(pavucontrol)$"
          "float on, match:class ^(SoundWireServer)$"
          "float on, match:class ^(.sameboy-wrapped)$"
          "float on, match:class ^(file_progress)$"
          "float on, match:class ^(confirm)$"
          "float on, match:class ^(dialog)$"
          "float on, match:class ^(download)$"
          "float on, match:class ^(notification)$"
          "float on, match:class ^(error)$"
          "float on, match:class ^(confirmreset)$"
          "float on, match:title ^(Open File)$"
          "float on, match:title ^(File Upload)$"
          "float on, match:title ^(branchdialog)$"
          "float on, match:title ^(Confirm to replace files)$"
          "float on, match:title ^(File Operation Progress)$"

          # xwaylandvideobridge
          "opacity 0.0 override, match:class ^(xwaylandvideobridge)$"
          "no_anim on, match:class ^(xwaylandvideobridge)$"
          "no_initial_focus on, match:class ^(xwaylandvideobridge)$"
          "max_size 1 1, match:class ^(xwaylandvideobridge)$"
          "no_blur on, match:class ^(xwaylandvideobridge)$"

          # No gaps when only one window
          "border_size 0, match:float false, match:workspace w[t1]"
          "rounding 0, match:float false, match:workspace w[t1]"
          "border_size 0, match:float false, match:workspace w[tg1]"
          "rounding 0, match:float false, match:workspace w[tg1]"
          "border_size 0, match:float false, match:workspace f[1]"
          "rounding 0, match:float false, match:workspace f[1]"

          # Remove context menu transparency
          "opaque on, match:class ^()$, match:title ^()$"
          "no_shadow on, match:class ^()$, match:title ^()$"
          "no_blur on, match:class ^()$, match:title ^()$"

          # Kitty styling
          "rounding 10, match:class ^(kitty)$"

          # opencode AI popup
          "float on, match:title ^(opencode-ai)$"
          "size 1111 650, match:title ^(opencode-ai)$"
          "center on, match:title ^(opencode-ai)$"

          # Android emulator
          "float on, match:class ^(emulator64-crash-service)$"
          "float on, match:class ^(qemu-system-x86_64)$"
          "float on, match:class ^(Emulator)$"
          "float on, match:title ^(Android Emulator)$"
          "float on, match:title ^(Emulator)$"
          "size 400 800, match:class ^(qemu-system-x86_64)$"
          "float on, match:title ^(Extended controls)$"
          "pin on, match:title ^(Extended controls)$"
          "stay_focused on, match:title ^(Extended controls)$"

          # Workspace assignments
          "workspace 1, match:class ^(vivaldi)$"

          # Thunderbird special workspace
          "workspace special:mail silent, match:class ^(thunderbird|thunderbird-bin)$"
          "float on, match:class ^(thunderbird|thunderbird-bin)$"
          "size 1111 650, match:class ^(thunderbird|thunderbird-bin)$"
          "center on, match:class ^(thunderbird|thunderbird-bin)$"
        ];

        workspace =
          [
            "w[t1], gapsout:0, gapsin:0"
            "w[tg1], gapsout:0, gapsin:0"
          ]
          ++ hyprCfg.workspaceRules;
      };

      extraConfig = ''
        ${monitorsConfig}
        ${hyprCfg.extraConfig}

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

    home.sessionPath = ["${config.home.homeDirectory}/.local/bin"];
  };
}
