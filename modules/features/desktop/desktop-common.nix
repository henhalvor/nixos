# Desktop Common — shared desktop environment foundation
# Source: nixos/modules/desktop/common.nix + home/modules/desktop/common.nix
# Template C: Colocated NixOS + HM
#
# HM options defined: my.desktop.terminal, my.desktop.browser
# Set values in user module's home-manager block.
{self, ...}: {
  # NixOS module — system-level desktop prerequisites
  flake.nixosModules.desktopCommon = {pkgs, ...}: {
    services.xserver.xkb = {
      layout = "no";
      variant = "";
    };

    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };

    programs.dconf.enable = true;

    fonts.packages = with pkgs; [noto-fonts noto-fonts-color-emoji];

    # Common Wayland session variables (compositor sets XDG_CURRENT_DESKTOP)
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_SESSION_TYPE = "wayland";
      SDL_VIDEODRIVER = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      GDK_BACKEND = "wayland";
    };

    # Inject HM module for all users
    home-manager.sharedModules = [self.homeModules.desktopCommon];
  };

  # Home Manager module — user-level desktop tools + session variables
  flake.homeModules.desktopCommon = {
    pkgs,
    lib,
    config,
    ...
  }: {
    options.my.desktop = {
      terminal = lib.mkOption {
        type = lib.types.str;
        default = "kitty";
        description = "Default terminal emulator command";
      };
      browser = lib.mkOption {
        type = lib.types.str;
        default = "firefox";
        description = "Default browser command";
      };
    };

    config = {
      home.packages = with pkgs; [
        playerctl
        brightnessctl
        pamixer
      ];

      xdg.enable = true;

      home.sessionVariables = {
        TERMINAL = config.my.desktop.terminal;
        BROWSER = config.my.desktop.browser;
      };
    };
  };
}
