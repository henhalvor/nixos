{ pkgs, ... }:

{
  home.packages = with pkgs; [ amazon-q-cli ];
}

