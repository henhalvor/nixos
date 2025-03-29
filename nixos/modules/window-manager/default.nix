{ config, pkgs, userSettings, systemSettings, ... }: {
  # Enable the X11 windowing system (needed for XWayland and GDM)
  services.xserver.enable = true;

  # Enable display manager
  services.xserver.displayManager.gdm.enable = true;

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
