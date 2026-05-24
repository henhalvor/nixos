# Bluetooth support
{...}: {
  flake.nixosModules.bluetooth = {pkgs, ...}: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          ControllerMode = "dual";
          FastConnectable = true;
          JustWorksRepairing = "always";
        };
      };
    };
    services.blueman.enable = true;

    environment.systemPackages = with pkgs; [
      bluetui
    ];
  };
}
