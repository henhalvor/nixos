{ config, pkgs, userSettings, systemSettings, ... }:

{
    # Enable the X11 windowing system (needed for XWayland and GDM)
  services.xserver.enable = true;

  # Enable Wayland compositor - Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.sway = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    #  If your cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    #Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";
    # NVIDIA specific
    XDG_SESSION_TYPE = "wayland";
  };

    # Enable display manager
  services.xserver.displayManager.gdm.enable = true;

  # enable gnome
  services.xserver.desktopManager.gnome.enable = true;

    # XDG portal
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  }
