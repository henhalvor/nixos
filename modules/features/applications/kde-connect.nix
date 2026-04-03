{self, ...}: {
  flake.nixosModules.kdeconnect = {...}: {
    home-manager.sharedModules = [self.homeModules.kdeconnect];

    programs.kdeconnect.enable = true;

    networking.firewall = rec {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
  };

  flake.homeModules.kdeconnect = {pkgs, ...}: {
    services.kdeconnect.enable = true;
  };
}
