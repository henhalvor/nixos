{ config, pkgs, userSettings, windowManager ? "hyprland", ... }:
let
  inherit (config.lib.stylix) colors;

  # Choose lock command based on window manager
  lockCommand = if windowManager == "hyprland" then
    "${pkgs.hyprlock}/bin/hyprlock"
  else if windowManager == "sway" then
    "${pkgs.swaylock}/bin/swaylock -f"
  else
    "loginctl lock-session";
in {
  home.packages = with pkgs; [ rofi-wayland ];

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
  };
  #
  home.file.".config/rofi/theme.rasi".text = ''

      /*****----- Configuration -----*****/
      configuration {
      	modi:                       "drun,run,filebrowser,window";
          show-icons:                 true;
          display-drun:               "APPS";
          display-run:                "RUN";
          display-filebrowser:        "FILES";
          display-window:             "WINDOW";
      	drun-display-format:        "{name}";
      	window-format:              "{w} · {c} · {t}";
      }

      /*****----- Global Properties -----*****/
    * {
          font:                        "${config.stylix.fonts.monospace.name} ${
            toString config.stylix.fonts.sizes.applications
          }";
          background:                  #${colors.base00};
          background-alt:              #${colors.base01};
          foreground:                  #${colors.base05};
          selected:                    #${colors.base0D};
          active:                      #${colors.base0B};
          urgent:                      #${colors.base08};
      }

      /*****----- Main Window -----*****/
      window {
          /* properties for window widget */
          transparency:                "real";
          location:                    center;
          anchor:                      center;
          fullscreen:                  false;
          width:                       1000px;
          x-offset:                    0px;
          y-offset:                    0px;

          /* properties for all widgets */
          enabled:                     true;
          border-radius:               15px;
          cursor:                      "default";
          background-color:            @background;
      }

      /*****----- Main Box -----*****/
      mainbox {
          enabled:                     true;
          spacing:                     0px;
          background-color:            transparent;
          orientation:                 horizontal;
          children:                    [ "imagebox", "listbox" ];
      }

      imagebox {
          padding:                     20px;
          background-color:            transparent;
          background-image:            url("~/.config/rofi/rofi.png", height);
          orientation:                 vertical;
          children:                    [ "inputbar", "dummy", "mode-switcher" ];
      }

      listbox {
          spacing:                     20px;
          padding:                     20px;
          background-color:            transparent;
          orientation:                 vertical;
          children:                    [ "message", "listview" ];
      }

      dummy {
          background-color:            transparent;
      }

      /*****----- Inputbar -----*****/
      inputbar {
          enabled:                     true;
          spacing:                     10px;
          padding:                     15px;
          border-radius:               10px;
          background-color:            @background-alt;
          text-color:                  @foreground;
          children:                    [ "textbox-prompt-colon", "entry" ];
      }
      textbox-prompt-colon {
          enabled:                     true;
          expand:                      false;
          str:                         "";
          background-color:            inherit;
          text-color:                  inherit;
      }
      entry {
          enabled:                     true;
          background-color:            inherit;
          text-color:                  inherit;
          cursor:                      text;
          placeholder:                 "Search";
          placeholder-color:           inherit;
      }

      /*****----- Mode Switcher -----*****/
      mode-switcher{
          enabled:                     true;
          spacing:                     20px;
          background-color:            transparent;
          text-color:                  @foreground;
      }
      button {
          padding:                     15px;
          border-radius:               10px;
          background-color:            @background-alt;
          text-color:                  inherit;
          cursor:                      pointer;
      }
      button selected {
          background-color:            @selected;
          text-color:                  @foreground;
      }

      /*****----- Listview -----*****/
      listview {
          enabled:                     true;
          columns:                     1;
          lines:                       8;
          cycle:                       true;
          dynamic:                     true;
          scrollbar:                   false;
          layout:                      vertical;
          reverse:                     false;
          fixed-height:                true;
          fixed-columns:               true;
          
          spacing:                     10px;
          background-color:            transparent;
          text-color:                  @foreground;
          cursor:                      "default";
      }

      /*****----- Elements -----*****/
      element {
          enabled:                     true;
          spacing:                     15px;
          padding:                     8px;
          border-radius:               10px;
          background-color:            transparent;
          text-color:                  @foreground;
          cursor:                      pointer;
      }
      element normal.normal {
          background-color:            inherit;
          text-color:                  inherit;
      }
      element normal.urgent {
          background-color:            @urgent;
          text-color:                  @foreground;
      }
      element normal.active {
          background-color:            @active;
          text-color:                  @foreground;
      }
      element selected.normal {
          background-color:            @selected;
          text-color:                  @foreground;
      }
      element selected.urgent {
          background-color:            @urgent;
          text-color:                  @foreground;
      }
      element selected.active {
          background-color:            @urgent;
          text-color:                  @foreground;
      }
      element-icon {
          background-color:            transparent;
          text-color:                  inherit;
          size:                        32px;
          cursor:                      inherit;
      }
      element-text {
          background-color:            transparent;
          text-color:                  inherit;
          cursor:                      inherit;
          vertical-align:              0.5;
          horizontal-align:            0.0;
      }

      /*****----- Message -----*****/
      message {
          background-color:            transparent;
      }
      textbox {
          padding:                     15px;
          border-radius:               10px;
          background-color:            @background-alt;
          text-color:                  @foreground;
          vertical-align:              0.5;
          horizontal-align:            0.0;
      }
      error-message {
          padding:                     15px;
          border-radius:               20px;
          background-color:            @background;
          text-color:                  @foreground;
      }

  '';

  # Add power management entries to rofi drun menu
  home.file = {
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
      Exec=${lockCommand}
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
