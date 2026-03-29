# Zathura — PDF viewer with MIME associations
# Source: home/modules/applications/zathura.nix
{ self, ... }: {
  flake.nixosModules.zathura = { ... }: {
    home-manager.sharedModules = [ self.homeModules.zathura ];
  };

  flake.homeModules.zathura = { pkgs, ... }: {
    home.packages = with pkgs; [ zathura ];
    programs.zathura.enable = true;

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "application/pdf" = "org.pwmt.zathura.desktop";
    };
  };
}
