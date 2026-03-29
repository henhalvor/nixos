# Cockpit — web-based server management
# Source: nixos/modules/server/cockpit.nix
# Currently unused but migrated for completeness.
{...}: {
  flake.nixosModules.cockpit = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [cockpit];

    services.cockpit = {
      enable = true;
      port = 9443;
    };

    networking.firewall.allowedTCPPorts = [9443];
  };
}
