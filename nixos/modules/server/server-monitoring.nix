{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    prometheus
    grafana
 ];



  # Prometheus setup
  services.prometheus = {
    enable = true;
    port = 9090;  # Default Prometheus port
    
    # Basic retention settings
    retentionTime = "15d";
    
    # Node exporter to collect system metrics
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [
          "systemd"
          "processes"
          "filesystem"
          "diskstats" 
          "cpu"
          "meminfo"
          "netdev"
          "loadavg"
        ];
        port = 9100;  # Default Node Exporter port
      };
    };
    
    # Configure what Prometheus monitors
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
          labels = {
            instance = "nixos-server";
          };
        }];
      }
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:9090" ];
          labels = {
            instance = "prometheus";
          };
        }];
      }
    ];
  };

  # Grafana setup
  services.grafana = {
    enable = true;
    
    # Server settings
    settings = {
      server = {
        http_addr = "0.0.0.0";  # Listen on all interfaces
        http_port = 4000;       # Default Grafana port
        domain = "10.0.0.120";  # Your server IP
        root_url = "http://10.0.0.120:4000/";
      };
      
      # Authentication (we'll set a simple admin password for now)
      security = {
        admin_user = "admin";
        # IMPORTANT: Change this to a secure password!
        admin_password = "StrongPassword123";
      };
      
      # Optional: Auto-provision data sources
      analytics.reporting_enabled = false;
    };
    
    # Auto-provision the Prometheus data source
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:9090";
          isDefault = true;
        }
      ];
    };
  };

  # Open firewall ports for both services
  networking.firewall.allowedTCPPorts = [ 9090 9100 4000 ];
}
