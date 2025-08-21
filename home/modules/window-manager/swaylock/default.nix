{ pkgs, config, ... }:
let
  # Access stylix colors
  colors = config.lib.stylix.colors;
in {
  # Ensure swaylock and swayidle packages are installed
  home.packages = [ pkgs.swaylock ];

  # Configure swaylock using the Home Manager module
  programs.swaylock = {
    enable = true;
    settings = {
      # -- Appearance --
      image = "${config.stylix.image}"; # Use stylix wallpaper
      # Base background color (behind image or if image fails)
      color = colors.base00; # Base background from stylix
      scaling = "fill"; # Optional: specify scaling explicitly

      # -- Font --
      font = config.stylix.fonts.monospace.name; # Use stylix font
      font-size = config.stylix.fonts.sizes.applications; # Use stylix font size

      # -- Indicator --
      indicator-idle-visible = true;
      indicator-radius = 120;
      indicator-thickness = 10;
      separator-color = colors.base01; # Surface color for separators

      # -- Base Colors --
      inside-color = colors.base00; # Base background
      ring-color = colors.base0D; # Blue accent color
      text-color = colors.base05; # Main text color

      # -- Highlight Colors --
      key-hl-color = colors.base0D; # Blue for key highlights
      bs-hl-color = colors.base09; # Orange for backspace highlights

      # -- State Colors: Verifying --
      inside-ver-color = colors.base00;
      ring-ver-color = colors.base0B; # Green for verification
      text-ver-color = colors.base05;

      # -- State Colors: Wrong --
      inside-wrong-color = colors.base00;
      ring-wrong-color = colors.base08; # Red for wrong password
      text-wrong-color = colors.base05;

      # -- State Colors: Cleared --
      inside-clear-color = colors.base00;
      ring-clear-color = colors.base0A; # Yellow for cleared
      text-clear-color = colors.base05;

      # -- State Colors: Caps Lock --
      inside-caps-lock-color = colors.base00;
      ring-caps-lock-color = colors.base0D; # Blue for caps lock
      text-caps-lock-color = colors.base0A; # Yellow text for caps lock

      # -- Layout Box (for -k option, if used) --
      layout-bg-color = colors.base01;
      layout-border-color = colors.base01;
      layout-text-color = colors.base05;

      # -- Misc --
      show-failed-attempts = true; # Keep from your example and working command
      # disable-caps-lock-text = false;
      # ignore-empty-password = false;
      # indicator-caps-lock = false; # Corresponds to -l flag
      # show-keyboard-layout = false; # Corresponds to -k flag
    };
  };

}
