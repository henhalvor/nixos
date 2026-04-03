# Stylix — system-wide theming (NixOS + Home Manager colocated)
# Source: nixos/modules/theme/stylix.nix + home/modules/themes/stylix/default.nix + lib/theme.nix
#
# Usage: Host imports self.nixosModules.stylix (+ inputs.stylix.nixosModules.stylix)
#        User module sets: my.theme.scheme and my.theme.wallpaper
{self, ...}: {
  # NixOS module — configures Stylix system-wide
  flake.nixosModules.stylix = {
    pkgs,
    lib,
    config,
    ...
  }: let
    # Theme scheme mapping (absorbed from lib/theme.nix)
    schemes = {
      "catppuccin-mocha" = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      "catppuccin-macchiato" = "${pkgs.base16-schemes}/share/themes/catppuccin-macchiato.yaml";
      "gruvbox-dark-hard" = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
      "nord" = "${pkgs.base16-schemes}/share/themes/nord.yaml";
      "dracula" = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
      "rose-pine-moon" = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
    };
  in {
    options.my.theme = {
      scheme = lib.mkOption {
        type = lib.types.str;
        default = "gruvbox-dark-hard";
        description = "Base16 color scheme name";
      };
      wallpaper = lib.mkOption {
        type = lib.types.str;
        default = "atoms.png";
        description = "Wallpaper filename (relative to assets/wallpapers/)";
      };
    };

    config = {
      stylix = {
        enable = true;
        autoEnable = true;
        polarity = "dark";

        base16Scheme =
          schemes.${config.my.theme.scheme}
            or (throw "Unknown scheme: ${config.my.theme.scheme}. Valid: ${lib.concatStringsSep ", " (builtins.attrNames schemes)}");

        # Path to wallpaper — ../../ goes from modules/features/ up to repo root
        image = ../../assets/wallpapers/${config.my.theme.wallpaper};

        cursor = {
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Classic";
          size = 24;
        };

        fonts = {
          monospace = {
            package = pkgs.nerd-fonts.hack;
            name = "Hack Nerd Font";
          };
          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };
          serif = {
            package = pkgs.noto-fonts;
            name = "Noto Serif";
          };
          sizes = {
            applications = 11;
            desktop = 11;
            popups = 11;
            terminal = 10;
          };
        };
      };

      # Inject HM module for all users
      home-manager.sharedModules = [self.homeModules.stylix];
    };
  };

  # Home Manager module — HM-specific stylix target overrides
  flake.homeModules.stylix = {...}: {
    # Disable Stylix auto-theming for neovim (nvf handles its own theme)
    stylix.targets.neovim.enable = false;

    # Use qtct for Qt theming (avoids deprecated "gnome" platform warning)
    stylix.targets.qt.platform = "qtct";
    qt.platformTheme.name = "qtct";

    stylix.targets.kde = {
      enable = true;
    };
  };
}
