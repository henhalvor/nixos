# External I/O — udisks2 for removable storage management
# Source: nixos/modules/external-io.nix
{...}: {
  flake.nixosModules.externalIo = {...}: {
    services.udisks2.enable = true;
  };
}
