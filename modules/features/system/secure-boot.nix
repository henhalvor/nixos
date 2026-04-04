# Secure Boot via Lanzaboote — overrides systemd-boot from bootloader.nix
# Source: systems/workstation/secure-boot.nix
# Usage: Import ALONGSIDE bootloader (this overrides systemd-boot with lanzaboote)
# Requires: lanzaboote flake input
{inputs, ...}: {
  flake.nixosModules.secureBoot = {
    lib,
    pkgs,
    ...
  }: {
    imports = [inputs.lanzaboote.nixosModules.lanzaboote];

    environment.systemPackages = [pkgs.sbctl];

    # Config here overrides the settings in bootloader.nix
    # https://github.com/nix-community/lanzaboote

    # Lanzaboote currently replaces the systemd-boot module.
    # This setting is usually set to true in configuration.nix
    # generated at installation time. So we force it to false
    # for now.
    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };
}
