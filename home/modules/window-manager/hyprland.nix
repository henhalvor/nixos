{ config, pkgs, userSettings, ... }:

{

  home.packages = with pkgs; [
    # Wayland essentials
    wofi # Application launcher
    waybar # Status bar
    # swaync          # Notification daemon
    # swaylock        # Screen locker
    # swayidle        # Idle management daemon
    wl-clipboard # Clipboard manager
    # grim            # Screenshot utility
    # slurp           # Screen region selector
    # wf-recorder     # Screen recording
    # brightnessctl   # Brightness control
    hyprland
    #picom # Compositor (optional)
    nm-applet # Network manager applet (optional)
  ];







  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    # Define Hyprland configuration
    config = {
      # Mod key settings (default is Super)
      mod = "Mod4"; # Super key

      # Define key bindings
      binds = [
        # Launch terminal with Mod + Enter
        "bind=MOD,Return,exec,kitty"

        # Reload configuration with Mod + Shift + R
        "bind=MOD+Shift,C,exec,hyprctl reload"

        # Close active window with Mod + Q
        "bind=MOD,Q,exec,hyprctl dispatch killactive"

        "bind=MOD,D,exec,wofi --show drun"
      ];

      # Set default workspace settings (optional)
      workspace = {
        gaps_in = 10;
        gaps_out = 20;
        border_size = 2;
      };

      # Window rules (optional)
      rules = [
        # Center new windows
        "windowrule=float,center"
      ];
    };

    # Autostart applications
    autostart = [
      "picom --experimental-backends" # Example for a compositor
      "nm-applet" # Network manager applet
    ];
  };
}
