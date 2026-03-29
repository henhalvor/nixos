# HP Server — system configuration
# Source: systems/hp-server/configuration.nix + hosts/hp-server.nix
{self, inputs, ...}: {
  flake.nixosModules.hpServerConfig = {pkgs, ...}: {
    imports = [
      # Hardware
      self.nixosModules.hpServerHardware

      # Core
      self.nixosModules.base
      self.nixosModules.bootloader
      self.nixosModules.networking
      inputs.home-manager.nixosModules.home-manager

      # Theme (Phase 2) — terminal theming
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      # System services (Phase 3)
      self.nixosModules.pipewire
      self.nixosModules.bluetooth
      self.nixosModules.nvidiaGraphics
      self.nixosModules.laptopServer

      # Server features (Phase 4)
      self.nixosModules.serverBase
      self.nixosModules.sshServer
      self.nixosModules.tailscale
      self.nixosModules.serverMonitoring
      # self.nixosModules.cockpit  # Currently unused

      # Shell & tools (Phase 8)
      self.nixosModules.zsh
      self.nixosModules.tmux

      # TODO: Phase 9+ features

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "hp-server";
    system.stateVersion = "25.05";

    programs.dconf.enable = true;

    # Home-manager settings
    home-manager = {
      useGlobalPkgs = false;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = {
        inherit inputs self;
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };
    };
  };
}
