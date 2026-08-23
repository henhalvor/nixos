# Sunshine remote game-streaming server.
#
# The display selection is deliberately declarative. Niri creates the stable
# `sunshine` virtual output, and Sunshine captures that output through the
# Wayland screencopy backend.
{ ... }:
{
  flake.nixosModules.sunshine = { pkgs, ... }:
  {
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = false;

      settings = {
        capture = "wlr";
        output_name = "sunshine";
        sunshine_name = "workstation";
      };

      applications = {
        apps = [
          {
            name = "Desktop (Sunshine virtual display)";
            "image-path" = "desktop.png";
          }
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      libva-utils
      cudatoolkit
    ];

    # Sunshine listens on all addresses, but the firewall admits its ports
    # only through the private Tailscale interface.
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [
        47984
        47989
        47990
        48010
      ];
      allowedUDPPorts = [
        47998
        47999
        48000
        48002
        48010
      ];
    };

  };
}
