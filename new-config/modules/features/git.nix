# Git — version control config with options
# Source: home/modules/settings/git.nix
# Template B: HM-only with options (user provides name/email)
{ self, ... }: {
  flake.nixosModules.git = { lib, ... }: {
    options.my.git = {
      userName = lib.mkOption {
        type = lib.types.str;
        description = "Git user name";
      };
      userEmail = lib.mkOption {
        type = lib.types.str;
        description = "Git user email";
      };
    };
    config = {
      home-manager.sharedModules = [ self.homeModules.git ];
    };
  };

  flake.homeModules.git = { config, lib, pkgs, osConfig, ... }: {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = osConfig.my.git.userName;
          email = osConfig.my.git.userEmail;
        };
        init.defaultBranch = "main";
        pull.rebase = false;
      };
    };

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
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "${osConfig.my.git.userEmail}" -f "${config.home.homeDirectory}/.ssh/id_ed25519" -N ""
          echo "New SSH key generated for GitHub. Please add this public key to your GitHub account:"
          cat "${config.home.homeDirectory}/.ssh/id_ed25519.pub"
        fi
      '';
    };

    programs.gh = {
      enable = true;
      settings.editor = "nvim";
      settings.git_protocol = "ssh";
    };
  };
}
