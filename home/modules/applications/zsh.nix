{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../scripts/search-with-zoxide.nix
  ];

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = ["git"];
    };
    shellAliases = {
      v = "nvim";
      lzg = "lazygit";
      cd = "z";
      f = "fzf";
      fman = "compgen -c | fzf | xargs man";
      nzo = "search-with-zoxide";
      # Git
      ga = "git add .";
      gc = "git commit";
      gs = "git status";
      gd = "git diff";
      gl = "git log";
      gp = "git push";
      gpl = "git pull";
      gco = "git checkout";
      gb = "git branch";
    };
    sessionVariables = {
      FZF_DEFAULT_COMMAND = "fd --hidden  --strip-cwd-prefix --exclude .git"; # Search for files
      FZF_CRTL_T_COMMAND = "fd --hidden  --strip-cwd-prefix --exclude .git"; # Same as default
      FZF_ALT_C_COMMAND = "fd --type d --hidden  --strip-cwd-prefix --exclude .git"; # Search for directories
      FZF_DEFAULT_OPTS = "--height 50% --layout=default --border";
      FZF_TMUX_OPTS = " -p90%,70% ";
      FZF_CTRL_T_OPTS = "--preview 'bat --color=always -n --line-range= :500 {}'";
      FZF_ALT_C_OPTS = "--preview 'eza --tree --color=always {} | head -n 50'";
    };
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initContent = ''
            # First source the theme
            source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
            # Then source your configuration
            [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

       # Define a function to load secrets with better debugging
            load_secrets() {
              local secrets_file="$HOME/.dotfiles/home/modules/settings/secrets/secrets.env"

              #echo "Attempting to load secrets from: $secrets_file"

              # Check if file exists
              if [[ ! -f "$secrets_file" ]]; then
                echo "Error: Secrets file does not exist"
                return 1
              fi

              # Check if file is readable
              if [[ ! -r "$secrets_file" ]]; then
                echo "Error: Secrets file is not readable"
                return 1
              fi

              # Check file permissions
              local file_perms=$(stat -c %a "$secrets_file")

              #echo "Current file permissions: $file_perms"

              if [[ "$file_perms" != "600" ]]; then
                echo "Warning: Secrets file should have permissions 600"
              fi

              # Read and process the file with debugging

              #echo "Reading secrets file..."

              while IFS= read -r line || [[ -n "$line" ]]; do
                # Skip empty lines and comments
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
                  echo "Skipping comment or empty line"
                  continue
                fi

                # Debug: Show what we're about to export (but mask the actual value)
                local key=$(echo "$line" | cut -d'=' -f1)

                # echo "Exporting: $key"

                # Export the variable
                export "$line"
              done < "$secrets_file"

              # Verify the export worked
              if [[ -n "$ANTHROPIC_API_KEY" ]]; then

                # echo "ANTHROPIC_API_KEY was successfully loaded"

              else
                echo "Warning: ANTHROPIC_API_KEY was not found or is empty"
              fi

              # echo "Secrets loading complete"
            }

            # Create an alias for easier use
            alias reload_secrets='load_secrets'



       # Set up a precmd hook that runs once after shell initialization
            load_secrets_once() {
              load_secrets
              # Remove this function from precmd hooks after it runs
              local hook_index
              hook_index=''${precmd_functions[(i)load_secrets_once]}
              if [[ $hook_index -le ''${#precmd_functions} ]]; then
                unset "precmd_functions[$hook_index]"
              fi
            }

            # Add our loading function to precmd hooks
            precmd_functions+=( load_secrets_once )

      # Disable forward incremental search (conflicts with tmux prefix keybind)
        bindkey -r "^S"
        bindkey -r "^R"

      # Bind Ctrl-F to search-with-zoxide
      # bindkey -s "^E" "search-with-zoxide\n"

      # Neovim old files picker using fzf
        nlof() {
          local oldfiles
          oldfiles=$(nvim -u NONE --headless +'lua io.write(table.concat(vim.v.oldfiles, "\n"))' +qa)

          [[ -z "$oldfiles" ]] && return

          local files
          files=$(echo "$oldfiles" | \
            while read -r file; do
              [[ -f "$file" ]] && echo "$file"
            done | \
            fzf --multi \
              --preview 'bat -n --color=always --line-range=:500 {} 2>/dev/null || echo "Error previewing file"' \
              --height=70% \
              --layout=default)

          [[ -n "$files" ]] && nvim $files
        }

        # Optional explicit alias (not required since function name matches)
        alias nlof='nlof'
      # Bind Ctrl-E to neovim old files
        bindkey -s "^F" "nlof\n"




    '';
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      save = 10000;
      ignoreDups = true;
      share = true;
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Link your p10k config file
  home.file.".p10k.zsh" = {
    source = ../../config/.p10k.zsh;
    onChange = ''
      # This ensures the config is reloaded when the file changes
      if [[ -n "$ZDOTDIR" ]]; then
        zsh_path="$ZDOTDIR/.zshrc"
      else
        zsh_path="$HOME/.zshrc"
      fi
      if [[ -f "$zsh_path" ]]; then
        source "$zsh_path"
      fi
    '';
  };
}
