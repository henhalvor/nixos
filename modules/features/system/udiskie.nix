# Udiskie — auto-mount USB drives
# Source: home/modules/settings/udiskie.nix
{ self, ... }: {
  flake.nixosModules.udiskie = { ... }: {
    home-manager.sharedModules = [ self.homeModules.udiskie ];
  };

  flake.homeModules.udiskie = { ... }: {
    services.udiskie = {
      enable = true;
      notify = true;
      tray = "auto";
      automount = true;
    };
  };
}
