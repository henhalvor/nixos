
{ config, pkgs, ... }:
{
  # Install Edge and our wrapper
  home.packages = with pkgs; [
    mission-center
  ];


}
