# Firewall — general-purpose open ports
# Service-specific ports stay in their own feature modules (cockpit, tailscale, ...).
{...}: {
  flake.nixosModules.firewall = {...}: {
    networking.firewall = {
      enable = true;
      # 8081: Metro bundler, so physical devices on the LAN can reach the dev server
      allowedTCPPorts = [8081];
    };
  };
}
