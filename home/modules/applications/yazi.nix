{ config, pkgs, ... }: {
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
        folder = [{
          run = ''cd "$@"'';
          block = true;
        }];
        text = [{
          run = ''nvim "$@"'';
          block = true;
        }];
        image = [{
          run = ''imv "$@"'';
          fork = true;
        }];
        video = [{
          run = ''mpv "$@"'';
          fork = true;
        }];
        pdf = [{
          run = ''zathura "$@"'';
          fork = true;
        }];
        # edit = [{
        #   # Use the wrapper script instead of nvim directly (to get api keys from secrets)
        #   run = "$HOME/.local/bin/nvim-wrapper.sh %*";
        #   block = true;
        # }];
        edit = [{
          run = ''nvim "$@"'';
          block = true;
        }];
      };
    };
  };

  home.packages = with pkgs; [ ffmpegthumbnailer unar poppler_utils file jq ];

  home.file.".local/bin/nvim-wrapper.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # nvim-wrapper.sh

      # Define the path to your secrets loading script
      SECRETS_LOADER="$HOME/.dotfiles/home/modules/settings/secrets/load-secrets.sh"

      # Source the secrets if the loader script exists
      if [[ -f "$SECRETS_LOADER" ]]; then
        # Source in a subshell to avoid polluting the wrapper's environment unnecessarily,
        # although the export in load-secrets.sh will affect the subsequent nvim command.
        source "$SECRETS_LOADER"
      else
        echo "Warning: Secrets loader script not found at $SECRETS_LOADER" >&2
      fi

      # Execute nvim with all arguments passed to the wrapper script
      exec nvim "$@"
    '';
  };
}
