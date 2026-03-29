

{ config, pkgs, userSettings, ... }: {
  # Add essential server packages
  environment.systemPackages = with pkgs; [ htop iftop iotop ];

  # System maintenance
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 4 * * * root nix-collect-garbage -d" # Clean old generations at 4 AM
    ];
  };
}
