# Laptop Power — vendor-neutral battery policy for Intel laptops
# Profiles come from power-profiles-daemon (enabled by noctalia unless tuned
# is on), which drives the firmware platform profile, e.g. samsung-galaxybook.
{...}: {
  flake.nixosModules.laptopPower = {pkgs, lib, ...}: {
    environment.systemPackages = with pkgs; [powertop acpi btop htop];

    services.spice-vdagentd.enable = lib.mkDefault false;
    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    powerManagement.enable = true;

    services.power-profiles-daemon.enable = true;
    services.thermald.enable = true;
    services.upower.enable = true;
  };
}
