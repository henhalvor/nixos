{ config, pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "server" = {
        hostname = "10.0.0.120";
        user = "henhal";
        extraOptions = {
          RequestTTY = "yes";
          RemoteCommand = "tmux new-session -A -s ssh";
          # Improve connection reliability for proxied services
          ExitOnForwardFailure = "yes";
          
        };
          # Compression can help with web applications
          compression = true;
          # dynamicForward = "8888";  # SOCKS proxy for more flexible forwarding

          # More aggressively keep connection alive
          serverAliveInterval = 30;
          serverAliveCountMax = 6;

          # Add a dynamic SOCKS proxy for flexible forwarding
          dynamicForwards = [
            {
              port = 8888;
              address = "localhost";
            }
          ];
         
        # Forward all necessary ports for Next.js and Supabase
        localForwards = [
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
      };
    };
  };
}
