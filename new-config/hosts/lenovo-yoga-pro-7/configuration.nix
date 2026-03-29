# Lenovo Yoga Pro 7 — system configuration
# Source: systems/lenovo-yoga-pro-7/configuration.nix + hosts/lenovo-yoga-pro-7.nix
{self, inputs, ...}: {
  flake.nixosModules.lenovoYogaPro7Config = {pkgs, ...}: {
    imports = [
      # Hardware
      self.nixosModules.lenovoYogaPro7Hardware

      # Core
      self.nixosModules.base
      self.nixosModules.bootloader
      self.nixosModules.networking
      inputs.home-manager.nixosModules.home-manager

      # Theme (Phase 2)
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      # Features (Phase 3+)
      self.nixosModules.bluetooth
      # TODO: Add remaining feature imports as they are migrated
      # self.nixosModules.niri
      # self.nixosModules.pipewire
      # ...

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "lenovo-yoga-pro-7";
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

    # TODO: Migrate remaining laptop-specific config in later phases
  };
}
