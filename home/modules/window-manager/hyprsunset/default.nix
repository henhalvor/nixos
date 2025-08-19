{ config, pkgs, lib, ... }: { 

  home.packages = with pkgs; [ hyprsunset ];
  services.hyprsunset.enable = true; }
