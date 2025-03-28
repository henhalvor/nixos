{ config, pkgs, userSettings, lib, ... }:

{
  imports = [
    ./rofi
    ./waybar
    ./swaylock
    ./swayidle

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
    # nm-applet # Network manager applet (optional)
    ddcutil # External monitor brightness control
    bluez # bluetooth
    blueberry
    autotiling-rs
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
    config = {
      #input = {
      #"*" = {
      #"repeat_delay" = "230";
      #"repeat_rate" = "23";
      #};
      #};
      input = {
        "*" = {
          xkb_layout = "no";
          xkb_options = "caps:escape";
        };
        "SYNA2BA6:00 06CB:CF00 Touchpad" = {
          tap = true;
          dwt = true;
          natural_scroll = true;
        };
      };

      output = {
        "*" = {
          bg =
            "~/.dotfiles/home/modules/window-manager/hyprpaper/catpuccin_landscape.png fill";
        };
      };

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
        { command = "zen"; }
        { command = "waybar"; }
        { command = "autotiling-rs"; }
        {
          # Store text entries
          command = "wl-paste --type text --watch clipman store &";
        }
        {
          # Store images
          command = "wl-paste --type image --watch clipman store &";
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

        "XF86MonBrightnessDown" = "light -U 10";
        "XF86MonBrightnessUp" = "light -A 10";
        "XF86AudioRaiseVolume" = "pactl set-sink-volume @DEFAULT_SINK@ +1%";
        "XF86AudioLowerVolume" = "pactl set-sink-volume @DEFAULT_SINK@ -1%";
        "XF86AudioMute" = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
      };
    };

  };
}
