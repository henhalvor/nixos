{ config, pkgs, unstable, ... }:

{
  # Your existing config...
  
  home.packages = with pkgs; [
    # Your existing packages...
    
    # Use aider-chat from unstable channel for latest version
    unstable.code-cursor
  ];
  
  # Rest of your config...
}
