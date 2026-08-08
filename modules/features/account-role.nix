# Account role — shared Home Manager security boundary.
{self, ...}: {
  flake.homeModules.accountRole = {lib, ...}: {
    options.my.account.role = lib.mkOption {
      type = lib.types.enum ["personal" "restricted-code-shell"];
      default = "personal";
      description = "Security role used to gate user-specific Home Manager behavior.";
    };
  };

  flake.nixosModules.accountRole = {...}: {
    home-manager.sharedModules = [self.homeModules.accountRole];
  };
}
