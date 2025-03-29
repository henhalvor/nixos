{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [ wlogout ];

  programs.wlogout = {
    enable = true;

  };
}
