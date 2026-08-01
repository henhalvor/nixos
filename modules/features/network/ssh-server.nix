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
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        PubKeyAuthentication = true;
        UsePAM = true;
        LogLevel = "VERBOSE";
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
      maxretry = 5;
      bantime = "24h";
    };
  };
}
