{
  config,
  pkgs,
  userSettings,
  lib,
  ...
}: {
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
    XKB_DEFAULT_OPTIONS = "terminate:ctrl_alt_bksp,caps:escape,altwin:swap_alt_win";
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
    wrapperFeatures.gtk = true;
    # Add extraConfig here to inject raw Sway commands
    extraConfig = ''
      # Disable default title bars and borders for new windows
      for_window [class=".*"] border none

      # Disable laptop screen when lid is closed
      bindswitch --reload --locked lid:on output "eDP-1" disable
      bindswitch --reload --locked lid:off output "eDP-1" enable

       # Workspace assignments for multi-monitor setup
      # Samsung monitor (main display) "Samsung Electric Company Odyssey G52A HNMWC00587"
      workspace 2 output DP-9
      workspace 3 output DP-9

      # ASUS monitor (portrait mode) "Unknown ASUS VG24V 0x00003EBC"
      workspace 1 output DP-8

      # Fallback for when laptop screen is active
      workspace 1 output eDP-1
      workspace 2 output eDP-1
      workspace 3 output eDP-1

      # yazi floating window
      for_window [app_id="kitty-yazi"] floating enable, resize set 1111 px 650 px, move position center, border pixel 2

      # Rule for Picture-in-Picture windows (based on title)
      for_window [title="^Picture-in-Picture$"] floating enable, resize set 480 px 270 px, move position 100 ppt 100 ppt, move left 500 px, move up 290 px, sticky enable, border pixel 0

      # Optional: More specific rule targeting Firefox PiP windows (if the above is too broad)
      # You can uncomment this if needed. The (?i) makes the class match case-insensitive.
      # for_window [class="^(?i)firefox$" title="^Picture-in-Picture$"] floating enable, resize set 480 px 270 px, move position 100 ppt 100 ppt, move left 500 px, move up 290 px, sticky enable, border pixel 0

      # Optional: Rule targeting Zen browser specifically (if it uses a distinct class or app_id)
      # Adjust the class or use app_id if necessary.
      # for_window [class="^(?i)zen$" title="^Picture-in-Picture$"] floating enable, resize set 480 px 270 px, move position 100 ppt 100 ppt, move left 500 px, move up 290 px, sticky enable, border pixel 0
    '';
    config = {
      # --- Disable Sway's built-in bar ---
      bars = []; # Set to an empty list to disable all swaybars

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
        "5426:64:Razer_Razer_Naga_2014" = {natural_scroll = "disabled";};
      };

      # --- Output Configuration ---
      output = {
        "eDP-1" = {
          scale = "1.6";
          mode = "2560x1600@90Hz";
        };
        "DP-9" = {
          scale = "1";
          mode = "2560x1440@144Hz";
          position = "1080,0";
        };
        "DP-8" = {
          scale = "1";
          mode = "1920x1080";
          transform = "270";
          position = "0,-180";
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
      focus.followMouse = true;
      # fonts = {
      #   names = [ "RobotoMono" ];
      #   size = 9.0;
      # };
      terminal = "{userSettings.term}";
      startup = [
        # TODO change to userSettings.browser
        # { command = "zen"; }
        {
          command = "waybar";
        }
        # Set wallpaper
        {
          command = "${pkgs.swaybg}/bin/swaybg -i ~/.dotfiles/home/modules/window-manager/hyprpaper/catpuccin_landscape.png -m fill";
        }
        # { command = "waybar"; }
        {command = "autotiling-rs";}
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
      menu = "${pkgs.rofi-wayland}/bin/rofi -show drun -theme ${config.home.homeDirectory}/.config/rofi/theme.rasi";

      keybindings = let
        modifier = config.wayland.windowManager.sway.config.modifier;
        menu = config.wayland.windowManager.sway.config.menu;
      in
        lib.mkOptionDefault {
          "${modifier}+Return" = "exec ${pkgs.kitty}/bin/kitty";
          "${modifier}+Shift+q" = "kill";
          "${modifier}+d" = "exec ${menu}";
          "${modifier}+Shift+c" = "exec reload";
          "${modifier}+o" = "exec clipman pick -t rofi -T'-theme ${config.home.homeDirectory}/.config/rofi/theme.rasi'";
          "${modifier}+Shift+o" = "exec clipman clear --all";
          "${modifier}+e" = "exec ${pkgs.kitty}/bin/kitty --class=kitty-yazi -o background_opacity=1.0 -e yazi";

          # Keybind to fix workspace 10 launching on startup (home manager bug)
          "${modifier}+0" = "exec ls";

          "XF86MonBrightnessUp" = "exec brightnessctl s +10%";
          "XF86MonBrightnessDown" = "exec brightnessctl s 10%-";
          "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +10%";
          "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -10%";
          "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
        };
    };
  };
}
