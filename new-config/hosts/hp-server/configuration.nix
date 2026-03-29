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

      # Theme (Phase 2) — server uses stylix too for terminal theming
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      # Features (Phase 3+)
      self.nixosModules.bluetooth
      # TODO: Add remaining feature imports as they are migrated
      # self.nixosModules.sshServer
      # self.nixosModules.tailscale
      # self.nixosModules.serverMonitoring
      # ...

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "hp-server";
    system.stateVersion = "25.05";

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

    # TODO: Migrate remaining server-specific config in later phases
  };
}
