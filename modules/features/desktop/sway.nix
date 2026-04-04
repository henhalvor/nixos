# Sway — tiling Wayland compositor
# Source: nixos/modules/desktop/sessions/sway.nix + home/modules/desktop/sessions/sway.nix
# Template C: Colocated NixOS + HM
#
# NixOS options: my.sway.monitors (set per-host)
# Uses osConfig.networking.hostName for host-specific keybindings.
{self, ...}: {
  flake.nixosModules.sway = {
    pkgs,
    ...
  }: {
    programs.sway = {
      enable = true;
      xwayland.enable = true;
    };

    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-wlr];

    security.pam.services.swaylock = {};
    security.polkit.enable = true;

    # Common Wayland env vars are in desktopCommon; Sway sets XDG_CURRENT_DESKTOP itself

    # video group is set in the user module
    programs.light.enable = true;

    home-manager.sharedModules = [self.homeModules.sway];
  };

  flake.homeModules.sway = {
    config,
    pkgs,
    lib,
    osConfig,
    ...
  }: let
    hostname = osConfig.networking.hostName;

    terminal = config.my.desktop.terminal or "kitty";
    browser = config.my.desktop.browser or "firefox";
    lockBin = "${pkgs.swaylock}/bin/swaylock -f";

    sway-toggle-monitors = pkgs.writeShellScriptBin "sway-toggle-monitors" ''
      #!/bin/bash
      DEBUG_FILE="/tmp/sway-monitor-toggle.log"
      echo "=== Monitor Toggle Debug $(date) ===" >> "$DEBUG_FILE"

      hdmi_power=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="HDMI-A-1") | .power // false')
      dp_power=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name=="DP-1") | .power // false')

      if [[ "$hdmi_power" == "true" ]] || [[ "$dp_power" == "true" ]]; then
        echo "Turning monitors OFF" >> "$DEBUG_FILE"
        swaymsg 'output HDMI-A-1 power off' >> "$DEBUG_FILE" 2>&1
        swaymsg 'output DP-1 power off' >> "$DEBUG_FILE" 2>&1
      else
        echo "Turning monitors ON" >> "$DEBUG_FILE"
        swaymsg 'output HDMI-A-1 power on' >> "$DEBUG_FILE" 2>&1
        swaymsg 'output DP-1 power on' >> "$DEBUG_FILE" 2>&1
        sleep 2
        swaymsg 'output HDMI-A-1 scale 1 mode 2560x1440@144Hz position 1080,0 power on' >> "$DEBUG_FILE" 2>&1
        swaymsg 'output DP-1 scale 1 mode 1920x1080@143855mHz transform 270 position 0,-180 power on' >> "$DEBUG_FILE" 2>&1
        sleep 1
        swaymsg 'workspace 2, move workspace to output HDMI-A-1' >> "$DEBUG_FILE" 2>&1
        swaymsg 'workspace 1, move workspace to output DP-1' >> "$DEBUG_FILE" 2>&1
      fi
      echo "=== End Debug ===" >> "$DEBUG_FILE"
    '';

    hostPackages =
      if hostname == "workstation"
      then [sway-toggle-monitors]
      else [];

    hostKeybindings =
      if hostname == "workstation"
      then {"Mod4+m" = "exec sway-toggle-monitors";}
      else if hostname == "lenovo-yoga-pro-7"
      then {
        "XF86MonBrightnessUp" = "exec brightnessctl s +10%";
        "XF86MonBrightnessDown" = "exec brightnessctl s 10%-";
      }
      else {};

    hostInput =
      if hostname == "lenovo-yoga-pro-7"
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
    home.packages = with pkgs;
      [brightnessctl pamixer playerctl ddcutil bluez blueberry autotiling-rs swaybg]
      ++ hostPackages;

    # Wayland env vars are in desktopCommon; sway sets XDG_CURRENT_DESKTOP itself

    wayland.windowManager.sway = {
      enable = true;
      wrapperFeatures.gtk = true;

      extraConfig = ''
        for_window [class=".*"] border none
        for_window [app_id="kitty-yazi"] floating enable, resize set 1111 px 650 px, move position center, border pixel 2
        for_window [title="^Picture-in-Picture$"] floating enable, resize set 480 px 270 px, move position 100 ppt 100 ppt, move left 500 px, move up 290 px, sticky enable, border pixel 0
      '';

      config = {
        bars = [];

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
            "5426:64:Razer_Razer_Naga_2014".natural_scroll = "disabled";
          }
          // hostInput;

        assigns."1" = [{app_id = "zen";}];

        defaultWorkspace = "1";
        modifier = "Mod4";
        floating.modifier = "Mod4";
        floating.border = 0;
        window.border = 0;
        focus.forceWrapping = false;
        focus.followMouse = true;
        terminal = "${pkgs.${terminal}}/bin/${terminal}";

        startup = [
          {command = browser;}
          {command = "${pkgs.swaybg}/bin/swaybg -i ~/.dotfiles/assets/wallpapers/catpuccin_landscape.png -m fill";}
          {command = "autotiling-rs";}
          {command = "blueman-applet";}
        ];

        keybindings = let
          modifier = config.wayland.windowManager.sway.config.modifier;
        in
          lib.mkOptionDefault ({
              "${modifier}+Return" = "exec ${pkgs.kitty}/bin/kitty";
              "${modifier}+Shift+q" = "kill";
              "${modifier}+Shift+c" = "exec reload";
              "${modifier}+o" = "exec clipboard-history";
              "${modifier}+Shift+o" = "exec clipboard-clear";
              "${modifier}+e" = "exec ${pkgs.kitty}/bin/kitty --class=kitty-yazi -o background_opacity=1.0 -e yazi";
              "${modifier}+Shift+l" = "exec ${lockBin}";
              "${modifier}+0" = "exec ls";
              "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +10%";
              "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -10%";
              "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
              "${modifier}+d" = "exec ${pkgs.rofi}/bin/rofi -show drun -theme ${config.home.homeDirectory}/.config/rofi/theme.rasi";
            }
            // hostKeybindings);
      };
    };
  };
}
