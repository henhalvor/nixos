{ config, pkgs, lib, ... }:

let
  # Define colors (e.g., Catppuccin Mocha) - makes styling easier
  theme = {
    rosewater = "#f5e0dc";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    maroon = "#eba0ac";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";

    text = "#cdd6f4";
    subtext1 = "#bac2de";
    subtext0 = "#a6adc8";
    overlay2 = "#9399b2";
    overlay1 = "#7f849c";
    overlay0 = "#6c7086";
    surface2 = "#585b70";
    surface1 = "#45475a";
    surface0 = "#313244";

    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
  };
in {
  # 1. Add necessary packages
  home.packages = with pkgs; [
    waybar
    mako # Notification daemon
    pavucontrol # GUI for PulseAudio control (for on-click)
    wlogout # Power menu (you already have this specified)
    blueman
    # Ensure blueberry or blueman is installed via Sway config or here
  ];

  # 2. Enable and configure Waybar
  programs.waybar = {
    enable = true;
    # Use systemd user service for better management
    systemd.enable = true;

    # 3. Configure Waybar Settings
    settings = [{
      layer = "top"; # Set to top layer
      position = "bottom"; # Bar position
      height = 24; # Bar height
      spacing = 4; # Spacing between modules

      # Define module placement
      modules-left = [ "sway/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "idle_inhibitor"
        "pulseaudio"
        # Bluetooth will likely show up in the tray via blueberry/blueman
        # "network"
        "mako" # Mako notification indicator
        "battery"
        "cpu"
        "memory"
        "tray" # System tray (for Bluetooth, etc.)
        "custom/exit"
      ];

      # --- Module Configurations ---

      "sway/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
        # format = "{icon}"; # Use icons only if desired
        format = "{name}"; # Show workspace names/numbers
        # format-icons = {
        #   "1" = "爵"; # Example Nerd Font icons
        #   "2" = "犯";
        #   "3" = "猪";
        #   "urgent" = "";
        #   "focused" = "";
        #   "default" = "";
        # };
        persistent-workspaces = {
          "*" = 5; # Show at least 5 workspaces per monitor
        };
      };

      "clock" = {
        format = " {:%H:%M}"; # Time
        format-alt = " {:%Y-%m-%d}"; # Date on alternate click/scroll
        tooltip-format = ''
          <big>{:%Y %B}</big>
          <tt>{calendar}</tt>''; # Calendar tooltip
        calendar = {
          mode = "year";
          mode-mon-col = 3;
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            months = "<span color='${theme.blue}'><b>{}</b></span>";
            days = "<span color='${theme.subtext1}'><b>{}</b></span>";
            weeks = "<span color='${theme.yellow}'><b>W{}</b></span>";
            weekdays = "<span color='${theme.peach}'><b>{}</b></span>";
            today = "<span color='${theme.rosewater}'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          "on-click-right" = "mode"; # Switch between normal/alternative format
          "on-scroll-up" = "shift_up"; # Go forward in calendar view
          "on-scroll-down" = "shift_down"; # Go backward in calendar view
        };
      };

      "idle_inhibitor" = {
        format = "{icon}";
        format-icons = {
          activated = ""; # Eye icon when active (inhibiting idle)
          deactivated = ""; # Different icon (e.g., zzz) when inactive
        };
        tooltip = true;
        tooltip-format-activated = "Idle Inhibitor Active";
        tooltip-format-deactivated = "Idle Inhibitor Inactive";
      };

      "pulseaudio" = {
        format = "{volume}% {icon}"; # {format_source} # Add source if needed
        format-muted = " Muted"; # Muted icon + text
        # format-source = " {volume}%";
        # format-source-muted = " Muted";
        format-icons = {
          default = [ "" "" "" ]; # Icons for different volume levels
          headphones = "";
          headset = "";

        };
        scroll-step = 5; # % change per scroll
        on-click =
          "${pkgs.pavucontrol}/bin/pavucontrol"; # Open pavucontrol on click
        tooltip = true;
        tooltip-format = "{volume}%";
      };

      "network" = {
        format-wifi = " {essid} ({signalStrength}%)";
        format-ethernet = "󰈀 Connected"; # Ethernet icon
        format-disconnected = "󰖪 Disconnected"; # Disconnected icon
        format-alt = "{ifname}: {ipaddr}/{cidr}";
        tooltip = true;
        tooltip-format-wifi = "{essid} ({signalStrength}%) - {ipaddr}";
        tooltip-format-ethernet = "{ifname} - {ipaddr}";
        tooltip-format-disconnected = "Disconnected";
        on-click = ""; # Add command if you want to launch network manager GUI
      };

      "mako" = {
        format = "{count} "; # Notification count + icon
        format-actions = "{count} "; # Same format when actions available
        format-dismissed = ""; # Icon only when no notifications
        # format-urgent = "{count} "; # Different format/icon for urgent
        max-visible = 5;
        tooltip = true;
        on-click =
          "${pkgs.mako}/bin/makoctl menu dmenu"; # Use makoctl for menu on click
        on-click-right =
          "${pkgs.mako}/bin/makoctl dismiss --all"; # Dismiss all on right click
        # default-timeout = 5000; # Handled by mako config itself
      };

      "battery" = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% 󰂄"; # Charging icon
        format-plugged =
          "{capacity}% 󰂄"; # Plugged icon (often same as charging)
        format-alt = "{time} {icon}"; # Show time remaining on alt
        format-icons =
          [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ]; # Battery icons
      };

      "cpu" = {
        format = " {usage}%"; # CPU icon + usage
        tooltip = true;
        tooltip-format = "CPU Usage: {usage}%";
        interval = 2; # Update every 2 seconds
      };

      "memory" = {
        format = "󰍛 {used:0.1f}G"; # Memory icon + Used/Total RAM in GiB
        tooltip = true;
        tooltip-format = "Memory: {used:0.1f} GiB / {total:0.1f} GiB ({perc}%)";
        interval = 5; # Update every 5 seconds
      };

      "tray" = {
        icon-size = 14;
        spacing = 10; # Spacing between tray icons
      };

      "custom/exit" = {
        format = ""; # Power icon
        tooltip = true;
        tooltip-format = "Power Menu";
        on-click =
          "${pkgs.wlogout}/bin/wlogout -p layer-shell"; # Launch wlogout
      };

    }];

    # 4. Styling with CSS
    style = ''
      /* Use CSS variables defined above */
      @define-color rosewater ${theme.rosewater};
      @define-color flamingo ${theme.flamingo};
      @define-color pink ${theme.pink};
      @define-color mauve ${theme.mauve};
      @define-color red ${theme.red};
      @define-color maroon ${theme.maroon};
      @define-color peach ${theme.peach};
      @define-color yellow ${theme.yellow};
      @define-color green ${theme.green};
      @define-color teal ${theme.teal};
      @define-color sky ${theme.sky};
      @define-color sapphire ${theme.sapphire};
      @define-color blue ${theme.blue};
      @define-color lavender ${theme.lavender};
      @define-color text ${theme.text};
      @define-color subtext1 ${theme.subtext1};
      @define-color subtext0 ${theme.subtext0};
      @define-color overlay2 ${theme.overlay2};
      @define-color overlay1 ${theme.overlay1};
      @define-color overlay0 ${theme.overlay0};
      @define-color surface2 ${theme.surface2};
      @define-color surface1 ${theme.surface1};
      @define-color surface0 ${theme.surface0};
      @define-color base ${theme.base};
      @define-color mantle ${theme.mantle};
      @define-color crust ${theme.crust};

      * {
        /* `otf-font-awesome` is required to be installed for icons */
        font-family: Hack Nerd Font, FontAwesome, sans-serif; /* Use Hack NF */
        font-size: 12px; /* Slightly smaller font size */
        min-height: 0; /* Allows modules to be smaller */
        border: none; /* Reset borders */
        border-radius: 0; /* Reset radius */
      }

      window#waybar {
        background-color: @base; /* Solid background color */
        /* background: transparent; */ /* Or keep transparent if you prefer */
        color: @text;
        /* border-bottom: 2px solid @surface1; */ /* Optional bottom border */
        transition-property: background-color;
        transition-duration: .5s;
      }

      /* Reset padding and margin for all modules */
      #workspaces,
      #clock,
      #pulseaudio,
      #network,
      #mako,
      #battery,
      #cpu,
      #memory,
      #temperature,
      #idle_inhibitor,
      #tray,
      #custom-exit {
        padding: 0 8px; /* Horizontal padding */
        margin: 2px 3px; /* Small vertical and horizontal margin */
        color: @text;
        background-color: transparent; /* Make module background transparent */
        border-radius: 4px; /* Slightly rounded corners for modules */
      }

      /* Style for focused workspace */
      #workspaces button.focused {
        color: @mauve;
        background-color: @surface0;
        border-radius: 4px;
      }

      /* Style for visible workspaces on other monitors */
      #workspaces button.visible {
         color: @text;
         background-color: transparent;
      }

      /* Style for urgent workspace */
      #workspaces button.urgent {
        color: @red;
        background-color: @surface0;
      }

      #workspaces button:hover {
        background-color: @surface1;
        color: @sky;
        border-radius: 4px;
        /* box-shadow: inherit; */ /* Optional: inherit shadow if bar has one */
        /* text-shadow: inherit; */ /* Optional: inherit text shadow */
      }

      /* Individual module styling */
      #clock {
        color: @sky;
        /* background-color: @surface0; */ /* Optional distinct background */
      }

      #battery {
        color: @green;
      }

      #battery.charging, #battery.plugged {
        color: @teal;
      }

      #battery.critical:not(.charging) {
        color: @red;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      #cpu {
        color: @peach;
      }

      #memory {
        color: @yellow;
      }

      #network {
        color: @blue;
      }
      #network.disconnected {
        color: @red;
      }

      #pulseaudio {
        color: @pink;
      }
      #pulseaudio.muted {
        color: @overlay1;
      }

      #mako {
          color: @lavender;
      }
      #mako.urgent { /* Assuming you add urgent format */
          color: @red;
      }
      #mako.dismissed {
          color: @overlay1;
      }


      #idle_inhibitor {
          color: @sapphire;
      }
      #idle_inhibitor.activated {
          color: @sapphire;
          /* background-color: @surface0; */ /* Optional background when active */
      }
       #idle_inhibitor.deactivated {
          color: @overlay1;
      }

      #tray {
          /* background-color: @mantle; */ /* Optional background for tray */
      }
      #tray > .passive {
        -gtk-icon-effect: dim;
      }
      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        /* background-color: @red; */ /* Optional background for attention */
      }


      #custom-exit {
        color: @red;
        padding: 0 10px; /* Slightly more padding for the exit button */
        margin-left: 6px; /* Extra space before exit */
      }

      /* Tooltip style */
      tooltip {
        background-color: @mantle;
        border: 1px solid @surface1;
        border-radius: 4px;
        padding: 8px;
      }
      tooltip label {
        color: @text;
      }

      /* Blinking animation for critical battery */
      @keyframes blink {
        to {
          color: @red;
          background-color: @surface0; /* Optional background blink */
        }
      }
    '';
  };

  services.blueman-applet = { enable = true; };

  services.network-manager-applet = { enable = true; };

  # 5. Configure Mako (Optional but recommended)
  services.mako = {
    enable = true;
    # Customize Mako appearance and behavior
    font = "JetBrainsMono Nerd Font 10";
    padding = "10";
    margin = "10";
    borderSize = 1;
    borderRadius = 5;
    defaultTimeout = 5000; # 5 seconds
    layer = "overlay"; # Ensure it appears above everything

    # Colors matching Waybar theme
    backgroundColor = "${theme.base}F0"; # Base with some transparency
    textColor = theme.text;
    borderColor = theme.surface1;

    # # Different criteria can have different styles
    # criteria = [
    #   {
    #     name = "urgency-low";
    #     borderColor = theme.green;
    #   }
    #   {
    #     name = "urgency-normal";
    #     borderColor = theme.blue;
    #   }
    #   {
    #     name = "urgency-high";
    #     borderColor = theme.red;
    #     textColor = theme.red;
    #   }
    #   # Add more criteria as needed, e.g., for specific apps
    #   # { app-name = "notify-send"; border_color = "#FAB387"; }
    # ];
  };
}
