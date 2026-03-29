# SSH Server — openssh + mosh + fail2ban
# Source: nixos/modules/server/ssh.nix
# Authorized keys should be set per-user in the user module.
{...}: {
  flake.nixosModules.sshServer = {pkgs, ...}: {
    programs.mosh.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        PubKeyAuthentication = true;
        UsePAM = false;
        LogLevel = "VERBOSE";
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
      };
      extraConfig = ''
        IPQoS lowdelay throughput
        TCPKeepAlive yes
        ClientAliveInterval 60
        ClientAliveCountMax 3
      '';
    };

    environment.systemPackages = with pkgs; [fail2ban];

    services.fail2ban = {
      enable = true;
      maxretry = 100;
      bantime = "24h";
    };
  };
}
