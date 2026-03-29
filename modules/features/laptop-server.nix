# Laptop Server — lid-close ignore, performance governor
# Source: systems/hp-server/laptop-server.nix
# For laptops repurposed as always-on servers.
{...}: {
  flake.nixosModules.laptopServer = {...}: {
    services.logind = {
      lidSwitch = "ignore";
      lidSwitchExternalPower = "ignore";
      settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
        IdleAction = "ignore";
      };
    };

    powerManagement = {
      enable = true;
      powertop.enable = false;
      cpuFreqGovernor = "performance";
    };
  };
}
