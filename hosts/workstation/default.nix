# Workstation — entry point
# Defines flake.nixosConfigurations.workstation
{self, inputs, ...}: {
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs self;
      pkgs-unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      pkgs24-11 = import inputs.nixpkgs-24-11 {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    };
    modules = [
      self.nixosModules.workstationConfig
    ];
  };
}
