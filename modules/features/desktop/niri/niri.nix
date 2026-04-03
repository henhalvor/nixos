# Niri — scrollable tiling Wayland compositor (pure Nix config)
#
# Uses nix-wrapper-modules to bake all settings into a wrapped niri package.
# Config is defined entirely in Nix — no external KDL files needed.
# The `hostVariant` option selects host-specific outputs/workspaces.
#
# Two wrapped packages are built:
#   wrappedNiri             — laptop/default variant
#   wrappedNiri-workstation — workstation variant (multi-monitor outputs)
#
# Run standalone:  nix run .#wrappedNiri
# NixOS module:    self.nixosModules.niri  (auto-selects package by hostname)
{
  self,
  inputs,
  lib,
  ...
}: let
  wallpaperPath = ../../../../assets/wallpapers/catppuccin_landscape.png;
in {
  # ── Wrapper Module ─────────────────────────────────────────────────────
  # Composable settings module consumed by wrapper-modules.wrappers.niri.wrap
  flake.wrapperModules.niriConfig = {
    config,
    lib,
    pkgs,
    ...
  }: let
    isWorkstation = config.hostVariant == "workstation";

    # Workstation-only helper: toggle HDMI-A-1 / DP-1 on/off
    toggle-monitors = pkgs.writeShellScriptBin "toggle-monitors" ''
      DEBUG_FILE="/tmp/niri-monitor-toggle.log"
      echo "=== Monitor Toggle Debug $(date) ===" >> "$DEBUG_FILE"

      outputs_json=$(niri msg --json outputs)

      get_output_enabled() {
        printf '%s' "$outputs_json" | ${pkgs.jq}/bin/jq -r --arg name "$1" '
          if type == "array" then
            any(.[]; (.name // .connector // .output // "") == $name and .current_mode != null)
          else
            .[$name].current_mode != null
          end
        '
      }

      hdmi_on=$(get_output_enabled "HDMI-A-1")
      dp_on=$(get_output_enabled "DP-1")

      echo "HDMI-A-1 enabled: $hdmi_on" >> "$DEBUG_FILE"
      echo "DP-1 enabled: $dp_on" >> "$DEBUG_FILE"

      if [[ "$hdmi_on" == "true" || "$dp_on" == "true" ]]; then
        echo "Turning monitors OFF" >> "$DEBUG_FILE"
        niri msg output HDMI-A-1 off >> "$DEBUG_FILE" 2>&1
        niri msg output DP-1 off >> "$DEBUG_FILE" 2>&1
      else
        echo "Turning monitors ON" >> "$DEBUG_FILE"
        niri msg output HDMI-A-1 on >> "$DEBUG_FILE" 2>&1
        niri msg output DP-1 on >> "$DEBUG_FILE" 2>&1
        sleep 2
      fi
      echo "=== End Debug ===" >> "$DEBUG_FILE"
    '';

    # Workstation-only helper: DDC/CI brightness for external monitors
    brightness-external = pkgs.writeShellScriptBin "brightness-external" ''
      VCP_BRIGHTNESS=10
      STEP=10
      ASUS_BUS=3
      SAMSUNG_BUS=4

      get_brightness() {
        local bus=$1
        ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" getvcp "$VCP_BRIGHTNESS" 2>/dev/null \
          | grep -oP 'current value =\s+\K\d+'
        sleep 0.05
      }
      set_brightness() {
        local bus=$1 value=$2
        ${pkgs.ddcutil}/bin/ddcutil --bus="$bus" setvcp "$VCP_BRIGHTNESS" "$value" 2>/dev/null
        sleep 0.1
      }
      increase_brightness() {
        local bus=$1 current
        current=$(get_brightness "$bus")
        if [[ -n "$current" ]]; then
          local new=$((current + STEP))
          [[ $new -gt 100 ]] && new=100
          set_brightness "$bus" "$new"
        fi
      }
      decrease_brightness() {
        local bus=$1 current
        current=$(get_brightness "$bus")
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

    # Wallpaper launcher (spawn-at-startup)
    start-wallpaper =
      pkgs.writeShellScriptBin "start-wallpaper"
      ''${lib.getExe pkgs.swaybg} -i ${wallpaperPath} -m fill'';

    # Helper to create a floating-popup window-rule for a given title
    mkFloatingPopup = {
      title,
      width ? 1111,
      height ? 650,
    }: {
      matches = [{title = "^${title}$";}];
      open-floating = true;
      default-column-width = {fixed = width;};
      default-window-height = {fixed = height;};
    };
  in {
    options = {
      terminal = lib.mkOption {
        type = lib.types.str;
        default = lib.getExe pkgs.kitty;
        description = "Terminal emulator executable path";
      };
      browser = lib.mkOption {
        type = lib.types.str;
        default = "zen-beta";
        description = "Web browser command";
      };
      hostVariant = lib.mkOption {
        type = lib.types.enum ["laptop" "workstation"];
        default = "laptop";
        description = "Host variant — selects outputs, workspace-to-output mappings, and extra binds";
      };
    };

    config = {
      v2-settings = true;

      settings = {
        # ── Input ──────────────────────────────────────────────────────
        input = {
          mod-key = "Super";
          mod-key-nested = "Alt";
          workspace-auto-back-and-forth = _: {};
          focus-follows-mouse = _: {
            props.max-scroll-amount = "0%";
          };

          keyboard = {
            xkb = {
              layout = "no";
              options = "caps:escape";
            };
            numlock = _: {};
          };

          touchpad = {
            tap = _: {};
            natural-scroll = _: {};
            dwt = _: {};
          };
        };

        # ── Layout ─────────────────────────────────────────────────────
        layout = {
          gaps = 25;
          center-focused-column = "on-overflow";
          always-center-single-column = _: {};
          default-column-width = {proportion = 0.9;};
          background-color = "transparent";

          focus-ring.off = _: {};

          border = {
            off = _: {};
            width = 0;
          };

          shadow = {
            on = _: {};
            draw-behind-window = true;
            softness = 50;
            spread = 5;
            offset = _: {
              props = {
                x = 0;
                y = 5;
              };
            };
            color = "#00000070";
          };

          tab-indicator.off = _: {};
        };

        # ── Global settings ────────────────────────────────────────────
        prefer-no-csd = _: {};
        clipboard.disable-primary = _: {};

        cursor = {
          xcursor-size = 24;
          hide-when-typing = _: {};
        };

        overview.zoom = 0.25;

        hotkey-overlay = {
          skip-at-startup = _: {};
          hide-not-bound = _: {};
        };

        screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

        environment = {
          QT_QPA_PLATFORM = "wayland";
          SDL_VIDEODRIVER = "wayland";
          CLUTTER_BACKEND = "wayland";
          XDG_SESSION_TYPE = "wayland";
          MOZ_ENABLE_WAYLAND = "1";
          XCURSOR_SIZE = "24";
        };

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        # ── Spawn at startup ───────────────────────────────────────────
        spawn-at-startup =
          [
            (lib.getExe start-wallpaper)
            config.browser
            "gmail"
          ]
          ++ lib.optionals isWorkstation [
            [config.terminal "--title" "startup-work-terminal"]
          ];

        # ── Binds ──────────────────────────────────────────────────────
        binds =
          {
            # App launchers
            "Mod+Return" = _: {
              props.repeat = false;
              content.spawn = config.terminal;
            };
            "Mod+Shift+Q" = _: {
              props.repeat = false;
              content.close-window = _: {};
            };
            "Mod+F" = _: {
              props.repeat = false;
              content.fullscreen-window = _: {};
            };
            "Mod+D" = _: {
              props.repeat = false;
              content.spawn = ["noctalia-shell" "ipc" "call" "launcher" "toggle"];
            };
            "Mod+O" = _: {
              props.repeat = false;
              content.spawn = "clipboard-history";
            };
            "Mod+Shift+O" = _: {
              props.repeat = false;
              content.spawn = "clipboard-clear";
            };
            "Mod+W" = _: {
              props.repeat = false;
              content.spawn-sh = "$HOME/.config/rofi/scripts/wallpaper-picker.sh";
            };
            "Mod+X" = _: {
              props.repeat = false;
              content.toggle-column-tabbed-display = _: {};
            };
            "Mod+V" = _: {
              props.repeat = false;
              content.toggle-window-floating = _: {};
            };
            "Mod+Shift+V" = _: {
              props.repeat = false;
              content.switch-focus-between-floating-and-tiling = _: {};
            };
            "Mod+E" = _: {
              props.repeat = false;
              content.spawn-sh = "${config.terminal} --title yazi-float -e yazi-float";
            };
            "Mod+I" = _: {
              props.repeat = false;
              content.spawn-sh = "${config.terminal} --title btop-float -e btop";
            };
            "Mod+B" = _: {
              props.repeat = false;
              content.spawn-sh = "${config.terminal} --title bluetui-float -e bluetui";
            };
            "Mod+A" = _: {
              props.repeat = false;
              content.spawn-sh = "${config.terminal} --title opencode-ai -e opencode --model github-copilot/gpt-5-mini";
            };
            "Mod+Shift+L" = _: {
              props = {
                allow-when-locked = true;
                repeat = false;
              };
              content.spawn = ["swaylock" "-f"];
            };
            "Mod+G" = _: {
              props.repeat = false;
              content.spawn-sh = "toggle-gmail";
            };

            # Screenshots (uses grim-screenshot module's `screenshot` script)
            "Print" = _: {
              props.repeat = false;
              content.spawn = ["screenshot" "--copy"];
            };
            "Mod+Print" = _: {
              props.repeat = false;
              content.spawn = ["screenshot" "--save"];
            };
            "Mod+Shift+Print" = _: {
              props.repeat = false;
              content.spawn = ["screenshot" "--swappy"];
            };

            # Focus navigation (hjkl + arrows)
            "Mod+H".focus-column-left = _: {};
            "Mod+J".focus-window-or-workspace-down = _: {};
            "Mod+K".focus-window-or-workspace-up = _: {};
            "Mod+L".focus-column-right = _: {};
            "Mod+Left".focus-column-left = _: {};
            "Mod+Right".focus-column-right = _: {};
            "Mod+Up".focus-window-or-workspace-up = _: {};
            "Mod+Down".focus-window-or-workspace-down = _: {};
            "Mod+Comma".focus-column-left = _: {};
            "Mod+Period".focus-column-right = _: {};

            # Workspace focus
            "Mod+1".focus-workspace = "1";
            "Mod+2".focus-workspace = "2";
            "Mod+3".focus-workspace = "3";
            "Mod+4".focus-workspace = "4";
            "Mod+5".focus-workspace = "5";
            "Mod+6".focus-workspace = "6";
            "Mod+7".focus-workspace = "7";
            "Mod+8".focus-workspace = "8";
            "Mod+9".focus-workspace = "9";
            "Mod+0".focus-workspace = "10";

            # Move window to workspace
            "Mod+Shift+1".move-window-to-workspace = "1";
            "Mod+Shift+2".move-window-to-workspace = "2";
            "Mod+Shift+3".move-window-to-workspace = "3";
            "Mod+Shift+4".move-window-to-workspace = "4";
            "Mod+Shift+5".move-window-to-workspace = "5";
            "Mod+Shift+6".move-window-to-workspace = "6";
            "Mod+Shift+7".move-window-to-workspace = "7";
            "Mod+Shift+8".move-window-to-workspace = "8";
            "Mod+Shift+9".move-window-to-workspace = "9";
            "Mod+Shift+0".move-window-to-workspace = "10";

            # Move columns/windows (hjkl + arrows)
            "Mod+Shift+H".move-column-left = _: {};
            "Mod+Shift+J".move-window-down = _: {};
            "Mod+Shift+K".move-window-up = _: {};
            "Mod+Shift+Left".move-column-left = _: {};
            "Mod+Shift+Right".move-column-right = _: {};
            "Mod+Shift+Up".move-window-up = _: {};
            "Mod+Shift+Down".move-window-down = _: {};
            "Mod+Shift+Comma".move-column-left = _: {};
            "Mod+Shift+Period".move-column-right = _: {};

            # Resize (Mod+Ctrl)
            "Mod+Ctrl+H".set-column-width = "-5%";
            "Mod+Ctrl+L".set-column-width = "+5%";
            "Mod+Ctrl+J".set-window-height = "+5%";
            "Mod+Ctrl+K".set-window-height = "-5%";
            "Mod+Ctrl+Left".set-column-width = "-5%";
            "Mod+Ctrl+Right".set-column-width = "+5%";
            "Mod+Ctrl+Up".set-window-height = "-5%";
            "Mod+Ctrl+Down".set-window-height = "+5%";

            # Media keys
            "XF86AudioRaiseVolume" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.pamixer} -i 2";
            };
            "XF86AudioLowerVolume" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.pamixer} -d 2";
            };
            "XF86AudioPlay" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} play-pause";
            };
            "XF86AudioNext" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} next";
            };
            "XF86AudioPrev" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} previous";
            };
            "XF86AudioStop" = _: {
              props.allow-when-locked = true;
              content.spawn-sh = "${lib.getExe pkgs.playerctl} stop";
            };

            # Laptop brightness (overridden on workstation)
            "XF86MonBrightnessUp" = _: {
              props.allow-when-locked = true;
              content.spawn = ["${lib.getExe pkgs.brightnessctl}" "s" "+10%"];
            };
            "XF86MonBrightnessDown" = _: {
              props.allow-when-locked = true;
              content.spawn = ["${lib.getExe pkgs.brightnessctl}" "s" "10%-"];
            };

            # Mouse wheel workspace navigation
            "Mod+WheelScrollDown" = _: {
              props.cooldown-ms = 150;
              content.focus-workspace-down = _: {};
            };
            "Mod+WheelScrollUp" = _: {
              props.cooldown-ms = 150;
              content.focus-workspace-up = _: {};
            };
          }
          # Workstation-only binds
          // lib.optionalAttrs isWorkstation {
            "Mod+M" = _: {
              props.repeat = false;
              content.spawn = lib.getExe toggle-monitors;
            };
            # Override laptop brightness with DDC/CI external-monitor control
            "XF86MonBrightnessUp" = _: {
              props.allow-when-locked = true;
              content.spawn = [
                (lib.getExe brightness-external)
                "--increase"
              ];
            };
            "XF86MonBrightnessDown" = _: {
              props.allow-when-locked = true;
              content.spawn = [
                (lib.getExe brightness-external)
                "--decrease"
              ];
            };
          };

        # ── Window Rules ───────────────────────────────────────────────
        window-rules =
          [
            # Global: rounded corners
            {
              geometry-corner-radius = 25;
              clip-to-geometry = true;
            }

            # Browsers open maximised on workspace 1
            {
              matches = [{app-id = "vivaldi";}];
              open-on-workspace = "1";
              open-maximized = true;
            }
            {
              matches = [{app-id = ''^zen$'';}];
              open-on-workspace = "1";
              open-maximized = true;
            }

            # Gmail PWA — startup instance goes to gmail workspace, unfocused
            {
              matches = [
                {
                  at-startup = true;
                  app-id = ''^chrome-mail\.google\.com__-Default$'';
                }
              ];
              open-on-workspace = "gmail";
              open-focused = false;
            }
            # Gmail PWA — subsequent instances float on gmail workspace
            {
              matches = [{app-id = ''^chrome-mail\.google\.com__-Default$'';}];
              open-on-workspace = "gmail";
              open-floating = true;
              default-column-width = {fixed = 1111;};
              default-window-height = {fixed = 650;};
            }

            # Picture-in-Picture
            {
              matches = [{title = "^Picture-in-Picture$";}];
              open-floating = true;
              default-column-width = {fixed = 480;};
              default-window-height = {fixed = 270;};
              default-floating-position = _: {
                props = {
                  x = 100;
                  y = 100;
                  relative-to = "bottom-right";
                };
              };
            }

            # Floating popups (terminal TUIs, etc.)
            (mkFloatingPopup {title = "yazi-float";})
            (mkFloatingPopup {title = "btop-float";})
            (mkFloatingPopup {title = "bluetui-float";})
            (mkFloatingPopup {title = "opencode-ai";})
            (mkFloatingPopup {title = "nmtui-popup";})
            (mkFloatingPopup {title = "wiremix-popup";})
            (mkFloatingPopup {title = "bluetui-popup";})

            # GNOME utilities float
            {
              matches = [{app-id = ''^org\.gnome\.Calculator$'';}];
              open-floating = true;
            }
            {
              matches = [{app-id = ''^org\.gnome\.FileRoller$'';}];
              open-floating = true;
            }

            # Pavucontrol
            {
              matches = [{app-id = ''^pavucontrol$'';}];
              open-floating = true;
              default-column-width = {fixed = 700;};
              default-window-height = {fixed = 450;};
            }

            # Misc floating
            {
              matches = [{app-id = ''^SoundWireServer$'';}];
              open-floating = true;
            }
            {
              matches = [{app-id = ''^emulator64-crash-service$'';}];
              open-floating = true;
            }
            {
              matches = [{app-id = ''^qemu-system-x86_64$'';}];
              open-floating = true;
              default-column-width = {fixed = 400;};
              default-window-height = {fixed = 800;};
            }
            {
              matches = [{app-id = ''^Emulator$'';}];
              open-floating = true;
            }
            {
              matches = [{title = "^Android Emulator$";}];
              open-floating = true;
            }
            {
              matches = [{title = "^Emulator$";}];
              open-floating = true;
            }
            {
              matches = [{title = "^Extended controls$";}];
              open-floating = true;
            }

            # Hide xwaylandvideobridge
            {
              matches = [{app-id = ''^xwaylandvideobridge$'';}];
              opacity = 0.0;
              min-width = 1;
              max-width = 1;
              min-height = 1;
              max-height = 1;
              focus-ring.off = _: {};
              shadow.off = _: {};
            }
          ]
          # Workstation: startup terminal goes to workspace 2
          ++ lib.optionals isWorkstation [
            {
              matches = [
                {
                  at-startup = true;
                  title = "^startup-work-terminal$";
                }
              ];
              open-on-workspace = "2";
              open-focused = false;
            }
          ];

        # ── Workspaces ─────────────────────────────────────────────────
        workspaces =
          if isWorkstation
          then {
            # Workstation: assign workspaces to outputs
            "1" = {open-on-output = "HDMI-A-1";};
            "2" = {open-on-output = "DP-1";};
            "3" = {open-on-output = "HDMI-A-1";};
            "4" = {open-on-output = "DP-1";};
            "5" = {open-on-output = "DP-1";};
            "6" = {open-on-output = "DP-1";};
            "7" = _: {};
            "8" = _: {};
            "9" = _: {};
            "10" = {open-on-output = "HEADLESS-1";};
            "gmail" = {open-on-output = "DP-1";};
          }
          else {
            # Laptop: plain workspaces
            "1" = _: {};
            "2" = _: {};
            "3" = _: {};
            "4" = _: {};
            "5" = _: {};
            "6" = _: {};
            "7" = _: {};
            "8" = _: {};
            "9" = _: {};
            "10" = _: {};
            "gmail" = _: {};
          };

        # ── Outputs (workstation only) ─────────────────────────────────
        outputs = lib.optionalAttrs isWorkstation {
          "HDMI-A-1" = {
            mode = "1920x1080";
            scale = 1;
            transform = "90";
            position = _: {
              props = {
                x = 0;
                y = 0;
              };
            };
          };
          "DP-1" = {
            mode = "2560x1440";
            scale = 1;
            position = _: {
              props = {
                x = 1080;
                y = 0;
              };
            };
            focus-at-startup = _: {};
          };
        };
      };
    };
  };

  # ── NixOS Module ─────────────────────────────────────────────────────
  # Enables niri as a session and selects the correct wrapped package.
  flake.nixosModules.niri = {
    pkgs,
    config,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    hostname = config.networking.hostName;
    niriPkg =
      if hostname == "workstation"
      then self.packages.${system}.wrappedNiri-workstation
      else self.packages.${system}.wrappedNiri;
  in {
    programs.niri = {
      enable = true;
      package = niriPkg;
    };

    security.pam.services.swaylock = {};
    security.polkit.enable = true;
    programs.light.enable = true;

    home-manager.sharedModules = [self.homeModules.niri];
  };

  # ── Home Manager Module ──────────────────────────────────────────────
  # Auxiliary packages needed at runtime alongside niri.
  # (brightnessctl, pamixer, playerctl are already in desktopCommon)
  flake.homeModules.niri = {pkgs, ...}: {
    home.packages = with pkgs; [
      ddcutil
      bluez
      blueberry
    ];
  };

  # ── Wrapped Packages ─────────────────────────────────────────────────
  perSystem = {pkgs, ...}: {
    packages.wrappedNiri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      imports = [self.wrapperModules.niriConfig];
    };

    packages.wrappedNiri-workstation = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      imports = [self.wrapperModules.niriConfig];
      hostVariant = "workstation";
    };
  };
}
