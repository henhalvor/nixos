{ config, pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "server" = {
        hostname = "10.0.0.17";
        user = "henhal";
      };
    };
  };

}
