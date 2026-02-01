{ config, lib, pkgs, ... }:
let
  # Use Stylix colors instead of hardcoded Catppuccin
  colors = config.lib.stylix.colors;
  
  # Gammastep toggle script
  gamma-toggle-script = pkgs.writeShellScriptBin "gamma-toggle" ''
    #!${pkgs.bash}/bin/bash
    set -e

    STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"
    gammastepStateDir="$STATE_HOME/gammastep"
    gammastepStateFile="$gammastepStateDir/default_temp.sh"
    mkdir -p "$gammastepStateDir"
    
    # Robust check: Use pgrep -af and filter for the specific executable path
    if ${pkgs.procps}/bin/pgrep -af gammastep | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|gamma-' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.gammastep}/bin/gammastep"; then
      # Kill gammastep
      pkill -f gammastep
      
      # Check again after delay
      sleep 0.5
      if ${pkgs.procps}/bin/pgrep -af gammastep | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|gamma-' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.gammastep}/bin/gammastep"; then
         ${pkgs.libnotify}/bin/notify-send --expire-time=4000 "ERROR: RedGlow process still detected after pkill!"
      else
         ${pkgs.libnotify}/bin/notify-send --expire-time=2000 "RedGlow Stopped."
      fi
    else
      # Start gammastep
      if [ ! -f "$gammastepStateFile" ]; then echo "default_temp=3400" > "$gammastepStateFile"; fi
      ${pkgs.gammastep}/bin/gammastep -O 3400 &
      disown
      ${pkgs.libnotify}/bin/notify-send --expire-time=1500 "RedGlow ON (3400K)"
    fi
  '';
