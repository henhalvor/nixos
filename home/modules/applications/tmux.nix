{
  config,
  lib,
  pkgs,
  ...
}: let
  # Status bar configuration using Machiato colors
  statusBar = ''
    # Status bar styling
    set -g status "on"
    set -g status-position top
    set -g status-justify "left"
  '';

  is_vim =
    pkgs.writeShellScriptBin "is_vim.sh"
    /*
    bash
    */
    ''
      pane_pid=$(tmux display -p "#{pane_pid}")

      [ -z "$pane_pid" ] && exit 1

      # Retrieve all descendant processes of the tmux pane's shell by iterating through the process tree.
      # This includes child processes and their descendants recursively.
      descendants=$(ps -eo pid=,ppid=,stat= | awk -v pid="$pane_pid" '{
          if ($3 !~ /^T/) {
              pid_array[$1]=$2
          }
      } END {
          for (p in pid_array) {
              current_pid = p
              while (current_pid != "" && current_pid != "0") {
                  if (current_pid == pid) {
                      print p
                      break
                  }
                  current_pid = pid_array[current_pid]
              }
          }
      }')

      if [ -n "$descendants" ]; then

          descendant_pids=$(echo "$descendants" | tr '\n' ',' | sed 's/,$//')

          ps -o args= -p "$descendant_pids" | grep -iqE "(^|/)([gn]?vim?x?)(diff)?"

          if [ $? -eq 0 ]; then
              exit 0
          fi
      fi

      exit 1
    '';
in {
  programs.tmux = {
    enable = true;

    # Core settings
    baseIndex = 1;
    escapeTime = 0;
    keyMode = "vi";
    mouse = true;
    # prefix = "C-s";
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      # Essential plugins
      sensible
      vim-tmux-navigator
      resurrect
      continuum
      catppuccin
    ];

    extraConfig = ''
       # Theme
       set -g @catppuccin_flavor 'macchiato' # latte, frappe, macchiato or mocha

       # Vim movement
      bind-key -n 'C-h' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-h' 'select-pane -L'
       bind-key -n 'C-j' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-j' 'select-pane -D'
       bind-key -n 'C-k' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-k' 'select-pane -U'
       bind-key -n 'C-l' if-shell '${is_vim}/bin/is_vim.sh' 'send-keys C-l' 'select-pane -R'

       bind-key -T copy-mode-vi 'C-h' select-pane -L
       bind-key -T copy-mode-vi 'C-j' select-pane -D
       bind-key -T copy-mode-vi 'C-k' select-pane -U
       bind-key -T copy-mode-vi 'C-l' select-pane -R      # Status bar styling
       set -g status "on"
       set -g status-position top

       set -g @catppuccin_window_left_separator ""
       set -g @catppuccin_window_right_separator " "
       set -g @catppuccin_window_middle_separator " █"
       set -g @catppuccin_window_number_position "right"

       set -g @catppuccin_window_default_fill "number"
       set -g @catppuccin_window_default_text "#W"

       set -g @catppuccin_window_current_fill "number"
       set -g @catppuccin_window_current_text "#W"

       set -g @catppuccin_status_modules_right "directory session"
       set -g @catppuccin_status_left_separator  " "
       set -g @catppuccin_status_right_separator ""
       set -g @catppuccin_status_right_separator_inverse "no"
       set -g @catppuccin_status_fill "icon"
       set -g @catppuccin_status_connect_separator "no"

       set -g @catppuccin_directory_text "#{pane_current_path}"

       # Reload config
       bind r source-file ~/.config/tmux/tmux.conf


       # Additional quality of life settings
       set -g focus-events on
       set -sa terminal-features ',xterm-256color:RGB'
       set -g automatic-rename on
       set -g renumber-windows on

       # Better split shortcuts
       bind | split-window -h -c "#{pane_current_path}"
       bind - split-window -v -c "#{pane_current_path}"

       # Automatically restore last saved environment when tmux is started
       set -g @continuum-restore 'on'

       # Save sessions every 15 minutes
       set -g @continuum-save-interval '15'
    '';
  };
}
