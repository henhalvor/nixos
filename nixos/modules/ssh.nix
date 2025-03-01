
{ config, pkgs, userSettings, systemSettings, ... }: {
  # Enable SSH server
  services.openssh = {
    enable = true;
    # Disable password authentication
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # OpenFireWall = true # Bad config option error caused by this
      PubKeyAuthentication = true;
      UsePAM = false;  # Disable PAM to ensure public key authentication is used
      LogLevel = "VERBOSE";
    };
  };



  # SSH Key Config
  users.users.${userSettings.username} = {
    # Add your SSH keys here
    # Yoga Pro 7 Ubuntu key (sway)
    # Yoga Pro 7 Nixos key (hyprland)
    # Desktop ssh key
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjlpTB8/FqToM9BkFuhL7w627YGto8ZYwAdXVR5AT+T henhal@henhal-Yoga-Pro-7-14APH8-Ubuntu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAyX9JZNVAi8TchOBM/bsbYHk6b4adcvqPS+yhCo0r/X henhalvor@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN05rLpXKWvbcdus29yl6d1uC18LKPqe9HLpiXUB9mxp henhalvor@gmail.com"
    ];
  };



  # Disable sleep/hibernation when lid is closed
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
    extraConfig = ''
      HandleLidSwitch=ignore
      HandleLidSwitchExternalPower=ignore
      HandleLidSwitchDocked=ignore
      IdleAction=ignore
    '';
  };

  # Add essential server packages
  environment.systemPackages = with pkgs; [
    htop
    iftop
    iotop
    #ufw      # Firewall
    fail2ban # Protection against brute force attacks
  ];

  # Enable fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 100;  # Number of attempts before ban
    bantime = "24h";
  };  

  # Keep the system awake
  powerManagement = {
    enable = true;
    powertop.enable = false;  # Disable powertop to prevent auto power saving
    cpuFreqGovernor = "performance";  # Use performance governor instead of powersave
  };

  
  # System maintenance
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 4 * * * root nix-collect-garbage -d" # Clean old generations at 4 AM
    ];
  };
}
