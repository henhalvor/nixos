# gThumb — image viewer
# Source: home/modules/applications/gthumb.nix
{ self, ... }: {
  flake.nixosModules.gthumb = { ... }: {
    home-manager.sharedModules = [ self.homeModules.gthumb ];
  };
  flake.homeModules.gthumb = { pkgs, ... }: {
    home.packages = with pkgs; [ gthumb ];

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "image/png" = "org.gnome.gThumb.desktop";
      "image/jpeg" = "org.gnome.gThumb.desktop";
      "image/webp" = "org.gnome.gThumb.desktop";
      "image/gif" = "org.gnome.gThumb.desktop";
    };
  };
}
