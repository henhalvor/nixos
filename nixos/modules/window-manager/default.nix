{ config, pkgs, userSettings, ... }: {
  # Enable the X11 windowing system (needed for XWayland and GDM)
  services.xserver.enable = true;

  # Enable display manager
  # services.xserver.displayManager.gdm.enable = true;

  # Add SDDM
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true; # Native Wayland support
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
