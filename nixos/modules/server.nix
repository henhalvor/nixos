
{ config, pkgs, userSettings, ... }: {
  # Enable SSH server
  services.openssh = {
    enable = true;
    # Forbid root login through SSH.
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubKeyAuthentication = true;
    };
  };

  # SSH Key Config
  users.users.${userSettings.username} = {
    # Add your SSH keys here
    # Yoga Pro 7 Ubuntu key (sway)
    # Yoga Pro 7 Nixos key (hyprland)
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjlpTB8/FqToM9BkFuhL7w627YGto8ZYwAdXVR5AT+T henhal@henhal-Yoga-Pro-7-14APH8-Ubuntu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOf2s4mEBjowY2N6DSav5d5s9dTQzLQEpB3oU2qLvvrX henhalvor@gmail.com"
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

  # Enable and configure firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH port
    # Add any other ports you need
  };

  # Enable fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 5;  # Number of attempts before ban
    bantime = "24h";
  };

  # Keep the system awake
  powerManagement = {
    enable = true;
    powertop.enable = false;  # Disable powertop to prevent auto power saving
    cpuFreqGovernor = "performance";  # Use performance governor instead of powersave
  };

  # Network settings for better server operation
  networking = {
    # useDHCP = true;  # Or set a static IP if needed
    # Optionally configure static IP:
    # interfaces.<interface>.ipv4.addresses = [{
    #   address = "192.168.1.100";
    #   prefixLength = 24;
    # }];
  };

  # System maintenance
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 4 * * * root nix-collect-garbage -d" # Clean old generations at 4 AM
    ];
  };
}
