{ config, lib, pkgs, ... }:

let
  # Status bar configuration using Machiato colors
  statusBar = ''
    # Status bar styling
    set -g status "on"
    set -g status-position top
    set -g status-justify "left"
  '';
in
{
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
      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R

      # Status bar styling
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

