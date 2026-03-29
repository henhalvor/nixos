{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cockpit
 ];


  services.cockpit = {
    enable = true;
    port = 9443;
  };


  networking.firewall.allowedTCPPorts = [ 9443 ];
}
