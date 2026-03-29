# Server Base — essential monitoring tools + maintenance
# Source: nixos/modules/server/default.nix
{...}: {
  flake.nixosModules.serverBase = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [htop iftop iotop];

    services.cron = {
      enable = true;
      systemCronJobs = [
        "0 4 * * * root nix-collect-garbage -d"
      ];
    };
  };
}
