{ config, pkgs, ... }: {
  # Enable Cockpit web console
  services.cockpit = {
    enable = true;
    port = 9090;  # Default port for Cockpit
    openFirewall = true;  # Open the firewall port
    settings = {
      WebService = {
        AllowUnencrypted = false;  # Require HTTPS
        ProtocolHeader = "X-Forwarded-Proto";
      };
    };
  };

  # Add useful Cockpit plugins
  environment.systemPackages = with pkgs; [
    cockpit
    # Optional but recommended plugins
    cockpit-machines     # For managing virtual machines
    cockpit-networkmanager  # For network management
    cockpit-storaged    # For storage management
    cockpit-system      # For system management
    # Remove cockpit-podman since we're using Docker
  ];

  # Optional: Add Prometheus monitoring
  services.prometheus = {
    enable = true;
    port = 9091;

    exporters = {
      node = {
        enable = true;
        enabledCollectors = ["systemd" "docker"];  # Added Docker collector
        port = 9100;
      };
    };

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
      }
    ];
  };

  # Add Docker metrics endpoint for Prometheus
  # virtualisation.docker.enable = true; # Docker is already enabled in default.nix

  virtualisation.docker.daemon.settings = {
    metrics-addr = "127.0.0.1:9323";
    experimental = true;
  };
} 
