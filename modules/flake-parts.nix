{inputs, ...}: {
  options.flake = inputs.flake-parts.lib.mkSubmoduleOptions {
    homeModules = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.attrs;
      default = {};
      description = "Home-manager modules, importable standalone or injected via sharedModules";
    };
  };

  config = {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
