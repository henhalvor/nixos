# Secrets — shell secret loader script
# Source: home/modules/settings/secrets/secrets.nix
# Template B2: HM-only
# Note: secrets.env is NOT tracked in git — user creates it manually
{ self, ... }: {
  flake.nixosModules.secrets = { ... }: {
    home-manager.sharedModules = [ self.homeModules.secrets ];
  };

  flake.homeModules.secrets = { ... }: {
    home.file.".local/secrets/load-secrets.sh" = {
      source = ./secrets/load-secrets.sh;
      executable = true;
    };
  };
}
