# Wayland Applets — system tray (NM applet)
# Source: home/modules/desktop/applets/wayland.nix
# Template B2: HM-only
{self, ...}: {
  flake.nixosModules.waylandApplets = {...}: {
    home-manager.sharedModules = [self.homeModules.waylandApplets];
  };

  flake.homeModules.waylandApplets = {pkgs, ...}: {
    services.blueman-applet.enable = false;
    services.network-manager-applet.enable = true;
    home.packages = [pkgs.networkmanagerapplet];
  };
}
