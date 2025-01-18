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
    prefix = "C-b";
    terminal = "tmux-256color";
    
    plugins = with pkgs.tmuxPlugins; [
      # Essential plugins
      sensible
      vim-tmux-navigator
      resurrect
      continuum
      
      # Theme
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour 'machiato'
          set -g @catppuccin_window_right_separator "█"
          set -g @catppuccin_window_number_position "right"
          set -g @catppuccin_window_middle_separator " "
          set -g @catppuccin_window_default_fill "none"
          set -g @catppuccin_window_current_fill "all"
          set -g @catppuccin_status_modules_right "directory session"
          set -g @catppuccin_status_left_separator "█"
          set -g @catppuccin_status_right_separator "█"
        '';
      }
    ];

    extraConfig = ''
      # Load status bar config
      ${statusBar}
      
      # Additional quality of life settings
      set -g focus-events on
      set -sa terminal-features ',xterm-256color:RGB'
      set -g automatic-rename on
      set -g renumber-windows on
      
      # Better split shortcuts
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
    '';
  };
}

# { config, lib, pkgs, ... }:
#
# {
#   programs.tmux = {
#     enable = true;
#
#     # Shortcut for reloading config
#     keyMode = "vi";
#     prefix = "C-b";  # Default prefix key
#
#     # Basic settings
#     baseIndex = 1;  # Start numbering windows at 1
#     escapeTime = 0; # No delay for escape key press
#     historyLimit = 5000;
#     mouse = true;
#
#     # Custom key bindings
#     extraConfig = ''
#       # Reload config
#       bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"
#
#       # Better split shortcuts
#       bind | split-window -h
#       bind - split-window -v
#
#       # Automatic window renaming
#       set-option -g automatic-rename on
#
#       # Terminal colors
#       set -g default-terminal "tmux-256color"
#       set -ag terminal-overrides ",xterm-256color:RGB"
#
#       # Status bar customization
#       set -g status-style 'bg=#333333 fg=#5eacd3'
#     '';
#
#     # Plugins (optional)
#     plugins = with pkgs.tmuxPlugins; [
#       sensible    # Sensible defaults
#       resurrect   # Save and restore sessions
#       continuum   # Automatic session saving
#     ];
#   };
# }
