# Yazi — terminal file manager
# Source: home/modules/applications/yazi.nix
# Template B2: HM-only
{ self, ... }: {
  flake.nixosModules.yazi = { ... }: {
    home-manager.sharedModules = [ self.homeModules.yazi ];
  };

  flake.homeModules.yazi = { config, pkgs, ... }: {
    programs.yazi = {
      enable = true;
      settings = {
        manager = {
          show_hidden = true;
          sort_by = "natural";
          sort_dir_first = true;
          sort_sensitive = false;
        };
        preview = {
          max_width = 1024;
          max_height = 1024;
        };
        opener = {
          folder = [{ run = ''cd "$@"''; block = true; }];
          text = [{ run = ''nvim "$@"''; block = true; }];
          image = [{ run = ''imv "$@"''; fork = true; }];
          video = [{ run = ''mpv "$@"''; fork = true; }];
          pdf = [{ run = ''zathura "$@"''; fork = true; }];
          edit = [{ run = ''nvim "$@"''; block = true; }];
        };
      };
    };

    home.packages = with pkgs; [ ffmpegthumbnailer unar poppler-utils file jq ];

    home.file.".local/bin/nvim-wrapper.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        SECRETS_LOADER="$HOME/.dotfiles/home/modules/settings/secrets/load-secrets.sh"
        if [[ -f "$SECRETS_LOADER" ]]; then
          source "$SECRETS_LOADER"
        else
          echo "Warning: Secrets loader script not found at $SECRETS_LOADER" >&2
        fi
        exec nvim "$@"
      '';
    };
  };
}
