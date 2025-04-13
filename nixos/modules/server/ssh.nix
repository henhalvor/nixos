{ config, pkgs, userSettings, ... }: {

  # Fix for allowing openssh.authorizedKeys to work (does not work without this)
  # fileSystems."/" = { options = [ "mode=755" ]; };

  # Enable SSH server
  services.openssh = {
    enable = true;
    # Disable password authentication
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # OpenFireWall = true # Bad config option error caused by this
      PubKeyAuthentication = true;
      UsePAM = false; # Disable PAM to ensure public key authentication is used
      LogLevel = "VERBOSE";

      # Performance tweaks
      # UseDNS = "no";  # Speeds up connections by skipping reverse DNS lookups
      # Optimize ciphers and algorithms
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes128-ctr"
        "aes192-ctr"
        "aes256-ctr"
      ];
      KexAlgorithms = [
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group-exchange-sha256"
      ];
      # MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";

    };
    extraConfig = ''
      IPQoS lowdelay throughput
      TCPKeepAlive yes
      ClientAliveInterval 60
      ClientAliveCountMax 3
    '';
  };

  # SSH Key Config
  users.users.${userSettings.username} = {
    # Add your SSH keys here
    # Yoga Pro 7 Ubuntu key (sway)
    # Yoga Pro 7 Nixos key (hyprland)
    # Desktop ssh key TODO: For some reason this does not write to the proper ssh file (has to be added manually)
    openssh.authorizedKeys.keys = [
"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMt1DD3rn6m5uBKGfgOwAerxKEpOJe54Aood9abQWAvx u0_a514@localhost"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjlpTB8/FqToM9BkFuhL7w627YGto8ZYwAdXVR5AT+T henhal@henhal-Yoga-Pro-7-14APH8-Ubuntu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAyX9JZNVAi8TchOBM/bsbYHk6b4adcvqPS+yhCo0r/X henhalvor@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN05rLpXKWvbcdus29yl6d1uC18LKPqe9HLpiXUB9mxp henhalvor@gmail.com"
    ];
  };

  # Add essential server packages
  environment.systemPackages = with pkgs;
    [
      fail2ban # Protection against brute force attacks
    ];

  # Enable fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 100; # Number of attempts before ban
    bantime = "24h";
  };

}
