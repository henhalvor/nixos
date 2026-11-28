# Stylix — system-wide theming (NixOS + Home Manager colocated)
# Source: nixos/modules/theme/stylix.nix + home/modules/themes/stylix/default.nix + lib/theme.nix
#
# Usage: Host imports self.nixosModules.stylix (+ inputs.stylix.nixosModules.stylix)
#        User module sets: my.theme.scheme and my.theme.wallpaper
#
# my.theme.colorSource picks who colours desktop apps:
#   "stylix"   — Stylix themes everything from my.theme.scheme (default).
#   "noctalia" — Noctalia v5 generates GTK, Qt, KDE (kdeglobals) and kitty
#                colours at runtime from its palette, through the built-in
#                templates enabled in its TOML ([theme.templates]). Stylix
#                keeps fonts, cursor and the colours of things Noctalia has no
#                template for: SDDM, rofi, console/boot, zathura, mpv, Firefox.
#                (Hosts on the noctaliaGreeter module get the login screen
#                from Noctalia's greeter sync instead of SDDM.)
#                Terminal tools (fzf, tmux, yazi) drop their Stylix colours
#                and follow kitty's ANSI palette, which Noctalia sets.
#
# TODO(noctalia): theme the apps still on Stylix colours from Noctalia too:
#   - Firefox: `noctalia firefox-theme` (pywalfox), then drop the Stylix target.
#   - rofi, zathura, mpv: user templates ([theme.templates] in the Noctalia
#     TOML) that write a colour file each app includes, plus a reload hook.
#   - Console/boot (and SDDM on hosts still using it): built at Nix time, so
#     they can't follow a runtime palette; set my.theme.scheme close to
#     Noctalia's palette instead.
# Neovim is never themed from outside; its config picks its own colorscheme.
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
      colorSource = lib.mkOption {
        type = lib.types.enum [
          "stylix"
          "noctalia"
        ];
        default = "stylix";
        description = "What colours desktop apps: Stylix's scheme, or Noctalia's palette through its app templates";
      };
    };

    config = {
      # Noctalia supplies the qt6ct palette; Kvantum would paint over it.
      # Stylix's Qt target stays on so the platform theme env is still set.
      qt.style = lib.mkIf (config.my.theme.colorSource == "noctalia") (lib.mkForce null);

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
  flake.homeModules.stylix = {
    config,
    lib,
    pkgs,
    osConfig,
    ...
  }: let
    noctaliaColors = osConfig.my.theme.colorSource == "noctalia";
    inherit (config.stylix) fonts;

    # Same layout as Stylix's qtct config, but Fusion with Noctalia's palette.
    qtctSettings = ctName: {
      Appearance = {
        custom_palette = true;
        color_scheme_path = "${config.xdg.configHome}/${ctName}/colors/noctalia.conf";
        standard_dialogs = "default";
        style = "Fusion";
      };
      Fonts = {
        fixed = ''"${fonts.monospace.name},${toString fonts.sizes.applications}"'';
        general = ''"${fonts.sansSerif.name},${toString fonts.sizes.applications}"'';
      };
    };

    # Noctalia's GTK hook only appends this import when it is missing, so
    # declaring it keeps gtk.css under Nix and the hook a no-op.
    gtkCss = ''@import url("noctalia.css");'';
  in
    lib.mkMerge [
      {
        # Disable Stylix auto-theming for neovim (the wrapped nvim config handles its own theme)
        stylix.targets.neovim.enable = false;

        # Use qtct for Qt theming (avoids deprecated "gnome" platform warning)
        stylix.targets.qt.platform = "qtct";
        qt.platformTheme.name = "qtct";

        # Writes kdeglobals for KDE/Kirigami apps. Without Plasma it only
        # gets fonts, not colours; Noctalia's kcolorscheme template fixes that.
        stylix.targets.kde.enable = !noctaliaColors;
      }

      (lib.mkIf noctaliaColors {
        stylix.targets = {
          # Keep GTK fonts from Stylix, take colours from Noctalia.
          gtk.colors.enable = false;
          qt.enable = false;
          kitty.enable = false; # fonts are set in kitty.nix
          # These fall back to the terminal's ANSI palette, which Noctalia sets.
          fzf.enable = false;
          tmux.enable = false;
          yazi.enable = false;
        };

        # Noctalia's GTK hook switches to adw-gtk3(-dark) if it is installed.
        gtk.theme = {
          package = pkgs.adw-gtk3;
          name = "adw-gtk3-dark";
        };
        xdg.configFile."gtk-3.0/gtk.css".text = gtkCss;
        # After Home Manager's adw-gtk3 import, so Noctalia's colours win.
        xdg.configFile."gtk-4.0/gtk.css".text = lib.mkAfter gtkCss;

        qt = {
          enable = true;
          qt5ctSettings = qtctSettings "qt5ct";
          qt6ctSettings = qtctSettings "qt6ct";
        };

        # Noctalia's kitty hook only appends this when missing; it then
        # reloads running kitty windows.
        programs.kitty.extraConfig = "include themes/noctalia.conf";
      })
    ];
}
