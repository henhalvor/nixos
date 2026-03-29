# Networking — NetworkManager
# Source: nixos/modules/networking.nix
# Note: networking.hostName is set per-host in configuration.nix, not here.
{...}: {
  flake.nixosModules.networking = {...}: {
    networking.networkmanager.enable = true;
  };
}
