# LibreOffice — office suite with spell checking
# Source: home/modules/applications/libreoffice.nix
{ self, ... }: {
  flake.nixosModules.libreoffice = { ... }: {
    home-manager.sharedModules = [ self.homeModules.libreoffice ];
  };

  flake.homeModules.libreoffice = { pkgs, ... }: {
    home.packages = with pkgs; [
      libreoffice
      hunspell
      hunspellDicts.en-us
      hunspellDicts.nb_NO
    ];
  };
}
