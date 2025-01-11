{ config, pkgs, userSettings, ... }:

{
  programs.git = {
    enable = true;
    userName = userSettings.name;
    userEmail = userSettings.email;
    extraConfig = {
      init = {
        defaultBranch = "main";
      };
    };
  };

  # SSH configuration
  programs.ssh = {
    enable = true;
    matchBlocks = {
      # This configures GitHub specifically
      "github.com" = {
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
    };
  };
}
