{
  config,
  lib,
  pkgs,
  desktop,
  ...
}: let
  lockBin =
    {
      hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
      swaylock = "${pkgs.swaylock}/bin/swaylock";
      loginctl = "loginctl lock-session";
      none = "true";
    }.${
      desktop.lock
    } or "loginctl lock-session";

  colors = config.lib.stylix.colors;
in {
  home.packages = with pkgs; [
    rofi-wayland
    wl-clipboard
    libnotify
  ];

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    theme = lib.mkForce "${config.home.homeDirectory}/.config/rofi/theme.rasi";
    extraConfig = {
      modi = "drun";
      show-icons = true;
      sidebar-mode = false;
      display-drun = "Apps";
    };
  };

  home.file = {
    ".config/rofi/theme.rasi".text = ''
      @theme "~/.config/rofi/themes/glass.rasi"
    '';

    ".config/rofi/themes/glass.rasi".text = ''
      * {
          font: "${config.stylix.fonts.monospace.name} ${toString config.stylix.fonts.sizes.applications}";
      }

      window {
          background-color: rgba(${colors.base00-rgb-r}, ${colors.base00-rgb-g}, ${colors.base00-rgb-b}, 0.5);
          border: 1px;
          border-color: #${colors.base03};
          border-radius: 10px;
          padding: 10px;
          width: 550px;
          location: center;
          anchor: center;
          x-offset: 0;
          y-offset: 0;
          transparency: "real";
      }

      mainbox {
          enabled: true;
          spacing: 0px;
          padding: 0px;
          orientation: vertical;
          children: [ inputbar, listview ];
          background-color: transparent;
      }

      inputbar {
          enabled: true;
          spacing: 0px;
          padding: 8px 10px;
          margin: 0px;
          background-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.05);
          border: 0 0 1px 0;
          border-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.15);
          border-radius: 10px;
          children: [ entry ];
      }

      prompt {
          enabled: false;
      }

      entry {
          enabled: true;
          background-color: transparent;
          text-color: #${colors.base05};
          placeholder: "";
          placeholder-color: #${colors.base05};
          expand: true;
          cursor: text;
      }

      listview {
          background-color: transparent;
          border: 0px;
          padding: 0px;
          margin: 0px;
          cycle: true;
          layout: vertical;
          spacing: 0px;
          scrollbar: false;
          columns: 1;
          dynamic: true;
          lines: 8;
          fixed-height: true;
      }

      element {
          enabled: true;
          padding: 6px 8px;
          margin: 0px;
          background-color: transparent;
          text-color: #${colors.base05};
          border: 0px;
          border-radius: 10px;
          orientation: horizontal;
          children: [ element-icon, element-text ];
      }

      element-icon {
          enabled: true;
          background-color: transparent;
          size: 1.2em;
          margin: 0px 10px 0px 0px;
      }

      element-text {
          background-color: transparent;
          text-color: inherit;
          highlight: none;
          expand: true;
          vertical-align: 0.5;
          format: "{text}";
      }

      element normal.normal {
          background-color: transparent;
          text-color: #${colors.base05};
      }

      element normal.active {
          background-color: transparent;
          text-color: #${colors.base0B};
      }

      element normal.urgent {
          background-color: transparent;
          text-color: #${colors.base08};
      }

      element selected.normal {
          background-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.1);
          text-color: #${colors.base0D};
      }

      element selected.active {
          background-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.1);
          text-color: #${colors.base0B};
      }

      element selected.urgent {
          background-color: rgba(${colors.base08-rgb-r}, ${colors.base08-rgb-g}, ${colors.base08-rgb-b}, 0.2);
          text-color: #${colors.base08};
      }

      element alternate.normal {
          background-color: transparent;
          text-color: #${colors.base05};
      }

      element alternate.active {
          background-color: transparent;
          text-color: #${colors.base0B};
      }

      element alternate.urgent {
          background-color: transparent;
          text-color: #${colors.base08};
      }

      scrollbar {
          width: 4px;
          border: 0px;
          handle-width: 8px;
          padding: 0px;
          background-color: transparent;
          handle-color: #${colors.base05};
      }

      message {
          border: 0px;
          padding: 0px;
          background-color: transparent;
      }

      textbox {
          text-color: #${colors.base05};
          background-color: transparent;
      }
    '';

    ".config/rofi/scripts/wallpaper-picker.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        WALLPAPER_DIR="''${WALLPAPER_DIR:-$HOME/.dotfiles/assets/wallpapers}"
        HYPRPAPER_CONF="''${HYPRPAPER_CONF:-$HOME/.config/hypr/hyprpaper.conf}"
        HYPRLOCK_CONF="''${HYPRLOCK_CONF:-$HOME/.config/hypr/hyprlock.conf}"

        if [ ! -d "$WALLPAPER_DIR" ]; then
          notify-send "Wallpaper Picker" "Directory not found: $WALLPAPER_DIR"
          exit 0
        fi

        if ! find "$WALLPAPER_DIR" -maxdepth 1 -type f \
          \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | grep -q .; then
          notify-send "Wallpaper Picker" "No wallpapers found in $WALLPAPER_DIR"
          exit 0
        fi

        persist_wallpaper_path() {
          local conf_file="$1"
          local new_path="$2"
          local escaped_path

          [[ -f "$conf_file" ]] || return 0

          escaped_path=$(printf '%s' "$new_path" | sed 's/[\/&]/\\&/g')
          sed -i "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = $escaped_path|" "$conf_file"
        }

        CHOICE=$(
          find "$WALLPAPER_DIR" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) |
            sort |
            while IFS= read -r f; do
              printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"
            done |
            rofi -dmenu -i -show-icons \
              -p "Select Wallpaper" \
              -theme "$HOME/.config/rofi/themes/glass.rasi" \
              -theme-str '
              window {
                width: 58%;
              }

              listview {
                layout: vertical;
                columns: 3;
                fixed-columns: true;
                lines: 3;
                fixed-height: false;
                dynamic: true;
              }

              element {
                orientation: vertical;
              }

              element-icon {
                size: 200px;
                horizontal-align: 0.5;
                margin: 0px 0px 2px 0px;
              }

              element-text {
                horizontal-align: 0.5;
              }
              '
        )

        [[ -z "$CHOICE" ]] && exit 0

        WALLPAPER="$WALLPAPER_DIR/$CHOICE"
        [[ ! -f "$WALLPAPER" ]] && exit 1

        hyprctl hyprpaper preload "$WALLPAPER" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper ",$WALLPAPER" || {
          notify-send "Wallpaper Error" "hyprpaper failed"
          exit 1
        }

        persist_wallpaper_path "$HYPRPAPER_CONF" "$WALLPAPER"
        persist_wallpaper_path "$HYPRLOCK_CONF" "$WALLPAPER"

        notify-send "Wallpaper Updated" "$CHOICE" -i "$WALLPAPER"
      '';
    };

    ".local/share/applications/power-shutdown.desktop".text = ''
      [Desktop Entry]
      Name=⏻ Shutdown
      Comment=Power off the system
      Exec=systemctl poweroff
      Icon=application-exit
      Type=Application
      Categories=System;
      Terminal=false
      NoDisplay=false
    '';

    ".local/share/applications/power-reboot.desktop".text = ''
      [Desktop Entry]
      Name=🔄 Reboot
      Comment=Restart the system
      Exec=systemctl reboot
      Icon=system-reboot-symbolic
      Type=Application
      Categories=System;
      Terminal=false
      NoDisplay=false
    '';

    ".local/share/applications/power-lock.desktop".text = ''
      [Desktop Entry]
      Name=🔒 Lock Screen
      Comment=Lock the screen
      Exec=${lockBin}
      Icon=dialog-password-symbolic
      Type=Application
      Categories=System;
      Terminal=false
      NoDisplay=false
    '';

    ".local/share/applications/power-logout.desktop".text = ''
      [Desktop Entry]
      Name=📤 Logout
      Comment=End the current session
      Exec=loginctl terminate-session $XDG_SESSION_ID
      Icon=system-users-symbolic
      Type=Application
      Categories=System;
      Terminal=false
      NoDisplay=false
    '';

    ".local/share/applications/power-suspend.desktop".text = ''
      [Desktop Entry]
      Name=💤 Suspend
      Comment=Suspend the system
      Exec=systemctl suspend
      Icon=media-playback-pause
      Type=Application
      Categories=System;
      Terminal=false
      NoDisplay=false
    '';
  };
}
