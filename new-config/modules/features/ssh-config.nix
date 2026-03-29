# SSH Config — remote machine connections with port forwarding
# Source: home/modules/settings/ssh.nix
# Template B2: HM-only (hardcoded per-user SSH hosts)
{ self, ... }: {
  flake.nixosModules.sshConfig = { ... }: {
    home-manager.sharedModules = [ self.homeModules.sshConfig ];
  };

  flake.homeModules.sshConfig = { ... }: let
    portsToForward = [
      { bind.port = 3000; host.address = "localhost"; host.port = 3000; }   # Next.js
      { bind.port = 5173; host.address = "localhost"; host.port = 5173; }   # Sveltekit
      { bind.port = 54321; host.address = "localhost"; host.port = 54321; } # Supabase API
      { bind.port = 54320; host.address = "localhost"; host.port = 54320; } # Supabase DB shadow
      { bind.port = 54329; host.address = "localhost"; host.port = 54329; } # Supabase DB pooler
      { bind.port = 8083; host.address = "localhost"; host.port = 8083; }   # Supabase edge fn inspector
      { bind.port = 54322; host.address = "localhost"; host.port = 54322; } # Supabase PostgreSQL
      { bind.port = 54323; host.address = "localhost"; host.port = 54323; } # Supabase Studio
      { bind.port = 54324; host.address = "localhost"; host.port = 54324; } # Supabase Inbucket
      { bind.port = 54327; host.address = "localhost"; host.port = 54327; } # Supabase analytics
      { bind.port = 38215; host.address = "localhost"; host.port = 38215; } # AWS SSO login
      { bind.port = 5037; host.address = "localhost"; host.port = 5037; }   # ADB Server
      { bind.port = 19000; host.address = "localhost"; host.port = 19000; } # Expo Dev Server
      { bind.port = 19001; host.address = "localhost"; host.port = 19001; } # Expo Dev Client
      { bind.port = 19002; host.address = "localhost"; host.port = 19002; } # Expo Dev Tools
      { bind.port = 8081; host.address = "localhost"; host.port = 8081; }   # Metro Bundler
      { bind.port = 19003; host.address = "localhost"; host.port = 19003; } # Expo Debugger
    ];
  in {
    programs.ssh = {
      enable = true;
      matchBlocks = {
        "server" = {
          hostname = "10.0.0.2";
          user = "henhal";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            ExitOnForwardFailure = "yes";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
            IPQoS = "lowdelay throughput";
            TCPKeepAlive = "yes";
            Ciphers = "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr";
            KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
            MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
          };
          compression = true;
          serverAliveInterval = 15;
          serverAliveCountMax = 6;
          dynamicForwards = [{ port = 8888; address = "localhost"; }];
          localForwards = portsToForward;
        };

        "workstation" = {
          hostname = "10.0.0.5";
          user = "henhal";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          localForwards = portsToForward;
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        "workstation-tailscale" = {
          hostname = "workstation.tail37a5eb.ts.net";
          user = "henhal";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          localForwards = portsToForward;
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        "laptop" = {
          hostname = "10.0.0.25";
          user = "henhal";
          identityFile = "~/.ssh/id_workstation";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };
      };
    };
  };
}
