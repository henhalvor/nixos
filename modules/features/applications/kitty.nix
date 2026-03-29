# Kitty — GPU-accelerated terminal emulator
# Source: home/modules/applications/kitty.nix
# Template D: HM feature + standalone package
{ self, ... }: {
  flake.nixosModules.kitty = { ... }: {
    home-manager.sharedModules = [ self.homeModules.kitty ];
  };

  flake.homeModules.kitty = { config, lib, pkgs, ... }: {
    programs.kitty = {
      enable = true;

      font = {
        name = config.stylix.fonts.monospace.name;
        size = config.stylix.fonts.sizes.terminal;
      };

      settings = {
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";

        background_opacity = lib.mkForce "0.70";
        dynamic_background_opacity = lib.mkForce "yes";
        background_blur = lib.mkForce "0";

        window_padding_width = 5;
        tab_bar_style = "hidden";
        confirm_os_window_close = 0;

        enable_audio_bell = "no";
        allow_remote_control = "yes";
      };
    };
  };

  # Standalone: nix run .#kitty
  perSystem = { pkgs, ... }: {
    packages.kitty = pkgs.kitty;
  };
}
