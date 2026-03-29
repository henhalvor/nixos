# Zsh — shell with oh-my-zsh, powerlevel10k, zoxide
# Source: home/modules/applications/zsh.nix + search-with-zoxide.nix
# Template D: HM feature + standalone package
{ self, ... }: {
  flake.nixosModules.zsh = { ... }: {
    # Enable zsh at system level so it can be used as login shell
    programs.zsh.enable = true;
    home-manager.sharedModules = [ self.homeModules.zsh ];
  };

  flake.homeModules.zsh = { config, pkgs, ... }: let
    search-with-zoxide = pkgs.writeShellScriptBin "search-with-zoxide" ''
      #!/bin/bash
      search_with_zoxide() {
          if [ -z "$1" ]; then
              file="$(fd --type f -I -H -E .git -E .git-crypt -E .cache -E .backup -E node_modules -E dist -E build -E target -E .direnv -E .vscode -E coverage -E .next -E .turbo -E out -E tmp -E vendor | fzf --height=70% --preview='bat -n --color=always --line-range :500 {}')"
              if [ -n "$file" ]; then
                  nvim "$file"
              fi
          else
              lines=$(zoxide query -l | xargs -I {} fd --type f -I -H -E .git -E .git-crypt -E .cache -E .backup -E .vscode -E node_modules -E dist -E build -E target -E .direnv -E coverage -E .next -E .turbo -E out -E tmp -E vendor "$1" {} | fzf --no-sort)
              line_count="$(echo "$lines" | wc -l | xargs)"

              if [ -n "$lines" ] && [ "$line_count" -eq 1 ]; then
                  file="$lines"
                  nvim "$file"
              elif [ -n "$lines" ]; then
                  file=$(echo "$lines" | fzf --query="$1" --height=70% --preview='bat -n --color=always --line-range :500 {}')
                  if [ -n "$file" ]; then
                      nvim "$file"
                  fi
              else
                  echo "No matches found." >&2
              fi
          fi
      }
      search_with_zoxide "$@"
    '';
  in {
    home.packages = [ search-with-zoxide ];

    programs.zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" ];
      };
      shellAliases = {
        v = "nvim";
        c = "clear";
        lzg = "lazygit";
        cd = "z";
        f = "fzf";
        fman = "compgen -c | fzf | xargs man";
        nzo = "search-with-zoxide";
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
        FZF_DEFAULT_COMMAND = "fd --hidden  --strip-cwd-prefix --exclude .git";
        FZF_CRTL_T_COMMAND = "fd --hidden  --strip-cwd-prefix --exclude .git";
        FZF_ALT_C_COMMAND = "fd --type d --hidden  --strip-cwd-prefix --exclude .git";
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
        # Powerlevel10k
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
        [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

        # Secrets loader
        load_secrets() {
          local secrets_file="$HOME/.dotfiles/home/modules/settings/secrets/secrets.env"
          if [[ ! -f "$secrets_file" ]]; then
            echo "Error: Secrets file does not exist"
            return 1
          fi
          if [[ ! -r "$secrets_file" ]]; then
            echo "Error: Secrets file is not readable"
            return 1
          fi
          local file_perms=$(stat -c %a "$secrets_file")
          if [[ "$file_perms" != "600" ]]; then
            echo "Warning: Secrets file should have permissions 600"
          fi
          while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
              continue
            fi
            export "$line"
          done < "$secrets_file"
        }
        alias reload_secrets='load_secrets'

        # Load secrets once on shell init
        load_secrets_once() {
          load_secrets
          local hook_index
          hook_index=''${precmd_functions[(i)load_secrets_once]}
          if [[ $hook_index -le ''${#precmd_functions} ]]; then
            unset "precmd_functions[$hook_index]"
          fi
        }
        precmd_functions+=( load_secrets_once )

        # Key bindings
        bindkey -r "^S"
        bindkey -r "^R"

        # Neovim old files picker
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
        alias nlof='nlof'
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

    # p10k config — user manages ~/.p10k.zsh manually or via dotfiles
    home.file.".p10k.zsh" = {
      source = ./p10k.zsh;
      onChange = ''
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
  };
}
