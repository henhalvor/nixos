{ config, pkgs, ... }:

{
  # Create the secrets directory and scripts
  home.file = {
    ".local/secrets/load-secrets.sh" = {
      source = ./secrets/load-secrets.sh; # This is relative to home.nix location
      executable = true;
    };
  };
}
