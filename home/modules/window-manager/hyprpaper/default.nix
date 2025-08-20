{ pkgs, ... }:

{
  home.packages = [ pkgs.hyprpaper ];
  #
  # # Create hyprpaper config file
  # xdg.configFile."hypr/hyprpaper.conf".text = ''
  #   preload = ~/.dotfiles/assets/wallpapers/catpuccin_landscape.png
  #
  #
  #   wallpaper = ,~/.dotfiles/assets/wallpapers/catpuccin_landscape.png
  #   # If you have multiple monitors you can specify which wallpaper goes to which monitor
  #   # wallpaper = monitor1,/path/to/wallpaper1.jpg
  #   # wallpaper = monitor2,/path/to/wallpaper2.jpg
  #
  #   # Optional settings
  #   ipc = off
  #   splash = false
  # '';

  # # Add hyprpaper to Hyprland's autostart
  # wayland.windowManager.hyprland.settings.exec-once = [
  #   "hyprpaper"
  # ];
}