in {
  # Add necessary packages
  home.packages = with pkgs; [
    pavucontrol
    wlogout
    blueman
    gammastep
    gamma-toggle-script
  ];

  # Enable blueman and network manager applets
  services.blueman-applet.enable = true;
  services.network-manager-applet.enable = true;

  # Configure Waybar
  programs.waybar = {
    enable = true;
    systemd.enable = false;

    settings = [{
      layer = "top";
      position = "top";
      height = 27;
      spacing = 4;

      # Module placement
      modules-left = [ "sway/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "idle_inhibitor"
        "custom/gammastep"
        "pulseaudio"
        "mako"
        "battery"
        "cpu"
        "memory"
        "tray"
        "custom/exit"
      ];

      # Module configurations
      "sway/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
        format = "{icon}";
        format-icons = {
          "1" = "";
          "2" = " ";
          "3" = "";
          "4" = "⌨";
        };
      };

      "clock" = {
        format = " {:%H:%M}";
        format-alt = " {:%Y-%m-%d}";
        tooltip-format = ''
          <big>{:%Y %B}</big>
          <tt>{calendar}</tt>'';
        calendar = {
          mode = "year";
          mode-mon-col = 3;
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            months = "<span color='#${colors.base0D}'><b>{}</b></span>";
            days = "<span color='#${colors.base04}'><b>{}</b></span>";
            weeks = "<span color='#${colors.base0A}'><b>W{}</b></span>";
            weekdays = "<span color='#${colors.base09}'><b>{}</b></span>";
            today = "<span color='#${colors.base0F}'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          "on-click-right" = "mode";
          "on-scroll-up" = "shift_up";
          "on-scroll-down" = "shift_down";
        };
      };

      "idle_inhibitor" = {
        format = "{icon}";
        format-icons = {
          activated = "";
          deactivated = "";
        };
        tooltip = true;
        tooltip-format-activated = "Idle Inhibitor Active";
        tooltip-format-deactivated = "Idle Inhibitor Inactive";
      };

      "pulseaudio" = {
        format = "{volume}% {icon}";
        format-muted = " Muted";
        format-icons = {
          default = [ "" "" "" ];
          headphones = "";
          headset = "";
        };
        scroll-step = 5;
        on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
        tooltip = true;
        tooltip-format = "{volume}%";
      };

      "mako" = {
        format = "{count} ";
        format-actions = "{count} ";
        format-dismissed = "";
        max-visible = 5;
        tooltip = true;
        on-click = "${pkgs.mako}/bin/makoctl menu dmenu";
        on-click-right = "${pkgs.mako}/bin/makoctl dismiss --all";
      };

      "battery" = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% 󰂄";
        format-plugged = "{capacity}% 󰂄";
        format-alt = "{time} {icon}";
        format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      };

      "cpu" = {
        format = " {usage}%";
        tooltip = true;
        tooltip-format = "CPU Usage: {usage}%";
        interval = 5;
        on-click = "${pkgs.mission-center}/bin/missioncenter";
      };

      "memory" = {
        format = "󰍛 {used:0.1f}G";
        tooltip = true;
        tooltip-format = "Memory: {used:0.1f} GiB / {total:0.1f} GiB ({perc}%)";
        interval = 5;
        on-click = "${pkgs.mission-center}/bin/missioncenter";
      };

      "tray" = {
        icon-size = 13;
        spacing = 10;
      };

      "custom/exit" = {
        format = "";
        tooltip = true;
        tooltip-format = "Power Menu";
        on-click = "${pkgs.wlogout}/bin/wlogout -p layer-shell";
      };

      "custom/gammastep" = {
        format = "{icon}";
        format-icons = [ "󰔎" ];
        tooltip = false;
        on-click = "${gamma-toggle-script}/bin/gamma-toggle";
      };
    }];

    # Styling with Stylix colors
    style = ''
      * {
        font-family: ${config.stylix.fonts.monospace.name}, FontAwesome, sans-serif;
        font-size: ${toString config.stylix.fonts.sizes.desktop}px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background-color: #${colors.base00};
        color: #${colors.base05};
        transition-property: background-color;
        transition-duration: .5s;
      }

      /* Module base styling */
      #workspaces,
      #clock,
      #pulseaudio,
      #network,
      #mako,
      #battery,
      #cpu,
      #memory,
      #idle_inhibitor,
      #tray,
      #custom-exit,
      #custom-gammastep {
        padding: 0 8px;
        margin: 2px 3px;
        color: #${colors.base05};
        background-color: transparent;
        border-radius: 4px;
      }

      /* Workspace styling */
      #workspaces button.focused {
        color: #${colors.base0E};
        background-color: #${colors.base02};
        border-radius: 4px;
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
        border-radius: 4px;
      }

      /* Individual module colors using Stylix base16 */
      #clock {
        color: #${colors.base0C};  /* Cyan */
      }

      #battery {
        color: #${colors.base0B};  /* Green */
      }

      #battery.charging,
      #battery.plugged {
        color: #${colors.base0C};  /* Cyan */
      }

      #battery.critical:not(.charging) {
        color: #${colors.base08};  /* Red */
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      #cpu {
        color: #${colors.base09};  /* Orange */
      }

      #memory {
        color: #${colors.base0A};  /* Yellow */
      }

      #pulseaudio {
        color: #${colors.base0F};  /* Magenta */
      }

      #pulseaudio.muted {
        color: #${colors.base03};  /* Dimmed */
      }

      #mako {
        color: #${colors.base0E};  /* Purple */
      }

      #mako.urgent {
        color: #${colors.base08};  /* Red */
      }

      #mako.dismissed {
        color: #${colors.base03};  /* Dimmed */
      }

      #idle_inhibitor {
        color: #${colors.base0D};  /* Blue */
      }

      #idle_inhibitor.deactivated {
        color: #${colors.base03};  /* Dimmed */
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }

      #custom-exit {
        color: #${colors.base08};  /* Red */
        padding: 0 10px;
        margin-left: 6px;
      }

      #custom-gammastep {
        font-size: 14px;
        margin-left: 2px;
      }

      /* Tooltip styling */
      tooltip {
        background-color: #${colors.base01};
        border: 1px solid #${colors.base02};
        border-radius: 4px;
        padding: 8px;
      }

      tooltip label {
        color: #${colors.base05};
      }

      /* Blinking animation */
      @keyframes blink {
        to {
          color: #${colors.base08};
          background-color: #${colors.base02};
        }
      }
    '';
  };
}
