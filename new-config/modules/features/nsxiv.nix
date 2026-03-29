# nsxiv — image viewer with MIME associations (currently unused)
# Source: home/modules/applications/nsxiv.nix
{ self, ... }: {
  flake.nixosModules.nsxiv = { ... }: {
    home-manager.sharedModules = [ self.homeModules.nsxiv ];
  };

  flake.homeModules.nsxiv = { pkgs, ... }: {
    home.packages = with pkgs; [ nsxiv ];

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "image/png" = "nsxiv.desktop";
      "image/jpeg" = "nsxiv.desktop";
      "image/gif" = "nsxiv.desktop";
      "image/bmp" = "nsxiv.desktop";
      "image/webp" = "nsxiv.desktop";
    };
  };
}
