# Waybar — status bar (session-aware: hyprland/niri/sway)
# Source: home/modules/desktop/bars/waybar.nix
# Template B2: HM-only with Stylix colors, session detection
{self, ...}: {
  flake.nixosModules.waybar = {...}: {
    home-manager.sharedModules = [self.homeModules.waybar];
  };

  flake.homeModules.waybar = {
    config,
    pkgs,
    lib,
    pkgs-unstable,
    ...
  }: let
    colors = config.lib.stylix.colors;

    isHyprland = config.wayland.windowManager.hyprland.enable or false;
    isNiri = config.programs.niri.enable or false;
    isSway = config.wayland.windowManager.sway.enable or false;

    workspaceModule =
      if isHyprland
      then "hyprland/workspaces"
      else if isNiri
      then "niri/workspaces"
      else if isSway
      then "sway/workspaces"
      else null;

    workspaceIcons = {
      "1" = "1";
      "2" = "2";
      "3" = "3";
      "4" = "4";
      "5" = "5";
      "6" = "6";
      "7" = "7";
      "8" = "8";
      "9" = "9";
      "10" = "10";
      gmail = "G";
    };

    execCmd = cmd:
      if isHyprland
      then "hyprctl dispatch exec '[float; size 1111 650] ${cmd}'"
      else if isNiri
      then cmd
      else if isSway
      then "swaymsg exec '${cmd}'"
      else cmd;
  in {
    home.packages = with pkgs; [pavucontrol wlogout pkgs-unstable.wiremix];

    programs.waybar = {
      enable = true;
      systemd.enable = true;

      settings = [
        {
          output = ["DP-1" "eDP-1"];
          layer = "top";
          exclusive = true;
          position = "top";
          height = 30;
          width = 300;
          spacing = 8;
          margin = "2px";
          anchor = "top center";
          reload_style_on_change = true;

          modules-center =
            ["clock"]
            ++ lib.optional (workspaceModule != null) workspaceModule
            ++ ["pulseaudio" "network" "bluetooth" "battery"];
          modules-right = [];

          "sway/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
            format = "{icon}";
            format-icons = workspaceIcons;
          };
          "hyprland/workspaces" = {
            format = "{icon}";
            format-icons = workspaceIcons;
          };
          "niri/workspaces" = {
            all-outputs = true;
            format = "{icon}";
            format-icons = workspaceIcons;
          };

          clock = {
            format = "{:%H:%M}";
            "format-alt" = "{:%a, %d %b}";
            tooltip = false;
          };
          network = {
            format = "{ifname}";
            "format-wifi" = "󰤨 {essid}";
            "format-ethernet" = "󰈀";
            "format-disconnected" = "󰤮";
            "tooltip-format" = "{ifname}: {ipaddr}";
            "on-click" = execCmd "${pkgs.kitty}/bin/kitty --title nmtui-popup -e nmtui";
          };
          bluetooth = {
            format = "󰂯";
            "format-connected" = "󰂯";
            "format-connected-battery" = "󰂯 {device_battery_percentage}%";
            "on-click" = execCmd "${pkgs.kitty}/bin/kitty --title bluetui-popup -e bluetui";
          };
          pulseaudio = {
            format = "  {volume}%";
            "format-muted" = "󰸈 Muted";
            "format-icons" = {
              default = ["" "" ""];
              headphones = "";
              headset = "";
            };
            "scroll-step" = 5;
            "on-click" = execCmd "${pkgs.kitty}/bin/kitty --title wiremix-popup -e wiremix";
            tooltip = false;
          };
          battery = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{capacity}% {icon}";
            "format-charging" = "{capacity}% 󰂄";
            "format-plugged" = "{capacity}% 󰂄";
            "format-icons" = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
            tooltip = false;
          };
        }
      ];

      style = ''
        * {
          font-family: ${config.stylix.fonts.monospace.name}, FontAwesome, sans-serif;
          font-size: 12px;
          min-height: 0;
          min-width: 0;
          border: none;
        }

        window#waybar {
          background: transparent;
          color: #${colors.base05};
        }

        .modules-center {
          background: alpha(#${colors.base00}, 0.5);
          border: 1px solid #${colors.base03};
          border-radius: 10px;
          padding: 6px 8px;
        }

        #workspaces,
        #clock,
        #pulseaudio,
        #network,
        #battery,
        #bluetooth {
          padding: 0 6px;
          margin: 0 2px;
          color: #${colors.base05};
          background-color: transparent;
        }

        #workspaces button {
          min-width: 18px;
          padding: 0 4px;
          margin: 0 1px;
          border-radius: 6px;
          background-color: transparent;
          color: #${colors.base05};
        }

        #workspaces button.focused {
          color: #${colors.base0E};
          background-color: alpha(#${colors.base05}, 0.08);
        }

        #workspaces button.urgent {
          color: #${colors.base08};
          background-color: alpha(#${colors.base08}, 0.1);
        }

        #workspaces button:hover {
          background-color: alpha(#${colors.base05}, 0.08);
          color: #${colors.base0C};
        }

        #clock { color: #${colors.base0C}; font-weight: bold; }
        #network { color: #${colors.base0B}; }
        #bluetooth { color: #${colors.base0E}; }
        #pulseaudio { color: #${colors.base0F}; }
        #pulseaudio.muted { color: #${colors.base03}; }
        #battery { color: #${colors.base0B}; }
      '';
    };
  };
}
