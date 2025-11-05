{ config, lib, pkgs, userSettings, ... }:

{
  programs.git = {
    enable = true;
    userName = userSettings.username;
    userEmail = userSettings.email;
    extraConfig = {
      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = false;
      };
    };
  };
  #
  # # SSH configuration
  # programs.ssh = {
  #   enable = true;
  #   matchBlocks = {
  #     # This configures GitHub specifically
  #     "github.com" = {
  #       identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
  #     };
  #   };
  # };
  #

  # SSH configuration
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
        extraOptions = {
          AddKeysToAgent = "yes";
          IdentitiesOnly = "yes";
        };
      };
    };
  };

  # Generate SSH key if it doesn't exist
  home.activation = {
    generateGitHubSSHKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${config.home.homeDirectory}/.ssh/id_ed25519" ]; then
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "${userSettings.email}" -f "${config.home.homeDirectory}/.ssh/id_ed25519" -N ""
        echo "New SSH key generated for GitHub. Please add this public key to your GitHub account:"
        cat "${config.home.homeDirectory}/.ssh/id_ed25519.pub"
      fi
    '';
  };
}
