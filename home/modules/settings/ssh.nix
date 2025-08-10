{ config, pkgs, ... }:
let

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
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "server" = {
        # hostname = "10.0.0.120"; # WIFI connection to server
        hostname = "10.0.0.2"; # LAN connection to server
        user = "henhal-dev";
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "tmux new-session -A -s ssh";
          # Improve connection reliability for proxied services
          ExitOnForwardFailure = "yes";

          # Performance optimizations
          Compression = "yes";
          ControlMaster = "auto";
          ControlPath = "~/.ssh/control:%h:%p:%r";
          ControlPersist = "10m";
          IPQoS = "lowdelay throughput";
          TCPKeepAlive = "yes";

          # Optimized ciphers and algorithms for better performance
          Ciphers =
            "chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr";
          KexAlgorithms =
            "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
          MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com";

        };
        # Compression can help with web applications
        compression = true;
        # dynamicForward = "8888";  # SOCKS proxy for more flexible forwarding

        # More aggressively keep connection alive
        serverAliveInterval = 15;
        serverAliveCountMax = 6;

        # Add a dynamic SOCKS proxy for flexible forwarding
        dynamicForwards = [{
          port = 8888;
          address = "localhost";
        }];

        # Forward all necessary ports for Next.js and Supabase
        localForwards = portsToForward;
      };
      # Workstation connection (when connecting FROM laptop TO workstation)
      "workstation" = {
        hostname = "10.0.0.5"; # Adjust this to your workstation's IP
        user = "henhal";
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "tmux new-session -A -s ssh";
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

      # Laptop connection (when connecting FROM workstation TO laptop)
      # We are not forwarding any ports here
      "laptop" = {
        hostname = "10.0.0.25"; # Adjust this to your laptop's IP
        user = "henhal";
        identityFile =
          "~/.ssh/id_workstation"; # Had trouble connecting from workstation to laptop, so explicitly set identity file to use my workstation key
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "tmux new-session -A -s ssh";
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
}
