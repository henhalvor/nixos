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
  toggleMonitorsWorkstation = import ../../scripts/toggle-monitors-workstation-sway.nix {
    inherit pkgs;
  };

  # Get host-specific desktop config
  outputs = hostConfig.desktop.outputs or {};
  extraConfig = hostConfig.desktop.extraConfig or "";

  # Determine lock command
  lockBin =
    {
      hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
      swaylock = "${pkgs.swaylock}/bin/swaylock -f";
      loginctl = "loginctl lock-session";
    }.${
      desktop.lock
    } or "loginctl lock-session";

  # Host-specific packages
  hostPackages =
    if hostConfig.hostname == "workstation"
    then [
      toggleMonitorsWorkstation
    ]
    else [];

  # Host-specific keybindings
  hostKeybindings =
    if hostConfig.hostname == "workstation"
    then {
      "Mod4+m" = "exec toggle-monitors";
    }
    else if hostConfig.hostname == "lenovo-yoga-pro-7"
    then {
      "XF86MonBrightnessUp" = "exec brightnessctl s +10%";
      "XF86MonBrightnessDown" = "exec brightnessctl s 10%-";
    }
    else {};

  # Host-specific input settings
  hostInput =
    if hostConfig.hostname == "lenovo-yoga-pro-7"
    then {
      "1739:52992:SYNA2BA6:00 06CB:CF00 Touchpad" = {
        tap = "enabled";
        dwt = "enabled";
        natural_scroll = "enabled";
        middle_emulation = "enabled";
      };
    }
    else {};
in {
  imports = [../rofi];

  home.packages = with pkgs;
    [
      # sway
      brightnessctl
      pamixer
      playerctl
      ddcutil
      bluez
      blueberry
      autotiling-rs
      swaybg
    ]
    ++ hostPackages;

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "sway";
    XKB_DEFAULT_OPTIONS = "terminate:ctrl_alt_bksp,caps:escape,altwin:swap_alt_win";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = 1;
    GDK_BACKEND = "wayland";
  };

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;

    extraConfig = ''
      # Host-specific configuration
      ${extraConfig}

      # Disable default title bars and borders for new windows
      for_window [class=".*"] border none

      # yazi floating window
      for_window [app_id="kitty-yazi"] floating enable, resize set 1111 px 650 px, move position center, border pixel 2

      # Picture-in-Picture windows
      for_window [title="^Picture-in-Picture$"] floating enable, resize set 480 px 270 px, move position 100 ppt 100 ppt, move left 500 px, move up 290 px, sticky enable, border pixel 0
    '';

    config = {
      bars = []; # Disable built-in bar

      input =
        {
          "*" = {
            xkb_layout = "no";
            xkb_options = "caps:escape";
            tap = "enabled";
            dwt = "enabled";
            natural_scroll = "enabled";
            middle_emulation = "enabled";
          };
          "5426:64:Razer_Razer_Naga_2014" = {
            natural_scroll = "disabled";
          };
        }
        // hostInput;

      output = outputs;

      assigns = {
        "1" = [{app_id = "zen";}];
      };

      defaultWorkspace = "1";
      modifier = "Mod4";
      floating.modifier = "Mod4";
      floating.border = 0;
      window.border = 0;
      focus.forceWrapping = false;
      focus.followMouse = true;
      terminal = "${userSettings.term}";

      startup = [
        {command = "${userSettings.browser}";}
        # {command = "waybar";} # waybar is systemd service
        {command = "${pkgs.swaybg}/bin/swaybg -i ~/.dotfiles/assets/wallpapers/catpuccin_landscape.png -m fill";}
        {command = "autotiling-rs";}
        {command = "blueman-applet";}
      ];

      menu = "${pkgs.rofi}/bin/rofi -show drun -theme ${config.home.homeDirectory}/.config/rofi/theme.rasi";

      keybindings = let
        modifier = config.wayland.windowManager.sway.config.modifier;
        menu = config.wayland.windowManager.sway.config.menu;

        baseKeybindings = {
          "${modifier}+Return" = "exec ${pkgs.kitty}/bin/kitty";
          "${modifier}+Shift+q" = "kill";
          "${modifier}+d" = "exec ${menu}";
          "${modifier}+Shift+c" = "exec reload";
          "${modifier}+o" = "exec clipboard-history";
          "${modifier}+Shift+o" = "exec clipboard-clear";
          "${modifier}+e" = "exec ${pkgs.kitty}/bin/kitty --class=kitty-yazi -o background_opacity=1.0 -e yazi";
          "${modifier}+Shift+l" = "exec ${lockBin}";

          # Fix workspace 10 launching on startup (home manager bug)
          "${modifier}+0" = "exec ls";

          # Audio
          "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +10%";
          "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -10%";
          "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
        };
      in
        lib.mkOptionDefault (baseKeybindings // hostKeybindings);
    };
  };
}
