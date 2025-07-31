{ config, pkgs, userSettings, systemName, ... }:
let
  sddmSetupScripts = {
    workstation = ''
      sleep 2
      ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-A-1 --mode 2560x1440 --rate 144 --pos 1080x0 --primary
      ${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --mode 1920x1080 --rate 144 --pos 0x-180 --rotate left
    '';

    # lenovo-yoga-pro-7 = ''
    #   sleep 2
    #   # Laptop setup - might need different display names
    #   ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --mode 2560x1600 --rate 90 --primary
    #   # Add external monitors if connected
    #   ${pkgs.xorg.xrandr}/bin/xrandr --output DP-9 --mode 2560x1440 --rate 144 --pos 1600x0 || true
    #   ${pkgs.xorg.xrandr}/bin/xrandr --output DP-8 --mode 1920x1080 --rate 144 --pos 0x-180 --rotate left || true
    # '';

    lenovo-yoga-pro-7 = "";
  };

  currentSetupScript =
    sddmSetupScripts.${systemName} or sddmSetupScripts.workstation;

in {
  # Enable the X11 windowing system (needed for XWayland and GDM)
  services.xserver.enable = true;

  # Enable display manager
  # services.xserver.displayManager.gdm.enable = true;

  # Add SDDM
  services.displayManager.sddm = {
    enable = true;
    setupScript = currentSetupScript;
    autoNumlock = true;
  };

  # XDG portal
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Keep dconf for GTK settings
  programs.dconf.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

}

