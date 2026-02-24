{
  config,
  lib,
  pkgs,
  ...
}: let
  # Use Stylix colors instead of hardcoded Catppuccin
  colors = config.lib.stylix.colors;
in {
  # Add necessary packages
  home.packages = with pkgs; [
    pavucontrol
    wlogout
  ];

  # Configure Waybar
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        width = 300;
        spacing = 10;
        margin = "8px";
        anchor = "top center";

        # Module placement
        modules-center = ["clock" "sway/workspaces" "hyprland/workspaces" "pulseaudio" "network" "bluetooth" "battery"];
        modules-right = [];

        # Module configurations
        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
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
          };
        };

        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
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
          };
        };

        "clock" = {
          format = " {:%H:%M}";
          tooltip = false;
        };

        "network" = {
          format = "{ifname}";
          format-wifi = "󰤨 {essid}";
          format-ethernet = "󰈀";
          format-disconnected = "󰤮";
          tooltip-format = "{ifname}: {ipaddr}";
          on-click = "hyprctl dispatch exec '[float; size 1111 650] kitty -e nmtui'";
        };

        "bluetooth" = {
          format = "󰂯";
          # format-connected = "󰂯 {device_alias}";
          format-connected = "󰂯";
          # format-connected-battery = "󰂯 {device_alias} {device_battery_percentage}%";
          format-connected-battery = "󰂯 {device_battery_percentage}%";
          on-click = "hyprctl dispatch exec '[float; size 1111 650] kitty -e bluetui'";
        };

        "pulseaudio" = {
          format = "  {volume}%";
          format-muted = "󰸈 Muted";
          format-icons = {
            default = ["" "" ""];
            headphones = "";
            headset = "";
          };
          scroll-step = 5;
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
          tooltip = false;
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% 󰂄";
          format-plugged = "{capacity}% 󰂄";
          format-icons = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          tooltip = false;
        };
      }
    ];

    # Styling with Stylix colors
    style = ''
      * {
        font-family: ${config.stylix.fonts.monospace.name}, FontAwesome, sans-serif;
        font-size: 12px;
        min-height: 0;
        min-width: 0;
        border: none;
      }

      window#waybar {
        background-color: #${colors.base00};
        color: #${colors.base05};
        border-radius: 20px;
        padding: 4px 12px;
        margin: 8px;
        border: 1px solid #${colors.base02};
      }

      /* Module base styling */
      #workspaces,
      #clock,
      #pulseaudio,
      #network,
      #battery,
      #bluetooth {
        padding: 0 6px;
        margin: 0 3px;
        color: #${colors.base05};
        background-color: transparent;
      }

      /* Workspace styling */
      #workspaces button {
        min-width: 20px;
        padding: 0 4px;
        margin: 0 2px;
        border-radius: 6px;
        background-color: transparent;
        color: #${colors.base05};
      }

      #workspaces button.focused {
        color: #${colors.base0E};
        background-color: #${colors.base02};
      }

      #workspaces button.visible {
        color: #${colors.base05};
        background-color: transparent;
      }

      #workspaces button.urgent {
        color: #${colors.base08};
        background-color: #${colors.base02};
      }

      #workspaces button:hover {
        background-color: #${colors.base02};
        color: #${colors.base0C};
      }

      /* Individual module colors */
      #clock {
        color: #${colors.base0C};
        font-weight: bold;
      }

      #network {
        color: #${colors.base0B};
      }

      #bluetooth {
        color: #${colors.base0E};
      }

      #pulseaudio {
        color: #${colors.base0F};
      }

      #pulseaudio.muted {
        color: #${colors.base03};
      }

      #battery {
        color: #${colors.base0B};
      }

      #battery.charging,
      #battery.plugged {
        color: #${colors.base0C};
      }

      #battery.critical:not(.charging) {
        color: #${colors.base08};
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      /* Blinking animation */
      @keyframes blink {
        to {
          color: #${colors.base08};
        }
      }
    '';
  };
}
