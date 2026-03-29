# SSH client — workstation connections from Android tablet
# Source: nix-on-droid/modules/ssh-client.nix
{ ... }: {
  flake.homeModules.sshClient = { pkgs, ... }: let
    portsToForward = [
      { bind.port = 3000;  host.address = "localhost"; host.port = 3000; }  # Next.js
      { bind.port = 5173;  host.address = "localhost"; host.port = 5173; }  # SvelteKit
      { bind.port = 54321; host.address = "localhost"; host.port = 54321; } # Supabase API
      { bind.port = 54320; host.address = "localhost"; host.port = 54320; } # Supabase DB shadow
      { bind.port = 54329; host.address = "localhost"; host.port = 54329; } # Supabase DB pooler
      { bind.port = 8083;  host.address = "localhost"; host.port = 8083; }  # Supabase Chrome inspector
      { bind.port = 54322; host.address = "localhost"; host.port = 54322; } # Supabase PostgreSQL
      { bind.port = 54323; host.address = "localhost"; host.port = 54323; } # Supabase Studio
      { bind.port = 54324; host.address = "localhost"; host.port = 54324; } # Supabase Inbucket
      { bind.port = 54327; host.address = "localhost"; host.port = 54327; } # Supabase analytics
      { bind.port = 38215; host.address = "localhost"; host.port = 38215; } # AWS SSO login
      { bind.port = 5037;  host.address = "localhost"; host.port = 5037; }  # ADB Server
      { bind.port = 19000; host.address = "localhost"; host.port = 19000; } # Expo Dev Server
      { bind.port = 19001; host.address = "localhost"; host.port = 19001; } # Expo Dev Client
      { bind.port = 19002; host.address = "localhost"; host.port = 19002; } # Expo Dev Tools
      { bind.port = 8081;  host.address = "localhost"; host.port = 8081; }  # Metro Bundler
      { bind.port = 19003; host.address = "localhost"; host.port = 19003; } # Expo Debugger
    ];

    sshCommonOpts = {
      Compression = "yes";
      IPQoS = "lowdelay throughput";
      TCPKeepAlive = "yes";
      Ciphers = "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr";
      KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
      MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
    };

    socksProxy = [{ port = 8888; address = "localhost"; }];
  in {
    home.packages = [ pkgs.mosh ];

    programs.ssh = {
      enable = true;
      matchBlocks = {
        "workstation-ssh" = {
          hostname = "10.0.0.5";
          user = "henhal";
          extraOptions = sshCommonOpts // {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          compression = true;
          serverAliveInterval = 15;
          serverAliveCountMax = 6;
          dynamicForwards = socksProxy;
          localForwards = portsToForward;
        };

        "workstation-mosh" = {
          hostname = "10.0.0.5";
          user = "henhal";
          extraOptions = sshCommonOpts // {
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          compression = true;
          serverAliveInterval = 15;
          serverAliveCountMax = 6;
          dynamicForwards = socksProxy;
          localForwards = portsToForward;
        };

        "workstation-ts-ssh" = {
          hostname = "100.73.24.108";
          user = "henhal";
          extraOptions = sshCommonOpts // {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            ControlMaster = "no";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "30s";
          };
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
          dynamicForwards = socksProxy;
          localForwards = portsToForward;
        };

        "workstation-ts-mosh" = {
          hostname = "100.73.24.108";
          user = "henhal";
          extraOptions = sshCommonOpts // {
            ControlMaster = "no";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "30s";
          };
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
          dynamicForwards = socksProxy;
          localForwards = portsToForward;
        };
      };
    };

    programs.zsh.shellAliases = {
      ws = "ssh workstation-ssh";
      wst = "ssh workstation-ts-ssh";
      wsm = "mosh workstation-mosh";
      wstm = "mosh workstation-ts-mosh";
    };
  };
}
