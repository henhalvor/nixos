# Mission Center — system monitor
# Source: home/modules/applications/mission-center.nix
{ self, ... }: {
  flake.nixosModules.missionCenter = { ... }: {
    home-manager.sharedModules = [ self.homeModules.missionCenter ];
  };
  flake.homeModules.missionCenter = { pkgs, ... }: {
    home.packages = with pkgs; [ mission-center ];
  };
}
