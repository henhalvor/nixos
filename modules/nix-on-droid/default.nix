# Nix-on-Droid — Galaxy Tab S10 Ultra configuration
# Source: nix-on-droid/default.nix + users/henhal-android/home.nix
# Defines flake.nixOnDroidConfigurations.default
{ self, inputs, ... }: let
  system = "aarch64-linux";

  # Terminal colors (gruvbox-dark-hard) — inlined from nix-on-droid/theme.nix
  terminalColors = {
    background = "#1d2021"; foreground = "#ebdbb2"; cursor = "#ebdbb2";
    color0 = "#1d2021"; color8 = "#928374";   # Black
    color1 = "#cc241d"; color9 = "#fb4934";   # Red
    color2 = "#98971a"; color10 = "#b8bb26";  # Green
    color3 = "#d79921"; color11 = "#fabd2f";  # Yellow
    color4 = "#458588"; color12 = "#83a598";  # Blue
    color5 = "#b16286"; color13 = "#d3869b";  # Magenta
    color6 = "#689d6a"; color14 = "#8ec07c";  # Cyan
    color7 = "#a89984"; color15 = "#ebdbb2";  # White
  };
in {
  flake.nixOnDroidConfigurations.default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ inputs.nix-on-droid.overlays.default ];
    };

    home-manager-path = inputs.home-manager.outPath;

    extraSpecialArgs = {
      inherit inputs self;
    };

    modules = [
      # System configuration
      ({ config, pkgs, lib, ... }: {
        system.stateVersion = "24.05";
        time.timeZone = "Europe/Oslo";

        nix.extraOptions = ''
          experimental-features = nix-command flakes
        '';

        environment.packages = with pkgs; [ vim git openssh wget curl ];
        environment.etcBackupExtension = ".bak";
        environment.sessionVariables.HOSTNAME = "galaxy-tab-s10-ultra";

        android-integration = {
          termux-open-url.enable = true;
          xdg-open.enable = true;
          termux-reload-settings.enable = true;
        };

        user.shell = "${pkgs.zsh}/bin/zsh";

        terminal.font = "${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack/HackNerdFontMono-Regular.ttf";
        terminal.colors = terminalColors;

        home-manager = {
          backupFileExtension = "hm-bak";
          useGlobalPkgs = true;

          extraSpecialArgs = {
            inherit inputs self;
            pkgs-unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            pkgs24-11 = import inputs.nixpkgs-24-11 {
              inherit system;
              config.allowUnfree = true;
            };
          };

          config = { config, pkgs, lib, ... }: {
            home.username = "nix-on-droid";
            home.homeDirectory = "/data/data/com.termux.nix/files/home";
            home.stateVersion = "24.05";
            programs.home-manager.enable = true;
            fonts.fontconfig.enable = true;

            home.packages = [ pkgs.vim ];

            # Shared homeModules from dendritic features
            imports = [
              self.homeModules.zsh
              self.homeModules.tmux
              self.homeModules.yazi
              self.homeModules.nvf
              self.homeModules.git
              self.homeModules.nerdFonts
              self.homeModules.devTools
              self.homeModules.sessionVariables
              self.homeModules.direnv
              self.homeModules.utils

              # Android-specific homeModules
              self.homeModules.basicCliTools
              self.homeModules.sshClient
            ];

            # Git config (HM-level options, no osConfig needed)
            my.git = {
              userName = "Henrik";
              userEmail = "henhalvor@gmail.com";
            };

            # Android hostname override
            home.sessionVariables.HOSTNAME = "galaxy-tab-s10-ultra";

            # Termux config — must be copied, not symlinked
            home.activation.termuxConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              $DRY_RUN_CMD mkdir -p ~/.termux/
              $DRY_RUN_CMD cp -f ${./termux.properties} ~/.termux/termux.properties
            '';

            # Copy Nerd Fonts for terminal glyph rendering
            home.activation.copyNerdFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              $VERBOSE_ECHO "Copying Nerd Fonts to ~/.termux/fonts/"
              $DRY_RUN_CMD mkdir -p ~/.termux/fonts/
              $DRY_RUN_CMD cp -f ${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack/*.ttf ~/.termux/fonts/
            '';

            # Hostname override for powerlevel10k prompt
            home.file.".zshenv".text = ''
              export HOSTNAME="galaxy-tab-s10-ultra"
              function hostname() { echo "galaxy-tab-s10-ultra"; }
            '';

            # Android-specific p10k config (hardcoded hostname)
            home.file.".p10k.zsh".source = lib.mkForce ./.p10k-android.zsh;
          };
        };
      })
    ];
  };
}
