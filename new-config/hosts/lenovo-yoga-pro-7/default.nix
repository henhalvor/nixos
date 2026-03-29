# Lenovo Yoga Pro 7 — entry point
{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.lenovo-yoga-pro-7 = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs self;
      pkgs-unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    };
    modules = [
      self.nixosModules.lenovoYogaPro7Config
    ];
  };
}
