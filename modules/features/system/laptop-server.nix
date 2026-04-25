# Laptop Server — lid-close ignore, performance governor
# Source: systems/hp-server/laptop-server.nix
# For laptops repurposed as always-on servers.
{lib, ...}: {
  flake.nixosModules.laptopServer = {...}: {
    services.logind = {
      lidSwitch = lib.mkForce "ignore";
      lidSwitchExternalPower = lib.mkForce "ignore";
      settings.Login = {
        HandleLidSwitch = lib.mkForce "ignore";
        HandleLidSwitchExternalPower = lib.mkForce "ignore";
        HandleLidSwitchDocked = lib.mkForce "ignore";
        IdleAction = lib.mkForce "ignore";
      };
    };

    powerManagement = {
      enable = lib.mkForce true;
      powertop.enable = lib.mkForce false;
      cpuFreqGovernor = lib.mkForce "performance";
    };
  };
}
