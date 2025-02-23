{ config, pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "devserver" = {
        hostname = "10.0.0.17";
        user = "henhal";
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
        # Keep connection alive
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
      };
    };
  };
}
