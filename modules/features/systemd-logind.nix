# systemd-logind — lid switch handling + polkit
# Source: nixos/modules/systemd-loginhd.nix
# Suitable for laptops with desktop sessions.
{...}: {
  flake.nixosModules.systemdLogind = {...}: {
    services.logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "lock";

      settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "lock";
        KillUserProcesses = false;
        InhibitDelayMaxSec = "5";
      };
    };

    security.pam.services.login.enableGnomeKeyring = true;
    security.polkit.enable = true;
  };
}
