{ config, pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    powertop
    thermald
    auto-cpufreq
    tlp
    acpi
    acpid
    # Replace cpupower with the correct package
    linuxPackages.cpupower
    cpulimit
  ];

  powerManagement = {
    enable = true;
    powertop.enable = true;
    cpuFreqGovernor = "powersave";
    # Remove the conflicting scsiLinkPolicy
  };

  services = {
    power-profiles-daemon.enable = false;
    auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
          scaling_min_freq = 400000;  # Set lower minimum frequency
          scaling_max_freq = 1800000; # Limit maximum frequency on battery
          energy_performance_preference = "power"; # Prioritize power saving over performance
        };
        charger = {
          governor = "powersave";
          turbo = "auto";
          scaling_min_freq = 400000;  # Also set lower min frequency on AC
          scaling_max_freq = 2400000; # Moderate max frequency on AC
          energy_performance_preference = "balance_power"; # Balance power and performance
        };
      };
    };
    
    # TLP for more comprehensive power management
    tlp = {
      enable = true;
      settings = {
        # CPU settings
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_BOOST_ON_AC = 0;
        CPU_BOOST_ON_BAT = 0;
        
        # CPU frequency limits
        CPU_SCALING_MIN_FREQ_ON_AC = 400000;
        CPU_SCALING_MAX_FREQ_ON_AC = 2400000;  # Throttle even on AC
        CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
        CPU_SCALING_MAX_FREQ_ON_BAT = 1800000;
        
        # CPU energy/performance policies
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance-power";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        
        # CPU scaling factors
        CPU_MAX_PERF_ON_AC = 80;        # Limit to 80% performance on AC
        CPU_MAX_PERF_ON_BAT = 60;       # Limit to 60% performance on battery
        
        # CPU throttle temperatures
        CPU_TEMP_UNDERVOLT = 75;        # Start light throttling at 75°C
        CPU_TEMP_THROTTLE = 85;         # Aggressive throttling at 85°C
        
        # Display and graphics settings
        RADEON_DPM_STATE_ON_AC = "performance";
        RADEON_DPM_STATE_ON_BAT = "battery";
        INTEL_GPU_MIN_FREQ_ON_AC = 350;
        INTEL_GPU_MIN_FREQ_ON_BAT = 350;
        INTEL_GPU_MAX_FREQ_ON_AC = 1150;
        INTEL_GPU_MAX_FREQ_ON_BAT = 800;
        INTEL_GPU_BOOST_FREQ_ON_AC = 1150;
        INTEL_GPU_BOOST_FREQ_ON_BAT = 800;
        
        # Power saving settings
        PCIE_ASPM_ON_BAT = "powersupersave";
        RUNTIME_PM_ON_BAT = "auto";
        USB_AUTOSUSPEND = 1;
        # WIFI_PWR_ON_BAT = 2;         # Medium power saving instead of maximum (1)
        DEVICES_TO_DISABLE_ON_BAT = ""; # Don't disable any devices on battery
        DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = ""; # Don't disable unused devices
        
        # Bluetooth settings
        DEVICES_TO_DISABLE_ON_STARTUP = ""; # Don't disable Bluetooth on startup
        BLUETOOTH_POWER_ON_AC = 1;    # Keep Bluetooth powered on AC
        BLUETOOTH_POWER_ON_BAT = 1;   # Keep Bluetooth powered on battery
        
        WOL_DISABLE = "Y";
        
        # SATA link power management (replacing powerManagement.scsiLinkPolicy)
        SATA_LINKPWR_ON_AC = "med_power_with_dipm";
        SATA_LINKPWR_ON_BAT = "min_power";
        
        # Additional disk power saving settings
        DISK_DEVICES = "sda sdb nvme0n1"; # Update with your actual disk devices
        DISK_APM_LEVEL_ON_AC = "254 254";
        DISK_APM_LEVEL_ON_BAT = "128 128";
        DISK_SPINDOWN_TIMEOUT_ON_AC = "0 0";
        DISK_SPINDOWN_TIMEOUT_ON_BAT = "60 60";
        DISK_IOSCHED = "none none";
        
        # Battery charge thresholds (if supported)
        # START_CHARGE_THRESH_BAT0 = 40;
        # STOP_CHARGE_THRESH_BAT0 = 80;

        # WiFi power management (use moderate settings that won't break connectivity)
        WIFI_PWR_ON_AC = 0;          # No power saving on AC
        WIFI_PWR_ON_BAT = 3;         # Moderate power saving (not aggressive)
        
      };
    };
    
    # Enhanced thermald configuration
    thermald = {
      enable = true;
      configFile = pkgs.writeText "thermal-conf.xml" ''
        <?xml version="1.0"?>
        <ThermalConfiguration>
          <Platform>
            <Name>CPU Throttling Configuration</Name>
            <ProductName>*</ProductName>
            <Preference>QUIET</Preference>
            <ThermalZones>
              <ThermalZone>
                <Type>cpu</Type>
                <TripPoints>
                  <TripPoint>
                    <SensorType>x86_pkg_temp</SensorType>
                    <Temperature>70000</Temperature>
                    <Type>passive</Type>
                    <CoolingDevice>
                      <Type>CPU</Type>
                      <SamplingPeriod>5</SamplingPeriod>
                    </CoolingDevice>
                  </TripPoint>
                </TripPoints>
              </ThermalZone>
            </ThermalZones>
          </Platform>
        </ThermalConfiguration>
      '';
    };
    

       
    udev.extraRules = ''
      # Remove NVIDIA USB xHCI Host Controller devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA USB Type-C UCSI devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA Audio devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA VGA/3D controller devices
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
      
      # USB autosuspend
      ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="auto"
      
      # PCI runtime power management
      SUBSYSTEM=="pci", ATTR{power/control}="auto"
    '';
  };
  
  boot = {
    extraModprobeConfig = ''
      blacklist nouveau
      options nouveau modeset=0
      
      # Additional power saving options for Intel and AMD
      options snd_hda_intel power_save=1
      
      # WiFi power management - use safer settings
      options iwlwifi power_save=0 d0i3_disable=1
      
      options btusb enable_autosuspend=0 # Prevent Bluetooth from auto-suspending
      options i915 enable_dc=2 enable_fbc=1 enable_guc=2
    '';
    blacklistedKernelModules =
      [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];
    kernelParams = [
      "quiet"
      "acpi_osi=Linux"
      "mem_sleep_default=deep"
      "intel_pstate=passive"
      "pcie_aspm=force"
      "i915.enable_psr=1"
      "i915.enable_fbc=1"
      "nmi_watchdog=0"
      "usbcore.autosuspend=1"
      "processor.max_cstate=5"          # Limit CPU to C-state 5
      "intel_pstate=passive"            # Allow userspace control of CPU freq
      "intel_pstate.max_perf_pct=80"    # Limit max performance to 80%
      "intel_pstate.no_turbo=1"         # Disable turbo boost
    ];
    
    # I/O scheduler optimization
    kernel.sysctl = {
      "vm.laptop_mode" = 5;
      "vm.dirty_writeback_centisecs" = 1500;
      "vm.swappiness" = 10;
      "kernel.nmi_watchdog" = 0;
    };
  };
  
  # Configure system sleep settings
  systemd = {
    sleep.extraConfig = ''
      HibernateDelaySec=3600
      SuspendState=mem
    '';
    services.power-profiles-daemon.enable = false; # Ensure it's disabled in favor of TLP
  };
  
  # Add hardware configuration to ensure Bluetooth works properly
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;  # Keep Bluetooth on at boot
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };
  };
  
  # Configure networking with power-efficient settings that won't break connectivity
  networking = {
    networkmanager = {
      enable = true;
      # Let the service settings above handle the backend configuration
    };
    
    # Pick only ONE of these options:
    
    # OPTION 1: Disable iwd (use with wpa_supplicant backend)
    wireless.iwd.enable = false;
    
    # OPTION 2: Enable iwd (use with iwd backend)
    # wireless.iwd.enable = true;
    # wireless.iwd.settings = {
    #   General = {
    #     EnableNetworkConfiguration = false;  # Let NetworkManager handle it
    #   };
    #   Settings = {
    #     AutoConnect = true;
    #   };
    # };
  };

  # CPU throttling service - fixed version
  systemd.services.cpu-throttle = {
    description = "CPU Throttling Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Only use commands known to work and avoid the failing set -b command
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.linuxPackages.cpupower}/bin/cpupower frequency-set -g powersave && ${pkgs.linuxPackages.cpupower}/bin/cpupower frequency-set --min 400MHz --max 2.4GHz'";
      RemainAfterExit = true;
      # Add permissions to access CPU controls
      CapabilityBoundingSet = ["CAP_SYS_NICE" "CAP_SYS_ADMIN"];
      ProtectSystem = "strict";
      ProtectHome = true;
      # Add retry on failure
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
