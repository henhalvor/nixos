{ nixpkgs, home-manager, stylix, lanzaboote, zen-browser, vscode-server, nvf, nvim-nix, nixpkgs-unstable, nixpkgs-24-11, ... }@inputs:
{ hostConfig, userSettings, extraModules ? [] }:

let
  system = "x86_64-linux";
  desktopLib = import ./desktop.nix { inherit (nixpkgs) lib; };
  resolvedDesktop = desktopLib.resolveDesktop (hostConfig.desktop or { session = "none"; });

  unstablePkgs = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };

  pkgs24-11 = import nixpkgs-24-11 {
    inherit system;
    config.allowUnfree = true;
  };

  pkgsForNixOS = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [];
  };
in
nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit userSettings hostConfig inputs;
    desktop = resolvedDesktop;  # Pre-resolved, ready to use
    unstable = unstablePkgs;
    pkgs24-11 = pkgs24-11;
    inherit zen-browser;
    hostname = hostConfig.hostname;
    # Legacy compatibility - will be removed in later phases
    windowManager = resolvedDesktop.session;
    systemName = hostConfig.hostname;
  };

  modules = [
    stylix.nixosModules.stylix
    lanzaboote.nixosModules.lanzaboote
    ../systems/${hostConfig.hostname}/configuration.nix
    ../nixos/modules/theme/stylix.nix  # Shared theme configuration
    {nixpkgs.config.allowUnfree = true;}

    # Base system config
    ({ config, pkgs, ... }: {
      networking.hostName = hostConfig.hostname;
      time.timeZone = "Europe/Oslo";
      i18n.defaultLocale = "en_US.UTF-8";
      system.stateVersion = userSettings.stateVersion;

      users.users.${userSettings.username} = {
        isNormalUser = true;
        description = userSettings.name;
        initialPassword = "password";
        extraGroups = [
          "networkmanager"
          "wheel"
          "i2c"
          "docker"
          "video"
          "libvirtd"
        ];
        shell = pkgsForNixOS.zsh;
        home = userSettings.homeDirectory;
        packages = with pkgsForNixOS; [ethtool];
      };
    })

    # Home Manager integration
    home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = false;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {
          inherit system userSettings hostConfig inputs;
          desktop = resolvedDesktop;
          unstable = unstablePkgs;
          pkgs24-11 = pkgs24-11;
          inherit zen-browser nvf nvim-nix stylix;
          # Legacy compatibility
          hostname = hostConfig.hostname;
          windowManager = resolvedDesktop.session;
          systemName = hostConfig.hostname;
        };
        users.${userSettings.username} = import ../users/${userSettings.username}/home.nix;
      };
    }
  ] ++ extraModules;
}
