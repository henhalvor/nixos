# Android development — ADB + emulator support
# Source: nixos/modules/android.nix
# Auto-adds all normal users to adbusers/kvm groups.
{...}: {
  flake.nixosModules.android = {
    config,
    lib,
    ...
  }: let
    normalUsers = builtins.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  in {
    programs.adb.enable = true;

    users.groups.adbusers.members = normalUsers;
    users.groups.kvm.members = normalUsers;
  };
}
