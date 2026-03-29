# GNOME — desktop environment
# Source: nixos/modules/desktop/sessions/gnome.nix + home/modules/desktop/sessions/gnome.nix
# Template C: Colocated NixOS + HM
{self, ...}: {
  flake.nixosModules.gnome = {pkgs, ...}: {
    services.xserver.enable = true;
    services.desktopManager.gnome.enable = true;

    environment.gnome.excludePackages = with pkgs; [gnome-tour epiphany];

    home-manager.sharedModules = [self.homeModules.gnome];
  };

  flake.homeModules.gnome = {...}: {
    dconf.settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
    };
  };
}
