{
  config,
  lib,
  pkgs,
  ...
}: let
  # Status bar configuration using Machiato colors
  # statusBar = ''
  #   # Status bar styling
  #   set -g status "on"
  #   set -g status-position top
  #   set -g status-justify "left"
  # '';
  #
  is_vim =
    pkgs.writeShellScriptBin "is_vim.sh"
    # bash
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
       # set -g @catppuccin_flavor 'macchiato' # latte, frappe, macchiato or mocha

       #
       # Old commented out config
       #

       # Status bar styling

       # set -g status "on"
       # set -g status-position top
       #
       # set -g @catppuccin_window_left_separator ""
       # set -g @catppuccin_window_right_separator " "
       # set -g @catppuccin_window_middle_separator " █"
       # set -g @catppuccin_window_number_position "right"
       #
       # set -g @catppuccin_window_default_fill "number"
       # set -g @catppuccin_window_default_text "#W"
       #
       # set -g @catppuccin_window_current_fill "number"
       # set -g @catppuccin_window_current_text "#W"
       #
       # set -g @catppuccin_status_modules_right "directory session"
       # set -g @catppuccin_status_left_separator  " "
       # set -g @catppuccin_status_right_separator ""
       # set -g @catppuccin_status_right_separator_inverse "no"
       # set -g @catppuccin_status_fill "icon"
       # set -g @catppuccin_status_connect_separator "no"
       #
       # set -g @catppuccin_directory_text "#{pane_current_path}"

       #
       #
       #


      #
      # New config
      #

      # Options
      set -sg terminal-overrides ",*:RGB"  # true color support
      set -g escape-time 0  # disable delays on escape sequences
      set -g mouse on
      set -g renumber-windows on  # keep numbering sequential
      set -g repeat-time 1000  # increase "prefix-free" window

      # Options: start indexes from 1
      set -g base-index 1
      set -g pane-base-index 1

           # Theme: borders
      set -g pane-border-lines simple
      set -g pane-border-style fg=black,bright
       # set -g pane-active-border-style fg=#89b4fa

      # Theme: status

      set -g status-position top
      set -g status-style bg=default,fg=black,bright
      set -g status-left ""
      set -g status-right "#[fg=black,bright]#S"

      # Theme: status (windows)
       set -g window-status-format "#[fg=gray]●"
      set -g window-status-current-format "●"
       # set -g window-status-current-style "#{?window_zoomed_flag,fg=yellow,fg=#89b4fa,nobold}"
      # set -g window-status-bell-style "fg=red,nobold"

      #
      #
      #

      # Enable OSC52 clipboard integration
      set-option -g set-clipboard on

      # Optional but recommended: allows terminals that support direct OSC52 copying
      set-option -ga terminal-features ',xterm-256color:clipboard'


       # Reload config
       bind r source-file ~/.config/tmux/tmux.conf

        # --- Dynamic sizing between different terminals ---
        set -g aggressive-resize on
        set-hook -g client-attached 'refresh-client -A'

        # (optional) ensure the first attached client defines window size
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




       # Additional quality of life settings
       set -g focus-events on
       # set -sa terminal-features ',xterm-256color:RGB'
       set -g automatic-rename on
       set -g renumber-windows on

       # Better split shortcuts
       bind | split-window -h -c "#{pane_current_path}"
       bind - split-window -v -c "#{pane_current_path}"

       # Automatically restore last saved environment when tmux is started
       set -g @continuum-restore 'on'

       # Save sessions every 15 minutes
       set -g @continuum-save-interval '15'


      # MOSH
      # When detaching, kill the client
      # Added for auto killing mosh session when detaching
      set -g detach-on-destroy on
    '';
  };
}
