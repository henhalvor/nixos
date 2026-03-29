# Tmux — terminal multiplexer
# Source: home/modules/applications/tmux.nix
# Template B2: HM-only
{ self, ... }: {
  flake.nixosModules.tmux = { ... }: {
    home-manager.sharedModules = [ self.homeModules.tmux ];
  };

  flake.homeModules.tmux = { pkgs, ... }: let
    is_vim = pkgs.writeShellScriptBin "is_vim.sh" ''
      pane_pid=$(tmux display -p "#{pane_pid}")
      [ -z "$pane_pid" ] && exit 1
      descendants=$(ps -eo pid=,ppid=,stat= | awk -v pid="$pane_pid" '{
          if ($3 !~ /^T/) { pid_array[$1]=$2 }
      } END {
          for (p in pid_array) {
              current_pid = p
              while (current_pid != "" && current_pid != "0") {
                  if (current_pid == pid) { print p; break }
                  current_pid = pid_array[current_pid]
              }
          }
      }')
      if [ -n "$descendants" ]; then
          descendant_pids=$(echo "$descendants" | tr '\n' ',' | sed 's/,$//')
          ps -o args= -p "$descendant_pids" | grep -iqE "(^|/)([gn]?vim?x?)(diff)?"
          if [ $? -eq 0 ]; then exit 0; fi
      fi
      exit 1
    '';
  in {
    programs.tmux = {
      enable = true;
      baseIndex = 1;
      escapeTime = 0;
      keyMode = "vi";
      mouse = true;
      terminal = "tmux-256color";

      plugins = with pkgs.tmuxPlugins; [
        sensible
        vim-tmux-navigator
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '15'
          '';
        }
        {
          plugin = tmux-sessionx;
          extraConfig = ''
            set -g @sessionx-bind 'o'
            set -g @sessionx-x-path '$HOME'
            set -g @sessionx-custom-paths '/home/henhal/code,/home/henhal/dotfiles'
            set -g @sessionx-custom-paths-subdirectories 'true'
            set -g @sessionx-zoxide-mode 'on'
          '';
        }
      ];

      extraConfig = ''
        set -sg terminal-overrides ",*:RGB"
        set -g escape-time 0
        set -g mouse on
        set -g renumber-windows on
        set -g repeat-time 1000

        set -g base-index 1
        set -g pane-base-index 1

        # Theme: borders
        set -g pane-border-lines simple
        set -g pane-border-style fg=black,bright

        # Theme: status
        set -g status-position top
        set -g status-style bg=default,fg=black,bright
        set -g status-left ""
        set -g status-right "#[fg=black,bright]#S"

        set -g window-status-format "#[fg=gray]●"
        set -g window-status-current-format "●"

        # OSC52 clipboard
        set-option -g set-clipboard on
        set-option -ga terminal-features ',xterm-256color:clipboard'

        # Reload config
        bind r source-file ~/.config/tmux/tmux.conf

        # Dynamic sizing
        set -g aggressive-resize on
        set-hook -g client-attached 'refresh-client -S'
        set-option -g allow-rename off

        # Vim movement
        bind-key -n 'C-h' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-h' 'select-pane -L'
        bind-key -n 'C-j' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-j' 'select-pane -D'
        bind-key -n 'C-k' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-k' 'select-pane -U'
        bind-key -n 'C-l' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-l' 'select-pane -R'

        bind-key -T copy-mode-vi 'C-h' select-pane -L
        bind-key -T copy-mode-vi 'C-j' select-pane -D
        bind-key -T copy-mode-vi 'C-k' select-pane -U
        bind-key -T copy-mode-vi 'C-l' select-pane -R

        set -g focus-events on
        set -sa terminal-features ',xterm-256color:RGB'
        set -g automatic-rename on
        set -g renumber-windows on

        # Better splits
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
      '';
    };
  };
}
