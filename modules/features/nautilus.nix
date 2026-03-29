# Nautilus — file manager with MIME associations
# Source: home/modules/applications/nautilus.nix
{ self, ... }: {
  flake.nixosModules.nautilus = { ... }: {
    home-manager.sharedModules = [ self.homeModules.nautilus ];
  };

  flake.homeModules.nautilus = { pkgs, ... }: {
    home.packages = with pkgs; [ nautilus gvfs ];

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };
}
