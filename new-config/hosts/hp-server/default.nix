# HP Server — entry point
{self, inputs, ...}: {
  flake.nixosConfigurations.hp-server = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs self;
      pkgs-unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    };
    modules = [
      self.nixosModules.hpServerConfig
    ];
  };
}
