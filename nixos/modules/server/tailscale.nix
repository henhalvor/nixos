# /etc/nixos/modules/tailscale.nix or similar
{ config, pkgs, ... }:

{
  services.tailscale.enable = true;

  # Since your server hosts services (SSH, Grafana, Prometheus) that you want
  # to access *from* other Tailscale devices, it's often easiest to trust
  # the Tailscale interface in your firewall. This allows connections
  # *over Tailscale* to reach the services listening on the server, without
  # needing to manage specific port openings for the Tailscale IP range.
  # The existing allowedTCPPorts apply to your physical network interfaces.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Note: You generally DON'T need `useRoutingFeatures` unless this server
  # will act as an exit node (routing all internet traffic for other devices)
  # or a subnet router (giving access to your whole LAN via Tailscale).
  # For simple device-to-device access, just enabling is enough.
}
