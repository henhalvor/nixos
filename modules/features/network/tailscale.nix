# Tailscale — mesh VPN
# Source: nixos/modules/server/tailscale.nix
{...}: {
  flake.nixosModules.tailscale = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };

    # Do not trust every service bound to tailscale0. Only the services that
    # intentionally accept direct tailnet traffic are reachable here;
    # Tailscale Serve proxies remain loopback-bound.
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [
        22 # SSH
        22000 # Syncthing transfer
      ];
      allowedUDPPorts = [
        21027 # Syncthing discovery
        22000 # Syncthing QUIC transfer
      ];
      allowedUDPPortRanges = [
        {
          from = 60000;
          to = 61000;
        } # Mosh
      ];
    };
  };
}
