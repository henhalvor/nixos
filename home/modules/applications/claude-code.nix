
{ config, pkgs, unstable, ... }:

{
  # Your existing config...
  
  home.packages = with pkgs; [
    unstable.claude-code
  ];
  
  # Rest of your config...
}
