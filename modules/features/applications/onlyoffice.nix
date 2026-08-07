# onlyOffice — office suite with spell checking
# Source: home/modules/applications/onlyoffice.nix
{ self, ... }:
{
  flake.nixosModules.onlyoffice =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.onlyoffice ];
    };

  flake.homeModules.onlyoffice =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        onlyoffice-desktopeditors
        corefonts
      ];
    };
}
