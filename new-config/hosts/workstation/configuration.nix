# Workstation — system configuration
# Source: systems/workstation/configuration.nix + hosts/workstation.nix
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.workstationConfig = {pkgs, ...}: {
    imports = [
      # Hardware
      self.nixosModules.workstationHardware

      # Core
      self.nixosModules.base
      self.nixosModules.secureBoot
      self.nixosModules.networking
      inputs.home-manager.nixosModules.home-manager

      # Theme (Phase 2)
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      # Features (Phase 3+)
      self.nixosModules.bluetooth
      # TODO: Add remaining feature imports as they are migrated
      # self.nixosModules.pipewire
      # self.nixosModules.hyprland
      # ...

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "workstation";
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

    # TODO: Migrate remaining workstation-specific config in later phases
  };
}
