{ config, pkgs, userSettings, lib, ... }:

{
  imports = [
    ./rofi
    ./waybar
    ./swaylock
    ./swayidle
    ./wlogout

    # ./kanshi
  ];

  home.packages = with pkgs; [
    hyprland
    # Wayland essentials
    wl-clipboard # Clipboard
    clipman # Clipboard management
    # slurp           # Screen region selector
    brightnessctl # For screen brightness control
    pamixer # For volume control
    playerctl # You already have this for media controls
    ddcutil # External monitor brightness control
    bluez # bluetooth
    blueberry
    autotiling-rs
    swaybg # Wallpaper setter
  ];

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "sway";
    XKB_DEFAULT_OPTIONS =
      "terminate:ctrl_alt_bksp,caps:escape,altwin:swap_alt_win";
    SDL_VIDEODRIVER = "wayland";

    # needs qt5.qtwayland in systemPackages
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # Fix for some Java AWT applications (e.g. Android Studio),
    # use this if they aren't displayed properly:
    _JAVA_AWT_WM_NONREPARENTING = 1;

    # gtk applications on wayland
    GDK_BACKEND = "wayland";
  };

  wayland.windowManager.sway = {
    enable = true;
    # Add extraConfig here to inject raw Sway commands
    extraConfig = ''
         # Disable default title bars and borders for new windows
      for_window [class=".*"] border none
    '';
    config = {
      # --- Disable Sway's built-in bar ---
      bars = [ ]; # Set to an empty list to disable all swaybars

      input = {
        "*" = {
          xkb_layout = "no";
          xkb_options = "caps:escape";
          tap = "enabled";
          dwt = "enabled";
          natural_scroll = "enabled";
          middle_emulation = "enabled";

        };
        "1739:52992:SYNA2BA6:00 06CB:CF00 Touchpad" = {
          tap = "enabled";
          dwt = "enabled";
          natural_scroll = "enabled";
          middle_emulation = "enabled";
        };

      };

      # --- Output Configuration ---
      output = {
        "eDP-1" = {
          scale = "1.6";
          mode = "2560x1600@90Hz";
        };
      };

      # --- Assign applications to workspaces ---
      assigns = {
        # Workspace numbers are strings here
        "1" = [
          # Add criteria for zen browser here.
          # Use app_id if available and reliable:
          {
            app_id = "zen";
          }
          # Or use class if app_id doesn't work or isn't suitable:
          # { class = "Zen"; } # Replace "Zen" with the actual class name
        ];
        # Example: Assign kitty terminal to workspace 2
        # "2" = [ { app_id = "kitty"; } ];
        # Example: Assign Firefox to workspace 3
        # "3" = [ { class = "firefox"; } ];
      };
      defaultWorkspace = "1";

      modifier = "Mod4";
      floating.modifier = "Mod4";
      floating.border = 0;
      window.border = 0;
      focus.forceWrapping = false;
      focus.followMouse = false;
      # fonts = {
      #   names = [ "RobotoMono" ];
      #   size = 9.0;
      # };
      terminal = "{userSettings.term}";
      startup = [
        # TODO change to userSettings.browser
        {
          command = "zen";
        }
        # Set wallpaper
        {
          command =
            "${pkgs.swaybg}/bin/swaybg -i ~/.dotfiles/home/modules/window-manager/hyprpaper/catpuccin_landscape.png -m fill";
        }
        # { command = "waybar"; }
        { command = "autotiling-rs"; }
        {
          # Store text entries
          command = "wl-paste --type text --watch clipman store &";
        }
        {
          # Store images
          command = "wl-paste --type image --watch clipman store &";
        }
        {
          # Bluetooth manager
          command = "blueman-applet";
        }
      ];

      menu = "${pkgs.rofi}/bin/rofi -show drun";

      keybindings = let
        modifier = config.wayland.windowManager.sway.config.modifier;
        menu = config.wayland.windowManager.sway.config.menu;
      in lib.mkOptionDefault {
        "${modifier}+Return" = "exec ${pkgs.kitty}/bin/kitty";
        "${modifier}+Shift+q" = "kill";
        "${modifier}+d" = "exec ${menu}";
        "${modifier}+Shift+c" = "reload";
        "${modifier}+o" = "clipman pick -t rofi";
        "${modifier}+Shift+o" = "clipman clear --all";
        "${modifier}+e" =
          "exec ${pkgs.kitty}/bin/kitty -e yazi, floating enable, resize set 1111 650";

        # Keybind to fix workspace 10 launching on startup (home manager bug)
        "${modifier}+0" = "exec ls";

        "XF86MonBrightnessUp" = "exec brightnessctl s +10%";
        "XF86MonBrightnessDown" = "exec brightnessctl s 10%-";
        "XF86AudioRaiseVolume" =
          "exec pactl set-sink-volume @DEFAULT_SINK@ +10%";
        "XF86AudioLowerVolume" =
          "exec pactl set-sink-volume @DEFAULT_SINK@ -10%";
        "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";

      };
    };

  };
}
