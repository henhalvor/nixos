# Moonlight Qt client for connecting to Sunshine hosts.
{ ... }:
{
  flake.nixosModules.moonlight = { pkgs, ... }:
  {
    environment.systemPackages = [ pkgs.moonlight-qt ];
  };
}
