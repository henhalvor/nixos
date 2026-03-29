# Tailscale — mesh VPN
# Source: nixos/modules/server/tailscale.nix
{...}: {
  flake.nixosModules.tailscale = {...}: {
    services.tailscale.enable = true;
    networking.firewall.trustedInterfaces = ["tailscale0"];
  };
}
