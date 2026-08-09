# Docker container runtime.
{...}: {
  flake.nixosModules.docker = {config, lib, ...}: let
    normalUsers = builtins.attrNames (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);
  in {
    virtualisation.docker.enable = true;
    users.groups.docker.members = normalUsers;
  };
}
