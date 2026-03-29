# Printer & Scanner support
# Source: nixos/modules/printer.nix
# Auto-adds all normal users to lp/scanner groups.
{...}: {
  flake.nixosModules.printer = {
    config,
    lib,
    ...
  }: let
    normalUsers = builtins.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  in {
    users.groups.lp.members = normalUsers;
    users.groups.scanner.members = normalUsers;

    hardware.sane.enable = true;

    services = {
      printing.enable = true;
      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
      system-config-printer.enable = true;
    };
  };
}
