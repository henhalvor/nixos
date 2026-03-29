{
  config,
  pkgs,
  ...
}: let
  portsToForward = [
    {
      # Next.js
      bind.port = 3000;
      host.address = "localhost";
      host.port = 3000;
    }
    {
      # Sveltekit
      bind.port = 5173;
      host.address = "localhost";
      host.port = 5173;
    }
    {
      # Supabase API, GraphQL, and Storage
      bind.port = 54321;
      host.address = "localhost";
      host.port = 54321;
    }
    {
      # Supabase DB shadow port
      bind.port = 54320;
      host.address = "localhost";
      host.port = 54320;
    }
    {
      # Supabase DB pooler
      bind.port = 54329;
      host.address = "localhost";
      host.port = 54329;
    }
    {
      # Supabase Chrome inspector for edge functions
      bind.port = 8083;
      host.address = "localhost";
      host.port = 8083;
    }
    {
      # Supabase PostgreSQL
      bind.port = 54322;
      host.address = "localhost";
      host.port = 54322;
    }
    {
      # Supabase Studio
      bind.port = 54323;
      host.address = "localhost";
      host.port = 54323;
    }
    {
      # Supabase Inbucket (email testing)
      bind.port = 54324;
      host.address = "localhost";
      host.port = 54324;
    }
    {
      # Supabase analytics
      bind.port = 54327;
      host.address = "localhost";
      host.port = 54327;
    }
    {
      # AWS SSO login
      bind.port = 38215;
      host.address = "localhost";
      host.port = 38215;
    }
    #
    # React Native
    #
    # ADB Server
    {
      bind.port = 5037;
      host.address = "localhost";
      host.port = 5037;
    }
    # Expo Development Server
    {
      bind.port = 19000;
      host.address = "localhost";
      host.port = 19000;
    }
    # Expo Development Client
    {
      bind.port = 19001;
      host.address = "localhost";
      host.port = 19001;
    }
    # Expo Developer Tools
    {
      bind.port = 19002;
      host.address = "localhost";
      host.port = 19002;
    }
    # Metro Bundler
    {
      bind.port = 8081;
      host.address = "localhost";
      host.port = 8081;
    }
    # Optional: Expo Debugger
    {
      bind.port = 19003;
      host.address = "localhost";
      host.port = 19003;
    }
  ];
in {
  # Install mosh for better mobile connectivity
  home.packages = with pkgs; [
    mosh
  ];

  programs.ssh = {
    enable = true;
    matchBlocks = {
      # Local network connection with SSH + tmux auto-attach
      "workstation-ssh" = {
        hostname = "10.0.0.5";
        user = "henhal";
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "tmux new-session -A -s main";

          # Connection optimization
          Compression = "yes";
          ControlMaster = "auto";
          ControlPath = "~/.ssh/control:%h:%p:%r";
          ControlPersist = "10m";
          IPQoS = "lowdelay throughput";
          TCPKeepAlive = "yes";

          # Optimized ciphers for performance
          Ciphers = "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr";
          KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
          MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
        };

        compression = true;
        serverAliveInterval = 15;
        serverAliveCountMax = 6;

        # Dynamic SOCKS proxy
        dynamicForwards = [
          {
            port = 8888;
            address = "localhost";
          }
        ];

        localForwards = portsToForward;
      };

      # Local network connection with Mosh (no tmux auto-attach - incompatible)
      "workstation-mosh" = {
        hostname = "10.0.0.5";
        user = "henhal";
        extraOptions = {
          # Note: No RemoteCommand - mosh is incompatible with it

          # Connection optimization
          Compression = "yes";
          ControlMaster = "auto";
          ControlPath = "~/.ssh/control:%h:%p:%r";
          ControlPersist = "10m";
          IPQoS = "lowdelay throughput";
          TCPKeepAlive = "yes";

          # Optimized ciphers for performance
          Ciphers = "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr";
          KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
          MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
        };

        compression = true;
        serverAliveInterval = 15;
        serverAliveCountMax = 6;

        # Dynamic SOCKS proxy
        dynamicForwards = [
          {
            port = 8888;
            address = "localhost";
          }
        ];

        localForwards = portsToForward;
      };

      # Tailscale connection with SSH + tmux auto-attach
      "workstation-ts-ssh" = {
        hostname = "100.73.24.108";
        user = "henhal";
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "tmux new-session -A -s main";

          # Connection optimization
          Compression = "yes";
          ControlMaster = "no";
          ControlPath = "~/.ssh/control:%h:%p:%r";
          ControlPersist = "30s";
          IPQoS = "lowdelay throughput";
          TCPKeepAlive = "yes";

          # Optimized ciphers for performance
          Ciphers = "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr";
          KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
          MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
        };

        compression = true;
        serverAliveInterval = 30;
        serverAliveCountMax = 3;

        # Dynamic SOCKS proxy
        dynamicForwards = [
          {
            port = 8888;
            address = "localhost";
          }
        ];

        localForwards = portsToForward;
      };

      # Tailscale connection with Mosh (no tmux auto-attach - incompatible)
      "workstation-ts-mosh" = {
        hostname = "100.73.24.108"; #"workstation.tail37a5eb.ts.net";

        user = "henhal";
        extraOptions = {
          # Note: No RemoteCommand - mosh is incompatible with it

          # Connection optimization
          Compression = "yes";
          ControlMaster = "no";
          ControlPath = "~/.ssh/control:%h:%p:%r";
          ControlPersist = "30s";
          IPQoS = "lowdelay throughput";
          TCPKeepAlive = "yes";

          # Optimized ciphers for performance
          Ciphers = "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr";
          KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
          MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";
        };

        compression = true;
        serverAliveInterval = 30;
        serverAliveCountMax = 3;

        # Dynamic SOCKS proxy
        dynamicForwards = [
          {
            port = 8888;
            address = "localhost";
          }
        ];

        localForwards = portsToForward;
      };
    };
  };

  # Shell aliases for quick access
  programs.zsh.shellAliases = {
    # SSH connections (with tmux auto-attach)
    ws = "ssh workstation-ssh"; # Local network
    wst = "ssh workstation-ts-ssh"; # Tailscale

    # Mosh connections (manual tmux attach required)
    wsm = "mosh workstation-mosh"; # Local network
    wstm = "mosh workstation-ts-mosh"; # Tailscale
  };
}
