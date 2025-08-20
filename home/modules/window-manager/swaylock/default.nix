{ pkgs, config, ... }: # Ensure config is passed

let
  # Catppuccin Macchiato palette (reuse from previous config)
  macchiato = {
    rosewater = "f4dbd6";
    flamingo = "f0c6c6";
    pink = "f5bde6";
    mauve = "c6a0f6";
    red = "ed8796";
    maroon = "ee99a0";
    peach = "f5a97f";
    yellow = "eed49f";
    green = "a6da95";
    teal = "8bd5ca";
    sky = "91d7e3";
    sapphire = "7dc4e4";
    blue = "8aadf4";
    lavender = "b7bdf8";
    text = "cad3f5";
    subtext1 = "b8c0e0";
    subtext0 = "a5adce";
    overlay2 = "939ab7";
    overlay1 = "8087a2";
    overlay0 = "6e738d";
    surface2 = "5b6078";
    surface1 = "494d64";
    surface0 = "363a4f";
    base = "24273a";
    mantle = "1e2030";
    crust = "181926";
  };

  # Verify this image path is correct!
  imagePath =
    "${config.home.homeDirectory}/.dotfiles/assets/wallpapers/catpuccin_landscape.png";
  # Or, if the image is relative to this Nix file (recommended):
  # imagePath = "${./relative/path/to/catpuccin_landscape.png}";

in {
  # Ensure swaylock and swayidle packages are installed
  home.packages = [ pkgs.swaylock ];

  # Configure swaylock using the Home Manager module
  programs.swaylock = {
    enable = true;
    settings = {
      # -- Appearance --
      image = imagePath;
      # Base background color (behind image or if image fails)
      color = macchiato.base; # Set to base color instead of black/white
      scaling = "fill"; # Optional: specify scaling explicitly

      # -- Font --
      font = "Hack Nerd Font"; # Make sure this matches your installed Nerd Font
      font-size = 24; # Keep font size from your example

      # -- Indicator --
      indicator-idle-visible = true; # Keep from your example
      indicator-radius = 120; # Use radius from working command
      indicator-thickness = 10; # Use thickness from working command
      # line-color = macchiato.surface1; # Color between ring/inside (optional, defaults often ok)
      separator-color = macchiato.surface1; # Color for highlight separators

      # -- Base Colors --
      inside-color = macchiato.surface0;
      ring-color = macchiato.lavender; # Base ring color
      text-color = macchiato.text;

      # -- Highlight Colors --
      key-hl-color = macchiato.blue;
      bs-hl-color = macchiato.peach;

      # -- State Colors: Verifying --
      inside-ver-color = macchiato.surface0;
      ring-ver-color = macchiato.green;
      text-ver-color = macchiato.text;

      # -- State Colors: Wrong --
      inside-wrong-color = macchiato.surface0;
      ring-wrong-color = macchiato.red;
      text-wrong-color = macchiato.text;

      # -- State Colors: Cleared --
      inside-clear-color = macchiato.surface0;
      ring-clear-color = macchiato.yellow;
      text-clear-color = macchiato.text;

      # -- State Colors: Caps Lock --
      inside-caps-lock-color =
        macchiato.surface0; # Let it use inside-color (or set explicitly)
      ring-caps-lock-color =
        macchiato.lavender; # Let it use ring-color (or set explicitly)
      text-caps-lock-color = macchiato.yellow;

      # -- Layout Box (for -k option, if used) --
      layout-bg-color = macchiato.surface1;
      layout-border-color = macchiato.surface1;
      layout-text-color = macchiato.text;

      # -- Misc --
      show-failed-attempts = true; # Keep from your example and working command
      # disable-caps-lock-text = false;
      # ignore-empty-password = false;
      # indicator-caps-lock = false; # Corresponds to -l flag
      # show-keyboard-layout = false; # Corresponds to -k flag
    };
  };

}
