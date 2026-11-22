{
  self,
  inputs,
  ...
}: let
  # KDE Connect from unstable: 26.04+ exposes `reachableAddresses` over D-Bus,
  # which the Noctalia AndroidConnect plugin uses to match the KDE Connect
  # device to its wireless adb connection (25.08 on stable lacks it).
  kdeconnectFor = pkgs:
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.kdePackages.kdeconnect-kde;
in {
  flake.nixosModules.kdeconnect = {pkgs, ...}: {
    home-manager.sharedModules = [self.homeModules.kdeconnect];

    programs.kdeconnect = {
      enable = true;
      package = kdeconnectFor pkgs;
    };

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
    services.kdeconnect = {
      enable = true;
      package = kdeconnectFor pkgs;
    };
  };
}
